#!/usr/bin/env Rscript
# =============================================================================
#  tfl/validate_shells.R — schema + ADaM coverage checks for shells.yaml
# =============================================================================
#
#  Run with:
#      Rscript tfl/validate_shells.R
#
#  Exits non-zero on any failure, so this is CI-friendly.
# =============================================================================

suppressMessages({
  library(yaml)
  library(stringr)
})

yaml_path <- "tfl/shells.yaml"
spec_glob <- "programming-specs/AD*-spec.md"

if (!file.exists(yaml_path)) stop("Missing ", yaml_path)
shells <- read_yaml(yaml_path)

errors   <- character()
warnings <- character()
err   <- function(msg) errors <<- c(errors, msg)
warn  <- function(msg) warnings <<- c(warnings, msg)

## -----------------------------------------------------------------------------
## 1. Schema checks on outputs
## -----------------------------------------------------------------------------

req_fields <- c("id", "kind", "title", "analysis_set", "source_datasets",
                "key_variables", "sap_ref")

for (i in seq_along(shells$outputs)) {
  o <- shells$outputs[[i]]
  id <- o$id %||% sprintf("<output #%d>", i)

  for (f in req_fields) {
    if (is.null(o[[f]])) err(sprintf("Output %s missing required field '%s'", id, f))
  }

  if (!is.null(o$kind) && !(o$kind %in% c("table", "figure", "listing"))) {
    err(sprintf("Output %s has invalid kind '%s' (must be table/figure/listing)", id, o$kind))
  }

  ## ID convention
  if (!is.null(o$id) && !str_detect(o$id, "^[TFL]-[A-Z]+-\\d{2}$")) {
    warn(sprintf("Output %s ID does not match convention {T|F|L}-{AREA}-NN", id))
  }

  ## ID prefix matches kind
  if (!is.null(o$id) && !is.null(o$kind)) {
    prefix <- substr(o$id, 1, 1)
    kind_prefix <- c(table = "T", figure = "F", listing = "L")[o$kind]
    if (prefix != kind_prefix) {
      err(sprintf("Output %s: ID prefix '%s' does not match kind '%s' (expected '%s')",
                  id, prefix, o$kind, kind_prefix))
    }
  }
}

## Unique IDs
ids <- vapply(shells$outputs, function(x) x$id %||% NA_character_, character(1))
dup <- unique(ids[duplicated(ids)])
if (length(dup)) err(sprintf("Duplicate output IDs: %s", paste(dup, collapse = ", ")))

## -----------------------------------------------------------------------------
## 2. Referential integrity: analysis_set / methods / reference_documents
## -----------------------------------------------------------------------------

as_ids      <- vapply(shells$analysis_sets, `[[`, character(1), "id")
method_ids  <- vapply(shells$methods, `[[`, character(1), "id")
refdoc_ids  <- vapply(shells$reference_documents, `[[`, character(1), "id")

for (o in shells$outputs) {
  id <- o$id

  if (!is.null(o$analysis_set) && !(o$analysis_set %in% as_ids)) {
    err(sprintf("Output %s references unknown analysis_set '%s'", id, o$analysis_set))
  }
  for (m in o$methods %||% character()) {
    if (!(m %in% method_ids)) err(sprintf("Output %s references unknown method '%s'", id, m))
  }
  for (r in o$reference_documents %||% character()) {
    if (!(r %in% refdoc_ids)) err(sprintf("Output %s references unknown reference_document '%s'", id, r))
  }
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## Duplicate analysis_set / method / refdoc IDs
for (label in c("analysis_sets", "methods", "reference_documents")) {
  ids_i <- vapply(shells[[label]], function(x) x$id %||% NA_character_, character(1))
  dup_i <- unique(ids_i[duplicated(ids_i)])
  if (length(dup_i)) err(sprintf("Duplicate %s IDs: %s", label, paste(dup_i, collapse = ", ")))
}

## -----------------------------------------------------------------------------
## 3. Reference document paths exist on disk
## -----------------------------------------------------------------------------

for (r in shells$reference_documents) {
  if (!file.exists(r$path)) {
    warn(sprintf("Reference document %s path does not exist: %s", r$id, r$path))
  }
}

## -----------------------------------------------------------------------------
## 4. ADaM coverage: every spec variable must be cited by ≥1 shell
## -----------------------------------------------------------------------------
##
## Parse variable names from the Variables tables in programming-specs/AD*-spec.md.
## Heuristic: lines matching   | N | NAME | ...   where NAME is UPPERCASE letters/digits.

spec_files <- Sys.glob(spec_glob)
spec_vars  <- character()
spec_vars_by_file <- list()

for (sf in spec_files) {
  lines <- readLines(sf, warn = FALSE)
  ## Match lines like "| 12 | TRTSDT | Date of First Exposure ..."
  m <- str_match(lines, "^\\|\\s*\\d+\\s*\\|\\s*([A-Z][A-Z0-9_]*)\\s*\\|")
  vars <- m[, 2]
  vars <- vars[!is.na(vars)]
  spec_vars_by_file[[basename(sf)]] <- vars
  spec_vars <- c(spec_vars, vars)
}
spec_vars <- unique(spec_vars)

shell_vars <- unique(unlist(lapply(shells$outputs, `[[`, "key_variables")))

missing_in_shells <- setdiff(spec_vars, shell_vars)
missing_in_specs  <- setdiff(shell_vars, spec_vars)

## Certain shell variables are expected to live outside ADaM specs
##   USUBJID, AVAL, CNSR, AVALC, PARAMCD etc. are ADaM standards
##   SDTM-sourced vars (DSSTDTC, AEBODSYS, AEDECOD, etc.) appear in shells pointing at SDTM
##   Coverage is informational, not hard-fail, until all 6 specs are written.
## So we warn on missing_in_specs (shell var has no spec yet) rather than err.

if (length(missing_in_shells)) {
  warn(sprintf(
    "ADaM spec variables not cited by any shell (candidates for removal from spec OR addition to a shell):\n  %s",
    paste(missing_in_shells, collapse = ", ")
  ))
}

if (length(missing_in_specs)) {
  warn(sprintf(
    "Shell variables not yet defined in any AD*-spec.md (expected while Phase 5 specs are still being drafted):\n  %s",
    paste(missing_in_specs, collapse = ", ")
  ))
}

## -----------------------------------------------------------------------------
## 5. Report
## -----------------------------------------------------------------------------

cat("=============================================================\n")
cat("  TFL Shells Validation Report\n")
cat("=============================================================\n\n")

cat(sprintf("Analysis sets:        %d\n", length(shells$analysis_sets)))
cat(sprintf("Methods:              %d\n", length(shells$methods)))
cat(sprintf("Reference documents:  %d\n", length(shells$reference_documents)))
cat(sprintf("Outputs:              %d (", length(shells$outputs)))
for (k in c("table", "figure", "listing")) {
  n <- sum(vapply(shells$outputs, function(x) x$kind == k, logical(1)))
  cat(sprintf("%d %ss  ", n, k))
}
cat(")\n")
cat(sprintf("Distinct shell vars:  %d\n", length(shell_vars)))
cat(sprintf("Distinct spec vars:   %d (from %d spec file%s)\n",
            length(spec_vars), length(spec_files),
            ifelse(length(spec_files) == 1, "", "s")))

if (length(spec_files)) {
  cat("\nSpec files parsed:\n")
  for (sf in names(spec_vars_by_file)) {
    cat(sprintf("  %-30s %d vars\n", sf, length(spec_vars_by_file[[sf]])))
  }
}

cat("\n-------------------------------------------------------------\n")
if (length(warnings)) {
  cat(sprintf("WARNINGS (%d):\n", length(warnings)))
  for (w in warnings) cat("  [WARN] ", w, "\n", sep = "")
} else {
  cat("WARNINGS: none\n")
}

cat("\n-------------------------------------------------------------\n")
if (length(errors)) {
  cat(sprintf("ERRORS (%d):\n", length(errors)))
  for (e in errors) cat("  [FAIL] ", e, "\n", sep = "")
  cat("\nValidation FAILED.\n")
  quit(status = 1)
} else {
  cat("ERRORS: none\n")
  cat("\nValidation PASSED.\n")
}
