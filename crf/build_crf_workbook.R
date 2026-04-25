# torivumab guidelines loaded
# Build CRF Excel Workbook — SIMULATED-TORIVUMAB-2026
# Phase 2 deliverable: crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx
# Standards: CDASH v2.1 → SDTMIG v3.4 → ADaMIG v1.3

library(openxlsx)

STUDY <- "SIMULATED-TORIVUMAB-2026"
PROTOCOL <- "TORIVA-LUNG 301"
DATE_GEN <- "2026-04-01"

wb <- createWorkbook()

# ── Styles ─────────────────────────────────────────────────────────────────────
st_cover_title  <- createStyle(fontSize = 18, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#1F3864", halign = "LEFT", valign = "center",
                                textDecoration = "bold")
st_cover_sub    <- createStyle(fontSize = 12, fontColour = "#1F3864", fontName = "Calibri",
                                halign = "LEFT", valign = "center")
st_cover_warn   <- createStyle(fontSize = 10, fontColour = "#C00000", fontName = "Calibri",
                                halign = "LEFT", valign = "center", textDecoration = "bold",
                                fgFill = "#FFF2CC", wrapText = TRUE)
st_cover_label  <- createStyle(fontSize = 10, fontColour = "#1F3864", fontName = "Calibri",
                                textDecoration = "bold", halign = "LEFT")
st_cover_value  <- createStyle(fontSize = 10, fontColour = "#000000", fontName = "Calibri",
                                halign = "LEFT")

st_hdr_blue     <- createStyle(fontSize = 10, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#1F3864", halign = "CENTER", valign = "center",
                                textDecoration = "bold", wrapText = TRUE,
                                border = "TopBottomLeftRight", borderColour = "#FFFFFF",
                                borderStyle = "thin")
st_hdr_teal     <- createStyle(fontSize = 10, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#2E75B6", halign = "CENTER", valign = "center",
                                textDecoration = "bold", wrapText = TRUE,
                                border = "TopBottomLeftRight", borderColour = "#FFFFFF",
                                borderStyle = "thin")
st_hdr_green    <- createStyle(fontSize = 10, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#375623", halign = "CENTER", valign = "center",
                                textDecoration = "bold", wrapText = TRUE,
                                border = "TopBottomLeftRight", borderColour = "#FFFFFF",
                                borderStyle = "thin")
st_hdr_orange   <- createStyle(fontSize = 10, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#C55A11", halign = "CENTER", valign = "center",
                                textDecoration = "bold", wrapText = TRUE,
                                border = "TopBottomLeftRight", borderColour = "#FFFFFF",
                                borderStyle = "thin")

st_row_alt      <- createStyle(fontSize = 9, fontName = "Calibri", fgFill = "#D9E1F2",
                                wrapText = TRUE, valign = "top",
                                border = "TopBottomLeftRight", borderColour = "#B8CCE4",
                                borderStyle = "thin")
st_row_norm     <- createStyle(fontSize = 9, fontName = "Calibri", fgFill = "#FFFFFF",
                                wrapText = TRUE, valign = "top",
                                border = "TopBottomLeftRight", borderColour = "#B8CCE4",
                                borderStyle = "thin")
st_req          <- createStyle(fontSize = 9, fontName = "Calibri", fgFill = "#FFF2CC",
                                wrapText = TRUE, valign = "top", textDecoration = "bold",
                                border = "TopBottomLeftRight", borderColour = "#B8CCE4",
                                borderStyle = "thin")
st_locked       <- createStyle(fontSize = 9, fontName = "Calibri", fgFill = "#E2EFDA",
                                wrapText = TRUE, valign = "top",
                                border = "TopBottomLeftRight", borderColour = "#B8CCE4",
                                borderStyle = "thin")
st_query_box    <- createStyle(fontSize = 9, fontName = "Calibri", fgFill = "#FFF2CC",
                                wrapText = TRUE, valign = "top",
                                border = "TopBottomLeftRight", borderColour = "#FFD966",
                                borderStyle = "thin")

st_section_hdr  <- createStyle(fontSize = 10, fontColour = "#FFFFFF", fontName = "Calibri",
                                fgFill = "#2E75B6", textDecoration = "bold",
                                border = "TopBottomLeftRight", borderColour = "#1F3864",
                                borderStyle = "medium")

# Helper: write a form sheet
write_form_sheet <- function(wb, sheet_name, form_domain, form_title, visit_info,
                              sdtm_domain, fields_df, header_colour = "blue") {
  addWorksheet(wb, sheet_name, tabColour = switch(header_colour,
    blue   = "#1F3864",
    teal   = "#2E75B6",
    green  = "#375623",
    orange = "#C55A11",
    "#1F3864"
  ))

  hdr_style <- switch(header_colour,
    blue   = st_hdr_blue,
    teal   = st_hdr_teal,
    green  = st_hdr_green,
    orange = st_hdr_orange,
    st_hdr_blue
  )

  # Form header block (rows 1-6)
  writeData(wb, sheet_name, x = data.frame(A = paste0("FORM: ", form_title)), startRow = 1, startCol = 1, colNames = FALSE)
  addStyle(wb, sheet_name, createStyle(fontSize = 14, fontColour = "#FFFFFF", fgFill = "#1F3864",
    textDecoration = "bold", fontName = "Calibri", valign = "center"), rows = 1, cols = 1:10, gridExpand = TRUE)
  mergeCells(wb, sheet_name, cols = 1:10, rows = 1)
  setRowHeights(wb, sheet_name, rows = 1, heights = 28)

  meta <- data.frame(
    Label = c("Study:", "Protocol:", "CDASH Domain:", "SDTM Domain:", "Visit:", "Generated:"),
    Value = c(STUDY, PROTOCOL, form_domain, sdtm_domain, visit_info, DATE_GEN),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(meta))) {
    writeData(wb, sheet_name, x = meta[i, "Label"], startRow = i + 1, startCol = 1, colNames = FALSE)
    writeData(wb, sheet_name, x = meta[i, "Value"], startRow = i + 1, startCol = 2, colNames = FALSE)
    addStyle(wb, sheet_name, st_cover_label, rows = i + 1, cols = 1)
    addStyle(wb, sheet_name, st_cover_value, rows = i + 1, cols = 2:10, gridExpand = TRUE)
  }
  setRowHeights(wb, sheet_name, rows = 2:7, heights = 16)

  # Column headers row 9
  col_names <- c("Seq", "CDASH Variable", "Field Label", "Data Type", "Format/Length",
                  "Codelist", "Required", "SDTM Variable", "Validation Rule", "Instructions / Help Text", "Query / DM Notes")
  writeData(wb, sheet_name, x = as.data.frame(t(col_names)), startRow = 9, startCol = 1, colNames = FALSE)
  addStyle(wb, sheet_name, hdr_style, rows = 9, cols = seq_along(col_names), gridExpand = TRUE)
  setRowHeights(wb, sheet_name, rows = 9, heights = 30)

  # Data rows
  nf <- nrow(fields_df)
  for (i in seq_len(nf)) {
    r <- 9 + i
    row_data <- as.data.frame(t(unlist(fields_df[i, 1:11])), stringsAsFactors = FALSE)
    writeData(wb, sheet_name, x = row_data, startRow = r, startCol = 1, colNames = FALSE)
    base_style <- if (i %% 2 == 0) st_row_alt else st_row_norm
    req_flag    <- if ("required" %in% names(fields_df)) fields_df[i, "required"] else ""
    locked_flag <- if ("locked"   %in% names(fields_df)) fields_df[i, "locked"]   else "N"
    style_to_use <- if (identical(locked_flag, "Y")) st_locked else
                    if (identical(req_flag,    "Y")) st_req     else base_style
    addStyle(wb, sheet_name, style_to_use, rows = r, cols = seq_along(col_names), gridExpand = TRUE)
    # Query column always yellow
    addStyle(wb, sheet_name, st_query_box, rows = r, cols = 11)
    setRowHeights(wb, sheet_name, rows = r, heights = 28)
  }

  # Column widths
  setColWidths(wb, sheet_name, cols = 1,  widths = 5)
  setColWidths(wb, sheet_name, cols = 2,  widths = 18)
  setColWidths(wb, sheet_name, cols = 3,  widths = 28)
  setColWidths(wb, sheet_name, cols = 4,  widths = 13)
  setColWidths(wb, sheet_name, cols = 5,  widths = 14)
  setColWidths(wb, sheet_name, cols = 6,  widths = 22)
  setColWidths(wb, sheet_name, cols = 7,  widths = 9)
  setColWidths(wb, sheet_name, cols = 8,  widths = 16)
  setColWidths(wb, sheet_name, cols = 9,  widths = 30)
  setColWidths(wb, sheet_name, cols = 10, widths = 38)
  setColWidths(wb, sheet_name, cols = 11, widths = 28)

  # Freeze panes
  freezePane(wb, sheet_name, firstActiveRow = 10, firstActiveCol = 3)
}

# Helper to build field rows
f <- function(seq, cdash, label, dtype, fmt, codelist, req, sdtm_var, validation, instructions, locked = "N") {
  data.frame(seq = seq, cdash_variable = cdash, field_label = label,
             data_type = dtype, format = fmt, codelist = codelist,
             required = req, sdtm_variable = sdtm_var,
             validation = validation, instructions = instructions,
             query_notes = "", locked = locked, stringsAsFactors = FALSE)
}

# ── SHEET 1: COVER ─────────────────────────────────────────────────────────────
addWorksheet(wb, "COVER", tabColour = "#1F3864")
setColWidths(wb, "COVER", cols = 1:2, widths = c(28, 60))

cover_rows <- list(
  list(1,  "Study",           STUDY),
  list(2,  "Protocol",        PROTOCOL),
  list(3,  "Document",        "Annotated Case Report Form (aCRF) — Phase 2 Deliverable"),
  list(4,  "Version",         "1.0"),
  list(5,  "Date",            DATE_GEN),
  list(6,  "Status",          "DRAFT — Gate 2 Review"),
  list(7,  "Sponsor",         "Celindra Therapeutics (FICTIONAL)"),
  list(8,  "Indication",      "Non-Small Cell Lung Cancer (NSCLC) — Stage IIIB/IV"),
  list(9,  "Standards",       "CDASH v2.1 | SDTMIG v3.4 | ADaMIG v1.3 | CDISC CT 2024-03"),
  list(10, "Response Criteria","RECIST 1.1"),
  list(11, "AE Coding",       "MedDRA v27.0 | CTCAE v5.0"),
  list(12, "Prepared by",     "Nova (AI Clinical Data Science Assistant)"),
  list(13, "Review by",       "Lovemore Gakava — Pending Gate 2")
)

writeData(wb, "COVER", x = data.frame(A = paste0("aCRF — ", STUDY)), startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "COVER", st_cover_title, rows = 1, cols = 1:2, gridExpand = TRUE)
mergeCells(wb, "COVER", cols = 1:2, rows = 1)
setRowHeights(wb, "COVER", rows = 1, heights = 36)

writeData(wb, "COVER",
  x = data.frame(A = "⚠ FICTIONAL EDUCATIONAL DOCUMENT — NOT FOR REGULATORY USE. All identifiers, patient data, and study results are completely synthetic."),
  startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, "COVER", st_cover_warn, rows = 2, cols = 1:2, gridExpand = TRUE)
mergeCells(wb, "COVER", cols = 1:2, rows = 2)
setRowHeights(wb, "COVER", rows = 2, heights = 36)

for (item in cover_rows) {
  r <- item[[1]] + 3
  writeData(wb, "COVER", x = data.frame(A = item[[2]]), startRow = r, startCol = 1, colNames = FALSE)
  writeData(wb, "COVER", x = data.frame(B = item[[3]]), startRow = r, startCol = 2, colNames = FALSE)
  addStyle(wb, "COVER", st_cover_label, rows = r, cols = 1)
  addStyle(wb, "COVER", st_cover_value, rows = r, cols = 2)
  setRowHeights(wb, "COVER", rows = r, heights = 18)
}

# Forms index table
idx_start <- length(cover_rows) + 7
writeData(wb, "COVER", x = data.frame(A = "FORMS INDEX"), startRow = idx_start, startCol = 1, colNames = FALSE)
addStyle(wb, "COVER", st_section_hdr, rows = idx_start, cols = 1:4, gridExpand = TRUE)
mergeCells(wb, "COVER", cols = 1:4, rows = idx_start)

forms_index <- data.frame(
  Domain = c("DM","DS","IE","EC","DA","AE","CM","MH","SU","VS","LB","PE","DD","TU","TR","RS"),
  Form_Name = c("Demographics","Disposition","Inclusion/Exclusion Criteria","Exposure as Collected",
                "Drug Accountability","Adverse Events","Concomitant Medications","Medical History",
                "Substance Use","Vital Signs","Laboratory Test Results","Physical Examination",
                "Death Details","Tumour Identification","Tumour Results","Disease Response"),
  Type = c(rep("Foundational CDASH",13), rep("Custom Oncology",3)),
  Visit_Schedule = c(
    "Screening/Baseline","All visits","Screening","All on-treatment",
    "Baseline/EOT","All on-treatment + FU","Baseline/ongoing","Screening/Baseline",
    "Screening/Baseline","All visits","Screening/Baseline/end-of-cycle/EOT",
    "Screening/Baseline/EOT","Post-mortem",
    "Baseline Imaging (IMG01)","All Imaging Visits","All Imaging Visits"
  ),
  stringsAsFactors = FALSE
)
writeData(wb, "COVER", x = forms_index, startRow = idx_start + 1, startCol = 1, colNames = TRUE)
addStyle(wb, "COVER", st_hdr_teal, rows = idx_start + 1, cols = 1:4, gridExpand = TRUE)
for (i in seq_len(nrow(forms_index))) {
  r <- idx_start + 1 + i
  s <- if (i %% 2 == 0) st_row_alt else st_row_norm
  addStyle(wb, "COVER", s, rows = r, cols = 1:4, gridExpand = TRUE)
  setRowHeights(wb, "COVER", rows = r, heights = 16)
}
setColWidths(wb, "COVER", cols = 1:4, widths = c(10, 38, 20, 40))

# ── SHEET 2: VISIT SCHEDULE ────────────────────────────────────────────────────
addWorksheet(wb, "VISIT SCHEDULE", tabColour = "#2E75B6")
vs_data <- read.csv("/home/ubuntu/.openclaw/workspace/torivumab-nsclc-301/crf/visit_schedule.csv",
                    stringsAsFactors = FALSE)
writeData(wb, "VISIT SCHEDULE", x = data.frame(A = "VISIT SCHEDULE — SIMULATED-TORIVUMAB-2026"),
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "VISIT SCHEDULE", st_cover_title, rows = 1, cols = 1:ncol(vs_data), gridExpand = TRUE)
mergeCells(wb, "VISIT SCHEDULE", cols = 1:ncol(vs_data), rows = 1)
setRowHeights(wb, "VISIT SCHEDULE", rows = 1, heights = 28)

writeData(wb, "VISIT SCHEDULE", x = vs_data, startRow = 2, startCol = 1, colNames = TRUE)
addStyle(wb, "VISIT SCHEDULE", st_hdr_teal, rows = 2, cols = seq_len(ncol(vs_data)), gridExpand = TRUE)
for (i in seq_len(nrow(vs_data))) {
  r <- 2 + i
  s <- if (i %% 2 == 0) st_row_alt else st_row_norm
  addStyle(wb, "VISIT SCHEDULE", s, rows = r, cols = seq_len(ncol(vs_data)), gridExpand = TRUE)
  setRowHeights(wb, "VISIT SCHEDULE", rows = r, heights = 28)
}
setColWidths(wb, "VISIT SCHEDULE", cols = seq_len(ncol(vs_data)), widths = "auto")
freezePane(wb, "VISIT SCHEDULE", firstActiveRow = 3, firstActiveCol = 2)

# ── SHEET 3: FIELD DEFINITIONS ────────────────────────────────────────────────
addWorksheet(wb, "FIELD DEFINITIONS", tabColour = "#2E75B6")
fd_data <- read.csv("/home/ubuntu/.openclaw/workspace/torivumab-nsclc-301/crf/field_definitions.csv",
                    stringsAsFactors = FALSE)
writeData(wb, "FIELD DEFINITIONS", x = data.frame(A = "FIELD DEFINITIONS — ALL FORMS"),
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "FIELD DEFINITIONS", st_cover_title, rows = 1, cols = 1:ncol(fd_data), gridExpand = TRUE)
mergeCells(wb, "FIELD DEFINITIONS", cols = 1:ncol(fd_data), rows = 1)
setRowHeights(wb, "FIELD DEFINITIONS", rows = 1, heights = 28)

writeData(wb, "FIELD DEFINITIONS", x = fd_data, startRow = 2, startCol = 1, colNames = TRUE)
addStyle(wb, "FIELD DEFINITIONS", st_hdr_teal, rows = 2, cols = seq_len(ncol(fd_data)), gridExpand = TRUE)
for (i in seq_len(nrow(fd_data))) {
  r <- 2 + i
  s <- if (fd_data[i, "required"] == "Yes") st_req else if (i %% 2 == 0) st_row_alt else st_row_norm
  addStyle(wb, "FIELD DEFINITIONS", s, rows = r, cols = seq_len(ncol(fd_data)), gridExpand = TRUE)
  setRowHeights(wb, "FIELD DEFINITIONS", rows = r, heights = 24)
}
setColWidths(wb, "FIELD DEFINITIONS", cols = seq_len(ncol(fd_data)), widths = "auto")
freezePane(wb, "FIELD DEFINITIONS", firstActiveRow = 3, firstActiveCol = 3)

# ── SHEET 4: CODELIST REFERENCE ───────────────────────────────────────────────
addWorksheet(wb, "CODELIST REFERENCE", tabColour = "#2E75B6")
cl_data <- read.csv("/home/ubuntu/.openclaw/workspace/torivumab-nsclc-301/crf/codelist_reference.csv",
                    stringsAsFactors = FALSE)
writeData(wb, "CODELIST REFERENCE", x = data.frame(A = "CODELIST REFERENCE — CDISC CT 2024-03 & Study-Specific"),
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "CODELIST REFERENCE", st_cover_title, rows = 1, cols = 1:ncol(cl_data), gridExpand = TRUE)
mergeCells(wb, "CODELIST REFERENCE", cols = 1:ncol(cl_data), rows = 1)
setRowHeights(wb, "CODELIST REFERENCE", rows = 1, heights = 28)

writeData(wb, "CODELIST REFERENCE", x = cl_data, startRow = 2, startCol = 1, colNames = TRUE)
addStyle(wb, "CODELIST REFERENCE", st_hdr_teal, rows = 2, cols = seq_len(ncol(cl_data)), gridExpand = TRUE)
for (i in seq_len(nrow(cl_data))) {
  r <- 2 + i
  s <- if (i %% 2 == 0) st_row_alt else st_row_norm
  addStyle(wb, "CODELIST REFERENCE", s, rows = r, cols = seq_len(ncol(cl_data)), gridExpand = TRUE)
  setRowHeights(wb, "CODELIST REFERENCE", rows = r, heights = 20)
}
setColWidths(wb, "CODELIST REFERENCE", cols = seq_len(ncol(cl_data)), widths = "auto")
freezePane(wb, "CODELIST REFERENCE", firstActiveRow = 3, firstActiveCol = 2)

# ── FORM SHEETS ────────────────────────────────────────────────────────────────

# DM — Demographics
dm_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled by system","Auto-populated from study setup","Y"),
  f(2,"SITEID","Site Identifier","Text","CHAR(10)","","Y","SITEID","Pre-filled by system","Auto-populated from site login","Y"),
  f(3,"SUBJID","Subject Identifier","Text","CHAR(20)","","Y","SUBJID","Alphanumeric; unique per site","Format: SSS-NNN (site code – subject number)","N"),
  f(4,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","System-derived","Auto-generated: STUDYID-SITEID-SUBJID","Y"),
  f(5,"BRTHDTC","Date of Birth","Date","YYYY-MM-DD","","Y","BRTHDTC","Valid date; not in future","Enter full date of birth","N"),
  f(6,"AGE","Age at Screening","Numeric","Integer","","Y","AGE","Auto-calc; range 18–99","Derived from BRTHDTC; display only","Y"),
  f(7,"AGEU","Age Units","Codelist","","YEARS (fixed)","Y","AGEU","Pre-filled: YEARS","Pre-filled","Y"),
  f(8,"SEX","Sex","Codelist","","SEX","Y","SEX","Single select","Select biological sex at birth","N"),
  f(9,"RACE","Race","Codelist","","RACE","Y","RACE","Single select","Select per FDA guidance","N"),
  f(10,"ETHNIC","Ethnicity","Codelist","","ETHNIC","Y","ETHNIC","Single select","Select ethnicity","N"),
  f(11,"COUNTRY","Country","Codelist","","ISO 3166-1 alpha-3","Y","COUNTRY","Pre-filled from site","Auto-populated from site config","Y"),
  f(12,"DMDTC","Date of Assessment","Date","YYYY-MM-DD","","Y","DMDTC","Valid date; within screening window","Date demographics form completed","N")
)
write_form_sheet(wb, "DM — Demographics", "DM", "Demographics",
                 "Screening / Baseline (C1D1)", "DM", dm_fields, "blue")

# DS — Disposition
ds_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"SITEID","Site Identifier","Text","CHAR(10)","","Y","SITEID","Pre-filled","Auto-populated","Y"),
  f(3,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(4,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled per visit","Auto-populated","Y"),
  f(5,"VISIT","Visit Name","Text","CHAR(40)","","Y","VISIT","Pre-filled per visit","Auto-populated","Y"),
  f(6,"DSSCAT","Disposition Category","Codelist","","DS_CATEGORY","Y","DSSCAT","Single select","Select disposition category","N"),
  f(7,"DSTERM","Disposition Term","Text","CHAR(200)","","N","DSTERM","Required if DSSCAT=DISCONTINUED","Describe reason for discontinuation","N"),
  f(8,"DSDECOD","Disposition Decoded","Codelist","","NCOMPLT","Y","DSDECOD","Single select","Select standardised reason","N"),
  f(9,"DSSTDTC","Start Date","Date","YYYY-MM-DD","","Y","DSSTDTC","Valid date; not in future","Date disposition event occurred","N"),
  f(10,"DSENDTC","End Date","Date","YYYY-MM-DD","","N","DSENDTC","Valid date ≥ DSSTDTC","Date disposition event ended","N")
)
write_form_sheet(wb, "DS — Disposition", "DS", "Disposition",
                 "Screening | C1D1 | EOT | All FU visits", "DS", ds_fields, "blue")

# IE — Inclusion/Exclusion
ie_criteria <- c(
  "IN01: Histologically or cytologically confirmed NSCLC (Stage IIIB/IIIC/IV)",
  "IN02: PD-L1 TPS ≥50% (22C3 pharmDx, central lab)",
  "IN03: No sensitising EGFR mutations (exon 19 del, exon 21 L858R, other activating)",
  "IN04: No ALK gene rearrangement",
  "IN05: ECOG Performance Status 0 or 1",
  "IN06: Measurable disease per RECIST 1.1",
  "IN07: Age ≥18 years",
  "IN08: No prior systemic therapy for advanced/metastatic NSCLC",
  "IN09: Adequate organ function (haematology, hepatic, renal per protocol Table 1)",
  "IN10: Life expectancy ≥12 weeks",
  "EX01: Active autoimmune disease requiring systemic treatment (within 2 years)",
  "EX02: Prior anti-PD-1 or anti-PD-L1 therapy",
  "EX03: Active CNS metastases (unless stable ≥4 weeks after treatment)",
  "EX04: Active systemic corticosteroids >10mg/day prednisone equivalent",
  "EX05: Known active hepatitis B or C infection",
  "EX06: Known HIV (unless undetectable viral load on ART)",
  "EX07: Other active malignancy within 2 years (except adequately treated non-melanoma skin cancer)",
  "EX08: Pregnant or breastfeeding",
  "EX09: Prior organ transplant or allogeneic bone marrow transplant",
  "EX10: Any condition that would interfere with study participation"
)
ie_cats <- c(rep("INCLUSION",10), rep("EXCLUSION",10))
ie_fields <- do.call(rbind, lapply(seq_along(ie_criteria), function(i) {
  f(i, "IEORRES", ie_criteria[i], "Codelist", "", "NY",
    "Y", "IEORRES",
    paste0("IE criterion ", substr(ie_criteria[i],1,4), ": all INCLUSION must = Y; all EXCLUSION must = N"),
    paste0("[", ie_cats[i], "] ", ie_criteria[i], " — Select: Y = Met  /  N = Not Met"))
}))
write_form_sheet(wb, "IE — Incl/Excl Criteria", "IE", "Inclusion/Exclusion Criteria",
                 "Screening (Week -4)", "IE", ie_fields, "teal")

# EC — Exposure as Collected
ec_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"ECTRT","Treatment Administered","Codelist","","EC_TREATMENT","Y","ECTRT","Single select","Select: Torivumab 200mg IV or Placebo IV","N"),
  f(5,"ECDOSE","Dose Administered (mg)","Numeric","Decimal(6.1)","","Y","ECDOSE","Range: 0–250 mg","Enter actual dose in mg","N"),
  f(6,"ECDOSU","Dose Units","Codelist","","mg (fixed)","Y","ECDOSU","Fixed: mg","Pre-filled: mg","Y"),
  f(7,"ECDOSFRM","Dose Form","Codelist","","FRM","Y","ECDOSFRM","Fixed: SOLUTION FOR INFUSION","Pre-filled","Y"),
  f(8,"ECDOSFRQ","Dosing Frequency","Codelist","","FREQ","Y","ECDOSFRQ","Fixed: Q3W","Pre-filled: Q3W","Y"),
  f(9,"ECROUTE","Route of Administration","Codelist","","ROUTE","Y","ECROUTE","Fixed: INTRAVENOUS","Pre-filled: INTRAVENOUS","Y"),
  f(10,"ECSTDTC","Infusion Start Date/Time","Datetime","YYYY-MM-DD HH:MM","","Y","ECSTDTC","Valid datetime; within visit window","Enter date and time infusion started","N"),
  f(11,"ECENDTC","Infusion End Date/Time","Datetime","YYYY-MM-DD HH:MM","","Y","ECENDTC","Valid datetime; ≥ ECSTDTC; duration ~30–60 min","Enter date and time infusion completed","N"),
  f(12,"ECMOOD","Mood of Dose","Codelist","","MOOD","Y","ECMOOD","Fixed: PERFORMED","Pre-filled: PERFORMED","Y"),
  f(13,"ECDOSEMOD","Dose Modified?","Codelist","","NY","Y","ECDOSEMOD","Single select; if Y complete ECMODREAS","Was dose modified from 200 mg?","N"),
  f(14,"ECMODREAS","Reason for Dose Modification","Text","CHAR(200)","","N","ECMODREAS","Required if ECDOSEMOD = Y","Describe reason for dose modification or interruption","N")
)
write_form_sheet(wb, "EC — Exposure", "EC", "Exposure as Collected (Dosing)",
                 "All on-treatment visits (Q3W)", "EC", ec_fields, "blue")

# AE — Adverse Events
ae_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"AESTDTC","AE Start Date","Date","YYYY-MM-DD","","Y","AESTDTC","Valid date; ≥ first dose date","Date adverse event first observed or reported","N"),
  f(5,"AEENDTC","AE End Date","Date","YYYY-MM-DD","","N","AEENDTC","Valid date ≥ AESTDTC; blank if ongoing","Date AE resolved; leave blank if still ongoing","N"),
  f(6,"AETERM","AE Term (Verbatim)","Text","CHAR(200)","","Y","AETERM","Free text; max 200 characters","Enter exact term as reported by subject or observed by clinician","N"),
  f(7,"AEDECOD","MedDRA Preferred Term","Codelist","","MEDDRA_PT","Y","AEDECOD","Coded by DM (MedDRA v27.0)","Coded centrally; field locked post-coding","Y"),
  f(8,"AESOC","MedDRA System Organ Class","Codelist","","MEDDRA_SOC","Y","AESOC","Auto-derived from AEDECOD","Auto-populated from MedDRA coding","Y"),
  f(9,"AESEV","Severity","Codelist","","AESEV","Y","AESEV","Single select","Select worst severity during AE episode","N"),
  f(10,"AETOXGR","CTCAE Grade","Codelist","","CTCAE_GRADE","Y","AETOXGR","Single select Grade 1–5; per CTCAE v5.0","Select CTCAE v5.0 grade at worst severity","N"),
  f(11,"AEREL","Relationship to Study Drug","Codelist","","AEREL","Y","AEREL","Single select","Investigator assessment of causal relationship","N"),
  f(12,"AESER","Serious AE?","Codelist","","NY","Y","AESER","Single select; if Y complete SAE form within 24h","Is this a Serious Adverse Event (SAE)?","N"),
  f(13,"AESERCR","SAE Criterion","Codelist","","AESERCR","N","AESERCR","Required if AESER = Y; multi-select allowed","Select all applicable SAE criteria","N"),
  f(14,"AEACN","Action Taken","Codelist","","ACN","Y","AEACN","Single select","Select action taken with study treatment due to this AE","N"),
  f(15,"AEOUT","Outcome","Codelist","","AEOUT","Y","AEOUT","Single select; if AEENDTC blank use RECOVERING or NOT RECOVERED","Select outcome of adverse event at time of form completion","N"),
  f(16,"AEPAT","AE Pattern","Codelist","","AEPAT","N","AEPAT","Optional","Select AE pattern: SINGLE EVENT / INTERMITTENT / CONTINUOUS","N")
)
write_form_sheet(wb, "AE — Adverse Events", "AE", "Adverse Events",
                 "All on-treatment visits + Off-treatment FU", "AE", ae_fields, "orange")

# CM — Concomitant Medications
cm_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"CMTRT","Medication Name (Verbatim)","Text","CHAR(200)","","Y","CMTRT","Free text; max 200 chars","Enter medication name exactly as prescribed","N"),
  f(4,"CMDECOD","WHO Drug Preferred Name","Codelist","","WHO_DRUG","Y","CMDECOD","Coded by DM","Coded centrally; locked post-coding","Y"),
  f(5,"CMCAT","Category","Codelist","","CM_CATEGORY","Y","CMCAT","Single select","PRIOR = stopped before first dose; CONCOMITANT = ongoing","N"),
  f(6,"CMINDC","Indication","Text","CHAR(200)","","Y","CMINDC","Free text","Enter indication for this medication","N"),
  f(7,"CMDOSE","Dose","Numeric","Decimal(8.2)","","N","CMDOSE","Positive number","Enter dose amount if known","N"),
  f(8,"CMDOSU","Dose Units","Codelist","","UNIT","N","CMDOSU","Required if CMDOSE entered","Select units","N"),
  f(9,"CMDOSFRQ","Frequency","Codelist","","FREQ","N","CMDOSFRQ","Optional","Select dosing frequency","N"),
  f(10,"CMROUTE","Route","Codelist","","ROUTE","N","CMROUTE","Optional","Select route of administration","N"),
  f(11,"CMSTDTC","Start Date","Date","YYYY-MM","","Y","CMSTDTC","Valid date; partial acceptable","Date medication started (YYYY or YYYY-MM acceptable)","N"),
  f(12,"CMENDTC","End Date","Date","YYYY-MM","","N","CMENDTC","Valid date ≥ CMSTDTC; blank if ongoing","Date medication stopped; leave blank if still ongoing","N"),
  f(13,"CMENRF","End Relative to Reference","Codelist","","STENRF","N","CMENRF","Optional","Select timing relative to study reference period","N")
)
write_form_sheet(wb, "CM — Concomitant Meds", "CM", "Concomitant Medications",
                 "Baseline (C1D1) + All on-treatment + FU visits", "CM", cm_fields, "blue")

# MH — Medical History
mh_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"MHTERM","Medical History Term (Verbatim)","Text","CHAR(200)","","Y","MHTERM","Free text; max 200 chars","Enter condition or disease as reported","N"),
  f(4,"MHDECOD","MedDRA Preferred Term","Codelist","","MEDDRA_PT","Y","MHDECOD","Coded by DM (MedDRA v27.0)","Coded centrally; locked post-coding","Y"),
  f(5,"MHCAT","Category","Codelist","","MH_CATEGORY","Y","MHCAT","Single select","Select: ONCOLOGY HISTORY or GENERAL MEDICAL HISTORY","N"),
  f(6,"MHSCAT","Subcategory","Codelist","","MH_SUBCATEGORY","N","MHSCAT","Optional","Select subcategory (e.g. PRIOR ANTICANCER THERAPY)","N"),
  f(7,"MHSTDTC","Start Date","Date","YYYY","","N","MHSTDTC","Partial date acceptable","Year (and month if known) condition started","N"),
  f(8,"MHENDTC","End Date","Date","YYYY","","N","MHENDTC","Valid date ≥ MHSTDTC; blank if ongoing","Year condition resolved; leave blank if ongoing","N"),
  f(9,"MHENRF","End Relative to Reference","Codelist","","STENRF","Y","MHENRF","Single select","BEFORE = resolved before study; ONGOING = active at study start","N")
)
write_form_sheet(wb, "MH — Medical History", "MH", "Medical History",
                 "Screening / Baseline (C1D1)", "MH", mh_fields, "blue")

# SU — Substance Use
su_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"SUCAT","Substance Category","Codelist","","SUCAT","Y","SUCAT","Fixed: TOBACCO","Pre-filled: TOBACCO","Y"),
  f(4,"SUOCCUR","Substance Use Occurrence","Codelist","","NY","Y","SUOCCUR","Single select","Has the subject ever used tobacco products?","N"),
  f(5,"SUDOSFRQ","Frequency of Use","Codelist","","FREQ_SU","N","SUDOSFRQ","Required if SUOCCUR = Y","Select frequency: DAILY / OCCASIONALLY / NEVER","N"),
  f(6,"SUENRF","End Relative to Reference","Codelist","","STENRF","N","SUENRF","Required if SUOCCUR = Y","BEFORE = former smoker; ONGOING = current smoker","N"),
  f(7,"SUSTDTC","Start Date of Use","Date","YYYY","","N","SUSTDTC","Partial date (YYYY); required if SUOCCUR = Y","Year tobacco use started","N"),
  f(8,"SUENDTC","End Date of Use","Date","YYYY","","N","SUENDTC","Required if SUENRF = BEFORE","Year tobacco use stopped","N")
)
write_form_sheet(wb, "SU — Substance Use", "SU", "Substance Use (Tobacco)",
                 "Screening / Baseline (C1D1)", "SU", su_fields, "blue")

# VS — Vital Signs
vs_tests <- data.frame(
  test_code = c("SYSBP","DIABP","PULSE","TEMP","RESP","WEIGHT","HEIGHT","BSA"),
  test_name = c("Systolic Blood Pressure","Diastolic Blood Pressure","Pulse Rate",
                "Temperature","Respiratory Rate","Body Weight","Body Height","Body Surface Area"),
  units     = c("mmHg","mmHg","beats/min","degrees C","breaths/min","kg","cm","m2"),
  range     = c("60–250","40–150","30–200","34.0–42.0","6–40","30–250","100–220","0.5–3.0"),
  visits    = c("All","All","All","All","All","All","Screening only","Screening only"),
  stringsAsFactors = FALSE
)
vs_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"VSDTC","Date/Time of Measurement","Datetime","YYYY-MM-DD HH:MM","","Y","VSDTC","Valid datetime; within visit window","Date and time vital signs measured","N")
)
for (i in seq_len(nrow(vs_tests))) {
  vs_fields <- rbind(vs_fields,
    f(4 + i,
      vs_tests$test_code[i],
      paste0(vs_tests$test_name[i], " (", vs_tests$units[i], ")"),
      "Numeric","Decimal(6.1)","VS_TEST",
      "Y", "VSORRES",
      paste0("Range: ", vs_tests$range[i], "; Units: ", vs_tests$units[i]),
      paste0("Enter ", vs_tests$test_name[i], " in ", vs_tests$units[i],
             if (vs_tests$visits[i] != "All") paste0(" — ", vs_tests$visits[i], " ONLY") else ""),
      "N"
    )
  )
}
vs_fields <- rbind(vs_fields,
  f(13,"VSPOS","Position (for BP)","Codelist","","POSITION","N","VSPOS","Required for BP measurements","Select subject position","N"))
write_form_sheet(wb, "VS — Vital Signs", "VS", "Vital Signs",
                 "All visits", "VS", vs_fields, "teal")

# LB — Laboratory (Clinical)
lb_clinical <- data.frame(
  code = c("HGB","WBC","NEUT","LYMPH","PLT","ALT","AST","ALKPH","BILI","CREAT","SODIUM","POTASS","ALBUMIN","TSH","GLUC"),
  name = c("Haemoglobin","White Blood Cell Count","Neutrophils (Absolute)","Lymphocytes (Absolute)",
           "Platelet Count","Alanine Aminotransferase","Aspartate Aminotransferase","Alkaline Phosphatase",
           "Total Bilirubin","Creatinine","Sodium","Potassium","Albumin","TSH","Glucose (Fasting)"),
  units = c("g/dL","10^9/L","10^9/L","10^9/L","10^9/L","U/L","U/L","U/L","umol/L","umol/L","mmol/L","mmol/L","g/L","mIU/L","mmol/L"),
  panel = c(rep("Haematology",5), rep("Chemistry",10)),
  stringsAsFactors = FALSE
)
lb_biomarkers <- data.frame(
  code  = c("PD-L1_TPS","EGFR_MUT","ALK_REARR","ROS1_REARR","KRAS_G12C","MET_EX14","RET_REARR","BRAF_V600E","NTRK_FUSE","TMB"),
  name  = c("PD-L1 Tumour Proportion Score","EGFR Mutation Status","ALK Rearrangement",
            "ROS1 Rearrangement","KRAS G12C Mutation","MET Exon 14 Skipping",
            "RET Rearrangement","BRAF V600E Mutation","NTRK Gene Fusion","Tumour Mutational Burden"),
  dtype = c("Numeric","Codelist","Codelist","Codelist","Codelist","Codelist","Codelist","Codelist","Codelist","Numeric"),
  stringsAsFactors = FALSE
)
lb_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"LBDTC","Date/Time of Collection","Datetime","YYYY-MM-DD HH:MM","","Y","LBDTC","Valid datetime; within visit window","Date and time sample collected","N")
)
# Clinical panel header
lb_fields <- rbind(lb_fields, f(5,"","── CLINICAL LABORATORY PANEL ──","","","","","","","","N"))
for (i in seq_len(nrow(lb_clinical))) {
  lb_fields <- rbind(lb_fields,
    f(5 + i, lb_clinical$code[i],
      paste0(lb_clinical$name[i], " (", lb_clinical$units[i], ") [", lb_clinical$panel[i], "]"),
      "Numeric","Decimal(8.3)","NRIND",
      "Y", "LBORRES",
      paste0("Enter numeric result; flag out-of-range; units: ", lb_clinical$units[i]),
      paste0("Enter ", lb_clinical$name[i], " as reported by laboratory in ", lb_clinical$units[i]),
      "N"))
}
# Biomarker panel header
lb_fields <- rbind(lb_fields, f(21,"","── BASELINE BIOMARKER PANEL (Screening/C1D1 only) ──","","","","","","","Collect tissue/blood as specified in protocol","N"))
for (i in seq_len(nrow(lb_biomarkers))) {
  lb_fields <- rbind(lb_fields,
    f(21 + i, lb_biomarkers$code[i],
      lb_biomarkers$name[i],
      lb_biomarkers$dtype[i],
      if (lb_biomarkers$code[i] %in% c("PD-L1_TPS","TMB")) "Decimal(6.2)" else "",
      if (lb_biomarkers$dtype[i] == "Codelist") "LB_BIOMARKER_CAT" else "",
      "Y", "LBORRES",
      paste0("Central lab result; ",
        if (lb_biomarkers$code[i] == "PD-L1_TPS") "≥50% = eligible (ELIGIBILITY CRITERION)" else
        if (lb_biomarkers$code[i] %in% c("EGFR_MUT","ALK_REARR")) "Presence = exclusion (EXCLUSION CRITERION)" else
        "Required; not exclusion criterion"),
      paste0("Enter result from central laboratory for ", lb_biomarkers$name[i]),
      "N"))
}
write_form_sheet(wb, "LB — Lab Results", "LB", "Laboratory Test Results (Clinical + Biomarkers)",
                 "Screening | C1D1 | End-of-Cycle | EOT", "LB", lb_fields, "teal")

# PE — Physical Examination
pe_systems <- c("GENERAL APPEARANCE","RESPIRATORY","CARDIOVASCULAR","GASTROINTESTINAL",
                "NEUROLOGICAL","DERMATOLOGICAL","MUSCULOSKELETAL","LYMPH NODES","ECOG PS")
pe_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"PEDTC","Date of Examination","Date","YYYY-MM-DD","","Y","PEDTC","Valid date; within visit window","Date physical examination performed","N")
)
for (i in seq_along(pe_systems)) {
  if (pe_systems[i] == "ECOG PS") {
    pe_fields <- rbind(pe_fields,
      f(4 + i, "PEORRES", "ECOG Performance Status", "Codelist", "", "ECOG",
        "Y", "PEORRES",
        "Required; ECOG 0 or 1 for eligibility at screening",
        "Select ECOG PS: 0=Fully active; 1=Restricted strenuous activity; 2-4=see ECOG scale", "N"))
  } else {
    pe_fields <- rbind(pe_fields,
      f(4 + i, "PEORRES", paste0(pe_systems[i], " — Finding"), "Codelist", "", "PE_RESULT",
        "Y", "PEORRES",
        "Single select; if ABNORMAL CS complete free text",
        paste0("Select: NORMAL / ABNORMAL NCS / ABNORMAL CS for ", pe_systems[i]), "N"))
  }
}
write_form_sheet(wb, "PE — Physical Exam", "PE", "Physical Examination",
                 "Screening | Baseline (C1D1) | EOT", "PE", pe_fields, "teal")

# DA — Drug Accountability
da_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"DATRT","Treatment Name","Codelist","","DA_TREATMENT","Y","DATRT","Single select","Select study drug","N"),
  f(5,"DATEST","Accountability Test","Codelist","","DA_TEST","Y","DATEST","Single select","Select: DISPENSED or RETURNED","N"),
  f(6,"DAORRES","Quantity","Numeric","Decimal(6.1)","","Y","DAORRES","Positive number","Enter quantity in units specified","N"),
  f(7,"DAORRESU","Units","Codelist","","UNIT","Y","DAORRESU","Single select","Select: mL or vials","N"),
  f(8,"DASTDTC","Date of Dispensing","Date","YYYY-MM-DD","","Y","DASTDTC","Valid date; within visit window","Date study drug dispensed or returned","N"),
  f(9,"DACOMM","Comments","Text","CHAR(200)","","N","DACOMM","Optional","Enter any relevant comments","N")
)
write_form_sheet(wb, "DA — Drug Accountability", "DA", "Drug Accountability",
                 "Baseline (C1D1) | EOT", "DA", da_fields, "blue")

# DD — Death Details
dd_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"DDDTC","Date of Death","Date","YYYY-MM-DD","","Y","DDDTC","Valid date; ≥ first dose; not in future","Date of subject death","N"),
  f(4,"DDORRES","Primary Cause of Death","Text","CHAR(200)","","Y","DDORRES","Free text; describe primary cause","Enter primary cause as determined by investigator","N"),
  f(5,"DDORRES","Contributing Cause of Death","Text","CHAR(200)","","N","DDORRES","Free text; secondary contributing cause","Enter contributing cause if applicable","N"),
  f(6,"DDORRES","Death Related to Study Drug?","Codelist","","AEREL","Y","DDORRES","Single select","Investigator causal assessment for death vs study drug","N"),
  f(7,"DDORRES","Autopsy Performed?","Codelist","","NY","N","DDORRES","Single select","Was an autopsy performed?","N")
)
write_form_sheet(wb, "DD — Death Details", "DD", "Death Details",
                 "Post-mortem (if applicable)", "DD", dd_fields, "orange")

# TU — Tumour Identification
tu_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"TUSEQ","Lesion Sequence Number","Numeric","Integer","","Y","TUSEQ","Auto-incremented; unique per subject","System-assigned; do not edit","Y"),
  f(4,"TUDTC","Date of Baseline Assessment","Date","YYYY-MM-DD","","Y","TUDTC","Valid date; within imaging visit window","Date baseline tumour identification performed","N"),
  f(5,"TUMETHOD","Assessment Method","Codelist","","TU_METHOD","Y","TUMETHOD","CT or MRI; must be consistent throughout study","Select imaging modality; document if method changes","N"),
  f(6,"TUORRES","Lesion Type","Codelist","","TU_LESTYPE","Y","TUORRES","TARGET: measurable ≥10mm (≥15mm lymph node); max 5 total; max 2 per organ; NON-TARGET: document all","Select: TARGET or NON-TARGET (NEW only at post-baseline visits)","N"),
  f(7,"TULOC","Lesion Location (Anatomic)","Codelist","","LOCLOINC","Y","TULOC","Single select per lesion","Select primary anatomic location","N"),
  f(8,"TULOCOT","Other Location (Text)","Text","CHAR(200)","","N","TULOCOT","Required if TULOC = OTHER","Describe location if OTHER selected","N"),
  f(9,"TULAT","Laterality","Codelist","","LAT","N","TULAT","Required for bilateral anatomy","Select: LEFT / RIGHT / BILATERAL","N"),
  f(10,"TUREF","Lesion Reference","Text","CHAR(50)","","N","TUREF","Optional; free text","Enter descriptive reference (e.g. 'Right upper lobe mass')","N")
)
write_form_sheet(wb, "TU — Tumour Identification", "TU", "Tumour Identification (RECIST 1.1)",
                 "Baseline Imaging Visit (IMG01 / Week 6)", "TU", tu_fields, "green")

# TR — Tumour Results
tr_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"TRSEQ","Sequence Number","Numeric","Integer","","Y","TRSEQ","Auto-incremented","System-assigned; do not edit","Y"),
  f(5,"TRLNKID","Link to TU Sequence","Text","CHAR(10)","","Y","TRLNKID","References TUSEQ from TU form","Enter TU sequence number for this lesion","N"),
  f(6,"TRDTC","Date of Assessment","Date","YYYY-MM-DD","","Y","TRDTC","Valid date; within imaging visit window","Date tumour measurement performed","N"),
  f(7,"TRTESTCD","Measurement Test","Codelist","","TR_TEST","Y","TRTESTCD","Single select","Select: LDIAM (target lesions) or LPERP (lymph node short axis)","N"),
  f(8,"TRORRES","Measurement (mm)","Numeric","Decimal(5.1)","","Y","TRORRES","Range: 0–500 mm; 0 = complete resolution","Enter longest diameter in millimetres; 0 if fully resolved","N"),
  f(9,"TRORRESU","Units","Codelist","","mm (fixed)","Y","TRORRESU","Fixed: mm","Pre-filled: mm","Y"),
  f(10,"TRSTAT","Completion Status","Codelist","","ND","N","TRSTAT","Select NOT DONE if measurement not performed","Complete if lesion not measurable at this visit","N"),
  f(11,"TRREASND","Reason Not Done","Text","CHAR(200)","","N","TRREASND","Required if TRSTAT = NOT DONE","Describe reason measurement not performed","N"),
  f(12,"TRCOMM","Comments","Text","CHAR(200)","","N","TRCOMM","Optional","Enter any relevant measurement comments","N")
)
write_form_sheet(wb, "TR — Tumour Results", "TR", "Tumour Results — Lesion Measurements (RECIST 1.1)",
                 "All imaging visits: IMG01 Q6W→Wk18, then Q12W", "TR", tr_fields, "green")

# RS — Disease Response
rs_fields <- rbind(
  f(1,"STUDYID","Study Identifier","Text","CHAR(20)","","Y","STUDYID","Pre-filled","Auto-populated","Y"),
  f(2,"USUBJID","Unique Subject ID","Text","CHAR(40)","","Y","USUBJID","Pre-filled","Auto-populated","Y"),
  f(3,"VISITNUM","Visit Number","Numeric","Integer","","Y","VISITNUM","Pre-filled","Auto-populated","Y"),
  f(4,"RSSEQ","Sequence Number","Numeric","Integer","","Y","RSSEQ","Auto-incremented","System-assigned; do not edit","Y"),
  f(5,"RSDTC","Date of Assessment","Date","YYYY-MM-DD","","Y","RSDTC","Valid date; matches TRDTC","Date overall response assessment performed","N"),
  f(6,"RSTESTCD","Response Test Code","Codelist","","RS_TEST","Y","RSTESTCD","Fixed: OVRLRESP","Pre-filled: OVRLRESP","Y"),
  f(7,"RSTEST","Response Test Name","Codelist","","RS_TEST","Y","RSTEST","Fixed: Overall Response","Pre-filled: Overall Response","Y"),
  f(8,"RSCAT","Response Category","Codelist","","RS_CATEGORY","Y","RSCAT","Fixed: RECIST 1.1","Pre-filled: RECIST 1.1","Y"),
  f(9,"RSORRES","Overall Response","Codelist","","RECIST_RESP","Y","RSORRES",
    "CR: all lesions disappeared; PR: ≥30% decrease; SD: neither; PD: ≥20% increase OR new lesions; NE: not evaluable",
    "Select overall RECIST 1.1 response based on all target + non-target lesions + new lesions","N"),
  f(10,"RSNEWLES","New Lesions Present?","Codelist","","NY","Y","RSNEWLES","If Y → response must be PD","Confirm whether any new lesions identified at this assessment","N"),
  f(11,"RSEVAL","Evaluator","Codelist","","EVAL","Y","RSEVAL","Single select","Select: INVESTIGATOR or INDEPENDENT ASSESSOR (BICR)","N"),
  f(12,"RSCOMM","Assessment Comments","Text","CHAR(200)","","N","RSCOMM","Optional","Enter clinical context for response determination","N")
)
write_form_sheet(wb, "RS — Disease Response", "RS", "Disease Response — Overall Assessment (RECIST 1.1)",
                 "All imaging visits: Q6W→Wk18, then Q12W", "RS", rs_fields, "green")

# ── SDTM MAPPING SUMMARY ───────────────────────────────────────────────────────
addWorksheet(wb, "SDTM MAPPING", tabColour = "#375623")
sdtm_map <- data.frame(
  CDASH_Domain = c("DM","DS","IE","EC","DA","AE","CM","MH","SU","VS","LB","LB","PE","DD","TU","TR","RS"),
  CDASH_Form   = c("Demographics","Disposition","Incl/Excl","Exposure","Drug Accountability",
                   "Adverse Events","Concomitant Meds","Medical History","Substance Use",
                   "Vital Signs","Lab Results (Clinical)","Lab Results (Biomarkers)","Physical Exam",
                   "Death Details","Tumour Identification","Tumour Results","Disease Response"),
  SDTM_Domain  = c("DM","DS","IE","EC","DA","AE","CM","MH","SU","VS","LB","LB","PE","DD","TU","TR","RS"),
  Key_Variables = c(
    "STUDYID,SITEID,SUBJID,USUBJID,AGE,SEX,RACE,ETHNIC,COUNTRY,ARM,ACTARM",
    "STUDYID,USUBJID,DSSCAT,DSTERM,DSDECOD,DSSTDTC,DSENDTC",
    "STUDYID,USUBJID,IETESTCD,IETEST,IECAT,IEORRES",
    "STUDYID,USUBJID,ECTRT,ECDOSE,ECDOSU,ECSTDTC,ECENDTC,ECROUTE,ECMOOD",
    "STUDYID,USUBJID,DATRT,DATEST,DAORRES,DAORRESU,DASTDTC",
    "STUDYID,USUBJID,AESTDTC,AETERM,AEDECOD,AESOC,AESEV,AETOXGR,AEREL,AESER,AEACN,AEOUT",
    "STUDYID,USUBJID,CMTRT,CMDECOD,CMCAT,CMINDC,CMSTDTC,CMENDTC",
    "STUDYID,USUBJID,MHTERM,MHDECOD,MHCAT,MHSTDTC,MHENDTC,MHENRF",
    "STUDYID,USUBJID,SUCAT,SUOCCUR,SUDOSFRQ,SUENRF,SUSTDTC",
    "STUDYID,USUBJID,VSTESTCD,VSTEST,VSORRES,VSORRESU,VSPOS,VSDTC",
    "STUDYID,USUBJID,LBTESTCD,LBTEST,LBORRES,LBORRESU,LBORNRLO,LBORNRHI,LBNRIND,LBDTC",
    "STUDYID,USUBJID,LBTESTCD(PD-L1_TPS etc),LBORRES,LBSTRESC,LBSPEC,LBMETHOD,LBDTC",
    "STUDYID,USUBJID,PETEST,PEORRES,PESTRESC,PEDTC",
    "STUDYID,USUBJID,DDDTC,DDORRES(cause/relationship)",
    "STUDYID,USUBJID,TUSEQ,TUORRES,TULOC,TUMETHOD,TUDTC",
    "STUDYID,USUBJID,TRSEQ,TRLNKID,TRTESTCD,TRORRES,TRORRESU,TRDTC",
    "STUDYID,USUBJID,RSSEQ,RSTESTCD,RSTEST,RSCAT,RSORRES,RSSTRESC,RSEVAL,RSDTC"
  ),
  ADaM_Target  = c("ADSL","ADSL","ADSL","ADEX","ADSL","ADAE","ADCM","ADSL","ADSL","ADVS","ADLB","ADLB","ADSL","ADTTE","ADTR","ADTR","ADRS"),
  stringsAsFactors = FALSE
)
writeData(wb, "SDTM MAPPING", x = data.frame(A = "SDTM/ADaM MAPPING SUMMARY — CDASH → SDTM → ADaM"),
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "SDTM MAPPING", st_cover_title, rows = 1, cols = 1:5, gridExpand = TRUE)
mergeCells(wb, "SDTM MAPPING", cols = 1:5, rows = 1)
setRowHeights(wb, "SDTM MAPPING", rows = 1, heights = 28)
writeData(wb, "SDTM MAPPING", x = sdtm_map, startRow = 2, startCol = 1)
addStyle(wb, "SDTM MAPPING", st_hdr_green, rows = 2, cols = 1:5, gridExpand = TRUE)
for (i in seq_len(nrow(sdtm_map))) {
  r <- 2 + i
  s <- if (i %% 2 == 0) st_row_alt else st_row_norm
  addStyle(wb, "SDTM MAPPING", s, rows = r, cols = 1:5, gridExpand = TRUE)
  setRowHeights(wb, "SDTM MAPPING", rows = r, heights = 24)
}
setColWidths(wb, "SDTM MAPPING", cols = 1:5, widths = c(14, 26, 14, 65, 12))
freezePane(wb, "SDTM MAPPING", firstActiveRow = 3, firstActiveCol = 2)

# ── SAVE ──────────────────────────────────────────────────────────────────────
out_path <- "/home/ubuntu/.openclaw/workspace/torivumab-nsclc-301/crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx"
saveWorkbook(wb, out_path, overwrite = TRUE)
cat("CRF workbook saved:", out_path, "\n")
cat("Sheets:", paste(names(wb), collapse = " | "), "\n")
