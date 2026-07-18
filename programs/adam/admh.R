# torivumab guidelines loaded
# =============================================================================
# Program    : admh.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADMH — Medical History Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §12
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/mh.parquet
# Output     : datasets/adam/admh.parquet
# Structure  : OCCDS — one record per medical history condition per subject
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
source(file.path("programs", "adam", "_adam_utils.R"))  # study_day()

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
mh   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "mh.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

admh <- mh |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    # MHSTDTC may be partial (year-only or year-month) — those parse to NA.
    # Per SAP §7, no imputation for descriptive MH summary.
    ASTDT      = as.Date(ifelse(nchar(MHSTDTC) == 10, MHSTDTC, NA_character_)),
    ASTDY      = if_else(!is.na(ASTDT) & !is.na(TRTSDT),
                          study_day(ASTDT, TRTSDT), NA_integer_),
    # PCANCERFL — primary cancer flag (NSCLC diagnosis)
    PCANCERFL  = if_else(MHCAT == "PRIMARY DIAGNOSIS", "Y", "N"),
    # ONGOFL — ongoing at study start
    ONGOFL     = if_else(MHENRTPT == "ONGOING", "Y", "N"),
    # PRIORFL — resolved before study (predates randomisation and has end date)
    PRIORFL    = if_else(MHENRTPT == "BEFORE", "Y", "N"),
    ANL01FL    = "Y"
  ) |>
  arrange(USUBJID, MHSEQ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    MHSEQ, MHTERM, MHDECOD, MHCAT,
    MHSTDTC, ASTDT, ASTDY,
    PCANCERFL, ONGOFL, PRIORFL,
    ANL01FL
  )

write_parquet(admh, file.path(ADAM_DIR, "admh.parquet"))
message("ADMH written: ", nrow(admh), " records (",
        n_distinct(admh$USUBJID), " subjects)")
message("  Primary cancer (PCANCERFL='Y'): ",
        n_distinct(admh$USUBJID[admh$PCANCERFL == "Y"]), " subjects")
message("  Ongoing at study start (ONGOFL='Y'): ",
        sum(admh$ONGOFL == "Y"), " records")
