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
    DDTESTCD = "DEATH",
    DDTEST   = "Death",
    DDORRES  = "Y",
    DDSTRESC = "Y",
    DDDTC    = as.character(DEATH_DATE),
    DDCAT    = "PRIMARY CAUSE OF DEATH",
    DDTERM   = str_to_upper(str_trim(PRIMARY_CAUSE)),
    DDSCAT   = ifelse(
      !is.na(CAUSE_DETAIL) & str_trim(as.character(CAUSE_DETAIL)) != "",
      str_to_upper(str_trim(CAUSE_DETAIL)),
      NA_character_
    )
  )

sdtm_dd <- raw |>
  arrange(USUBJID) |>
  transmute(
    STUDYID,
    DOMAIN   = "DD",
    USUBJID,
    DDSEQ,
    DDTESTCD,
    DDTEST,
    DDORRES,
    DDSTRESC,
    DDDTC,
    DDCAT,
    DDTERM,
    DDSCAT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_dd, file.path(OUT_DIR, "dd.parquet"))
message("DD written: ", nrow(sdtm_dd), " records")
