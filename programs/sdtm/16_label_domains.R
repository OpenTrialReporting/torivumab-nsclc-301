# =============================================================================
# Program    : 16_label_domains.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Attach SDTMIG v3.4 variable labels to every SDTM parquet domain.
#              Uses labelled::set_variable_labels(); arrow serialises the
#              labelled attributes into the parquet R-metadata blob so that
#              any reader using arrow::read_parquet() recovers the labels
#              automatically — no separate lookup needed.
# Reads from : datasets/sdtm/*.parquet
# Writes to  : datasets/sdtm/*.parquet  (in-place, via atomic .tmp rename)
# Run after  : all domain mapping programs (00_run_sdtm.R sources this last)
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(labelled)
  library(dplyr)
})

SDTM_DIR <- file.path("datasets", "sdtm")

# -----------------------------------------------------------------------------
# Master variable label dictionary — SDTMIG v3.4
# -----------------------------------------------------------------------------
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
    SITEID   = "Study Site Identifier",
    BRTHDTC  = "Date/Time of Birth",
    AGE      = "Age",
    AGEU     = "Age Units",
    SEX      = "Sex",
    RACE     = "Race",
    ETHNIC   = "Ethnicity",
    COUNTRY  = "Country",
    ARMCD    = "Planned Arm Code",
    ARM      = "Description of Planned Arm",
    ACTARMCD = "Actual Arm Code",
    ACTARM   = "Description of Actual Arm",
    ARMNRS   = "Reason Arm and/or Epoch Not Collected",
    RFSTDTC  = "Subject Reference Start Date/Time",
    RFENDTC  = "Subject Reference End Date/Time",
    RFXSTDTC = "Date/Time of First Study Treatment",
    RFXENDTC = "Date/Time of Last Study Treatment",
    RFICDTC  = "Date/Time of Informed Consent",
    RFPENDTC = "Date/Time of End of Participation",
    DTHDTC   = "Date/Time of Death",
    DTHFL    = "Subject Death Flag",
    DMDTC    = "Date/Time of Collection",
    DMDY     = "Study Day of Collection"
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

  ds = c(SHARED, list(
    DSSEQ    = "Sequence Number",
    DSTERM   = "Reported Term for the Disposition Event",
    DSDECOD  = "Standardized Disposition Term",
    DSCAT    = "Category for Disposition Event",
    DSSCAT   = "Subcategory for Disposition Event",
    DSSTDTC  = "Start Date/Time of Disposition Event",
    DSENDTC  = "End Date/Time of Disposition Event",
    DSDY     = "Study Day of Start of Disposition Event"
  )),

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
    EXSTDY   = "Study Day of Start of Treatment",
    EXENDY   = "Study Day of End of Treatment"
  )),

  ae = c(SHARED, list(
    AESEQ    = "Sequence Number",
    AETERM   = "Reported Term for the Adverse Event",
    AEDECOD  = "Dictionary-Derived Term",
    AEBODSYS = "Body System or Organ Class",
    AEHLT    = "High Level Term",
    AELLT    = "Lowest Level Term",
    AESOC    = "Primary System Organ Class",
    AECAT    = "Category for Adverse Event",
    AESEV    = "Severity/Intensity",
    AETOXGR  = "Standard Toxicity Grade",
    AESER    = "Serious Event",
    AEREL    = "Causality",
    AEACN    = "Action Taken with Study Treatment",
    AEOUT    = "Outcome of Adverse Event",
    AESTDTC  = "Start Date/Time of Adverse Event",
    AEENDTC  = "End Date/Time of Adverse Event",
    AESTDY   = "Study Day of Start of Adverse Event",
    AEENDY   = "Study Day of End of Adverse Event",
    AESDTH   = "Results in Death",
    AESHOSP  = "Requires or Prolongs Inpatient Hospitalisation",
    AESLIFE  = "Is Life Threatening",
    AESDISAB = "Causes Persistent or Significant Disability/Incapacity",
    AESMIE   = "Other Medically Important Serious Event",
    AESCONG  = "Congenital Anomaly or Birth Defect"
  )),

  cm = c(SHARED, list(
    CMSEQ    = "Sequence Number",
    CMTRT    = "Reported Name of Drug, Med, or Therapy",
    CMDECOD  = "Standardized Medication Name",
    CMCLAS   = "Medication Class",
    CMCAT    = "Category for Medication",
    CMINDC   = "Indication",
    CMROUTE  = "Route of Administration",
    CMSTDTC  = "Start Date/Time of Medication",
    CMENDTC  = "End Date/Time of Medication",
    CMENRTPT = "End Relative to Reference Time Point",
    CMONGO   = "Ongoing Indicator",
    CMSTDY   = "Study Day of Start of Medication",
    CMENDY   = "Study Day of End of Medication"
  )),

  mh = c(SHARED, list(
    MHSEQ    = "Sequence Number",
    MHTERM   = "Reported Term for the Medical History",
    MHDECOD  = "Dictionary-Derived Term",
    MHBODSYS = "Body System or Organ Class",
    MHCAT    = "Category for Medical History",
    MHOCCUR  = "Medical History Occurrence",
    MHPRESP  = "Medical History Pre-Specified",
    MHSTDTC  = "Start Date/Time of Medical History Event",
    MHENDTC  = "End Date/Time of Medical History Event",
    MHENRTPT = "End Relative to Reference Time Point",
    MHSTDY   = "Study Day of Start of Medical History Event"
  )),

  su = c(SHARED, list(
    SUSEQ    = "Sequence Number",
    SUTRT    = "Reported Name of Substance Used",
    SUCAT    = "Category of Substance Use",
    SUSCAT   = "Subcategory of Substance Use",
    SUOCCUR  = "Substance Use Occurrence",
    SUDOSE   = "Dose per Administration",
    SUDOSU   = "Dose Units",
    SUFREQ   = "Dosing Frequency per Interval",
    SUSTDTC  = "Start Date/Time of Substance Use",
    SUENDTC  = "End Date/Time of Substance Use",
    SUENRTPT = "End Relative to Reference Time Point"
  )),

  vs = c(SHARED, list(
    VSSEQ    = "Sequence Number",
    VSTESTCD = "Vital Signs Test Short Name",
    VSTEST   = "Vital Signs Test Name",
    VSCAT    = "Category for Vital Signs",
    VSORRES  = "Result or Finding in Original Units",
    VSORRESU = "Original Units",
    VSSTRESC = "Character Result/Finding in Std Format",
    VSSTRESN = "Numeric Result/Finding in Standard Units",
    VSSTRESU = "Standard Units",
    VSNRLO   = "Reference Range Lower Limit-Orig Units",
    VSNRHI   = "Reference Range Upper Limit-Orig Units",
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
    LBSTNRLO = "Reference Range Lower Limit in Std Unit",
    LBSTNRHI = "Reference Range Upper Limit in Std Unit",
    LBNRIND  = "Reference Range Indicator",
    LBBLFL   = "Baseline Flag",
    LBDTC    = "Date/Time of Specimen Collection",
    LBDY     = "Study Day of Specimen Collection"
  )),

  pe = c(SHARED, list(
    PESEQ    = "Sequence Number",
    PETESTCD = "Body System Examined Short Name",
    PETEST   = "Body System Examined",
    PECAT    = "Category for Examination",
    PEORRES  = "Result or Finding in Original Units",
    PENORM   = "Normal Indicator",
    PECLSIG  = "Clinically Significant",
    PEDTC    = "Date/Time of Examination",
    PEDY     = "Study Day of Examination"
  )),

  tu = c(SHARED, list(
    TUSEQ    = "Sequence Number",
    TUTESTCD = "Tumor Identification Short Name",
    TUTEST   = "Tumor Identification Name",
    TUORRES  = "Result or Finding in Original Units",
    TUSTRESC = "Character Result/Finding in Std Format",
    TULOC    = "Location of the Tumor",
    TUMETHOD = "Method of Identification",
    TUGRPID  = "Group ID",
    TULINKID = "Link ID",
    TUDTC    = "Date/Time of Tumor Identification",
    TUDY     = "Study Day of Tumor Identification"
  )),

  tr = c(SHARED, list(
    TRSEQ    = "Sequence Number",
    TRTESTCD = "Tumor Result Test Short Name",
    TRTEST   = "Tumor Result Test Name",
    TRORRES  = "Result or Finding in Original Units",
    TRORRESU = "Original Units",
    TRSTRESC = "Character Result/Finding in Std Format",
    TRSTRESN = "Numeric Result/Finding in Standard Units",
    TRSTRESU = "Standard Units",
    TRGRPID  = "Group ID",
    TRLINKID = "Link ID",
    TRDTC    = "Date/Time of Assessment",
    TRDY     = "Study Day of Assessment"
  )),

  rs = c(SHARED, list(
    RSSEQ    = "Sequence Number",
    RSTESTCD = "Disease Response Test Short Name",
    RSTEST   = "Disease Response Test Name",
    RSCAT    = "Category of Disease Response",
    RSSCAT   = "Subcategory of Disease Response",
    RSEVAL   = "Evaluator",
    RSORRES  = "Result or Finding in Original Units",
    RSSTRESC = "Character Result/Finding in Std Format",
    RSSTRESN = "Numeric Result/Finding in Standard Units",
    RSDTC    = "Date/Time of Disease Response Assessment",
    RSDY     = "Study Day of Disease Response Assessment"
  )),

  dd = c(SHARED, list(
    DDSEQ    = "Sequence Number",
    DDTESTCD = "Death Detail Test Short Name",
    DDTEST   = "Death Detail Test Name",
    DDCAT    = "Category for Death Detail",
    DDTERM   = "Reported Term for Death Detail",
    DDORRES  = "Result or Finding in Original Units",
    DDSTRESC = "Character Result/Finding in Std Format",
    DDDTC    = "Date/Time of Death",
    DDDY     = "Study Day of Death"
  ))
)

# -----------------------------------------------------------------------------
# Helper — apply only labels for variables that exist in the data frame
# (silently ignores label entries for absent variables)
# -----------------------------------------------------------------------------
apply_labels <- function(df, label_list) {
  applicable <- label_list[intersect(names(label_list), names(df))]
  # var_label<- accepts a named list; only columns present in df are set.
  var_label(df) <- applicable
  df
}

# -----------------------------------------------------------------------------
# Process each domain parquet
# -----------------------------------------------------------------------------
parquet_files <- list.files(SDTM_DIR, pattern = "\\.parquet$", full.names = TRUE)

cat("\n=== Label Attachment (SDTMIG v3.4) ===\n")
cat(sprintf("  Source: %s\n\n", SDTM_DIR))

for (path in parquet_files) {
  domain_key <- sub("\\.parquet$", "", basename(path))

  if (!domain_key %in% names(DOMAIN_LABELS)) {
    cat(sprintf("  %-12s SKIP (no label definition)\n", domain_key))
    next
  }

  df        <- as.data.frame(read_parquet(path))
  label_map <- DOMAIN_LABELS[[domain_key]]

  n_vars      <- ncol(df)
  n_labelled  <- length(intersect(names(label_map), names(df)))
  unlabelled  <- setdiff(names(df), names(label_map))

  df_labelled <- apply_labels(df, label_map)

  # Atomic write: temp file in same directory avoids cross-device rename errors
  tmp <- paste0(path, ".tmp")
  write_parquet(df_labelled, tmp)
  file.rename(tmp, path)

  cat(sprintf("  %-12s %3d / %3d vars labelled", domain_key, n_labelled, n_vars))
  if (length(unlabelled) > 0) {
    cat(sprintf("  [unlabelled: %s]", paste(unlabelled, collapse = ", ")))
  }
  cat("\n")
}

# -----------------------------------------------------------------------------
# Round-trip verification
# -----------------------------------------------------------------------------
cat("\n  Round-trip check (dm.parquet):\n")
dm_check <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dm.parquet")))
dm_lbls  <- var_label(dm_check)
cat(sprintf("    USUBJID  : %s\n", dm_lbls$USUBJID))
cat(sprintf("    AGE      : %s\n", dm_lbls$AGE))
cat(sprintf("    RFSTDTC  : %s\n", dm_lbls$RFSTDTC))
cat(sprintf("    DTHFL    : %s\n", dm_lbls$DTHFL))
cat(sprintf("    ARM      : %s\n", dm_lbls$ARM))

cat("\n=== Label attachment complete ===\n")
