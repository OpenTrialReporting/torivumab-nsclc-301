# torivumab guidelines loaded
# =============================================================================
# Program    : programs/qc/build_trackers.R
# Purpose    : Generate three QC programming-tracker Excel files for SDTM,
#              ADaM, and TFL deliverables. Each tracker captures primary
#              programmer, QC programmer, status, dates, findings, and lock
#              sign-off — standard pharma double-programming workflow.
# Outputs    : qc/SDTM-PROGRAMMING-TRACKER.xlsx
#              qc/ADAM-PROGRAMMING-TRACKER.xlsx
#              qc/TFL-PROGRAMMING-TRACKER.xlsx
# Usage      : Rscript programs/qc/build_trackers.R   (from project root)
# =============================================================================

suppressPackageStartupMessages({
  library(openxlsx2)
})

QC_DIR <- "qc"
dir.create(QC_DIR, showWarnings = FALSE, recursive = TRUE)

TODAY <- format(Sys.Date(), "%Y-%m-%d")

# -----------------------------------------------------------------------------
# Pre-loaded "accepted limitations" — synthetic-data simplifications that QC
# should NOT re-discover as defects. See qc/VALIDATION-PLAN.md §8 for the
# full table. Keys are output / dataset IDs; values are the note to insert
# into the "Findings / issues" column.
# -----------------------------------------------------------------------------
ACCEPTED_LIMITATIONS <- list(
  sdtm = list(
    SUPPSU = "AL-01: SUPPSU is a legacy artifact (STUDYID 'TORIVUMAB-NSCLC-301', not 'CTX-NSCLC-301'); no generator script in programs/sdtm/. See SDTM-MAPPING-SPEC.md §17. Accepted — not a defect.",
    CM     = "AL-02: cm.parquet does not include post-trial anti-cancer therapy (only supportive-care meds). Affects T-DS-03 + T-EFF-12. Accepted — not a defect.",
    DS     = "AL-03: SDTM.DS does not carry explicit DSCAT='PROTOCOL DEVIATION' records; only PPROTFL='N' is derivable. Accepted — not a defect.",
    RELREC = "AL-11: relrec.parquet contains duplicate rows (~5 per multi-visit lesion) because relrec.R emits one row per TU/TR record rather than one per unique lesion-id. compare_sdtm.R falls back to identical() comparison. Future relrec.R revision should distinct() on (USUBJID, RDOMAIN, IDVARVAL). Accepted — not a defect."
  ),
  adam = list(
    ADTTE = "AL-04: PARAMCD='PFSINV' not derived because the synthetic data has no separate BICR vs Investigator assessment. Affects T-EFF-11. Accepted — not a defect."
  ),
  tfl = list(
    `T-EFF-10` = "AL-06: τ = 30 months (not the SAP-proposed 36 months) bounded by max follow-up. See footnote in t_eff_10_os_rmst.R. Accepted — not a defect.",
    `T-EFF-11` = "AL-07: PFS-INV ≡ PFS in synthetic data (no separate BICR). Identical results to T-EFF-03 expected. Accepted — not a defect.",
    `T-EFF-12` = "AL-02 + AL-10: subsequent anti-cancer therapy not simulated; OSWOT censoring applies only the TRTEDT + 30d component. Accepted — not a defect.",
    `T-DS-02`  = "AL-09: Deviation subcategories beyond 'randomised but never dosed' all show 0 (synthetic data has no granular deviation records). Accepted — not a defect.",
    `T-DS-03`  = "AL-10: Rows for subsequent anti-cancer therapy + missed assessments show 0 (synthetic data limitation). Accepted — not a defect.",
    `T-AE-06`  = "AL-08: AESI categorisation uses MedDRA-PT regex stand-in pending SAP §4.6 deferred AESI list. Accepted — not a defect."
  )
)

# Status values (used in dropdowns + legend)
STATUS_VALUES <- c(
  "Not started",
  "Programmed — pending QC",
  "QC in progress",
  "QC passed — issues none",
  "QC passed — minor issues resolved",
  "QC failed — under rework",
  "Locked"
)

# Colour-coding for status (light fills)
STATUS_FILLS <- c(
  "Not started"                        = "FFE0E0E0",   # grey
  "Programmed — pending QC"            = "FFFFF2CC",   # pale yellow
  "QC in progress"                     = "FFFCE4D6",   # pale orange
  "QC passed — issues none"            = "FFE2EFDA",   # pale green
  "QC passed — minor issues resolved"  = "FFD0E4F7",   # pale blue
  "QC failed — under rework"           = "FFF8CBAD",   # peach
  "Locked"                             = "FFC6E0B4"    # darker green
)

# -----------------------------------------------------------------------------
# Common helpers
# -----------------------------------------------------------------------------
HEADER_FONT  <- wb_color(hex = "FFFFFFFF")
HEADER_FILL  <- "1F3864"
SECTION_FILL <- "F2F2F2"
BORDER_COL   <- "888888"

style_tracker_sheet <- function(wb, sheet, n_rows, n_cols, freeze_first_n_cols = 2) {
  # Header row formatting
  wb$add_fill(sheet = sheet, dims = wb_dims(rows = 1, cols = 1:n_cols),
              color = wb_color(hex = HEADER_FILL))
  wb$add_font(sheet = sheet, dims = wb_dims(rows = 1, cols = 1:n_cols),
              bold = TRUE, color = HEADER_FONT, size = 11, name = "Calibri")
  wb$add_cell_style(sheet = sheet, dims = wb_dims(rows = 1, cols = 1:n_cols),
                    horizontal = "left", vertical = "center",
                    wrap_text = TRUE)
  wb$set_row_heights(sheet = sheet, rows = 1, heights = 36)

  # Body borders + alignment
  body_dims <- wb_dims(rows = 2:(n_rows + 1), cols = 1:n_cols)
  wb$add_border(sheet = sheet, dims = body_dims,
                bottom_color = wb_color(hex = BORDER_COL),
                top_color    = wb_color(hex = BORDER_COL),
                left_color   = wb_color(hex = BORDER_COL),
                right_color  = wb_color(hex = BORDER_COL),
                bottom_border = "thin", top_border = "thin",
                left_border = "thin", right_border = "thin",
                inner_hgrid = "thin", inner_vgrid = "thin")
  wb$add_cell_style(sheet = sheet, dims = body_dims,
                    vertical = "top", wrap_text = TRUE)

  # Freeze top row + N leftmost cols
  wb$freeze_pane(sheet = sheet,
                 first_active_row = 2,
                 first_active_col = freeze_first_n_cols + 1)
}

apply_status_fills <- function(wb, sheet, n_rows, status_col_letter) {
  for (status in names(STATUS_FILLS)) {
    rule_dims <- paste0(status_col_letter, "2:", status_col_letter, n_rows + 1)
    dxf_id <- wb_add_dxfs_style(
      wb,
      name    = paste0("status_", abs(utf8ToInt(substr(status, 1, 1))[1])),
      bg_fill = wb_color(hex = STATUS_FILLS[status])
    )
    wb$add_conditional_formatting(
      sheet = sheet,
      dims  = rule_dims,
      rule  = status,
      type  = "containsText",
      style = paste0("status_", abs(utf8ToInt(substr(status, 1, 1))[1]))
    )
  }
}

add_status_validation <- function(wb, sheet, status_col_letter, n_rows) {
  rng <- paste0(status_col_letter, "2:", status_col_letter, n_rows + 1)
  wb$add_data_validation(
    sheet  = sheet,
    dims   = rng,
    type   = "list",
    value  = sprintf('"%s"', paste(STATUS_VALUES, collapse = ",")),
    allow_blank = TRUE,
    show_error  = FALSE
  )
}

set_widths <- function(wb, sheet, widths) {
  wb$set_col_widths(sheet = sheet, cols = seq_along(widths), widths = widths)
}

# -----------------------------------------------------------------------------
# Build a Status Legend sheet (same content in every workbook)
# -----------------------------------------------------------------------------
add_status_legend <- function(wb) {
  legend_df <- data.frame(
    Status = STATUS_VALUES,
    Meaning = c(
      "Output has not been programmed yet. No code, no parquet, no TFL file.",
      "Primary programmer has produced the output. Awaiting assignment to a QC programmer.",
      "Independent QC programmer is actively re-programming and comparing.",
      "QC double-programming passed. Outputs match within tolerance. No issues raised.",
      "QC found minor issues (typos, formatting) — resolved before sign-off.",
      "QC found substantive differences. Output is being reworked by primary programmer.",
      "Output approved and locked for the snapshot. Any change triggers re-QC."
    ),
    stringsAsFactors = FALSE
  )
  wb$add_worksheet("Status legend")
  wb$add_data(sheet = "Status legend", x = legend_df, start_row = 1, start_col = 1)
  style_tracker_sheet(wb, "Status legend", nrow(legend_df), ncol(legend_df),
                       freeze_first_n_cols = 1)
  apply_status_fills(wb, "Status legend", nrow(legend_df), status_col_letter = "A")
  set_widths(wb, "Status legend", c(40, 90))
}

# -----------------------------------------------------------------------------
# Sign-off sheet
# -----------------------------------------------------------------------------
add_signoff_sheet <- function(wb, deliverable_name) {
  sign_df <- data.frame(
    Role = c(
      "Lead programmer",
      "Lead QC programmer",
      "Biostatistician (analysis review)",
      "Data manager",
      "Project manager",
      "Quality assurance",
      "Sponsor representative"
    ),
    Name      = "",
    Signature = "",
    Date      = "",
    Comment   = "",
    stringsAsFactors = FALSE
  )
  wb$add_worksheet("Sign-off")
  wb$add_data(sheet = "Sign-off", x = sign_df, start_row = 3, start_col = 1)

  # Title block above the table
  wb$add_data(sheet = "Sign-off",
              x = data.frame(c(
                paste0(deliverable_name, " — Sign-off sheet"),
                paste0("Generated ", TODAY, " — synthetic data, not for regulatory submission")
              )),
              start_row = 1, start_col = 1, col_names = FALSE)
  wb$add_font(sheet = "Sign-off", dims = "A1",
              bold = TRUE, size = 14, color = wb_color(hex = HEADER_FILL))
  wb$add_font(sheet = "Sign-off", dims = "A2",
              italic = TRUE, color = wb_color(hex = "C0392B"), size = 9)

  style_tracker_sheet(wb, "Sign-off", nrow(sign_df), ncol(sign_df),
                       freeze_first_n_cols = 1)
  set_widths(wb, "Sign-off", c(34, 22, 22, 14, 50))
}

# -----------------------------------------------------------------------------
# SDTM tracker rows (sourced from the actual file inventory + spec)
# -----------------------------------------------------------------------------
sdtm_rows <- function() {
  parquets <- list.files("datasets/sdtm", pattern = "\\.parquet$", full.names = FALSE)
  # File-size and row-count for each
  detail <- lapply(parquets, function(f) {
    size_kb <- round(file.info(file.path("datasets/sdtm", f))$size / 1024, 1)
    n_rows  <- nrow(arrow::read_parquet(file.path("datasets/sdtm", f)))
    list(name = sub("\\.parquet$", "", f),
         size_kb = size_kb,
         n_rows = n_rows)
  })

  meta <- list(
    dm     = list(klass = "Special purpose", spec_ref = "SDTM-MAPPING-SPEC.md §1",  source = "raw/demographics.csv", script = "programs/sdtm/dm.R"),
    ds     = list(klass = "Events",          spec_ref = "SDTM-MAPPING-SPEC.md §2",  source = "raw/demographics.csv + raw/disposition.csv", script = "programs/sdtm/ds.R"),
    ex     = list(klass = "Interventions",   spec_ref = "SDTM-MAPPING-SPEC.md §3",  source = "raw/exposure.csv", script = "programs/sdtm/ex.R"),
    da     = list(klass = "Interventions",   spec_ref = "SDTM-MAPPING-SPEC.md §4",  source = "raw/drug_accountability.csv", script = "programs/sdtm/da.R"),
    ae     = list(klass = "Events",          spec_ref = "SDTM-MAPPING-SPEC.md §5",  source = "raw/adverse_events.csv + meddra_oncology_subset.csv", script = "programs/sdtm/ae.R"),
    cm     = list(klass = "Interventions",   spec_ref = "SDTM-MAPPING-SPEC.md §6",  source = "raw/conmed.csv + atc_conmed.csv", script = "programs/sdtm/cm.R"),
    mh     = list(klass = "Events",          spec_ref = "SDTM-MAPPING-SPEC.md §7",  source = "raw/medical_history.csv", script = "programs/sdtm/mh.R"),
    su     = list(klass = "Interventions",   spec_ref = "SDTM-MAPPING-SPEC.md §8",  source = "raw/substance_use.csv", script = "programs/sdtm/su.R"),
    dd     = list(klass = "Events",          spec_ref = "SDTM-MAPPING-SPEC.md §9",  source = "raw/death.csv", script = "programs/sdtm/dd.R"),
    lb     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §10", source = "raw/labs.csv", script = "programs/sdtm/lb.R"),
    vs     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §11", source = "raw/vital_signs.csv", script = "programs/sdtm/vs.R"),
    pe     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §12", source = "raw/physical_exam.csv", script = "programs/sdtm/pe.R"),
    tu     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §13", source = "raw/tumor_measurements.csv", script = "programs/sdtm/tu.R"),
    tr     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §14", source = "raw/tumor_measurements.csv", script = "programs/sdtm/tr.R"),
    rs     = list(klass = "Findings",        spec_ref = "SDTM-MAPPING-SPEC.md §15", source = "raw/overall_response.csv", script = "programs/sdtm/rs.R"),
    suppdm = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §16", source = "raw/demographics.csv", script = "programs/sdtm/suppdm.R"),
    suppsu = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §17", source = "raw/substance_use.csv (legacy)", script = "(generator missing — see spec §17)"),
    suppae = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §18", source = "ae.parquet + raw/adverse_events.csv", script = "programs/sdtm/suppae.R"),
    suppcm = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §19", source = "cm.parquet", script = "programs/sdtm/suppcm.R"),
    supplb = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §20", source = "lb.parquet", script = "programs/sdtm/supplb.R"),
    relrec = list(klass = "Relationship",    spec_ref = "SDTM-MAPPING-SPEC.md §21", source = "tu.parquet + tr.parquet + rs.parquet", script = "programs/sdtm/relrec.R")
  )

  rows <- lapply(detail, function(d) {
    m <- meta[[d$name]]
    if (is.null(m)) m <- list(klass = "—", spec_ref = "—", source = "—", script = "—")
    dom_upper <- toupper(d$name)
    finding   <- ACCEPTED_LIMITATIONS$sdtm[[dom_upper]] %||% ""
    data.frame(
      `Domain`                 = dom_upper,
      `Class`                  = m$klass,
      `Source (raw / SDTM)`    = m$source,
      `Implementation script` = m$script,
      `Spec reference`         = m$spec_ref,
      `Output file`            = paste0("datasets/sdtm/", d$name, ".parquet"),
      `Records`                = format(d$n_rows, big.mark = ","),
      `Size (KB)`              = d$size_kb,
      `Primary programmer`     = "",
      `Programmed date`        = TODAY,
      `QC programmer`          = "",
      `QC method`              = "Independent double programming",
      `QC start date`          = "",
      `QC complete date`       = "",
      `Status`                 = "Programmed — pending QC",
      `Findings / issues`      = finding,
      `Resolution`             = "",
      `Lock date`              = "",
      `Comments`               = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

# -----------------------------------------------------------------------------
# ADaM tracker rows
# -----------------------------------------------------------------------------
adam_rows <- function() {
  parquets <- list.files("datasets/adam", pattern = "\\.parquet$", full.names = FALSE)
  detail <- lapply(parquets, function(f) {
    size_kb <- round(file.info(file.path("datasets/adam", f))$size / 1024, 1)
    n_rows  <- nrow(arrow::read_parquet(file.path("datasets/adam", f)))
    list(name = sub("\\.parquet$", "", f), size_kb = size_kb, n_rows = n_rows)
  })

  meta <- list(
    adsl  = list(klass = "Subject-Level Analysis Dataset", spec_ref = "ADAM-MAPPING-SPEC.md §1", source = "DM + SUPPDM + EX + DS + DD",      analyses = "All — anchor"),
    adae  = list(klass = "Occurrence Data Structure",       spec_ref = "ADAM-MAPPING-SPEC.md §2", source = "AE + ADSL",                       analyses = "T-AE-01..07, L-AE-01/03"),
    adlb  = list(klass = "Basic Data Structure",            spec_ref = "ADAM-MAPPING-SPEC.md §3", source = "LB + ADSL",                       analyses = "T-LB-01/02, L-LB-01"),
    adtr  = list(klass = "Basic Data Structure",            spec_ref = "ADAM-MAPPING-SPEC.md §4", source = "TR + ADSL",                       analyses = "F-EFF-03 (Waterfall), F-EFF-04 (Spider)"),
    adrs  = list(klass = "Basic Data Structure",            spec_ref = "ADAM-MAPPING-SPEC.md §5", source = "RS + ADSL + ADTR",                analyses = "T-EFF-05 (ORR), T-EFF-06 (DCR), T-EFF-13 (ORR-ITT)"),
    adtte = list(klass = "Basic Data Structure",            spec_ref = "ADAM-MAPPING-SPEC.md §6", source = "ADSL + ADRS + DS + DD",           analyses = "T-EFF-01..04, T-EFF-07..12, F-EFF-01/02/05/06")
  )

  rows <- lapply(detail, function(d) {
    m <- meta[[d$name]]
    ds_upper <- toupper(d$name)
    finding  <- ACCEPTED_LIMITATIONS$adam[[ds_upper]] %||% ""
    data.frame(
      `Dataset`                 = ds_upper,
      `Class`                   = m$klass,
      `SDTM source`             = m$source,
      `Implementation script`  = paste0("programs/adam/", d$name, ".R"),
      `Spec reference`          = m$spec_ref,
      `Downstream analyses`     = m$analyses,
      `Output file`             = paste0("datasets/adam/", d$name, ".parquet"),
      `Records`                 = format(d$n_rows, big.mark = ","),
      `Size (KB)`               = d$size_kb,
      `Primary programmer`      = "",
      `Programmed date`         = TODAY,
      `QC programmer`           = "",
      `QC method`               = "Independent double programming",
      `QC start date`           = "",
      `QC complete date`        = "",
      `Status`                  = "Programmed — pending QC",
      `Findings / issues`       = finding,
      `Resolution`              = "",
      `Lock date`               = "",
      `Comments`                = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

# -----------------------------------------------------------------------------
# TFL tracker rows  (drawn from shells.yaml; status drawn from tfl/ output presence)
# -----------------------------------------------------------------------------
tfl_rows <- function() {
  yaml_path <- "sap/shells/shells.yaml"
  if (!requireNamespace("yaml", quietly = TRUE)) install.packages("yaml")
  shells <- yaml::read_yaml(yaml_path)$outputs

  produced_tables <- list.files("tfl/tables",  pattern = "\\.rtf$", full.names = FALSE)
  produced_figs   <- list.files("tfl/figures", pattern = "\\.png$", full.names = FALSE)
  produced_ids    <- c(sub("\\.rtf$", "", produced_tables),
                       sub("\\.png$", "", produced_figs))

  rows <- lapply(shells, function(o) {
    id_norm <- o$id
    status  <- if (id_norm %in% produced_ids) "Programmed — pending QC"
               else                            "Not started"
    output_files <- if (o$kind %in% c("table", "listing"))
      sprintf("tfl/tables/%s.{rtf, docx, html}", o$id)
    else
      sprintf("tfl/figures/%s.png", o$id)

    estimand <- o$estimand_id %||% ""
    sap_ref  <- o$sap_ref %||% ""

    src_ds <- paste(o$source_datasets, collapse = ", ")

    finding <- ACCEPTED_LIMITATIONS$tfl[[o$id]] %||% ""
    data.frame(
      `Output ID`            = o$id,
      `Kind`                 = o$kind,
      `Title`                = o$title,
      `Analysis set`         = o$analysis_set %||% "",
      `Source dataset(s)`    = src_ds,
      `Shell reference`      = "shells.yaml + TFL-SHELLS-DOC.docx",
      `Implementation script` = paste0("programs/tfl/", tolower(gsub("-", "_", o$id)), "*.R"),
      `Output files`         = output_files,
      `SAP reference`        = sap_ref,
      `Estimand ID`          = estimand,
      `Primary programmer`   = "",
      `Programmed date`      = if (id_norm %in% produced_ids) TODAY else "",
      `QC programmer`        = "",
      `QC method`            = "Independent double programming + footer reconciliation",
      `QC start date`        = "",
      `QC complete date`     = "",
      `Status`               = status,
      `Findings / issues`    = finding,
      `Resolution`           = "",
      `Lock date`            = "",
      `Comments`             = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  do.call(rbind, rows)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a

# -----------------------------------------------------------------------------
# Workbook builders
# -----------------------------------------------------------------------------
build_workbook <- function(df, sheet_name, deliverable_name, widths,
                            status_col_letter) {
  wb <- wb_workbook(creator = "torivumab-nsclc-301 build_trackers.R")
  wb$add_worksheet(sheet_name)
  wb$add_data(sheet = sheet_name, x = df, start_row = 1, start_col = 1)
  style_tracker_sheet(wb, sheet_name, nrow(df), ncol(df), freeze_first_n_cols = 2)
  apply_status_fills(wb, sheet_name, nrow(df), status_col_letter)
  add_status_validation(wb, sheet_name, status_col_letter, nrow(df))
  set_widths(wb, sheet_name, widths)
  add_status_legend(wb)
  add_signoff_sheet(wb, deliverable_name)
  wb
}

# Build SDTM
cat("Building SDTM tracker ...\n")
sdtm_df <- sdtm_rows()
sdtm_widths <- c(
  10, 18, 38, 30, 28, 32, 10, 10, 22, 14, 22, 32, 14, 14, 32, 40, 40, 14, 36
)
wb_sdtm <- build_workbook(sdtm_df, "SDTM tracker", "SDTM Programming",
                            sdtm_widths, status_col_letter = "O")
wb_save(wb_sdtm, file.path(QC_DIR, "SDTM-PROGRAMMING-TRACKER.xlsx"), overwrite = TRUE)
cat(sprintf("  qc/SDTM-PROGRAMMING-TRACKER.xlsx  (%d rows)\n", nrow(sdtm_df)))

# Build ADaM
cat("Building ADaM tracker ...\n")
adam_df <- adam_rows()
adam_widths <- c(
  10, 36, 34, 30, 28, 46, 32, 10, 10, 22, 14, 22, 32, 14, 14, 32, 40, 40, 14, 36
)
wb_adam <- build_workbook(adam_df, "ADaM tracker", "ADaM Programming",
                            adam_widths, status_col_letter = "P")
wb_save(wb_adam, file.path(QC_DIR, "ADAM-PROGRAMMING-TRACKER.xlsx"), overwrite = TRUE)
cat(sprintf("  qc/ADAM-PROGRAMMING-TRACKER.xlsx  (%d rows)\n", nrow(adam_df)))

# Build TFL
cat("Building TFL tracker ...\n")
tfl_df <- tfl_rows()
tfl_widths <- c(
  10, 10, 50, 16, 26, 36, 36, 36, 14, 12, 22, 14, 22, 38, 14, 14, 32, 40, 40, 14, 36
)
wb_tfl <- build_workbook(tfl_df, "TFL tracker", "TFL Programming",
                           tfl_widths, status_col_letter = "Q")
wb_save(wb_tfl, file.path(QC_DIR, "TFL-PROGRAMMING-TRACKER.xlsx"), overwrite = TRUE)
cat(sprintf("  qc/TFL-PROGRAMMING-TRACKER.xlsx  (%d rows)\n", nrow(tfl_df)))

cat("\nAll three trackers written to qc/ — open in Excel/LibreOffice to assign\n")
cat("programmers and update statuses as QC progresses.\n")
