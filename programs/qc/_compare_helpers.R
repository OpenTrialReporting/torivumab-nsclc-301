# torivumab guidelines loaded
# =============================================================================
# programs/qc/_compare_helpers.R
# Shared utilities for primary-vs-QC dataset comparison. Sourced by
# compare_sdtm.R and compare_adam.R.
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(diffdf)
})

# Read a parquet dataset, drop labelled attributes that may differ
# spuriously between implementations.
read_ds <- function(path) {
  df <- as.data.frame(read_parquet(path))
  attr(df, "spec") <- NULL
  for (j in seq_along(df)) attributes(df[[j]])$label <- NULL
  df
}

# Compare two single datasets. Returns a list with summary fields.
compare_one_dataset <- function(primary_path, qc_path, ds_name, keys = NULL) {
  if (!file.exists(primary_path)) {
    return(list(name = ds_name, status = "MISSING_PRIMARY",
                  summary = sprintf("Primary file not found: %s", primary_path),
                  details = NULL))
  }
  if (!file.exists(qc_path)) {
    return(list(name = ds_name, status = "MISSING_QC",
                  summary = sprintf("QC file not found: %s", qc_path),
                  details = NULL))
  }

  a <- read_ds(primary_path)
  b <- read_ds(qc_path)

  # Dimension check
  if (!identical(dim(a), dim(b))) {
    return(list(name = ds_name, status = "FAIL — dim",
                  summary = sprintf("Dim mismatch: primary %s vs QC %s",
                                     paste(dim(a), collapse="x"),
                                     paste(dim(b), collapse="x")),
                  details = NULL))
  }

  # Variable name + order check
  if (!identical(names(a), names(b))) {
    missing_in_qc <- setdiff(names(a), names(b))
    extra_in_qc   <- setdiff(names(b), names(a))
    return(list(name = ds_name, status = "FAIL — var list",
                  summary = sprintf("Vars differ. Missing in QC: %s. Extra in QC: %s.",
                                     ifelse(length(missing_in_qc)==0, "none", paste(missing_in_qc, collapse=", ")),
                                     ifelse(length(extra_in_qc)==0,   "none", paste(extra_in_qc,   collapse=", "))),
                  details = NULL))
  }

  # Resolve unique keys per dataset shape
  pick_keys <- function(df) {
    nms <- names(df)
    # 1) Explicit user keys take priority
    if (!is.null(keys)) return(intersect(keys, nms))
    # 2) RELREC: STUDYID + USUBJID + RDOMAIN + RELID + IDVAR + IDVARVAL
    if (all(c("RELID","IDVARVAL") %in% nms))
      return(intersect(c("STUDYID","USUBJID","RDOMAIN","RELID","IDVAR","IDVARVAL"), nms))
    # 3) SUPP--: STUDYID + RDOMAIN + USUBJID + IDVAR + IDVARVAL + QNAM
    if ("QNAM" %in% nms)
      return(intersect(c("STUDYID","RDOMAIN","USUBJID","IDVAR","IDVARVAL","QNAM"), nms))
    # 4) BDS (ADaM): STUDYID + USUBJID + PARAMCD + AVISITN (+ AVAL for ties)
    if (all(c("PARAMCD","USUBJID") %in% nms)) {
      k <- intersect(c("STUDYID","USUBJID","PARAMCD","AVISITN","AVISIT","ADT"), nms)
      # Validate uniqueness; if not unique, append more discriminators
      if (anyDuplicated(df[, k, drop = FALSE]) > 0) {
        for (extra in c("AVAL","AVALC","LBSEQ","TRLINKID")) {
          if (extra %in% nms) {
            k <- c(k, extra)
            if (anyDuplicated(df[, k, drop = FALSE]) == 0) break
          }
        }
      }
      return(k)
    }
    # 5) OCCDS / events / interventions: STUDYID + USUBJID + --SEQ
    seq_vars <- nms[grepl("SEQ$", nms)]
    if (length(seq_vars) > 0)
      return(intersect(c("STUDYID","USUBJID", seq_vars), nms))
    # 6) Subject-level (DM, ADSL): STUDYID + USUBJID
    if (all(c("STUDYID","USUBJID") %in% nms))
      return(c("STUDYID","USUBJID"))
    # 7) Fallback
    nms[1:min(2, length(nms))]
  }
  keys_use <- pick_keys(a)
  # Ensure keys are unique in both frames — otherwise diffdf will fail
  if (anyDuplicated(a[, keys_use, drop = FALSE]) > 0 ||
      anyDuplicated(b[, keys_use, drop = FALSE]) > 0) {
    keys_use <- names(a)  # use full row as key (slow but always works)
  }

  dd <- tryCatch(diffdf(a, b, keys = keys_use, suppress_warnings = TRUE),
                  error = function(e) e)
  if (inherits(dd, "error")) {
    # Fall back to direct identical() check when diffdf can't establish
    # unique keys (e.g. RELREC has legitimate duplicate parent rows).
    if (identical(a, b)) {
      return(list(name = ds_name, status = "PASS",
                  summary = sprintf("%d rows × %d cols identical (no unique key; identical() used)",
                                     nrow(a), ncol(a)),
                  details = NULL))
    }
    # Quantify the diff: how many rows differ?
    a_keys <- do.call(paste, c(a, sep = ""))
    b_keys <- do.call(paste, c(b, sep = ""))
    n_only_a <- sum(!a_keys %in% b_keys)
    n_only_b <- sum(!b_keys %in% a_keys)
    return(list(name = ds_name, status = "FAIL — content (no unique key)",
                summary = sprintf("Cannot establish unique keys (%s). %d rows in primary not in QC; %d rows in QC not in primary.",
                                   conditionMessage(dd), n_only_a, n_only_b),
                details = NULL))
  }

  has_diffs <- length(dd) > 0
  if (!has_diffs) {
    return(list(name = ds_name, status = "PASS",
                  summary = sprintf("%d rows × %d cols match (keys: %s)",
                                     nrow(a), ncol(a), paste(keys_use, collapse=", ")),
                  details = NULL))
  }

  # Summarise diffdf output
  msgs <- capture.output(print(dd))
  list(
    name = ds_name, status = "FAIL — content",
    summary = sprintf("%d categories of difference (keys: %s)",
                       length(dd), paste(keys_use, collapse=", ")),
    details = paste(msgs, collapse = "\n")
  )
}

# Run a comparison across all parquets in two directories and emit a
# markdown report.
compare_directories <- function(primary_dir, qc_dir, report_path,
                                  layer_label = "Dataset", keys = NULL) {
  primary_files <- list.files(primary_dir, pattern = "\\.parquet$", full.names = FALSE)
  qc_files      <- list.files(qc_dir,      pattern = "\\.parquet$", full.names = FALSE)
  all_names <- sort(unique(c(primary_files, qc_files)))

  results <- lapply(all_names, function(f) {
    compare_one_dataset(file.path(primary_dir, f),
                        file.path(qc_dir,      f),
                        sub("\\.parquet$", "", f),
                        keys = keys)
  })

  n_pass <- sum(vapply(results, function(r) r$status == "PASS",  logical(1)))
  n_fail <- sum(vapply(results, function(r) startsWith(r$status, "FAIL"), logical(1)))
  n_miss <- sum(vapply(results, function(r) startsWith(r$status, "MISSING"), logical(1)))
  n_err  <- sum(vapply(results, function(r) r$status == "ERROR", logical(1)))

  # Markdown
  dir.create(dirname(report_path), showWarnings = FALSE, recursive = TRUE)
  out <- c(
    sprintf("# %s comparison — primary vs QC", layer_label),
    "",
    sprintf("**Generated:** %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    sprintf("**Primary directory:** `%s`", primary_dir),
    sprintf("**QC directory:** `%s`", qc_dir),
    "",
    sprintf("**Total datasets:** %d  ·  PASS: %d  ·  FAIL: %d  ·  MISSING: %d  ·  ERROR: %d",
            length(results), n_pass, n_fail, n_miss, n_err),
    "",
    if (n_fail == 0 && n_miss == 0 && n_err == 0)
      sprintf("✅ **All %d datasets match.**", n_pass)
    else
      sprintf("⚠️ **%d dataset(s) require attention.**", n_fail + n_miss + n_err),
    "",
    "## Per-dataset summary",
    "",
    "| Dataset | Status | Summary |",
    "|---|---|---|"
  )
  for (r in results) {
    out <- c(out, sprintf("| %s | %s | %s |", r$name, r$status, r$summary))
  }

  # Detailed sections for failures
  fail_results <- Filter(function(r) startsWith(r$status, "FAIL") && !is.null(r$details),
                          results)
  if (length(fail_results) > 0) {
    out <- c(out, "", "## Detailed findings")
    for (r in fail_results) {
      out <- c(out, "", sprintf("### %s — %s", r$name, r$status), "",
                "```", r$details, "```")
    }
  }

  out <- c(out, "",
            "## Conventions",
            "",
            "- `PASS` = `diffdf` reports no differences between primary and QC parquets.",
            "- `FAIL — dim` = number of rows or columns differs.",
            "- `FAIL — var list` = variable names or order differ.",
            "- `FAIL — content` = same shape but values differ (see details).",
            "- `MISSING_PRIMARY` / `MISSING_QC` = one side does not have the file.",
            "- `ERROR` = `diffdf` failed to run (check parquet integrity).",
            "",
            "Labels and `arrow` metadata are stripped before comparison.")
  writeLines(out, report_path)

  cat(sprintf("\n=== %s comparison ===\n", layer_label))
  cat(sprintf("  PASS: %d  FAIL: %d  MISSING: %d  ERROR: %d\n",
              n_pass, n_fail, n_miss, n_err))
  cat(sprintf("  Report: %s\n", report_path))

  invisible(results)
}
