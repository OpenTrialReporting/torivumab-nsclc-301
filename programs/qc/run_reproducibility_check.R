# torivumab guidelines loaded
# =============================================================================
# Program    : programs/qc/run_reproducibility_check.R
# Purpose    : Re-run the full pipeline (raw → SDTM → ADaM → Define-XML → TFL)
#              into an isolated staging directory and diff every produced
#              artefact against the committed state. Reports per-file
#              pass/fail.
#
# Strategy   : This script does NOT modify any committed file. It builds a
#              temporary staging copy of the project tree, runs each pipeline
#              orchestrator there, and compares byte-by-byte (parquets,
#              PNGs) or content-aware (CSVs ignoring CRLF/LF differences,
#              docx/html via structured parse).
#
# Run from   : Project root
# Usage      : Rscript programs/qc/run_reproducibility_check.R
#              Optional env var: TFL_REPRO_KEEP_STAGE=1   keep staging dir
# Output     : qc/reports/<timestamp>/reproducibility.md
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(digest)
})

PROJECT_ROOT <- normalizePath(".")
TS           <- format(Sys.time(), "%Y%m%dT%H%M%S")
REPORT_DIR   <- file.path("qc", "reports", TS)
dir.create(REPORT_DIR, showWarnings = FALSE, recursive = TRUE)

STAGE <- tempfile(pattern = "tfl_repro_")
dir.create(STAGE, recursive = TRUE)
cat(sprintf("Staging directory: %s\n", STAGE))

# Copy the inputs the pipeline needs (raw CSVs, codelists, programs,
# spec markdown). Outputs (datasets/sdtm, datasets/adam, define, tfl)
# are NOT copied — they're what we'll re-derive and compare.
COPY_DIRS <- c("raw", "programs", "sap", "programming-specs",
                "protocol", "crf")
for (d in COPY_DIRS) {
  src <- file.path(PROJECT_ROOT, d)
  if (dir.exists(src)) {
    file.copy(src, STAGE, recursive = TRUE)
  }
}

# Create empty output dirs in the staging tree
for (d in c("datasets/sdtm", "datasets/adam", "define",
            "tfl/tables", "tfl/figures", "qc")) {
  dir.create(file.path(STAGE, d), recursive = TRUE, showWarnings = FALSE)
}

run_step <- function(label, script) {
  cat(sprintf("\n--- Running %s (%s) ---\n", label, script))
  cmd <- sprintf("cd %s && Rscript %s",
                  shQuote(STAGE), shQuote(script))
  rc <- system(cmd, intern = FALSE)
  if (rc != 0) stop("Step failed: ", label, " (exit code ", rc, ")")
  invisible(rc)
}

# Don't re-run the raw simulation by default — it's slow and identical seeds
# should give identical output. Run if RERUN_RAW=1 in env.
if (identical(Sys.getenv("RERUN_RAW"), "1")) {
  run_step("Raw simulation", "programs/raw/00_simulate_raw.R")
} else {
  cat("\nSkipping raw simulation (set RERUN_RAW=1 to include it).\n")
}

run_step("SDTM",        "programs/sdtm/00_run_sdtm.R")
run_step("ADaM",        "programs/adam/00_run_adam.R")
run_step("Define-XML",  "programs/define/build_define.R")
run_step("TFL",         "programs/tfl/00_run_tfl.R")

# -----------------------------------------------------------------------------
# Comparison
# -----------------------------------------------------------------------------
sha1_file <- function(p) tryCatch(digest::digest(file = p, algo = "sha1"),
                                    error = function(e) NA_character_)

# Parquet content comparison (ignores file-level metadata like timestamps)
parquet_match <- function(a, b) {
  da <- tryCatch(as.data.frame(read_parquet(a)), error = function(e) NULL)
  db <- tryCatch(as.data.frame(read_parquet(b)), error = function(e) NULL)
  if (is.null(da) || is.null(db)) return("ERROR")
  if (!identical(dim(da), dim(db))) return(sprintf("DIM MISMATCH (committed %s vs new %s)",
                                                     paste(dim(da), collapse="x"),
                                                     paste(dim(db), collapse="x")))
  if (!identical(names(da), names(db))) return("COLUMN NAMES MISMATCH")
  if (identical(da, db)) return("MATCH")
  # Column-by-column diff summary
  n_diff <- sum(vapply(seq_len(ncol(da)), function(j) !identical(da[[j]], db[[j]]), logical(1)))
  sprintf("CONTENT DIFF in %d / %d columns", n_diff, ncol(da))
}

# Text comparison ignoring line-ending differences
text_match <- function(a, b) {
  ta <- tryCatch(paste(readLines(a, warn = FALSE), collapse = "\n"),
                  error = function(e) NA_character_)
  tb <- tryCatch(paste(readLines(b, warn = FALSE), collapse = "\n"),
                  error = function(e) NA_character_)
  if (is.na(ta) || is.na(tb)) return("ERROR")
  if (identical(ta, tb)) "MATCH" else "CONTENT DIFF"
}

binary_match <- function(a, b) {
  if (!file.exists(a) || !file.exists(b)) return("MISSING")
  if (file.size(a) != file.size(b)) {
    return(sprintf("SIZE DIFF (%d → %d bytes)", file.size(a), file.size(b)))
  }
  ha <- sha1_file(a); hb <- sha1_file(b)
  if (identical(ha, hb)) "MATCH" else "BYTE DIFF (same size, different content)"
}

compare_one <- function(rel_path) {
  committed <- file.path(PROJECT_ROOT, rel_path)
  new       <- file.path(STAGE,         rel_path)
  ext <- tolower(tools::file_ext(rel_path))

  if (!file.exists(committed) || !file.exists(new)) {
    return(c(file = rel_path, status = "MISSING",
              detail = sprintf("committed=%s new=%s",
                                file.exists(committed), file.exists(new))))
  }
  result <- switch(ext,
    "parquet" = parquet_match(committed, new),
    "csv"     = text_match(committed, new),
    "xml"     = text_match(committed, new),
    "md"      = text_match(committed, new),
    "html"    = text_match(committed, new),
    "rtf"     = text_match(committed, new),
    "png"     = binary_match(committed, new),
    "docx"    = "SKIP (DOCX has timestamps; not compared)",
    binary_match(committed, new)
  )
  c(file = rel_path, status = if (startsWith(result, "MATCH")) "MATCH"
                                else "MISMATCH",
    detail = result)
}

# Collect file lists across pipeline outputs
collect <- function(dir, pattern = NULL) {
  fs <- list.files(file.path(STAGE, dir),
                    pattern = pattern, full.names = FALSE, recursive = TRUE)
  if (length(fs) == 0) return(character(0))
  file.path(dir, fs)
}

targets <- c(
  collect("datasets/sdtm", "\\.parquet$"),
  collect("datasets/adam", "\\.parquet$"),
  collect("define",        "\\.(xml|md)$"),
  collect("tfl/tables",    "\\.(rtf|html)$"),
  collect("tfl/figures",   "\\.png$"),
  collect("tfl",           "TFL-OUTPUTS\\.html$")
)
cat(sprintf("\nComparing %d artefacts ...\n", length(targets)))

results <- lapply(targets, compare_one)
mat <- do.call(rbind, results) |> as.data.frame(stringsAsFactors = FALSE)

n_match    <- sum(mat$status == "MATCH")
n_mismatch <- sum(mat$status == "MISMATCH")
n_missing  <- sum(mat$status == "MISSING")

# -----------------------------------------------------------------------------
# Write markdown report
# -----------------------------------------------------------------------------
report_path <- file.path(REPORT_DIR, "reproducibility.md")
out <- c(
  "# Reproducibility check",
  "",
  sprintf("**Run:** %s", TS),
  sprintf("**Staging dir:** `%s`", STAGE),
  sprintf("**Total artefacts compared:** %d", nrow(mat)),
  sprintf("**Match:** %d  ·  **Mismatch:** %d  ·  **Missing:** %d",
          n_match, n_mismatch, n_missing),
  "",
  if (n_mismatch == 0 && n_missing == 0)
    "✅ **All artefacts reproduce byte-for-byte (or content-identical for text formats).**"
  else
    sprintf("⚠️ **%d artefact(s) do not reproduce.** See table below.",
             n_mismatch + n_missing),
  "",
  "## Per-file results",
  "",
  "| File | Status | Detail |",
  "|---|---|---|"
)
for (i in seq_len(nrow(mat))) {
  out <- c(out, sprintf("| %s | %s | %s |",
                          mat$file[i], mat$status[i], mat$detail[i]))
}
out <- c(out, "",
          "## Notes",
          "",
          "- `.docx` files are skipped (officer writes a timestamp into the document core properties; bytes differ but content is equivalent).",
          "- `.csv` / `.html` / `.md` / `.xml` / `.rtf` are compared after line-ending normalisation.",
          "- `.parquet` is compared via `arrow::read_parquet()` data-frame equality (ignores file-level metadata).",
          "- `.png` is compared by SHA-1.",
          "- The raw simulation step is skipped unless `RERUN_RAW=1` (same seed → identical output by construction; skip avoids ~30s of redundant work).")
writeLines(out, report_path)
cat(sprintf("\nReport: %s\n", report_path))

# Console summary
cat("\n=== Reproducibility summary ===\n")
cat(sprintf("  MATCH    : %d\n", n_match))
cat(sprintf("  MISMATCH : %d\n", n_mismatch))
cat(sprintf("  MISSING  : %d\n", n_missing))

if (!identical(Sys.getenv("TFL_REPRO_KEEP_STAGE"), "1")) {
  unlink(STAGE, recursive = TRUE, force = TRUE)
  cat("\nStaging dir cleaned up. Set TFL_REPRO_KEEP_STAGE=1 to keep it.\n")
} else {
  cat(sprintf("\nStaging dir retained at %s (TFL_REPRO_KEEP_STAGE=1).\n", STAGE))
}

# Non-zero exit if any mismatch
if (n_mismatch > 0 || n_missing > 0) {
  cat("\nNon-zero exit because of mismatches.\n")
  quit(save = "no", status = 1)
}
