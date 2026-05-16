# torivumab guidelines loaded
# =============================================================================
# programs/qc/compare_sdtm.R
# Compare primary SDTM parquets against an independent QC re-derivation.
#
# Usage      : Rscript programs/qc/compare_sdtm.R <primary_dir> <qc_dir>
# Defaults   : <primary_dir> = datasets/sdtm
#              <qc_dir>      = qc/sdtm   (where the QC programmer's outputs
#                                         should be placed)
# Output     : qc/reports/<timestamp>/sdtm-compare.md
# =============================================================================

source(file.path("programs", "qc", "_compare_helpers.R"))

args <- commandArgs(trailingOnly = TRUE)
primary_dir <- if (length(args) >= 1) args[1] else "datasets/sdtm"
qc_dir      <- if (length(args) >= 2) args[2] else "qc/sdtm"

if (!dir.exists(primary_dir)) stop("Primary dir not found: ", primary_dir)
if (!dir.exists(qc_dir))      stop("QC dir not found: ", qc_dir,
                                    "\nPlace QC parquets there and re-run, ",
                                    "or run with explicit arguments.")

ts <- format(Sys.time(), "%Y%m%dT%H%M%S")
report_path <- file.path("qc", "reports", ts, "sdtm-compare.md")

compare_directories(
  primary_dir = primary_dir,
  qc_dir      = qc_dir,
  report_path = report_path,
  layer_label = "SDTM"
)
