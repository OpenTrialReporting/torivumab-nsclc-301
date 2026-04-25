#!/usr/bin/env Rscript
# =============================================================================
#  tfl/render_shells_doc.R  —  shells.yaml → visual TFL shell document
# =============================================================================
#
#  Reads  tfl/shells.yaml
#  Writes tfl/TFL-SHELLS-DOC.docx  (and optionally tfl/TFL-SHELLS-DOC.pdf)
#
#  Each output (table / figure / listing) gets its own page showing the
#  approximate final layout with placeholder values (xx.x, xxx, etc.)
#  This is the Gate 3.5 deliverable for stakeholder review and sign-off.
#
#  Usage (run from repo root):
#      Rscript tfl/render_shells_doc.R           # Word only
#      Rscript tfl/render_shells_doc.R --pdf     # Word + PDF via LibreOffice
#
#  Packages: yaml, officer, flextable, ggplot2, patchwork, survival
#  Install:  install.packages(c("yaml", "officer", "flextable", "ggplot2", "patchwork", "survival"))
# =============================================================================

args     <- commandArgs(trailingOnly = TRUE)
make_pdf <- "--pdf" %in% args

suppressMessages({
  for (pkg in c("yaml", "officer", "flextable", "ggplot2", "patchwork", "survival")) {
    if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
})
set_flextable_defaults(fonts_ignore = TRUE)

# ---- Paths ----------------------------------------------------------------
yaml_path <- "tfl/shells.yaml"
docx_path <- "tfl/TFL-SHELLS-DOC.docx"
pdf_path  <- "tfl/TFL-SHELLS-DOC.pdf"

if (!file.exists(yaml_path)) stop("Missing: ", yaml_path, " — run from repo root.")
shells <- read_yaml(yaml_path)
meta   <- shells$meta
cat("Loaded shells.yaml:", length(shells$outputs), "outputs\n")

# ---- Constants ------------------------------------------------------------
# Colors must be "#RRGGBB" for flextable >= 0.7 and officer compatibility
C_NAVY   <- "#1F3864"
C_BLUE   <- "#2E75B6"
C_RED    <- "#C0392B"
C_GREY   <- "#888888"
C_LGREY  <- "#F2F2F2"
C_MID    <- "#CCCCCC"
C_WHITE  <- "#FFFFFF"
F_MONO   <- "Courier New"
F_SANS   <- "Arial"
PH       <- "xx.x"         # continuous placeholder
PHN      <- "xxx"          # count placeholder
PHPCT    <- "xx.x%"        # percent placeholder
PHNPCT   <- "xxx (xx.x%)"  # count + pct placeholder
PHCI     <- "(xx.x, xx.x)" # CI placeholder
PHHR     <- "x.xxx"        # HR / p-value placeholder

# ---- Utility ---------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a

find_as <- function(id) {
  for (a in shells$analysis_sets) if (a$id == id) return(a)
  list(label = id, expected_n = "xxx", treatment_var = "TRT01P")
}

as_pop_line <- function(id) {
  ai <- find_as(id)
  n  <- ai$expected_n %||% "xxx"
  paste0(ai$label, " Population (N=", n, ")")
}

method_names_str <- function(mids) {
  nms <- vapply(mids, function(mid) {
    for (m in shells$methods) if (m$id == mid) return(m$name)
    mid
  }, character(1))
  paste(nms, collapse = "; ")
}

resolve_rows <- function(rows_str) {
  if (is.null(rows_str)) return(NULL)
  m <- regmatches(rows_str, regexpr("T-[A-Z]+-\\d+", rows_str))
  if (length(m) == 1 && grepl("[Ss]ame as", rows_str)) {
    ref <- Filter(function(x) x$id == m, shells$outputs)
    if (length(ref)) return(ref[[1]]$layout$rows)
  }
  rows_str
}

# Arm column labels
arm1 <- function(n = 300) paste0("Torivumab 200mg\n(N=", n, ")")
arm2 <- function(n = 150) paste0("Placebo\n(N=", n, ")")
tot  <- function(n = 450) paste0("Total\n(N=", n, ")")

# ---- Flextable builder -----------------------------------------------------
# df must have a character Label column (col 1) + value columns
# indent_rows: integer vector of row indices to indent in col 1
# header_rows: integer vector of row indices to bold/shade as section headers
make_ft <- function(df, indent_rows = integer(0), header_rows = integer(0),
                    col1_w = 3.0, value_w = NULL) {
  nc <- ncol(df)
  if (is.null(value_w)) value_w <- (7.0 - col1_w) / max(nc - 1, 1)

  ft <- flextable(df)
  ft <- font(ft, fontname = F_MONO, part = "all")
  ft <- fontsize(ft, size = 8, part = "body")
  ft <- fontsize(ft, size = 8, part = "header")
  ft <- bold(ft, part = "header")
  ft <- bg(ft, bg = C_NAVY, part = "header")
  ft <- color(ft, color = C_WHITE, part = "header")
  ft <- bg(ft, bg = C_WHITE, part = "body")
  ft <- border_outer(ft, border = fp_border(color = "#999999", width = 1), part = "all")
  ft <- border_inner_h(ft, border = fp_border(color = C_MID, width = 0.5), part = "body")
  ft <- border_inner_v(ft, border = fp_border(color = C_MID, width = 0.5), part = "all")
  ft <- align(ft, j = 1, align = "left", part = "all")
  if (nc > 1) ft <- align(ft, j = seq(2, nc), align = "center", part = "all")
  ft <- padding(ft, padding.left = 5, padding.right = 5,
                padding.top = 2, padding.bottom = 2, part = "all")
  ft <- width(ft, j = 1, width = col1_w)
  if (nc > 1) for (j in 2:nc) ft <- width(ft, j = j, width = value_w)
  if (length(indent_rows)) ft <- padding(ft, i = indent_rows, j = 1,
                                         padding.left = 16, part = "body")
  if (length(header_rows)) {
    ft <- bg(ft, i = header_rows, bg = C_LGREY, part = "body")
    ft <- bold(ft, i = header_rows, part = "body")
    ft <- color(ft, i = header_rows, j = 1, color = C_NAVY, part = "body")
  }
  ft
}

# ---- Mock data builders by output type ------------------------------------

## Helper: df from label/arm1/arm2 vectors
two_arm_df <- function(labels, v1, v2, a1_n = 300, a2_n = 150) {
  df <- data.frame(Label = labels, A1 = v1, A2 = v2,
                   stringsAsFactors = FALSE, check.names = FALSE)
  names(df) <- c(" ", arm1(a1_n), arm2(a2_n))
  df
}

three_arm_df <- function(labels, v1, v2, vt, a1_n = 300, a2_n = 150, t_n = 450) {
  df <- data.frame(Label = labels, A1 = v1, A2 = v2, Tot = vt,
                   stringsAsFactors = FALSE, check.names = FALSE)
  names(df) <- c(" ", arm1(a1_n), arm2(a2_n), tot(t_n))
  df
}

# T-DM-01 — Demographics
dm_mock <- function() {
  lbl <- c(
    "Age (years)", "  n", "  Mean (SD)", "  Median (Min, Max)",
    "  < 65, n (%)", "  ≥ 65, n (%)",
    "Sex", "  Female, n (%)", "  Male, n (%)",
    "Race", "  Asian, n (%)", "  Black or African American, n (%)",
    "  White, n (%)", "  Other / Not reported, n (%)",
    "Region", "  North America, n (%)", "  Europe, n (%)", "  Asia-Pacific, n (%)",
    "Histology", "  Squamous, n (%)", "  Non-squamous, n (%)",
    "ECOG PS at baseline", "  0, n (%)", "  1, n (%)",
    "PD-L1 TPS group", "  50–74%, n (%)", "  ≥ 75%, n (%)",
    "Number of prior lines",
    "  0 (first-line), n (%)"
  )
  v1 <- c(PHN, PHN, paste(PH, paste0("(", PH, ")")), paste0(PH, " (", PH, ", ", PH, ")"),
          PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT, PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT,
          "", PHNPCT, PHNPCT,
          "", PHNPCT)
  v2 <- v1
  vt <- v1
  hdr <- c(1, 7, 10, 15, 19, 22, 25, 28)
  ind <- c(2:6, 8:9, 11:14, 16:18, 20:21, 23:24, 26:27, 29)
  list(df = three_arm_df(lbl, v1, v2, vt), header_rows = hdr, indent_rows = ind)
}

# T-DS-01 — Disposition
ds_mock <- function() {
  lbl <- c("Screened", "  Screen failures", "Randomised / ITT (N=450)",
           "  Torivumab 200mg", "  Placebo",
           "Safety population", "Per-Protocol population",
           "Response Evaluable population",
           "Completed study treatment", "Discontinued treatment",
           "  Disease progression", "  Adverse event", "  Withdrawal by subject",
           "  Death", "  Other",
           "Ongoing at data cutoff", "Died on study")
  v1 <- c(PHN, PHN, PHN, PHN, "—",
          PHN, PHN, PHN, PHNPCT, PHNPCT,
          PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT)
  v2 <- c("—", "—", "—", "—", PHN,
          PHN, PHN, PHN, PHNPCT, PHNPCT,
          PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT)
  hdr <- c(3, 10)
  ind <- c(4:5, 11:15)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-EFF-01/03/08/11 — TTE primary (OS or PFS)
tte_mock <- function(param = "OS") {
  lbl <- c(
    paste("Number of subjects"),
    paste0("  Events (", param, " or death), n (%)"),
    "  Censored, n (%)",
    paste0("Median ", param, " (months)"),
    "  Estimate", "  95% CI (Brookmeyer-Crowley)",
    paste0(param, " probability at 12 months (95% CI)"),
    paste0(param, " probability at 24 months (95% CI)"),
    "Hazard Ratio (Torivumab / Placebo)",
    "  Estimate (stratified Cox)", "  95% CI",
    "Stratified log-rank p-value"
  )
  v1 <- c(PHN, PHNPCT, PHNPCT, "", PH, PHCI, paste(PH, PHCI), paste(PH, PHCI), "", PHHR, PHCI, PHHR)
  v2 <- c(PHN, PHNPCT, PHNPCT, "", PH, PHCI, paste(PH, PHCI), paste(PH, PHCI), "", "—", "—", "—")
  hdr <- c(4, 9)
  ind <- c(2:3, 5:6, 10:11)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-EFF-02/04 — KM probabilities
km_prob_mock <- function() {
  lbl <- c("6 months", "12 months", "18 months", "24 months")
  # 4 value cols: arm1 estimate, arm1 CI, arm2 estimate, arm2 CI
  df <- data.frame(
    " " = lbl,
    "Prob" = rep(PH, 4), "95% CI" = rep(PHCI, 4),
    "Prob " = rep(PH, 4), "95% CI " = rep(PHCI, 4),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  list(df = df, header_rows = integer(0), indent_rows = integer(0),
       needs_span = TRUE, span_labels = c(arm1(), arm2()))
}

# T-EFF-05 — ORR / T-EFF-06 — DCR
response_mock <- function(type = "ORR") {
  if (type == "ORR") {
    lbl <- c("N (Response Evaluable)", "Responders (CR + PR), n (%)",
             "  95% CI (Clopper-Pearson)", "  95% CI (Wilson — sensitivity)",
             "Risk Difference (Torivumab − Placebo, %)",
             "  95% CI (Mantel-Haenszel)", "  Stratified CMH p-value",
             "Best Overall Response",
             "  Complete Response (CR), n (%)", "  Partial Response (PR), n (%)",
             "  Stable Disease (SD), n (%)", "  Progressive Disease (PD), n (%)",
             "  Not Evaluable (NE), n (%)")
    v1 <- c(PHN, PHNPCT, PHCI, PHCI, PH, PHCI, PHHR,
            "", PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT)
    v2 <- c(PHN, PHNPCT, PHCI, PHCI, "—", "—", "—",
            "", PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT)
    hdr <- c(8);  ind <- c(3:4, 6:7, 9:13)
  } else {
    lbl <- c("N (Response Evaluable)", "Subjects with CR + PR + SD (≥ 8 wks), n (%)",
             "  95% CI (Clopper-Pearson)",
             "Risk Difference (Torivumab − Placebo, %)",
             "  95% CI (Mantel-Haenszel)", "  Stratified CMH p-value")
    v1 <- c(PHN, PHNPCT, PHCI, PH, PHCI, PHHR)
    v2 <- c(PHN, PHNPCT, PHCI, "—", "—", "—")
    hdr <- integer(0);  ind <- c(3, 5:6)
  }
  list(df = two_arm_df(lbl, v1, v2, a1_n = 300, a2_n = 140),
       header_rows = hdr, indent_rows = ind)
}

# T-EFF-07 — Duration of Response
dor_mock <- function() {
  lbl <- c("Confirmed Responders, n",
           "Median DoR (months)",
           "  Estimate", "  95% CI (Brookmeyer-Crowley)",
           "DoR ≥ 6 months, n (%)", "DoR ≥ 12 months, n (%)")
  v1 <- c(PHN, "", PH, PHCI, PHNPCT, PHNPCT)
  v2 <- c(PHN, "", PH, PHCI, PHNPCT, PHNPCT)
  list(df = two_arm_df(lbl, v1, v2), header_rows = c(2), indent_rows = c(3:4))
}

# T-EFF-09 — Landmark
landmark_mock <- function() {
  df <- data.frame(
    " " = c("12 months", "24 months"),
    "Prob" = c(PH, PH), "95% CI" = c(PHCI, PHCI),
    "Prob " = c(PH, PH), "95% CI " = c(PHCI, PHCI),
    "Difference" = c(PH, PH), "95% CI  " = c(PHCI, PHCI),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  list(df = df, header_rows = integer(0), indent_rows = integer(0),
       needs_span = TRUE, span_labels = c(arm1(), arm2(), "Difference (95% CI)"))
}

# T-EFF-10 — RMST
rmst_mock <- function() {
  lbl <- c("RMST at τ = 36 months (months)",
           paste0("  ", arm1(300)), paste0("  ", arm2(150)),
           "RMST Difference (Torivumab − Placebo)",
           "  Estimate", "  95% CI", "  p-value")
  v1 <- c("", PH, PH, "", PH, PHCI, PHHR)
  v2 <- rep("", length(lbl))
  df <- data.frame(" " = lbl, "Estimate / 95% CI" = v1, check.names = FALSE)
  list(df = df, header_rows = c(1, 4), indent_rows = c(2:3, 5:7), single_col = TRUE)
}

# T-EX-01 — Exposure
ex_mock <- function() {
  lbl <- c(
    "Treatment duration (months)", "  Median (Min, Max)",
    "  Mean (SD)",
    "  ≥ 6 cycles, n (%)", "  ≥ 12 cycles, n (%)", "  ≥ 24 cycles, n (%)",
    "Number of cycles received", "  Mean (SD)", "  Median (Min, Max)",
    "Relative dose intensity (%)", "  Mean (SD)")
  v1 <- c("", paste0(PH, " (", PH, ", ", PH, ")"), paste(PH, paste0("(", PH, ")")),
          PHNPCT, PHNPCT, PHNPCT,
          "", paste(PH, paste0("(", PH, ")")), paste0(PH, " (", PH, ", ", PH, ")"),
          "", paste(PH, paste0("(", PH, ")")))
  v2 <- v1
  hdr <- c(1, 7, 10);  ind <- c(2:6, 8:9, 11)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-AE-01 — AE overall
ae_overall_mock <- function() {
  lbl <- c("Any AE", "Any treatment-emergent AE (TEAE)",
           "  Grade 1–2 TEAE", "  Grade ≥ 3 TEAE",
           "Any serious AE (SAE)", "Any TEAE leading to discontinuation",
           "Any immune-related AE (irAE)",
           "  Grade ≥ 3 irAE",
           "Any adverse event of special interest (AESI)",
           "Any AE leading to death")
  v1 <- rep(PHNPCT, length(lbl))
  v2 <- rep(PHNPCT, length(lbl))
  vt <- rep(PHNPCT, length(lbl))
  hdr <- integer(0);  ind <- c(3:4, 8)
  list(df = three_arm_df(lbl, v1, v2, vt), header_rows = hdr, indent_rows = ind)
}

# T-AE-02/03/04 — AE by SOC/PT (hierarchical)
ae_soc_mock <- function(grade_filter = "") {
  lbl <- c(
    paste0("Any TEAE", grade_filter),
    "System Organ Class 1 (e.g. Respiratory)", "  Preferred Term 1 (e.g. Pneumonitis)", "  Preferred Term 2",
    "System Organ Class 2 (e.g. Gastrointestinal)", "  Preferred Term 1 (e.g. Diarrhoea)", "  Preferred Term 2",
    "System Organ Class 3 (e.g. Endocrine)", "  Preferred Term 1 (e.g. Hypothyroidism)",
    "[Additional SOC/PTs...]"
  )
  v1 <- c(PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, "...")
  v2 <- v1
  hdr <- c(2, 5, 8);  ind <- c(3:4, 6:7, 9)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-AE-05 — irAE
irae_mock <- function() {
  lbl <- c("Any irAE",
           "Pneumonitis", "  Grade 1–2", "  Grade 3–4",
           "Colitis / Diarrhoea", "  Grade 1–2", "  Grade 3–4",
           "Hepatitis", "  Grade 1–2", "  Grade 3–4",
           "Endocrinopathies (any)", "  Hypothyroidism", "  Hyperthyroidism",
           "  Adrenal insufficiency", "  Diabetes mellitus type 1",
           "Infusion-related reaction", "  Grade 1–2", "  Grade 3–4",
           "Other irAE")
  v1 <- rep(PHNPCT, length(lbl))
  v2 <- rep(PHNPCT, length(lbl))
  hdr <- c(2, 5, 8, 11, 16, 19);  ind <- c(3:4, 6:7, 9:10, 12:15, 17:18)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-AE-06 — AESI
aesi_mock <- function() {
  lbl <- c("Any AESI",
           "AESI Category 1 (per Protocol §7.4)", "  Grade 1–2", "  Grade ≥ 3",
           "AESI Category 2", "  Grade 1–2", "  Grade ≥ 3",
           "AESI Category 3", "  Grade 1–2", "  Grade ≥ 3",
           "[Categories per Protocol §7.4 AESI list — to be finalised at SAP lock]")
  v1 <- c(PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, "—")
  v2 <- v1
  hdr <- c(2, 5, 8);  ind <- c(3:4, 6:7, 9:10)
  list(df = two_arm_df(lbl, v1, v2), header_rows = hdr, indent_rows = ind)
}

# T-AE-07 — Deaths
deaths_mock <- function() {
  lbl <- c("All on-study deaths, n (%)", "  Within 30 days of last dose",
           "  Due to adverse event", "  Due to disease progression",
           "  Other / Unknown",
           "Deaths after data cutoff (not counted)", "[Source: ADSL DTHFL='Y'; DTHCAUS]")
  v1 <- c(PHNPCT, PHNPCT, PHNPCT, PHNPCT, PHNPCT, "—", "")
  v2 <- v1
  list(df = two_arm_df(lbl, v1, v2), header_rows = integer(0), indent_rows = c(2:5))
}

# T-DS-02 — Protocol deviations
deviations_mock <- function() {
  lbl <- c("Subjects with ≥ 1 major deviation, n (%)",
           "  Eligibility criteria violated",
           "  Randomised but never dosed",
           "  Prohibited concomitant medication",
           "  ≥ 2 consecutive missed tumour assessments",
           "  Other")
  v1 <- rep(PHNPCT, 6);  v2 <- v1;  vt <- v1
  list(df = three_arm_df(lbl, v1, v2, vt), header_rows = c(1), indent_rows = c(2:6))
}

# T-LB-01 — Shift table (one representative panel shown; note says one per PARAMCD)
shift_mock <- function() {
  df <- data.frame(
    "Baseline" = c("Normal", "Low", "High", "Total"),
    "Normal" = c(PHN, PHN, PHN, PHN),
    "Low"    = c(PHN, PHN, PHN, PHN),
    "High"   = c(PHN, PHN, PHN, PHN),
    "Total"  = c(PHN, PHN, PHN, PHN),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  list(df = df, header_rows = integer(0), indent_rows = integer(0),
       note_extra = "Panel shown for one PARAMCD; document contains one panel per lab test per arm.")
}

# T-LB-02 — Lab Grade ≥3
lb_grade3_mock <- function() {
  params <- c("Haemoglobin", "Neutrophils", "Platelets", "ALT", "AST",
              "Alkaline Phosphatase", "Bilirubin (total)", "Creatinine",
              "Sodium", "Potassium", "TSH", "[Additional parameters...]")
  v1 <- c(rep(PHNPCT, 11), "")
  v2 <- v1
  list(df = two_arm_df(params, v1, v2), header_rows = integer(0), indent_rows = integer(0))
}

# Listing mock — column header rows + 3 placeholder rows
listing_mock <- function(output) {
  vars <- output$key_variables
  if (!length(vars)) vars <- c("USUBJID", "TRT01A", "PARAMCD", "VALUE", "ADT")
  placeholder_row <- setNames(
    as.list(rep("—", length(vars))), vars
  )
  df <- rbind(
    as.data.frame(placeholder_row, stringsAsFactors = FALSE),
    as.data.frame(placeholder_row, stringsAsFactors = FALSE),
    as.data.frame(placeholder_row, stringsAsFactors = FALSE)
  )
  df
}

# ---- Dispatch: get mock data for a given output ---------------------------
get_mock <- function(o) {
  switch(o$id,
    "T-DM-01"  = dm_mock(),
    "T-DS-01"  = ds_mock(),
    "T-DS-02"  = deviations_mock(),
    "T-EX-01"  = ex_mock(),
    "T-EFF-01" = tte_mock("OS"),
    "T-EFF-02" = km_prob_mock(),
    "T-EFF-03" = tte_mock("PFS"),
    "T-EFF-04" = km_prob_mock(),
    "T-EFF-05" = response_mock("ORR"),
    "T-EFF-06" = response_mock("DCR"),
    "T-EFF-07" = dor_mock(),
    "T-EFF-08" = tte_mock("OS"),
    "T-EFF-09" = landmark_mock(),
    "T-EFF-10" = rmst_mock(),
    "T-EFF-11" = tte_mock("PFS"),
    "T-AE-01"  = ae_overall_mock(),
    "T-AE-02"  = ae_soc_mock(),
    "T-AE-03"  = ae_soc_mock(" (Grade ≥ 3)"),
    "T-AE-04"  = ae_soc_mock(" (Serious)"),
    "T-AE-05"  = irae_mock(),
    "T-AE-06"  = aesi_mock(),
    "T-AE-07"  = deaths_mock(),
    "T-LB-01"  = shift_mock(),
    "T-LB-02"  = lb_grade3_mock(),
    NULL
  )
}

# ---- Figure placeholder text (fallback) ------------------------------------
figure_placeholder <- function(o) {
  ly <- o$layout %||% list()
  lines <- c(
    paste0("  Title  :  ", o$title),
    paste0("  Output :  ", o$id, "  |  Kind: Figure"),
    paste0("  Set    :  ", as_pop_line(o$analysis_set)),
    paste0("  Source :  ", paste(o$source_datasets, collapse = ", ")),
    ""
  )
  if (!is.null(ly$axes))        lines <- c(lines, paste0("  Axes   :  ", ly$axes))
  if (!is.null(ly$features))    lines <- c(lines, paste0("  Features: ", ly$features))
  if (!is.null(ly$annotations)) lines <- c(lines, paste0("  Annots :  ", ly$annotations))
  if (!is.null(ly$rows))        lines <- c(lines, paste0("  Rows   :  ", ly$rows))
  if (!is.null(ly$columns))     lines <- c(lines, paste0("  Columns:  ", ly$columns))
  lines <- c(lines, "", "  [Placeholder — figure generated in Phase 6 from ADaM data]")
  paste(lines, collapse = "\n")
}

# ---- Figure shell generators -------------------------------------------------
# Realistic synthetic curves/bars/lanes for visual context, but every numeric
# annotation uses xx.x / xxx placeholders.  No real data — consistent with
# the table shell convention while still looking like a clinical trial figure.

SHELL_THEME <- theme_minimal(base_family = F_SANS, base_size = 10) +
  theme(
    plot.title      = element_text(face = "bold", size = 11, color = C_NAVY),
    plot.subtitle   = element_text(size = 9, color = "#444444"),
    plot.caption    = element_text(size = 7.5, color = C_RED, face = "italic"),
    panel.grid.minor = element_blank()
  )

SHELL_CAPTION <- "DRAFT SHELL \u2014 synthetic curves for layout review only; all annotations are placeholders"
C_ANNOT <- "#333333"  # annotation text colour — high contrast

## F-EFF-01 / F-EFF-02: KM curve (synthetic + placeholder annotations) --------
shell_km_plot <- function(param = "OS") {
  set.seed(4718)
  n <- 100
  arm <- rep(c("Torivumab 200mg", "Placebo"), each = n)
  hr_sim <- if (param == "OS") 0.72 else 0.65
  time <- c(rexp(n, rate = 1 / 24), rexp(n, rate = 1 / (24 * hr_sim)))
  cens_time <- runif(2 * n, min = 6, max = 36)
  obs_time  <- pmin(time, cens_time)
  status    <- as.integer(time <= cens_time)

  df <- data.frame(time = obs_time, status = status, arm = arm)
  fit <- survfit(Surv(time, status) ~ arm, data = df)
  sfit <- summary(fit)

  step_df <- data.frame(
    time = sfit$time, surv = sfit$surv,
    lower = sfit$lower, upper = sfit$upper,
    arm = sub("arm=", "", sfit$strata)
  )
  arms <- unique(step_df$arm)
  step_df <- rbind(
    data.frame(time = 0, surv = 1, lower = 1, upper = 1, arm = arms[1]),
    data.frame(time = 0, surv = 1, lower = 1, upper = 1, arm = arms[2]),
    step_df
  )

  risk_times <- seq(0, 36, by = 6)

  ylab <- if (param == "OS") "Survival Probability" else "Progression-Free Probability"
  ttl  <- if (param == "OS") "Kaplan-Meier Curve \u2014 Overall Survival"
          else "Kaplan-Meier Curve \u2014 Progression-Free Survival"

  cols <- c("Torivumab 200mg" = C_BLUE, "Placebo" = C_RED)

  p_main <- ggplot(step_df, aes(x = time, y = surv, color = arm, fill = arm)) +
    geom_step(linewidth = 0.9) +
    geom_ribbon(aes(ymin = lower, ymax = upper), stat = "identity",
                alpha = 0.12, color = NA) +
    # Median reference
    annotate("segment", x = 0, xend = 36, y = 0.5, yend = 0.5,
             linetype = "dotted", color = C_MID, linewidth = 0.4) +
    annotate("text", x = 1, y = 0.53, label = "Median: xx.x vs xx.x months",
             size = 3, hjust = 0, family = F_MONO, color = C_ANNOT) +
    # HR / p annotation box
    annotate("label", x = 20, y = 0.15,
             label = paste0("HR = x.xxx (95% CI: xx.x \u2013 xx.x)\n",
                            "Stratified log-rank p = x.xxxx"),
             size = 3.2, hjust = 0, family = F_MONO, color = C_ANNOT,
             fill = "#FFFFFF", label.size = 0.4, label.padding = unit(6, "pt")) +
    # DRAFT watermark
    annotate("text", x = 18, y = 0.58, label = "DRAFT", size = 20,
             alpha = 0.07, fontface = "bold", color = C_NAVY) +
    scale_color_manual(values = cols) +
    scale_fill_manual(values = cols) +
    scale_x_continuous(breaks = risk_times, limits = c(0, 36)) +
    scale_y_continuous(breaks = seq(0, 1, 0.25),
                       labels = paste0(seq(0, 100, 25), "%"),
                       limits = c(0, 1)) +
    labs(x = "Time (months)", y = ylab, title = ttl,
         subtitle = "ITT Population (N=xxx)",
         caption = SHELL_CAPTION, color = NULL, fill = NULL) +
    SHELL_THEME +
    theme(legend.position = "bottom")

  # Number-at-risk table — xxx placeholders
  risk_df <- expand.grid(
    time = risk_times,
    arm  = c("Torivumab 200mg", "Placebo"),
    stringsAsFactors = FALSE
  )
  risk_df$label <- "xxx"

  p_risk <- ggplot(risk_df, aes(x = time, y = arm, label = label)) +
    geom_text(size = 3, family = F_MONO, color = C_ANNOT) +
    scale_x_continuous(breaks = risk_times, limits = c(0, 36)) +
    labs(x = NULL, y = NULL, title = "Number at risk") +
    theme_minimal(base_size = 9, base_family = F_SANS) +
    theme(
      plot.title  = element_text(size = 8, face = "bold", color = C_NAVY,
                                 margin = margin(0, 0, 2, 0)),
      panel.grid  = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks  = element_blank(),
      axis.text.y = element_text(size = 7.5, color = C_NAVY),
      plot.margin = margin(0, 5, 0, 5)
    )

  (p_main / p_risk) + patchwork::plot_layout(heights = c(5, 1))
}

## F-EFF-03: Waterfall (synthetic bars + placeholder annotations) --------------
shell_waterfall_plot <- function() {
  set.seed(6293)
  n <- 80
  arm <- sample(c("Torivumab 200mg", "Placebo"), n, replace = TRUE, prob = c(0.67, 0.33))
  pchg <- ifelse(arm == "Torivumab 200mg",
                 rnorm(n, mean = -25, sd = 30),
                 rnorm(n, mean = -5,  sd = 30))
  pchg <- pmax(pmin(pchg, 80), -100)

  df <- data.frame(pchg = pchg, arm = arm)
  df <- df[order(df$pchg), ]
  df$subj <- seq_len(nrow(df))

  cols <- c("Torivumab 200mg" = C_BLUE, "Placebo" = C_RED)

  ggplot(df, aes(x = subj, y = pchg, fill = arm)) +
    geom_col(width = 0.8) +
    geom_hline(yintercept = -30, linetype = "dashed", color = "#2ECC71", linewidth = 0.6) +
    geom_hline(yintercept =  20, linetype = "dashed", color = "#E67E22", linewidth = 0.6) +
    annotate("text", x = 3, y = -34, label = "PR threshold (\u221230%)",
             size = 2.8, hjust = 0, color = "#2ECC71") +
    annotate("text", x = 3, y = 24, label = "PD threshold (+20%)",
             size = 2.8, hjust = 0, color = "#E67E22") +
    # ORR placeholder
    annotate("label", x = n * 0.65, y = 65,
             label = "ORR: xx.x% vs xx.x%\nN = xxx evaluable subjects",
             size = 3, hjust = 0, family = F_MONO, color = C_ANNOT,
             fill = "#FFFFFF", label.size = 0.4, label.padding = unit(5, "pt")) +
    annotate("text", x = n / 2, y = -5, label = "DRAFT", size = 20,
             alpha = 0.07, fontface = "bold", color = C_NAVY) +
    scale_fill_manual(values = cols) +
    labs(x = "Subject (sorted by best % change)",
         y = "Best % Change from Baseline SLD",
         title = "Waterfall \u2014 Best Percent Change in Target Lesion SLD",
         subtitle = "Response Evaluable Population (N=xxx)",
         caption = SHELL_CAPTION, fill = NULL) +
    SHELL_THEME +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
          legend.position = "bottom")
}

## F-EFF-04: Spider (synthetic lines + placeholder annotations) ----------------
shell_spider_plot <- function() {
  set.seed(8154)
  n_subj <- 50
  arms <- sample(c("Torivumab 200mg", "Placebo"), n_subj, replace = TRUE, prob = c(0.67, 0.33))
  visits <- c(0, 6, 12, 18, 24, 30, 36)

  df <- do.call(rbind, lapply(seq_len(n_subj), function(i) {
    n_vis <- sample(3:length(visits), 1)
    vis <- visits[seq_len(n_vis)]
    trend <- if (arms[i] == "Torivumab 200mg") -0.8 else 0.3
    pchg <- cumsum(c(0, rnorm(n_vis - 1, mean = trend, sd = 8)))
    pchg <- pmax(pmin(pchg, 80), -100)
    data.frame(subj = paste0("S", i), week = vis, pchg = pchg, arm = arms[i])
  }))

  cols <- c("Torivumab 200mg" = C_BLUE, "Placebo" = C_RED)

  ggplot(df, aes(x = week, y = pchg, group = subj, color = arm)) +
    geom_line(alpha = 0.45, linewidth = 0.4) +
    geom_hline(yintercept = -30, linetype = "dashed", color = "#2ECC71", linewidth = 0.4) +
    geom_hline(yintercept =  20, linetype = "dashed", color = "#E67E22", linewidth = 0.4) +
    annotate("text", x = 37, y = -30, label = "PR (\u221230%)",
             size = 2.5, hjust = 0, color = "#2ECC71") +
    annotate("text", x = 37, y = 20, label = "PD (+20%)",
             size = 2.5, hjust = 0, color = "#E67E22") +
    annotate("label", x = 1, y = 75,
             label = "N = xxx subjects  |  One line per subject",
             size = 2.8, hjust = 0, family = F_MONO, color = C_ANNOT,
             fill = "#FFFFFF", label.size = 0.4, label.padding = unit(4, "pt")) +
    annotate("text", x = 18, y = 0, label = "DRAFT", size = 20,
             alpha = 0.07, fontface = "bold", color = C_NAVY) +
    scale_color_manual(values = cols) +
    scale_x_continuous(breaks = visits) +
    scale_y_continuous(limits = c(-80, 85)) +
    labs(x = "Weeks from Baseline", y = "% Change from Baseline SLD",
         title = "Spider \u2014 Target Lesion SLD Change Over Time",
         subtitle = "Response Evaluable Population (N=xxx)",
         caption = SHELL_CAPTION, color = NULL) +
    SHELL_THEME +
    theme(legend.position = "bottom")
}

## F-EFF-05: Forest (synthetic HRs + placeholder annotations) -----------------
shell_forest_plot <- function() {
  set.seed(3471)
  subgroups <- c(
    "Overall (stratified)",
    "Histology: Squamous", "Histology: Non-squamous",
    "Region: North America", "Region: Europe", "Region: Asia-Pacific",
    "Sex: Male", "Sex: Female",
    "Age: < 65", "Age: \u2265 65",
    "ECOG: 0", "ECOG: 1",
    "PD-L1: 50\u201374%", "PD-L1: \u2265 75%"
  )
  n_sg <- length(subgroups)
  hr     <- c(0.72, runif(n_sg - 1, 0.45, 1.10))
  hr_lo  <- hr * runif(n_sg, 0.55, 0.85)
  hr_hi  <- hr * runif(n_sg, 1.15, 1.55)

  df <- data.frame(
    subgroup = factor(subgroups, levels = rev(subgroups)),
    hr = hr, lo = hr_lo, hi = hr_hi,
    is_overall = c(TRUE, rep(FALSE, n_sg - 1))
  )

  ggplot(df, aes(x = hr, y = subgroup)) +
    geom_vline(xintercept = 1, linetype = "dashed", color = C_GREY) +
    geom_pointrange(aes(xmin = lo, xmax = hi),
                    size = 0.45, linewidth = 0.55, color = C_NAVY,
                    shape = ifelse(df$is_overall, 18, 16)) +
    # Placeholder text columns
    geom_text(aes(label = "x.xxx (xx.x, xx.x)"),
              x = max(hr_hi) * 1.15, size = 2.6, hjust = 0,
              family = F_MONO, color = C_ANNOT) +
    geom_text(aes(label = "xxx   xxx"),
              x = 0.16, size = 2.6, hjust = 0, family = F_MONO, color = C_ANNOT) +
    # Column headers
    annotate("text", x = 0.16, y = n_sg + 0.6,
             label = "n      ev", size = 2.8, hjust = 0,
             fontface = "bold", family = F_MONO, color = C_NAVY) +
    annotate("text", x = max(hr_hi) * 1.15, y = n_sg + 0.6,
             label = "HR (95% CI)", size = 2.8, hjust = 0,
             fontface = "bold", family = F_MONO, color = C_NAVY) +
    # Favours labels
    annotate("text", x = 0.38, y = 0.3, label = "\u2190 Favours Torivumab",
             size = 2.5, hjust = 0, color = "#555555", family = F_SANS) +
    annotate("text", x = 1.05, y = 0.3, label = "Favours Placebo \u2192",
             size = 2.5, hjust = 0, color = "#555555", family = F_SANS) +
    annotate("text", x = 0.85, y = 7, label = "DRAFT", size = 18,
             alpha = 0.07, fontface = "bold", color = C_NAVY) +
    scale_x_log10(breaks = c(0.25, 0.5, 1, 2),
                  limits = c(0.12, max(hr_hi) * 2.2)) +
    labs(x = "Hazard Ratio (log scale)", y = NULL,
         title = "Forest \u2014 OS Hazard Ratio by Subgroup",
         subtitle = "ITT Population (N=xxx)  |  Unstratified Cox per subgroup; overall stratified",
         caption = SHELL_CAPTION) +
    SHELL_THEME +
    theme(panel.grid.major.y = element_blank())
}

## F-EFF-06: Swimmer (synthetic lanes + placeholder annotations) ---------------
shell_swimmer_plot <- function() {
  set.seed(5907)
  n <- 25
  arm <- sample(c("Torivumab 200mg", "Placebo"), n, replace = TRUE, prob = c(0.7, 0.3))
  resp_start <- runif(n, 1, 6)
  resp_dur   <- rexp(n, rate = 1 / 10)
  total_time <- resp_start + resp_dur + runif(n, 0, 4)

  event <- sample(c("PD", "Death", "Ongoing"), n, replace = TRUE, prob = c(0.4, 0.15, 0.45))
  event_time <- ifelse(event == "Ongoing", total_time,
                       resp_start + resp_dur + runif(n, 0, 1))
  total_time <- pmax(total_time, event_time + 0.5)

  df <- data.frame(
    subj = factor(paste0("S", sprintf("%02d", seq_len(n)))),
    arm = arm, resp_start = resp_start,
    resp_end = resp_start + resp_dur,
    event = event, event_time = event_time, total_time = total_time
  )
  df <- df[order(df$total_time), ]
  df$subj <- factor(df$subj, levels = df$subj)

  cols <- c("Torivumab 200mg" = C_BLUE, "Placebo" = C_RED)

  ggplot(df) +
    geom_segment(aes(x = 0, xend = total_time, y = subj, yend = subj),
                 color = C_LGREY, linewidth = 2.5) +
    geom_segment(aes(x = resp_start, xend = resp_end, y = subj, yend = subj, color = arm),
                 linewidth = 2.5) +
    geom_point(data = df[df$event == "PD", ],
               aes(x = event_time, y = subj),
               shape = 17, size = 2.2, color = "#E67E22") +
    geom_point(data = df[df$event == "Death", ],
               aes(x = event_time, y = subj),
               shape = 4, size = 2.2, stroke = 1.2, color = "#333333") +
    geom_point(data = df[df$event == "Ongoing", ],
               aes(x = total_time, y = subj),
               shape = 62, size = 3, color = "#2ECC71") +
    # Annotation — high contrast
    annotate("label", x = max(df$total_time) * 0.65, y = 3,
             label = paste0("\u25b2 PD     \u2716 Death     > Ongoing\n",
                            "xxx confirmed responders"),
             size = 2.8, hjust = 0.5, family = F_SANS, color = C_ANNOT,
             fill = "#FFFFFF", label.size = 0.4, label.padding = unit(5, "pt")) +
    annotate("text", x = max(df$total_time) / 2, y = n / 2, label = "DRAFT",
             size = 18, alpha = 0.07, fontface = "bold", color = C_NAVY) +
    scale_color_manual(values = cols) +
    labs(x = "Months from Randomisation", y = NULL,
         title = "Swimmer \u2014 Confirmed Responders",
         subtitle = "Confirmed Responders (N=xxx)  |  One lane per responder",
         caption = SHELL_CAPTION, color = NULL) +
    SHELL_THEME +
    theme(axis.text.y = element_text(size = 6), legend.position = "bottom")
}

# ---- Figure dispatch -------------------------------------------------------
get_figure_plot <- function(o) {
  switch(o$id,
    "F-EFF-01" = shell_km_plot("OS"),
    "F-EFF-02" = shell_km_plot("PFS"),
    "F-EFF-03" = shell_waterfall_plot(),
    "F-EFF-04" = shell_spider_plot(),
    "F-EFF-05" = shell_forest_plot(),
    "F-EFF-06" = shell_swimmer_plot(),
    NULL
  )
}

# Save a ggplot to a temp PNG and return the file path
save_mock_figure <- function(p, width = 7, height = 4.5, dpi = 150) {
  f <- tempfile(fileext = ".png")
  ggsave(f, plot = p, width = width, height = height, dpi = dpi, bg = "white")
  f
}

# ---- Annotation panel helper -----------------------------------------------
## Builds a flextable annotation panel for one output.
## ann  — the `annotations` list from shells.yaml (may be NULL)
## Returns a flextable or NULL if no rows exist.
make_annotation_ft <- function(ann) {
  if (is.null(ann)) return(NULL)
  ann_rows <- ann$rows
  if (is.null(ann_rows) || length(ann_rows) == 0) return(NULL)

  C_ANNOT_BG  <- "#EAF0FB"   # light blue — standard row
  C_ANNOT_HDR <- "#D0E4F7"   # slightly deeper blue — column header row
  C_STUDY_BG  <- "#FFF8E7"   # amber — study-specific variable rows
  STUDY_TAG   <- "# study-specific"

  # Build the data frame (one row per annotation entry)
  rows_df <- do.call(rbind, lapply(ann_rows, function(ar) {
    var_raw   <- as.character(ar$variable   %||% "")
    where_raw <- as.character(ar$where      %||% "")
    var_disp   <- gsub(STUDY_TAG, "†", var_raw,   fixed = TRUE)
    where_disp <- gsub(STUDY_TAG, "†", where_raw, fixed = TRUE)
    data.frame(
      Row         = as.character(ar$row        %||% ""),
      Dataset     = as.character(ar$dataset    %||% ""),
      Where       = trimws(where_disp),
      Variable    = trimws(var_disp),
      Derivation  = as.character(ar$derivation %||% ""),
      is_study    = grepl(STUDY_TAG, var_raw) | grepl(STUDY_TAG, where_raw),
      stringsAsFactors = FALSE