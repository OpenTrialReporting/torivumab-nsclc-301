# =============================================================================
# torivumab guidelines loaded
# 06_mh.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: MH (Medical History)
# Standard: SDTMIG v3.4 | MedDRA v27.0
# Seed: set.seed(306)
# =============================================================================
#
# Outputs:
#   sdtm/mh.parquet              — SDTM MH domain (Parquet)
#   data-raw/raw_data/mh_raw.csv — Raw medical history records
#
# MH strategy:
#   - Comorbidities typical of first-line NSCLC patients (age ~64, smokers)
#   - Conditions present at screening (MHOCCUR = Y for active/historical)
#   - Autoimmune conditions → exclusion; none generated here
#   - Hypertension, COPD, cardiovascular, diabetes represent main categories
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

set.seed(306)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(C1D1_DATE = as.Date(C1D1_DATE))

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Medical history catalogue ──────────────────────────────────────────────────
# p_use: population prevalence in this patient type
# ongoing: T = still active at screening; F = historical
mh_catalogue <- tribble(
  ~mhterm,                       ~mhdecod,                      ~mhbodsys,                                        ~p_use, ~ongoing,
  "Hypertension",                "Hypertensive disorder",        "Vascular disorders",                              0.48,  TRUE,
  "COPD",                        "Chronic obstructive pulmonary disease", "Respiratory, thoracic and mediastinal disorders", 0.30, TRUE,
  "Type 2 diabetes mellitus",    "Type 2 diabetes mellitus",    "Metabolism and nutrition disorders",               0.20,  TRUE,
  "Hyperlipidaemia",             "Hyperlipidaemia",             "Metabolism and nutrition disorders",               0.35,  TRUE,
  "Gastro-oesophageal reflux",   "Gastro-oesophageal reflux disease", "Gastrointestinal disorders",                0.22,  TRUE,
  "Coronary artery disease",     "Coronary artery disease",     "Cardiac disorders",                                0.12,  TRUE,
  "Hypothyroidism",              "Hypothyroidism",              "Endocrine disorders",                              0.10,  TRUE,
  "Atrial fibrillation",         "Atrial fibrillation",         "Cardiac disorders",                                0.08,  TRUE,
  "Peripheral vascular disease", "Peripheral vascular disease", "Vascular disorders",                               0.06,  TRUE,
  "Osteoarthritis",              "Osteoarthritis",              "Musculoskeletal and connective tissue disorders",   0.18,  TRUE,
  "Depression",                  "Depressive disorder",         "Psychiatric disorders",                            0.12,  TRUE,
  "Chronic kidney disease",      "Chronic kidney disease",      "Renal and urinary disorders",                      0.08,  TRUE,
  "Myocardial infarction",       "Myocardial infarction",       "Cardiac disorders",                                0.08,  FALSE,  # historical
  "Pulmonary embolism",          "Pulmonary embolism",          "Vascular disorders",                               0.04,  FALSE,
  "Stroke",                      "Cerebrovascular accident",    "Nervous system disorders",                         0.04,  FALSE,
  "Appendicitis",                "Appendicitis",                "Gastrointestinal disorders",                       0.05,  FALSE
)

generate_mh <- function(subj) {
  c1d1    <- subj$C1D1_DATE
  mh_recs <- list()
  seq_n   <- 0L

  for (i in seq_len(nrow(mh_catalogue))) {
    cond <- mh_catalogue[i, ]
    if (runif(1L) > cond$p_use[[1]]) next

    seq_n <- seq_n + 1L

    # Onset: 1-20 years before C1D1
    onset_yrs  <- round(runif(1L, 1, 20), 1)
    onset_date <- c1d1 - round(onset_yrs * 365.25)

    # End date: historical conditions resolved; ongoing still active
    ongoing <- cond$ongoing[[1]]
    if (!ongoing) {
      # Historical: resolved 1-10 years ago
      resolve_yrs  <- round(runif(1L, 0.5, onset_yrs - 0.5), 1)
      end_date <- c1d1 - round(resolve_yrs * 365.25)
      mhoccur   <- "Y"
      mhenrtpt  <- "BEFORE"
    } else {
      end_date  <- NA_Date_
      mhoccur   <- "Y"
      mhenrtpt  <- "ONGOING"
    }

    mh_recs[[seq_n]] <- tibble(
      STUDYID  = STUDYID,
      DOMAIN   = "MH",
      USUBJID  = subj$USUBJID,
      MHSEQ    = seq_n,
      MHTERM   = cond$mhterm[[1]],
      MHDECOD  = cond$mhdecod[[1]],
      MHBODSYS = cond$mhbodsys[[1]],
      MHOCCUR  = mhoccur,
      MHSTDTC  = format(onset_date, "%Y-%m-%d"),
      MHENDTC  = ifelse(!is.na(end_date), format(end_date, "%Y-%m-%d"), ""),
      MHENRTPT = mhenrtpt,
      EPOCH    = "SCREENING"
    )
  }

  if (length(mh_recs) == 0L) return(NULL)
  bind_rows(mh_recs) %>% mutate(MHSEQ = row_number())
}

MH <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_mh)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(MH, "sdtm/mh.parquet")
write.csv(MH, "data-raw/raw_data/mh_raw.csv", row.names = FALSE, na = "")

cat("\n=== MH Domain Validation ===\n")
cat(sprintf("  Total MH records        : %d\n", nrow(MH)))
cat(sprintf("  Subjects with ≥1 MH     : %d / %d (%.0f%%)\n",
            n_distinct(MH$USUBJID), nrow(backbone),
            100 * n_distinct(MH$USUBJID) / nrow(backbone)))
cat("  Top conditions:\n")
print(MH %>% count(MHDECOD, sort = TRUE) %>% slice_head(n = 8))
cat("\n  Outputs written: sdtm/mh.parquet, data-raw/raw_data/mh_raw.csv\n")
cat("=== MH generation complete ===\n")
