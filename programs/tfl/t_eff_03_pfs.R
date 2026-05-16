# torivumab guidelines loaded
# =============================================================================
# t_eff_03_pfs.R
# T-EFF-03 — Progression-Free Survival Analysis
# Population: ITT
# Source: ADTTE PARAMCD='PFS', ADSL
# Estimand: E2 (SAP §13.5) — primary PFS
# Methods: stratified log-rank + stratified Cox PH; KM medians via log-log CI.
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "PFS")

adsl <- adsl |>
  mutate(REGION = case_when(
    COUNTRY %in% c("UNITED STATES", "CANADA")                           ~ "NA",
    COUNTRY %in% c("GERMANY", "FRANCE", "UNITED KINGDOM", "SPAIN",
                    "ITALY", "NETHERLANDS", "POLAND")                   ~ "EU",
    COUNTRY %in% c("JAPAN", "SOUTH KOREA", "AUSTRALIA")                 ~ "APAC",
    TRUE                                                                ~ "OTHER"
  ))

dat <- adtte |>
  left_join(adsl |> select(USUBJID, HISTCAT, REGION), by = "USUBJID") |>
  mutate(
    AVAL_MO = AVAL / 30.4375,
    is_trt  = as.integer(TRT01P == "Torivumab + Chemotherapy")
  )

counts <- adsl_arm_counts(adsl, "ITTFL")

km_summary <- function(d) {
  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = d, conf.type = "log-log")
  tbl <- summary(fit)$table
  list(
    n       = as.integer(tbl["records"]),
    events  = as.integer(tbl["events"]),
    median  = unname(tbl["median"]),
    lo      = unname(tbl["0.95LCL"]),
    hi      = unname(tbl["0.95UCL"])
  )
}
km_trt <- km_summary(dat |> filter(is_trt == 1))
km_pbo <- km_summary(dat |> filter(is_trt == 0))

cox_fit <- coxph(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
                 data = dat)
cox_s   <- summary(cox_fit)$conf.int
hr      <- cox_s["is_trt", "exp(coef)"]
hr_lo   <- cox_s["is_trt", "lower .95"]
hr_hi   <- cox_s["is_trt", "upper .95"]

sd_fit <- survdiff(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
                   data = dat)
pval   <- 1 - pchisq(sd_fit$chisq, df = 1)

# Event-type breakdown (PD vs death) — useful for PFS reporting
evt_pd    <- dat |> group_by(is_trt) |>
  summarise(n_pd = sum(CNSR == 0 & EVNTDESC == "PROGRESSIVE DISEASE"),
            n_dt = sum(CNSR == 0 & EVNTDESC == "DEATH"),
            .groups = "drop")
n_pd_trt  <- evt_pd$n_pd[evt_pd$is_trt == 1]
n_pd_pbo  <- evt_pd$n_pd[evt_pd$is_trt == 0]
n_dt_trt  <- evt_pd$n_dt[evt_pd$is_trt == 1]
n_dt_pbo  <- evt_pd$n_dt[evt_pd$is_trt == 0]

rows <- data.frame(
  Label = c(
    "Number of subjects, N",
    "PFS events, n (%)",
    "  Disease progression, n (%)",
    "  Death without progression, n (%)",
    "Censored, n (%)",
    "Median PFS, months (95% CI)",
    "Hazard ratio (95% CI), stratified Cox PH",
    "p-value, stratified log-rank"
  ),
  TRT = c(
    sprintf("%d", km_trt$n),
    fmt_n_pct(km_trt$events, km_trt$n),
    fmt_n_pct(n_pd_trt, km_trt$n),
    fmt_n_pct(n_dt_trt, km_trt$n),
    fmt_n_pct(km_trt$n - km_trt$events, km_trt$n),
    fmt_med_ci(km_trt$median, km_trt$lo, km_trt$hi),
    fmt_hr_ci(hr, hr_lo, hr_hi),
    fmt_p(pval)
  ),
  PBO = c(
    sprintf("%d", km_pbo$n),
    fmt_n_pct(km_pbo$events, km_pbo$n),
    fmt_n_pct(n_pd_pbo, km_pbo$n),
    fmt_n_pct(n_dt_pbo, km_pbo$n),
    fmt_n_pct(km_pbo$n - km_pbo$events, km_pbo$n),
    fmt_med_ci(km_pbo$median, km_pbo$lo, km_pbo$hi),
    "", ""
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo)
)

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.0)
ft <- ft |> indent_ft(c(3, 4), levels = 1)
ft <- bold(ft, i = 7:8, part = "body")

write_table_all_formats(
  ft,
  id         = "T-EFF-03",
  title      = "Progression-Free Survival Analysis (BICR)",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Median PFS estimated by Kaplan-Meier; 95% CI by Brookmeyer-Crowley (log-log).",
    "Hazard ratio from stratified Cox proportional-hazards model.",
    "Stratification factors: histology and region (NA / EU / APAC / OTHER).",
    "Primary estimand (E2): hypothetical handling for new anti-cancer therapy and ≥2 consecutive missed assessments (FDA 2018). See SAP §13.5.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='PFS'."
  )
)

.PFS_RESULTS <- list(km_trt = km_trt, km_pbo = km_pbo,
                     hr = hr, hr_lo = hr_lo, hr_hi = hr_hi, p = pval)
assign(".PFS_RESULTS", .PFS_RESULTS, envir = globalenv())

message(sprintf("T-EFF-03 written: HR=%.3f (%.3f-%.3f), p=%s, PFS TRT=%.1fm PBO=%.1fm",
                hr, hr_lo, hr_hi, fmt_p(pval), km_trt$median, km_pbo$median))
