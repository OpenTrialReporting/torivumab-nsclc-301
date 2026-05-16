# torivumab guidelines loaded
# =============================================================================
# l_ae_01_sae.R
# L-AE-01 — Listing of Serious Adverse Events
# Population: Safety
# Source: ADAE WHERE AESER='Y'
# =============================================================================

adae <- load_adam("adae") |> filter(SAFFL == "Y", AESER == "Y")

lst <- adae |>
  arrange(SITEID, USUBJID, AESEQ) |>
  transmute(
    `Site`              = SITEID,
    `Subject ID`        = SUBJID,
    `Arm`               = TRT01A,
    `AE Seq`            = AESEQ,
    `Verbatim term`     = AETERM,
    `Preferred term`    = AEDECOD,
    `SOC`               = AESOC,
    `CTCAE`             = AETOXGR,
    `Start date`        = as.character(ASTDT),
    `End date`          = as.character(AENDT),
    `Day of start`      = ASTDY,
    `Outcome`           = AEOUT,
    `Action taken`     = AEACN,
    `TEAE?`             = TRTEMFL,
    `irAE?`             = IRAEFL
  )

write_listing_all_formats(
  lst, id = "L-AE-01",
  title = "Listing of Serious Adverse Events",
  population = sprintf("Safety Population — %d SAE records", nrow(lst)),
  notes = c(
    "All records with AESER='Y' from ADAE.",
    "Sorted by Site, Subject, AE sequence.",
    "Source: datasets/adam/adae.parquet WHERE AESER='Y'."
  )
)
message(sprintf("L-AE-01 written: %d SAE records", nrow(lst)))
