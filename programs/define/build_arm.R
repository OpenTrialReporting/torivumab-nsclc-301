# =============================================================================
# Program    : programs/define/build_arm.R
# Purpose    : Build the v0.1 Analysis Results Metadata (ARM) file
#              `define/arm.xml` for the 43 TFL outputs defined in
#              `sap/shells/shells.yaml`.
#
# Scope (v0.1):
#   - One arm:ResultDisplay per output (43 total).
#   - One arm:AnalysisResult per display carrying:
#       * Reason, Purpose, ParameterOID(s)
#       * AnalysisDatasets / AnalysisVariable references (symbolic — matches
#         the IG.<DS> / IT.<DS>.<VAR> naming used by `build_define.R`)
#       * Documentation (SAP cross-reference + methods list)
#       * ProgrammingCode (R; file reference to programs/tfl/<id>_*.R)
#   - def:leaf entries for the TFL output document and the R program.
#   - WhereClause refinement (e.g. PARAMCD='OS') is deferred to v0.2; v0.1
#     emits ParameterOID and leaves analysis-set semantics in Documentation.
#
# Run from   : Project root
# Usage      : Rscript programs/define/build_arm.R
# Output     : define/arm.xml
# =============================================================================

suppressPackageStartupMessages({
  library(yaml)
})

SHELLS_PATH <- "sap/shells/shells.yaml"
OUT_PATH    <- "define/arm.xml"
TODAY_TS    <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
FILE_TS     <- format(Sys.time(), "%Y%m%d%H%M%S")

STUDY_OID    <- "cdisc.TORIVUMAB-NSCLC-301"
STUDY_NAME   <- "SIMULATED-TORIVUMAB-2026"
STUDY_DESC   <- "Torivumab + Chemotherapy vs Placebo + Chemotherapy in 1L Advanced NSCLC"
PROTOCOL     <- "TORIVUMAB-NSCLC-301"
ORIGINATOR   <- "Celindra Therapeutics (fictional)"

shells <- yaml::read_yaml(SHELLS_PATH)
outputs <- shells$outputs
stopifnot(length(outputs) > 0)

# --- helpers ---------------------------------------------------------------
esc <- function(s) {
  if (is.null(s) || (is.character(s) && length(s) == 1 && is.na(s))) return("")
  s <- as.character(s)
  s <- gsub("&", "&amp;",  s, fixed = TRUE)
  s <- gsub("<", "&lt;",   s, fixed = TRUE)
  s <- gsub(">", "&gt;",   s, fixed = TRUE)
  s <- gsub('"', "&quot;", s, fixed = TRUE)
  s
}
trans <- function(text) {
  sprintf('<Description><TranslatedText xml:lang="en">%s</TranslatedText></Description>',
          esc(text))
}

# Map output id (e.g. "T-EFF-01") to its R script under programs/tfl/.
# Convention: lowercase + dashes-to-underscores prefix, then first matching
# file. Returns NA if none found.
find_program_script <- function(id) {
  stub <- tolower(gsub("-", "_", id))
  hits <- list.files("programs/tfl",
                      pattern = paste0("^", stub, "(_|\\.).*\\.R$"),
                      ignore.case = TRUE,
                      full.names = FALSE)
  if (length(hits) == 0) NA_character_ else hits[1]
}

# Map output id to its primary TFL document path under tfl/.
tfl_doc_path <- function(o) {
  switch(o$kind,
    "table"   = file.path("..", "tfl", "tables",  paste0(o$id, ".html")),
    "listing" = file.path("..", "tfl", "tables",  paste0(o$id, ".html")),
    "figure"  = file.path("..", "tfl", "figures", paste0(o$id, ".png")),
    file.path("..", "tfl", paste0(o$id, ".html"))
  )
}

# --- emit one arm:ResultDisplay --------------------------------------------
emit_result_display <- function(o) {
  rd_oid <- sprintf("RD.%s", o$id)
  ar_oid <- sprintf("AR.%s", o$id)
  leaf_doc <- sprintf("LF.%s.OUTPUT", o$id)
  leaf_pgm <- sprintf("LF.%s.PROGRAM", o$id)

  # AnalysisDatasets — one block per source_datasets entry; in v0.1 attach
  # key_variables to the first dataset (proper per-dataset attribution is
  # deferred to v0.2 because shells.yaml doesn't carry that mapping).
  ds <- o$source_datasets %||% character(0)
  kv <- o$key_variables  %||% character(0)
  ds_blocks <- vapply(seq_along(ds), function(j) {
    vars <- if (j == 1L) kv else character(0)
    var_xml <- if (length(vars) == 0) "" else {
      paste(sprintf('          <arm:AnalysisVariable ItemOID="IT.%s.%s"/>',
                     ds[j], vars),
            collapse = "\n")
    }
    paste0(
      sprintf('        <arm:AnalysisDataset ItemGroupOID="IG.%s">', ds[j]),
      if (nzchar(var_xml)) paste0("\n", var_xml) else "",
      "\n        </arm:AnalysisDataset>"
    )
  }, character(1))
  ads_block <- if (length(ds_blocks) == 0) "" else paste0(
    "      <arm:AnalysisDatasets>\n",
    paste(ds_blocks, collapse = "\n"), "\n",
    "      </arm:AnalysisDatasets>"
  )

  # ParameterOIDs
  pcodes <- o$parameter_codes %||% character(0)
  param_block <- if (length(pcodes) == 0) "" else paste(
    sprintf("      <arm:ParameterOID>%s</arm:ParameterOID>", esc(pcodes)),
    collapse = "\n"
  )

  # Documentation — SAP ref + methods list (cross-refs only)
  methods_str <- paste(o$methods %||% character(0), collapse = ", ")
  doc_text <- paste0(
    sprintf("Analysis set: %s. ", o$analysis_set %||% ""),
    sprintf("SAP %s. ", o$sap_ref %||% ""),
    if (nzchar(methods_str)) sprintf("Methods: %s.", methods_str) else ""
  )
  doc_block <- paste0(
    "      <arm:Documentation>\n",
    "        ", trans(doc_text), "\n",
    "      </arm:Documentation>"
  )

  # Programming code
  pgm <- find_program_script(o$id)
  if (is.na(pgm)) {
    pgm_block <- ""
    leaf_pgm_xml <- ""
  } else {
    pgm_path_rel <- file.path("..", "programs", "tfl", pgm)
    pgm_code <- sprintf("Rscript programs/tfl/%s", pgm)
    pgm_block <- paste0(
      "      <arm:ProgrammingCode>\n",
      "        <arm:Context>R</arm:Context>\n",
      sprintf("        <arm:Code>%s</arm:Code>\n", esc(pgm_code)),
      sprintf('        <def:DocumentRef leafID="%s"/>\n', leaf_pgm),
      "      </arm:ProgrammingCode>"
    )
    leaf_pgm_xml <- sprintf(
      '<def:leaf ID="%s" xlink:href="%s"><def:title>programs/tfl/%s</def:title></def:leaf>',
      leaf_pgm, esc(pgm_path_rel), esc(pgm)
    )
  }

  rd_xml <- paste0(
    sprintf('    <arm:ResultDisplay OID="%s" Name="%s">', rd_oid, esc(o$id)), "\n",
    "      ", trans(o$title %||% o$id), "\n",
    sprintf('      <def:DocumentRef leafID="%s"/>', leaf_doc), "\n",
    sprintf('      <arm:AnalysisResult OID="%s">', ar_oid), "\n",
    "      ", trans(paste0(o$title %||% o$id,
                          if (!is.null(o$analysis_set))
                            paste0(" — ", o$analysis_set, " Population") else "")), "\n",
    if (nzchar(param_block)) paste0(param_block, "\n") else "",
    sprintf("      <arm:AnalysisReason>%s</arm:AnalysisReason>",  esc(o$reason  %||% "")), "\n",
    sprintf("      <arm:AnalysisPurpose>%s</arm:AnalysisPurpose>", esc(o$purpose %||% "")), "\n",
    if (nzchar(ads_block)) paste0(ads_block, "\n") else "",
    doc_block, "\n",
    if (nzchar(pgm_block)) paste0(pgm_block, "\n") else "",
    "      </arm:AnalysisResult>\n",
    "    </arm:ResultDisplay>"
  )

  doc_path <- tfl_doc_path(o)
  leaf_doc_xml <- sprintf(
    '<def:leaf ID="%s" xlink:href="%s"><def:title>%s</def:title></def:leaf>',
    leaf_doc, esc(doc_path), esc(paste(o$id, "—", o$title %||% ""))
  )

  list(rd_xml = rd_xml, leaves = c(leaf_doc_xml, leaf_pgm_xml))
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

# --- assemble file ---------------------------------------------------------
emitted <- lapply(outputs, emit_result_display)
rd_xml_all     <- vapply(emitted, function(x) x$rd_xml, character(1))
leaves_xml_all <- unlist(lapply(emitted, function(x) x$leaves), use.names = FALSE)
leaves_xml_all <- leaves_xml_all[nzchar(leaves_xml_all)]

xml <- c(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<ODM xmlns="http://www.cdisc.org/ns/odm/v1.3"',
  '     xmlns:def="http://www.cdisc.org/ns/def/v2.1"',
  '     xmlns:arm="http://www.cdisc.org/ns/arm/v1.0"',
  '     xmlns:xlink="http://www.w3.org/1999/xlink"',
  '     ODMVersion="1.3.2"',
  '     FileType="Snapshot"',
  sprintf('     FileOID="%s.arm.%s"', STUDY_OID, FILE_TS),
  sprintf('     CreationDateTime="%s"', TODAY_TS),
  sprintf('     AsOfDateTime="%s"',     TODAY_TS),
  sprintf('     Originator="%s"',       esc(ORIGINATOR)),
  '     def:Context="Submission">',
  sprintf('  <Study OID="%s">', STUDY_OID),
  '    <GlobalVariables>',
  sprintf('      <StudyName>%s</StudyName>',               esc(STUDY_NAME)),
  sprintf('      <StudyDescription>%s</StudyDescription>', esc(STUDY_DESC)),
  sprintf('      <ProtocolName>%s</ProtocolName>',         esc(PROTOCOL)),
  '    </GlobalVariables>',
  '    <MetaDataVersion OID="MDV.ARM.0.1" Name="ARM v0.1"',
  '                     Description="Analysis Results Metadata (ARM) v0.1 — Phase 6a pilot"',
  '                     def:DefineVersion="2.1.0">',
  '    <arm:AnalysisResultDisplays>',
  paste(rd_xml_all, collapse = "\n"),
  '    </arm:AnalysisResultDisplays>',
  paste(paste0("    ", leaves_xml_all), collapse = "\n"),
  '    </MetaDataVersion>',
  '  </Study>',
  '</ODM>'
)

dir.create(dirname(OUT_PATH), showWarnings = FALSE, recursive = TRUE)
writeLines(xml, OUT_PATH)
cat(sprintf("Wrote %s (%d ResultDisplays, %d leaves)\n",
            OUT_PATH, length(rd_xml_all), length(leaves_xml_all)))
