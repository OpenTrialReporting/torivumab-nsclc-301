###############################################################################
# 00_simulate_raw.R
# Master controller — SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Sets global seed and sources all domain simulation scripts in order.
# Output CSVs land in: raw/
###############################################################################

set.seed(20260301)

# ── paths ──────────────────────────────────────────────────────────────────
# Resolve script directory robustly across Rscript, RStudio, and source()
.resolve_script_dir <- function() {
  # 1. commandArgs (Rscript path/to/00_simulate_raw.R)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(dirname(sub("^--file=", "", file_arg))))
  }
  # 2. sys.frames (source() call)
  for (i in sys.nframe():1) {
    env <- sys.frame(i)
    if (exists("ofile", envir = env, inherits = FALSE)) {
      return(normalizePath(dirname(get("ofile", envir = env))))
    }
  }
  # 3. RStudio API
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    ctx <- tryCatch(rstudioapi::getActiveDocumentContext(), error = NULL)
    if (!is.null(ctx) && nchar(ctx$path) > 0) {
      return(normalizePath(dirname(ctx$path)))
    }
  }
  # 4. Hardcoded fallback
  normalizePath(file.path(Sys.getenv("R_SCRIPTS_DIR",
    "C:/Users/lgaka/Downloads/torivumab-nsclc-301/programs/raw")))
}

PROGRAMS_DIR <- .resolve_script_dir()
RAW_DIR      <- normalizePath(file.path(PROGRAMS_DIR, "..", "..", "raw"),
                              mustWork = FALSE)

if (!dir.exists(RAW_DIR)) dir.create(RAW_DIR, recursive = TRUE)

# ── packages (install if missing) ─────────────────────────────────────────
required_pkgs <- c("dplyr", "lubridate", "readr", "tidyr", "stringr", "purrr")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(readr)
  library(tidyr)
  library(stringr)
  library(purrr)
})

# ── global constants shared across domain scripts ──────────────────────────
N_SUBJECTS     <- 450
N_SITES        <- 15
ENROL_START    <- as.Date("2022-03-01")
ENROL_END      <- as.Date("2023-09-30")
DATA_CUTOFF    <- as.Date("2025-01-31")
ARMS           <- c("Torivumab + Chemotherapy", "Placebo + Chemotherapy")

# Survival parameters (embedded — not exposed as columns)
LAMBDA_OS_TRT  <- log(2) / 21.5   # months
LAMBDA_OS_PBO  <- log(2) / 13.3
LAMBDA_PFS_TRT <- log(2) / 10.5
LAMBDA_PFS_PBO <- log(2) / 5.8
ORR_TRT        <- 0.44
ORR_PBO        <- 0.20
IRAE_PROB_TRT  <- 0.35
IRAE_PROB_PBO  <- 0.05
G3P_PROB_TRT   <- 0.28
G3P_PROB_PBO   <- 0.22

message("=== CTX-NSCLC-301 Raw Data Simulation ===")
message("Seed: 20260301 | N = ", N_SUBJECTS, " | Cut-off: ", DATA_CUTOFF)
message("")

# ── source domain scripts in order ──────────────�