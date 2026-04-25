# =============================================================================
# torivumab guidelines loaded
# 04_ae.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: AE (Adverse Events)
# Standard: SDTMIG v3.4 | MedDRA v27.0 | CTCAE v5.0
# Seed: set.seed(304)
# =============================================================================
#
# Outputs:
#   sdtm/ae.parquet              — SDTM AE domain (Parquet)
#   data-raw/raw_data/ae_raw.csv — Raw AE records
#
# AE generation strategy:
#   - Rate and severity reflect published anti-PD-1 NSCLC safety data
#   - irAEs (immune-related) more frequent in torivumab arm
#   - Chemotherapy-type AEs (nausea, fatigue) similar across arms
#   - MedDRA v27.0 PT and SOC terms (synthetic, simplified)
#   - CTCAE v5.0 Grade 1-5 distribution per event type
#   - Relatedness: irAEs ~ 70% related in TOR arm; others ~ 10%
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

set.seed(304)

# ── Load backbone ──────────────────────────────────────────────────────────────
backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE      = as.Date(C1D1_DATE),
    LAST_DOSE_DATE = as.Date(LAST_DOSE_DATE),
    EOT_DATE       = as.Date(EOT_DATE),
    OBS_OS_DATE    = as.Date(OBS_OS_DATE),
    DATA_CUTOFF    = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── AE event catalogue ─────────────────────────────────────────────────────────
# Columns:
#   aeterm     : verbatim term (AETERM)
#   aedecod    : MedDRA Preferred Term (AEDECOD)
#   aebodsys   : MedDRA SOC (AEBODSYS)
#   aesoc      : MedDRA SOC (same as AEBODSYS for primary SOC)
#   is_irae    : immune-related (more frequent in TOR arm)
#   p_tor      : probability per subject-treatment (TOR arm)
#   p_pbo      : probability per subject-treatment (PBO arm)
#   grade_probs: list of Grade 1-5 probabilities (CTCAE v5.0)
#   rel_probs  : P(related) in [TOR, PBO]
#   p_serious  : P(SAE) conditional on event occurring
#   resolves   : P(AE resolves within 30-90 days)

ae_catalogue <- tribble(
  ~aeterm,                            ~aedecod,                              ~aebodsys,                                            ~is_irae, ~p_tor, ~p_pbo, ~grade_probs,            ~rel_p_tor, ~rel_p_pbo, ~p_serious, ~resolves,
  "Fatigue",                          "Fatigue",                             "General disorders and administration site conditions", FALSE,   0.60,  0.55,  c(.50,.35,.12,.02,.01),   0.30, 0.10,  0.02,  0.85,
  "Decreased appetite",               "Decreased appetite",                  "Metabolism and nutrition disorders",                   FALSE,   0.30,  0.28,  c(.55,.35,.08,.02,0),     0.25, 0.10,  0.02,  0.80,
  "Nausea",                           "Nausea",                              "Gastrointestinal disorders",                          FALSE,   0.25,  0.23,  c(.60,.30,.08,.02,0),     0.20, 0.10,  0.01,  0.90,
  "Cough",                            "Cough",                               "Respiratory, thoracic and mediastinal disorders",     FALSE,   0.22,  0.20,  c(.65,.28,.06,.01,0),     0.15, 0.10,  0.01,  0.75,
  "Dyspnoea",                         "Dyspnoea",                            "Respiratory, thoracic and mediastinal disorders",     FALSE,   0.28,  0.30,  c(.40,.40,.15,.04,.01),   0.20, 0.15,  0.08,  0.70,
  "Pruritus",                         "Pruritus",                            "Skin and subcutaneous tissue disorders",               TRUE,    0.20,  0.05,  c(.65,.28,.06,.01,0),     0.75, 0.15,  0.01,  0.88,
  "Rash",                             "Rash",                                "Skin and subcutaneous tissue disorders",               TRUE,    0.18,  0.04,  c(.55,.30,.12,.03,0),     0.80, 0.15,  0.02,  0.85,
  "Diarrhoea",                        "Diarrhoea",                           "Gastrointestinal disorders",                          TRUE,    0.18,  0.08,  c(.50,.30,.15,.04,.01),   0.65, 0.15,  0.04,  0.85,
  "Hypothyroidism",                   "Hypothyroidism",                      "Endocrine disorders",                                  TRUE,    0.12,  0.02,  c(.30,.45,.20,.05,0),     0.85, 0.10,  0.02,  0.40,
  "Hyperthyroidism",                  "Hyperthyroidism",                      "Endocrine disorders",                                  TRUE,    0.06,  0.01,  c(.35,.40,.20,.05,0),     0.85, 0.10,  0.02,  0.50,
  "Pneumonitis",                      "Pneumonitis",                         "Respiratory, thoracic and mediastinal disorders",     TRUE,    0.06,  0.01,  c(.15,.30,.35,.15,.05),   0.85, 0.10,  0.30,  0.75,
  "Colitis",                          "Colitis",                             "Gastrointestinal disorders",                          TRUE,    0.04,  0.005, c(.20,.30,.35,.12,.03),   0.85, 0.10,  0.20,  0.80,
  "Hepatitis",                        "Hepatitis",                           "Hepatobiliary disorders",                              TRUE,    0.04,  0.005, c(.20,.35,.30,.12,.03),   0.85, 0.10,  0.25,  0.75,
  "Peripheral neuropathy",            "Peripheral neuropathy",               "Nervous system disorders",                            FALSE,   0.08,  0.06,  c(.50,.30,.15,.05,0),     0.20, 0.10,  0.03,  0.65,
  "Arthralgia",                       "Arthralgia",                          "Musculoskeletal and connective tissue disorders",      TRUE,    0.12,  0.04,  c(.55,.30,.12,.03,0),     0.70, 0.15,  0.02,  0.80,
  "Anaemia",                          "Anaemia",                             "Blood and lymphatic system disorders",                 FALSE,   0.20,  0.18,  c(.40,.35,.20,.04,.01),   0.20, 0.15,  0.05,  0.75,
  "Neutropenia",                      "Neutropenia",                         "Blood and lymphatic system disorders",                 FALSE,   0.08,  0.07,  c(.25,.30,.30,.12,.03),   0.20, 0.15,  0.10,  0.85,
  "Infusion-related reaction",        "Infusion related reaction",           "Immune system disorders",                              TRUE,    0.06,  0.02,  c(.55,.30,.12,.03,0),     0.90, 0.40,  0.05,  0.95,
  "Headache",                         "Headache",                            "Nervous system disorders",                            FALSE,   0.12,  0.10,  c(.65,.28,.06,.01,0),     0.20, 0.10,  0.01,  0.90,
  "Back pain",                        "Back pain",                           "Musculoskeletal and connective tissue disorders",      FALSE,   0.10,  0.09,  c(.55,.30,.12,.03,0),     0.15, 0.10,  0.02,  0.80,
  "Oedema peripheral",                "Oedema peripheral",                   "General disorders and administration site conditions", FALSE,   0.09,  0.08,  c(.55,.30,.12,.03,0),     0.15, 0.10,  0.02,  0.75,
  "Hyponatraemia",                    "Hyponatraemia",                       "Metabolism and nutrition disorders",                   TRUE,    0.05,  0.02,  c(.25,.35,.28,.10,.02),   0.60, 0.20,  0.12,  0.80,
  "Aspartate aminotransferase increased", "Aspartate aminotransferase increased", "Investigations",                               TRUE,    0.07,  0.02,  c(.30,.35,.25,.08,.02),   0.80, 0.20,  0.05,  0.85,
  "Alanine aminotransferase increased",   "Alanine aminotransferase increased",   "Investigations",                               TRUE,    0.07,  0.02,  c(.30,.35,.25,.08,.02),   0.80, 0.20,  0.05,  0.85,
  "Pyrexia",                          "Pyrexia",                             "General disorders and administration site conditions", FALSE,   0.10,  0.08,  c(.60,.28,.10,.02,0),     0.25, 0.10,  0.04,  0.92,
  "Constipation",                     "Constipation",                        "Gastrointestinal disorders",                          FALSE,   0.10,  0.09,  c(.65,.28,.06,.01,0),     0.15, 0.10,  0.01,  0.85
)

# CTCAE grade → AESEV mapping
grade_to_sev <- c("1" = "MILD", "2" = "MODERATE", "3" = "SEVERE",
                  "4" = "SEVERE", "5" = "FATAL")


# ── Generate AE records ────────────────────────────────────────────────────────
generate_ae <- function(subj) {
  arm          <- subj$ARMCD
  c1d1         <- subj$C1D1_DATE
  last_dose    <- subj$LAST_DOSE_DATE
  obs_end      <- min(subj$OBS_OS_DATE, subj$DATA_CUTOFF)
  treat_days   <- as.integer(last_dose - c1d1) + 30L  # 30-day safety window post-EOT
  obs_days     <- as.integer(obs_end - c1d1)

  if (obs_days <= 0L) return(NULL)

  ae_records <- list()
  ae_seq     <- 0L

  for (i in seq_len(nrow(ae_catalogue))) {
    ae      <- ae_catalogue[i, ]
    p_event <- if (arm == "TOR") ae$p_tor[[1]] else ae$p_pbo[[1]]

    # Randomly determine if this subject experiences this AE
    if (runif(1L) > p_event) next

    # Number of occurrences (most AEs occur once; some recur)
    n_occur <- if (runif(1L) < 0.15) 2L else 1L  # 15% chance of recurrence

    for (occ in seq_len(n_occur)) {
      # AE onset: uniform over observation period (mostly during treatment)
      # Weighted toward treatment period (80% during treatment)
      treat_frac <- min(treat_days, obs_days) / obs_days
      if (runif(1L) < max(treat_frac, 0.80)) {
        onset_day <- sample(1L:max(min(treat_days, obs_days), 1L), 1L)
      } else {
        onset_day <- sample(
          max(treat_days + 1L, 1L):max(obs_days, treat_days + 1L), 1L
        )
      }
      onset_date <- c1d1 + onset_day - 1L

      if (onset_date > obs_end) next  # beyond last contact — skip

      # CTCAE grade
      grade_probs <- ae$grade_probs[[1]]
      grade <- sample(1L:5L, 1L, prob = grade_probs)

      # Grade 5 only if subject died on study
      if (grade == 5L && subj$DTHFL != "Y") {
        grade <- 4L
      }

      # Duration: grade-dependent, shorter for lower grades
      base_duration <- switch(as.character(grade),
                               "1" = round(runif(1L, 3, 14)),
                               "2" = round(runif(1L, 7, 28)),
                               "3" = round(runif(1L, 14, 56)),
                               "4" = round(runif(1L, 21, 90)),
                               "5" = 0L)  # fatal — no end date
      resolves <- runif(1L) < ae$resolves[[1]]

      end_date_val <- if (grade == 5L) {
        # Use death date if available, else onset + 1
        if (!is.na(subj$DEATH_DATE) && subj$DEATH_DATE != "") {
          as.Date(subj$DEATH_DATE)
        } else {
          onset_date + 1L
        }
      } else if (resolves) {
        onset_date + base_duration
      } else {
        NA_Date_  # ongoing
      }

      # Cap end date at data cutoff
      if (!is.na(end_date_val) && end_date_val > subj$DATA_CUTOFF) {
        end_date_val <- NA_Date_
      }

      # Relatedness
      rel_p    <- if (arm == "TOR") ae$rel_p_tor[[1]] else ae$rel_p_pbo[[1]]
      aerel    <- ifelse(runif(1L) < rel_p, "RELATED", "NOT RELATED")

      # Serious AE
      p_ser    <- ae$p_serious[[1]]
      # Serious probability higher for grade ≥3
      if (grade >= 3L) p_ser <- min(p_ser * 3.0, 0.95)
      aeser    <- ifelse(runif(1L) < p_ser, "Y", "N")

      # Action taken with study treatment (AEACN)
      aeacn <- if (grade >= 4L) {
        sample(c("DRUG WITHDRAWN", "DOSE NOT GIVEN"), 1L, prob = c(0.5, 0.5))
      } else if (grade == 3L && ae$is_irae[[1]]) {
        sample(c("DOSE NOT GIVEN", "DOSE REDUCED", "DRUG WITHDRAWN", "NOT APPLICABLE"),
               1L, prob = c(0.35, 0.20, 0.25, 0.20))
      } else {
        "NOT APPLICABLE"
      }

      # Outcome (AEOUT)
      aeout <- if (grade == 5L) {
        "FATAL"
      } else if (!is.na(end_date_val)) {
        if (grade >= 3L) {
          sample(c("RECOVERED/RESOLVED", "RECOVERED/RESOLVED WITH SEQUELAE"),
                 1L, prob = c(0.85, 0.15))
        } else {
          "RECOVERED/RESOLVED"
        }
      } else {
        sample(c("NOT RECOVERED/NOT RESOLVED", "RECOVERING/RESOLVING"),
               1L, prob = c(0.55, 0.45))
      }

      ae_seq <- ae_seq + 1L
      ae_records[[ae_seq]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "AE",
        USUBJID  = subj$USUBJID,
        AESEQ    = ae_seq,
        AETERM   = ae$aeterm[[1]],
        AEDECOD  = ae$aedecod[[1]],
        AEBODSYS = ae$aebodsys[[1]],
        AESOC    = ae$aebodsys[[1]],
        AESTDTC  = format(onset_date,    "%Y-%m-%d"),
        AEENDTC  = ifelse(!is.na(end_date_val),
                          format(end_date_val, "%Y-%m-%d"), ""),
        AETOXGR  = as.character(grade),
        AESEV    = grade_to_sev[as.character(grade)],
        AEREL    = aerel,
        AESER    = aeser,
        AEACN    = aeacn,
        AEOUT    = aeout,
        EPOCH    = ifelse(onset_date <= last_dose + 30L, "TREATMENT", "FOLLOW-UP"),
        AESTDY   = onset_day
      )
    }
  }

  if (length(ae_records) == 0L) return(NULL)

  bind_rows(ae_records) %>%
    arrange(AESTDTC, AESEQ) %>%
    mutate(AESEQ = row_number())
}

AE <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_ae)


# ── Write outputs ──────────────────────────────────────────────────────────────
dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(AE, "sdtm/ae.parquet")
write.csv(AE, "data-raw/raw_data/ae_raw.csv", row.names = FALSE, na = "")


# ── Validation ─────────────────────────────────────────────────────────────────
cat("\n=== AE Domain Validation ===\n")
cat(sprintf("  Total AE records        : %d\n", nrow(AE)))
cat(sprintf("  Subjects with ≥1 AE     : %d / %d (%.0f%%)\n",
            n_distinct(AE$USUBJID), nrow(backbone),
            100 * n_distinct(AE$USUBJID) / nrow(backbone)))
cat(sprintf("  SAEs                    : %d (%.1f%%)\n",
            sum(AE$AESER == "Y"),
            100 * mean(AE$AESER == "Y")))
cat(sprintf("  Grade 3-4 AEs           : %d (%.1f%%)\n",
            sum(AE$AETOXGR %in% c("3","4")),
            100 * mean(AE$AETOXGR %in% c("3","4"))))
cat(sprintf("  Grade 5 (fatal) AEs     : %d\n",
            sum(AE$AETOXGR == "5")))
cat(sprintf("  Related AEs             : %d (%.1f%%)\n",
            sum(AE$AEREL == "RELATED"),
            100 * mean(AE$AEREL == "RELATED")))
cat("\n  Top 10 AE PTs (all arms):\n")
print(
  AE %>% count(AEDECOD, sort = TRUE) %>% slice_head(n = 10)
)
cat("\n  Outputs written:\n")
cat("    sdtm/ae.parquet\n")
cat("    data-raw/raw_data/ae_raw.csv\n")
cat("\n=== AE generation complete ===\n")
