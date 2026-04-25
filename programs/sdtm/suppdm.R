# =============================================================================
# Program    : suppdm.R
# Domain     : SUPPDM — Supplemental Qualifiers for DM
# SDTM IG ref: Section 8.4
# Reads from : raw/demographics.csv
# Writes to  : datasets/sdtm/suppdm.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)
library(tidyr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "demographics.csv"), stringsAsFactors = FALSE)

raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-")
  )

# Define supplemental variables
supp_vars <- tribble(
  ~QNAM,      ~QLABEL,                               ~raw_col,
  "ECOGBSL",  "ECOG Performance Status at Baseline", "ECOG_BASELINE",
  "PDL1SCR",  "PD-L1 TPS Score",                    "PDL1_SCORE",
  "PDL1GRP",  "PD-L1 TPS Group",                    "PDL1_GROUP",
  "HISTSCAT", "Tumour Histology Stratum",            "HISTOLOGY"
)

# Build long SUPPQUAL records
supp_list <- lapply(seq_len(nrow(supp_vars)), function(i) {
  qnam   <- supp_vars$QNAM[i]
  qlabel <- supp_vars$QLABEL[i]
  col    <- supp_vars$raw_col[i]

  raw |>
    filter(!is.na(.data[[col]]) & str_trim(as.character(.data[[col]])) != "") |>
    transmute(
      STUDYID  = STUDYID,
      RDOMAIN  = "DM",
      USUBJID,
      IDVAR    = "",
      IDVARVAL = "",
      QNAM     = qnam,
      QLABEL   = qlabel,
      QVAL     = as.character(.data[[col]]),
      QORIG    = "CRF",
      QEVAL    = ""
    )
})

sdtm_suppdm <- bind_rows(supp_list) |>
  arrange(USUBJID, QNAM)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_suppdm, file.path(OUT_DIR, "suppdm.parquet"))
message("SUPPDM written: ", nrow(sdtm_suppdm), " records")
