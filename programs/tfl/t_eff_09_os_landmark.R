# torivumab guidelines loaded
# =============================================================================
# t_eff_09_os_landmark.R
# T-EFF-09 — OS Landmark Analysis (Sensitivity)
# Compares survival probabilities at specific landmarks between arms,
# with Greenwood SE for the probability difference.
# Source: ADTTE PARAMCD='OS'
# Reference: SAP §11 sensitivity
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")
counts <- adsl_arm_counts(adsl, "ITTFL")

dat <- adtte |> mutate(AVAL_MO = AVAL / 30.4375,
                       is_trt  = TRT01P == "Torivumab + Chemotherapy")

LANDMARKS <- c(6, 12, 18, 24, 30)

probs_trt <- km_landmark_probs(dat |> filter(is_trt),  timepoints = LANDMARKS)
probs_pbo <- km_landmark_probs(dat |> filter(!is_trt), timepoints = LANDMARKS)

# Greenwood SE for difference: SE_diff^2 = SE_trt^2 + SE_pbo^2 (independent arms)
fit_trt <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = dat |> filter(is_trt))
fit_pbo <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = dat |> filter(!is_trt))
ext_trt <- summary(fit_trt, times = LANDMARKS, extend = TRUE)
ext_pbo <- summary(fit_pbo, times = LANDMARKS, extend = TRUE)
se_trt  <- ext_trt$std.err
se_pbo  <- ext_pbo$std.err
diffs   <- 100 * (probs_trt$surv - probs_pbo$surv)
se_diff <- 100 * sqrt(se_trt^2 + se_pbo^2)
ci_lo   <- diffs - 1.96 * se_diff
ci_hi   <- diffs + 1.96 * se_diff
z       <- diffs / se_diff
p_two   <- 2 * (1 - pnorm(abs(z)))

rows <- data.frame(
  Landmark = sprintf("%d months", LANDMARKS),
  TRT      = sprintf("%.1f%% (%.1f, %.1f)",
                      100*probs_trt$surv, 100*probs_trt$lo, 100*probs_trt$hi),
  PBO      = sprintf("%.1f%% (%.1f, %.1f)",
                      100*probs_pbo$surv, 100*probs_pbo$lo, 100*probs_pbo$hi),
  Diff     = sprintf("%.1f (%.1f, %.1f)", diffs, ci_lo, ci_hi),
  p        = sapply(p_two, fmt_p),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(
  "Landmark",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  "Difference TRT − PBO (95% CI)",
  "p-value"
)

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 1.8)

write_table_all_formats(
  ft, id = "T-EFF-09",
  title = "Overall Survival Landmark Analysis (Sensitivity)",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Survival probabilities at fixed landmark months by Kaplan-Meier.",
    "95% CI on the difference via Greenwood SE (sum of arm-specific SEs).",
    "Two-sided p-value: z = diff / SE_diff.",
    "Reference: SAP §11 sensitivity.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OS'."
  )
)
message("T-EFF-09 written")
