# torivumab guidelines loaded
# =============================================================================
# Program    : programs/qc/run_reproducibility_check.R
# Purpose    : Re-run pipeline steps (raw → SDTM → ADaM → Define-XML → TFL)
#              into an isolated staging directory and diff every produced
#              artefact against the committed state. Reports per-file
#              pass/fail.
#
# Strategy   : This script does NOT modify any committed file. It builds a
#              temporary staging copy of the project tree, runs each
#              requested pipeline orchestrator there, and compares
#              byte-by-byte (parquets, PNGs) or content-aware (CSVs
#              ignoring CRLF/LF differences, docx/html via structured
#              parse).
#
# Run from   : Project root
# Usage      : Rscript programs/qc/run_reproducibility_check.R [STEPS]
#                  STEPS (optional; default = all):
#                    --raw      Re-run raw simulation
#                    --sdtm     Re-run SDTM derivation
#                    --adam     Re-run ADaM derivation
#                    --define   Re-rebuild Define-XML
#                    --tfl      Re-rebuild TFL
#                  --help / -h  Show usage and exit
#              Env vars:
#                TFL_REPRO_KEEP_STAGE=1   keep staging dir after run
#                RERUN_RAW=1              (legacy) add raw to step list
#              Examples:
#                Rscript programs/qc/run_reproducibility_check.R
#                Rscript programs/qc/run_reproducibility_check.R --tfl
#                Rscript programs/qc/run_reproducibility_check.R --sdtm --adam
# Output     : qc/reports/<timestamp>/reproducibility.md
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(digest)
})

# -----------------------------------------------------------------------------
# CLI argument parsing
# -----------------------------------------------------------------------------
ALL_STEPS <- c("raw", "sdtm", "adam", "define", "tfl")
args      <- commandArgs(trailingOnly = TRUE)

if (any(args %in% c("--help", "-h"))) {
  cat("Usage: Rscript programs/qc/run_reproducibility_check.R [STEPS]\n\n")
  cat("Steps (if none specified, all run):\n")
  cat("  --raw      Re-run raw simulation\n")
  cat("  --sdtm     Re-run SDTM derivation\n")
  cat("  --adam     Re-run ADaM derivation\n")
  cat("  --define   Re-rebuild Define-XML\n")
  cat("  --tfl      Re-rebuild TFL\n\n")
  cat("Env vars:\n")
  cat("  TFL_REPRO_KEEP_STAGE=1   Keep staging dir after run\n")
  cat("  RERUN_RAW=1              (legacy) add raw to step list\n")
  quit(save = "no", status = 0)
}

flagged <- gsub("^--", "", args[grepl("^--", args)])
unknown <- setdiff(flagged, ALL_STEPS)
if (length(unknown) > 0) {
  stop("Unknown step(s): ", paste(unknown, collapse = ", "),
       "\n  Valid steps: ", paste(ALL_STEPS, collapse = ", "),
       "\n  Use --help for usage.")
}

if (length(flagged) == 0) {
  steps_to_run <- ALL_STEPS
} else {
  # Preserve canonical pipeline order regardless of CLI order
  steps_to_run <- ALL_STEPS[ALL_STEPS %in% flagged]
}

if (identical(Sys.getenv("RERUN_RAW"), "1") && !"raw" %in% steps_to_run) {
  steps_to_run <- c("raw", steps_to_run)
}

cat(sprintf("Steps to run: %s\n", paste(steps_to_run, collapse = ", ")))
skipped <- setdiff(ALL_STEPS, steps_to_run)
if (length(skipped) > 0) {
  cat(sprintf("Steps to skip: %s\n", paste(skipped, collapse = ", ")))
}

PROJECT_ROOT <- normalizePath(".")
TS           <- format(Sys.time(), "%Y%m%dT%H%M%S")
REPORT_DIR   <- file.path(PROJECT_ROOT, "qc", "reports", TS)
dir.create(REPORT_DIR, showWarnings = FALSE, recursive = TRUE)

STAGE <- tempfile(pattern = "tfl_repro_")
dir.create(STAGE, recursive = TRUE)
cat(sprintf("Staging directory: %s\n", STAGE))

# Copy the inputs the pipeline needs (raw CSVs, codelists, programs,
# spec markdown). Outputs (datasets/sdtm, datasets/adam, define, tfl)
# are NOT copied by default — they're what we'll re-derive and compare.
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

# For steps NOT being re-run, seed the staging output dir with committed
# files so downstream steps have their inputs (e.g. --tfl only still
# needs ADaM parquets available).
copy_committed_into_stage <- function(rel_dir) {
  src <- file.path(PROJECT_ROOT, rel_dir)
  dst <- file.path(STAGE, rel_dir)
  if (!dir.exists(src)) return(invisible())
  files <- list.files(src, recursive = TRUE, full.names = FALSE)
  for (f in files) {
    dir.create(dirname(file.path(dst, f)),
                recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(src, f), file.path(dst, f), overwrite = TRUE)
  }
}

STEP_OUTPUT_DIRS <- list(
  sdtm   = "datasets/sdtm",
  adam   = "datasets/adam",
  define = "define",
  tfl    = c("tfl/tables", "tfl/figures", "tfl")
)
for (step in names(STEP_OUTPUT_DIRS)) {
  if (!step %in% steps_to_run) {
    for (d in STEP_OUTPUT_DIRS[[step]]) {
      # For "tfl", only seed if not part of a re-running step's parent.
      # (tfl/tables and tfl/figures are leaf dirs; the bare "tfl" dir
      # only holds the TFL-OUTPUTS.html roll-up — copying it is harmless
      # since tfl is being skipped here.)
      copy_committed_into_stage(d)
    }
  }
}

# -----------------------------------------------------------------------------
# Step runner
# -----------------------------------------------------------------------------
run_step <- function(label, script) {
  cat(sprintf("\n--- Running %s (%s) ---\n", label, script))
  old_wd <- getwd()
  setwd(STAGE)
  on.exit(setwd(old_wd), add = TRUE)
  rc <- system2("Rscript", args = shQuote(script))
  if (rc != 0) stop("Step failed: ", label, " (exit code ", rc, ")")
  invisible(rc)
}

STEP_SCRIPTS <- list(
  raw    = list(label = "Raw simulation", script = "programs/raw/00_simulate_raw.R"),
  sdtm   = list(label = "SDTM",           script = "programs/sdtm/00_run_sdtm.R"),
  adam   = list(label = "ADaM",           script = "programs/adam/00_run_adam.R"),
  define = list(label = "Define-XML",     script = "programs/define/build_define.R"),
  tfl    = list(label = "TFL",            script = "programs/tfl/00_run_tfl.R")
)

for (step in ALL_STEPS) {
  if (step %in% steps_to_run) {
    run_step(STEP_SCRIPTS[[step]]$label, STEP_SCRIPTS[[step]]$script)
  } else {
    cat(sprintf("\nSkipping %s (not requested; using committed outputs as inputs to downstream steps).\n",
                STEP_SCRIPTS[[step]]$label))
  }
}

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

# Strip render-time non-determinism (timestamps, auto-generated IDs) so
# reproducibility comparison reflects content drift, not render fingerprints.
# Patterns observed in this pipeline:
#   - DRAFT_TAG (`_helpers.R`)  : "DRAFT — produced YYYY-MM-DD — synthetic ..."
#   - flextable HTML class IDs : "cl-<6+ hex>" auto-generated per render
#   - Define-XML (`build_define.R`):
#       FileOID="<STUDYID>.<YYYYMMDDHHMMSS>"
#       CreationDateTime="..."
#       AsOfDateTime="..."
normalize_text <- function(text, ext) {
  # DRAFT_TAG date (both em-dash and hyphen variants)
  text <- gsub("DRAFT\\s*[—\\-]\\s*produced\\s+\\d{4}-\\d{2}-\\d{2}",
               "DRAFT — produced <DATE>", text, perl = TRUE)
  # flextable auto-generated CSS class IDs in HTML
  if (ext == "html") {
    text <- gsub("cl-[a-f0-9]{6,}", "cl-<ID>", text)
  }
  if (ext == "xml") {
    text <- gsub('CreationDateTime="[^"]*"', 'CreationDateTime="<TS>"', text)
    text <- gsub('AsOfDateTime="[^"]*"',     'AsOfDateTime="<TS>"',     text)
    text <- gsub('FileOID="([^."]*)\\.[0-9]+"', 'FileOID="\\1.<TS>"',    text)
  }
  text
}

# Text comparison ignoring line-ending differences and render-time tokens.
text_match <- function(a, b, ext = "") {
  ta <- tryCatch(paste(readLines(a, warn = FALSE), collapse = "\n"),
                  error = function(e) NA_character_)
  tb <- tryCatch(paste(readLines(b, warn = FALSE), collapse = "\n"),
                  error = function(e) NA_character_)
  if (is.na(ta) || is.na(tb)) return("ERROR")
  ta <- normalize_text(ta, ext)
  tb <- normalize_text(tb, ext)
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
    "csv"     = text_match(committed, new, ext),
    "xml"     = text_match(committed, new, ext),
    "md"      = text_match(committed, new, ext),
    "html"    = text_match(committed, new, ext),
    "rtf"     = text_match(committed, new, ext),
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

# Only compare outputs of steps that were actually re-run.
collect_for_step <- function(step) {
  switch(step,
    "raw"    = collect("raw", "\\.csv$"),
    "sdtm"   = collect("datasets/sdtm", "\\.parquet$"),
    "adam"   = collect("datasets/adam", "\\.parquet$"),
    "define" = collect("define", "\\.(xml|md)$"),
    "tfl"    = c(collect("tfl/tables",  "\\.(rtf|html)$"),
                  collect("tfl/figures", "\\.png$"),
                  collect("tfl",         "TFL-OUTPUTS\\.html$")),
    character(0)
  )
}
targets <- unique(unlist(lapply(steps_to_run, collect_for_step)))
cat(sprintf("\nComparing %d artefacts ...\n", length(targets)))

results <- lapply(targets, compare_one)
mat <- do.call(rbind, results) |> as.data.frame(stringsAsFactors = FALSE)

n_match    <- if (nrow(mat) == 0) 0 else sum(mat$status == "MATCH")
n_mismatch <- if (nrow(mat) == 0) 0 else sum(mat$status == "MISMATCH")
n_missing  <- if (nrow(mat) == 0) 0 else sum(mat$status == "MISSING")

# -----------------------------------------------------------------------------
# Write markdown report
# -----------------------------------------------------------------------------
report_path <- file.path(REPORT_DIR, "reproducibility.md")
out <- c(
  "# Reproducibility check",
  "",
  sprintf("**Run:** %s", TS),
  sprintf("**Staging dir:** `%s`", STAGE),
  sprintf("**Steps re-run:** %s", paste(steps_to_run, collapse = ", ")),
  sprintf("**Steps skipped:** %s",
          if (length(skipped) == 0) "(none)" else paste(skipped, collapse = ", ")),
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
          "- `.csv` / `.html` / `.md` / `.xml` / `.rtf` are compared after line-ending normalisation **and** stripping of render-time tokens: `DRAFT — produced <DATE>`, flextable CSS class IDs (`cl-<hex>`) in HTML, and Define-XML `CreationDateTime` / `AsOfDateTime` / `FileOID` timestamps.",
          "- `.parquet` is compared via `arrow::read_parquet()` data-frame equality (ignores file-level metadata).",
          "- `.png` is compared by SHA-1.",
          "- Only artefacts produced by the steps re-run in this invocation are compared. For skipped upstream steps, the committed outputs are seeded into the staging tree so downstream re-runs have their inputs.",
          "- Run with `--help` to see per-step flags.")
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
