# =============================================================================
# Program    : label_adam.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Attach ADaMIG v1.3 variable labels to every ADaM parquet dataset.
#              The admiral derivation programs only preserve labels on columns
#              carried through from labelled SDTM inputs; newly derived analysis
#              variables were written without a `label` attribute (5 datasets
#              fully unlabelled — adex/adlb/adrs/adtr/adtte). This pass closes
#              that gap so every column is labelled (parity with SDTM).
#
#              Labels are sourced primarily from the programming specs
#              (programming-specs/AD*-spec.md — the authoritative 8-column
#              variable table), with a curated SUPPLEMENT for analysis variables
#              that are present in the data but not enumerated in a spec table
#              (e.g. ADY, TRT01PN, ICDT). Uses labelled::var_label(); arrow
#              serialises the attributes into the parquet R-metadata blob so any
#              reader using arrow::read_parquet() recovers them automatically.
#
# Reads from : datasets/adam/*.parquet  +  programming-specs/AD*-spec.md
# Writes to  : datasets/adam/*.parquet  (in-place, via atomic .tmp rename)
# Run after  : all ADaM derivation programs (00_run_adam.R sources this last)
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(labelled)
})

ADAM_DIR <- file.path("datasets", "adam")
SPEC_DIR <- "programming-specs"

# -----------------------------------------------------------------------------
# Spec parser — extract Variable -> Label from the numbered variable table
# ("| # | Variable | Label | Type | Length | Origin | Codelist | Derivation").
# Only integer-numbered rows are variable-table rows; other tables in the spec
# (Sources, Parameters) are not integer-numbered and are ignored.
# -----------------------------------------------------------------------------
parse_spec_labels <- function(spec_path) {
  if (!file.exists(spec_path)) return(list())
  lines <- readLines(spec_path, warn = FALSE)
  rows  <- grep("^\\|\\s*[0-9]+\\s*\\|", lines, value = TRUE)
  out <- list()
  for (r in rows) {
    cells <- trimws(strsplit(r, "\\|", perl = TRUE)[[1]])
    cells <- cells[cells != ""]
    if (length(cells) < 3) next
    var <- gsub("`|\\*", "", cells[2])
    lab <- trimws(gsub("`", "", cells[3]))
    if (grepl("^[A-Za-z][A-Za-z0-9]*$", var) && nzchar(lab) && lab != "—") {
      out[[var]] <- lab
    }
  }
  out
}

# -----------------------------------------------------------------------------
# SUPPLEMENT — standard ADaM / analysis labels for columns present in the data
# but not enumerated in a spec variable table (verified against programs/adam/).
# Spec labels take precedence; this only fills what the specs do not cover.
# -----------------------------------------------------------------------------
SUPPLEMENT <- list(
  # Identifiers / treatment (shared, ADaMIG standard)
  STUDYID  = "Study Identifier",
  USUBJID  = "Unique Subject Identifier",
  SUBJID   = "Subject Identifier for the Study",
  SITEID   = "Study Site Identifier",
  TRT01PN  = "Planned Treatment (N)",
  TRT01AN  = "Actual Treatment (N)",
  TRTDURD  = "Total Treatment Duration (Days)",
  # Timing (BDS analysis relative days + analysis visit)
  ADY      = "Analysis Relative Day",
  ASTDY    = "Analysis Start Relative Day",
  AENDY    = "Analysis End Relative Day",
  AVISIT   = "Analysis Visit",
  AVISITN  = "Analysis Visit (N)",
  VISIT    = "Visit Name",
  VISITNUM = "Visit Number",
  AVALU    = "Analysis Value Unit",
  # ADSL clinical characteristics
  ICDT     = "Date of Informed Consent",
  LSTALVDT = "Last Known Alive Date",
  ECOG     = "Baseline ECOG Performance Status",
  PDL1CAT  = "PD-L1 TPS Category",
  PDL1SCR  = "PD-L1 Tumor Proportion Score (%)",
  HISTCAT  = "Histology Category",
  # ADAE
  AETERM   = "Reported Term for the Adverse Event",
  AESOC    = "Primary System Organ Class",
  AESERFL  = "Serious Event Flag",
  # ADLB
  LBSEQ    = "Sequence Number",
  LBCAT    = "Category for Lab Test",
  NRIND    = "Reference Range Indicator",
  ATOXGRN  = "Analysis Toxicity Grade (N)",
  # ADTR
  LNKID    = "Link ID",
  N_TGT    = "Number of Target Lesions"
)

# -----------------------------------------------------------------------------
# STANDARD — ADaMIG v1.3 / CDISC-standard variable labels that MUST match the
# controlled label exactly (Pinnacle 21 AD0018). These override both spec and
# SUPPLEMENT for standard variables (the CDISC label is authoritative). All are
# <= 40 chars so they survive XPT v5 truncation unchanged.
# -----------------------------------------------------------------------------
STANDARD <- list(
  SUBJID   = "Subject Identifier for the Study",
  ITTFL    = "Intent-To-Treat Population Flag",
  TRT01P   = "Planned Treatment for Period 01",
  TRT01A   = "Actual Treatment for Period 01",
  TRT01PN  = "Planned Treatment for Period 01 (N)",
  TRT01AN  = "Actual Treatment for Period 01 (N)",
  TRTSDT   = "Date of First Exposure to Treatment",
  TRTEDT   = "Date of Last Exposure to Treatment",
  ASTDY    = "Analysis Start Relative Day",
  AENDY    = "Analysis End Relative Day",
  AVALC    = "Analysis Value (C)",
  PARAMN   = "Parameter (N)",
  BASE     = "Baseline Value",
  ONTRTFL  = "On-Treatment Record Flag",
  CMTRT    = "Reported Name of Drug, Med, or Therapy",
  AESTDTC  = "Start Date/Time of Adverse Event",
  AEENDTC  = "End Date/Time of Adverse Event",
  LSTALVDT = "Date Last Known Alive"
)

# -----------------------------------------------------------------------------
# Process each ADaM parquet
# -----------------------------------------------------------------------------
parquet_files <- sort(list.files(ADAM_DIR, pattern = "\\.parquet$", full.names = TRUE))

cat("\n=== ADaM Label Attachment (ADaMIG v1.3) ===\n")
cat(sprintf("  Data  : %s\n  Specs : %s\n\n", ADAM_DIR, SPEC_DIR))

gaps <- list()   # dataset -> columns left unlabelled (should be none)

for (path in parquet_files) {
  ds        <- sub("\\.parquet$", "", basename(path))
  spec_path <- file.path(SPEC_DIR, sprintf("%s-spec.md", toupper(ds)))

  df        <- as.data.frame(read_parquet(path))
  spec_map  <- parse_spec_labels(spec_path)

  # Resolve per column: STANDARD (CDISC-controlled) first, then spec, then
  # SUPPLEMENT. STANDARD wins so P21 AD0018 label checks pass for standard vars.
  label_map <- list()
  for (v in names(df)) {
    if (!is.null(STANDARD[[v]]))        label_map[[v]] <- STANDARD[[v]]
    else if (!is.null(spec_map[[v]]))   label_map[[v]] <- spec_map[[v]]
    else if (!is.null(SUPPLEMENT[[v]])) label_map[[v]] <- SUPPLEMENT[[v]]
  }

  applicable <- label_map[intersect(names(label_map), names(df))]
  var_label(df) <- applicable

  unlabelled <- setdiff(names(df), names(applicable))
  if (length(unlabelled) > 0) gaps[[ds]] <- unlabelled

  # Atomic write: temp file in same directory avoids cross-device rename errors
  tmp <- paste0(path, ".tmp")
  write_parquet(df, tmp)
  file.rename(tmp, path)

  cat(sprintf("  %-8s %3d / %3d vars labelled%s\n",
              ds, length(applicable), ncol(df),
              if (length(unlabelled)) sprintf("  [GAP: %s]",
                paste(unlabelled, collapse = ", ")) else ""))
}

# -----------------------------------------------------------------------------
# Round-trip verification (labels survive a read)
# -----------------------------------------------------------------------------
cat("\n  Round-trip check (adtte.parquet):\n")
adtte_lbls <- var_label(as.data.frame(read_parquet(file.path(ADAM_DIR, "adtte.parquet"))))
for (v in c("USUBJID", "PARAMCD", "AVAL", "CNSR", "ADT")) {
  if (!is.null(adtte_lbls[[v]])) cat(sprintf("    %-8s : %s\n", v, adtte_lbls[[v]]))
}

# -----------------------------------------------------------------------------
# Hard coverage gate — no ADaM column may ship unlabelled
# -----------------------------------------------------------------------------
if (length(gaps) > 0) {
  msg <- paste(vapply(names(gaps), function(d)
    sprintf("    %s: %s", d, paste(gaps[[d]], collapse = ", ")),
    character(1)), collapse = "\n")
  stop("Unlabelled ADaM columns remain — add to a spec table or SUPPLEMENT:\n", msg)
}

cat("\n=== ADaM label attachment complete — 100% coverage ===\n")
