# torivumab guidelines loaded
# =============================================================================
# Program    : dv.R
# Domain     : DV — Protocol Deviations
# SDTM IG ref: Section 6.3 (DV — Protocol Deviations)
# Reads from : raw/protocol_deviations.csv
# Writes to  : datasets/sdtm/dv.parquet
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)

RAW_DIR <- "raw"
OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

raw_path <- file.path(RAW_DIR, "protocol_deviations.csv")
if (!file.exists(raw_path)) {
  stop(
    "Cannot find raw/protocol_deviations.csv. ",
    "Run programs/raw/15_protocol_deviations.R first."
  )
}

raw <- read.csv(raw_path, stringsAsFactors = FALSE)

raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-")
  )

sdtm_dv <- raw |>
  arrange(USUBJID, DV_DATE) |>
  group_by(USUBJID) |>
  mutate(DVSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN   = "DV",
    USUBJID,
    DVSEQ,
    DVTERM   = str_trim(DV_TERM),
    DVDECOD  = str_to_upper(str_trim(DV_DECODE)),
    DVCAT    = str_to_upper(str_trim(DV_SEVERITY)),    # MAJOR / MINOR
    # DVSCAT dropped: it is functionally 1:1 with DVDECOD (P21 SD1040 redundant)
    DVSTDTC  = as.character(DV_DATE),
    EPOCH    = str_to_upper(str_trim(DV_EPOCH))
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_dv, file.path(OUT_DIR, "dv.parquet"))
message("DV written: ", nrow(sdtm_dv), " records (",
        n_distinct(sdtm_dv$USUBJID), " subjects, ",
        sum(sdtm_dv$DVCAT == "MAJOR"), " MAJOR / ",
        sum(sdtm_dv$DVCAT == "MINOR"), " MINOR)")
