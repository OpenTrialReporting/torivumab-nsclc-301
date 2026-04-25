# =============================================================================
# Program    : su.R
# Domain     : SU — Substance Use
# SDTM IG ref: Section 6.x
# Reads from : raw/substance_use.csv
# Writes to  : datasets/sdtm/su.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "substance_use.csv"), stringsAsFactors = FALSE)

# Map USE_STATUS to SUOCCUR (Y/N)
map_suoccur <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("CURRENT", "EVER", "YES", "Y", "FORMER", "PAST") ~ "Y",
    x_up %in% c("NEVER", "NO", "N")                              ~ "N",
    TRUE ~ NA_character_
  )
}

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    SUTRT    = str_to_upper(str_trim(SUBSTANCE)),
    SUOCCUR  = map_suoccur(USE_STATUS),
    SUCAT    = str_to_upper(str_trim(SUBSTANCE)),
    SUSCAT   = str_to_upper(str_trim(USE_STATUS)),
    # SUSTDTC: not directly available; leave as NA per spec
    SUSTDTC  = NA_character_,
    # SUPACKYRS: pack-years for tobacco
    SUPACKYRS = suppressWarnings(as.numeric(PACK_YEARS)),
    SUFREQ   = str_to_upper(str_trim(as.character(FREQUENCY)))
  ) |>
  arrange(USUBJID, SUCAT) |>
  group_by(USUBJID) |>
  mutate(SUSEQ = row_number()) |>
  ungroup()

sdtm_su <- raw |>
  transmute(
    STUDYID,
    DOMAIN    = "SU",
    USUBJID,
    SUSEQ,
    SUTRT,
    SUOCCUR,
    SUCAT,
    SUSCAT,
    SUSTDTC,
    SUPACKYRS,
    SUFREQ
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_su, file.path(OUT_DIR, "su.parquet"))
message("SU written: ", nrow(sdtm_su), " records")
