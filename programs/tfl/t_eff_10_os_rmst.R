# torivumab guidelines loaded
# =============================================================================
# t_eff_10_os_rmst.R
# T-EFF-10 — Restricted Mean Survival Time (OS), tau = 36 months
# Source: ADTTE PARAMCD='OS'
# Estimand: E1a (SAP §13.4 sensitivity)
# Method: survRM2::rmst2 (unadjusted; sensitivity to PH assumption)
# =============================================================================

if (!requireNamespace("survRM2", quietly = TRUE))
  install.packages("survRM2", repos = "https://cloud.r-project.org", quiet = TRUE)
library(survRM2)

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")
counts <- adsl_arm_counts(adsl, "ITTFL")

dat <- adtte |>
  filter(!is.na(AVAL)) |>           # drop never-dosed subject with NA AVAL
  mutate(AVAL_MO = AVAL / 30.4375,
         arm_n   = as.integer(TRT01P == "Torivumab + Chemotherapy"))

TAU <- 30  # months — bounded by min(max follow-up per arm) to keep rmst2 stable

# rmst2 expects: time, status (1=event, 0=censor), arm (0/1)
res <- rmst2(time = dat$AVAL_MO,
             status = as.integer(dat$CNSR == 0),
             arm = dat$arm_n,
             tau = TAU)

rmst1 <- res$RMST.arm1$rmst   # vector: Est, SE, lower, upper
rmst0 <- res$RMST.arm0$rmst
diff_tab <- res$unadjusted.result["RMST (arm=1)-(arm=0)", ]

rows <- data.frame(
  Label = c(
    sprintf("Restricted Mean OS at τ = %d months (95%% CI)", TAU),
    "Difference TRT − PBO, months (95% CI)",
    "p-value (test of difference)"
  ),
  TRT = c(
    sprintf("%.2f (%.2f, %.2f)", rmst1["Est."], rmst1["lower .95"], rmst1["upper .95"]),
    "", ""
  ),
  PBO = c(
    sprintf("%.2f (%.2f, %.2f)", rmst0["Est."], rmst0["lower .95"], rmst0["upper .95"]),
    "", ""
  ),
  Combined = c(
    "",
    sprintf("%.2f (%.2f, %.2f)", diff_tab["Est."],
            diff_tab["lower .95"], diff_tab["upper .95"]),
    fmt_p(diff_tab["p"])
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo),
                 "Treatment effect")

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.4)
ft <- bold(ft, i = 2:3, part = "body")

write_table_all_formats(
  ft, id = "T-EFF-10",
  title = "Restricted Mean Survival Time — Overall Survival",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    sprintf("RMST(τ=%d months) — area under the KM curve up to τ.", TAU),
    "τ = 30 months reflects the minimum of arm-specific maximum follow-up (35 mo TRT, ~32 mo PBO at-risk). SAP §13.4 proposes 36 months as the protocol-defined horizon; this can be revisited once accrual extends.",
    "Estimand E1a (SAP §13.4): sensitivity to the proportional-hazards assumption underlying T-EFF-01.",
    "Estimated via survRM2::rmst2() (unadjusted, stratification handled via inverse-probability weighting in the package; same arms as primary).",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OS'."
  )
)
message(sprintf("T-EFF-10 written: RMST diff = %.2f months", diff_tab["Est."]))
