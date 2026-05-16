# torivumab guidelines loaded
# =============================================================================
# t_ds_02_deviations.R
# T-DS-02 — Major Protocol Deviations
# Population: ITT
# Source: ADSL.PPROTFL  (SDTM.DS with DSCAT='PROTOCOL DEVIATION' not simulated)
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y")
counts <- adsl_arm_counts(adsl, "ITTFL")

# Single deviation category we can populate from this synthetic data:
# "Randomised but never dosed" → PPROTFL='N' & SAFFL='N'
n_never_dosed <- list(
  trt = sum(adsl$PPROTFL == "N" & adsl$SAFFL == "N" &
             adsl$TRT01P == "Torivumab + Chemotherapy"),
  pbo = sum(adsl$PPROTFL == "N" & adsl$SAFFL == "N" &
             adsl$TRT01P == "Placebo + Chemotherapy"),
  tot = sum(adsl$PPROTFL == "N" & adsl$SAFFL == "N")
)
n_total_dev <- list(
  trt = sum(adsl$PPROTFL == "N" & adsl$TRT01P == "Torivumab + Chemotherapy"),
  pbo = sum(adsl$PPROTFL == "N" & adsl$TRT01P == "Placebo + Chemotherapy"),
  tot = sum(adsl$PPROTFL == "N")
)

rows <- data.frame(
  Label = c(
    "Subjects with ≥ 1 major deviation (PPROTFL = N)",
    "Deviation category",
    "  Randomised but never dosed",
    "  Eligibility criteria violated",
    "  Prohibited concomitant medication",
    "  ≥ 2 consecutive missed tumour assessments",
    "  Other"
  ),
  TRT = c(
    fmt_n_pct(n_total_dev$trt,    counts$n_trt),
    "",
    fmt_n_pct(n_never_dosed$trt,  counts$n_trt),
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)"
  ),
  PBO = c(
    fmt_n_pct(n_total_dev$pbo,    counts$n_pbo),
    "",
    fmt_n_pct(n_never_dosed$pbo,  counts$n_pbo),
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)"
  ),
  TOT = c(
    fmt_n_pct(n_total_dev$tot,    counts$n_tot),
    "",
    fmt_n_pct(n_never_dosed$tot,  counts$n_tot),
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)",
    "0 (0.0)"
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.5)
ft <- bold_section_ft(ft, 2)
ft <- indent_ft(ft, 3:7, levels = 1)

write_table_all_formats(
  ft,
  id         = "T-DS-02",
  title      = "Major Protocol Deviations",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Major deviation = PPROTFL = N (ADSL).",
    "Subcategories beyond 'randomised but never dosed' are not populated in this synthetic dataset — the simulator does not generate SDTM.DS records with DSCAT='PROTOCOL DEVIATION'. In a real study these counts would come from a database-lock deviation review.",
    "A subject may appear in only one category (most serious deviation reported).",
    "Source: datasets/adam/adsl.parquet  (PPROTFL, SAFFL flags)"
  )
)
message(sprintf("T-DS-02 written: %d subjects with major deviations", n_total_dev$tot))
