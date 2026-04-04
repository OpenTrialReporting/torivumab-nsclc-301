# =============================================================================
# torivumab guidelines loaded
# 11_tu.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: TU (Tumour Identification) — RECIST 1.1
# Standard: SDTMIG v3.4 | CDISC Oncology Disease Response Supplement 2023
# Seed: set.seed(311)
# =============================================================================
#
# Outputs:
#   sdtm/tu.parquet              — SDTM TU domain (Parquet)
#   data-raw/raw_data/tu_raw.csv — Raw tumour identification records
#   data-raw/raw_data/tu_lesion_map.csv — Lesion-to-subject map for TR/RS
#
# TU strategy (RECIST 1.1):
#   - Target lesions: 2-5 per subject (measurable, ≥10mm)
#   - Non-target lesions: 0-3 per subject (non-measurable or too numerous)
#   - TULOC: anatomical location (lung, lymph node, liver, adrenal, bone)
#   - TUMETHOD: CT or MRI
#   - Baseline only (SCR or C1D1): tumour identification visit
#   - TUREFID: unique lesion reference ID per subject
#
# RECIST 1.1 Lesion Location Pool:
#   - Primary: Lung (right/left), Mediastinal lymph nodes, Hilar lymph nodes
#   - Distant: Liver, Adrenal gland, Contralateral lung, Pleura, Bone
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# Run after: 01_dm.R
# Run before: 12_tr.R, 13_rs.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(311)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(C1D1_DATE = as.Date(C1D1_DATE))

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── Lesion location catalogue ──────────────────────────────────────────────────
# TULOC values (CDISC CT 2024-03 TULOC codelist)
target_locations <- c(
  "LUNG", "LUNG", "LUNG",               # most common primary
  "LYMPH NODE", "LYMPH NODE",           # mediastinal/hilar — common in NSCLC
  "LIVER",                              # hepatic metastasis
  "ADRENAL GLAND",                      # adrenal metastasis
  "PLEURA"                              # pleural metastasis
)

nontarget_locations <- c(
  "BONE",           # bone metastasis (non-measurable if lytic)
  "BRAIN",          # brain metastasis (non-measurable if <10mm)
  "LYMPH NODE",     # sub-10mm nodes
  "PLEURA"          # pleural effusion
)

# Laterality pool (CDISC CT LAT codelist)
lat_pool <- c("LEFT", "RIGHT", "BILATERAL", "")

# Direction pool (CDISC CT DIR codelist)
dir_pool <- c("ANTERIOR", "POSTERIOR", "SUPERIOR", "INFERIOR", "MEDIAL", "LATERAL", "")

# Method: CT preferred, MRI for brain/liver
method_for_loc <- function(loc) {
  if (loc %in% c("BRAIN", "LIVER")) sample(c("CT", "MRI"), 1L, prob = c(0.4, 0.6))
  else "CT"
}

generate_tu <- function(subj) {
  c1d1     <- subj$C1D1_DATE
  scr_date <- c1d1 - 14L

  # Number of target lesions: 2-5 (RECIST 1.1 allows up to 5, max 2 per organ)
  n_target <- sample(2L:5L, 1L, prob = c(0.10, 0.30, 0.35, 0.25))

  # Number of non-target lesions: 0-3
  n_nontarget <- sample(0L:3L, 1L, prob = c(0.30, 0.35, 0.25, 0.10))

  tu_recs <- list()
  seq_n   <- 0L

  # ── Target lesions ────────────────────────────────────────────────────────
  # Sample locations without replacement (max 2 per organ for targets)
  locs_available <- sample(target_locations)
  loc_counts     <- table(locs_available)
  # RECIST: max 2 per organ
  used_locs <- character(0)
  for (k in seq_len(n_target)) {
    # Pick next available location
    for (loc in locs_available) {
      if (sum(used_locs == loc) < 2L) {
        chosen_loc <- loc
        used_locs  <- c(used_locs, chosen_loc)
        break
      }
    }

    seq_n <- seq_n + 1L
    lesion_id <- sprintf("%s-T%02d", subj$SUBJID, k)

    lat <- if (chosen_loc %in% c("LUNG", "ADRENAL GLAND", "LYMPH NODE")) {
      sample(c("LEFT", "RIGHT"), 1L)
    } else ""

    dir <- if (chosen_loc == "LIVER") {
      sample(c("ANTERIOR", "POSTERIOR", "SUPERIOR", "INFERIOR"), 1L)
    } else ""

    # Baseline longest diameter: 10-50mm for target lesions
    # Lymph nodes: short axis ≥15mm counts as target
    if (chosen_loc == "LYMPH NODE") {
      baseline_mm <- round(runif(1L, 15, 45))
      trtestcd    <- "LPERP"  # perpendicular/short axis for nodes
    } else {
      baseline_mm <- round(runif(1L, 10, 50))
      trtestcd    <- "LDIAM"  # longest diameter
    }

    tu_recs[[seq_n]] <- tibble(
      STUDYID   = STUDYID,
      DOMAIN    = "TU",
      USUBJID   = subj$USUBJID,
      TUSEQ     = seq_n,
      TUREFID   = lesion_id,
      TULNKID   = lesion_id,   # links to TR records
      TUORRES   = chosen_loc,
      TUSTRESC  = chosen_loc,
      TULOC     = chosen_loc,
      TULAT     = lat,
      TUDIR     = dir,
      TUMETHOD  = method_for_loc(chosen_loc),
      TUTESTCD  = "TUMIDENT",
      TUTEST    = "Tumour Identification",
      TUCAT     = "TARGET",
      TUSPID    = sprintf("T%d", k),   # target lesion number
      TUSTDTC   = format(scr_date, "%Y-%m-%d"),
      TUDY      = as.integer(scr_date - c1d1) + 1L,
      VISIT     = "SCR",
      VISITNUM  = 0.0,
      EPOCH     = "SCREENING",
      # Store baseline size for TR script
      BASELINE_MM = baseline_mm,
      MEAS_TYPE   = trtestcd
    )
  }

  # ── Non-target lesions ────────────────────────────────────────────────────
  if (n_nontarget > 0L) {
    nt_locs <- sample(nontarget_locations, n_nontarget, replace = TRUE)

    for (k in seq_len(n_nontarget)) {
      seq_n <- seq_n + 1L
      lesion_id <- sprintf("%s-NT%02d", subj$SUBJID, k)

      lat <- if (nt_locs[k] %in% c("BRAIN", "ADRENAL GLAND")) {
        sample(c("LEFT", "RIGHT"), 1L)
      } else ""

      tu_recs[[seq_n]] <- tibble(
        STUDYID   = STUDYID,
        DOMAIN    = "TU",
        USUBJID   = subj$USUBJID,
        TUSEQ     = seq_n,
        TUREFID   = lesion_id,
        TULNKID   = lesion_id,
        TUORRES   = nt_locs[k],
        TUSTRESC  = nt_locs[k],
        TULOC     = nt_locs[k],
        TULAT     = lat,
        TUDIR     = "",
        TUMETHOD  = method_for_loc(nt_locs[k]),
        TUTESTCD  = "TUMIDENT",
        TUTEST    = "Tumour Identification",
        TUCAT     = "NON-TARGET",
        TUSPID    = sprintf("NT%d", k),
        TUSTDTC   = format(scr_date, "%Y-%m-%d"),
        TUDY      = as.integer(scr_date - c1d1) + 1L,
        VISIT     = "SCR",
        VISITNUM  = 0.0,
        EPOCH     = "SCREENING",
        BASELINE_MM = NA_real_,
        MEAS_TYPE   = "LDIAM"
      )
    }
  }

  bind_rows(tu_recs) %>% mutate(TUSEQ = row_number())
}

TU_full <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_tu)

# ── SDTM TU (core columns) and lesion map ─────────────────────────────────────
lesion_map <- TU_full %>%
  select(USUBJID, TUREFID, TULNKID, TUCAT, TUSPID, TULOC, TULAT,
         TUMETHOD, BASELINE_MM, MEAS_TYPE)

TU <- TU_full %>%
  select(STUDYID, DOMAIN, USUBJID, TUSEQ, TUREFID, TULNKID,
         TUORRES, TUSTRESC, TULOC, TULAT, TUDIR, TUMETHOD,
         TUTESTCD, TUTEST, TUCAT, TUSPID,
         TUSTDTC, TUDY, VISIT, VISITNUM, EPOCH)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(TU, "sdtm/tu.parquet")
write.csv(TU, "data-raw/raw_data/tu_raw.csv", row.names = FALSE, na = "")
write.csv(lesion_map, "data-raw/raw_data/tu_lesion_map.csv", row.names = FALSE, na = "")

cat("\n=== TU Domain Validation ===\n")
cat(sprintf("  Total TU records        : %d\n", nrow(TU)))
cat(sprintf("  Subjects with TU data   : %d / %d\n",
            n_distinct(TU$USUBJID), nrow(backbone)))
cat(sprintf("  Target lesions          : %d (%.1f per subject)\n",
            sum(TU$TUCAT == "TARGET"),
            mean(TU_full %>% group_by(USUBJID) %>%
                   filter(TUCAT == "TARGET") %>% tally() %>% pull(n))))
cat(sprintf("  Non-target lesions      : %d\n", sum(TU$TUCAT == "NON-TARGET")))
cat("\n  Target lesion locations:\n")
print(TU %>% filter(TUCAT == "TARGET") %>% count(TULOC, sort = TRUE))
cat("\n  Outputs written:\n")
cat("    sdtm/tu.parquet\n")
cat("    data-raw/raw_data/tu_raw.csv\n")
cat("    data-raw/raw_data/tu_lesion_map.csv\n")
cat("=== TU generation complete ===\n")
