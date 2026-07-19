# torivumab guidelines loaded
# =============================================================================
# Program    : addv.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADDV — Protocol Deviations Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §8
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/dv.parquet
# Output     : datasets/adam/addv.parquet
# Structure  : OCCDS — one record per deviation per subject
# Updated    : 2026-05-17 — now sources SDTM.DV (was ADSL.PPROTFL only)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
source(file.path("programs", "adam", "_adam_utils.R"))  # study_day()

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
dv   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dv.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL, PPROTFL, DTHFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN, RANDDT)

addv <- dv |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    ADT     = as.Date(DVSTDTC),
    ADY     = study_day(ADT, RANDDT),
    DVSEV   = DVCAT,   # MAJOR / MINOR
    # ANL01FL (SAP §12.2): records in this dataset's analysis population.
    # Protocol deviations are summarised on all randomised subjects.
    ANL01FL = if_else(ITTFL == "Y", "Y", NA_character_)
  ) |>
  arrange(USUBJID, DVSEQ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, PPROTFL, DTHFL,
    TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    DVSEQ, DVTERM, DVDECOD, DVCAT, DVSEV,
    DVSTDTC, ADT, ADY,
    ANL01FL
  )

write_parquet(addv, file.path(ADAM_DIR, "addv.parquet"))
message("ADDV written: ", nrow(addv), " records (",
        n_distinct(addv$USUBJID), " subjects, ",
        sum(addv$DVSEV == "MAJOR"), " MAJOR / ",
        sum(addv$DVSEV == "MINOR"), " MINOR)")
