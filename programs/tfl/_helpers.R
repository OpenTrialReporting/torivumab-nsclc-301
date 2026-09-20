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

# ---- Rounding --------------------------------------------------------------
# Half-up rounding, decided on the decimal value a number denotes rather than on
# the binary double's last bits (#27, signed 2026-09-20).
#
# Why this is not left to sprintf(): C's printf rounds the stored double, so a
# quantity that is mathematically an exact tie can round either way depending on
# how it was accumulated. T-VS-01 holds a real instance — temperature change at
# C1D1, placebo, mean exactly 0.05 on n = 58 — which sprintf renders "0.1" and
# base R's round() renders "0.0" (half-to-even). Neither is wrong; what is wrong
# is that the convention was never chosen, so the printed value depended on the
# C library.
#
# signif(, 12) absorbs accumulation noise well below any precision this study
# reports, so a value denoting 0.05 rounds as 0.05 whichever order it was summed
# in; ties then go away from zero, the convention used in clinical reporting.
# SAP §12 records the rule.
ROUND_SIGNIF_DIGITS <- 12L

round_half_up <- function(x, digits = 0) {
  scaled <- signif(x * 10^digits, ROUND_SIGNIF_DIGITS)
  out    <- ifelse(scaled < 0, -floor(-scaled + 0.5), floor(scaled + 0.5))
  out / 10^digits
}

# Format with the house rounding rule applied first, so sprintf only renders an
# already-rounded number and never makes a rounding decision of its own.
fmt_fixed <- function(x, digits = 1)
  formatC(round_half_up(x, digits), format = "f", digits = digits)

# ---- Stratified Mantel-Haenszel risk difference -----------------------------
# #27 D13 (signed 2026-09-20). SAP §13.6 specifies a stratified MH risk
# difference across histology x region. mantelhaen.test() cannot supply it — on a
# 2 x 2 x K table it returns a common ODDS RATIO — so the estimate is built here
# with Mantel-Haenszel weights and the Greenland & Robins (1985) variance, and
# mantelhaen.test() is retained only for the CMH p-value.
#
#   w_i  = n1_i * n0_i / N_i                      MH weight per stratum
#   RD   = sum(w_i * (p1_i - p0_i)) / sum(w_i)
#   Var  = sum( (x1_i(n1_i-x1_i)n0_i^3 + x0_i(n0_i-x0_i)n1_i^3)
#               / (n1_i * n0_i * N_i^2) ) / (sum w_i)^2
#
# Strata with no subjects in one arm carry no information about the difference
# and are dropped; the number retained is returned so it can be footnoted.
mh_risk_diff <- function(x1, n1, x0, n0, conf_level = 0.95) {
  keep <- n1 > 0 & n0 > 0
  x1 <- x1[keep]; n1 <- n1[keep]; x0 <- x0[keep]; n0 <- n0[keep]
  if (!length(n1)) return(list(rd = NA_real_, se = NA_real_, lo = NA_real_,
                               hi = NA_real_, k = 0L, k_dropped = sum(!keep)))
  N  <- n1 + n0
  w  <- n1 * n0 / N
  rd <- sum(w * (x1 / n1 - x0 / n0)) / sum(w)
  v  <- sum((x1 * (n1 - x1) * n0^3 + x0 * (n0 - x0) * n1^3) /
              (n1 * n0 * N^2)) / sum(w)^2
  se <- sqrt(v)
  z  <- stats::qnorm(1 - (1 - conf_level) / 2)
  list(rd = rd, se = se, lo = rd - z * se, hi = rd + z * se,
       k = length(n1), k_dropped = sum(!keep))
}

# ---- Number formatters -----------------------------------------------------
fmt_n_pct <- function(n, denom, digits = 1) {
  if (length(denom) == 1) denom <- rep(denom, length(n))
  p <- 100 * n / denom
  ifelse(is.na(n) | denom == 0, "—",
         paste0(as.integer(n), " (", fmt_fixed(p, digits), ")"))
}
fmt_mean_sd <- function(m, s, digits = 1)
  paste0(fmt_fixed(m, digits), " (", fmt_fixed(s, digits), ")")
fmt_med_range <- function(med, mn, mx, digits = 1)
  paste0(fmt_fixed(med, digits), " (", fmt_fixed(mn, digits), ", ",
         fmt_fixed(mx, digits), ")")
fmt_med_ci <- function(med, lo, hi, digits = 1, na_text = "NE")
  sprintf("%s (%s, %s)",
          ifelse(is.na(med), na_text, fmt_fixed(med, digits)),
          ifelse(is.na(lo),  na_text, fmt_fixed(lo,  digits)),
          ifelse(is.na(hi),  na_text, fmt_fixed(hi,  digits)))
fmt_hr_ci <- function(hr, lo, hi)
  paste0(fmt_fixed(hr, 3), " (", fmt_fixed(lo, 3), ", ", fmt_fixed(hi, 3), ")")
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

# ---- Survival-analysis helpers (shared across efficacy tables) ------------
# Greenwood-CI survival probability at given timepoints (months).
# Returns a data frame: tp_months, surv, lo, hi.
km_landmark_probs <- function(data, time_var = "AVAL_MO", event_var = "CNSR",
                              event_value = 0, timepoints) {
  tt  <- data[[time_var]]
  evt <- data[[event_var]] == event_value
  fit <- survfit(Surv(tt, evt) ~ 1, conf.type = "log-log")
  s   <- summary(fit, times = timepoints, extend = TRUE)
  data.frame(
    tp_months = s$time,
    surv      = s$surv,
    lo        = s$lower,
    hi        = s$upper
  )
}

# Stratified Cox HR for a TRT vs PBO comparison.
# data must have: AVAL_MO, CNSR, is_trt (logical or 0/1), HISTCAT, REGION.
# Coerces is_trt to integer internally so the model coefficient name is
# stable ("is_trt") regardless of input type.
stratified_cox <- function(data) {
  data$is_trt <- as.integer(data$is_trt)
  fit <- coxph(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
               data = data)
  s   <- summary(fit)$conf.int
  list(hr = s["is_trt","exp(coef)"],
       lo = s["is_trt","lower .95"],
       hi = s["is_trt","upper .95"])
}

# Stratified log-rank p
stratified_logrank <- function(data) {
  data$is_trt <- as.integer(data$is_trt)
  sd <- survdiff(Surv(AVAL_MO, CNSR == 0) ~ is_trt + strata(HISTCAT, REGION),
                 data = data)
  1 - pchisq(sd$chisq, df = 1)
}

# Region alias — REGION1 is now derived in ADSL (programs/adam/adsl.R, 2026-05-17).
# Kept as a thin wrapper so existing TFL code that references REGION continues to work.
# REGION is the randomisation stratum and is derived once, in ADSL. This used to
# carry a second copy of the mapping as a fallback, which disagreed with ADSL's
# and would have been used silently had REGION1 ever been absent. A single
# definition is the point: the duplicate is how the country-code defect in #42
# stayed invisible. Missing REGION1 is now an error, not something to recompute.
add_region <- function(adsl) {
  if (!"REGION1" %in% names(adsl))
    stop("ADSL has no REGION1 — region is a randomisation stratum and is derived ",
         "in programs/adam/adsl.R. Re-run the ADaM step rather than deriving it here.",
         call. = FALSE)
  adsl |> mutate(REGION = REGION1)
}

# ---- AE SOC × PT table builder (used by T-AE-02/03/04/05/06) --------------
# Builds a SOC-then-PT incidence table from a pre-filtered ADAE.
# adae_sub: ADAE filtered to the event subset of interest (e.g. SAEs).
# n_trt / n_pbo: denominator subject counts per arm.
# min_pct: threshold for including a PT (≥ this % in either arm).
build_ae_soc_pt_ft <- function(adae_sub, n_trt, n_pbo, min_pct = 0,
                                soc_var = "AEBODSYS", pt_var = "AEDECOD",
                                col1_w = 4.0) {
  inc <- adae_sub |>
    filter(!is.na(.data[[soc_var]]), !is.na(.data[[pt_var]])) |>
    group_by(.data[[soc_var]], .data[[pt_var]], TRT01A) |>
    summarise(n = n_distinct(USUBJID), .groups = "drop") |>
    tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)
  # Rename arm columns BY NAME, never by position: group_by() sorts its keys, so
  # pivot_wider() emits the arms alphabetically (Placebo before Torivumab). A
  # positional rename here silently swapped the two arms in T-AE-03/04/05.
  names(inc)[1:2] <- c("SOC", "PT")
  inc <- inc |>
    rename(TRT = `Torivumab + Chemotherapy`,
           PBO = `Placebo + Chemotherapy`) |>
    mutate(pct_trt = 100 * TRT / n_trt,
            pct_pbo = 100 * PBO / n_pbo,
            max_pct = pmax(pct_trt, pct_pbo)) |>
    filter(max_pct >= min_pct) |>
    arrange(SOC, desc(max_pct))

  soc_inc <- adae_sub |>
    group_by(.data[[soc_var]], TRT01A) |>
    summarise(n = n_distinct(USUBJID), .groups = "drop") |>
    tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)
  names(soc_inc)[1] <- "SOC"
  soc_inc <- soc_inc |>
    rename(TRT = `Torivumab + Chemotherapy`,
           PBO = `Placebo + Chemotherapy`)

  rows <- list(); section_rows <- integer(0); indent_rows <- integer(0)
  rid <- 0L
  add <- function(label, t, p, sec = FALSE) {
    rid <<- rid + 1L
    rows[[rid]] <<- data.frame(
      Label = label,
      TRT   = fmt_n_pct(t, n_trt),
      PBO   = fmt_n_pct(p, n_pbo),
      stringsAsFactors = FALSE, check.names = FALSE)
    if (sec) section_rows <<- c(section_rows, rid)
    else     indent_rows  <<- c(indent_rows,  rid)
  }

  for (soc in sort(unique(inc$SOC))) {
    soc_t <- soc_inc$TRT[soc_inc$SOC == soc]
    soc_p <- soc_inc$PBO[soc_inc$SOC == soc]
    add(soc, soc_t, soc_p, sec = TRUE)
    pts <- inc |> filter(SOC == soc)
    for (i in seq_len(nrow(pts))) {
      add(paste0("  ", pts$PT[i]), pts$TRT[i], pts$PBO[i])
    }
  }
  if (length(rows) == 0) {
    rows[[1]] <- data.frame(Label = "(no events meeting criteria)",
                             TRT = "0 (0.0)", PBO = "0 (0.0)",
                             stringsAsFactors = FALSE, check.names = FALSE)
  }
  tbl <- do.call(rbind, rows)
  names(tbl) <- c(" ",
                  arm_label("Torivumab + Chemotherapy", n_trt),
                  arm_label("Placebo + Chemotherapy",   n_pbo))
  ft <- flextable(tbl) |> tfl_theme_ft(col1_w = col1_w)
  if (length(section_rows) > 0) ft <- bold_section_ft(ft, section_rows)
  if (length(indent_rows)  > 0) ft <- indent_ft(ft, indent_rows, levels = 1)
  list(ft = ft, n_pts = length(indent_rows), n_socs = length(section_rows))
}

# ---- Listing writer (wide single-format DOCX + HTML) ----------------------
# Listings are typically wide; RTF too. We produce DOCX + HTML + RTF.
write_listing_all_formats <- function(df, id, title, population,
                                       notes = character(0), col_widths = NULL) {
  base <- file.path(TFL_TABLES_DIR, id)  # listings live in same dir as tables

  ft <- flextable(df)
  ft <- font(ft, fontname = F_SANS, part = "all")
  ft <- fontsize(ft, size = 8, part = "body")
  ft <- fontsize(ft, size = 8, part = "header")
  ft <- bold(ft, part = "header")
  ft <- bg(ft, bg = C_NAVY,  part = "header")
  ft <- color(ft, color = C_WHITE, part = "header")
  ft <- bg(ft, bg = C_WHITE, part = "body")
  ft <- border_outer(ft, border = fp_border(color = "#666666", width = 1), part = "all")
  ft <- border_inner_h(ft, border = fp_border(color = C_MID, width = 0.4), part = "body")
  ft <- border_inner_v(ft, border = fp_border(color = C_MID, width = 0.4), part = "all")
  ft <- align(ft, align = "left", part = "all")
  ft <- padding(ft, padding.left = 4, padding.right = 4,
                padding.top = 1.5, padding.bottom = 1.5, part = "all")
  if (!is.null(col_widths)) {
    for (j in seq_along(col_widths)) ft <- width(ft, j = j, width = col_widths[j])
  } else {
    ft <- set_table_properties(ft, layout = "autofit", width = 1)
  }

  # DOCX — landscape page since listings are wide
  doc <- read_docx()
  doc <- body_set_default_section(doc, prop_section(
    page_size    = page_size(width = 11.69, height = 8.27, orient = "landscape"),
    page_margins = page_mar(top = 0.6, bottom = 0.6, left = 0.7, right = 0.7)
  ))
  for (p in make_title_fpar(id, title, population)) doc <- body_add_fpar(doc, p)
  doc <- body_add_par(doc, " ")
  doc <- body_add_flextable(doc, ft, align = "left")
  doc <- body_add_par(doc, " ")
  for (p in make_footnote_fpar(notes)) doc <- body_add_fpar(doc, p)
  print(doc, target = paste0(base, ".docx"))

  save_as_rtf(ft, path = paste0(base, ".rtf"))

  # HTML: render as plain <table> for listings (flextable HTML bloats with
  # large row counts due to inline per-cell styles + base64 SVG fonts).
  # Plain HTML keeps L-LB-01 ≈ 1 MB instead of 99 MB.
  esc <- function(x) htmltools::htmlEscape(as.character(x), attribute = FALSE)
  th_row <- paste0("<th>", esc(names(df)), "</th>", collapse = "")
  td_rows <- vapply(seq_len(nrow(df)), function(i) {
    paste0("<tr>",
           paste0("<td>", esc(unlist(df[i, ])), "</td>", collapse = ""),
           "</tr>")
  }, character(1))
  html_str <- paste0(
    "<!doctype html>\n<html><head><meta charset='utf-8'>",
    "<title>", id, " — ", title, "</title>",
    "<style>",
    "body{font-family:Arial,sans-serif;margin:24px;color:#222;}",
    ".tfl-title{font-weight:bold;color:#1F3864;font-size:16px;}",
    ".tfl-sub{color:#555;font-size:12px;margin-bottom:8px;}",
    ".tfl-note{font-size:11px;color:#444;margin-top:8px;}",
    ".tfl-draft{font-size:10px;color:#C0392B;font-style:italic;margin-top:10px;}",
    "table{border-collapse:collapse;font-size:10px;width:100%;margin-top:8px;}",
    "th{background:#1F3864;color:#fff;padding:4px 6px;text-align:left;}",
    "td{padding:3px 6px;border-bottom:1px solid #ddd;}",
    "tr:nth-child(even) td{background:#f7f9fc;}",
    "</style></head><body>\n",
    "<div class='tfl-sub'>", SPONSOR, " &middot; ", PROTOCOL,
    " &middot; Data cutoff: ", DATA_CUTOFF, "</div>",
    "<div class='tfl-title'>", id, " &mdash; ", title, "</div>",
    "<div class='tfl-sub'>", population, "</div>\n",
    "<table><thead><tr>", th_row, "</tr></thead><tbody>",
    paste(td_rows, collapse = ""),
    "</tbody></table>",
    paste0("<div class='tfl-note'>",
           paste(htmltools::htmlEscape(notes), collapse = "<br>"),
           "</div>"),
    "<div class='tfl-draft'>", DRAFT_TAG, "</div>",
    "</body></html>"
  )
  writeLines(html_str, paste0(base, ".html"))

  invisible(list(id = id, base = base, n = nrow(df)))
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
    as.character(flextable::htmltools_value(ft)),
    paste0("<div class='tfl-note'>",
           paste(htmltools::htmlEscape(notes), collapse = "<br>"),
           "</div>"),
    "<div class='tfl-draft'>", DRAFT_TAG, "</div>",
    "</body></html>"
  )
  writeLines(html_str, paste0(base, ".html"))

  invisible(list(id = id, base = base))
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
