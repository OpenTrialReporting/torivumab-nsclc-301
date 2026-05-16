# torivumab guidelines loaded
# =============================================================================
# Program    : build_define.R
# Purpose    : Generate Define-XML v2.1 covering all SDTM (datasets/sdtm/) and
#              ADaM (datasets/adam/) parquet datasets. Variable-level metadata
#              (name, label, datatype, length, mandatory, origin, key sequence,
#              class, structure) is derived from the parquet schemas and the
#              labelled attributes attached by 16_label_domains.R.
#
# Scope (v0.1):
#   - All 21 SDTM domains + 6 ADaM datasets
#   - ItemGroupDef per dataset, ItemRef + ItemDef per variable
#   - Origin stubbed by heuristic (Assigned / Collected / Derived)
#   - CodeListDef refs are sponsor-defined stubs (extend later)
#   - No Value-Level Metadata; no full MethodDef chains
#
# Output     : define/define.xml
#              define/DEFINE-SUMMARY.md (human-readable inventory)
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(labelled)
  library(xml2)
  library(dplyr)
  library(stringr)
})

STUDYID    <- "CTX-NSCLC-301"
STUDYNAME  <- "SIMULATED-TORIVUMAB-2026"
STUDYDESC  <- "Phase 3 randomised, double-blind, placebo-controlled NSCLC study (synthetic data)"
PROTOCOL   <- "TORIVUMAB-NSCLC-301"
ORIGINATOR <- "Lovemore Gakava (synthetic dataset author)"
NOW        <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
TODAY      <- format(Sys.Date(), "%Y-%m-%d")

SDTM_DIR <- "datasets/sdtm"
ADAM_DIR <- "datasets/adam"
OUT_DIR  <- "define"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# Domain metadata: class, structure, key variables
# -----------------------------------------------------------------------------
DOMAIN_META <- list(
  # SDTM
  dm     = list(class = "SPECIAL PURPOSE", structure = "One record per subject",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID")),
  ds     = list(class = "EVENTS",          structure = "One record per subject per disposition event",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "DSSEQ")),
  ex     = list(class = "INTERVENTIONS",   structure = "One record per subject per administration",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "EXSEQ")),
  da     = list(class = "INTERVENTIONS",   structure = "One record per subject per accountability measure per drug per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "DASEQ")),
  ae     = list(class = "EVENTS",          structure = "One record per subject per adverse event",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "AESEQ")),
  cm     = list(class = "INTERVENTIONS",   structure = "One record per subject per medication per occurrence",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "CMSEQ")),
  lb     = list(class = "FINDINGS",        structure = "One record per subject per lab test per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "LBSEQ")),
  vs     = list(class = "FINDINGS",        structure = "One record per subject per vital sign measurement per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "VSSEQ")),
  mh     = list(class = "EVENTS",          structure = "One record per subject per medical history event",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "MHSEQ")),
  pe     = list(class = "FINDINGS",        structure = "One record per subject per body system per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "PESEQ")),
  tu     = list(class = "FINDINGS",        structure = "One record per subject per lesion per visit (tumor identification)",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "TUSEQ")),
  tr     = list(class = "FINDINGS",        structure = "One record per subject per lesion per measurement per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "TRSEQ")),
  rs     = list(class = "FINDINGS",        structure = "One record per subject per assessment per visit",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "RSSEQ")),
  dd     = list(class = "EVENTS",          structure = "One record per subject per death detail",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "DDSEQ")),
  su     = list(class = "INTERVENTIONS",   structure = "One record per subject per substance use occurrence",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "SUSEQ")),
  suppdm = list(class = "RELATIONSHIP",    structure = "One record per subject per qualifier",
                purpose = "Tabulation",
                keys = c("STUDYID", "RDOMAIN", "USUBJID", "QNAM")),
  suppae = list(class = "RELATIONSHIP",    structure = "One record per parent record per qualifier",
                purpose = "Tabulation",
                keys = c("STUDYID", "RDOMAIN", "USUBJID", "IDVAR", "IDVARVAL", "QNAM")),
  suppcm = list(class = "RELATIONSHIP",    structure = "One record per parent record per qualifier",
                purpose = "Tabulation",
                keys = c("STUDYID", "RDOMAIN", "USUBJID", "IDVAR", "IDVARVAL", "QNAM")),
  supplb = list(class = "RELATIONSHIP",    structure = "One record per parent record per qualifier",
                purpose = "Tabulation",
                keys = c("STUDYID", "RDOMAIN", "USUBJID", "IDVAR", "IDVARVAL", "QNAM")),
  suppsu = list(class = "RELATIONSHIP",    structure = "One record per parent record per qualifier",
                purpose = "Tabulation",
                keys = c("STUDYID", "RDOMAIN", "USUBJID", "IDVAR", "IDVARVAL", "QNAM")),
  relrec = list(class = "RELATIONSHIP",    structure = "One record per related record",
                purpose = "Tabulation",
                keys = c("STUDYID", "USUBJID", "RDOMAIN", "RELID", "IDVAR", "IDVARVAL")),
  # ADaM
  adsl   = list(class = "SUBJECT LEVEL ANALYSIS DATASET",
                structure = "One record per subject",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID")),
  adae   = list(class = "OCCURRENCE DATA STRUCTURE",
                structure = "One record per subject per adverse event",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID", "AESEQ")),
  adlb   = list(class = "BASIC DATA STRUCTURE",
                structure = "One record per subject per parameter per analysis visit",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN")),
  adtr   = list(class = "BASIC DATA STRUCTURE",
                structure = "One record per subject per parameter per analysis visit",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN")),
  adrs   = list(class = "BASIC DATA STRUCTURE",
                structure = "One record per subject per parameter per analysis visit",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID", "PARAMCD", "AVISITN")),
  adtte  = list(class = "BASIC DATA STRUCTURE",
                structure = "One record per subject per time-to-event parameter",
                purpose = "Analysis",
                keys = c("STUDYID", "USUBJID", "PARAMCD"))
)

DOMAIN_LABEL <- c(
  dm = "Demographics", ds = "Disposition", ex = "Exposure",
  da = "Drug Accountability", ae = "Adverse Events",
  cm = "Concomitant Medications", lb = "Laboratory Test Results",
  vs = "Vital Signs", mh = "Medical History",
  pe = "Physical Examination", tu = "Tumor Identification",
  tr = "Tumor Results", rs = "Disease Response",
  dd = "Death Details", su = "Substance Use",
  suppdm = "Supplemental Qualifiers for DM",
  suppae = "Supplemental Qualifiers for AE",
  suppcm = "Supplemental Qualifiers for CM",
  supplb = "Supplemental Qualifiers for LB",
  suppsu = "Supplemental Qualifiers for SU",
  relrec = "Related Records",
  adsl  = "Subject-Level Analysis Dataset",
  adae  = "Adverse Events Analysis Dataset",
  adlb  = "Laboratory Analysis Dataset",
  adtr  = "Tumor Results Analysis Dataset",
  adrs  = "Disease Response Analysis Dataset",
  adtte = "Time-to-Event Analysis Dataset"
)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
infer_datatype <- function(x) {
  if (inherits(x, "Date") || inherits(x, "POSIXt")) return("date")
  if (is.integer(x)) return("integer")
  if (is.numeric(x)) return("float")
  if (is.logical(x)) return("text")
  cls <- class(x)[1]
  # Date-like character columns (--DTC, --STDTC, --ENDTC)
  if (is.character(x)) {
    smp <- na.omit(x)[1:min(50, length(na.omit(x)))]
    if (length(smp) > 0 && all(grepl("^\\d{4}-\\d{2}-\\d{2}", smp))) return("date")
    return("text")
  }
  "text"
}

infer_length <- function(x, dt) {
  if (dt %in% c("integer", "float")) {
    rng <- suppressWarnings(range(x, na.rm = TRUE))
    if (any(!is.finite(rng))) return(8L)
    return(8L)  # SAS numeric is 8 bytes
  }
  if (dt == "date") return(10L)  # ISO 8601 YYYY-MM-DD
  vals <- as.character(x)
  vals <- vals[!is.na(vals) & vals != ""]
  if (!length(vals)) return(1L)
  max(nchar(vals), 1L)
}

# Origin heuristic: returns one of Collected / Assigned / Derived / Protocol
infer_origin <- function(varname, domain_key) {
  v <- toupper(varname)
  if (v %in% c("STUDYID", "DOMAIN", "RDOMAIN")) return("Assigned")
  if (grepl("SEQ$", v)) return("Derived")
  if (grepl("FL$", v)) return("Derived")
  if (v %in% c("USUBJID", "SUBJID", "SITEID")) return("Assigned")
  if (grepl("^(ARM|ACTARM|ARMCD|ACTARMCD)$", v)) return("Assigned")
  if (grepl("DTC$|DY$|DT$", v)) return("Collected")
  if (grepl("^(VISIT|VISITNUM|EPOCH)$", v)) return("Assigned")
  if (grepl("^(QNAM|QLABEL|QVAL|QORIG|QEVAL|IDVAR|IDVARVAL|RELTYPE|RELID)$", v)) return("Derived")
  if (grepl("DECOD$|BODSYS$|SOC$|HLT$|LLT$|ATC$", v)) return("Assigned")
  # ADaM analysis vars: AVAL, AVALC, CHG, PCHG, BASE, PARAMCD, PARAM, TRT*, ANL*
  if (grepl("^(AVAL|AVALC|CHG|PCHG|BASE|BASEC|PARAM|PARAMCD|PARAMN|PARAMTYP|TRT|ANL|ASTDT|AENDT|ADT|ADTM|ATPT|ATPTN|AVISIT|AVISITN)", v)) return("Derived")
  if (grepl("^A[A-Z]+$", v)) return("Derived")  # other ADaM vars
  "Collected"
}

esc <- function(x) {
  if (is.null(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;",  x, fixed = TRUE)
  x <- gsub(">", "&gt;",  x, fixed = TRUE)
  x <- gsub("\"", "&quot;", x, fixed = TRUE)
  x
}

# -----------------------------------------------------------------------------
# Read all datasets and assemble metadata
# -----------------------------------------------------------------------------
read_meta <- function(dir, ds_keys) {
  files <- list.files(dir, pattern = "\\.parquet$", full.names = TRUE)
  out <- list()
  for (f in files) {
    key <- sub("\\.parquet$", "", basename(f))
    df  <- as.data.frame(read_parquet(f))
    lbl <- var_label(df)
    meta_d <- DOMAIN_META[[key]]
    keys <- if (!is.null(meta_d)) meta_d$keys else c("STUDYID", "USUBJID")
    vars <- lapply(names(df), function(v) {
      x   <- df[[v]]
      dt  <- infer_datatype(x)
      list(
        name      = v,
        label     = if (!is.null(lbl[[v]])) lbl[[v]] else v,
        datatype  = dt,
        length    = as.integer(infer_length(x, dt)),
        origin    = infer_origin(v, key),
        mandatory = if (v %in% keys) "Yes" else "No",
        keyseq    = if (v %in% keys) match(v, keys) else NA_integer_
      )
    })
    out[[key]] <- list(
      domain    = key,
      records   = nrow(df),
      class     = if (!is.null(meta_d)) meta_d$class else "RELATIONSHIP",
      structure = if (!is.null(meta_d)) meta_d$structure else "—",
      purpose   = if (!is.null(meta_d)) meta_d$purpose else "Tabulation",
      label     = ifelse(!is.na(DOMAIN_LABEL[key]), DOMAIN_LABEL[key], key),
      vars      = vars,
      filename  = paste0(key, ".xpt")
    )
  }
  out
}

cat("Reading SDTM parquets ...\n")
sdtm <- read_meta(SDTM_DIR)
cat("Reading ADaM parquets ...\n")
adam <- read_meta(ADAM_DIR)
all_ds <- c(sdtm, adam)

# -----------------------------------------------------------------------------
# Build Define-XML 2.1
# -----------------------------------------------------------------------------
xml_header <- '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="define2-1-0.xsl"?>'

study_oid <- paste0("STUDY.", STUDYID)
mdv_oid   <- "MDV.MSG-SDTM-3.4-ADAM-1.3"

# Build ItemGroupDef + ItemDef strings per dataset
build_dataset_xml <- function(ds) {
  dom_upper <- toupper(ds$domain)
  ig_oid    <- paste0("IG.", dom_upper)
  lf_oid    <- paste0("LF.", dom_upper)
  is_adam   <- ds$purpose == "Analysis"
  std_ref   <- if (is_adam) "STD.ADAM" else "STD.SDTM"

  itemrefs <- vapply(seq_along(ds$vars), function(i) {
    v <- ds$vars[[i]]
    keyseq_attr <- if (!is.na(v$keyseq)) sprintf(' KeySequence="%d"', v$keyseq) else ""
    sprintf(
      '        <ItemRef ItemOID="IT.%s.%s" OrderNumber="%d" Mandatory="%s"%s/>',
      dom_upper, v$name, i, v$mandatory, keyseq_attr
    )
  }, character(1))

  domain_attr <- if (dom_upper %in% c("DM","DS","EX","DA","AE","CM","LB","VS","MH","PE","TU","TR","RS","DD","SU")) {
    sprintf(' Domain="%s"', dom_upper)
  } else ""

  ig <- paste0(
    sprintf(
      '      <ItemGroupDef OID="%s" Name="%s" Repeating="%s" IsReferenceData="No" SASDatasetName="%s"%s Purpose="%s" def:Structure="%s" def:Class="%s" def:ArchiveLocationID="%s" def:StandardOID="%s">\n',
      ig_oid, dom_upper,
      ifelse(length(ds$vars) > 0 && any(grepl("SEQ$|PARAMCD|QNAM|RELID", sapply(ds$vars, `[[`, "name"))), "Yes", "No"),
      dom_upper, domain_attr, ds$purpose, esc(ds$structure), ds$class, lf_oid, std_ref
    ),
    sprintf('        <Description><TranslatedText xml:lang="en">%s</TranslatedText></Description>\n', esc(ds$label)),
    paste(itemrefs, collapse = "\n"),
    sprintf('\n        <def:leaf ID="%s" xlink:href="%s">\n', lf_oid, ds$filename),
    sprintf('          <def:title>%s</def:title>\n', ds$filename),
    '        </def:leaf>\n',
    '      </ItemGroupDef>'
  )
  ig
}

# ItemDefs are emitted once per (domain, variable). Some variables (STUDYID,
# USUBJID) appear in every dataset; per CDISC Define-XML practice each
# ItemGroupDef references a domain-scoped ItemOID.
build_itemdefs <- function(ds) {
  dom_upper <- toupper(ds$domain)
  ids <- vapply(ds$vars, function(v) {
    sprintf(
      paste0(
        '      <ItemDef OID="IT.%s.%s" Name="%s" SASFieldName="%s" DataType="%s" Length="%d">\n',
        '        <Description><TranslatedText xml:lang="en">%s</TranslatedText></Description>\n',
        '        <def:Origin Type="%s"/>\n',
        '      </ItemDef>'
      ),
      dom_upper, v$name, v$name, v$name, v$datatype, v$length,
      esc(v$label), v$origin
    )
  }, character(1))
  paste(ids, collapse = "\n")
}

igroup_blocks <- vapply(all_ds, build_dataset_xml, character(1))
itemdef_blocks <- vapply(all_ds, build_itemdefs, character(1))

odm <- paste0(
  xml_header, "\n",
  '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"\n',
  '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"\n',
  '     xmlns:xlink="http://www.w3.org/1999/xlink"\n',
  '     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n',
  '     ODMVersion="1.3.2"\n',
  '     FileType="Snapshot"\n',
  sprintf('     FileOID="%s.%s"\n', STUDYID, format(Sys.time(), "%Y%m%d%H%M%S")),
  sprintf('     CreationDateTime="%s"\n', NOW),
  sprintf('     AsOfDateTime="%s"\n', NOW),
  sprintf('     Originator="%s"\n', esc(ORIGINATOR)),
  '     def:Context="Submission">\n',
  sprintf('  <Study OID="%s">\n', study_oid),
  '    <GlobalVariables>\n',
  sprintf('      <StudyName>%s</StudyName>\n', esc(STUDYNAME)),
  sprintf('      <StudyDescription>%s</StudyDescription>\n', esc(STUDYDESC)),
  sprintf('      <ProtocolName>%s</ProtocolName>\n', esc(PROTOCOL)),
  '    </GlobalVariables>\n',
  sprintf('    <MetaDataVersion OID="%s" Name="MSG SDTM-IG 3.4 + ADaM-IG 1.3" Description="%s — Define-XML v2.1" def:DefineVersion="2.1.0">\n',
          mdv_oid, esc(STUDYNAME)),
  '      <def:Standards>\n',
  '        <def:Standard OID="STD.SDTM" Name="SDTMIG" Type="IG" PublishingSet="SDTM" Version="3.4" Status="Final"/>\n',
  '        <def:Standard OID="STD.ADAM" Name="ADaMIG" Type="IG" PublishingSet="ADaM" Version="1.3" Status="Final"/>\n',
  '        <def:Standard OID="STD.CT.SDTM" Name="CDISC/NCI" Type="CT" PublishingSet="SDTM" Version="2024-03-29" Status="Final"/>\n',
  '        <def:Standard OID="STD.CT.ADAM" Name="CDISC/NCI" Type="CT" PublishingSet="ADaM" Version="2024-03-29" Status="Final"/>\n',
  '      </def:Standards>\n',
  paste(igroup_blocks, collapse = "\n"), "\n",
  paste(itemdef_blocks, collapse = "\n"), "\n",
  '    </MetaDataVersion>\n',
  '  </Study>\n',
  '</ODM>\n'
)

writeLines(odm, file.path(OUT_DIR, "define.xml"), useBytes = TRUE)

# Validate well-formedness via xml2 parse round-trip
doc <- read_xml(file.path(OUT_DIR, "define.xml"))
ns <- c(odm = "http://www.cdisc.org/ns/odm/v1.3", def = "http://www.cdisc.org/ns/def/v2.1")
n_ig <- length(xml_find_all(doc, "//odm:ItemGroupDef", ns))
n_it <- length(xml_find_all(doc, "//odm:ItemDef",     ns))

# -----------------------------------------------------------------------------
# Human-readable summary
# -----------------------------------------------------------------------------
summary_lines <- c(
  "# Define-XML v2.1 — Inventory",
  "",
  sprintf("**Study:** %s (%s)", STUDYNAME, STUDYID),
  sprintf("**Generated:** %s", TODAY),
  sprintf("**File:** `define/define.xml`"),
  sprintf("**Datasets:** %d  ·  **Variables:** %d", n_ig, n_it),
  "",
  "## Datasets",
  "",
  "| Dataset | Class | Records | Variables | Structure |",
  "|---------|-------|--------:|----------:|-----------|"
)
for (k in names(all_ds)) {
  ds <- all_ds[[k]]
  summary_lines <- c(summary_lines, sprintf(
    "| %s | %s | %s | %d | %s |",
    toupper(k), ds$class, format(ds$records, big.mark = ","),
    length(ds$vars), ds$structure
  ))
}
summary_lines <- c(summary_lines, "",
  "## Standards",
  "",
  "- SDTMIG v3.4 (Final)",
  "- ADaMIG v1.3 (Final)",
  "- CDISC/NCI CT 2024-03-29 (SDTM + ADaM)",
  "",
  "## Known limitations (v0.1)",
  "",
  "- Codelist references stubbed; Value-Level Metadata not yet emitted.",
  "- MethodDefs limited to inferred origin tags (Collected / Assigned / Derived).",
  "- WhereClauseDefs not yet emitted (typical for ADTTE PARAMCD-based VLM).",
  "- ItemDef OIDs are domain-scoped (e.g. `IT.DM.STUDYID`); the SHARED ItemDef",
  "  pattern is deferred to a future iteration.",
  ""
)
writeLines(summary_lines, file.path(OUT_DIR, "DEFINE-SUMMARY.md"))

cat(sprintf("\nDefine-XML written: define/define.xml (%d datasets, %d variables)\n",
            n_ig, n_it))
cat("Summary written: define/DEFINE-SUMMARY.md\n")
