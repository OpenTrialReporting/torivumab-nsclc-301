# =============================================================================
# Program    : adae.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADAE — Adverse Event Analysis Dataset
# Spec       : programming-specs/ADAE-spec.md
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/ae.parquet
# Output     : datasets/adam/adae.parquet
# Run via    : programs/adam/00_run_adam.R (after adsl.R)
# =============================================================================

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr)
  library(lubridate)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
dir.create(ADAM_DIR, showWarnings = FALSE, recursive = TRUE)

# 1. Read inputs
adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
ae   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ae.parquet")))

# 2. Merge ADSL onto AE
adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, TRTDURD, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

adae <- ae |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID"))

# 3. Convert AE dates
adae <- adae |>
  mutate(
    ASTDT = as.Date(AESTDTC),
    AENDT = as.Date(AEENDTC)
  )

# 4. Study day of AE onset
adae <- adae |>
  mutate(
    ASTDY = as.integer(ASTDT - TRTSDT) + 1L,
    AENDY = if_else(!is.na(AENDT), as.integer(AENDT - TRTSDT) + 1L, NA_integer_)
  )

# 5. Treatment-emergent flag (TRTEMFL)
adae <- adae |>
  mutate(
    TRTEMFL = if_else(
      !is.na(ASTDT) & !is.na(TRTSDT) &
        ASTDT >= TRTSDT &
        ASTDT <= (TRTEDT + days(30)),
      "Y", "N"
    )
  )

# 6. irAE flag (IRAEFL)
adae <- adae |>
  mutate(
    IRAEFL = if_else(
      !is.na(AECAT) & toupper(trimws(AECAT)) == "IMMUNE-RELATED",
      "Y", "N", missing = "N"
    )
  )

# 7. CTCAE grade — backfill from AESEV if AETOXGR absent in ae.parquet
if (!"AETOXGR" %in% names(adae)) {
  adae <- adae |>
    mutate(AETOXGR = case_when(
      AESEV == "MILD"             ~ "1",
      AESEV == "MODERATE"         ~ "2",
      AESEV == "SEVERE"           ~ "3",
      AESEV == "LIFE-THREATENING" ~ "4",
      AESEV == "FATAL"            ~ "5",
      TRUE                        ~ NA_character_
    ))
}
if (!"AESOC" %in% names(adae)) {
  adae <- adae |> mutate(AESOC = AEBODSYS)
}

adae <- adae |>
  mutate(
    AETOXGRN = suppressWarnings(as.integer(AETOXGR)),
    AESERFL  = if_else(AESER == "Y", "Y", "N", missing = "N")
  )

# 8. Analysis flag and value
adae <- adae |>
  mutate(
    ANL01FL = if_else(TRTEMFL == "Y" & SAFFL == "Y", "Y", NA_character_),
    AVAL    = AETOXGRN
  )

# 9. Select final variables
adae <- adae |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT, TRTDURD,
    AESEQ,
    AETERM, AEDECOD, AEBODSYS, AEHLT, AELLT, AESOC,
    AECAT,
    AESTDTC, AEENDTC, ASTDT, AENDT, ASTDY, AENDY,
    AESEV, AETOXGR, AETOXGRN,
    AESER, AESERFL, AEREL, AEACN, AEOUT,
    AESDTH, AESHOSP, AESLIFE, AESDISAB, AESMIE, AESCONG,
    TRTEMFL, IRAEFL, ANL01FL, AVAL
  ) |>
  arrange(USUBJID, AESEQ)

# 10. Write output
write_parquet(adae, file.path(ADAM_DIR, "adae.parquet"))
message("ADAE written: ", nrow(adae), " records")
message("  TRTEMFL=Y: ", sum(adae$TRTEMFL == "Y", na.rm = TRUE))
message("  IRAEFL=Y:  ", sum(adae$IRAEFL  == "Y", na.rm = TRUE))
message("  AESER=Y:   ", sum(adae$AESER   == "Y", na.rm = TRUE))
