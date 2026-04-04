# =============================================================================
# torivumab guidelines loaded
# 14_dd.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: DD (Death Details)
# Standard: SDTMIG v3.4 | MedDRA v27.0
# Seed: set.seed(314)
# =============================================================================
#
# Outputs:
#   sdtm/dd.parquet              — SDTM DD domain (Parquet)
#   data-raw/raw_data/dd_raw.csv — Raw death detail records
#
# DD strategy:
#   - One record per subject who died on-study or within follow-up
#   - DDTERM: cause of death (verbatim)
#   - DDDECOD: MedDRA PT (simplified)
#   - DDCAT: PRIMARY CAUSE, SECONDARY CAUSE
#   - Primary cause: mostly NSCLC progression (~85%); some non-cancer deaths
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

set.seed(314)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  filter(DTHFL == "Y") %>%
  mutate(
    DEATH_DATE  = as.Date(DEATH_DATE),
    C1D1_DATE   = as.Date(C1D1_DATE)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

if (nrow(backbone) == 0L) {
  cat("No deaths recorded — DD domain empty.\n")
  write_parquet(tibble(), "sdtm/dd.parquet")
  write.csv(tibble(), "data-raw/raw_data/dd_raw.csv", row.names = FALSE)
  quit(save = "no")
}

# Primary causes of death
primary_causes_cancer <- c(
  "NSCLC progression"   = 0.82,
  "Respiratory failure due to tumour" = 0.05,
  "NSCLC with brain metastasis" = 0.05,
  "Malignant pleural effusion" = 0.03,
  "Haemoptysis secondary to tumour" = 0.02,
  "NSCLC with hepatic failure" = 0.03
)
primary_causes_noncancer <- c(
  "Cardiac arrest" = 0.35,
  "Pneumonia" = 0.25,
  "Pulmonary embolism" = 0.20,
  "Sepsis" = 0.15,
  "Unknown" = 0.05
)

# MedDRA PT mappings
cause_to_meddra <- c(
  "NSCLC progression"                      = "Malignant neoplasm progression",
  "Respiratory failure due to tumour"       = "Respiratory failure",
  "NSCLC with brain metastasis"             = "Brain neoplasm malignant",
  "Malignant pleural effusion"              = "Pleural effusion malignant",
  "Haemoptysis secondary to tumour"         = "Haemoptysis",
  "NSCLC with hepatic failure"             = "Hepatic failure",
  "Cardiac arrest"                          = "Cardiac arrest",
  "Pneumonia"                               = "Pneumonia",
  "Pulmonary embolism"                      = "Pulmonary embolism",
  "Sepsis"                                  = "Sepsis",
  "Unknown"                                 = "Death"
)

n <- nrow(backbone)
# 90% cancer deaths, 10% non-cancer
is_cancer_death <- runif(n) < 0.90

primary_cause <- character(n)
for (i in seq_len(n)) {
  if (is_cancer_death[i]) {
    primary_cause[i] <- sample(names(primary_causes_cancer), 1L,
                               prob = primary_causes_cancer)
  } else {
    primary_cause[i] <- sample(names(primary_causes_noncancer), 1L,
                               prob = primary_causes_noncancer)
  }
}

DD <- tibble(
  STUDYID  = STUDYID,
  DOMAIN   = "DD",
  USUBJID  = backbone$USUBJID,
  DDSEQ    = 1L,
  DDTERM   = primary_cause,
  DDDECOD  = cause_to_meddra[primary_cause],
  DDCAT    = "PRIMARY CAUSE OF DEATH",
  DDSCAT   = ifelse(is_cancer_death, "DISEASE PROGRESSION", "INTERCURRENT ILLNESS"),
  DDDTC    = format(backbone$DEATH_DATE, "%Y-%m-%d"),
  DDDY     = as.integer(backbone$DEATH_DATE - backbone$C1D1_DATE) + 1L,
  EPOCH    = "FOLLOW-UP"
)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(DD, "sdtm/dd.parquet")
write.csv(DD, "data-raw/raw_data/dd_raw.csv", row.names = FALSE, na = "")

cat("\n=== DD Domain Validation ===\n")
cat(sprintf("  Total death records     : %d\n", nrow(DD)))
cat(sprintf("  Cancer-related deaths   : %d (%.0f%%)\n",
            sum(DD$DDSCAT == "DISEASE PROGRESSION"),
            100 * mean(DD$DDSCAT == "DISEASE PROGRESSION")))
cat("\n  Primary cause distribution:\n")
print(DD %>% count(DDTERM, sort = TRUE))
cat("\n  Outputs written: sdtm/dd.parquet, data-raw/raw_data/dd_raw.csv\n")
cat("=== DD generation complete ===\n")
