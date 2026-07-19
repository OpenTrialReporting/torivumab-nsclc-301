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

# ---- Reference dates / death from companion CRFs -------------------------------
# DM carries the study reference and treatment window dates plus death, which are
# collected on the exposure / disposition / death forms (P21 SD0057 expects
# ARMCD, ACTARMCD, RFXSTDTC, RFXENDTC, RFENDTC, RFPENDTC, DTHDTC, DTHFL).
ex_ref <- read.csv(file.path(RAW_DIR, "exposure.csv"), stringsAsFactors = FALSE) |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
         sdt = suppressWarnings(as.Date(START_DATE)),
         edt = suppressWarnings(as.Date(END_DATE))) |>
  group_by(USUBJID) |>
  summarise(RFXSTDTC = as.character(min(sdt, na.rm = TRUE)),
            RFXENDTC = as.character(max(edt, na.rm = TRUE)), .groups = "drop")

disp_ref <- read.csv(file.path(RAW_DIR, "disposition.csv"), stringsAsFactors = FALSE) |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
         end_dt = pmax(suppressWarnings(as.Date(DISC_DATE)),
                       suppressWarnings(as.Date(LAST_CONTACT_DATE)),
                       suppressWarnings(as.Date(STUDY_COMPLETION_DATE)), na.rm = TRUE)) |>
  transmute(USUBJID, disp_end = as.character(end_dt))

death_ref <- read.csv(file.path(RAW_DIR, "death.csv"), stringsAsFactors = FALSE) |>
  transmute(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
            DTHDTC  = as.character(suppressWarnings(as.Date(DEATH_DATE))),
            DTHFL   = "Y")

# Derive USUBJID
# SUBJECT_ID is formatted as "SITE001-0001" — use it directly; extract
# the numeric suffix for SUBJID.
raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
    SUBJID  = sub(".*-", "", SUBJECT_ID),   # keep only the trailing numeric part
    SITEID  = as.character(SITE_ID)
  ) |>
  left_join(ex_ref,    by = "USUBJID") |>
  left_join(disp_ref,  by = "USUBJID") |>
  left_join(death_ref, by = "USUBJID")

# Derive AGE from BIRTHDATE and INFORM_CONSENT_DATE (reference date)
raw <- raw |>
  mutate(
    birth_dt    = suppressWarnings(as.Date(BIRTHDATE)),
    ref_dt      = suppressWarnings(as.Date(INFORM_CONSENT_DATE)),
    AGE         = as.integer(floor(as.numeric(difftime(ref_dt, birth_dt, units = "days")) / 365.25)),
    AGEU        = "YEARS",
    DMDTC       = as.character(INFORM_CONSENT_DATE),
    # Reference start = day 1 for study-day math. Use the earlier of randomization
    # and first dose so a dose given the day before randomization does not produce
    # negative exposure study days (P21 SD1135).
    RFSTDTC     = as.character(pmin(suppressWarnings(as.Date(RAND_DATE)),
                                    suppressWarnings(as.Date(RFXSTDTC)), na.rm = TRUE)),
    RFICDTC     = as.character(INFORM_CONSENT_DATE),
    # Subject reference / participation end: death if died, else last disposition
    # contact (P21 SD0057 RFENDTC/RFPENDTC).
    RFENDTC     = dplyr::coalesce(DTHDTC, disp_end),
    RFPENDTC    = dplyr::coalesce(disp_end, DTHDTC),
    # DTHFL is a "No Yes Response (Yes only)" variable — Y or null, never N
    # (P21 CT2001).
    DTHFL       = ifelse(is.na(DTHFL), NA_character_, DTHFL),
    ARM         = as.character(TREATMENT_ARM),
    ACTARM      = as.character(TREATMENT_ARM),
    # Planned/actual arm codes (must match TA.ARMCD) — P21 SD0057 ARMCD/ACTARMCD
    ARMCD       = dplyr::recode(as.character(TREATMENT_ARM),
                                "Torivumab + Chemotherapy" = "TORICHEMO",
                                "Placebo + Chemotherapy"   = "PBOCHEMO"),
    ACTARMCD    = ARMCD,
    # ARMNRS: reason not randomised (screen failures) — none in this dataset
    ARMNRS      = ifelse(as.character(SCREEN_FAIL) %in% c("Y", "1", "TRUE"),
                         "SCREEN FAILURE", NA_character_),
    # Blank ARM/ACTARM + codes for screen failures
    ARM         = ifelse(!is.na(ARMNRS), NA_character_, ARM),
    ACTARM      = ifelse(!is.na(ARMNRS), NA_character_, ACTARM),
    ARMCD       = ifelse(!is.na(ARMNRS), NA_character_, ARMCD),
    ACTARMCD    = ifelse(!is.na(ARMNRS), NA_character_, ACTARMCD),
    SEX         = dplyr::recode(str_to_upper(str_trim(SEX)),   # CDISC SEX codelist (P21 CT2001)
                                "MALE" = "M", "FEMALE" = "F", .default = "U"),
    RACE        = str_to_upper(str_trim(RACE)),
    ETHNIC      = str_to_upper(str_trim(ETHNIC)),
    COUNTRY     = dplyr::recode(str_to_upper(str_trim(COUNTRY)),  # ISO 3166-1 alpha-3 / GENC (P21 SD1322)
                    "AUSTRALIA" = "AUS", "BRAZIL" = "BRA", "CANADA" = "CAN",
                    "FRANCE" = "FRA", "GERMANY" = "DEU", "ITALY" = "ITA",
                    "JAPAN" = "JPN", "NETHERLANDS" = "NLD", "POLAND" = "POL",
                    "SOUTH KOREA" = "KOR", "SPAIN" = "ESP",
                    "UNITED KINGDOM" = "GBR", "UNITED STATES" = "USA"),
    DMBLFL      = "Y"
  )

sdtm_dm <- raw |>
  # SDTMIG v3.4 DM variable order (DMDY appended by 17_derive_timing.R)
  transmute(
    STUDYID  = STUDYID,
    DOMAIN   = "DM",
    USUBJID,
    SUBJID,
    RFSTDTC,
    RFENDTC,
    RFXSTDTC,
    RFXENDTC,
    RFICDTC,
    RFPENDTC,
    DTHDTC,
    DTHFL,
    SITEID,
    AGE,
    AGEU,
    SEX,
    RACE,
    ETHNIC,
    ARMCD,
    ARM,
    ACTARMCD,
    ACTARM,
    ARMNRS,
    COUNTRY,
    DMDTC
  ) |>
  arrange(USUBJID)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_dm, file.path(OUT_DIR, "dm.parquet"))
message("DM written: ", nrow(sdtm_dm), " records")
