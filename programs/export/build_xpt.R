# =============================================================================
# Program    : build_xpt.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Export every SDTM + ADaM parquet dataset to SAS Transport v5
#              (.xpt) for Pinnacle 21 validation.
#
#              Variable labels are taken from the parquet R-metadata (attached
#              by 16_label_domains.R / label_adam.R) and truncated to the XPT v5
#              40-character limit. Dataset labels are read from define.xml
#              (ItemGroupDef Description). Written with haven::write_xpt(version=5).
#
# Reads from : datasets/sdtm/*.parquet, datasets/adam/*.parquet, define/define.xml
# Writes to  : xpt/sdtm/*.xpt, xpt/adam/*.xpt
# Run from   : project root  ->  Rscript programs/export/build_xpt.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(haven)
  library(labelled)
  library(xml2)
})

DEFINE  <- "define/define.xml"
OUT_DIR <- "xpt"

# -----------------------------------------------------------------------------
# Dataset labels from define.xml (SASDatasetName -> ItemGroupDef Description)
# -----------------------------------------------------------------------------
ds_labels <- local({
  doc  <- read_xml(DEFINE)
  igds <- xml_find_all(doc, "//*[local-name()='ItemGroupDef']")
  nm   <- vapply(igds, function(n) xml_attr(n, "SASDatasetName"), character(1))
  lb   <- vapply(igds, function(n) {
    t <- xml_find_first(n, ".//*[local-name()='TranslatedText']")
    if (length(t)) xml_text(t) else NA_character_
  }, character(1))
  setNames(lb, toupper(nm))
})

# -----------------------------------------------------------------------------
# Export one directory of parquet -> xpt
# -----------------------------------------------------------------------------
export_dir <- function(src, sub) {
  files  <- sort(list.files(src, pattern = "[.]parquet$", full.names = TRUE))
  outdir <- file.path(OUT_DIR, sub)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  cat(sprintf("\n== %s -> %s ==\n", src, outdir))

  for (f in files) {
    ds <- toupper(sub("[.]parquet$", "", basename(f)))
    df <- as.data.frame(read_parquet(f))

    # Variable labels: keep from parquet, truncate to XPT v5 max (40 chars)
    labs <- var_label(df)
    for (v in names(df)) {
      lb <- labs[[v]]
      if (!is.null(lb) && !is.na(lb) && nchar(lb) > 40) {
        attr(df[[v]], "label") <- substr(lb, 1, 40)
      }
    }

    # Dataset label from define.xml (<= 40 chars)
    dl <- ds_labels[[ds]]
    if (!is.null(dl) && !is.na(dl)) attr(df, "label") <- substr(dl, 1, 40)

    out <- file.path(outdir, paste0(tolower(ds), ".xpt"))
    write_xpt(df, out, version = 5, name = ds)

    cat(sprintf("  %-8s %3d vars %8d obs  label=\"%s\"\n",
                tolower(ds), ncol(df), nrow(df),
                if (is.null(attr(df, "label"))) "" else attr(df, "label")))
  }
}

export_dir("datasets/sdtm", "sdtm")
export_dir("datasets/adam", "adam")

cat(sprintf("\nDone. XPT written under %s/  (point Pinnacle 21 at xpt/sdtm and xpt/adam;\n",
            OUT_DIR))
cat("metadata: define/define.xml)\n")
