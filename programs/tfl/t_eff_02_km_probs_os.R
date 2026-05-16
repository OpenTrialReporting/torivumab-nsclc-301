# torivumab guidelines loaded
# =============================================================================
# t_eff_02_km_probs_os.R
# T-EFF-02 — Kaplan-Meier Survival Probabilities, OS
# Population: ITT
# Source: ADTTE PARAMCD='OS'
# Estimand: E1 (supplements T-EFF-01)
# Method: Greenwood (log-log) 95% CI on landmark survival probabilities
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")
counts <- adsl_arm_counts(adsl, "ITTFL")

dat <- adtte |> mutate(AVAL_MO = AVAL / 30.4375,
                       is_trt  = TRT01P == "Torivumab + Chemotherapy")

LANDMARKS <- c(6, 12, 18, 24, 30)

probs_trt <- km_landmark_probs(dat |> filter(is_trt), timepoints = LANDMARKS)
probs_pbo <- km_landmark_probs(dat |> filter(!is_trt), timepoints = LANDMARKS)

rows <- data.frame(
  Label = sprintf("OS probability at %d months (95%% CI)", LANDMARKS),
  TRT   = sprintf("%.1f%% (%.1f, %.1f)",
                  100*probs_trt$surv, 100*probs_trt$lo, 100*probs_trt$hi),
  PBO   = sprintf("%.1f%% (%.1f, %.1f)",
                  100*probs_pbo$surv, 100*probs_pbo$lo, 100*probs_pbo$hi),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.0)
write_table_all_formats(
  ft, id = "T-EFF-02",
  title = "Kaplan-Meier Survival Probabilities — Overall Survival",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Survival probabilities estimated by Kaplan-Meier.",
    "95% CI by Greenwood SE on the log-log transformation.",
    "Supplements T-EFF-01 (primary OS analysis).",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OS'."
  )
)
message("T-EFF-02 written")
