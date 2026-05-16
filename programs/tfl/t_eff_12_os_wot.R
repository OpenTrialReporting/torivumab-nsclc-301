# torivumab guidelines loaded
# =============================================================================
# t_eff_12_os_wot.R
# T-EFF-12 — OS While-on-Treatment (Sensitivity)
# Source: ADTTE PARAMCD='OSWOT'
# Estimand: E1b (SAP §13.4 sensitivity)
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adtte <- load_adam("adtte") |> filter(PARAMCD == "OSWOT")
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

# Event-type breakdown for clarity
evnt_breakdown <- function(d) {
  list(
    on_tx    = sum(d$EVNTDESC == "DEATH ON/WITHIN 30D OF LAST DOSE",  na.rm = TRUE),
    lost     = sum(d$EVNTDESC == "CENSORED - LOST BEFORE TRTEDT+30D", na.rm = TRUE),
    alive    = sum(d$EVNTDESC == "CENSORED - ALIVE AT TRTEDT+30D",    na.rm = TRUE)
  )
}
ev_trt <- evnt_breakdown(dat |> filter(is_trt))
ev_pbo <- evnt_breakdown(dat |> filter(!is_trt))

rows <- data.frame(
  Label = c(
    "Number of subjects (ITT), N",
    "Events (deaths on/within 30d of last dose), n (%)",
    "Censored — alive at TRTEDT + 30d, n (%)",
    "Censored — lost before TRTEDT + 30d, n (%)",
    "Median OS-WOT, months (95% CI)",
    "Hazard ratio (95% CI), stratified Cox PH",
    "p-value, stratified log-rank"
  ),
  TRT = c(
    sprintf("%d", km_trt$n),
    fmt_n_pct(ev_trt$on_tx, km_trt$n),
    fmt_n_pct(ev_trt$alive, km_trt$n),
    fmt_n_pct(ev_trt$lost,  km_trt$n),
    fmt_med_ci(km_trt$median, km_trt$lo, km_trt$hi),
    fmt_hr_ci(cox$hr, cox$lo, cox$hi),
    fmt_p(p_lr)
  ),
  PBO = c(
    sprintf("%d", km_pbo$n),
    fmt_n_pct(ev_pbo$on_tx, km_pbo$n),
    fmt_n_pct(ev_pbo$alive, km_pbo$n),
    fmt_n_pct(ev_pbo$lost,  km_pbo$n),
    fmt_med_ci(km_pbo$median, km_pbo$lo, km_pbo$hi),
    "", ""
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)
ft <- bold(ft, i = 6:7, part = "body")

write_table_all_formats(
  ft, id = "T-EFF-12",
  title = "Overall Survival — While-on-Treatment Sensitivity",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Estimand E1b (SAP §13.4) — isolates the treatment-period effect from late off-treatment dilution.",
    "Event = death on or within 30 days of last study treatment (TRTEDT + 30 days).",
    "Censor = min(TRTEDT + 30 days, LSTALVDT).",
    "SYNTHETIC-DATA NOTE: SAP §13.4 also specifies censoring at start of subsequent anti-cancer therapy; that variable is not simulated in this dataset, so only the TRTEDT + 30d component is applied.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OSWOT'."
  )
)
message(sprintf("T-EFF-12 written: HR=%.3f", cox$hr))
