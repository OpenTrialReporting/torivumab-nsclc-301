# torivumab guidelines loaded
# =============================================================================
# Program    : addv.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADDV — Protocol Deviations Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §8
# Depends on : datasets/adam/adsl.parquet
# Output     : datasets/adam/addv.parquet
# Structure  : OCCDS — one record per deviation per subject
# Note       : Synthetic data has no SDTM.DS deviation records and no DV
#              domain. ADDV is therefore derived from ADSL.PPROTFL = 'N'
#              with a single category ("Randomised but never dosed"). In a
#              real study ADDV would be populated from SDTM.DV.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

ADAM_DIR <- file.path("datasets", "adam")

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))

addv <- adsl |>
  filter(PPROTFL == "N") |>
  mutate(
    DVSEQ    = 1L,
    DVTERM   = if_else(is.na(TRTSDT),
                        "Randomised but never dosed",
                        "Other (not subcategorised in synthetic data)"),
    DVDECOD  = if_else(is.na(TRTSDT),
                        "NEVER DOSED",
                        "OTHER"),
    DVCAT    = "MAJOR",
    DVSCAT   = "STUDY-DRUG ELIGIBILITY",
    ADT      = if_else(!is.na(TRTSDT), as.Date(TRTSDT), as.Date(RANDDT)),
    ADY      = as.integer(ADT - RANDDT) + 1L,
    ANL01FL  = "Y"
  ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, PPROTFL, DTHFL,
    TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    DVSEQ, DVTERM, DVDECOD, DVCAT, DVSCAT,
    ADT, ADY, ANL01FL
  ) |>
  arrange(USUBJID)

write_parquet(addv, file.path(ADAM_DIR, "addv.parquet"))
message("ADDV written: ", nrow(addv), " records (",
        n_distinct(addv$USUBJID), " subjects)")
message("  Categories: ", paste(names(table(addv$DVTERM)),
                                  unname(table(addv$DVTERM)),
                                  sep="=", collapse=", "))
