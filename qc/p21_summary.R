# p21_summary.R — print per-rule Found totals from a Pinnacle 21 report.
# Usage: Rscript qc/p21_summary.R <report.xlsx>
# Reads the Issue Summary sheet, LOCF-fills the merged Severity/Source cells,
# and prints rules sorted by true Found count (the Details sheet caps at
# 1000 rows/rule, so Issue Summary is the source of truth for totals).
suppressWarnings(suppressMessages({
  if (!requireNamespace("readxl", quietly = TRUE)) {
    cat("readxl not installed — skipping summary.\n"); quit(status = 0)
  }
  library(readxl)
}))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1 || !file.exists(args[1])) {
  cat("usage: Rscript qc/p21_summary.R <report.xlsx>\n"); quit(status = 0)
}
raw <- as.data.frame(suppressMessages(read_excel(args[1], sheet = "Issue Summary",
                                                 col_names = FALSE)))
hdr <- which(apply(raw, 1, function(r) any(grepl("Pinnacle 21 ID", r))))[1]
names(raw) <- as.character(unlist(raw[hdr, ]))
b <- raw[(hdr + 1):nrow(raw), ]
b <- b[!is.na(b$`Pinnacle 21 ID`), ]
b$Found <- suppressWarnings(as.numeric(b$Found))
names(b)[names(b) == "Pinnacle 21 ID"] <- "ID"
byid <- aggregate(Found ~ ID, b, sum)
sev  <- b[!duplicated(b$ID), c("ID", "Severity", "Message")]
m <- merge(byid, sev, by = "ID"); m <- m[order(-m$Found), ]
cat(sprintf("\n=== %s ===\n", basename(args[1])))
cat(sprintf("Total findings: %d  across %d rules\n\n", sum(m$Found, na.rm = TRUE), nrow(m)))
for (i in seq_len(nrow(m)))
  cat(sprintf("  %-8s %8d  [%-9s] %s\n", m$ID[i], m$Found[i],
              ifelse(is.na(m$Severity[i]), "", m$Severity[i]),
              substr(ifelse(is.na(m$Message[i]), "", m$Message[i]), 1, 66)))
