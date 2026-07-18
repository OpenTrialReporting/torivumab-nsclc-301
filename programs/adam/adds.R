# torivumab guidelines loaded
# =============================================================================
# Program    : adds.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADDS — Subject Disposition Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §7
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/ds.parquet
# Output     : datasets/adam/adds.parquet
# Structure  : OCCDS — one record per disposition event per subject
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
source(file.path("programs", "adam", "_adam_utils.R"))  # study_day()
dir.create(ADAM_DIR, showWarnings = FALSE, recursive = TRUE)

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
ds   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ds.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL, PPROTFL, DTHFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

# Categorise each DS event
adds <- ds |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    ADT      = as.Date(DSSTDTC),
    ADY      = study_day(ADT, TRTSDT),
    DSCATGY  = case_when(
      DSCAT == "PROTOCOL MILESTONE" & DSDECOD == "INFORMED CONSENT OBTAINED" ~ "Consent",
      DSCAT == "PROTOCOL MILESTONE" & DSDECOD == "RANDOMIZED"                ~ "Randomisation",
      DSCAT == "DISPOSITION EVENT"  & DSDECOD == "COMPLETED"                 ~ "Completed",
      DSCAT == "DISPOSITION EVENT"                                            ~ "Discontinued",
      TRUE                                                                    ~ "Other"
    ),
    EOTFL    = if_else(DSCATGY %in% c("Completed", "Discontinued"), "Y", "N"),
    ANL01FL  = "Y"
  ) |>
  arrange(USUBJID, DSSEQ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, PPROTFL, DTHFL,
    TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    DSSEQ, DSTERM, DSDECOD, DSCAT, DSSCAT,
    DSCATGY, EOTFL,
    ADT, ADY, ANL01FL
  )

write_parquet(adds, file.path(ADAM_DIR, "adds.parquet"))
message("ADDS written: ", nrow(adds), " records (",
        n_distinct(adds$USUBJID), " subjects)")
message("  DSCATGY: ", paste(names(table(adds$DSCATGY)),
                              unname(table(adds$DSCATGY)),
                              sep="=", collapse=", "))
