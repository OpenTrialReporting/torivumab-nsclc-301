# torivumab guidelines loaded
# =============================================================================
# t_ae_01_overall.R
# T-AE-01 — Overall Summary of Adverse Events
# Population: Safety
# Source: ADAE + ADSL
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y")

counts <- list(
  n_trt = sum(adsl$TRT01A == "Torivumab + Chemotherapy"),
  n_pbo = sum(adsl$TRT01A == "Placebo + Chemotherapy"),
  n_tot = nrow(adsl)
)

# Helper: count distinct subjects per arm matching a filter
n_subj <- function(df, expr) {
  flt <- df |> filter(!!enquo(expr))
  list(
    trt = n_distinct(flt$USUBJID[flt$TRT01A == "Torivumab + Chemotherapy"]),
    pbo = n_distinct(flt$USUBJID[flt$TRT01A == "Placebo + Chemotherapy"]),
    tot = n_distinct(flt$USUBJID)
  )
}

n_any_ae  <- n_subj(adae, TRUE)
n_teae    <- n_subj(adae, TRTEMFL == "Y")
n_g3p     <- n_subj(adae, TRTEMFL == "Y" & AETOXGRN >= 3)
n_g5      <- n_subj(adae, TRTEMFL == "Y" & AETOXGRN == 5)
n_serious <- n_subj(adae, TRTEMFL == "Y" & AESER == "Y")
n_irae    <- n_subj(adae, TRTEMFL == "Y" & IRAEFL == "Y")
n_disc    <- n_subj(adae, TRTEMFL == "Y" & grepl("WITHDRAWN", AEACN))
n_dose_mod<- n_subj(adae, TRTEMFL == "Y" & grepl("REDUCED|INTERRUPTED", AEACN))

make_row <- function(label, n) data.frame(
  Label = label,
  TRT = fmt_n_pct(n$trt, counts$n_trt),
  PBO = fmt_n_pct(n$pbo, counts$n_pbo),
  TOT = fmt_n_pct(n$tot, counts$n_tot),
  stringsAsFactors = FALSE, check.names = FALSE
)

tbl <- rbind(
  make_row("Any AE",                                       n_any_ae),
  make_row("Any treatment-emergent AE (TEAE)",             n_teae),
  make_row("  Grade ≥ 3 TEAE",                              n_g3p),
  make_row("  Grade 5 (fatal) TEAE",                        n_g5),
  make_row("  Serious TEAE",                                n_serious),
  make_row("  Immune-related TEAE",                         n_irae),
  make_row("  TEAE leading to study drug discontinuation",  n_disc),
  make_row("  TEAE leading to dose modification",           n_dose_mod)
)
names(tbl) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.6)
ft <- indent_ft(ft, 3:8, levels = 1)

write_table_all_formats(
  ft, id = "T-AE-01",
  title = "Overall Summary of Adverse Events",
  population = pop_label(counts$n_tot, "SAFFL"),
  notes = c(
    "n (%) = number (percentage) of subjects in the arm with at least one event of the specified type. Multiple events per subject are counted once.",
    "TEAE = AE with onset ≥ TRTSDT and ≤ TRTEDT + 30 days.",
    "Immune-related: ADAE.IRAEFL = 'Y' (derived from SDTM.AE.AECAT = 'IMMUNE-RELATED').",
    "Source: datasets/adam/adae.parquet, adsl.parquet."
  )
)
message(sprintf("T-AE-01 written: TEAE TRT %d / PBO %d / Total %d",
                n_teae$trt, n_teae$pbo, n_teae$tot))
