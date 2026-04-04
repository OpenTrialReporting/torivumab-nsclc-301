# =============================================================================
# torivumab guidelines loaded
# 08_vs.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: VS (Vital Signs)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(308)
# =============================================================================
#
# Outputs:
#   sdtm/vs.parquet              — SDTM VS domain (Parquet)
#   data-raw/raw_data/vs_raw.csv — Raw vital signs records
#
# VS strategy:
#   - Collected at: Screening, C1D1, all dosing/EOC visits, imaging, EOT, FU
#   - Tests: HEIGHT (screening only), WEIGHT, SYSBP, DIABP, TEMP, PULSE, RESP
#   - Values drawn from realistic normal distributions (NSCLC population)
#   - ECOG PS generated here as a VS test (SDTMIG permits in VS or separate)
#     VSTESTCD = ECOG; VSTEST = "ECOG Performance Status"
#   - Weight may decrease slightly over time (disease progression pattern)
#   - Body temperature: ~1% febrile episodes (>38°C)
#
# Visit schedule (simplified):
#   SCR, C1D1, C1D8, C1D15, C1D22, C2D1, C2D22, every EOC thereafter,
#   IMG01-04 + Q12W, EOT, FU01-03
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

set.seed(308)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    OBS_OS_DATE = as.Date(OBS_OS_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Visit schedule (study days from C1D1) ─────────────────────────────────────
# Visits where VS are collected
visit_days <- c(
  SCR  = -14L,   C1D1  = 1L,   C1D8  = 8L,   C1D15 = 15L,
  C1D22 = 22L,  C2D1  = 22L,  C2D22 = 43L,
  C3D1  = 64L,  C3D22 = 85L,  C4D1  = 85L,  C4D22 = 106L,
  C5D1  = 106L, C5D22 = 127L,
  IMG01 = 42L,  IMG02 = 84L,  IMG03 = 126L, IMG04 = 168L,
  EOT   = 999L,  # placeholder — computed per subject
  FU01  = 1090L, FU02  = 1180L, FU03  = 1365L
)

visit_names <- names(visit_days)

# VS tests collected at each visit type
# HEIGHT: screening only; ECOG: screening, C1D1, every EOC and EOT, FU
vs_tests <- tribble(
  ~VSTESTCD, ~VSTEST,                  ~VSORRESU, ~mean_val, ~sd_val,  ~visits,
  "HEIGHT",  "Height",                 "cm",        168.0,    9.0,   "SCR",
  "WEIGHT",  "Weight",                 "kg",         72.0,   13.0,   "ALL",
  "SYSBP",   "Systolic Blood Pressure","mmHg",       128.0,   16.0,   "ALL",
  "DIABP",   "Diastolic Blood Pressure","mmHg",       80.0,   10.0,   "ALL",
  "TEMP",    "Temperature",            "C",           36.7,    0.4,   "ALL",
  "PULSE",   "Pulse Rate",             "beats/min",   76.0,   11.0,   "ALL",
  "RESP",    "Respiratory Rate",       "breaths/min", 17.0,    2.0,   "ALL",
  "ECOG",    "ECOG Performance Status","",             0.5,    0.5,   "ECOG"
)

# ECOG visits: SCR, C1D1, C1D22, C2D22, EOT, FU01, FU02, FU03
ecog_visits <- c("SCR", "C1D1", "C1D22", "C2D22", "C3D22", "C4D22",
                 "C5D22", "IMG01", "IMG02", "IMG03", "IMG04", "EOT",
                 "FU01", "FU02", "FU03")

generate_vs <- function(subj) {
  c1d1    <- subj$C1D1_DATE
  obs_end <- min(subj$OBS_OS_DATE, subj$DATA_CUTOFF)
  eot_day <- as.integer(subj$EOT_DATE - c1d1) + 1L

  vs_recs <- list()
  seq_n   <- 0L

  # Subject-level baseline demographics for realistic distributions
  # Sex-adjusted height and weight
  is_male  <- subj$SEX == "M"
  h_mean   <- ifelse(is_male, 173.0, 161.0)
  w_mean   <- ifelse(is_male,  78.0,  65.0)
  subj_ht  <- round(rnorm(1L, h_mean, 8.0), 1)
  subj_wt0 <- round(rnorm(1L, w_mean, 12.0), 1)
  subj_sbp <- round(rnorm(1L, 128.0, 14.0))
  subj_dbp <- round(rnorm(1L,  80.0,  9.0))

  # Assign visits up to obs_end
  visits_to_gen <- names(visit_days)

  for (vname in visits_to_gen) {
    vday <- if (vname == "EOT") eot_day else visit_days[[vname]]
    vdate <- c1d1 + vday - 1L  # study day → calendar date

    if (vdate > obs_end) next

    # Add small date jitter (windows) except SCR and C1D1
    if (!vname %in% c("SCR", "C1D1")) {
      jitter <- sample(-3L:3L, 1L)
      vdate  <- vdate + jitter
      if (vdate > obs_end) next
    }

    # Weight trend: slight decline after progression
    prog_date <- as.Date(subj$PROG_DATE)
    days_on   <- as.integer(vdate - c1d1)
    wt_decline <- ifelse(vdate > prog_date,
                         0.02 * as.integer(vdate - prog_date) / 30,
                         0.0)
    subj_wt <- pmax(round(subj_wt0 * (1 - wt_decline) +
                             rnorm(1L, 0, 1.2), 1), 35.0)

    # For each VS test at this visit
    for (j in seq_len(nrow(vs_tests))) {
      test <- vs_tests[j, ]

      # Height: screening only
      if (test$VSTESTCD[[1]] == "HEIGHT" && vname != "SCR") next

      # ECOG: only at ECOG visits
      if (test$VSTESTCD[[1]] == "ECOG" && !vname %in% ecog_visits) next

      # Standard VS: all visits
      if (test$visits[[1]] == "SCR" && vname != "SCR") next

      # Determine value
      val <- switch(test$VSTESTCD[[1]],
        "HEIGHT" = subj_ht,
        "WEIGHT" = subj_wt,
        "SYSBP"  = round(subj_sbp + rnorm(1L, 0, 4.0)),
        "DIABP"  = round(subj_dbp + rnorm(1L, 0, 3.0)),
        "TEMP"   = {
          t <- round(rnorm(1L, 36.7, 0.35), 1)
          # 1% chance of fever
          if (runif(1L) < 0.01) t <- round(runif(1L, 38.0, 39.5), 1)
          t
        },
        "PULSE"  = round(rnorm(1L, 76.0, 10.0)),
        "RESP"   = round(rnorm(1L, 17.0, 2.0)),
        "ECOG"   = {
          # ECOG tends to worsen after progression
          base_ecog <- if (vname == "SCR") sample(c(0L, 1L), 1L, prob = c(0.6, 0.4)) else NULL
          if (!is.null(base_ecog)) {
            base_ecog
          } else {
            days_post_prog <- pmax(as.integer(vdate - prog_date), 0L)
            p_ecog2 <- min(0.05 + days_post_prog * 0.001, 0.35)
            sample(c(0L, 1L, 2L), 1L, prob = c(0.45 - p_ecog2/2,
                                                 0.45 - p_ecog2/2,
                                                 p_ecog2))
          }
        }
      )

      seq_n <- seq_n + 1L

      vs_recs[[seq_n]] <- tibble(
        STUDYID   = STUDYID,
        DOMAIN    = "VS",
        USUBJID   = subj$USUBJID,
        VSSEQ     = seq_n,
        VSTESTCD  = test$VSTESTCD[[1]],
        VSTEST    = test$VSTEST[[1]],
        VSORRES   = as.character(val),
        VSORRESU  = test$VSORRESU[[1]],
        VSSTRESC  = as.character(val),
        VSSTRESN  = as.numeric(val),
        VSSTRESU  = test$VSORRESU[[1]],
        VSDTC     = format(vdate, "%Y-%m-%d"),
        VSDY      = as.integer(vdate - c1d1) + 1L,
        VISIT     = vname,
        VISITNUM  = which(visit_names == vname)[1L],
        EPOCH     = ifelse(vdate < c1d1, "SCREENING",
                           ifelse(vdate > as.Date(subj$EOT_DATE), "FOLLOW-UP",
                                  "TREATMENT"))
      )
    }
  }

  if (length(vs_recs) == 0L) return(NULL)
  bind_rows(vs_recs) %>% mutate(VSSEQ = row_number())
}

VS <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_vs)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(VS, "sdtm/vs.parquet")
write.csv(VS, "data-raw/raw_data/vs_raw.csv", row.names = FALSE, na = "")

cat("\n=== VS Domain Validation ===\n")
cat(sprintf("  Total VS records        : %d\n", nrow(VS)))
cat(sprintf("  Subjects with VS data   : %d / %d\n",
            n_distinct(VS$USUBJID), nrow(backbone)))
cat(sprintf("  VS tests generated      : %s\n",
            paste(sort(unique(VS$VSTESTCD)), collapse = ", ")))
cat(sprintf("  Mean weight (kg)        : %.1f\n",
            mean(VS$VSSTRESN[VS$VSTESTCD == "WEIGHT"], na.rm = TRUE)))
cat(sprintf("  Mean SBP (mmHg)         : %.1f\n",
            mean(VS$VSSTRESN[VS$VSTESTCD == "SYSBP"], na.rm = TRUE)))
cat("\n  Outputs written: sdtm/vs.parquet, data-raw/raw_data/vs_raw.csv\n")
cat("=== VS generation complete ===\n")
