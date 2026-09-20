# torivumab guidelines loaded
# =============================================================================
# t_eff_08_os_pp.R
# T-EFF-08 — Overall Survival in Per-Protocol Population (Sensitivity)
# Source: ADTTE PARAMCD='OS' filtered to PPROTFL='Y'
# Reference: SAP §11 sensitivity (PP vs ITT)
# =============================================================================

adsl  <- load_adam("adsl") |> filter(PPROTFL == "Y") |> add_region()
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS", USUBJID %in% adsl$USUBJID)
counts <- list(
  n_trt = sum(adsl$TRT01P == "Torivumab + Chemotherapy"),
  n_pbo = sum(adsl$TRT01P == "Placebo + Chemotherapy"),
  n_tot = nrow(adsl)
)

dat <- adtte |>
  left_join(adsl |> select(USUBJID, HISTCAT, REGION), by = "USUBJID") |>
  mutate(AVAL_MO = AVAL / 30.4375,
         is_trt  = TRT01P == "Torivumab + Chemotherapy")

km_summary <- function(d) {
  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = d, conf.type = "log-log")
  s <- summary(fit)$table
  list(n = as.integer(s["records"]), events = as.integer(s["events"]),
       median = unname(s["median"]), lo = unname(s["0.95LCL"]), hi = unname(s["0.95UCL"]))
}
km_trt <- km_summary(dat |> filter(is_trt))
km_pbo <- km_summary(dat |> filter(!is_trt))

cox <- stratified_cox(dat)
p_lr <- stratified_logrank(dat)

rows <- data.frame(
  Label = c(
    "Number of subjects (PP), N",
    "Events (deaths), n (%)",
    "Censored, n (%)",
    "Median OS, months (95% CI)",
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
  ft, id = "T-EFF-08",
  title = "Overall Survival in Per-Protocol Population (Sensitivity)",
  population = sprintf("Per-Protocol Population (N=%d)", counts$n_tot),
  notes = c(
    "Sensitivity analysis re-running the primary OS analysis on subjects with PPROTFL='Y' (no major protocol deviations).",
    "Stratified Cox PH; stratification factors: histology × region.",
    "Reference: SAP §11 (ITT vs PP sensitivity).",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OS', filtered ADSL.PPROTFL='Y'."
  )
)
message(sprintf("T-EFF-08 written: PP HR=%.3f", cox$hr))
