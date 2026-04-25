#!/usr/bin/env Rscript
# =============================================================================
#  tfl/render_shells.R — YAML → Markdown generator for TFL shells
# =============================================================================
#
#  Reads tfl/shells.yaml and writes tfl/TFL-SHELLS.md.
#  Run with:
#      Rscript tfl/render_shells.R
#
#  NEVER edit tfl/TFL-SHELLS.md by hand. Edit shells.yaml and re-render.
# =============================================================================

suppressMessages({
  library(yaml)
})

yaml_path <- "tfl/shells.yaml"
md_path   <- "tfl/TFL-SHELLS.md"

if (!file.exists(yaml_path)) stop("Missing ", yaml_path)
shells <- read_yaml(yaml_path)

## -----------------------------------------------------------------------------
## Helpers

bullet_list <- function(x) {
  if (length(x) == 0) return("—")
  paste0("`", x, "`", collapse = ", ")
}

mk_ids <- function(x) {
  if (length(x) == 0) return("—")
  paste(x, collapse = ", ")
}

## Lookup helper: find an item in a list-of-lists by id
find_by_id <- function(lst, id) {
  for (item in lst) if (!is.null(item$id) && item$id == id) return(item)
  NULL
}

analysis_set_label <- function(id) {
  a <- find_by_id(shells$analysis_sets, id)
  if (is.null(a)) return(id)
  paste0(a$label, " (", id, ")")
}

method_label <- function(id) {
  m <- find_by_id(shells$methods, id)
  if (is.null(m)) return(id)
  paste0(m$name, " [", id, "]")
}

refdoc_label <- function(id) {
  r <- find_by_id(shells$reference_documents, id)
  if (is.null(r)) return(id)
  paste0("[", r$title, "](../", r$path, ")")
}

render_output <- function(o, level = 4) {
  h <- paste(rep("#", level), collapse = "")
  md <- c()
  md <- c(md, sprintf("%s %s — %s", h, o$id, o$title))
  md <- c(md, "")
  md <- c(md, "| Field | Value |")
  md <- c(md, "|---|---|")
  md <- c(md, sprintf("| **Kind** | %s |", o$kind))
  md <- c(md, sprintf("| **Analysis set** | %s |", analysis_set_label(o$analysis_set)))
  md <- c(md, sprintf("| **Source datasets** | %s |", bullet_list(o$source_datasets)))
  if (length(o$parameter_codes) > 0)
    md <- c(md, sprintf("| **Parameter codes** | %s |", bullet_list(o$parameter_codes)))
  md <- c(md, sprintf("| **Key variables** | %s |", bullet_list(o$key_variables)))
  if (length(o$methods) > 0) {
    m_labels <- vapply(o$methods, method_label, character(1))
    md <- c(md, sprintf("| **Methods** | %s |", paste(m_labels, collapse = "; ")))
  }
  md <- c(md, sprintf("| **SAP reference** | %s |", o$sap_ref %||% "—"))
  if (length(o$reference_documents) > 0) {
    r_labels <- vapply(o$reference_documents, refdoc_label, character(1))
    md <- c(md, sprintf("| **Reference documents** | %s |", paste(r_labels, collapse = ", ")))
  }
  if (!is.null(o$layout)) {
    for (k in names(o$layout)) {
      md <- c(md, sprintf("| **Layout — %s** | %s |", k, o$layout[[k]]))
    }
  }
  md <- c(md, "")
  if (!is.null(o$notes) && nzchar(trimws(o$notes))) {
    notes_txt <- gsub("\n$", "", o$notes)
    md <- c(md, paste0("**Notes:** ", notes_txt))
    md <- c(md, "")
  }
  paste(md, collapse = "\n")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

## -----------------------------------------------------------------------------
## Build Markdown

out <- c()

## Front-matter and banner
out <- c(out, "# TFL Shells — SIMULATED-TORIVUMAB-2026")
out <- c(out, "")
out <- c(out, "> ⚠️ **GENERATED FILE — DO NOT EDIT DIRECTLY.**")
out <- c(out, "> Source of truth: [`tfl/shells.yaml`](shells.yaml).")
out <- c(out, "> Regenerate with: `Rscript tfl/render_shells.R`")
out <- c(out, "> Validate with: `Rscript tfl/validate_shells.R`")
out <- c(out, "")
out <- c(out, "> ⚠️ **FICTIONAL EDUCATIONAL DOCUMENT — NOT FOR REGULATORY USE.**")
out <- c(out, "")
out <- c(out, "---")
out <- c(out, "")

## Metadata
m <- shells$meta
out <- c(out, "## Administrative", "")
out <- c(out, "| Field | Value |", "|---|---|")
out <- c(out, sprintf("| **Study** | %s (%s) |", m$study, m$study_short))
out <- c(out, sprintf("| **SAP version** | v%s |", m$sap_version))
out <- c(out, sprintf("| **Protocol version** | v%s |", m$protocol_version))
out <- c(out, sprintf("| **Shells version** | v%s |", m$shells_version))
out <- c(out, sprintf("| **Date** | %s |", m$shells_date))
out <- c(out, sprintf("| **Author** | %s |", m$author))
out <- c(out, sprintf("| **Gate** | %s — blocks Phase 5 ADaM |", m$gate))
out <- c(out, sprintf("| **ARS alignment** | %s |", m$ars_alignment))
out <- c(out, sprintf("| **Format rationale** | [`SHELLS-FORMAT-RATIONALE.md`](SHELLS-FORMAT-RATIONALE.md) |"))
out <- c(out, "")

## Purpose
out <- c(out, "## Purpose", "")
out <- c(out, "Authoritative catalogue of every Table, Figure, and Listing planned for the CSR.")
out <- c(out, "Each output specifies the analysis set, source ADaM datasets, key variables, statistical methods, and a reference back to the SAP section that governs it.")
out <- c(out, "Shells in this file drive the downstream `programming-specs/AD*-spec.md` coverage check and (eventually) the `tern`/`rtables` output code.")
out <- c(out, "")
out <- c(out, "Schema aligns with CDISC ARS v1.0 concepts (analysis_sets / data_subsets / methods / reference_documents / outputs). This is not yet a full ARS JSON serialisation — the intent is that a future `render_ars.R` can emit ARS JSON directly from this same YAML.")
out <- c(out, "")

## Analysis sets
out <- c(out, "## 1. Analysis Sets", "")
out <- c(out, "| ID | Label | Definition | Filter | Treatment var | Expected N |")
out <- c(out, "|---|---|---|---|---|---|")
for (a in shells$analysis_sets) {
  n <- if (is.null(a$expected_n)) "—" else as.character(a$expected_n)
  adsl <- a$adsl_filter %||% "—"
  f_cell <- if (!is.null(a$adrs_filter))
              sprintf("ADSL: `%s`<br>ADRS: `%s`", adsl, a$adrs_filter)
            else
              sprintf("ADSL: `%s`", adsl)
  out <- c(out, sprintf("| %s | %s | %s | %s | `%s` | %s |",
                        a$id, a$label, a$definition, f_cell,
                        a$treatment_var, n))
}
out <- c(out, "")

## Methods
out <- c(out, "## 2. Statistical Methods", "")
out <- c(out, "| ID | Name | Description | R package · function |")
out <- c(out, "|---|---|---|---|")
for (mm in shells$methods) {
  fn <- if (!is.null(mm$r_function)) sprintf("%s · `%s`", mm$r_package %||% "—", mm$r_function) else mm$r_package %||% "—"
  out <- c(out, sprintf("| %s | %s | %s | %s |",
                        mm$id, mm$name, mm$description, fn))
}
out <- c(out, "")

## Reference documents
out <- c(out, "## 3. Reference Documents", "")
out <- c(out, "| ID | Title | Path |")
out <- c(out, "|---|---|---|")
for (r in shells$reference_documents) {
  out <- c(out, sprintf("| %s | %s | [`%s`](../%s) |",
                        r$id, r$title, r$path, r$path))
}
out <- c(out, "")

## Outputs — group by kind
out <- c(out, "## 4. Outputs", "")
out <- c(out, sprintf("Total: %d outputs (%d tables, %d figures, %d listings).",
                      length(shells$outputs),
                      sum(vapply(shells$outputs, function(x) x$kind == "table", logical(1))),
                      sum(vapply(shells$outputs, function(x) x$kind == "figure", logical(1))),
                      sum(vapply(shells$outputs, function(x) x$kind == "listing", logical(1)))))
out <- c(out, "")

for (grp in c("table", "figure", "listing")) {
  heading <- switch(grp,
                    table   = "### 4.1 Tables",
                    figure  = "### 4.2 Figures",
                    listing = "### 4.3 Listings")
  out <- c(out, heading, "")
  for (o in shells$outputs) {
    if (o$kind != grp) next
    out <- c(out, render_output(o, level = 4))
  }
}

## ADaM coverage summary
out <- c(out, "## 5. ADaM Coverage Summary", "")
out <- c(out, "Every variable in `programming-specs/AD*-spec.md` should be cited by ≥1 shell's `key_variables`. `validate_shells.R` enforces this — see its report output.")
out <- c(out, "")
all_vars <- sort(unique(unlist(lapply(shells$outputs, `[[`, "key_variables"))))
out <- c(out, sprintf("Distinct variables cited across all shells: **%d**.", length(all_vars)))
out <- c(out, "")
out <- c(out, "<details><summary>Full variable list</summary>", "")
out <- c(out, paste0("`", paste(all_vars, collapse = "`, `"), "`"))
out <- c(out, "", "</details>", "")

## SAP crosswalk
out <- c(out, "## 6. SAP → Output Crosswalk", "")
out <- c(out, "| SAP § | Outputs |")
out <- c(out, "|---|---|")
## Group outputs by sap_ref
refs <- vapply(shells$outputs, function(x) x$sap_ref %||% "—", character(1))
ids  <- vapply(shells$outputs, `[[`, character(1), "id")
for (r in sort(unique(refs))) {
  matching <- ids[refs == r]
  out <- c(out, sprintf("| %s | %s |", r, paste(matching, collapse = ", ")))
}
out <- c(out, "")

## Change log
out <- c(out, "## 7. Change Log", "")
out <- c(out, "| Version | Date | Change |")
out <- c(out, "|---|---|---|")
out <- c(out, sprintf("| %s | %s | Regenerated from `tfl/shells.yaml` |",
                      m$shells_version, m$shells_date))
out <- c(out, "")

writeLines(out, md_path)
cat("Wrote", md_path, "(", length(out), "lines)\n")
