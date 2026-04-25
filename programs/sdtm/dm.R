# =============================================================================
# Program    : dm.R
# Domain     : DM — Demographics
# SDTM IG ref: Section 5.1
# Reads from : raw/demographics.csv
# Writes to  : datasets/sdtm/dm.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "demographics.csv"), stringsAsFactors = FALSE)

# Derive USUBJID
# SUBJECT_ID is formatted as "SITE001-0001" — use it directly; extract
# the numeric suffix for SUBJID.
raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
    SUBJID  = sub(".*-", "", SUBJECT_ID),   # keep only the trailing numeric part
    SITEID  = as.character(SITE_ID)
  )

# Derive AGE from BIRTHDATE and INFORM_CONSENT_DATE (reference date)
raw <- raw |>
  mutate(
    birth_dt    = suppressWarnings(as.Date(BIRTHDATE)),
    ref_dt      = suppressWarnings(as.Date(INFORM_CONSENT_DATE)),
    AGE         = as.integer(floor(as.numeric(difftime(ref_dt, birth_dt, units = "days")) / 365.25)),
    AGEU        = "YEARS",
    DMDTC       = as.character(INFORM_CONSENT_DATE),
    RFSTDTC     = as.character(RAND_DATE),
    RFICDTC     = as.character(INFORM_CONSENT_DATE),
    ARM         = as.character(TREATMENT_ARM),
    ACTARM      = as.character(TREATMENT_ARM),
    # ARMNRS: reason not randomised (screen failures)
    ARMNRS      = ifelse(as.character(SCREEN_FAIL) %in% c("Y", "1", "TRUE"),
                         "SCREEN FAILURE", NA_character_),
    # Blank ARM/ACTARM for screen failures
    ARM         = ifelse(!is.na(ARMNRS), "SCREEN FAILURE", ARM),
    ACTARM      = ifelse(!is.na(ARMNRS), "SCREEN FAILURE", ACTARM),
    SEX         = str_to_upper(str_trim(SEX)),
    RACE        = str_to_upper(str_trim(RACE)),
    ETHNIC      = str_to_upper(str_trim(ETHNIC)),
    COUNTRY     = str_to_upper(str_trim(COUNTRY)),
    DMBLFL      = "Y"
  )

sdtm_dm <- raw |>
  transmute(
    STUDYID  = STUDYID,
    DOMAIN   = "DM",
    USUBJID,
    SUBJID,
    SITEID,
    AGE,
    AGEU,
    SEX,
    RACE,
    ETHNIC,
    COUNTRY,
    DMDTC,
    RFSTDTC,
    RFICDTC,
    ARM,
    ACTARM,
    ARMNRS
  ) |>
  arrange(USUBJID)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_dm, file.path(OUT_DIR, "dm.parquet"))
message("DM written: ", nrow(sdtm_dm), " records")
