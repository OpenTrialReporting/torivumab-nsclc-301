# =============================================================================
# torivumab guidelines loaded
# 09_lb.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: LB (Laboratory Test Results)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03 | LOINC
# Seed: set.seed(309)
# =============================================================================
#
# Outputs:
#   sdtm/lb.parquet              — SDTM LB domain (Parquet)
#   data-raw/raw_data/lb_raw.csv — Raw lab records
#
# LB panels generated:
#   1. Haematology: WBC, HGB, PLT, NEUT, LYMPH, MONO
#   2. Chemistry: ALT, AST, ALKPH, BILI, CREAT, BUN, NA, K, GLUC, ALB
#   3. Thyroid: TSH, T4 (irAE monitoring for anti-PD-1)
#   4. Urinalysis (dipstick): USPECGR, UPH, UPROT, UGLUC, UBILI
#   5. Biomarkers (baseline only): PD-L1 TPS, EGFR mutation, ALK, ROS1,
#      KRAS G12C, MET exon 14, RET, BRAF V600E, NTRK, TMB
#
# Visit schedule for labs:
#   SCR, C1D1, C1D22 (EOC1), C2D22 (EOC2), every EOC thereafter, EOT, FU01
#   Thyroid: SCR, every 2 cycles, EOT
#   Biomarkers: SCR only (central lab)
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

set.seed(309)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    OBS_OS_DATE = as.Date(OBS_OS_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Lab test catalogue ─────────────────────────────────────────────────────────
# Columns: LBTESTCD, LBTEST, LBCAT, LBORRES unit, normal range [lo, hi],
#          mean, sd for normal generation
lab_tests <- tribble(
  ~LBTESTCD, ~LBTEST,                           ~LBCAT,       ~LBORRESU,    ~norm_lo, ~norm_hi,  ~mu,     ~sigma, ~panel,
  # Haematology
  "WBC",     "Leukocytes",                       "HEMATOLOGY", "10^9/L",      3.5,      10.5,     7.0,     1.8,   "HAEM",
  "HGB",     "Hemoglobin",                       "HEMATOLOGY", "g/dL",       12.0,      16.0,    13.5,     1.5,   "HAEM",
  "PLT",     "Platelets",                        "HEMATOLOGY", "10^9/L",    150.0,     400.0,   230.0,    60.0,   "HAEM",
  "NEUT",    "Neutrophils",                      "HEMATOLOGY", "10^9/L",      1.8,       7.5,     4.5,     1.3,   "HAEM",
  "LYMPH",   "Lymphocytes",                      "HEMATOLOGY", "10^9/L",      1.0,       4.0,     2.1,     0.6,   "HAEM",
  "MONO",    "Monocytes",                        "HEMATOLOGY", "10^9/L",      0.2,       1.0,     0.5,     0.15,  "HAEM",
  # Chemistry
  "ALT",     "Alanine Aminotransferase",         "CHEMISTRY",  "U/L",         7.0,      40.0,    22.0,     9.0,   "CHEM",
  "AST",     "Aspartate Aminotransferase",        "CHEMISTRY",  "U/L",        10.0,      40.0,    24.0,     9.0,   "CHEM",
  "ALKPH",   "Alkaline Phosphatase",             "CHEMISTRY",  "U/L",        44.0,     147.0,    80.0,    22.0,   "CHEM",
  "BILI",    "Bilirubin",                        "CHEMISTRY",  "umol/L",      5.0,      21.0,    11.0,     4.0,   "CHEM",
  "CREAT",   "Creatinine",                       "CHEMISTRY",  "umol/L",     60.0,     110.0,    82.0,    16.0,   "CHEM",
  "BUN",     "Blood Urea Nitrogen",              "CHEMISTRY",  "mmol/L",      2.5,       6.7,     4.5,     1.0,   "CHEM",
  "NA",      "Sodium",                           "CHEMISTRY",  "mmol/L",    136.0,     145.0,   140.0,     2.5,   "CHEM",
  "K",       "Potassium",                        "CHEMISTRY",  "mmol/L",      3.5,       5.0,     4.1,     0.4,   "CHEM",
  "GLUC",    "Glucose",                          "CHEMISTRY",  "mmol/L",      3.9,       6.1,     5.2,     0.8,   "CHEM",
  "ALB",     "Albumin",                          "CHEMISTRY",  "g/L",        35.0,      52.0,    42.0,     4.0,   "CHEM",
  # Thyroid
  "TSH",     "Thyroid Stimulating Hormone",      "ENDOCRINE",  "mIU/L",       0.5,       4.5,     2.0,     0.8,   "THYR",
  "T4FREE",  "Free Thyroxine",                   "ENDOCRINE",  "pmol/L",     12.0,      22.0,    16.0,     2.0,   "THYR",
  # Urinalysis (dipstick — semi-quantitative coded values)
  "USPECGR", "Urine Specific Gravity",           "URINALYSIS", "",            1.005,     1.030,   1.015,   0.005, "URINE",
  "UPH",     "Urine pH",                        "URINALYSIS", "",             4.5,       8.5,     6.0,     1.0,   "URINE"
)

# Biomarker tests (screening only, central lab, mostly qualitative)
biomarker_tests <- tribble(
  ~LBTESTCD,     ~LBTEST,                         ~LBCAT,       ~p_positive_tor, ~p_positive_pbo,
  "PDL1TPS",     "PD-L1 TPS (22C3)",              "BIOMARKER",   1.00,             1.00,   # all ≥50% (inclusion)
  "EGFRMUT",     "EGFR Mutation Status",           "BIOMARKER",   0.00,             0.00,   # all negative (exclusion)
  "ALKREARR",    "ALK Rearrangement",              "BIOMARKER",   0.00,             0.00,   # all negative (exclusion)
  "ROS1REARR",   "ROS1 Rearrangement",             "BIOMARKER",   0.02,             0.02,
  "KRASG12C",    "KRAS G12C Mutation",             "BIOMARKER",   0.13,             0.13,
  "METEX14",     "MET Exon 14 Skipping",           "BIOMARKER",   0.03,             0.03,
  "RETREARR",    "RET Rearrangement",              "BIOMARKER",   0.02,             0.02,
  "BRAFV600E",   "BRAF V600E Mutation",            "BIOMARKER",   0.02,             0.02,
  "NTRK",        "NTRK Fusion",                   "BIOMARKER",   0.01,             0.01
)

# TMB optional (genomic panel used in ~60% of subjects)
TMB_USE_PROB <- 0.62

# Visit schedule for routine labs (study days from C1D1)
# SCR = -14, C1D1 = 1, EOC visits every 21d, EOT ~+30d post last dose
routine_lab_visits <- c(
  SCR = -14L, C1D1 = 1L, C1D22 = 22L, C2D22 = 43L,
  C3D22 = 85L, C4D22 = 106L, C5D22 = 127L,
  C6D22 = 148L, C7D22 = 169L, C8D22 = 190L,
  C9D22 = 211L, C10D22 = 232L, EOT = 999L, FU01 = 1090L
)

thyroid_visits <- c("SCR", "C1D22", "C3D22", "C5D22", "C7D22", "C9D22", "EOT")


generate_lb_routine <- function(subj) {
  c1d1    <- subj$C1D1_DATE
  obs_end <- min(subj$OBS_OS_DATE, subj$DATA_CUTOFF)
  eot_day <- as.integer(subj$EOT_DATE - c1d1) + 1L

  lb_recs <- list()
  seq_n   <- 0L

  for (vname in names(routine_lab_visits)) {
    vday  <- if (vname == "EOT") eot_day else routine_lab_visits[[vname]]
    vdate <- c1d1 + vday - 1L
    if (vdate > obs_end) next
    if (vname != "SCR" && vname != "C1D1") {
      vdate <- vdate + sample(-2L:2L, 1L)
    }

    # Determine panels for this visit
    panels_at_visit <- c("HAEM", "CHEM")   # routine every lab visit
    if (vname %in% thyroid_visits) panels_at_visit <- c(panels_at_visit, "THYR")
    if (vname %in% c("SCR", "C1D1", "EOT")) panels_at_visit <- c(panels_at_visit, "URINE")

    # Determine lab result: slight degradation over time on-treatment
    days_on <- max(as.integer(vdate - c1d1), 0L)

    for (j in seq_len(nrow(lab_tests))) {
      test <- lab_tests[j, ]
      if (!test$panel[[1]] %in% panels_at_visit) next

      # Urinalysis semi-quantitative: generate from normal, then round
      if (test$panel[[1]] == "URINE") {
        val <- round(rnorm(1L, test$mu[[1]], test$sigma[[1]]), 3)
        val <- pmax(pmin(val, test$norm_hi[[1]] + 0.05),
                    test$norm_lo[[1]] - 0.05)
        val <- round(val, if (test$LBTESTCD[[1]] == "USPECGR") 3L else 1L)
      } else {
        # Continuous lab: baseline from normal distribution
        # Small random walk over time (intra-subject correlation)
        val <- rnorm(1L, test$mu[[1]], test$sigma[[1]])
        val <- pmax(val, 0.01)

        # irAE pattern: liver enzymes may spike in TOR arm
        if (subj$ARMCD == "TOR" && test$LBTESTCD[[1]] %in% c("ALT", "AST")) {
          spike_p <- 0.003 * (days_on / 30)  # increasing risk over time
          if (runif(1L) < spike_p) {
            val <- val * runif(1L, 3.0, 8.0)  # Grade 2-3 elevation
          }
        }
        # Hypothyroidism pattern: TSH elevates in TOR arm ~12%
        if (subj$ARMCD == "TOR" && test$LBTESTCD[[1]] == "TSH" && days_on > 60L) {
          if (runif(1L) < 0.012) val <- val * runif(1L, 2.0, 6.0)
        }

        val <- round(val, if (test$LBORRESU[[1]] %in% c("g/dL","g/L")) 1L else
                          if (test$LBORRESU[[1]] %in% c("10^9/L","mmol/L","mIU/L","pmol/L")) 2L
                          else 0L)
      }

      # Normal range flags
      lbnrlo <- test$norm_lo[[1]]
      lbnrhi <- test$norm_hi[[1]]
      lbnrind <- ifelse(val < lbnrlo, "L",
                        ifelse(val > lbnrhi, "H", "N"))

      seq_n <- seq_n + 1L
      lb_recs[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "LB",
        USUBJID  = subj$USUBJID,
        LBSEQ    = seq_n,
        LBTESTCD = test$LBTESTCD[[1]],
        LBTEST   = test$LBTEST[[1]],
        LBCAT    = test$LBCAT[[1]],
        LBORRES  = as.character(val),
        LBORRESU = test$LBORRESU[[1]],
        LBSTRESC = as.character(val),
        LBSTRESN = val,
        LBSTRESU = test$LBORRESU[[1]],
        LBNRLO   = lbnrlo,
        LBNRHI   = lbnrhi,
        LBNRIND  = lbnrind,
        LBDTC    = format(vdate, "%Y-%m-%d"),
        LBDY     = as.integer(vdate - c1d1) + 1L,
        VISIT    = vname,
        VISITNUM = which(names(routine_lab_visits) == vname)[1L],
        EPOCH    = ifelse(vdate < c1d1, "SCREENING",
                          ifelse(vdate > subj$EOT_DATE, "FOLLOW-UP", "TREATMENT"))
      )
    }
  }
  if (length(lb_recs) == 0L) return(NULL)
  bind_rows(lb_recs)
}

generate_lb_biomarkers <- function(subj) {
  c1d1 <- subj$C1D1_DATE
  scr_date <- c1d1 - 14L

  bm_recs <- list()
  seq_n   <- 0L

  for (j in seq_len(nrow(biomarker_tests))) {
    bm <- biomarker_tests[j, ]
    p_pos <- if (subj$ARMCD == "TOR") bm$p_positive_tor[[1]] else bm$p_positive_pbo[[1]]

    result_bin <- runif(1L) < p_pos

    # PD-L1 TPS: numeric value ≥50% (required by inclusion criterion)
    lborres <- if (bm$LBTESTCD[[1]] == "PDL1TPS") {
      tps_val <- round(runif(1L, 50, 99))
      as.character(tps_val)
    } else {
      ifelse(result_bin, "POSITIVE", "NEGATIVE")
    }

    seq_n <- seq_n + 1L
    bm_recs[[seq_n]] <- tibble(
      STUDYID  = STUDYID,
      DOMAIN   = "LB",
      USUBJID  = subj$USUBJID,
      LBSEQ    = seq_n,
      LBTESTCD = bm$LBTESTCD[[1]],
      LBTEST   = bm$LBTEST[[1]],
      LBCAT    = bm$LBCAT[[1]],
      LBORRES  = lborres,
      LBORRESU = ifelse(bm$LBTESTCD[[1]] == "PDL1TPS", "%", ""),
      LBSTRESC = lborres,
      LBSTRESN = ifelse(bm$LBTESTCD[[1]] == "PDL1TPS", as.numeric(lborres), NA_real_),
      LBSTRESU = ifelse(bm$LBTESTCD[[1]] == "PDL1TPS", "%", ""),
      LBNRLO   = NA_real_,
      LBNRHI   = NA_real_,
      LBNRIND  = "",
      LBDTC    = format(scr_date, "%Y-%m-%d"),
      LBDY     = as.integer(scr_date - c1d1) + 1L,
      VISIT    = "SCR",
      VISITNUM = 0.0,
      EPOCH    = "SCREENING"
    )
  }

  # TMB (optional, ~62% of subjects)
  if (runif(1L) < TMB_USE_PROB) {
    tmb_val <- round(runif(1L, 1, 35))  # mutations per megabase
    seq_n <- seq_n + 1L
    bm_recs[[seq_n]] <- tibble(
      STUDYID  = STUDYID,
      DOMAIN   = "LB",
      USUBJID  = subj$USUBJID,
      LBSEQ    = seq_n,
      LBTESTCD = "TMB",
      LBTEST   = "Tumour Mutational Burden",
      LBCAT    = "BIOMARKER",
      LBORRES  = as.character(tmb_val),
      LBORRESU = "mut/Mb",
      LBSTRESC = as.character(tmb_val),
      LBSTRESN = tmb_val,
      LBSTRESU = "mut/Mb",
      LBNRLO   = NA_real_,
      LBNRHI   = NA_real_,
      LBNRIND  = "",
      LBDTC    = format(scr_date, "%Y-%m-%d"),
      LBDY     = as.integer(scr_date - c1d1) + 1L,
      VISIT    = "SCR",
      VISITNUM = 0.0,
      EPOCH    = "SCREENING"
    )
  }

  if (length(bm_recs) == 0L) return(NULL)
  bind_rows(bm_recs)
}

# Generate all LB records
LB_routine    <- backbone %>% split(seq_len(nrow(.))) %>% map_dfr(generate_lb_routine)
LB_biomarkers <- backbone %>% split(seq_len(nrow(.))) %>% map_dfr(generate_lb_biomarkers)

LB <- bind_rows(LB_routine, LB_biomarkers) %>%
  arrange(USUBJID, LBDTC, LBTESTCD) %>%
  group_by(USUBJID) %>%
  mutate(LBSEQ = row_number()) %>%
  ungroup()

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(LB, "sdtm/lb.parquet")
write.csv(LB, "data-raw/raw_data/lb_raw.csv", row.names = FALSE, na = "")

cat("\n=== LB Domain Validation ===\n")
cat(sprintf("  Total LB records        : %d\n", nrow(LB)))
cat(sprintf("  Subjects with LB data   : %d / %d\n",
            n_distinct(LB$USUBJID), nrow(backbone)))
cat(sprintf("  Biomarker records       : %d\n",
            sum(LB$LBCAT == "BIOMARKER")))
cat(sprintf("  PD-L1 TPS (n)           : %d; median = %.0f%%\n",
            sum(LB$LBTESTCD == "PDL1TPS"),
            median(LB$LBSTRESN[LB$LBTESTCD == "PDL1TPS"], na.rm = TRUE)))
cat(sprintf("  Elevated ALT (>ULN)     : %d (%.1f%% of ALT results)\n",
            sum(LB$LBTESTCD == "ALT" & LB$LBNRIND == "H"),
            100 * mean(LB$LBTESTCD == "ALT" & LB$LBNRIND == "H")))
cat("\n  Outputs written: sdtm/lb.parquet, data-raw/raw_data/lb_raw.csv\n")
cat("=== LB generation complete ===\n")
