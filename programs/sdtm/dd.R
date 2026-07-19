# =============================================================================
# Program    : dd.R
# Domain     : DD — Death Details
# SDTM IG ref: Section 6.x (Oncology Death Details)
# Reads from : raw/death.csv
# Writes to  : datasets/sdtm/dd.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "death.csv"), stringsAsFactors = FALSE)

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    DDSEQ    = 1L,
    DDTESTCD = "PRCDTH",                 # CDISC DD test code (P21 CT2002)
    DDTEST   = "Primary Cause of Death",
    # Result of the "Primary Cause of Death" test is the cause itself, carried in
    # the standard DDORRES/DDSTRESC (previously a "Y" flag with the cause in the
    # non-standard DDTERM, which was dropped — P21 SD0058).
    DDORRES  = str_to_upper(str_trim(PRIMARY_CAUSE)),
    DDSTRESC = str_to_upper(str_trim(PRIMARY_CAUSE)),
    DDDTC    = as.character(DEATH_DATE)
  )

sdtm_dd <- raw |>
  arrange(USUBJID) |>
  # DDCAT/DDSCAT (permissible, redundant "UNKNOWN" — SD1076/SD1040) and DDTERM
  # (not in DD model — SD0058) dropped; cause of death is carried in DDORRES.
  transmute(
    STUDYID,
    DOMAIN   = "DD",
    USUBJID,
    DDSEQ,
    DDTESTCD,
    DDTEST,
    DDORRES,
    DDSTRESC,
    DDDTC
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_dd, file.path(OUT_DIR, "dd.parquet"))
message("DD written: ", nrow(sdtm_dd), " records")
