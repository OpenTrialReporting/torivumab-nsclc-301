# =============================================================================
# torivumab guidelines loaded
# 05_cm.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: CM (Concomitant Medications)
# Standard: SDTMIG v3.4 | WHO Drug Dictionary
# Seed: set.seed(305)
# =============================================================================
#
# Outputs:
#   sdtm/cm.parquet              — SDTM CM domain (Parquet)
#   data-raw/raw_data/cm_raw.csv — Raw CM records
#
# CM generation strategy:
#   - Pre-existing medications (started before/at screening) — background meds
#   - On-study medications: supportive care, corticosteroids for irAE management
#   - Medications reflect NSCLC patient population comorbidities
#   - No anti-cancer concomitant therapy (exclusion criterion in protocol)
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

set.seed(305)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Medication catalogue ────────────────────────────────────────────────────────
# CMTRT: verbatim, CMDECOD: WHO Drug Dictionary name
# p_use: probability subject is on this med at/around study entry
# timing: "pre" (background, started before study), "on" (on-study supportive)
# category: WHO ATC category
cm_catalogue <- tribble(
  ~cmtrt,               ~cmdecod,             ~cmclas,        ~p_use,  ~timing,
  "Amlodipine",         "AMLODIPINE",          "C08CA01",       0.25,   "pre",
  "Lisinopril",         "LISINOPRIL",          "C09AA03",       0.22,   "pre",
  "Atorvastatin",       "ATORVASTATIN",        "C10AA05",       0.30,   "pre",
  "Metformin",          "METFORMIN",           "A10BA02",       0.18,   "pre",
  "Omeprazole",         "OMEPRAZOLE",          "A02BC01",       0.28,   "pre",
  "Levothyroxine",      "LEVOTHYROXINE",       "H03AA01",       0.12,   "pre",
  "Aspirin",            "ACETYLSALICYLIC ACID","B01AC06",       0.20,   "pre",
  "Metoprolol",         "METOPROLOL",          "C07AB02",       0.15,   "pre",
  "Warfarin",           "WARFARIN",            "B01AA03",       0.05,   "pre",
  "Gabapentin",         "GABAPENTIN",          "N03AX12",       0.08,   "pre",
  "Ondansetron",        "ONDANSETRON",         "A04AA01",       0.15,   "on",
  "Loperamide",         "LOPERAMIDE",          "A07DA03",       0.10,   "on",
  "Prednisone",         "PREDNISONE",          "H02AB07",       0.08,   "on",  # irAE mgmt
  "Methylprednisolone", "METHYLPREDNISOLONE",  "H02AB04",       0.05,   "on",  # irAE mgmt
  "Granisetron",        "GRANISETRON",         "A04AA02",       0.08,   "on",
  "Dexamethasone",      "DEXAMETHASONE",       "H02AB02",       0.12,   "on",
  "Furosemide",         "FUROSEMIDE",          "C03CA01",       0.10,   "pre",
  "Pantoprazole",       "PANTOPRAZOLE",        "A02BC02",       0.15,   "pre",
  "Paracetamol",        "PARACETAMOL",         "N02BE01",       0.20,   "on"
)

generate_cm <- function(subj) {
  c1d1    <- subj$C1D1_DATE
  obs_end <- min(subj$EOT_DATE, subj$DATA_CUTOFF)
  cm_recs <- list()
  seq_n   <- 0L

  for (i in seq_len(nrow(cm_catalogue))) {
    med <- cm_catalogue[i, ]
    if (runif(1L) > med$p_use[[1]]) next

    seq_n <- seq_n + 1L

    if (med$timing[[1]] == "pre") {
      # Started before study: CMSTDTC = C1D1 - 30 to 5 years prior
      start_offset <- sample(30L:1825L, 1L)
      start_date   <- c1d1 - start_offset
      # Ongoing through most of study (80%) or stopped during study
      if (runif(1L) < 0.80) {
        end_date <- NA_Date_
      } else {
        end_offset <- sample(14L:as.integer(obs_end - c1d1), 1L)
        end_date   <- c1d1 + end_offset
      }
    } else {
      # On-study: started during treatment
      start_offset <- sample(1L:max(as.integer(obs_end - c1d1), 1L), 1L)
      start_date   <- c1d1 + start_offset - 1L
      # Duration: 7-60 days for supportive meds
      dur <- sample(7L:60L, 1L)
      end_date <- start_date + dur
      if (end_date > obs_end) end_date <- NA_Date_
    }

    cm_recs[[seq_n]] <- tibble(
      STUDYID  = STUDYID,
      DOMAIN   = "CM",
      USUBJID  = subj$USUBJID,
      CMSEQ    = seq_n,
      CMTRT    = med$cmtrt[[1]],
      CMDECOD  = med$cmdecod[[1]],
      CMCLAS   = med$cmclas[[1]],
      CMSTDTC  = format(start_date, "%Y-%m-%d"),
      CMENDTC  = ifelse(!is.na(end_date), format(end_date, "%Y-%m-%d"), ""),
      CMENRTPT = ifelse(is.na(end_date), "ONGOING", ""),
      CMONGO   = ifelse(is.na(end_date), "Y", ""),
      EPOCH    = ifelse(start_date < c1d1, "SCREENING", "TREATMENT")
    )
  }

  if (length(cm_recs) == 0L) return(NULL)
  bind_rows(cm_recs) %>% mutate(CMSEQ = row_number())
}

CM <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_cm)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(CM, "sdtm/cm.parquet")
write.csv(CM, "data-raw/raw_data/cm_raw.csv", row.names = FALSE, na = "")

cat("\n=== CM Domain Validation ===\n")
cat(sprintf("  Total CM records        : %d\n", nrow(CM)))
cat(sprintf("  Subjects with ≥1 CM     : %d / %d\n",
            n_distinct(CM$USUBJID), nrow(backbone)))
cat(sprintf("  Ongoing medications     : %d (%.1f%%)\n",
            sum(CM$CMONGO == "Y"), 100 * mean(CM$CMONGO == "Y")))
cat("  Top medications:\n")
print(CM %>% count(CMDECOD, sort = TRUE) %>% slice_head(n = 8))
cat("\n  Outputs written: sdtm/cm.parquet, data-raw/raw_data/cm_raw.csv\n")
cat("=== CM generation complete ===\n")
