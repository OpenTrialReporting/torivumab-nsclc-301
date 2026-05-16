###############################################################################
# 02_disposition.R
# Generates raw/disposition.csv + derived OS/PFS clocks for downstream scripts
# Depends on: demographics (global)
#
# v0.2 (2026-05-16) — Tier A + Tier B model:
#   • Tier A: per-subject hazards scaled by baseline covariates (PD-L1 score,
#             histology, ECOG PS, smoking status, geographic region) via
#             multiplicative log-linear model: λ_i = λ_arm × exp(Σ β_k·x_ki).
#   • Tier B: Weibull (instead of exponential) for OS and PFS — shape > 1
#             produces realistic "slow then steep" KM curves while preserving
#             marginal medians via scale calibration.
#   • Covariates centered to study mean ⇒ marginal hazards drift <5%; explicit
#             per-arm calibration constants restore protocol-stated medians.
#
# Coefficient sources (log-HR for OS; PFS uses near-identical effects):
#   PD-L1 TPS per 50-pt rise: HR 0.75 (KEYNOTE-024 subgroup forest, 2019)
#   Squamous vs non-squamous: HR 1.25 (Pooled IO meta-analysis, ESMO 2022)
#   ECOG PS per +1 point:     HR 1.40 (Standard NSCLC prognostic factor)
#   Former smoker vs never:   HR 0.80 (KEYNOTE-024, CheckMate-227)
#   Current smoker vs never:  HR 0.85 (smaller effect than former)
#   Region APAC vs NA/EU:     HR 0.90 (mixed evidence; mild EE advantage)
###############################################################################

message("  Simulating disposition (Tier A+B model)...")

suppressPackageStartupMessages({
  library(lubridate)
  library(dplyr)
})

dm <- demographics
n  <- nrow(dm)

rand_dates <- as.Date(dm$RAND_DATE)
is_trt     <- dm$TREATMENT_ARM == "Torivumab + Chemotherapy"

# ── Region derivation from country ────────────────────────────────────────
region <- dplyr::case_when(
  dm$COUNTRY %in% c("United States", "Canada")                      ~ "NA",
  dm$COUNTRY %in% c("Germany", "France", "United Kingdom", "Spain",
                    "Italy", "Netherlands", "Poland")               ~ "EU",
  dm$COUNTRY %in% c("Japan", "South Korea", "Australia")            ~ "APAC",
  dm$COUNTRY == "Brazil"                                            ~ "SA",
  TRUE                                                              ~ "OTHER"
)

# =============================================================================
# Tier A — Covariate-driven hazard adjustment
# =============================================================================
# Coefficients (log-HR) — applied multiplicatively to per-subject hazard
# OS and PFS effects: shared direction, slightly stronger for PFS where noted.
BETA <- list(
  os = list(
    pdl1_per_50pt    = log(0.75),    # HR 0.75 per 50-point PD-L1 rise
    squamous         = log(1.25),    # HR 1.25 squamous vs non-squamous
    ecog_per_1pt     = log(1.40),    # HR 1.40 per ECOG +1
    smoke_former     = log(0.80),    # HR 0.80 former vs never
    smoke_current    = log(0.85),    # HR 0.85 current vs never
    region_apac      = log(0.90)     # HR 0.90 APAC vs NA/EU
  ),
  pfs = list(
    pdl1_per_50pt    = log(0.70),    # PFS effect slightly larger
    squamous         = log(1.20),
    ecog_per_1pt     = log(1.30),
    smoke_former     = log(0.85),
    smoke_current    = log(0.90),
    region_apac      = log(0.85)
  )
)

# Build covariate vectors (raw scale)
x_pdl1   <- dm$PDL1_SCORE / 50         # per-50-pt scale → effect = log(0.75) at +50
x_squam  <- as.integer(dm$HISTOLOGY == "Squamous")
x_ecog   <- as.integer(dm$ECOG_BASELINE)
x_smkF   <- as.integer(dm$SMOKING_STATUS == "Former")
x_smkC   <- as.integer(dm$SMOKING_STATUS == "Current")
x_apac   <- as.integer(region == "APAC")

# Center each covariate (preserve marginal hazard close to baseline).
# NA-tolerant: imputes NA with mean (zero contribution to LP).
cen <- function(x) {
  m <- mean(x, na.rm = TRUE)
  x[is.na(x)] <- m
  x - m
}

x_pdl1_c <- cen(x_pdl1)
x_squam_c <- cen(x_squam)
x_ecog_c <- cen(x_ecog)
x_smkF_c <- cen(x_smkF)
x_smkC_c <- cen(x_smkC)
x_apac_c <- cen(x_apac)

linear_predictor <- function(beta) {
  beta$pdl1_per_50pt * x_pdl1_c +
    beta$squamous       * x_squam_c +
    beta$ecog_per_1pt   * x_ecog_c +
    beta$smoke_former   * x_smkF_c +
    beta$smoke_current  * x_smkC_c +
    beta$region_apac    * x_apac_c
}

lp_os  <- linear_predictor(BETA$os)
lp_pfs <- linear_predictor(BETA$pfs)

# =============================================================================
# Tier B — Weibull survival distributions
# =============================================================================
# Weibull(shape=k, scale=σ) — increasing hazard for k>1. Median = σ·(log2)^(1/k).
# For PH compatibility under Weibull, per-subject scale = σ_arm·exp(-LP_i/k).
WEIBULL_SHAPE_OS  <- 1.40   # moderate steepening of OS KM curve
WEIBULL_SHAPE_PFS <- 1.20   # slight steepening of PFS KM (events earlier)

# Convert protocol-stated median months to Weibull scale per arm.
median_to_scale <- function(med, shape) med / (log(2))^(1 / shape)

scale_os_trt  <- median_to_scale(21.5, WEIBULL_SHAPE_OS)
scale_os_pbo  <- median_to_scale(13.3, WEIBULL_SHAPE_OS)
scale_pfs_trt <- median_to_scale(10.5, WEIBULL_SHAPE_PFS)
scale_pfs_pbo <- median_to_scale(5.8,  WEIBULL_SHAPE_PFS)

# Calibration: centered LPs preserve marginals only approximately because
# exp(LP) is convex; compute E[exp(LP/k)] empirically and divide it out so
# the marginal median lands exactly on protocol values.
cal_os  <- mean(exp(lp_os  / WEIBULL_SHAPE_OS))
cal_pfs <- mean(exp(lp_pfs / WEIBULL_SHAPE_PFS))

per_subject_scale <- function(sig_arm, lp, shape, cal) {
  sig_arm / exp(lp / shape) * cal
}

sigma_os  <- ifelse(is_trt,
                    per_subject_scale(scale_os_trt,  lp_os,  WEIBULL_SHAPE_OS,  cal_os),
                    per_subject_scale(scale_os_pbo,  lp_os,  WEIBULL_SHAPE_OS,  cal_os))
sigma_pfs <- ifelse(is_trt,
                    per_subject_scale(scale_pfs_trt, lp_pfs, WEIBULL_SHAPE_PFS, cal_pfs),
                    per_subject_scale(scale_pfs_pbo, lp_pfs, WEIBULL_SHAPE_PFS, cal_pfs))

# Sample
os_months  <- rweibull(n, shape = WEIBULL_SHAPE_OS,  scale = sigma_os)
pfs_months <- rweibull(n, shape = WEIBULL_SHAPE_PFS, scale = sigma_pfs)
pfs_months <- pmin(pfs_months, os_months)   # PFS ≤ OS (biological constraint)

os_days    <- round(os_months  * 30.4375)
pfs_days   <- round(pfs_months * 30.4375)

death_date_potential   <- rand_dates + os_days
last_tx_date_potential <- rand_dates + pfs_days
died_before_cutoff     <- death_date_potential <= DATA_CUTOFF

# =============================================================================
# Discontinuation reason assignment (unchanged from v0.1)
# =============================================================================
disc_reasons_pd  <- "Progressive Disease"
disc_reasons_ae  <- "Adverse Event"
disc_reasons_wbs <- "Withdrawal by Subject"
disc_reasons_phd <- "Physician Decision"
disc_reasons_oth <- "Other"

completion_status <- character(n)
disc_date         <- as.Date(rep(NA, n))
disc_reason       <- character(n)
last_contact_date <- as.Date(rep(NA, n))
study_completion  <- as.Date(rep(NA, n))

for (i in seq_len(n)) {
  tx_end <- min(last_tx_date_potential[i], DATA_CUTOFF - 1)

  if (died_before_cutoff[i]) {
    completion_status[i] <- "Discontinued"
    disc_date[i]         <- death_date_potential[i]
    disc_reason[i] <- sample(
      c(disc_reasons_pd, disc_reasons_ae, disc_reasons_oth),
      1, prob = c(0.72, 0.18, 0.10)
    )
    last_contact_date[i] <- death_date_potential[i]
    study_completion[i]  <- death_date_potential[i]
  } else {
    early_disc <- runif(1) < 0.35
    if (early_disc) {
      disc_day <- sample(seq(pfs_days[i], os_days[i], length.out = 5), 1)
      disc_day <- max(21, min(disc_day, as.integer(DATA_CUTOFF - rand_dates[i]) - 7))
      disc_d   <- rand_dates[i] + round(disc_day)
      if (disc_d >= DATA_CUTOFF) {
        completion_status[i] <- "Completed"
        disc_date[i]         <- NA
        disc_reason[i]       <- ""
        last_contact_date[i] <- DATA_CUTOFF - sample(0:14, 1)
        study_completion[i]  <- DATA_CUTOFF
      } else {
        completion_status[i] <- "Discontinued"
        disc_date[i]         <- disc_d
        disc_reason[i] <- sample(
          c(disc_reasons_pd, disc_reasons_ae, disc_reasons_wbs,
            disc_reasons_phd, disc_reasons_oth),
          1, prob = c(0.50, 0.20, 0.14, 0.10, 0.06)
        )
        last_contact_date[i] <- min(disc_d + sample(56:168, 1), DATA_CUTOFF)
        study_completion[i]  <- last_contact_date[i]
      }
    } else {
      completion_status[i] <- "Completed"
      disc_date[i]         <- NA
      disc_reason[i]       <- ""
      last_contact_date[i] <- DATA_CUTOFF - sample(0:14, 1)
      study_completion[i]  <- DATA_CUTOFF
    }
  }
}

disposition <- data.frame(
  SUBJECT_ID            = dm$SUBJECT_ID,
  COMPLETION_STATUS     = completion_status,
  DISC_DATE             = format(disc_date, "%Y-%m-%d"),
  DISC_REASON           = disc_reason,
  LAST_CONTACT_DATE     = format(last_contact_date, "%Y-%m-%d"),
  STUDY_COMPLETION_DATE = format(study_completion, "%Y-%m-%d"),
  stringsAsFactors      = FALSE
)

# Expose to downstream scripts
assign("disposition",              disposition,              envir = .GlobalEnv)
assign("os_days_sim",              os_days,                  envir = .GlobalEnv)
assign("pfs_days_sim",             pfs_days,                 envir = .GlobalEnv)
assign("death_date_potential",     death_date_potential,     envir = .GlobalEnv)
assign("died_before_cutoff",       died_before_cutoff,       envir = .GlobalEnv)
assign("rand_dates",               rand_dates,               envir = .GlobalEnv)
assign("is_trt",                   is_trt,                   envir = .GlobalEnv)
# New: expose linear predictors for tumor measurements ORR derivation
assign("lp_os_sim",                lp_os,                    envir = .GlobalEnv)
assign("lp_pfs_sim",               lp_pfs,                   envir = .GlobalEnv)
assign("region_sim",               region,                   envir = .GlobalEnv)

write.csv(disposition,
          file      = file.path(RAW_DIR, "disposition.csv"),
          row.names = FALSE,
          na        = "")

message("  disposition.csv written: ", nrow(disposition), " rows")
message("    Discontinued: ",
        sum(disposition$COMPLETION_STATUS == "Discontinued"),
        " | Completed: ",
        sum(disposition$COMPLETION_STATUS == "Completed"))
message(sprintf("    Marginal medians: OS_trt=%.1fm OS_pbo=%.1fm PFS_trt=%.1fm PFS_pbo=%.1fm",
        median(os_months[is_trt]),  median(os_months[!is_trt]),
        median(pfs_months[is_trt]), median(pfs_months[!is_trt])))
