# torivumab guidelines loaded
# =============================================================================
# l_ae_03_disc.R
# L-AE-03 — Listing of AEs Leading to Study Drug Discontinuation
# Population: Safety
# Source: ADAE WHERE AEACN contains 'WITHDRAWN'
# =============================================================================

adae <- load_adam("adae") |>
  filter(SAFFL == "Y", grepl("WITHDRAWN", AEACN))

lst <- adae |>
  arrange(SITEID, USUBJID, AESEQ) |>
  transmute(
    `Site`              = SITEID,
    `Subject ID`        = SUBJID,
    `Arm`               = TRT01A,
    `AE Seq`            = AESEQ,
    `Preferred term`    = AEDECOD,
    `SOC`               = AESOC,
    `CTCAE`             = AETOXGR,
    `Serious?`          = AESER,
    `irAE?`             = IRAEFL,
    `Onset date`        = as.character(ASTDT),
    `End date`          = as.character(AENDT),
    `Day of onset`      = ASTDY,
    `Outcome`           = AEOUT,
    `Action taken`     = AEACN
  )

write_listing_all_formats(
  lst, id = "L-AE-03",
  title = "Listing of Adverse Events Leading to Study Drug Discontinuation",
  population = sprintf("Safety Population — %d records", nrow(lst)),
  notes = c(
    "All AE records where AEACN contains 'WITHDRAWN' (i.e., study drug permanently discontinued).",
    "Source: datasets/adam/adae.parquet."
  )
)
message(sprintf("L-AE-03 written: %d AE records", nrow(lst)))
