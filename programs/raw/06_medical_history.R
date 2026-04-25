###############################################################################
# 06_medical_history.R
# Generates raw/medical_history.csv
# Realistic comorbidities for an NSCLC patient population
# Depends on: demographics, rand_dates
###############################################################################

message("  Simulating medical history...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

# ── condition pools ────────────────────────────────────────────────────────
# Common comorbidities in NSCLC (lung cancer) population
always_pool <- c(
  "Non-small cell lung cancer",
  "Lung carcinoma",
  "Primary lung malignancy"
)

cardio_pool <- c(
  "Hypertension", "Essential hypertension", "High blood pressure",
  "Coronary artery disease", "Ischaemic heart disease",
  "Atrial fibrillation", "Cardiac arrhythmia",
  "Heart failure", "Congestive cardiac failure",
  "Hyperlipidaemia", "Dyslipidaemia", "Hypercholesterolaemia"
)

pulm_pool <- c(
  "Chronic obstructive pulmonary disease", "COPD",
  "Emphysema", "Chronic bronchitis",
  "Asthma", "Bronchial asthma",
  "Pulmonary fibrosis", "Interstitial lung disease"
)

metabolic_pool <- c(
  "Type 2 diabetes mellitus", "Diabetes mellitus",
  "Hypothyroidism", "Thyroid disorder",
  "Obesity", "Overweight",
  "Gout", "Hyperuricaemia"
)

gi_pool <- c(
  "Gastro-oesophageal reflux disease", "GERD",
  "Peptic ulcer disease", "Gastric ulcer",
  "Irritable bowel syndrome"
)

other_pool <- c(
  "Osteoporosis", "Osteoarthritis", "Rheumatoid arthritis",
  "Chronic kidney disease", "Renal impairment",
  "Anxiety disorder", "Depression", "Major depressive disorder",
  "Migraine", "Headache disorder",
  "Deep vein thrombosis", "Pulmonary embolism",
  "Anaemia", "Iron deficiency anaemia",
  "Peripheral neuropathy",
  "Alcohol use disorder",
  "Hepatitis B", "Hepatitis C"
)

verbatim_variants <- function(term) {
  # Small variation to simulate free-text entry
  mods <- c(
    function(t) t,
    function(t) tolower(t),
    function(t) tools::toTitleCase(tolower(t)),
    function(t) paste0(t, " (controlled)"),
    function(t) paste0(t, " (stable)"),
    function(t) paste0("history of ", tolower(t)),
    function(t) paste0("known ", tolower(t))
  )
  sample(mods, 1)[[1]](term)
}

mhist_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id  <- dm$SUBJECT_ID[i]
  rand_dt  <- rand_dates[i]
  smoking  <- dm$SMOKING_STATUS[i]
  ecog     <- dm$ECOG_BASELINE[i]

  rows <- list()

  # Primary diagnosis (always present)
  primary_cond <- sample(always_pool, 1)
  onset_yr <- rand_dt - sample(30:730, 1)   # 1 month to 2 years before rand
  rows[[length(rows) + 1]] <- data.frame(
    SUBJECT_ID        = subj_id,
    CONDITION_VERBATIM = verbatim_variants(primary_cond),
    ONSET_DATE        = format(onset_yr, "%Y-%m"),
    STATUS            = "Active",
    PREEXISTING       = "Y",
    stringsAsFactors  = FALSE
  )

  # Cardiovascular (common in this age group)
  if (runif(1) < 0.60) {
    n_cv <- sample(1:3, 1, prob = c(0.55, 0.30, 0.15))
    cv_terms <- sample(cardio_pool, n_cv)
    for (cond in cv_terms) {
      onset_y <- rand_dt - sample(365:(365*15), 1)
      status  <- sample(c("Active", "Resolved"), 1, prob = c(0.80, 0.20))
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID        = subj_id,
        CONDITION_VERBATIM = verbatim_variants(cond),
        ONSET_DATE        = format(onset_y, "%Y"),
        STATUS            = status,
        PREEXISTING       = "Y",
        stringsAsFactors  = FALSE
      )
    }
  }

  # Pulmonary (especially smokers/ex-smokers)
  pulm_p <- if (smoking %in% c("Current", "Former")) 0.55 else 0.20
  if (runif(1) < pulm_p) {
    cond <- sample(pulm_pool, 1)
    onset_y <- rand_dt - sample(365:(365*10), 1)
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID        = subj_id,
      CONDITION_VERBATIM = verbatim_variants(cond),
      ONSET_DATE        = format(onset_y, "%Y"),
      STATUS            = "Active",
      PREEXISTING       = "Y",
      stringsAsFactors  = FALSE
    )
  }

  # Metabolic
  if (runif(1) < 0.40) {
    n_met <- sample(1:2, 1, prob = c(0.70, 0.30))
    met_terms <- sample(metabolic_pool, n_met)
    for (cond in met_terms) {
      onset_y <- rand_dt - sample(365:(365*10), 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID        = subj_id,
        CONDITION_VERBATIM = verbatim_variants(cond),
        ONSET_DATE        = format(onset_y, "%Y"),
        STATUS            = "Active",
        PREEXISTING       = "Y",
        stringsAsFactors  = FALSE
      )
    }
  }

  # GI
  if (runif(1) < 0.25) {
    cond <- sample(gi_pool, 1)
    onset_y <- rand_dt - sample(365:(365*8), 1)
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID        = subj_id,
      CONDITION_VERBATIM = verbatim_variants(cond),
      ONSET_DATE        = format(onset_y, "%Y"),
      STATUS            = sample(c("Active", "Resolved"), 1, prob = c(0.60, 0.40)),
      PREEXISTING       = "Y",
      stringsAsFactors  = FALSE
    )
  }

  # Other
  n_other <- sample(0:3, 1, prob = c(0.20, 0.40, 0.30, 0.10))
  if (n_other > 0) {
    other_terms <- sample(other_pool, n_other)
    for (cond in other_terms) {
      onset_y <- rand_dt - sample(365:(365*12), 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID        = subj_id,
        CONDITION_VERBATIM = verbatim_variants(cond),
        ONSET_DATE        = format(onset_y, "%Y"),
        STATUS            = sample(c("Active", "Resolved"), 1, prob = c(0.65, 0.35)),
        PREEXISTING       = "Y",
        stringsAsFactors  = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    mhist_list[[i]] <- do.call(rbind, rows)
  }
}

medical_history <- do.call(rbind, Filter(Negate(is.null), mhist_list))
row.names(medical_history) <- NULL

assign("medical_history", medical_history, envir = .GlobalEnv)

write.csv(medical_history,
          file      = file.path(RAW_DIR, "medical_history.csv"),
          row.names = FALSE,
          na        = "")

message("  medical_history.csv written: ", nrow(medical_history), " rows")
