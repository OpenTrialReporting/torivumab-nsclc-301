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
source(file.path("programs", "adam", "_adam_utils.R"))  # study_day()

adsl   <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
cm     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "cm.parquet")))
suppcm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "suppcm.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

# Pivot SUPPCM wide. SUPPCM carries CMATC (the SDTM-compliant home) but CM has
# CMATC denormalised too — rename the SUPPCM copy to avoid a join collision, then
# coalesce after.
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
    ASTDY     = study_day(ASTDT, TRTSDT),
    AENDY     = study_day(AENDT, TRTSDT),
    # On-treatment flag: medication overlaps with TRTSDT..TRTEDT
    ONTRTFL   = if_else(
      !is.na(ASTDT) & !is.na(TRTSDT) &
        ASTDT <= TRTEDT &
        (is.na(AENDT) | AENDT >= TRTSDT),
      "Y", NA_character_),        # Y-only flag: Y or null, never "N" (P21 AD0269)
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
    # Subsequent anti-cancer therapy flag — closes AL-02 (2026-05-17).
    # CMINDC text-match against raw seed value from 16_subsequent_therapy.R.
    SUBSQTFL  = if_else(
      !is.na(CMINDC) &
        toupper(CMINDC) %in% c("SUBSEQUENT ANTI-CANCER THERAPY",
                                 "ANTINEOPLASTIC AGENTS"),
      "Y", "N"),
    ANL01FL   = "Y"      # AVAL prohibited in OCCDS (P21 AD0252)
  ) |>
  arrange(USUBJID, CMSEQ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    CMSEQ, CMTRT, CMDECOD, CMATC, CMINDC, CMROUTE,
    CMSTDTC, CMENDTC, ASTDT, AENDT, ASTDY, AENDY,
    PRIORFL, CONFL, ONTRTFL, CMIRAEFL, SUBSQTFL,
    ANL01FL
  )

write_parquet(adcm, file.path(ADAM_DIR, "adcm.parquet"))
message("ADCM written: ", nrow(adcm), " records")
message("  CONFL='Y':    ", sum(adcm$CONFL == "Y", na.rm=TRUE))
message("  PRIORFL='Y':  ", sum(adcm$PRIORFL == "Y", na.rm=TRUE))
message("  CMIRAEFL='Y': ", sum(adcm$CMIRAEFL == "Y", na.rm=TRUE))
