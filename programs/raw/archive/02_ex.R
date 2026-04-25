# =============================================================================
# torivumab guidelines loaded
# 02_ex.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: EX (Exposure)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(302)
# =============================================================================
#
# Outputs:
#   sdtm/ex.parquet              — SDTM EX domain (Parquet)
#   data-raw/raw_data/ex_raw.csv — Raw exposure records
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# Run after: 01_dm.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(302)

# ── Load backbone ──────────────────────────────────────────────────────────────
backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE      = as.Date(C1D1_DATE),
    LAST_DOSE_DATE = as.Date(LAST_DOSE_DATE),
    DATA_CUTOFF    = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Dosing constants ───────────────────────────────────────────────────────────
PROTOCOL_DOSE   <- 200.0   # mg (torivumab); placebo = 0 mg (recorded as 0 per SDTM)
DOSE_VOLUME_ML  <- 100.0   # mg/100 mL NS infusion
INFUSION_MIN    <- 30L     # 30-minute infusion (typical for anti-PD-1)
CYCLE_DAYS      <- 21L     # Q3W = every 21 days

# Dose reduction probabilities (torivumab only, per cycle — for grade ≥3 irAEs)
# ~8% of active subjects require dose hold; holds are recorded as separate records
P_DOSE_HOLD_PER_CYCLE <- 0.04   # 4% per cycle → ~8% of subjects over treatment
P_DOSE_PERM_DISC      <- 0.005  # 0.5% per cycle → permanent discontinuation for toxicity


# ── Generate EX records ────────────────────────────────────────────────────────
# One record per infusion visit (Q3W). For subjects who held a dose, the hold
# is recorded as a separate record with EXDOSE = 0 and EXDOSMOD = "DOSE NOT GIVEN".

generate_ex <- function(subj) {
  n_cycles <- subj$N_CYCLES
  if (n_cycles < 1L) {
    # Subject received no doses (edge case: withdrew before C1D1 — not expected here)
    return(NULL)
  }

  arm        <- subj$ARMCD
  c1d1       <- subj$C1D1_DATE
  last_dose  <- subj$LAST_DOSE_DATE
  cutoff     <- subj$DATA_CUTOFF

  # All scheduled dose dates (Day 1 of each cycle = C1D1 + (cycle-1)*21)
  dose_days  <- seq(0L, by = CYCLE_DAYS, length.out = n_cycles)
  dose_dates <- c1d1 + dose_days

  # Trim to last dose date (backbone already accounts for PFS/dropout/cutoff)
  dose_dates <- dose_dates[dose_dates <= last_dose + 3L]   # allow ±3 day window
  if (length(dose_dates) == 0L) return(NULL)

  # Add small visit window jitter (±3 days from scheduled date)
  # Screening visit (C1D1) is always Day 1; subsequent visits have ±3 day window
  jitter <- c(0L, sample(-3L:3L, length(dose_dates) - 1L, replace = TRUE))
  dose_dates_actual <- dose_dates + jitter

  n_doses <- length(dose_dates_actual)

  # Dose holds (torivumab arm only): random per-cycle with low probability
  held <- logical(n_doses)
  perm_disc <- FALSE
  if (arm == "TOR") {
    for (k in seq_len(n_doses)) {
      if (!perm_disc) {
        held[k] <- runif(1L) < P_DOSE_HOLD_PER_CYCLE
        if (!held[k] && runif(1L) < P_DOSE_PERM_DISC) {
          # Permanent discontinuation: remaining doses also "not given"
          if (k < n_doses) {
            held[(k + 1L):n_doses] <- TRUE
            perm_disc <- TRUE
          }
        }
      } else {
        held[k] <- TRUE
      }
    }
  }

  # Actual dose administered
  dose_vals <- if (arm == "TOR") {
    ifelse(held, 0.0, PROTOCOL_DOSE)
  } else {
    # Placebo: dose recorded as 0 per SDTM convention for masked studies
    rep(0.0, n_doses)
  }

  # Infusion start: dose_date at a realistic time (08:00 – 16:00)
  start_hour   <- sample(8L:16L, n_doses, replace = TRUE)
  start_minute <- sample(c(0L, 15L, 30L, 45L), n_doses, replace = TRUE)
  end_minute   <- start_minute + INFUSION_MIN
  end_hour     <- start_hour + end_minute %/% 60L
  end_minute   <- end_minute %% 60L

  # Format as ISO 8601 datetime
  ecstdtc <- sprintf("%s %02d:%02d",
                     format(dose_dates_actual, "%Y-%m-%d"),
                     start_hour, start_minute)
  ecendtc <- sprintf("%s %02d:%02d",
                     format(dose_dates_actual, "%Y-%m-%d"),
                     end_hour, end_minute)

  tibble(
    STUDYID    = STUDYID,
    DOMAIN     = "EX",
    USUBJID    = subj$USUBJID,
    EXSEQ      = seq_len(n_doses),
    EXTRT      = ifelse(arm == "TOR", "TORIVUMAB", "PLACEBO"),
    EXDOSE     = dose_vals,
    EXDOSU     = "mg",
    EXDOSFRM   = "SOLUTION FOR INFUSION",
    EXDOSFRQ   = "Q3W",
    EXROUTE    = "INTRAVENOUS",
    EXSTDTC    = ecstdtc,
    EXENDTC    = ecendtc,
    VISIT      = paste0("CYCLE ", seq_len(n_doses), " DAY 1"),
    VISITNUM   = as.numeric(seq_len(n_doses)),
    EPOCH      = ifelse(seq_len(n_doses) == 1L, "TREATMENT", "TREATMENT"),
    EXDOSEMOD  = ifelse(held, "DOSE NOT GIVEN", ""),
    # Calculated study day (relative to C1D1 = Day 1)
    EXSTDY     = as.integer(dose_dates_actual - c1d1) + 1L
  )
}

EX <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_ex)


# ── Write outputs ──────────────────────────────────────────────────────────────
dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(EX, "sdtm/ex.parquet")
write.csv(EX, "data-raw/raw_data/ex_raw.csv", row.names = FALSE, na = "")


# ── Validation ─────────────────────────────────────────────────────────────────
cat("\n=== EX Domain Validation ===\n")
cat(sprintf("  Total infusion records  : %d\n", nrow(EX)))
cat(sprintf("  Subjects with ≥1 record : %d (expected %d)\n",
            n_distinct(EX$USUBJID), nrow(backbone)))
cat(sprintf("  Dose holds (TOR arm)    : %d (%.1f%% of active doses)\n",
            sum(EX$EXDOSEMOD == "DOSE NOT GIVEN" & EX$EXTRT == "TORIVUMAB"),
            100 * sum(EX$EXDOSEMOD == "DOSE NOT GIVEN" & EX$EXTRT == "TORIVUMAB") /
              sum(EX$EXTRT == "TORIVUMAB")))
cat(sprintf("  Mean cycles (TOR)       : %.1f\n",
            mean(EX %>% filter(EXTRT == "TORIVUMAB") %>%
                   group_by(USUBJID) %>% tally() %>% pull(n))))
cat(sprintf("  Mean cycles (PBO)       : %.1f\n",
            mean(EX %>% filter(EXTRT == "PLACEBO") %>%
                   group_by(USUBJID) %>% tally() %>% pull(n))))
cat(sprintf("  EXSEQ unique per subj   : %s\n",
            ifelse(all(EX %>% group_by(USUBJID) %>%
                         summarise(ok = !any(duplicated(EXSEQ))) %>% pull(ok)),
                   "PASS", "FAIL")))
cat("\n  Outputs written:\n")
cat("    sdtm/ex.parquet\n")
cat("    data-raw/raw_data/ex_raw.csv\n")
cat("\n=== EX generation complete ===\n")
