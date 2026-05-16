# torivumab guidelines loaded
# =============================================================================
# Program    : suppae.R
# Dataset    : SUPPAE — Supplemental Qualifiers for AE
# SDTM IG ref: Section 8.4
# Reads from : datasets/sdtm/ae.parquet, raw/adverse_events.csv
# Writes to  : datasets/sdtm/suppae.parquet
# Notes      : Non-standard AE qualifiers required for ADAE flag derivation:
#                IRAEFL  — Immune-related AE flag (Y/N)
#                AEDISFL — AE led to study drug discontinuation (Y/N)
#                AEACTFL — Dose modified due to AE (Y/N) — collapses AEACN
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)
library(tidyr)

RAW_DIR  <- "raw"
SDTM_DIR <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

ae  <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ae.parquet")))
raw <- read.csv(file.path(RAW_DIR, "adverse_events.csv"), stringsAsFactors = FALSE) |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"))

map_yn <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("Y", "YES", "TRUE", "1") ~ "Y",
    x_up %in% c("N", "NO", "FALSE", "0") ~ "N",
    TRUE                                 ~ NA_character_
  )
}

# Re-derive flags per AE record. AE rows are ordered by (USUBJID, AESTDTC)
# in ae.R, so join raw back on the same key.
raw_with_flags <- raw |>
  arrange(USUBJID, AE_START_DATE) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  transmute(
    USUBJID,
    AESEQ,
    IRAEFL  = ifelse(str_to_upper(str_trim(AECAT)) == "IMMUNE-RELATED", "Y", "N"),
    AEDISFL = ifelse(map_yn(LEADING_TO_DISCONTINUATION) == "Y", "Y", "N"),
    AEACTFL = case_when(
      str_to_upper(str_trim(ACTION_TAKEN)) %in%
        c("DOSE REDUCED", "DOSE INTERRUPTED", "DRUG INTERRUPTED",
          "DRUG WITHDRAWN", "DOSE REDUCTION") ~ "Y",
      TRUE                                    ~ "N"
    )
  )

# Long-form SUPPAE
supp_long <- raw_with_flags |>
  pivot_longer(
    cols      = c(IRAEFL, AEDISFL, AEACTFL),
    names_to  = "QNAM",
    values_to = "QVAL"
  ) |>
  mutate(
    STUDYID  = STUDYID,
    RDOMAIN  = "AE",
    IDVAR    = "AESEQ",
    IDVARVAL = as.character(AESEQ),
    QLABEL   = case_when(
      QNAM == "IRAEFL"  ~ "Immune-Related AE Flag",
      QNAM == "AEDISFL" ~ "AE Led to Study Drug Discontinuation",
      QNAM == "AEACTFL" ~ "Dose Modified Due to AE"
    ),
    QORIG    = "DERIVED",
    QEVAL    = ""
  ) |>
  filter(!is.na(QVAL), QVAL != "") |>
  transmute(STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, QNAM, QLABEL, QVAL, QORIG, QEVAL) |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(supp_long, file.path(SDTM_DIR, "suppae.parquet"))
message("SUPPAE written: ", nrow(supp_long), " records (",
        n_distinct(supp_long$USUBJID), " subjects, ",
        n_distinct(supp_long$QNAM), " QNAMs)")
