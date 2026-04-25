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

tm_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id <- dm$SUBJECT_ID[i]
  rand_dt <- rand_dates[i]
  trt     <- is_trt[i]
  pfs_d   <- pfs_days_sim[i]

  last_obs_dt <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  # ── determine response trajectory ────────────────────────────────────
  orr_p  <- if (trt) ORR_TRT else ORR_PBO
  is_responder <- runif(1) < orr_p  # CR or PR — not stored as column

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
