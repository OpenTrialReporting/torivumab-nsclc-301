# torivumab guidelines loaded
# =============================================================================
# t_eff_07_dor.R
# T-EFF-07 — Duration of Response (descriptive, responders only)
# Population: Confirmed responders (subset of Response Evaluable)
# Source: ADTTE PARAMCD='DOR'
# Estimand: E4
# =============================================================================

adtte <- load_adam("adtte") |> filter(PARAMCD == "DOR")
dat <- adtte |> mutate(AVAL_MO = AVAL / 30.4375,
                       is_trt  = TRT01P == "Torivumab + Chemotherapy")

km_summary <- function(d) {
  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = d, conf.type = "log-log")
  s   <- summary(fit)$table
  list(
    n      = as.integer(s["records"]),
    events = as.integer(s["events"]),
    median = unname(s["median"]),
    lo     = unname(s["0.95LCL"]),
    hi     = unname(s["0.95UCL"])
  )
}

km_trt <- km_summary(dat |> filter(is_trt))
km_pbo <- km_summary(dat |> filter(!is_trt))

# Landmark probabilities
LANDMARKS <- c(6, 12, 18)
probs_trt <- km_landmark_probs(dat |> filter(is_trt), timepoints = LANDMARKS)
probs_pbo <- km_landmark_probs(dat |> filter(!is_trt), timepoints = LANDMARKS)

prob_row <- function(p) sprintf("%.1f%% (%.1f, %.1f)",
                                  100*p$surv, 100*p$lo, 100*p$hi)

rows <- data.frame(
  Label = c(
    "Number of confirmed responders, n",
    "Events (PD or death), n (%)",
    "Censored, n (%)",
    "Median DoR, months (95% CI)",
    sprintf("DoR probability at %d months (95%% CI)", LANDMARKS)
  ),
  TRT = c(
    sprintf("%d", km_trt$n),
    fmt_n_pct(km_trt$events, km_trt$n),
    fmt_n_pct(km_trt$n - km_trt$events, km_trt$n),
    fmt_med_ci(km_trt$median, km_trt$lo, km_trt$hi),
    sapply(seq_along(LANDMARKS), function(i)
      prob_row(list(surv=probs_trt$surv[i], lo=probs_trt$lo[i], hi=probs_trt$hi[i])))
  ),
  PBO = c(
    sprintf("%d", km_pbo$n),
    fmt_n_pct(km_pbo$events, km_pbo$n),
    fmt_n_pct(km_pbo$n - km_pbo$events, km_pbo$n),
    fmt_med_ci(km_pbo$median, km_pbo$lo, km_pbo$hi),
    sapply(seq_along(LANDMARKS), function(i)
      prob_row(list(surv=probs_pbo$surv[i], lo=probs_pbo$lo[i], hi=probs_pbo$hi[i])))
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", km_trt$n),
                 arm_label("Placebo + Chemotherapy",   km_pbo$n))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)
ft <- bold(ft, i = 4, part = "body")

write_table_all_formats(
  ft, id = "T-EFF-07",
  title = "Duration of Response",
  population = sprintf("Confirmed Responders (N=%d)", km_trt$n + km_pbo$n),
  notes = c(
    "DoR = time from first confirmed CR/PR to PD or death (per SAP §4.4 / §13.7).",
    "Median DoR by KM; 95% CI by Brookmeyer-Crowley (log-log).",
    "Descriptive only (estimand E4) — no formal between-arm test per SAP §5.4.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='DOR'."
  )
)
message(sprintf("T-EFF-07 written: median DoR TRT %.1fm vs PBO %.1fm",
                km_trt$median, km_pbo$median))
