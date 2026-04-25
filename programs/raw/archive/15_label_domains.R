# =============================================================================
# torivumab guidelines loaded
# 15_label_domains.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Label Attachment
# =============================================================================
#
# Attaches CDISC SDTMIG v3.4 variable labels to every Parquet domain using
# labelled::set_variable_labels(). Labels are serialised by {arrow} into the
# Parquet file's R metadata blob and are therefore available to any R user
# who reads the file with arrow::read_parquet() — no extra lookup needed.
#
# Label source: SDTMIG v3.4, CDISC Controlled Terminology 2024-03
#
# Outputs: overwrites sdtm/*.parquet in-place with labels attached
#
# Dependencies: all sdtm/*.parquet files must already exist
# Run after: 01_dm.R … 14_dd.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(labelled)
  library(dplyr)
})

# ── Master variable label dictionary (SDTMIG v3.4) ───────────────────────────
# Shared variables (appear in most domains)
SHARED <- list(
  STUDYID  = "Study Identifier",
  DOMAIN   = "Domain Abbreviation",
  USUBJID  = "Unique Subject Identifier",
  VISIT    = "Visit Name",
  VISITNUM = "Visit Number",
  EPOCH    = "Epoch"
)

DOMAIN_LABELS <- list(

  dm = c(SHARED, list(
    SUBJID   = "Subject Identifier for the Study",
    RFSTDTC  = "Subject Reference Start Date/Time",
    RFENDTC  = "Subject Reference End Date/Time",
    RFXSTDTC = "Date/Time of First Study Treatment",
    RFXENDTC = "Date/Time of Last Study Treatment",
    RFICDTC  = "Date/Time of Informed Consent",
    RFPENDTC = "Date/Time of End of Participation",
    DTHDTC   = "Date/Time of Death",
    DTHFL    = "Subject Death Flag",
    SITEID   = "Study Site Identifier",
    BRTHDTC  = "Date/Time of Birth",
    AGE      = "Age",
    AGEU     = "Age Units",
    SEX      = "Sex",
    RACE     = "Race",
    ETHNIC   = "Ethnicity",
    ARMCD    = "Planned Arm Code",
    ARM      = "Description of Planned Arm",
    ACTARMCD = "Actual Arm Code",
    ACTARM   = "Description of Actual Arm",
    COUNTRY  = "Country",
    DMDTC    = "Date/Time of Collection"
  )),

  suppdm = list(
    STUDYID  = "Study Identifier",
    RDOMAIN  = "Related Domain Abbreviation",
    USUBJID  = "Unique Subject Identifier",
    IDVAR    = "Identifying Variable",
    IDVARVAL = "Identifying Variable Value",
    QNAM     = "Qualifier Variable Name",
    QLABEL   = "Qualifier Variable Label",
    QVAL     = "Data Value",
    QORIG    = "Origin",
    QEVAL    = "Evaluator"
  ),

  ex = c(SHARED, list(
    EXSEQ    = "Sequence Number",
    EXTRT    = "Name of Treatment",
    EXDOSE   = "Dose per Administration",
    EXDOSU   = "Dose Units",
    EXDOSFRM = "Dose Form",
    EXDOSFRQ = "Dosing Frequency per Interval",
    EXROUTE  = "Route of Administration",
    EXSTDTC  = "Start Date/Time of Treatment",
    EXENDTC  = "End Date/Time of Treatment",
    EXDOSEMOD = "Reason for Dose Adjustment",
    EXSTDY   = "Study Day of Start of Treatment"
  )),

  ds = c(SHARED, list(
    DSSEQ    = "Sequence Number",
    DSTERM   = "Reported Term for the Disposition Event",
    DSDECOD  = "Standardized Disposition Term",
    DSCAT    = "Category for Disposition Event",
    DSSCAT   = "Subcategory for Disposition Event",
    DSSTDTC  = "Start Date/Time of Disposition Event",
    DSENDTC  = "End Date/Time of Disposition Event"
  )),

  ae = c(SHARED, list(
    AESEQ    = "Sequence Number",
    AETERM   = "Reported Term for the Adverse Event",
    AEDECOD  = "Dictionary-Derived Term",
    AEBODSYS = "Body System or Organ Class",
    AESOC    = "Primary System Organ Class",
    AESTDTC  = "Start Date/Time of Adverse Event",
    AEENDTC  = "End Date/Time of Adverse Event",
    AETOXGR  = "Standard Toxicity Grade",
    AESEV    = "Severity/Intensity",
    AEREL    = "Causality",
    AESER    = "Serious Event",
    AEACN    = "Action Taken with Study Treatment",
    AEOUT    = "Outcome of Adverse Event",
    AESTDY   = "Study Day of Start of Adverse Event"
  )),

  cm = c(SHARED, list(
    CMSEQ    = "Sequence Number",
    CMTRT    = "Reported Name of Drug, Med, or Therapy",
    CMDECOD  = "Standardized Medication Name",
    CMCLAS   = "Medication Class",
    CMSTDTC  = "Start Date/Time of Medication",
    CMENDTC  = "End Date/Time of Medication",
    CMENRTPT = "End Relative to Reference Time Point",
    CMONGO   = "Ongoing Indicator"
  )),

  mh = c(SHARED, list(
    MHSEQ    = "Sequence Number",
    MHTERM   = "Reported Term for the Medical History",
    MHDECOD  = "Dictionary-Derived Term",
    MHBODSYS = "Body System or Organ Class",
    MHOCCUR  = "Medical History Occurrence",
    MHSTDTC  = "Start Date/Time of Medical History Event",
    MHENDTC  = "End Date/Time of Medical History Event",
    MHENRTPT = "End Relative to Reference Time Point"
  )),

  su = c(SHARED, list(
    SUSEQ    = "Sequence Number",
    SUTRT    = "Reported Name of Substance Used",
    SUCAT    = "Category of Substance Use",
    SUOCCUR  = "Substance Use Occurrence",
    SUSTDTC  = "Start Date/Time of Substance Use",
    SUENDTC  = "End Date/Time of Substance Use",
    SUENRTPT = "End Relative to Reference Time Point",
    SUDOSE   = "Dose per Administration",
    SUDOSU   = "Dose Units"
  )),

  suppsu = list(
    STUDYID  = "Study Identifier",
    RDOMAIN  = "Related Domain Abbreviation",
    USUBJID  = "Unique Subject Identifier",
    IDVAR    = "Identifying Variable",
    IDVARVAL = "Identifying Variable Value",
    QNAM     = "Qualifier Variable Name",
    QLABEL   = "Qualifier Variable Label",
    QVAL     = "Data Value",
    QORIG    = "Origin",
    QEVAL    = "Evaluator"
  ),

  vs = c(SHARED, list(
    VSSEQ    = "Sequence Number",
    VSTESTCD = "Vital Signs Test Short Name",
    VSTEST   = "Vital Signs Test Name",
    VSORRES  = "Result or Finding in Original Units",
    VSORRESU = "Original Units",
    VSSTRESC = "Character Result/Finding in Std Format",
    VSSTRESN = "Numeric Result/Finding in Standard Units",
    VSSTRESU = "Standard Units",
    VSDTC    = "Date/Time of Measurements",
    VSDY     = "Study Day of Vital Signs"
  )),

  lb = c(SHARED, list(
    LBSEQ    = "Sequence Number",
    LBTESTCD = "Lab Test or Examination Short Name",
    LBTEST   = "Lab Test or Examination Name",
    LBCAT    = "Category for Lab Test",
    LBORRES  = "Result or Finding in Original Units",
    LBORRESU = "Original Units",
    LBSTRESC = "Character Result/Finding in Std Format",
    LBSTRESN = "Numeric Result/Finding in Standard Units",
    LBSTRESU = "Standard Units",
    LBNRLO   = "Reference Range Lower Limit in Std Unit",
    LBNRHI   = "Reference Range Upper Limit in Std Unit",
    LBNRIND  = "Reference Range Indicator",
    LBDTC    = "Date/Time of Specimen Collection",
    LBDY     = "Study Day of Specimen Collection"
  )),

  pe = c(SHARED, list(
    PESEQ    = "Sequence Number",
    PETESTCD = "Body System Examined Short Name",
    PETEST   = "Body System Examined",
    PECAT    = "Category for Examination",
    PEORRES  = "Result or Finding in Original Units",
    PEDESC   = "Description of Finding",
    PECLSIG  = "Clinically Significant",
    PEDTC    = "Date/Time of Examination",
    PEDY     = "Study Day of Examination"
  )),

  tu = c(SHARED, list(
    TUSEQ    = "Sequence Number",
    TUREFID  = "Reference ID",
    TULNKID  = "Link ID",
    TUORRES  = "Result or Finding in Original Units",
    TUSTRESC = "Character Result/Finding in Std Format",
    TULOC    = "Location of the Tumor",
    TULAT    = "Laterality",
    TUDIR    = "Directionality",
    TUMETHOD = "Method of Identification",
    TUTESTCD = "Tumor Identification Short Name",
    TUTEST   = "Tumor Identification Name",
    TUCAT    = "Category of Tumor",
    TUSPID   = "Sponsor-Defined Identifier",
    TUSTDTC  = "Start Date/Time of Tumor Identification",
    TUDY     = "Study Day of Tumor Identification"
  )),

  tr = c(SHARED, list(
    TRSEQ    = "Sequence Number",
    TRREFID  = "Reference ID",
    TRLNKID  = "Link ID",
    TRTESTCD = "Tumor Result Test Short Name",
    TRTEST   = "Tumor Result Test Name",
    TRORRES  = "Result or Finding in Original Units",
    TRORRESU = "Original Units",
    TRSTRESC = "Character Result/Finding in Std Format",
    TRSTRESN = "Numeric Result/Finding in Standard Units",
    TRSTRESU = "Standard Units",
    TRSTAT   = "Completion Status",
    TRDTC    = "Date/Time of Assessment",
    TRDY     = "Study Day of Assessment"
  )),

  rs = c(SHARED, list(
    RSSEQ    = "Sequence Number",
    RSTESTCD = "Disease Response Test Short Name",
    RSTEST   = "Disease Response Test Name",
    RSCAT    = "Category of Disease Response",
    RSSCAT   = "Subcategory of Disease Response",
    RSORRES  = "Result or Finding in Original Units",
    RSSTRESC = "Character Result/Finding in Std Format",
    RSDTC    = "Date/Time of Disease Response Assessment",
    RSDY     = "Study Day of Disease Response Assessment"
  )),

  dd = c(SHARED, list(
    DDSEQ    = "Sequence Number",
    DDTERM   = "Reported Term for the Death Detail",
    DDDECOD  = "Dictionary-Derived Term",
    DDCAT    = "Category for Death Detail",
    DDSCAT   = "Subcategory for Death Detail",
    DDDTC    = "Date/Time of Death",
    DDDY     = "Study Day of Death"
  ))
)


# ── Helper: apply labels to a data frame ─────────────────────────────────────
# Only labels for columns that actually exist in df are applied;
# extra label entries are silently ignored (avoids errors on optional vars).
apply_labels <- function(df, label_list) {
  applicable <- label_list[intersect(names(label_list), names(df))]
  set_variable_labels(df, .labels = applicable)
}


# ── Process each domain ───────────────────────────────────────────────────────
parquet_files <- list.files("sdtm/", pattern = "\\.parquet$", full.names = TRUE)

cat("\n=== Label Attachment (SDTMIG v3.4) ===\n")

results <- lapply(parquet_files, function(path) {
  domain_key <- sub("\\.parquet$", "", basename(path))

  if (!domain_key %in% names(DOMAIN_LABELS)) {
    cat(sprintf("  %-12s SKIP (no label definition)\n", domain_key))
    return(invisible(NULL))
  }

  df        <- read_parquet(path) %>% as.data.frame()
  label_map <- DOMAIN_LABELS[[domain_key]]

  n_vars     <- ncol(df)
  n_labelled <- length(intersect(names(label_map), names(df)))
  n_missing  <- length(setdiff(names(df), names(label_map)))

  df_labelled <- apply_labels(df, label_map)

  # Write to a sibling temp file in the same directory, then atomically rename.
  # Using tempfile() in a different directory (e.g. Windows %TEMP%) causes
  # file.copy() to fail with "Invalid argument" across drives. file.rename()
  # within the same directory is atomic and avoids the memory-map lock on the
  # source file.
  tmp <- paste0(path, ".tmp")
  write_parquet(df_labelled, tmp)
  file.rename(tmp, path)

  cat(sprintf("  %-12s %3d / %3d vars labelled",
              domain_key, n_labelled, n_vars))
  if (n_missing > 0L) {
    unlabelled <- setdiff(names(df), names(label_map))
    cat(sprintf("  [unlabelled: %s]", paste(unlabelled, collapse = ", ")))
  }
  cat("\n")
  invisible(NULL)
})

# ── Verify round-trip ─────────────────────────────────────────────────────────
cat("\n  Round-trip check (dm.parquet):\n")
dm_check <- read_parquet("sdtm/dm.parquet") %>% as.data.frame()
dm_lbls  <- var_label(dm_check)
cat(sprintf("    USUBJID label : %s\n", dm_lbls$USUBJID))
cat(sprintf("    AGE label     : %s\n", dm_lbls$AGE))
cat(sprintf("    RFSTDTC label : %s\n", dm_lbls$RFSTDTC))
cat(sprintf("    DTHFL label   : %s\n", dm_lbls$DTHFL))

cat("\n=== Label attachment complete ===\n")
