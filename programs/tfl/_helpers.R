# torivumab guidelines loaded
# =============================================================================
# programs/tfl/_helpers.R
# Shared utilities for Phase 6 TFL production.
#
# Conventions:
#   - All tables built as flextable objects (theme via tfl_theme_ft())
#   - flextable -> RTF via flextable::save_as_rtf
#   - flextable -> DOCX via flextable::save_as_docx
#   - flextable -> HTML via flextable::save_as_html  (or htmltools rendering)
#   - Figures saved as PNG via ggplot2::ggsave (300 dpi for publication)
#
# Each output script: source("_helpers.R"); build the table/figure; call
#   write_table_all_formats(ft, "T-DM-01", title=..., footnotes=...)
# or
#   write_figure(plot, "F-EFF-01", width=..., height=...)
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(flextable)
  library(officer)
  library(ggplot2)
  library(survival)
  library(scales)
})
set_flextable_defaults(fonts_ignore = TRUE)

# ---- Study constants (mirror SHELLS-DOC for consistency) -------------------
SPONSOR     <- "Celindra Therapeutics (fictional)"
PROTOCOL    <- "Protocol TORIVUMAB-NSCLC-301"
STUDY_NAME  <- "SIMULATED-TORIVUMAB-2026"
DATA_CUTOFF <- "2025-01-31"
DRAFT_TAG   <- sprintf("DRAFT — produced %s — synthetic data, NOT for regulatory submission",
                       format(Sys.Date(), "%Y-%m-%d"))

# Colours / fonts (match shells doc)
C_NAVY  <- "#1F3864"
C_BLUE  <- "#2E75B6"
C_GREY  <- "#888888"
C_LGREY <- "#F2F2F2"
C_MID   <- "#CCCCCC"
C_WHITE <- "#FFFFFF"
F_MONO  <- "Courier New"
F_SANS  <- "Arial"

# Output paths
TFL_TABLES_DIR  <- "tfl/tables"
TFL_FIGURES_DIR <- "tfl/figures"
dir.create(TFL_TABLES_DIR,  showWarnings = FALSE, recursive = TRUE)
dir.create(TFL_FIGURES_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- ADaM loaders ----------------------------------------------------------
load_adam <- function(name) {
  path <- file.path("datasets", "adam", paste0(name, ".parquet"))
  as.data.frame(read_parquet(path))
}

# ---- Number formatters -----------------------------------------------------
fmt_n_pct <- function(n, denom, digits = 1) {
  if (length(denom) == 1) denom <- rep(denom, length(n))
  p <- 100 * n / denom
  ifelse(is.na(n) | denom == 0, "—",
         sprintf("%d (%.*f)", as.integer(n), digits, p))
}
fmt_mean_sd <- function(m, s, digits = 1)
  sprintf("%.*f (%.*f)", digits, m, digits, s)
fmt_med_range <- function(med, mn, mx, digits = 1)
  sprintf("%.*f (%.*f, %.*f)", digits, med, digits, mn, digits, mx)
fmt_med_ci <- function(med, lo, hi, digits = 1, na_text = "NE")
  sprintf("%s (%s, %s)",
          ifelse(is.na(med), na_text, sprintf("%.*f", digits, med)),
          ifelse(is.na(lo),  na_text, sprintf("%.*f", digits, lo)),
          ifelse(is.na(hi),  na_text, sprintf("%.*f", digits, hi)))
fmt_hr_ci <- function(hr, lo, hi)
  sprintf("%.3f (%.3f, %.3f)", hr, lo, hi)
fmt_p <- function(p) {
  ifelse(is.na(p), "—",
    ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))
}

# ---- Common flextable styling ---------------------------------------------
tfl_theme_ft <- function(ft, col1_w = 3.0, value_w = NULL) {
  nc <- ncol(ft$body$dataset)
  if (is.null(value_w)) value_w <- (7.0 - col1_w) / max(nc - 1, 1)
  ft <- font(ft, fontname = F_SANS, part = "all")
  ft <- fontsize(ft, size = 9, part = "body")
  ft <- fontsize(ft, size = 9, part = "header")
  ft <- bold(ft, part = "header")
  ft <- bg(ft, bg = C_NAVY,  part = "header")
  ft <- color(ft, color = C_WHITE, part = "header")
  ft <- bg(ft, bg = C_WHITE, part = "body")
  ft <- border_outer(ft, border = fp_border(color = "#666666", width = 1), part = "all")
  ft <- border_inner_h(ft, border = fp_border(color = C_MID, width = 0.4), part = "body")
  ft <- border_inner_v(ft, border = fp_border(color = C_MID, width = 0.4), part = "all")
  ft <- align(ft, j = 1, align = "left", part = "all")
  if (nc > 1) ft <- align(ft, j = seq(2, nc), align = "center", part = "all")
  ft <- padding(ft, padding.left = 5, padding.right = 5,
                padding.top = 2, padding.bottom = 2, part = "all")
  ft <- width(ft, j = 1, width = col1_w)
  if (nc > 1) for (j in 2:nc) ft <- width(ft, j = j, width = value_w)
  ft
}

# Indent rows on column 1 (visual hierarchy for nested categories)
indent_ft <- function(ft, rows, levels = 1) {
  if (length(rows) == 0) return(ft)
  padding(ft, i = rows, j = 1, padding.left = 5 + 10 * levels, part = "body")
}
bold_section_ft <- function(ft, rows) {
  if (length(rows) == 0) return(ft)
  ft <- bold(ft, i = rows, part = "body")
  ft <- bg(ft, i = rows, bg = C_LGREY, part = "body")
  color(ft, i = rows, j = 1, color = C_NAVY, part = "body")
}

# ---- Title + footnote block (used by all writers) -------------------------
make_title_fpar <- function(output_id, title, population) {
  list(
    fpar(ftext(SPONSOR,  prop = fp_text(font.family = F_SANS, font.size = 9,
                                        bold = TRUE, color = C_NAVY))),
    fpar(ftext(sprintf("%s  |  Data cutoff: %s", PROTOCOL, DATA_CUTOFF),
               prop = fp_text(font.family = F_SANS, font.size = 9, color = C_GREY))),
    fpar(ftext(sprintf("%s", output_id),
               prop = fp_text(font.family = F_SANS, font.size = 10,
                              bold = TRUE, color = C_NAVY))),
    fpar(ftext(title, prop = fp_text(font.family = F_SANS, font.size = 12,
                                     bold = TRUE, color = C_NAVY))),
    fpar(ftext(population, prop = fp_text(font.family = F_SANS, font.size = 9,
                                          color = "#444444")))
  )
}
make_footnote_fpar <- function(notes = character(0)) {
  pieces <- list()
  for (n in notes) {
    pieces[[length(pieces) + 1]] <- fpar(
      ftext(n, prop = fp_text(font.family = F_SANS, font.size = 8))
    )
  }
  pieces[[length(pieces) + 1]] <- fpar(
    ftext(DRAFT_TAG, prop = fp_text(font.family = F_SANS, font.size = 7,
                                    italic = TRUE, color = "#C0392B"))
  )
  pieces
}

# ---- Multi-format writer for tables ----------------------------------------
# Writes <id>.rtf, <id>.docx, <id>.html into tfl/tables/.
# DOCX includes header + table + footnotes (full submission look).
# RTF is the bare table (most regulatory pipelines wrap headers separately).
# HTML uses flextable's htmlwidget renderer with the same theming.
write_table_all_formats <- function(ft, id, title, population, notes = character(0)) {
  base <- file.path(TFL_TABLES_DIR, id)

  # DOCX: full submission-style page
  doc <- read_docx()
  doc <- body_set_default_section(doc, prop_section(
    page_size    = page_size(width = 8.27, height = 11.69, orient = "portrait"),
    page_margins = page_mar(top = 0.75, bottom = 0.75, left = 0.8, right = 0.8)
  ))
  for (p in make_title_fpar(id, title, population)) doc <- body_add_fpar(doc, p)
  doc <- body_add_par(doc, " ")
  doc <- body_add_flextable(doc, ft, align = "left")
  doc <- body_add_par(doc, " ")
  for (p in make_footnote_fpar(notes)) doc <- body_add_fpar(doc, p)
  print(doc, target = paste0(base, ".docx"))

  # RTF: just the table (header info typically goes in regulatory wrapping)
  save_as_rtf(ft, path = paste0(base, ".rtf"))

  # HTML: flextable's html with a wrapping title/footnote block
  html_str <- paste0(
    "<!doctype html>\n<html><head><meta charset='utf-8'>",
    "<title>", id, " — ", title, "</title>",
    "<style>",
    "body{font-family:Arial,sans-serif;margin:24px;color:#222;}",
    ".tfl-title{font-weight:bold;color:#1F3864;}",
    ".tfl-sub{color:#555;font-size:12px;margin-bottom:8px;}",
    ".tfl-note{font-size:11px;color:#444;margin-top:6px;}",
    ".tfl-draft{font-size:10px;color:#C0392B;font-style:italic;margin-top:10px;}",
    "</style></head><body>\n",
    "<div class='tfl-sub'>", SPONSOR, " &middot; ", PROTOCOL,
    " &middot; Data cutoff: ", DATA_CUTOFF, "</div>",
    "<div class='tfl-title'>", id, " &mdash; ", title, "</div>",
    "<div class='tfl-sub'>", population, "</div>\n",
    htmltools_value(ft),
    paste0("<div class='tfl-note'>",
           paste(htmltools::htmlEscape(notes), collapse = "<br>"),
           "</div>"),
    "<div class='tfl-draft'>", DRAFT_TAG, "</div>",
    "</body></html>"
  )
  writeLines(html_str, paste0(base, ".html"))

  invisible(list(id = id, base = base))
}

# flextable's htmltools_value — wraps as_raster + as_html via the package
htmltools_value <- function(ft) {
  paste0(htmltools::HTML(format(ft, type = "html")))
}

# ---- Figure writer ---------------------------------------------------------
write_figure <- function(p, id, width = 7, height = 4.5, dpi = 300) {
  out <- file.path(TFL_FIGURES_DIR, paste0(id, ".png"))
  ggsave(out, plot = p, width = width, height = height, dpi = dpi, bg = "white")
  invisible(out)
}

# ---- Population labels (consistent across outputs) ------------------------
adsl_arm_counts <- function(adsl, flag_col = "ITTFL") {
  sub <- adsl[adsl[[flag_col]] == "Y", ]
  list(
    n_trt = sum(sub$TRT01P == "Torivumab + Chemotherapy"),
    n_pbo = sum(sub$TRT01P == "Placebo + Chemotherapy"),
    n_tot = nrow(sub)
  )
}

pop_label <- function(n, flag_col = "ITTFL") {
  pop <- switch(flag_col,
    ITTFL   = "ITT Population",
    SAFFL   = "Safety Population",
    PPROTFL = "Per-Protocol Population",
    flag_col)
  sprintf("%s (N=%d)", pop, n)
}

# Arm column headers
arm_label <- function(arm, n) paste0(arm, "\n(N=", n, ")")
