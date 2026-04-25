# =============================================================================
# torivumab guidelines loaded
# 03_ds.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: DS (Disposition)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(303)
# =============================================================================
#
# Outputs:
#   sdtm/ds.parquet              — SDTM DS domain (Parquet)
#   data-raw/raw_data/ds_raw.csv — Raw disposition records
#
# Key DS records generated per subject:
#   1. INFORMED CONSENT (Screening)
#   2. RANDOMIZED (C1D1)
#   3. COMPLETED / DISCONTINUED (EOT) — with reason
#   4. COMPLETED FOLLOW-UP (FU03 or LTFU — if reached)
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

set.seed(303)

# ── Load backbone ──────────────────────────────────────────────────────────────
backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE      = as.Date(C1D1_DATE),
    RFICDTC_DATE   = as.Date(RFICDTC_DATE),
    LAST_DOSE_DATE = as.Date(LAST_DOSE_DATE),
    EOT_DATE       = as.Date(EOT_DATE),
    OBS_OS_DATE    = as.Date(OBS_OS_DATE),
    PROG_DATE      = as.Date(PROG_DATE),
    DROPOUT_DATE   = as.Date(DROPOUT_DATE),
    DATA_CUTOFF    = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Discontinuation reason probabilities ────────────────────────────────────────
# Reasons for EOT (% among those who discontinued early, not completed all 35 cycles)
# Per KEYNOTE-024 and typical anti-PD-1 trial patterns:
disc_reasons_tor <- c(
  "DISEASE PROGRESSION"         = 0.55,
  "ADVERSE EVENT"               = 0.18,
  "SUBJECT WITHDREW CONSENT"    = 0.08,
  "PHYSICIAN DECISION"          = 0.06,
  "DEATH"                       = 0.05,
  "PROTOCOL DEVIATION"          = 0.04,
  "LOST TO FOLLOW-UP"           = 0.02,
  "OTHER"                       = 0.02
)
disc_reasons_pbo <- c(
  "DISEASE PROGRESSION"         = 0.68,
  "ADVERSE EVENT"               = 0.10,
  "SUBJECT WITHDREW CONSENT"    = 0.08,
  "PHYSICIAN DECISION"          = 0.05,
  "DEATH"                       = 0.04,
  "PROTOCOL DEVIATION"          = 0.03,
  "LOST TO FOLLOW-UP"           = 0.01,
  "OTHER"                       = 0.01
)

# CDISC CT NCOMPLT decode mappings (SDTMIG DSDECOD)
disc_decode <- c(
  "DISEASE PROGRESSION"         = "PROGRESSIVE DISEASE",
  "ADVERSE EVENT"               = "ADVERSE EVENT",
  "SUBJECT WITHDREW CONSENT"    = "WITHDRAWAL BY SUBJECT",
  "PHYSICIAN DECISION"          = "PHYSICIAN DECISION",
  "DEATH"                       = "DEATH",
  "PROTOCOL DEVIATION"          = "PROTOCOL DEVIATION",
  "LOST TO FOLLOW-UP"           = "LOST TO FOLLOW-UP",
  "OTHER"                       = "OTHER"
)

# DS categories (DSSCAT)
DSCAT_PROTOCOL   <- "PROTOCOL MILESTONE"
DSCAT_DISC       <- "STUDY DISCONTINUATION"
DSCAT_FU         <- "FOLLOW-UP"

# ── Generate DS records ────────────────────────────────────────────────────────
generate_ds <- function(subj) {
  records <- list()
  seq_n   <- 0L

  # ── Record 1: Informed consent ──────────────────────────────────────────────
  seq_n <- seq_n + 1L
  records[[seq_n]] <- tibble(
    STUDYID  = STUDYID,
    DOMAIN   = "DS",
    USUBJID  = subj$USUBJID,
    DSSEQ    = seq_n,
    DSTERM   = "INFORMED CONSENT OBTAINED",
    DSDECOD  = "INFORMED CONSENT OBTAINED",
    DSCAT    = DSCAT_PROTOCOL,
    DSSCAT   = "",
    DSSTDTC  = format(subj$RFICDTC_DATE, "%Y-%m-%d"),
    DSENDTC  = "",
    EPOCH    = "SCREENING",
    VISITNUM = 0.0,
    VISIT    = "SCREENING"
  )

  # ── Record 2: Randomised ────────────────────────────────────────────────────
  seq_n <- seq_n + 1L
  records[[seq_n]] <- tibble(
    STUDYID  = STUDYID,
    DOMAIN   = "DS",
    USUBJID  = subj$USUBJID,
    DSSEQ    = seq_n,
    DSTERM   = "RANDOMIZED",
    DSDECOD  = "RANDOMIZED",
    DSCAT    = DSCAT_PROTOCOL,
    DSSCAT   = "",
    DSSTDTC  = format(subj$C1D1_DATE, "%Y-%m-%d"),
    DSENDTC  = "",
    EPOCH    = "TREATMENT",
    VISITNUM = 1.0,
    VISIT    = "CYCLE 1 DAY 1"
  )

  # ── Record 3: EOT (completed or discontinued) ───────────────────────────────
  max_treat_days <- 35L * 21L
  treatment_days <- subj$LAST_DOSE_DAYS + 30L  # approx EOT = last dose + 30 d

  # Determine whether subject completed protocol treatment
  # "Completed" = reached max cycles (35) AND no early discontinuation
  prog_days    <- as.integer(subj$PROG_DATE    - subj$C1D1_DATE)
  dropout_days <- as.integer(subj$DROPOUT_DATE - subj$C1D1_DATE)
  cutoff_days  <- as.integer(subj$DATA_CUTOFF  - subj$C1D1_DATE)

  completed_35_cycles <- subj$N_CYCLES >= 35L
  eot_date <- subj$EOT_DATE

  if (completed_35_cycles) {
    disc_reason <- "COMPLETED"
    disc_decode_val <- "COMPLETED"
    dscat_eot   <- DSCAT_PROTOCOL
  } else {
    # Determine primary discontinuation reason
    arm <- subj$ARMCD
    if (arm == "TOR") {
      disc_reason <- sample(names(disc_reasons_tor), 1L,
                            prob = disc_reasons_tor)
    } else {
      disc_reason <- sample(names(disc_reasons_pbo), 1L,
                            prob = disc_reasons_pbo)
    }
    disc_decode_val <- disc_decode[[disc_reason]]
    dscat_eot   <- DSCAT_DISC
  }

  seq_n <- seq_n + 1L
  records[[seq_n]] <- tibble(
    STUDYID  = STUDYID,
    DOMAIN   = "DS",
    USUBJID  = subj$USUBJID,
    DSSEQ    = seq_n,
    DSTERM   = disc_reason,
    DSDECOD  = disc_decode_val,
    DSCAT    = dscat_eot,
    DSSCAT   = ifelse(completed_35_cycles, "COMPLETED TREATMENT", "DISCONTINUED"),
    DSSTDTC  = format(eot_date, "%Y-%m-%d"),
    DSENDTC  = "",
    EPOCH    = "TREATMENT",
    VISITNUM = 99.0,
    VISIT    = "END OF TREATMENT"
  )

  # ── Record 4: Follow-up milestones ──────────────────────────────────────────
  # FU-01 (Month 3 post-EOT): if subject survived to that point
  fu_dates <- list(
    list(visit = "FOLLOW-UP VISIT 1", visitnum = 100.0, offset = 90L,  epoch = "FOLLOW-UP"),
    list(visit = "FOLLOW-UP VISIT 2", visitnum = 101.0, offset = 180L, epoch = "FOLLOW-UP"),
    list(visit = "FOLLOW-UP VISIT 3", visitnum = 102.0, offset = 365L, epoch = "FOLLOW-UP")
  )

  for (fu in fu_dates) {
    fu_date <- eot_date + fu$offset
    # Only generate FU record if subject was alive at that time point
    # (OBS_OS_DATE reflects last contact/death)
    if (fu_date <= subj$OBS_OS_DATE && fu_date <= subj$DATA_CUTOFF) {
      seq_n <- seq_n + 1L
      records[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "DS",
        USUBJID  = subj$USUBJID,
        DSSEQ    = seq_n,
        DSTERM   = "FOLLOW-UP VISIT COMPLETED",
        DSDECOD  = "COMPLETED",
        DSCAT    = DSCAT_FU,
        DSSCAT   = "OFF-TREATMENT FOLLOW-UP",
        DSSTDTC  = format(fu_date, "%Y-%m-%d"),
        DSENDTC  = "",
        EPOCH    = fu$epoch,
        VISITNUM = fu$visitnum,
        VISIT    = fu$visit
      )
    }
  }

  # ── Record 5: Death (if applicable) ─────────────────────────────────────────
  if (!is.na(subj$DEATH_DATE) && subj$DEATH_DATE != "") {
    death_date <- as.Date(subj$DEATH_DATE)
    if (death_date <= subj$DATA_CUTOFF) {
      seq_n <- seq_n + 1L
      records[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "DS",
        USUBJID  = subj$USUBJID,
        DSSEQ    = seq_n,
        DSTERM   = "DEATH",
        DSDECOD  = "DEATH",
        DSCAT    = DSCAT_DISC,
        DSSCAT   = "DEATH",
        DSSTDTC  = format(death_date, "%Y-%m-%d"),
        DSENDTC  = "",
        EPOCH    = ifelse(death_date <= subj$EOT_DATE + 30L, "TREATMENT",
                          "FOLLOW-UP"),
        VISITNUM = 999.0,
        VISIT    = "UNSCHEDULED"
      )
    }
  }

  bind_rows(records)
}

DS <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_ds) %>%
  # Re-sequence DSSEQ within subject after combining
  group_by(USUBJID) %>%
  mutate(DSSEQ = row_number()) %>%
  ungroup() %>%
  arrange(USUBJID, DSSEQ)


# ── Write outputs ──────────────────────────────────────────────────────────────
dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(DS, "sdtm/ds.parquet")
write.csv(DS, "data-raw/raw_data/ds_raw.csv", row.names = FALSE, na = "")


# ── Validation ─────────────────────────────────────────────────────────────────
cat("\n=== DS Domain Validation ===\n")
cat(sprintf("  Total DS records        : %d\n", nrow(DS)))
cat(sprintf("  Subjects with IC record : %d (expected %d)\n",
            sum(DS$DSTERM == "INFORMED CONSENT OBTAINED"),
            nrow(backbone)))
cat(sprintf("  Subjects randomised     : %d (expected %d)\n",
            sum(DS$DSTERM == "RANDOMIZED"),
            nrow(backbone)))
cat(sprintf("  EOT records             : %d (expected %d)\n",
            sum(DS$VISIT  == "END OF TREATMENT"),
            nrow(backbone)))
cat(sprintf("  Deaths recorded in DS   : %d\n",
            sum(DS$DSTERM == "DEATH")))
cat(sprintf("  Discontinuation reasons (EOT):\n"))
eot_reasons <- DS %>%
  filter(VISIT == "END OF TREATMENT") %>%
  count(DSDECOD) %>%
  mutate(pct = round(100 * n / sum(n), 1))
print(eot_reasons)
cat("\n  Outputs written:\n")
cat("    sdtm/ds.parquet\n")
cat("    data-raw/raw_data/ds_raw.csv\n")
cat("\n=== DS generation complete ===\n")
