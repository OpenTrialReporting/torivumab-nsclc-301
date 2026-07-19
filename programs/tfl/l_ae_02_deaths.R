# torivumab guidelines loaded
# =============================================================================
# l_ae_02_deaths.R
# L-AE-02 — Listing of Deaths
# Population: Safety
# Source: ADSL (DTHFL='Y') + SDTM.DD (cause)
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y", DTHFL == "Y")
dd   <- as.data.frame(read_parquet("datasets/sdtm/dd.parquet"))

lst <- adsl |>
  left_join(dd |> select(USUBJID, DDORRES), by = "USUBJID") |>
  mutate(
    days_post_trt = as.integer(as.Date(DTHDT) - as.Date(TRTEDT)),
    on_study      = ifelse(days_post_trt <= 30, "Yes", "No")
  ) |>
  arrange(SITEID, USUBJID) |>
  transmute(
    `Site`               = SITEID,
    `Subject ID`         = SUBJID,
    `Arm`                = TRT01A,
    `Age`                = AGE,
    `Sex`                = SEX,
    `First dose`         = as.character(TRTSDT),
    `Last dose`          = as.character(TRTEDT),
    `Death date`         = as.character(DTHDT),
    `Days post last dose` = days_post_trt,
    `Death ≤ 30d?`        = on_study,
    `Primary cause`      = DDORRES
  )

write_listing_all_formats(
  lst, id = "L-AE-02",
  title = "Listing of Deaths",
  population = sprintf("Safety Population — %d deaths", nrow(lst)),
  notes = c(
    "All deceased subjects with their primary cause from SDTM.DD.",
    "On-study death = within 30 days of last study treatment.",
    "Source: datasets/adam/adsl.parquet + datasets/sdtm/dd.parquet."
  )
)
message(sprintf("L-AE-02 written: %d deaths", nrow(lst)))
