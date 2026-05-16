# torivumab guidelines loaded
# =============================================================================
# t_eff_01_os.R
# T-EFF-01 — Overall Survival Analysis (Primary)
# Population: ITT
# Source: ADTTE PARAMCD='OS', ADSL (for stratification factors)
# Estimand: E1 (SAP §13.4, primary)
# Methods: stratified log-rank + stratified Cox PH; KM medians with 95% CI
#          via Brookmeyer-Crowley (log-log).
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")

# Region derivation (matches T-DM-01)
adsl <- adsl |>
  mutate(REGION = case_when(
    COUNTRY %in% c("UNITED STATES", "CANADA")                           ~ "NA",
    COUNTRY %in% c("GERMANY", "FRANCE", "UNITED KINGDOM", "SPAIN",
                    "ITALY", "NETHERLANDS", "POLAND")                   ~ "EU",
    COUNTRY %in% c("JAPAN", "SOUTH KOREA", "AUSTRALIA")                 ~ "APAC",
    COUNTRY == "BRAZIL"                                                 ~ "OTHER",
    TRUE                                                                ~ "OTHER"
  ))

dat <- adtte |>
  left_join(adsl |> select(USUBJID, HISTCAT, REGION), by = "USUBJID") |>
  mutate(
    AVAL_MO = AVAL / 30.4375,
    is_trt  = as.integer(TRT01P == "Torivumab + Chemotherapy")
  )

counts <- adsl_arm_counts(adsl, "ITTFL")

# ---- KM medians per arm (Brookmeyer-Crowley log-log CI) ------------------
km_summary <- function(d) {
  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ 1, data = d, conf.type = "log-log")
  tbl <- summary(fit)$table
  list(
    n         = as.integer(tbl["records"]),
    events    = as.integer(tbl["events"]),
    median    = unname(tbl["median"]),
    lo        = unname(tbl["0.95LCL"]),
    hi        = unname(tbl["0.95UCL"])
  )
}
km_trt <- km_summary(dat |> filter(is_trt == 1))
km_pbo <- km_summary(dat |> filter(is_trt == 0))

# ---- Stratified Cox HR + 95% CI -------------------------------------------
cox_fit <- coxph(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
                 data = dat)
cox_s   <- summary(cox_fit)$conf.int
hr      <- cox_s["is_trt", "exp(coef)"]
hr_lo   <- cox_s["is_trt", "lower .95"]
hr_hi   <- cox_s["is_trt", "upper .95"]

# ---- Stratified log-rank p-value ------------------------------------------
sd_fit <- survdiff(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
                   data = dat)
chisq <- sd_fit$chisq
pval  <- 1 - pchisq(chisq, df = 1)

# ---- Build table ----------------------------------------------------------
rows <- data.frame(
  Label = c(
    "Number of subjects, N",
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
    fmt_hr_ci(hr, hr_lo, hr_hi),
    fmt_p(pval)
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
names(rows) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo)
)

# Bold the HR / p-value rows (treatment effect summary)
ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.0)
ft <- bold(ft, i = 5:6, part = "body")

# Write outputs
write_table_all_formats(
  ft,
  id         = "T-EFF-01",
  title      = "Overall Survival Analysis (Primary)",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Median OS estimated by Kaplan-Meier; 95% CI by Brookmeyer-Crowley (log-log).",
    "Hazard ratio from stratified Cox proportional-hazards model.",
    "Stratification factors: histology (squamous / non-squamous) and region (NA / EU / APAC / OTHER).",
    "Primary estimand (E1): treatment policy for all intercurrent events. See SAP §13.4.",
    "Source: datasets/adam/adtte.parquet WHERE PARAMCD='OS'."
  )
)

# Stash for the combined deliverable
.OS_RESULTS <- list(km_trt = km_trt, km_pbo = km_pbo,
                    hr = hr, hr_lo = hr_lo, hr_hi = hr_hi, p = pval)
assign(".OS_RESULTS", .OS_RESULTS, envir = globalenv())

message(sprintf("T-EFF-01 written: HR=%.3f (%.3f-%.3f), p=%s, OS TRT=%.1fm PBO=%.1fm",
                hr, hr_lo, hr_hi, fmt_p(pval), km_trt$median, km_pbo$median))
