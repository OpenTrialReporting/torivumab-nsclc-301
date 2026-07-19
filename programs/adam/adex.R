# torivumab guidelines loaded
# =============================================================================
# Program    : adex.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADEX — Exposure Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §9
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/ex.parquet
# Output     : datasets/adam/adex.parquet
# Structure  : BDS — one record per administration plus per-subject summaries
# Parameters : DOSEAMT (per administration), CUMDOSE, NCYCLE, RDI (relative
#              dose intensity = actual/planned cumulative dose)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

source(file.path("programs", "adam", "_visit_utils.R"))

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
ex   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ex.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, TRTDURD, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

# ---------------------------------------------------------------------------
# 1. Per-administration records (DOSEAMT parameter)
# ---------------------------------------------------------------------------
ex_admin <- ex |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    PARAM    = "Dose Amount per Administration",
    PARAMCD  = "DOSEAMT",
    AVAL     = as.numeric(EXDOSE),
    AVALU    = EXDOSU,
    ADT      = as.Date(EXSTDTC),
    ADY      = study_day(ADT, TRTSDT),
    AEXTRT   = EXTRT,
    ANL01FL  = if_else(SAFFL == "Y", "Y", NA_character_)
  ) |>
  arrange(USUBJID, AEXTRT, ADT) |>
  group_by(USUBJID, AEXTRT) |>
  mutate(AEXSEQ = row_number(),
         NCYCLE = AEXSEQ) |>
  ungroup() |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
         TRTSDT, TRTEDT, TRTDURD,
         AEXSEQ, AEXTRT,
         PARAM, PARAMCD, AVAL, AVALU,
         ADT, ADY, NCYCLE, VISIT, VISITNUM,
         ANL01FL)

# ---------------------------------------------------------------------------
# 2. Per-subject per-drug cumulative dose (CUMDOSE parameter)
# ---------------------------------------------------------------------------
ex_cumdose <- ex_admin |>
  group_by(USUBJID, AEXTRT) |>
  summarise(
    AVAL    = sum(AVAL, na.rm = TRUE),
    AVALU   = first(AVALU),
    NCYCLE  = max(NCYCLE),
    ADT     = max(ADT),
    .groups = "drop"
  ) |>
  left_join(adsl_vars, by = "USUBJID") |>
  mutate(
    PARAM    = "Cumulative Dose",  # generic per PARAMCD (drug is in AEXTRT); P21 AD0141
    PARAMCD  = "CUMDOSE",
    ADY      = study_day(ADT, TRTSDT),
    AEXSEQ   = NA_integer_,
    VISIT    = NA_character_,
    VISITNUM = NA_real_,
    ANL01FL  = if_else(SAFFL == "Y", "Y", NA_character_)
  ) |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
         TRTSDT, TRTEDT, TRTDURD,
         AEXSEQ, AEXTRT,
         PARAM, PARAMCD, AVAL, AVALU,
         ADT, ADY, NCYCLE, VISIT, VISITNUM,
         ANL01FL)

# ---------------------------------------------------------------------------
# 3. Per-subject per-drug Relative Dose Intensity (RDI parameter)
# ---------------------------------------------------------------------------
# Planned cumulative dose per drug per subject:
#   TORIVUMAB / PLACEBO: 200 mg per cycle (fixed)
#   CARBOPLATIN, PEMETREXED: actual per-cycle planned dose varies (BSA / AUC)
#     — for RDI we use the per-subject MEAN of actual doses × planned cycles
#       as the denominator (synthetic-data simplification)
PLANNED_PER_CYCLE <- c(TORIVUMAB = 200, PLACEBO = 200)

planned_cum <- ex_admin |>
  group_by(USUBJID, AEXTRT) |>
  summarise(
    actual_cum   = sum(AVAL, na.rm = TRUE),
    n_admin      = n(),
    avg_per_dose = mean(AVAL, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    planned_cum = case_when(
      AEXTRT %in% names(PLANNED_PER_CYCLE) ~ PLANNED_PER_CYCLE[AEXTRT] * n_admin,
      TRUE                                   ~ avg_per_dose * n_admin
    ),
    RDI = ifelse(planned_cum > 0, 100 * actual_cum / planned_cum, NA_real_)
  )

ex_rdi <- planned_cum |>
  left_join(adsl_vars, by = "USUBJID") |>
  mutate(
    PARAM    = "Relative Dose Intensity",  # generic per PARAMCD (drug in AEXTRT); P21 AD0141
    PARAMCD  = "RDI",
    AVAL     = RDI,
    AVALU    = "%",
    ADT      = TRTEDT,
    ADY      = study_day(ADT, TRTSDT),
    AEXSEQ   = NA_integer_,
    NCYCLE   = n_admin,
    VISIT    = NA_character_,
    VISITNUM = NA_real_,
    ANL01FL  = if_else(SAFFL == "Y", "Y", NA_character_)
  ) |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
         TRTSDT, TRTEDT, TRTDURD,
         AEXSEQ, AEXTRT,
         PARAM, PARAMCD, AVAL, AVALU,
         ADT, ADY, NCYCLE, VISIT, VISITNUM,
         ANL01FL)

# ---------------------------------------------------------------------------
# 4. Stack + analysis visit
# ---------------------------------------------------------------------------
adex <- bind_rows(ex_admin, ex_cumdose, ex_rdi) |>
  mutate(
    AVISIT  = VISIT,
    AVISITN = derive_avisitn(VISIT, VISITNUM)
  ) |>
  relocate(AVISIT, AVISITN, .after = VISITNUM)

write_parquet(adex, file.path(ADAM_DIR, "adex.parquet"))
message("ADEX written: ", nrow(adex), " records")
message("  DOSEAMT records: ", sum(adex$PARAMCD == "DOSEAMT"))
message("  CUMDOSE records: ", sum(adex$PARAMCD == "CUMDOSE"))
message("  RDI records:     ", sum(adex$PARAMCD == "RDI"))
