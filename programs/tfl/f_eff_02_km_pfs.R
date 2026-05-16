# torivumab guidelines loaded
# =============================================================================
# f_eff_02_km_pfs.R
# F-EFF-02 — Kaplan-Meier Curve, Progression-Free Survival
# Population: ITT
# Source: ADTTE PARAMCD='PFS', ADSL
# Estimand: E2 (SAP §13.5)
# =============================================================================

source(file.path("programs", "tfl", "_km_plot.R"))

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "PFS")

dat <- adtte |>
  mutate(
    AVAL_MO = AVAL / 30.4375,
    arm     = factor(TRT01P,
                     levels = c("Torivumab + Chemotherapy", "Placebo + Chemotherapy"),
                     labels = c("Torivumab + Chemo", "Placebo + Chemo"))
  )

p <- km_plot(
  data         = dat,
  endpoint     = "Progression-Free Survival",
  xlab         = "Time from randomisation (months)",
  ylab         = "PFS probability",
  max_month    = 24,
  risk_breaks  = seq(0, 24, by = 3),
  output_id    = "F-EFF-02"
)

write_figure(p, "F-EFF-02", width = 8, height = 6, dpi = 300)
message("F-EFF-02 written")
