# =============================================================================
# torivumab guidelines loaded
# 00_run_all.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Master Execution Script
# =============================================================================
#
# Run this script to regenerate all SDTM domains from scratch.
# All scripts use set.seed() for full reproducibility.
#
# Dependency order (must be respected):
#   01_dm.R     → DM + SUPPDM + subject_backbone.csv (BACKBONE — run first)
#   02_ex.R     → EX                (requires: backbone)
#   03_ds.R     → DS                (requires: backbone)
#   04_ae.R     → AE                (requires: backbone)
#   05_cm.R     → CM                (requires: backbone)
#   06_mh.R     → MH                (requires: backbone)
#   07_su.R     → SU + SUPPSU       (requires: backbone)
#   08_vs.R     → VS                (requires: backbone)
#   09_lb.R     → LB                (requires: backbone)
#   10_pe.R     → PE                (requires: backbone)
#   11_tu.R     → TU + lesion_map   (requires: backbone)
#   12_tr.R     → TR + sum_diam     (requires: backbone + lesion_map)
#   13_rs.R     → RS                (requires: backbone + sum_diam)
#   14_dd.R     → DD                (requires: backbone)
#
# Outputs: sdtm/*.parquet, data-raw/raw_data/*.csv
# Session info saved to: data-raw/session_info.txt
# =============================================================================

# Set working directory to project root
# (adjust if running interactively from a different location)
if (!file.exists("data-raw/00_run_all.R")) {
  stop("Run this script from the project root directory (torivumab-nsclc-301/).")
}

cat("=============================================================\n")
cat("  SIMULATED-TORIVUMAB-2026 — Phase 3 Data Generation\n")
cat("  Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=============================================================\n\n")

# Ordered list of scripts
scripts <- c(
  "data-raw/01_dm.R",
  "data-raw/02_ex.R",
  "data-raw/03_ds.R",
  "data-raw/04_ae.R",
  "data-raw/05_cm.R",
  "data-raw/06_mh.R",
  "data-raw/07_su.R",
  "data-raw/08_vs.R",
  "data-raw/09_lb.R",
  "data-raw/10_pe.R",
  "data-raw/11_tu.R",
  "data-raw/12_tr.R",
  "data-raw/13_rs.R",
  "data-raw/14_dd.R"
)

timings <- list()

for (script in scripts) {
  cat(sprintf("\n--- Running %s ---\n", script))
  t_start <- proc.time()["elapsed"]
  source(script, echo = FALSE)
  t_end <- proc.time()["elapsed"]
  elapsed <- round(t_end - t_start, 1)
  timings[[script]] <- elapsed
  cat(sprintf("    [%s completed in %.1f seconds]\n", script, elapsed))
}

# ── Summary ────────────────────────────────────────────────────────────────────
cat("\n=============================================================\n")
cat("  PHASE 3 GENERATION COMPLETE\n")
cat(sprintf("  Finished: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("=============================================================\n\n")

# Domain inventory
sdtm_files <- list.files("sdtm/", pattern = "\\.parquet$", full.names = TRUE)
cat("  SDTM Parquet outputs:\n")
for (f in sdtm_files) {
  sz  <- round(file.size(f) / 1024, 0)
  cat(sprintf("    %-30s %5d KB\n", basename(f), sz))
}

cat("\n  Timing summary:\n")
for (s in names(timings)) {
  cat(sprintf("    %-40s %.1f s\n", basename(s), timings[[s]]))
}
cat(sprintf("\n  Total elapsed: %.1f seconds\n",
            sum(unlist(timings))))

# Save session info
session_info_path <- "data-raw/session_info.txt"
sink(session_info_path)
cat("SIMULATED-TORIVUMAB-2026 — Phase 3 Data Generation\n")
cat(sprintf("Generated: %s\n\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
sessionInfo()
sink()
cat(sprintf("\n  Session info saved to: %s\n", session_info_path))
cat("\n  All outputs committed-ready in sdtm/ and data-raw/raw_data/\n")
cat("=============================================================\n")
