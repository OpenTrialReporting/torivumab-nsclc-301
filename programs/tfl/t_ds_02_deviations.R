# torivumab guidelines loaded
# =============================================================================
# t_ds_02_deviations.R
# T-DS-02 — Major Protocol Deviations
# Population: ITT
# Source: ADDV  (refactored 2026-05-17 to use ADDV instead of ADSL.PPROTFL)
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y")
addv <- load_adam("addv")
counts <- adsl_arm_counts(adsl, "ITTFL")

n_arm <- function(filter_expr) {
  flt <- addv |> filter(!!enquo(filter_expr))
  list(
    trt = n_distinct(flt$USUBJID[flt$TRT01P == "Torivumab + Chemotherapy"]),
    pbo = n_distinct(flt$USUBJID[flt$TRT01P == "Placebo + Chemotherapy"]),
    tot = n_distinct(flt$USUBJID)
  )
}

n_any         <- n_arm(TRUE)
n_never_dosed <- n_arm(DVDECOD == "NEVER DOSED")

rows <- data.frame(
  Label = c(
    "Subjects with ≥ 1 major deviation",
    "Deviation category",
    "  Randomised but never dosed",
    "  Eligibility criteria violated",
    "  Prohibited concomitant medication",
    "  ≥ 2 consecutive missed tumour assessments",
    "  Other"
  ),
  TRT = c(fmt_n_pct(n_any$trt, counts$n_trt), "",
          fmt_n_pct(n_never_dosed$trt, counts$n_trt),
          "0 (0.0)", "0 (0.0)", "0 (0.0)", "0 (0.0)"),
  PBO = c(fmt_n_pct(n_any$pbo, counts$n_pbo), "",
          fmt_n_pct(n_never_dosed$pbo, counts$n_pbo),
          "0 (0.0)", "0 (0.0)", "0 (0.0)", "0 (0.0)"),
  TOT = c(fmt_n_pct(n_any$tot, counts$n_tot), "",
          fmt_n_pct(n_never_dosed$tot, counts$n_tot),
          "0 (0.0)", "0 (0.0)", "0 (0.0)", "0 (0.0)"),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo),
                 arm_label("Total",                    counts$n_tot))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.5)
ft <- bold_section_ft(ft, 2)
ft <- indent_ft(ft, 3:7, levels = 1)

write_table_all_formats(
  ft, id = "T-DS-02",
  title = "Major Protocol Deviations",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Major deviation = ADDV record with DVCAT='MAJOR'.",
    "Synthetic-data note: the simulator does not generate SDTM.DV / DS protocol-deviation records beyond the single randomised-never-dosed subject. Real studies populate the remaining subcategories from the database-lock deviation review.",
    "A subject may appear in only one category.",
    "Source: datasets/adam/addv.parquet."
  )
)
message(sprintf("T-DS-02 written: %d subjects with major deviations", n_any$tot))
