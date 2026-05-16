# torivumab guidelines loaded
# =============================================================================
# Program    : adcm.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADCM — Concomitant Medications Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §10
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/cm.parquet,
#              datasets/sdtm/suppcm.parquet
# Output     : datasets/adam/adcm.parquet
# Structure  : OCCDS — one record per medication occurrence per subject
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")

adsl   <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
cm     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "cm.parquet")))
suppcm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "suppcm.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

# Pivot SUPPCM wide. SUPPCM carries CMATC (the SDTM-compliant home) but
# CM has CMATC inlined too — rename the SUPPCM copy to avoid a join
# collision, then coalesce after.
suppcm_wide <- suppcm |>
  mutate(IDVARVAL = as.integer(IDVARVAL)) |>
  select(USUBJID, CMSEQ = IDVARVAL, QNAM, QVAL) |>
  pivot_wider(names_from = QNAM, values_from = QVAL) |>
  rename(CMATC_SUPP = CMATC)

adcm <- cm |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  left_join(suppcm_wide, by = c("USUBJID", "CMSEQ")) |>
  mutate(CMATC = coalesce(CMATC, CMATC_SUPP)) |>
  select(-CMATC_SUPP) |>
  mutate(
    ASTDT     = as.Date(CMSTDTC),
    AENDT     = as.Date(CMENDTC),
    ASTDY     = as.integer(ASTDT - TRTSDT) + 1L,
    AENDY     = if_else(!is.na(AENDT), as.integer(AENDT - TRTSDT) + 1L, NA_integer_),
    # On-treatment flag: medication overlaps with TRTSDT..TRTEDT
    ONTRTFL   = if_else(
      !is.na(ASTDT) & !is.na(TRTSDT) &
        ASTDT <= TRTEDT &
        (is.na(AENDT) | AENDT >= TRTSDT),
      "Y", "N"),
    # Prior (started before treatment, ended before TRTSDT)
    PRIORFL   = if_else(
      !is.na(ASTDT) & !is.na(TRTSDT) &
        ASTDT < TRTSDT &
        (!is.na(AENDT) & AENDT < TRTSDT),
      "Y", "N"),
    # Concomitant (during treatment window)
    CONFL     = ONTRTFL,
    # irAE management indicator from SUPPCM
    CMIRAEFL  = if_else(is.na(CMIRAEFL), "N", CMIRAEFL),
    ANL01FL   = "Y",
    AVAL      = NA_real_  # OCCDS — no analysis value
  ) |>
  arrange(USUBJID, CMSEQ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    CMSEQ, CMTRT, CMDECOD, CMATC, CMINDC, CMROUTE,
    CMSTDTC, CMENDTC, ASTDT, AENDT, ASTDY, AENDY,
    PRIORFL, CONFL, ONTRTFL, CMIRAEFL,
    ANL01FL, AVAL
  )

write_parquet(adcm, file.path(ADAM_DIR, "adcm.parquet"))
message("ADCM written: ", nrow(adcm), " records")
message("  CONFL='Y':    ", sum(adcm$CONFL == "Y", na.rm=TRUE))
message("  PRIORFL='Y':  ", sum(adcm$PRIORFL == "Y", na.rm=TRUE))
message("  CMIRAEFL='Y': ", sum(adcm$CMIRAEFL == "Y", na.rm=TRUE))
