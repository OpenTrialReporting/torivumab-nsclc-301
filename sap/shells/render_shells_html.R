#!/usr/bin/env Rscript
# torivumab guidelines loaded
# =============================================================================
#  sap/shells/render_shells_html.R — Markdown → HTML for the TFL shell catalogue
# =============================================================================
#
#  Reads sap/shells/TFL-SHELLS.md and writes sap/shells/TFL-SHELLS.html.
#  Run AFTER render_shells.R, with:
#      Rscript sap/shells/render_shells_html.R
#
#  NEVER edit sap/shells/TFL-SHELLS.html by hand. Edit shells.yaml, re-run
#  render_shells.R, then re-run this script.
#
#  Reconstructed 2026-09-20: the committed TFL-SHELLS.html was pandoc-generated
#  but no script recorded how, so it drifted stale. Options below reproduce the
#  committed artefact: plain html_document, default bootstrap theme, no TOC,
#  self-contained.
# =============================================================================

suppressMessages(library(rmarkdown))

md_path   <- "sap/shells/TFL-SHELLS.md"
html_path <- "sap/shells/TFL-SHELLS.html"

if (!file.exists(md_path)) stop("Missing ", md_path, " — run render_shells.R first.")

render(
  input         = md_path,
  output_format = html_document(theme = "bootstrap", toc = FALSE,
                                self_contained = TRUE, highlight = "default"),
  output_file   = basename(html_path),
  quiet         = TRUE
)

cat(sprintf("Wrote %s (%.0f KB)\n", html_path, file.size(html_path) / 1024))
