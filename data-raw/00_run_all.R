# =============================================================================
# torivumab guidelines loaded
# 00_run_all.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Master Execution Script
# =============================================================================
#
# Run this script to regenerate all SDTM domains from scratch.
# All scripts use set.seed() for full reproducibility.
#
# Each domain script is run in a FRESH R subprocess (via Rscript) so that
# memory from large domains (VS ~49K rows, LB ~91K rows) is fully released
# before the next script starts. This prevents segfaults from cumulative
# heap pressure when source()-ing all scripts in a single R session.
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
#   15_label_domains.R → attaches SDTMIG v3.4 labels to all sdtm/*.parquet
#
# Outputs: sdtm/*.parquet, data-raw/raw_data/*.csv
# Session info saved to: data-raw/session_info.txt
# =============================================================================

if (!file.exists("data-raw/00_run_all.R")) {
  stop("Run this script from the project root directory (torivumab-nsclc-301/).")
}

# ── Locate Rscript executable ─────────────────────────────────────────────────
# Prefer the same R that is running this orchestrator script; fall back to PATH.
rscript <- file.path(R.home("bin"), "Rscript")
if (.Platform$OS.type == "windows") rscript <- paste0(rscript, ".exe")
if (!file.exists(rscript)) rscript <- Sys.which("Rscript")
if (nchar(rscript) == 0L) stop("Rscript not found — check your R installation.")

cat("=============================================================\n")
cat("  SIMULATED-TORIVUMAB-2026 — Phase 3 Data Generation\n")
cat("  Started :", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("  Rscript :", rscript, "\n")
cat("=============================================================\n\n")

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
  "data-raw/14_dd.R",
  "data-raw/15_label_domains.R"  # attaches SDTMIG v3.4 labels to all Parquet files
)

timings    <- numeric(length(scripts))
exit_codes <- integer(length(scripts))
names(timings)    <- scripts
names(exit_codes) <- scripts

for (i in seq_along(scripts)) {
  script <- scripts[i]
  cat(sprintf("\n--- Running %s ---\n", script))

  t_start    <- proc.time()["elapsed"]
  exit_codes[i] <- system2(
    command = rscript,
    args    = c("--vanilla", shQuote(script)),
    stdout  = ""   # inherit stdout → printed directly to console
  )
  elapsed    <- round(proc.time()["elapsed"] - t_start, 1L)
  timings[i] <- elapsed

  status_str <- if (exit_codes[i] == 0L) "OK" else sprintf("FAILED (exit %d)", exit_codes[i])
  cat(sprintf("    [%s — %s — %.1f s]\n", basename(script), status_str, elapsed))

  # Abort pipeline on first failure: downstream scripts depend on earlier outputs
  if (exit_codes[i] != 0L) {
    cat(sprintf("\n  *** Pipeline aborted at %s ***\n", script))
    cat("  Fix the error above, then re-run 00_run_all.R.\n")
    cat("  Scripts that already completed do NOT need to be re-run\n")
    cat("  unless you want a clean regeneration from scratch.\n")
    quit(save = "no", status = 1L)
  }
}

# ── Summary ────────────────────────────────────────────────────────────────────
any_failed <- any(exit_codes != 0L)

cat("\n=============================================================\n")
cat(if (any_failed) "  PHASE 3 GENERATION — COMPLETED WITH ERRORS\n"
    else             "  PHASE 3 GENERATION COMPLETE\n")
cat(sprintf("  Finished : %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("=============================================================\n\n")

# Domain inventory
sdtm_files <- sort(list.files("sdtm/", pattern = "\\.parquet$", full.names = TRUE))
cat("  SDTM Parquet outputs:\n")
for (f in sdtm_files) {
  sz <- round(file.size(f) / 1024, 0)
  cat(sprintf("    %-30s %5d KB\n", basename(f), sz))
}
cat(sprintf("\n  Total SDTM size: %.1f MB\n",
            sum(file.size(sdtm_files)) / 1024^2))

cat("\n  Timing summary:\n")
for (i in seq_along(scripts)) {
  ok <- if (exit_codes[i] == 0L) "" else " *** FAILED"
  cat(sprintf("    %-40s %6.1f s%s\n", basename(scripts[i]), timings[i], ok))
}
cat(sprintf("\n  Total elapsed: %.1f seconds (%.1f minutes)\n",
            sum(timings), sum(timings) / 60))

# Save session info
session_info_path <- "data-raw/session_info.txt"
writeLines(c(
  "SIMULATED-TORIVUMAB-2026 — Phase 3 Data Generation",
  sprintf("Generated : %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("Rscript   : %s", rscript),
  sprintf("R version : %s", R.version.string),
  "",
  "Scripts run (in order):",
  sprintf("  %s  exit=%d  %.1fs", basename(scripts), exit_codes, timings)
), session_info_path)
cat(sprintf("\n  Session info saved to: %s\n", session_info_path))
cat("=============================================================\n")
