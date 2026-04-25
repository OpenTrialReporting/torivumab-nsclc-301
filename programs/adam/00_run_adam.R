# =============================================================================
# Program    : 00_run_adam.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Master controller — sources all ADaM derivation programs
#              in the dependency order required by ADaMIG.
# Precondition : All SDTM parquet files must exist in datasets/sdtm/
#                (run programs/sdtm/00_run_sdtm.R first)
# Run from   : Project root (torivumab-nsclc-301/)
# Usage      : Rscript programs/adam/00_run_adam.R
#              OR source("programs/adam/00_run_adam.R") from R console
# =============================================================================

# Verify working directory is project root
if (!file.exists("datasets/sdtm")) {
  stop(
    "Working directory must be the project root (containing datasets/sdtm/).\n",
    "Current directory: ", getwd(), "\n",
    "Run: setwd('path/to/torivumab-nsclc-301') before sourcing."
  )
}

# Check SDTM inputs exist
required_sdtm <- c("dm", "ds", "ex", "ae", "lb", "tr", "tu", "rs", "dd", "suppdm")
missing_sdtm <- required_sdtm[
  !file.exists(file.path("datasets", "sdtm", paste0(required_sdtm, ".parquet")))
]
if (length(missing_sdtm) > 0) {
  stop("Missing SDTM parquet files: ",
       paste(missing_sdtm, collapse = ", "),
       "\nRun programs/sdtm/00_run_sdtm.R first.")
}

# Ensure output directory exists
dir.create("datasets/adam", showWarnings = FALSE, recursive = TRUE)

# ── ADaM execution order (per PHASE-5-APPROACH.md §Build Order) ──────────────
# ADSL first (subject-level anchor; population flags, treatment dates)
# ADAE, ADLB, ADTR: independent after ADSL
# ADRS: requires ADSL + ADTR
# ADTTE: requires ADSL + ADRS

adam_programs <- c(
  "adsl",   # ADSL  — Subject-Level Analysis Dataset
  "adae",   # ADAE  — Adverse Event Analysis Dataset
  "adlb",   # ADLB  — Laboratory Test Results BDS
  "adtr",   # ADTR  — Tumor Results BDS
  "adrs",   # ADRS  — Oncology Response Analysis Dataset
  "adtte"   # ADTTE — Time-to-Event Analysis Dataset
)

run_adam <- function(dataset) {
  prog_path <- file.path("programs", "adam", paste0(dataset, ".R"))
  message("\n", strrep("=", 70))
  message("Running: ", prog_path)
  message(strrep("=", 70))

  withCallingHandlers(
    tryCatch(
      {
        source(prog_path, local = new.env(parent = globalenv()))
        message("SUCCESS: ", toupper(dataset))
      },
      error = function(e) {
        message("ERROR in ", toupper(dataset), ": ", conditionMessage(e))
        stop("Execution halted in ", toupper(dataset), ". Fix and re-run.")
      }
    ),
    warning = function(w) {
      message("WARNING in ", toupper(dataset), ": ", conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
}

start_time <- proc.time()

for (ds in adam_programs) {
  run_adam(ds)
}

elapsed <- proc.time() - start_time

message("\n", strrep("=", 70))
message("All ADaM datasets completed.")
message(sprintf("Total elapsed time: %.1f seconds", elapsed["elapsed"]))
message(strrep("=", 70))

# ── Summary: list output parquet files ───────────────────────────────────────
out_files <- list.files("datasets/adam", pattern = "\\.parquet$", full.names = TRUE)
if (length(out_files) > 0) {
  message("\nADaM parquet files written:")
  for (f in sort(out_files)) {
    size_kb <- round(file.info(f)$size / 1024, 1)
    message(sprintf("  %-40s %8.1f KB", basename(f), size_kb))
  }
} else {
  message("WARNING: No ADaM parquet files found in datasets/adam/")
}

# ── Gate 4 population reconciliation check ───────────────────────────────────
message("\n── Gate 4 reconciliation ──────────────────────────────────────────")
tryCatch({
  library(arrow, quietly = TRUE)
  adsl <- as.data.frame(arrow::read_parquet("datasets/adam/adsl.parquet"))
  message("ADSL rows     : ", nrow(adsl))
  message("ITTFL=Y       : ", sum(adsl$ITTFL  == "Y", na.rm = TRUE))
  message("SAFFL=Y       : ", sum(adsl$SAFFL  == "Y", na.rm = TRUE))
  message("PPROTFL=Y     : ", sum(adsl$PPROTFL == "Y", na.rm = TRUE))
  message("DTHFL=Y       : ", sum(adsl$DTHFL  == "Y", na.rm = TRUE))
  cat("\nTreatment arm distribution:\n")
  print(table(adsl$TRT01P, useNA = "ifany"))

  adtte <- as.data.frame(arrow::read_parquet("datasets/adam/adtte.parquet"))
  os_sub <- adtte[adtte$PARAMCD == "OS" & adtte$ITTFL == "Y", ]
  if (nrow(os_sub) > 0) {
    message(sprintf("\nOS  events=%d (%.0f%%)  median=%.0f days",
                    sum(os_sub$CNSR == 0),
                    100 * mean(os_sub$CNSR == 0),
                    median(os_sub$AVAL, na.rm = TRUE)))
  }
  pfs_sub <- adtte[adtte$PARAMCD == "PFS" & adtte$ITTFL == "Y", ]
  if (nrow(pfs_sub) > 0) {
    message(sprintf("PFS events=%d (%.0f%%)  median=%.0f days",
                    sum(pfs_sub$CNSR == 0),
                    100 * mean(pfs_sub$CNSR == 0),
                    median(pfs_sub$AVAL, na.rm = TRUE)))
  }
}, error = function(e) {
  message("Gate 4 check skipped: ", conditionMessage(e))
})

message(strrep("=", 70))
