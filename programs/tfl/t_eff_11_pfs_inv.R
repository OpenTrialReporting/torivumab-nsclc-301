# torivumab guidelines loaded
# =============================================================================
# t_eff_11_pfs_inv.R
# T-EFF-11 — PFS by Investigator (Sensitivity)
# Source: ADTTE PARAMCD='PFSINV' (Investigator-assessed)
# Estimand: E2a (SAP §13.5 sensitivity)
# AL-04/AL-07 closure (2026-05-17): now uses real PFSINV (PD dates from
# SDTM.RS records with RSEVAL='INVESTIGATOR'), distinct from the BICR-based
# primary PFS used in T-EFF-03.
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adtte <- load_adam("adtte") |> filter(PARAMCD == "PFSINV")
counts <- adsl_arm_counts(adsl, "ITTFL")

dat <- adtte |>
  left_join(adsl |> select(USUBJID, HISTCAT, REGION), by = "USUBJID") |>
  mutate(AVAL_MO = AVAL / 30.4375,
         is_trt  = TRT01P == "Torivumab + Chemotherapy")

km_summary <- function(d) {
  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = d, conf.type = "log-log")
  s <- summary(fit)$table
  list(n = as.integer(s["records"]), events = as.integer(s["events"]),
       median = unname(s["median"]), lo = unname(s["0.95LCL"]),
       hi = unname(s["0.95UCL"]))
}
km_trt <- km_summary(dat |> filter(is_trt))
km_pbo <- km_summary(dat |> filter(!is_trt))

cox <- stratified_cox(dat)
p_lr <- stratified_logrank(dat)

rows <- data.frame(
  Label = c(
    "Number of subjects, N",
    "PFS events, n (%)",
    "Censored, n (%)",
    "Median PFS, months (95% CI)",
    "Hazard ratio (95% CI), stratified Cox PH",
    "p-value, stratified log-rank"
  ),
  TRT = c(
    sprintf("%d", km_trt$n),
    fmt_n_pct(km_trt$events, km_trt$n),
    fmt_n_pct(km_trt$n - km_trt$events, km_trt$n),
    fmt_med_ci(km_trt$median, km_trt$lo, km_trt$hi),
    fmt_hr_ci(cox$hr, cox$lo, cox$hi),
    fmt_p(p_lr)
  ),
  PBO = c(
    sprintf("%d", km_pbo$n),
    fmt_n_pct(km_pbo$events, km_pbo$n),
    fmt_n_pct(km_pbo$n - km_pbo$events, km_pbo$n),
    fmt_med_ci(km_pbo$median, km_pbo$lo, km_pbo$hi),
    "", ""
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.0)
ft <- bold(ft, i = 5:6, part = "body")

write_table_all_formats(
  ft, id = "T-EFF-11",
  title = "Progression-Free Survival by Investigator (Sensitivity)",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Sensitivity estimand E2a — assesses concordance of Investigator read with BICR primary.",
    "PFSINV PD dates derived from SDTM.RS records with RSEVAL='INVESTIGATOR'; primary PFS (T-EFF-03) uses RSEVAL='INDEPENDENT ASSESSOR' (BICR). BICR vs Investigator discordance is simulated at ~10%.",
    "Stratified Cox PH; stratification factors: histology × region.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='PFSINV'."
  )
)
message(sprintf("T-EFF-11 written: HR=%.3f", cox$hr))
