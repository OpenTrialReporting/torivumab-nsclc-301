# =============================================================================
# Program    : ex.R
# Domain     : EX — Exposure
# SDTM IG ref: Section 6.3
# Reads from : raw/exposure.csv
# Writes to  : datasets/sdtm/ex.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "exposure.csv"), stringsAsFactors = FALSE)

# VISITNUM lookup: derive from CYCLE_NUMBER and DAY_IN_CYCLE
# C1D1=1, C1D15=2, C2D1=3, C3D1=4, ...
derive_visitnum <- function(cycle, day) {
  cycle <- as.integer(cycle)
  day   <- as.integer(day)
  dplyr::case_when(
    cycle == 1  & day == 1  ~ 1L,
    cycle == 1  & day == 15 ~ 2L,
    cycle >= 2              ~ as.integer(cycle + 1L),
    TRUE                    ~ NA_integer_
  )
}

derive_visit <- function(cycle, day) {
  cycle <- as.integer(cycle)
  day   <- as.integer(day)
  dplyr::case_when(
    cycle == 1  & day == 1  ~ "C1D1",
    cycle == 1  & day == 15 ~ "C1D15",
    cycle >= 2              ~ paste0("C", cycle, "D", day),
    TRUE                    ~ NA_character_
  )
}

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    EXTRT    = str_to_upper(str_trim(DRUG_NAME)),
    EXDOSE   = as.numeric(DOSE_MG),
    EXDOSU   = str_to_upper(str_trim(DOSE_UNIT)),
    EXROUTE  = "INTRAVENOUS",
    EXSTDTC  = as.character(START_DATE),
    EXENDTC  = as.character(END_DATE),
    VISITNUM = derive_visitnum(CYCLE_NUMBER, DAY_IN_CYCLE),
    VISIT    = derive_visit(CYCLE_NUMBER, DAY_IN_CYCLE),
    # EPOCH: derive from cycle
    EPOCH    = case_when(
      as.integer(CYCLE_NUMBER) >= 1 ~ "TREATMENT",
      TRUE                          ~ "TREATMENT"
    )
  )

sdtm_ex <- raw |>
  arrange(USUBJID, EXSTDTC, EXTRT) |>
  group_by(USUBJID) |>
  mutate(EXSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN   = "EX",
    USUBJID,
    EXSEQ,
    EXTRT,
    EXDOSE,
    EXDOSU,
    EXROUTE,
    EXSTDTC,
    EXENDTC,
    VISITNUM,
    VISIT,
    EPOCH
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ex, file.path(OUT_DIR, "ex.parquet"))
message("EX written: ", nrow(sdtm_ex), " records")
