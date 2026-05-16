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
    ADY      = as.integer(ADT - TRTSDT) + 1L,
    AVISIT   = VISIT,
    AVISITN  = VISITNUM,
    AVAL     = VSSTRESN,
    AVALC    = VSSTRESC,
    AVALU    = VSSTRESU,
    ABLFL    = if_else(AVISIT %in% c("SCREENING", "SCR", "C1D1") &
                        ADT <= TRTSDT, "Y", NA_character_)
  )

# Baseline value per (USUBJID, PARAMCD) = last non-missing AVAL with ABLFL='Y'
baseline <- advs |>
  filter(ABLFL == "Y", !is.na(AVAL)) |>
  arrange(USUBJID, PARAMCD, ADT) |>
  group_by(USUBJID, PARAMCD) |>
  summarise(BASE = last(AVAL), .groups = "drop")

advs <- advs |>
  left_join(baseline, by = c("USUBJID", "PARAMCD")) |>
  mutate(
    CHG      = AVAL - BASE,
    PCHG     = if_else(!is.na(BASE) & BASE != 0, 100 * (AVAL - BASE) / BASE, NA_real_),
    ANL01FL  = "Y"
  ) |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    VSSEQ,
    PARAM, PARAMCD, PARAMN,
    ADT, ADY, AVISIT, AVISITN,
    AVAL, AVALC, AVALU,
    BASE, CHG, PCHG, ABLFL,
    ANL01FL
  ) |>
  arrange(USUBJID, PARAMCD, AVISITN, ADT)

write_parquet(advs, file.path(ADAM_DIR, "advs.parquet"))
message("ADVS written: ", nrow(advs), " records (",
        n_distinct(advs$PARAMCD), " parameters)")
