# =============================================================================
# torivumab guidelines loaded
# 12_tr.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: TR (Tumour Results) — RECIST 1.1 lesion measurements
# Standard: SDTMIG v3.4 | CDISC Oncology Disease Response Supplement 2023
# Seed: set.seed(312)
# =============================================================================
#
# Outputs:
#   sdtm/tr.parquet              — SDTM TR domain (Parquet)
#   data-raw/raw_data/tr_raw.csv — Raw tumour measurement records
#   data-raw/raw_data/tr_sum_diam.csv — Sum of diameters per visit (for RS/ADTR)
#
# TR strategy (RECIST 1.1):
#   - One TR record per target lesion per imaging visit
#   - Non-target lesions: present/absent/unequivocal progression
#   - Imaging schedule: Wk6, Wk12, Wk18, Wk24, then Q12W
#   - Target lesion measurements follow treatment response trajectory:
#     - CR: tumour disappears (TRORRES = 0)
#     - PR: ≥30% reduction in sum of diameters from baseline nadir
#     - SD: neither PR nor PD criteria met
#     - PD: ≥20% increase from nadir + ≥5mm absolute; or new lesion
#   - Response pattern based on subject's PFS time (from backbone)
#
# Dependencies:
#   - data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
#   - data-raw/raw_data/tu_lesion_map.csv (from 11_tu.R)
# Run after: 11_tu.R
# Run before: 13_rs.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(312)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    PROG_DATE   = as.Date(PROG_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    OBS_OS_DATE = as.Date(OBS_OS_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

lesion_map <- read.csv("data-raw/raw_data/tu_lesion_map.csv",
                       stringsAsFactors = FALSE)

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Imaging visit schedule (days from C1D1) ───────────────────────────────────
# Per visit schedule: Wk6, Wk12, Wk18, Wk24, then Q12W until progression/EOT
img_visits_base <- c(
  IMG01 = 42L,  IMG02 = 84L,  IMG03 = 126L, IMG04 = 168L,
  IMG05 = 252L, IMG06 = 336L, IMG07 = 420L, IMG08 = 504L,
  IMG09 = 588L, IMG10 = 672L, IMG11 = 756L
)
# Window: ±3 days (Wk6-18), ±7 days (Wk24+)
img_window <- c(
  IMG01 = 3L, IMG02 = 3L, IMG03 = 3L,
  IMG04 = 7L, IMG05 = 7L, IMG06 = 7L, IMG07 = 7L,
  IMG08 = 7L, IMG09 = 7L, IMG10 = 7L, IMG11 = 7L
)


# ── Response trajectory simulation ────────────────────────────────────────────
# Given PFS time, simulate per-lesion measurements across imaging visits.
#
# Response pattern probabilities (KEYNOTE-024 inspired):
#   TOR arm: ~45% PR/CR, ~35% SD, ~20% early PD
#   PBO arm: ~15% PR, ~40% SD, ~45% early PD
#
# Tumour size trajectory modelled as exponential growth/decay:
#   size(t) = size0 * exp(growth_rate * t)
#   where growth_rate < 0 for responders, > 0 for progressors
#   With a nadir followed by exponential regrowth for SD/PR→PD subjects

assign_response_pattern <- function(arm, pfs_months) {
  if (arm == "TOR") {
    if (pfs_months >= 12) {
      sample(c("CR", "PR", "SD"), 1L, prob = c(0.05, 0.60, 0.35))
    } else if (pfs_months >= 6) {
      sample(c("PR", "SD", "PD"), 1L, prob = c(0.45, 0.40, 0.15))
    } else {
      sample(c("PR", "SD", "PD"), 1L, prob = c(0.20, 0.30, 0.50))
    }
  } else {
    # PBO arm
    if (pfs_months >= 6) {
      sample(c("PR", "SD", "PD"), 1L, prob = c(0.10, 0.55, 0.35))
    } else {
      sample(c("SD", "PD"),       1L, prob = c(0.35, 0.65))
    }
  }
}

# Per-visit size multiplier given response pattern and time
tumour_size_factor <- function(pattern, visit_day, pfs_days, baseline = 1.0) {
  # Shrinkage/growth rates (per day)
  shrink_rate <- switch(pattern,
    "CR"  = -0.012,   # rapid complete response
    "PR"  = -0.006,   # partial response
    "SD"  = -0.001,   # stable (slight shrinkage or flat)
    "PD"  =  0.005    # progressive disease
  )

  # After progression, growth accelerates
  if (visit_day > pfs_days && pattern != "PD") {
    # Progression: exponential regrowth after nadir
    nadir_factor <- exp(shrink_rate * pfs_days)
    regrowth_rate <- 0.006
    days_post_prog <- visit_day - pfs_days
    return(nadir_factor * exp(regrowth_rate * days_post_prog))
  }

  # Before progression: exponential decay (response) or growth (PD)
  factor <- exp(shrink_rate * visit_day)

  # CR: floor at near-zero (0.1mm = below detection)
  if (pattern == "CR" && visit_day > 60L) {
    factor <- pmax(factor, 0.001)   # near complete disappearance
  }

  factor
}

generate_tr <- function(subj) {
  c1d1       <- subj$C1D1_DATE
  pfs_days   <- subj$PFS_DAYS_RAW
  prog_date  <- subj$PROG_DATE
  obs_end    <- min(subj$OBS_OS_DATE, subj$DATA_CUTOFF)
  arm        <- subj$ARMCD

  # Get lesions for this subject
  subj_lesions <- lesion_map %>%
    filter(USUBJID == subj$USUBJID)

  if (nrow(subj_lesions) == 0L) return(NULL)

  target_lesions    <- subj_lesions %>% filter(TUCAT == "TARGET")
  nontarget_lesions <- subj_lesions %>% filter(TUCAT == "NON-TARGET")

  if (nrow(target_lesions) == 0L) return(NULL)

  # Assign subject-level response pattern
  pfs_months <- pfs_days / 30.4375
  response_pattern <- assign_response_pattern(arm, pfs_months)

  # Add small per-lesion variation in response
  lesion_response_adj <- rnorm(nrow(target_lesions), 0, 0.003)

  tr_recs <- list()
  seq_n   <- 0L

  # Determine which imaging visits this subject attended
  visit_days_vec  <- img_visits_base
  visit_names_vec <- names(img_visits_base)

  prev_new_lesion <- FALSE   # track if new lesion already declared

  sum_diam_records <- list()  # for TR sum of diameters

  for (vi in seq_along(visit_days_vec)) {
    vname    <- visit_names_vec[vi]
    vday_sched <- visit_days_vec[vi]
    vwindow  <- img_window[vi]

    # Apply window jitter
    vday_actual <- vday_sched + sample(-vwindow:vwindow, 1L)
    vdate       <- c1d1 + vday_actual - 1L

    if (vdate > obs_end) break  # past last contact

    # Include a small probability of missed imaging visit
    if (vday_sched > 42L && runif(1L) < 0.04) next  # 4% missed visit rate

    # ── Target lesion measurements ─────────────────────────────────────────
    sum_diam_this_visit <- 0.0

    for (li in seq_len(nrow(target_lesions))) {
      lesion <- target_lesions[li, ]
      bl_mm  <- lesion$BASELINE_MM[[1]]
      mtype  <- lesion$MEAS_TYPE[[1]]

      # Compute size factor for this visit
      per_lesion_rate_adj <- lesion_response_adj[li]
      adj_pattern <- response_pattern  # could vary per lesion

      sz_factor <- tumour_size_factor(adj_pattern, vday_actual, pfs_days)
      # Add small noise
      sz_factor <- sz_factor * exp(rnorm(1L, 0, 0.05))
      # Apply per-lesion adjustment
      sz_factor <- sz_factor * exp(per_lesion_rate_adj * vday_actual)
      sz_factor <- pmax(sz_factor, 0.001)

      meas_mm <- round(bl_mm * sz_factor, 1)

      # RECIST: if <5mm, record as 0 (too small to measure) for target
      # If CR (near zero for ≥2 visits), record as 0
      if (meas_mm < 5.0 && adj_pattern == "CR") meas_mm <- 0.0
      if (meas_mm < 1.0) meas_mm <- 0.0

      sum_diam_this_visit <- sum_diam_this_visit + meas_mm

      seq_n <- seq_n + 1L
      tr_recs[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "TR",
        USUBJID  = subj$USUBJID,
        TRSEQ    = seq_n,
        TRREFID  = lesion$TUREFID[[1]],
        TRLNKID  = lesion$TULNKID[[1]],
        TRTESTCD = mtype,
        TRTEST   = ifelse(mtype == "LDIAM", "Longest Diameter", "Perpendicular Diameter"),
        TRORRES  = as.character(meas_mm),
        TRORRESU = "mm",
        TRSTRESC = as.character(meas_mm),
        TRSTRESN = meas_mm,
        TRSTRESU = "mm",
        TRSTAT   = "",
        TRDTC    = format(vdate, "%Y-%m-%d"),
        TRDY     = vday_actual,
        VISIT    = vname,
        VISITNUM = vi,
        EPOCH    = "TREATMENT",
        TUCAT    = "TARGET",
        BASELINE_MM = bl_mm    # keep for % change calculation
      )
    }

    # ── Non-target lesion assessments ──────────────────────────────────────
    for (li in seq_len(nrow(nontarget_lesions))) {
      lesion <- nontarget_lesions[li, ]

      # Non-target: PRESENT / ABSENT / UNEQUIVOCAL PROGRESSION
      nt_result <- if (vday_actual > pfs_days * 1.05 &&
                       response_pattern == "PD") {
        sample(c("PRESENT", "UNEQUIVOCAL PROGRESSION"), 1L, prob = c(0.4, 0.6))
      } else if (vday_actual > pfs_days * 0.8) {
        sample(c("PRESENT", "ABSENT"), 1L, prob = c(0.7, 0.3))
      } else {
        sample(c("PRESENT", "ABSENT"), 1L, prob = c(0.6, 0.4))
      }

      seq_n <- seq_n + 1L
      tr_recs[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "TR",
        USUBJID  = subj$USUBJID,
        TRSEQ    = seq_n,
        TRREFID  = lesion$TUREFID[[1]],
        TRLNKID  = lesion$TULNKID[[1]],
        TRTESTCD = "TUMSTATE",
        TRTEST   = "Tumour State",
        TRORRES  = nt_result,
        TRORRESU = "",
        TRSTRESC = nt_result,
        TRSTRESN = NA_real_,
        TRSTRESU = "",
        TRSTAT   = "",
        TRDTC    = format(vdate, "%Y-%m-%d"),
        TRDY     = vday_actual,
        VISIT    = vname,
        VISITNUM = vi,
        EPOCH    = "TREATMENT",
        TUCAT    = "NON-TARGET",
        BASELINE_MM = NA_real_
      )
    }

    # ── Sum of Diameters record ────────────────────────────────────────────
    sum_diam_records[[vi]] <- tibble(
      USUBJID  = subj$USUBJID,
      VISIT    = vname,
      TRDTC    = format(vdate, "%Y-%m-%d"),
      TRDY     = vday_actual,
      SUM_DIAM = sum_diam_this_visit,
      RESPONSE_PATTERN = response_pattern
    )
  }

  # Compute percent change from baseline sum of diameters
  target_bl_sum <- sum(target_lesions$BASELINE_MM, na.rm = TRUE)

  non_null_sums <- Filter(Negate(is.null), sum_diam_records)
  if (length(non_null_sums) == 0L) {
    return(list(tr = NULL, sum = NULL))
  }

  sum_diam_df <- bind_rows(non_null_sums) %>%
    mutate(
      BL_SUM_DIAM  = target_bl_sum,
      PCT_CHANGE   = round(100 * (SUM_DIAM - target_bl_sum) / target_bl_sum, 1)
    )

  list(
    tr = if (length(tr_recs) > 0L) bind_rows(tr_recs) %>% mutate(TRSEQ = row_number()) else NULL,
    sum = sum_diam_df
  )
}

# Generate all TR records
tr_results <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map(generate_tr)

TR <- map_dfr(tr_results, ~ .x$tr)
TR_SUM <- map_dfr(tr_results, ~ .x$sum)

# Remove internal columns before writing SDTM
TR_sdtm <- TR %>%
  select(STUDYID, DOMAIN, USUBJID, TRSEQ, TRREFID, TRLNKID,
         TRTESTCD, TRTEST, TRORRES, TRORRESU,
         TRSTRESC, TRSTRESN, TRSTRESU, TRSTAT,
         TRDTC, TRDY, VISIT, VISITNUM, EPOCH)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(TR_sdtm, "sdtm/tr.parquet")
write.csv(TR_sdtm, "data-raw/raw_data/tr_raw.csv", row.names = FALSE, na = "")
write.csv(TR_SUM, "data-raw/raw_data/tr_sum_diam.csv", row.names = FALSE, na = "")

cat("\n=== TR Domain Validation ===\n")
cat(sprintf("  Total TR records        : %d\n", nrow(TR_sdtm)))
cat(sprintf("  Subjects with TR data   : %d / %d\n",
            n_distinct(TR_sdtm$USUBJID), nrow(backbone)))
cat(sprintf("  Target measurements     : %d\n",
            sum(TR_sdtm$TRTESTCD %in% c("LDIAM","LPERP"))))
cat(sprintf("  Non-target assessments  : %d\n",
            sum(TR_sdtm$TRTESTCD == "TUMSTATE")))
cat("\n  Sum of diameters % change distribution:\n")
cat(sprintf("    Median pct change : %.1f%%\n",
            median(TR_SUM$PCT_CHANGE, na.rm = TRUE)))
cat("\n  Response patterns assigned:\n")
print(TR_SUM %>% distinct(USUBJID, RESPONSE_PATTERN) %>%
        count(RESPONSE_PATTERN, sort = TRUE))
cat("\n  Outputs written:\n")
cat("    sdtm/tr.parquet\n")
cat("    data-raw/raw_data/tr_raw.csv\n")
cat("    data-raw/raw_data/tr_sum_diam.csv\n")
cat("=== TR generation complete ===\n")
