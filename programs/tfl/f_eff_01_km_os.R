# torivumab guidelines loaded
# =============================================================================
# f_eff_01_km_os.R
# F-EFF-01 — Kaplan-Meier Curve, Overall Survival (Primary)
# Population: ITT
# Source: ADTTE PARAMCD='OS', ADSL
# Estimand: E1 (SAP §13.4)
# =============================================================================

source(file.path("programs", "tfl", "_km_plot.R"))

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")

dat <- adtte |>
  mutate(
    AVAL_MO = AVAL / 30.4375,
    arm     = factor(TRT01P,
                     levels = c("Torivumab + Chemotherapy", "Placebo + Chemotherapy"),
                     labels = c("Torivumab + Chemo", "Placebo + Chemo"))
  )

p <- km_plot(
  data         = dat,
  endpoint     = "Overall Survival",
  xlab         = "Time from randomisation (months)",
  ylab         = "Survival probability",
  max_month    = 36,
  risk_breaks  = seq(0, 36, by = 6),
  output_id    = "F-EFF-01"
)

write_figure(p, "F-EFF-01", width = 8, height = 7, dpi = 300)
message("F-EFF-01 written")
