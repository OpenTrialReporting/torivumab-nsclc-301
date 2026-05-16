# torivumab guidelines loaded
# =============================================================================
# Program    : 00_run_tfl.R
# Purpose    : Master controller — sources all TFL production scripts.
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Run from   : Project root (torivumab-nsclc-301/)
# Usage      : Rscript programs/tfl/00_run_tfl.R
#              OR source("programs/tfl/00_run_tfl.R") from R console
# Phase 6a   : Focused pilot — 5 high-priority outputs across all 3 formats.
# Output dir : tfl/tables/   (RTF + DOCX + HTML per table)
#              tfl/figures/  (PNG per figure)
#              tfl/          (combined HTML and DOCX for review)
# =============================================================================

if (!file.exists("datasets/adam")) {
  stop("Working directory must be the project root (containing datasets/adam/).\n",
       "Current directory: ", getwd())
}

PROGRAMS_TFL_DIR <- "programs/tfl"

# Load shared helpers once; scripts source nothing else (they use what _helpers
# placed in the global env).
source(file.path(PROGRAMS_TFL_DIR, "_helpers.R"))

tfl_programs <- c(
  # Phase 6a — efficacy + demographics
  "t_dm_01_demographics.R",        # Demographic & baseline characteristics
  "t_eff_01_os.R",                  # Overall Survival primary analysis
  "t_eff_03_pfs.R",                 # Progression-Free Survival
  "f_eff_01_km_os.R",               # KM curve — OS
  "f_eff_02_km_pfs.R",              # KM curve — PFS
  # Phase 6b — disposition + exposure
  "t_ds_01_disposition.R",          # Subject Disposition
  "t_ds_02_deviations.R",           # Major Protocol Deviations
  "t_ds_03_intercurrent_events.R",  # Intercurrent Events Summary (SAP §13.3)
  "t_ex_01_exposure.R",             # Study Drug Exposure
  # Phase 6c — efficacy completion (tables)
  "t_eff_02_km_probs_os.R",         # KM landmark probabilities — OS
  "t_eff_04_km_probs_pfs.R",        # KM landmark probabilities — PFS
  "t_eff_05_orr.R",                 # Objective Response Rate (BICR — Investigator here)
  "t_eff_06_dcr.R",                 # Disease Control Rate
  "t_eff_07_dor.R",                 # Duration of Response
  "t_eff_08_os_pp.R",               # OS in Per-Protocol Population (sensitivity)
  "t_eff_09_os_landmark.R",         # OS Landmark Analysis (sensitivity)
  "t_eff_10_os_rmst.R",             # OS RMST (estimand E1a)
  "t_eff_11_pfs_inv.R",             # PFS by Investigator (estimand E2a)
  "t_eff_12_os_wot.R",              # OS While-on-Treatment (estimand E1b)
  "t_eff_13_orr_itt.R",             # ORR ITT denominator (estimand E3a)
  # Phase 6c — efficacy completion (figures)
  "f_eff_03_waterfall.R",           # Waterfall — best % change SLD
  "f_eff_04_spider.R",              # Spider — SLD over time
  "f_eff_05_forest.R",              # Forest — OS HR by subgroup
  "f_eff_06_swimmer.R",             # Swimmer — responder timelines
  # Phase 6d — safety tables
  "t_ae_01_overall.R",              # Overall summary of AEs
  "t_ae_02_soc_pt.R",               # TEAEs by SOC + PT (>=5%)
  "t_ae_03_g3_plus.R",              # Grade >=3 TEAEs
  "t_ae_04_sae.R",                  # Serious AEs
  "t_ae_05_irae.R",                 # Immune-related AEs
  "t_ae_06_aesi.R",                 # AESIs by category
  "t_ae_07_deaths.R",               # Deaths summary
  "t_lb_01_shift.R",                # Lab shift table
  "t_lb_02_g3_plus.R",              # Lab Grade >=3
  # Phase 6d — listings
  "l_ae_01_sae.R",                  # SAE listing
  "l_ae_02_deaths.R",               # Deaths listing
  "l_ae_03_disc.R",                 # AEs leading to discontinuation
  "l_lb_01_g3_plus.R",              # Grade >=3 lab values listing
  "l_ds_01_deviations.R",           # Major protocol deviations listing
  # Phase 6e — pharma-standard descriptive tables (added 2026-05-17)
  "t_cm_01_conmed.R",               # Conmed by class/PT
  "t_vs_01_summary.R",              # VS mean change at key visits
  "t_vs_02_weight_shift.R",         # Weight change categories
  "t_mh_01_summary.R",              # MH by category/term
  "t_dv_01_deviations.R"            # Protocol deviations detail
)

run_tfl <- function(script) {
  prog_path <- file.path(PROGRAMS_TFL_DIR, script)
  message("\n", strrep("=", 70))
  message("Running: ", prog_path)
  message(strrep("=", 70))
  tryCatch(
    {
      source(prog_path, local = new.env(parent = globalenv()))
      message("SUCCESS: ", script)
    },
    error = function(e) {
      message("ERROR in ", script, ": ", conditionMessage(e))
      stop("Execution halted in ", script, ". Fix and re-run.")
    }
  )
}

start <- proc.time()
for (s in tfl_programs) run_tfl(s)

# Combined deliverables
combined_path <- file.path(PROGRAMS_TFL_DIR, "99_combine_outputs.R")
if (file.exists(combined_path)) {
  message("\n", strrep("=", 70))
  message("Running: ", combined_path)
  message(strrep("=", 70))
  source(combined_path, local = new.env(parent = globalenv()))
}

elapsed <- proc.time() - start
message("\n", strrep("=", 70))
message("All TFL outputs produced.")
message(sprintf("Total elapsed time: %.1f seconds", elapsed["elapsed"]))
message(strrep("=", 70))

# Inventory
tables  <- list.files(TFL_TABLES_DIR,  full.names = FALSE)
figures <- list.files(TFL_FIGURES_DIR, full.names = FALSE)
combined <- list.files("tfl", pattern = "^TFL-OUTPUTS", full.names = FALSE)
message("\nTables (tfl/tables/): ", length(tables))
for (f in sort(tables))  message("  ", f)
message("\nFigures (tfl/figures/): ", length(figures))
for (f in sort(figures)) message("  ", f)
message("\nCombined (tfl/): ", length(combined))
for (f in sort(combined)) message("  ", f)
