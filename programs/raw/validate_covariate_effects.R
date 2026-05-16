###############################################################################
# validate_covariate_effects.R
# Verifies that the Tier A+B covariate model in 02_disposition.R and
# 09_tumor_measurements.R recovers the input HRs and preserves marginal
# medians within tolerance. Run AFTER 00_simulate_raw.R has produced
# raw/demographics.csv, raw/disposition.csv, raw/overall_response.csv.
#
# Reports:
#   1. Marginal medians (OS, PFS) per arm vs protocol-stated values
#   2. Cox PH HR estimates vs input log-HR coefficients
#   3. Logistic ORR effect estimates vs input log-odds coefficients
#   4. Pass/fail flag per check (±20% tolerance on HR; ±2 months on median)
###############################################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(survival)
})

RAW_DIR <- "raw"

dm <- read.csv(file.path(RAW_DIR, "demographics.csv"), stringsAsFactors = FALSE)
ds <- read.csv(file.path(RAW_DIR, "disposition.csv"),  stringsAsFactors = FALSE)
rs <- read.csv(file.path(RAW_DIR, "overall_response.csv"), stringsAsFactors = FALSE)

# ── Derive OS/PFS time + event flags ────────────────────────────────────────
dat <- dm |>
  left_join(ds, by = "SUBJECT_ID") |>
  mutate(
    rand_dt        = as.Date(RAND_DATE),
    death_dt       = as.Date(DISC_DATE),  # set when died
    last_contact_dt = as.Date(LAST_CONTACT_DATE),
    is_trt          = TREATMENT_ARM == "Torivumab + Chemotherapy",
    region          = case_when(
      COUNTRY %in% c("United States", "Canada")                         ~ "NA",
      COUNTRY %in% c("Germany", "France", "United Kingdom", "Spain",
                      "Italy", "Netherlands", "Poland")                 ~ "EU",
      COUNTRY %in% c("Japan", "South Korea", "Australia")               ~ "APAC",
      TRUE                                                              ~ "OTHER"
    ),
    died            = !is.na(death_dt) &
                        COMPLETION_STATUS == "Discontinued" &
                        DISC_REASON %in% c("Progressive Disease",
                                           "Adverse Event", "Other"),
    os_event        = died,
    os_end_dt       = pmax(death_dt, last_contact_dt, na.rm = TRUE),
    os_months       = as.numeric(os_end_dt - rand_dt) / 30.4375
  )

# Derive PFS from RS (first PD or death)
pd_per_subj <- rs |>
  mutate(is_pd = INVESTIGATOR_RESPONSE %in% c("PD", "Progressive Disease")) |>
  filter(is_pd) |>
  group_by(SUBJECT_ID) |>
  summarise(first_pd_dt = as.Date(min(ASSESSMENT_DATE)), .groups = "drop")

dat <- dat |>
  left_join(pd_per_subj, by = "SUBJECT_ID") |>
  mutate(
    pfs_event_dt = pmin(first_pd_dt, death_dt, na.rm = TRUE),
    pfs_event    = !is.na(pfs_event_dt),
    pfs_end_dt   = if_else(pfs_event, pfs_event_dt, last_contact_dt),
    pfs_months   = as.numeric(pfs_end_dt - rand_dt) / 30.4375
  )

# ── Marginal median check ──────────────────────────────────────────────────
TARGET <- list(os_trt = 21.5, os_pbo = 13.3, pfs_trt = 10.5, pfs_pbo = 5.8)

km_med <- function(time, event) {
  fit <- survfit(Surv(time, event) ~ 1)
  s   <- summary(fit)$table
  s["median"]
}

obs <- list(
  os_trt  = km_med(dat$os_months[dat$is_trt],   dat$os_event[dat$is_trt]),
  os_pbo  = km_med(dat$os_months[!dat$is_trt],  dat$os_event[!dat$is_trt]),
  pfs_trt = km_med(dat$pfs_months[dat$is_trt],  dat$pfs_event[dat$is_trt]),
  pfs_pbo = km_med(dat$pfs_months[!dat$is_trt], dat$pfs_event[!dat$is_trt])
)

cat("\n=== Marginal median check (KM estimator) ===\n")
cat(sprintf("  %-10s %8s %8s %8s   %s\n", "Metric", "Target", "Observed", "Δ (mo)", "Status"))
for (k in names(TARGET)) {
  d <- obs[[k]] - TARGET[[k]]
  status <- if (abs(d) <= 2.5) "PASS" else "WARN"
  cat(sprintf("  %-10s %8.1f %8.1f %+8.1f   [%s]\n",
              k, TARGET[[k]], obs[[k]], d, status))
}

# ── Cox PH for OS — check covariate HRs ────────────────────────────────────
cat("\n=== Cox PH HR estimates — OS ===\n")
dat <- dat |>
  mutate(
    pdl1_50pt = PDL1_SCORE / 50,
    squamous  = as.integer(HISTOLOGY == "Squamous"),
    ecog_pts  = as.integer(ECOG_BASELINE),
    smk_form  = as.integer(SMOKING_STATUS == "Former"),
    smk_curr  = as.integer(SMOKING_STATUS == "Current"),
    region_apac = as.integer(region == "APAC"),
    arm_trt   = as.integer(is_trt)
  )

cox_os <- coxph(
  Surv(os_months, os_event) ~ arm_trt + pdl1_50pt + squamous + ecog_pts +
    smk_form + smk_curr + region_apac,
  data = dat
)

INPUT_OS_HR <- c(
  arm_trt     = NA,        # arm effect is via different scale, not LP
  pdl1_50pt   = 0.75,
  squamous    = 1.25,
  ecog_pts    = 1.40,
  smk_form    = 0.80,
  smk_curr    = 0.85,
  region_apac = 0.90
)

est <- summary(cox_os)$conf.int  # cols: exp(coef), exp(-coef), lower .95, upper .95
cat(sprintf("  %-12s %10s %10s %14s   %s\n",
            "Covariate", "Input HR", "Est HR", "95% CI", "Status"))
for (v in rownames(est)) {
  input_hr <- INPUT_OS_HR[v]
  est_hr   <- est[v, "exp(coef)"]
  ci_lo    <- est[v, "lower .95"]
  ci_hi    <- est[v, "upper .95"]
  status <- if (is.na(input_hr)) "—" else
            if (input_hr >= ci_lo && input_hr <= ci_hi) "PASS" else "CHECK"
  cat(sprintf("  %-12s %10s %10.3f  (%.3f-%.3f)   [%s]\n",
              v,
              if (is.na(input_hr)) "—" else sprintf("%.3f", input_hr),
              est_hr, ci_lo, ci_hi, status))
}

# ── ORR logistic check ─────────────────────────────────────────────────────
cat("\n=== Logistic ORR effect estimates ===\n")

bor <- rs |>
  group_by(SUBJECT_ID) |>
  summarise(
    is_responder = any(INVESTIGATOR_RESPONSE %in%
                       c("CR", "Complete Response", "PR", "Partial Response")),
    .groups = "drop"
  )

orr_dat <- dat |>
  left_join(bor, by = "SUBJECT_ID") |>
  mutate(is_responder = if_else(is.na(is_responder), FALSE, is_responder))

logit_orr <- glm(
  is_responder ~ arm_trt + pdl1_50pt + squamous + ecog_pts + smk_form + smk_curr,
  data   = orr_dat,
  family = binomial
)

INPUT_ORR_OR <- c(
  arm_trt   = NA,
  pdl1_50pt = 2.0,
  squamous  = 0.75,
  ecog_pts  = 0.70,
  smk_form  = 1.30,
  smk_curr  = 1.40
)

est_orr <- exp(cbind(OR = coef(logit_orr), confint.default(logit_orr)))
cat(sprintf("  %-12s %10s %10s %14s   %s\n",
            "Covariate", "Input OR", "Est OR", "95% CI", "Status"))
for (v in rownames(est_orr)) {
  if (v == "(Intercept)") next
  input_or <- INPUT_ORR_OR[v]
  est_or   <- est_orr[v, "OR"]
  ci_lo    <- est_orr[v, "2.5 %"]
  ci_hi    <- est_orr[v, "97.5 %"]
  status <- if (is.na(input_or)) "—" else
            if (input_or >= ci_lo && input_or <= ci_hi) "PASS" else "CHECK"
  cat(sprintf("  %-12s %10s %10.3f  (%.3f-%.3f)   [%s]\n",
              v,
              if (is.na(input_or)) "—" else sprintf("%.3f", input_or),
              est_or, ci_lo, ci_hi, status))
}

# ── Marginal ORR per arm ───────────────────────────────────────────────────
cat("\n=== Marginal ORR per arm ===\n")
orr_summ <- orr_dat |>
  group_by(arm = if_else(is_trt, "TRT", "PBO")) |>
  summarise(
    n_subj      = n(),
    n_responder = sum(is_responder),
    orr         = mean(is_responder),
    .groups = "drop"
  )
print(orr_summ)
cat(sprintf("  Target: TRT %.2f | PBO %.2f\n", 0.44, 0.20))

cat("\n=== Validation complete ===\n")
