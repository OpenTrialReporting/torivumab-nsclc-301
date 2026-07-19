# torivumab guidelines loaded
# =============================================================================
# Program    : advs.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADVS — Vital Signs Analysis Dataset
# Spec       : programs/adam/ADAM-MAPPING-SPEC.md §11
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/vs.parquet
# Output     : datasets/adam/advs.parquet
# Structure  : BDS — one record per subject per parameter per analysis visit
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

source(file.path("programs", "adam", "_visit_utils.R"))

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")

adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
vs   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "vs.parquet")))

adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

advs <- vs |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    PARAM    = VSTEST,
    PARAMCD  = VSTESTCD,
    PARAMN   = match(PARAMCD, sort(unique(PARAMCD))),
    ADT      = as.Date(VSDTC),
    ADY      = study_day(ADT, TRTSDT),
    AVAL     = VSSTRESN,
    AVALC    = VSSTRESC,
    AVALU    = VSSTRESU
  )

# Analysis-visit windowing (SAP §12.2): nearest scheduled visit by ADY
# (TREATMENT stream); EOT/follow-up kept by collected role.
.win <- derive_avisit_windowed(advs$ADY, advs$VISIT, advs$VISITNUM, "TREATMENT")
advs$AVISIT  <- .win$AVISIT
advs$AVISITN <- .win$AVISITN
advs$ATPTREF <- .win$ATPTREF

# Baseline flag: exactly ONE record per USUBJID/PARAMCD — the last non-missing
# pre-treatment measurement (P21 AD0154 — no multiple baselines). BASE is that
# record's AVAL, so ABLFL='Y' => AVAL == BASE (P21 AD0152).
advs <- advs |>
  group_by(USUBJID, PARAMCD) |>
  arrange(ADT, VSSEQ, .by_group = TRUE) |>
  mutate(
    .pre  = !is.na(AVAL) & ADT <= TRTSDT,
    ABLFL = if_else(.pre & cumsum(.pre) == sum(.pre) & sum(.pre) > 0L,
                    "Y", NA_character_)
  ) |>
  ungroup() |>
  select(-.pre)

baseline <- advs |>
  filter(ABLFL == "Y") |>
  select(USUBJID, PARAMCD, BASE = AVAL)

advs <- advs |>
  left_join(baseline, by = c("USUBJID", "PARAMCD")) |>
  mutate(
    CHG      = AVAL - BASE,
    PCHG     = if_else(!is.na(BASE) & BASE != 0, 100 * (AVAL - BASE) / BASE, NA_real_)
  )
# ANL01FL: one record per USUBJID x PARAMCD x AVISIT, closest to visit target
# (ties -> later ADT), so windowed records are not double-counted (SAP §12.2).
advs$ANL01FL <- flag_anl01(advs, "PARAMCD")
advs <- advs |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    VSSEQ,
    PARAM, PARAMCD, PARAMN,
    ADT, ADY, VISIT, VISITNUM, AVISIT, AVISITN,
    AVAL, AVALC, AVALU,
    BASE, CHG, PCHG, ABLFL,
    ANL01FL
  ) |>
  arrange(USUBJID, PARAMCD, AVISITN, ADT)

write_parquet(advs, file.path(ADAM_DIR, "advs.parquet"))
message("ADVS written: ", nrow(advs), " records (",
        n_distinct(advs$PARAMCD), " parameters)")
