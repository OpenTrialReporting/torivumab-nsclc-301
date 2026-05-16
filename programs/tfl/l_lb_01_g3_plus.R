# torivumab guidelines loaded
# =============================================================================
# l_lb_01_g3_plus.R
# L-LB-01 — Listing of Grade ≥ 3 Laboratory Abnormalities
# Population: Safety
# Source: ADLB WHERE ATOXGRN >= 3
# =============================================================================

adlb <- load_adam("adlb") |>
  filter(SAFFL == "Y", !is.na(ATOXGRN), ATOXGRN >= 3)
# ADLB already carries SUBJID/SITEID/TRT01A from the ADSL merge in adlb.R,
# so no additional join needed.

lst <- adlb |>
  arrange(SITEID, USUBJID, PARAMCD, ADT) |>
  transmute(
    `Site`            = SITEID,
    `Subject ID`      = SUBJID,
    `Arm`             = TRT01A,
    `Parameter`       = PARAM,
    `Visit`           = VISIT,
    `Date`            = as.character(ADT),
    `Study day`       = ADY,
    `Value`           = AVAL,
    `Units`           = AVALU,
    `Range`           = sprintf("(%.2f, %.2f)", ANRLO, ANRHI),
    `CTCAE Grade`     = ATOXGR,
    `Range indicator` = NRIND,
    `Baseline value`  = BASE,
    `Change`          = CHG
  )

write_listing_all_formats(
  lst, id = "L-LB-01",
  title = "Listing of Grade ≥ 3 Laboratory Abnormalities",
  population = sprintf("Safety Population — %d records", nrow(lst)),
  notes = c(
    "All ADLB records with CTCAE Grade ≥ 3 (ATOXGRN ≥ 3).",
    "Sorted by Site, Subject, Parameter, Date.",
    "Source: datasets/adam/adlb.parquet WHERE ATOXGRN >= 3."
  )
)
message(sprintf("L-LB-01 written: %d records", nrow(lst)))
