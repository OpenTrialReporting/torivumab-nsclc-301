# torivumab guidelines loaded
# =============================================================================
# programs/qc/compare_adam.R
# Compare primary ADaM parquets against an independent QC re-derivation.
# Also performs Cox HR validation per the VALIDATION-PLAN.md §6.3 acceptance
# criteria (HRs within ±0.05; KM medians within ±0.5 mo).
#
# Usage      : Rscript programs/qc/compare_adam.R <primary_dir> <qc_dir>
# Defaults   : <primary_dir> = datasets/adam
#              <qc_dir>      = qc/adam
# Output     : qc/reports/<timestamp>/adam-compare.md
# =============================================================================

source(file.path("programs", "qc", "_compare_helpers.R"))

suppressPackageStartupMessages(library(survival))

args <- commandArgs(trailingOnly = TRUE)
primary_dir <- if (length(args) >= 1) args[1] else "datasets/adam"
qc_dir      <- if (length(args) >= 2) args[2] else "qc/adam"

if (!dir.exists(primary_dir)) stop("Primary dir not found: ", primary_dir)
if (!dir.exists(qc_dir))      stop("QC dir not found: ", qc_dir,
                                    "\nPlace QC parquets there and re-run.")

ts <- format(Sys.time(), "%Y%m%dT%H%M%S")
report_dir  <- file.path("qc", "reports", ts)
report_path <- file.path(report_dir, "adam-compare.md")

# Step 1 — structural comparison
results <- compare_directories(
  primary_dir = primary_dir,
  qc_dir      = qc_dir,
  report_path = report_path,
  layer_label = "ADaM"
)

# Step 2 — statistical reproducibility on ADTTE per PARAMCD
hr_check_report <- file.path(report_dir, "adam-hr-check.md")

hr_check <- function(adtte_path, label) {
  if (!file.exists(adtte_path)) return(NULL)
  ad <- as.data.frame(read_parquet(adtte_path))
  out <- list()
  for (p in unique(ad$PARAMCD)) {
    sub <- ad[ad$PARAMCD == p, ]
    sub$is_trt <- as.integer(sub$TRT01P == "Torivumab + Chemotherapy")
    sub <- sub[!is.na(sub$AVAL), ]
    if (length(unique(sub$is_trt)) < 2 || sum(sub$CNSR == 0) < 5) next
    fit <- tryCatch(coxph(Surv(AVAL, CNSR == 0) ~ is_trt, data = sub),
                     error = function(e) NULL)
    if (is.null(fit)) next
    s <- summary(fit)$conf.int
    fit_km <- survfit(Surv(AVAL, CNSR == 0) ~ is_trt, data = sub)
    tab <- summary(fit_km)$table
    med <- tab[, "median"]
    out[[p]] <- list(
      PARAMCD = p,
      HR      = s[1, "exp(coef)"],
      lo      = s[1, "lower .95"],
      hi      = s[1, "upper .95"],
      n_evt   = sum(sub$CNSR == 0),
      med_trt = unname(med["is_trt=1"]) / 30.4375,
      med_pbo = unname(med["is_trt=0"]) / 30.4375
    )
  }
  out
}

p_results <- hr_check(file.path(primary_dir, "adtte.parquet"), "Primary")
q_results <- hr_check(file.path(qc_dir,      "adtte.parquet"), "QC")

cat("\n=== ADTTE Cox HR check ===\n")
out_hr <- c(
  "# ADTTE Cox HR validation",
  "",
  sprintf("**Generated:** %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("**Primary:** %s", file.path(primary_dir, "adtte.parquet")),
  sprintf("**QC:**      %s", file.path(qc_dir,      "adtte.parquet")),
  "",
  "Acceptance: HR within ±0.05 of primary; KM median within ±0.5 months.",
  "",
  "| PARAMCD | Primary HR (CI) | QC HR (CI) | ΔHR | Primary med TRT/PBO (mo) | QC med TRT/PBO (mo) | Status |",
  "|---|---|---|---|---|---|---|"
)
all_pass <- TRUE
all_params <- sort(unique(c(names(p_results), names(q_results))))
for (p in all_params) {
  pr <- p_results[[p]]; qr <- q_results[[p]]
  if (is.null(pr) || is.null(qr)) {
    out_hr <- c(out_hr, sprintf("| %s | %s | %s | — | — | — | MISSING |",
                                 p,
                                 if (is.null(pr)) "—" else "(primary present)",
                                 if (is.null(qr)) "—" else "(QC present)"))
    all_pass <- FALSE
    next
  }
  delta_hr <- abs(pr$HR - qr$HR)
  # NA medians are an inherent property of some endpoints (e.g. TTR for
  # non-responders) — compare only when both sides have a value.
  med_trt_ok <- (is.na(pr$med_trt) && is.na(qr$med_trt)) ||
                  (!is.na(pr$med_trt) && !is.na(qr$med_trt) &&
                   abs(pr$med_trt - qr$med_trt) <= 0.5)
  med_pbo_ok <- (is.na(pr$med_pbo) && is.na(qr$med_pbo)) ||
                  (!is.na(pr$med_pbo) && !is.na(qr$med_pbo) &&
                   abs(pr$med_pbo - qr$med_pbo) <= 0.5)
  hr_ok      <- delta_hr <= 0.05
  status     <- if (hr_ok && med_trt_ok && med_pbo_ok) "PASS" else "FAIL"
  if (status == "FAIL") all_pass <- FALSE
  fmt_med <- function(x) if (is.na(x)) "NE" else sprintf("%.1f", x)
  out_hr <- c(out_hr, sprintf(
    "| %s | %.3f (%.3f, %.3f) | %.3f (%.3f, %.3f) | %.3f | %s / %s | %s / %s | %s |",
    p, pr$HR, pr$lo, pr$hi, qr$HR, qr$lo, qr$hi, delta_hr,
    fmt_med(pr$med_trt), fmt_med(pr$med_pbo),
    fmt_med(qr$med_trt), fmt_med(qr$med_pbo), status))
  cat(sprintf("  %-6s  %s  (ΔHR=%.3f, med TRT %s vs %s)\n",
              p, status, delta_hr, fmt_med(pr$med_trt), fmt_med(qr$med_trt)))
}
out_hr <- c(out_hr, "",
             if (all_pass) "✅ All PARAMCDs pass HR + median tolerance."
             else          "⚠️ One or more PARAMCDs fail HR or median tolerance — see table.")
writeLines(out_hr, hr_check_report)
cat(sprintf("HR check report: %s\n", hr_check_report))
