# torivumab guidelines loaded
# =============================================================================
# Program    : programs/qc/check_env.R
# Purpose    : Gate the pipeline on a reproducible environment. Compares every
#              dependency declared in uvr.toml against the version pinned in
#              uvr.lock, and reports missing packages and genuine version drift.
#
# Run from   : Project root
# Usage      : Rscript programs/qc/check_env.R
# Exit codes : 0 = environment matches the lockfile
#              1 = one or more packages missing or drifted
#
# Notes      : uvr.lock carries two version fields per package. `raw_version` is
#              the true CRAN version; `version` is uvr's normalised form (e.g.
#              openxlsx raw 4.2.8.1 -> normalised "4.2.8-4.1"). Compare against
#              raw_version. Comparison uses package_version() rather than string
#              equality, because R normalises "3.8-9" to "3.8.9" — a string
#              compare reports false drift on every hyphenated CRAN version.
# =============================================================================

lock_path <- "uvr.lock"
toml_path <- "uvr.toml"
for (f in c(lock_path, toml_path)) if (!file.exists(f)) stop("Missing ", f, " — run from the project root.")

# ---- parse uvr.lock ---------------------------------------------------------
lock   <- readLines(lock_path, warn = FALSE)
starts <- grep("^\\[\\[package\\]\\]", lock)
field  <- function(blk, key) {
  m <- grep(paste0("^", key, "\\s*="), blk, value = TRUE)
  if (!length(m)) NA_character_ else sub('^[^"]*"([^"]*)".*$', "\\1", m[1])
}
locked <- list()
for (i in seq_along(starts)) {
  end <- if (i < length(starts)) starts[i + 1] - 1L else length(lock)
  blk <- lock[starts[i]:end]
  nm  <- field(blk, "name")
  if (!is.na(nm)) locked[[nm]] <- field(blk, "raw_version")
}

# ---- parse [dependencies] from uvr.toml --------------------------------------
toml <- readLines(toml_path, warn = FALSE)
s    <- grep("^\\[dependencies\\]", toml)
if (!length(s)) stop("No [dependencies] section in ", toml_path)
nxt  <- grep("^\\[", toml); nxt <- nxt[nxt > s]
e    <- if (length(nxt)) nxt[1] - 1L else length(toml)
declared <- trimws(sub("\\s*=.*$", "", grep("=", toml[(s + 1):e], value = TRUE)))

# ---- compare ----------------------------------------------------------------
same <- function(a, b) {
  ok <- tryCatch(package_version(a) == package_version(b), error = function(e) NA)
  isTRUE(ok)
}
missing <- character(0); drift <- character(0)
for (p in sort(declared)) {
  want <- locked[[p]]
  have <- tryCatch(as.character(packageVersion(p)), error = function(e) NA_character_)
  if (is.na(have))                      missing <- c(missing, p)
  else if (!is.na(want) && !same(want, have))
    drift <- c(drift, sprintf("%s: locked %s, installed %s", p, want, have))
}

cat(sprintf("Declared dependencies : %d\n", length(declared)))
cat(sprintf("Matching uvr.lock     : %d\n", length(declared) - length(missing) - length(drift)))
if (length(missing)) cat("\nMISSING (", length(missing), "):\n  ", paste(missing, collapse = ", "), "\n", sep = "")
if (length(drift))   cat("\nVERSION DRIFT (", length(drift), "):\n  ", paste(drift, collapse = "\n  "), "\n", sep = "")

# System tooling the pipeline shells out to.
sys_missing <- Filter(function(b) nchar(Sys.which(b)) == 0, c("zstd", "pandoc"))
if (length(sys_missing)) cat("\nSYSTEM TOOLS MISSING:\n  ", paste(sys_missing, collapse = ", "), "\n", sep = "")

ok <- !length(missing) && !length(drift) && !length(sys_missing)
cat("\n", if (ok) "ENVIRONMENT OK" else "ENVIRONMENT NOT REPRODUCIBLE", "\n", sep = "")
quit(status = if (ok) 0L else 1L)
