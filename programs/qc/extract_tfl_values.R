# torivumab guidelines loaded
# =============================================================================
# programs/qc/extract_tfl_values.R
# Parse tfl/tables/*.docx and extract every cell value to a single CSV.
# Enables programmatic comparison of primary vs QC TFL outputs via
#   diff <(sort qc/tfl-values-primary.csv) <(sort qc/tfl-values-qc.csv)
#
# Usage      : Rscript programs/qc/extract_tfl_values.R [<tables_dir>] [<out_csv>]
# Defaults   : <tables_dir> = tfl/tables
#              <out_csv>    = qc/reports/<timestamp>/tfl-values.csv
# Notes      : Only .docx is parsed (rich structured tables). RTF and HTML
#              are independent renderings of the same flextable so values
#              are guaranteed identical.
# =============================================================================

suppressPackageStartupMessages({
  library(officer)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
tables_dir <- if (length(args) >= 1) args[1] else "tfl/tables"
ts <- format(Sys.time(), "%Y%m%dT%H%M%S")
out_csv <- if (length(args) >= 2) {
  args[2]
} else {
  file.path("qc", "reports", ts, "tfl-values.csv")
}

dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)

if (!dir.exists(tables_dir)) stop("Directory not found: ", tables_dir)

docx_files <- list.files(tables_dir, pattern = "\\.docx$", full.names = TRUE)
cat(sprintf("Found %d .docx files in %s\n", length(docx_files), tables_dir))

extract_one <- function(path) {
  output_id <- sub("\\.docx$", "", basename(path))
  doc <- tryCatch(read_docx(path), error = function(e) NULL)
  if (is.null(doc)) {
    return(data.frame(output_id = output_id, table_n = NA_integer_,
                        row_n = NA_integer_, col_n = NA_integer_,
                        cell_text = NA_character_,
                        stringsAsFactors = FALSE))
  }
  summ <- docx_summary(doc)
  tables <- summ |> filter(content_type == "table cell")
  if (nrow(tables) == 0) {
    return(data.frame(output_id = output_id, table_n = NA_integer_,
                        row_n = NA_integer_, col_n = NA_integer_,
                        cell_text = NA_character_,
                        stringsAsFactors = FALSE))
  }
  data.frame(
    output_id = output_id,
    table_n   = tables$doc_index,
    row_n     = tables$row_id,
    col_n     = tables$cell_id,
    cell_text = tables$text,
    stringsAsFactors = FALSE
  )
}

all_cells <- bind_rows(lapply(docx_files, extract_one))
cat(sprintf("Extracted %d cells across %d outputs\n",
            nrow(all_cells), length(unique(all_cells$output_id))))

# Normalise: strip whitespace, collapse internal runs of whitespace
all_cells$cell_text <- trimws(all_cells$cell_text)
all_cells$cell_text <- gsub("\\s+", " ", all_cells$cell_text)

# Sort by (output_id, table_n, row_n, col_n) so diff is stable
all_cells <- all_cells |> arrange(output_id, table_n, row_n, col_n)

write.csv(all_cells, out_csv, row.names = FALSE, na = "")
cat(sprintf("Wrote %s\n", out_csv))

# Summary per output
summary_path <- sub("\\.csv$", "-summary.md", out_csv)
summ_df <- all_cells |>
  group_by(output_id) |>
  summarise(n_cells = n(),
            n_numeric = sum(grepl("^[-+]?[0-9.,]+$", cell_text)),
            n_text    = sum(!grepl("^[-+]?[0-9.,]+$", cell_text)),
            .groups = "drop")
out_md <- c(
  "# TFL value extraction — summary",
  "",
  sprintf("**Generated:** %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("**Source dir:** `%s`", tables_dir),
  sprintf("**Output CSV:** `%s`", out_csv),
  sprintf("**Total .docx parsed:** %d", length(docx_files)),
  sprintf("**Total cells extracted:** %d", nrow(all_cells)),
  "",
  "## Per-output cell counts",
  "",
  "| Output | Cells | Numeric | Text |",
  "|---|---:|---:|---:|"
)
for (i in seq_len(nrow(summ_df))) {
  out_md <- c(out_md, sprintf("| %s | %d | %d | %d |",
                                summ_df$output_id[i], summ_df$n_cells[i],
                                summ_df$n_numeric[i], summ_df$n_text[i]))
}
out_md <- c(out_md, "",
             "## How to compare primary vs QC",
             "",
             "```bash",
             "# Run on both primary and QC output dirs:",
             "Rscript programs/qc/extract_tfl_values.R tfl/tables       qc/tfl-values-primary.csv",
             "Rscript programs/qc/extract_tfl_values.R qc/tfl/tables    qc/tfl-values-qc.csv",
             "",
             "# Diff (using GNU diff):",
             "diff <(sort qc/tfl-values-primary.csv) <(sort qc/tfl-values-qc.csv)",
             "",
             "# Or in R:",
             "p <- read.csv('qc/tfl-values-primary.csv')",
             "q <- read.csv('qc/tfl-values-qc.csv')",
             "waldo::compare(p, q)",
             "```",
             "",
             "Any cells that differ flag a programming discrepancy and should be",
             "logged on the TFL tracker under 'Findings / issues'.")
writeLines(out_md, summary_path)
cat(sprintf("Wrote %s\n", summary_path))
