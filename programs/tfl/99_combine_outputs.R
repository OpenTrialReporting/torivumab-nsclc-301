# torivumab guidelines loaded
# =============================================================================
# 99_combine_outputs.R
# Builds tfl/TFL-OUTPUTS.html and tfl/TFL-OUTPUTS.docx — one document
# containing all five Phase 6a pilot outputs (3 tables + 2 figures) for
# stakeholder review.
# =============================================================================

PILOT_OUTPUTS <- list(
  list(id = "T-DM-01", title = "Demographic and Baseline Characteristics", kind = "table"),
  list(id = "T-EFF-01", title = "Overall Survival Analysis (Primary)",       kind = "table"),
  list(id = "T-EFF-03", title = "Progression-Free Survival Analysis (BICR)", kind = "table"),
  list(id = "F-EFF-01", title = "Kaplan-Meier Curve — Overall Survival",     kind = "figure"),
  list(id = "F-EFF-02", title = "Kaplan-Meier Curve — Progression-Free Survival", kind = "figure")
)

# ---- HTML combined ---------------------------------------------------------
html_pieces <- c(
  "<!doctype html>\n<html><head><meta charset='utf-8'>",
  "<title>TFL Outputs — SIMULATED-TORIVUMAB-2026 (Phase 6a pilot)</title>",
  "<style>",
  "body{font-family:Arial,sans-serif;margin:32px;color:#222;max-width:1100px;}",
  "h1{color:#1F3864;border-bottom:2px solid #1F3864;padding-bottom:6px;}",
  "h2{color:#1F3864;margin-top:36px;}",
  ".meta{color:#555;font-size:13px;margin-bottom:18px;}",
  ".output{margin:24px 0;padding:18px;border:1px solid #ccc;border-radius:6px;background:#fafbfd;}",
  ".output-id{font-weight:bold;color:#1F3864;}",
  ".output-title{font-size:16px;font-weight:bold;margin:4px 0 12px 0;}",
  "img{max-width:100%;height:auto;display:block;margin:12px auto;}",
  ".draft{color:#C0392B;font-style:italic;font-size:11px;}",
  ".formats{font-size:12px;color:#555;margin-top:8px;}",
  ".formats a{color:#2E75B6;text-decoration:none;margin-right:10px;}",
  "</style></head><body>\n",
  sprintf("<h1>TFL Outputs — %s</h1>\n", STUDY_NAME),
  sprintf("<div class='meta'><b>%s</b> &middot; %s &middot; Data cutoff: %s</div>\n",
          SPONSOR, PROTOCOL, DATA_CUTOFF),
  sprintf("<div class='meta'>Phase 6a pilot — %d outputs.</div>\n", length(PILOT_OUTPUTS)),
  sprintf("<div class='draft'>%s</div>\n", DRAFT_TAG)
)

for (o in PILOT_OUTPUTS) {
  html_pieces <- c(html_pieces, sprintf("<div class='output'>"))
  html_pieces <- c(html_pieces,
    sprintf("<div class='output-id'>%s</div>", o$id),
    sprintf("<div class='output-title'>%s</div>", o$title))

  if (o$kind == "table") {
    # Inline the table's existing standalone HTML body (strip <html>/<head>)
    f <- file.path(TFL_TABLES_DIR, paste0(o$id, ".html"))
    if (file.exists(f)) {
      body <- readLines(f, warn = FALSE) |> paste(collapse = "\n")
      body <- sub(".*<body[^>]*>", "", body)
      body <- sub("</body>.*", "", body)
      html_pieces <- c(html_pieces, body)
    }
    html_pieces <- c(html_pieces, sprintf(
      "<div class='formats'>Standalone files: <a href='tables/%s.rtf'>RTF</a> | <a href='tables/%s.docx'>DOCX</a> | <a href='tables/%s.html'>HTML</a></div>",
      o$id, o$id, o$id))
  } else if (o$kind == "figure") {
    html_pieces <- c(html_pieces, sprintf("<img src='figures/%s.png' alt='%s'>", o$id, o$id))
    html_pieces <- c(html_pieces, sprintf(
      "<div class='formats'>Standalone file: <a href='figures/%s.png'>PNG</a></div>", o$id))
  }

  html_pieces <- c(html_pieces, "</div>")
}
html_pieces <- c(html_pieces, "</body></html>\n")
writeLines(paste(html_pieces, collapse = "\n"), "tfl/TFL-OUTPUTS.html")
message("tfl/TFL-OUTPUTS.html written")

# ---- DOCX combined ---------------------------------------------------------
doc <- read_docx()
doc <- body_set_default_section(doc, prop_section(
  page_size    = page_size(width = 8.27, height = 11.69, orient = "portrait"),
  page_margins = page_mar(top = 0.75, bottom = 0.75, left = 0.8, right = 0.8)
))

# Cover page
doc <- body_add_fpar(doc, fpar(ftext(STUDY_NAME,
  prop = fp_text(font.family = F_SANS, font.size = 22, bold = TRUE, color = C_NAVY))))
doc <- body_add_fpar(doc, fpar(ftext("TFL Outputs — Phase 6a pilot",
  prop = fp_text(font.family = F_SANS, font.size = 16, color = C_NAVY))))
doc <- body_add_par(doc, " ")
doc <- body_add_fpar(doc, fpar(ftext(SPONSOR,
  prop = fp_text(font.family = F_SANS, font.size = 11, bold = TRUE))))
doc <- body_add_fpar(doc, fpar(ftext(PROTOCOL,
  prop = fp_text(font.family = F_SANS, font.size = 11, color = C_GREY))))
doc <- body_add_fpar(doc, fpar(ftext(sprintf("Data cutoff: %s", DATA_CUTOFF),
  prop = fp_text(font.family = F_SANS, font.size = 11, color = C_GREY))))
doc <- body_add_par(doc, " ")
doc <- body_add_fpar(doc, fpar(ftext(sprintf("Contents (%d outputs):", length(PILOT_OUTPUTS)),
  prop = fp_text(font.family = F_SANS, font.size = 11, bold = TRUE))))
for (o in PILOT_OUTPUTS) {
  doc <- body_add_fpar(doc, fpar(ftext(sprintf("  • %s — %s", o$id, o$title),
    prop = fp_text(font.family = F_SANS, font.size = 10))))
}
doc <- body_add_par(doc, " ")
doc <- body_add_fpar(doc, fpar(ftext(DRAFT_TAG,
  prop = fp_text(font.family = F_SANS, font.size = 9, italic = TRUE, color = "#C0392B"))))

# Each output on its own page (re-render rather than embed externally)
# Tables: rebuild flextable from data; figures: insert PNG
for (o in PILOT_OUTPUTS) {
  doc <- body_add_break(doc)
  doc <- body_add_fpar(doc, fpar(ftext(SPONSOR,
    prop = fp_text(font.family = F_SANS, font.size = 9, bold = TRUE, color = C_NAVY))))
  doc <- body_add_fpar(doc, fpar(ftext(PROTOCOL,
    prop = fp_text(font.family = F_SANS, font.size = 9, color = C_GREY))))
  doc <- body_add_fpar(doc, fpar(ftext(o$id,
    prop = fp_text(font.family = F_SANS, font.size = 11, bold = TRUE, color = C_NAVY))))
  doc <- body_add_fpar(doc, fpar(ftext(o$title,
    prop = fp_text(font.family = F_SANS, font.size = 14, bold = TRUE, color = C_NAVY))))
  doc <- body_add_par(doc, " ")

  if (o$kind == "table") {
    # Embed by extracting from the per-table DOCX is complex; simpler: just
    # write a hyperlink note and instruct the reader.  Since the table content
    # also exists in tfl/tables/<id>.docx, we cross-reference there.
    f_docx <- file.path(TFL_TABLES_DIR, paste0(o$id, ".docx"))
    doc <- body_add_fpar(doc, fpar(ftext(
      sprintf("→ See tfl/tables/%s.docx for the formatted table.", o$id),
      prop = fp_text(font.family = F_SANS, font.size = 10, italic = TRUE, color = C_NAVY))))
  } else if (o$kind == "figure") {
    img <- file.path(TFL_FIGURES_DIR, paste0(o$id, ".png"))
    if (file.exists(img)) doc <- body_add_img(doc, src = img, width = 6.5, height = 4.5)
  }

  doc <- body_add_par(doc, " ")
  doc <- body_add_fpar(doc, fpar(ftext(DRAFT_TAG,
    prop = fp_text(font.family = F_SANS, font.size = 7, italic = TRUE, color = "#C0392B"))))
}

print(doc, target = "tfl/TFL-OUTPUTS.docx")
message("tfl/TFL-OUTPUTS.docx written")
