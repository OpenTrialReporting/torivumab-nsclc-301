# =============================================================================
# torivumab guidelines loaded
# 07_su.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: SU (Substance Use — Tobacco)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(307)
# =============================================================================
#
# Outputs:
#   sdtm/su.parquet              — SDTM SU domain (Parquet)
#   data-raw/raw_data/su_raw.csv — Raw substance use records
#
# SU strategy:
#   - Tobacco use is the primary substance collected (NSCLC)
#   - All subjects must have smoking history (study inclusion: current/former smoker)
#   - SUTRT = "TOBACCO", SUCAT = "TOBACCO USE"
#   - SUOCCUR = Y for all (inclusion criterion)
#   - Smoking status: ~40% current, ~60% former (KEYNOTE-024 type population)
#   - Pack-years: current smokers 20-80 py; former smokers 15-70 py
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# Run after: 01_dm.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
})

set.seed(307)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(C1D1_DATE = as.Date(C1D1_DATE))

STUDYID <- "TORIVUMAB-NSCLC-301"

n <- nrow(backbone)

# Smoking status (all subjects are smokers per inclusion criteria)
# 40% current smoker, 60% former smoker (KEYNOTE-024: median ~75% former)
smoking_status <- ifelse(runif(n) < 0.38, "CURRENT SMOKER", "EX-SMOKER")

# Pack-years (normal distribution, range truncated)
py_mean <- ifelse(smoking_status == "CURRENT SMOKER", 42, 35)
pack_years <- pmax(round(rnorm(n, mean = py_mean, sd = 15), 1), 5.0)

# Smoking start age: 14-25 years old
start_age <- sample(14L:25L, n, replace = TRUE)

# For former smokers: quit 1-30 years ago
quit_years <- ifelse(smoking_status == "EX-SMOKER",
                     round(runif(n, 1, 30), 1), NA_real_)

# SUSTDTC: start of smoking (approximate year from age)
su_start_date <- backbone$C1D1_DATE -
  round((backbone$AGE - start_age) * 365.25)

# SUENDTC: quit date for former smokers
su_end_date <- ifelse(
  smoking_status == "EX-SMOKER",
  as.character(backbone$C1D1_DATE - round(quit_years * 365.25, 0)),
  NA_character_
)

SU <- tibble(
  STUDYID  = STUDYID,
  DOMAIN   = "SU",
  USUBJID  = backbone$USUBJID,
  SUSEQ    = 1L,
  SUTRT    = "TOBACCO",
  SUCAT    = "TOBACCO USE",
  SUOCCUR  = "Y",
  SUSTDTC  = format(su_start_date, "%Y-%m-%d"),
  SUENDTC  = su_end_date,
  SUENRTPT = ifelse(smoking_status == "CURRENT SMOKER", "ONGOING", ""),
  SUDOSE   = pack_years,     # pack-years as dose proxy
  SUDOSU   = "PACK-YEARS",
  EPOCH    = "SCREENING",
  # Supplemental: smoking status (SUPPSU) — stored inline for generation purposes
  # Will be moved to SUPPSU in domain assembly
  SMKSTAT  = smoking_status
)

# Split into SU core and SUPPSU
SU_core <- SU %>%
  select(STUDYID, DOMAIN, USUBJID, SUSEQ, SUTRT, SUCAT, SUOCCUR,
         SUSTDTC, SUENDTC, SUENRTPT, SUDOSE, SUDOSU, EPOCH)

SUPPSU <- SU %>%
  transmute(
    STUDYID  = STUDYID,
    RDOMAIN  = "SU",
    USUBJID  = USUBJID,
    IDVAR    = "SUSEQ",
    IDVARVAL = "1",
    QNAM     = "SMKSTAT",
    QLABEL   = "Smoking Status",
    QVAL     = SMKSTAT,
    QORIG    = "CRF",
    QEVAL    = ""
  )

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(SU_core, "sdtm/su.parquet")
write_parquet(SUPPSU,  "sdtm/suppsu.parquet")
write.csv(SU_core, "data-raw/raw_data/su_raw.csv", row.names = FALSE, na = "")

cat("\n=== SU Domain Validation ===\n")
cat(sprintf("  Total SU records        : %d (expected %d)\n", nrow(SU_core), nrow(backbone)))
cat(sprintf("  Current smokers         : %d (%.0f%%)\n",
            sum(SU$SMKSTAT == "CURRENT SMOKER"),
            100 * mean(SU$SMKSTAT == "CURRENT SMOKER")))
cat(sprintf("  Former smokers          : %d (%.0f%%)\n",
            sum(SU$SMKSTAT == "EX-SMOKER"),
            100 * mean(SU$SMKSTAT == "EX-SMOKER")))
cat(sprintf("  Median pack-years       : %.1f\n", median(SU$SUDOSE)))
cat("\n  Outputs written: sdtm/su.parquet, sdtm/suppsu.parquet, data-raw/raw_data/su_raw.csv\n")
cat("=== SU generation complete ===\n")
