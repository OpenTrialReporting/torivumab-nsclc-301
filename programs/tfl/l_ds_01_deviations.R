# torivumab guidelines loaded
# =============================================================================
# l_ds_01_deviations.R
# L-DS-01 — Listing of Major Protocol Deviations
# Source: ADSL WHERE PPROTFL='N'  (synthetic-data limitation noted)
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y", PPROTFL == "N")

lst <- adsl |>
  arrange(SITEID, USUBJID) |>
  transmute(
    `Site`               = SITEID,
    `Subject ID`         = SUBJID,
    `Arm (planned)`      = TRT01P,
    `Arm (actual)`       = TRT01A,
    `Informed consent`   = as.character(ICDT),
    `Randomisation`      = as.character(RANDDT),
    `First dose`         = ifelse(is.na(TRTSDT), "(never dosed)", as.character(TRTSDT)),
    `Last dose`          = ifelse(is.na(TRTEDT), "—",             as.character(TRTEDT)),
    `Deviation category` = ifelse(is.na(TRTSDT),
                                    "Randomised but never dosed",
                                    "(other — not subcategorised in synthetic data)"),
    `Death?`             = DTHFL,
    `Last known alive`   = as.character(LSTALVDT)
  )

write_listing_all_formats(
  lst, id = "L-DS-01",
  title = "Listing of Major Protocol Deviations",
  population = sprintf("ITT Population — %d subjects with PPROTFL='N'", nrow(lst)),
  notes = c(
    "All ITT subjects with ADSL.PPROTFL='N' (excluded from Per-Protocol population).",
    "SYNTHETIC-DATA NOTE: SDTM.DS in this dataset does not carry explicit DSCAT='PROTOCOL DEVIATION' records, so deviation subcategories beyond 'randomised but never dosed' cannot be programmatically populated. In a real study these would come from the database-lock deviation review.",
    "Source: datasets/adam/adsl.parquet WHERE PPROTFL='N'."
  )
)
message(sprintf("L-DS-01 written: %d subjects", nrow(lst)))
