###############################################################################
# 09_tumor_measurements.R
# Generates raw/tumor_measurements.csv
# RECIST 1.1 — target lesions (1-3), non-target lesions (1-2)
# Assessments every ~6 weeks starting at Week 6
# Depends on: demographics, rand_dates, is_trt, pfs_days_sim, ORR_TRT, ORR_PBO
###############################################################################

message("  Simulating tumor measurements...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

# ── anatomical location pools ──────────────────────────────────────────────
target_locs  <- c("Right lung", "Left lung", "Right lower lobe", "Left lower lobe",
                  "Right upper lobe", "Mediastinum", "Liver", "Adrenal gland",
                  "Lymph node - mediastinal", "Lymph node - hilar",
                  "Lymph node - supraclavicular", "Brain", "Bone - vertebra",
                  "Bone - rib", "Pleura")
nontarget_locs <- c("Bone - pelvis", "Pleural effusion", "Pericardial effusion",
                    "Peritoneum", "Skin", "Lymph node - axillary",
                    "Adrenal gland", "Brain")

# ── assessment visit schedule (every 42 days from C3D1) ───────────────────
tumor_visit_offsets <- seq(42, 42 * 20, by = 42)  # up to ~Week 84
tumor_visit_names   <- paste0("TUMOR_ASSESS_WK", tumor_visit_offsets / 7)

# =============================================================================
# Tier A — Covariate-driven ORR (per-subject response probability)
# =============================================================================
# logit(p_i) = logit(orr_arm) + Σ β_k · x_ki_centered
# Coefficients (log-odds, ORR direction — higher = more response):
#   PD-L1 per 50-pt rise: log(2.0)   = +0.693   (KEYNOTE-024: TPS-driven ORR)
#   Squamous vs non-sq:  log(0.75)  = -0.288
#   ECOG per +1 point:    log(0.70)  = -0.357
#   Former smoker:        log(1.30)  = +0.262
#   Current smoker:       log(1.40)  = +0.336
# Centering preserves marginal ORR within ~1pp; explicit re-calibration
# (intercept shift) below restores ORR_TRT / ORR_PBO exactly.
BETA_ORR <- list(
  pdl1_per_50pt    = log(2.0),
  squamous         = log(0.75),
  ecog_per_1pt     = log(0.70),
  smoke_former     = log(1.30),
  smoke_current    = log(1.40)
)

logit  <- function(p) log(p / (1 - p))
expit  <- function(x) 1 / (1 + exp(-x))
# NA-tolerant centering (imputes NA with mean → zero LP contribution)
cen    <- function(x) {
  m <- mean(x, na.rm = TRUE)
  x[is.na(x)] <- m
  x - m
}

xo_pdl1  <- cen(dm$PDL1_SCORE / 50)
xo_squam <- cen(as.integer(dm$HISTOLOGY == "Squamous"))
xo_ecog  <- cen(as.integer(dm$ECOG_BASELINE))
xo_smkF  <- cen(as.integer(dm$SMOKING_STATUS == "Former"))
xo_smkC  <- cen(as.integer(dm$SMOKING_STATUS == "Current"))

lp_orr <- BETA_ORR$pdl1_per_50pt * xo_pdl1 +
          BETA_ORR$squamous       * xo_squam +
          BETA_ORR$ecog_per_1pt   * xo_ecog +
          BETA_ORR$smoke_former   * xo_smkF +
          BETA_ORR$smoke_current  * xo_smkC

# Per-subject ORR probability; per-arm intercept re-calibration ensures
# marginal ORR within arm equals protocol-stated ORR_TRT / ORR_PBO.
orr_prob <- numeric(n)
for (arm_flag in c(TRUE, FALSE)) {
  idx       <- which(is_trt == arm_flag)
  arm_orr   <- if (arm_flag) ORR_TRT else ORR_PBO
  intercept <- logit(arm_orr)
  raw_p     <- expit(intercept + lp_orr[idx])
  # Re-calibrate intercept so mean(p) == arm_orr (handles convexity drift)
  shift     <- logit(arm_orr) - logit(mean(raw_p))
  orr_prob[idx] <- expit(intercept + shift + lp_orr[idx])
}

tm_list <- vector("list", n)

# ── Missed-visit simulation (AL-12 closure, 2026-05-17) ────────────────────
# ~6% of subjects have a stochastic episode of 2-3 consecutive missed Q6W
# tumour assessments mid-trial. Drives T-DS-03 IE4 ("≥2 consecutive missed
# tumour assessments"). Selection seeded for reproducibility.
set.seed(20260309)  # local seed for missed-visit selection
MISS_RATE <- 0.15
miss_subj <- sample(seq_len(n), size = round(n * MISS_RATE))
# For each selected subject, choose a start visit and gap length (2 or 3
# consecutive misses). Start biased to visits 2-5 so the gap falls early
# enough to be observable before the subject progresses or discontinues
# (later starts often coincide with PD-driven loop termination and produce
# no detectable gap in OVR).
miss_plan <- lapply(seq_len(n), function(i) {
  if (!(i %in% miss_subj)) return(integer(0))
  start   <- sample(2:5, 1)
  gap_len <- sample(2:3, 1, prob = c(0.6, 0.4))
  seq(start, start + gap_len - 1L)
})

for (i in seq_len(n)) {
  subj_id <- dm$SUBJECT_ID[i]
  rand_dt <- rand_dates[i]
  trt     <- is_trt[i]
  pfs_d   <- pfs_days_sim[i]
  skip_idx <- miss_plan[[i]]

  last_obs_dt <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  # ── determine response trajectory (covariate-driven per-subject) ─────
  is_responder <- runif(1) < orr_prob[i]  # CR or PR — not stored as column

  # CR vs PR split (among responders)
  is_cr  <- is_responder && (runif(1) < 0.12)

  # Number of target lesions (1-3)
  n_target    <- sample(1:3, 1, prob = c(0.30, 0.45, 0.25))
  n_nontarget <- sample(0:2, 1, prob = c(0.30, 0.50, 0.20))

  # Baseline target lesion sizes (mm)
  baseline_sizes <- round(runif(n_target, min = 12, max = 65), 1)
  target_locs_sel    <- sample(target_locs,    n_target,    replace = FALSE)
  nontarget_locs_sel <- if (n_nontarget > 0)
    sample(nontarget_locs, n_nontarget, replace = FALSE) else character(0)

  rows <- list()

  # ── baseline assessment at screening ─────────────────────────────────
  baseline_dt <- rand_dt - sample(7:21, 1)

  for (tl in seq_len(n_target)) {
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID          = subj_id,
      ASSESSMENT_DATE     = format(baseline_dt, "%Y-%m-%d"),
      VISIT_NAME          = "BASELINE",
      LESION_ID           = paste0("TARGET_", tl),
      LESION_TYPE         = "Target",
      ANATOMICAL_LOCATION = target_locs_sel[tl],
      LONGEST_DIAMETER_MM = baseline_sizes[tl],
      RESPONSE_CATEGORY   = "",
      NEW_LESION          = "N",
      stringsAsFactors    = FALSE
    )
  }
  for (nl in seq_len(n_nontarget)) {
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID          = subj_id,
      ASSESSMENT_DATE     = format(baseline_dt, "%Y-%m-%d"),
      VISIT_NAME          = "BASELINE",
      LESION_ID           = paste0("NONTARGET_", nl),
      LESION_TYPE         = "Non-target",
      ANATOMICAL_LOCATION = nontarget_locs_sel[nl],
      LONGEST_DIAMETER_MM = NA,
      RESPONSE_CATEGORY   = "Present",
      NEW_LESION          = "N",
      stringsAsFactors    = FALSE
    )
  }

  # ── on-study assessments ─────────────────────────────────────────────
  current_sizes <- baseline_sizes

  for (a_idx in seq_along(tumor_visit_offsets)) {
    assess_offset <- tumor_visit_offsets[a_idx]
    assess_dt     <- rand_dt + assess_offset + sample(-3:3, 1)

    if (assess_dt > min(last_obs_dt, DATA_CUTOFF)) break
    if (assess_offset > pfs_d + 28) break   # past progression, no more scans

    # AL-12: subject missed this scheduled visit; skip writing any rows for
    # this index. Lesion-size state still updates so the next observed visit
    # reflects continued growth/shrinkage during the unobserved window.
    if (a_idx %in% skip_idx) next

    visit_nm <- tumor_visit_names[a_idx]

    # ── size trajectory ───────────────────────────────────────────────
    # Week since treatment
    wk <- assess_offset / 7

    # Determine change from baseline sum
    sum_baseline <- sum(baseline_sizes)

    if (is_cr) {
      # CR: sizes shrink to 0 by ~Week 18
      cr_factor <- pmax(0, 1 - (wk / 18))
      current_sizes <- pmax(0, baseline_sizes * cr_factor + rnorm(n_target, 0, 1))
    } else if (is_responder) {
      # PR: nadir ~30-65% reduction, then stable or slight growth
      nadir_pct <- runif(1, 0.30, 0.65)
      nadir_wk  <- sample(c(6, 12, 18), 1)
      if (wk <= nadir_wk) {
        factor <- 1 - nadir_pct * (wk / nadir_wk)
      } else {
        # slight regrowth after nadir
        regrowth <- 0.005 * (wk - nadir_wk)
        factor   <- (1 - nadir_pct) + regrowth
        factor   <- min(factor, 1.4)   # cap at 40% above baseline
      }
      current_sizes <- pmax(2, baseline_sizes * factor + rnorm(n_target, 0, 1.5))
    } else {
      # SD or PD: slow growth, PD accelerates after PFS
      pd_wk <- pfs_d / 7
      if (wk < pd_wk) {
        # SD: slight fluctuation
        factor <- 1 + rnorm(1, 0.02, 0.05)
        factor <- pmax(0.90, pmin(1.30, factor))
      } else {
        # PD: clear growth
        factor <- 1.20 + 0.06 * (wk - pd_wk)
        factor <- pmin(factor, 3.0)
      }
      current_sizes <- pmax(5, baseline_sizes * factor + rnorm(n_target, 0, 2))
    }

    # New lesion only in PD territory
    has_new_lesion <- !is_responder && (assess_offset > pfs_d) && (runif(1) < 0.35)

    for (tl in seq_len(n_target)) {
      ld <- if (is_cr && wk >= 18) 0 else round(current_sizes[tl], 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        ASSESSMENT_DATE     = format(assess_dt, "%Y-%m-%d"),
        VISIT_NAME          = visit_nm,
        LESION_ID           = paste0("TARGET_", tl),
        LESION_TYPE         = "Target",
        ANATOMICAL_LOCATION = target_locs_sel[tl],
        LONGEST_DIAMETER_MM = ld,
        RESPONSE_CATEGORY   = "",
        NEW_LESION          = "N",
        stringsAsFactors    = FALSE
      )
    }

    # Non-target lesions
    for (nl in seq_len(n_nontarget)) {
      nt_resp <- if (is_responder && wk >= 6) {
        sample(c("Absent", "Present"), 1, prob = c(0.35, 0.65))
      } else if (!is_responder && assess_offset > pfs_d) {
        sample(c("Present", "Unequivocal PD"), 1, prob = c(0.40, 0.60))
      } else {
        "Present"
      }
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        ASSESSMENT_DATE     = format(assess_dt, "%Y-%m-%d"),
        VISIT_NAME          = visit_nm,
        LESION_ID           = paste0("NONTARGET_", nl),
        LESION_TYPE         = "Non-target",
        ANATOMICAL_LOCATION = nontarget_locs_sel[nl],
        LONGEST_DIAMETER_MM = NA,
        RESPONSE_CATEGORY   = nt_resp,
        NEW_LESION          = "N",
        stringsAsFactors    = FALSE
      )
    }

    # New lesion row
    if (has_new_lesion) {
      new_loc <- sample(target_locs, 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        ASSESSMENT_DATE     = format(assess_dt, "%Y-%m-%d"),
        VISIT_NAME          = visit_nm,
        LESION_ID           = "NEW_1",
        LESION_TYPE         = "Target",
        ANATOMICAL_LOCATION = new_loc,
        LONGEST_DIAMETER_MM = round(runif(1, 10, 40), 1),
        RESPONSE_CATEGORY   = "",
        NEW_LESION          = "Y",
        stringsAsFactors    = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    tm_list[[i]] <- do.call(rbind, rows)
  }
}

tumor_measurements <- do.call(rbind, Filter(Negate(is.null), tm_list))
row.names(tumor_measurements) <- NULL

assign("tumor_measurements", tumor_measurements, envir = .GlobalEnv)
# Also expose responder info for overall_response script (via is_cr/is_responder won't carry)
# We store a lookup: rebuild from ORR simulation using same seed logic — overall_response
# will re-derive from tumor_measurements data

write.csv(tumor_measurements,
          file      = file.path(RAW_DIR, "tumor_measurements.csv"),
          row.names = FALSE,
          na        = "")

message("  tumor_measurements.csv written: ", nrow(tumor_measurements), " rows")
