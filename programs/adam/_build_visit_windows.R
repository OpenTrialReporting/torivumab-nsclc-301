# =============================================================================
# Program    : _build_visit_windows.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Generate the analysis-visit window reference used for date-based
#              windowing of BDS findings (SAP §12.2). Two nearest-target
#              partitions:
#                - TREATMENT stream (ADLB, ADVS): Q3W scheduled visits.
#                - TUMOUR stream (ADRS, ADTR): RECIST tumour assessments.
#              Targets are the protocol nominal study days; window boundaries are
#              the midpoints between consecutive targets (a gap-free, non-
#              overlapping integer partition), so each assessment maps to its
#              nearest scheduled visit. Event-driven visits (EOT, follow-up) are
#              NOT day-windowed and are excluded here (kept by collected role).
# Writes to  : crf/analysis_visit_windows.csv
# =============================================================================

add_bounds <- function(df, stream) {
  df <- df[order(df$TARGET_DY), ]
  t  <- df$TARGET_DY; n <- nrow(df)
  b  <- floor((head(t, -1) + t[-1]) / 2)          # n-1 midpoint boundaries
  df$WLO    <- c(-Inf, b + 1)
  df$WHI    <- c(b, Inf)
  df$STREAM <- stream
  df[, c("STREAM", "AVISIT", "AVISITN", "TARGET_DY", "WLO", "WHI")]
}

# ---- TREATMENT stream: SCREENING, induction C1D1/C1D15/C2..C6D1, maintenance ---
# Q3W cadence: CnD1 nominal day = 1 + (n-1)*21; MAINT_CmD1 continues (cycle 6+m).
# Maintenance runs to at least cycle 42 in the data; cover 50 with margin.
n_maint <- 50L
# The pre-treatment window (AVISITN 0) is the baseline analysis visit — labelled
# "Baseline" per CDISC ADaM convention (ADaMIG BDS examples / ADaM Pilot); the
# ABLFL='Y' record (last value on/before first dose, SAP §12.3) falls in it.
trt <- data.frame(
  AVISIT    = c("Baseline", "C1D1", "C1D15",
                paste0("C", 2:6, "D1"),
                paste0("MAINT_C", 1:n_maint, "D1")),
  AVISITN   = c(0L, 1L, 2L, 3:7, 9L + (1:n_maint)),
  TARGET_DY = c(-14, 1, 15,
                1 + (2:6 - 1) * 21,
                1 + (5 + 1:n_maint) * 21),
  stringsAsFactors = FALSE
)

# ---- TUMOUR stream: BASELINE + RECIST assessments (labels are Q6W multiples) ---
wks <- seq(6, 120, 6)
tum <- data.frame(
  AVISIT    = c("Baseline", paste0("TUMOR_ASSESS_WK", wks)),
  AVISITN   = c(0L, as.integer(wks)),
  TARGET_DY = c(-14, wks * 7),
  stringsAsFactors = FALSE
)

windows <- rbind(add_bounds(trt, "TREATMENT"), add_bounds(tum, "TUMOUR"))
# integer, finite-friendly output (Inf -> blank sentinels handled by the reader)
dir.create("crf", showWarnings = FALSE)
write.csv(windows, "crf/analysis_visit_windows.csv", row.names = FALSE, na = "")
cat("Wrote crf/analysis_visit_windows.csv:", nrow(windows), "rows (",
    sum(windows$STREAM == "TREATMENT"), "treatment /",
    sum(windows$STREAM == "TUMOUR"), "tumour )\n")
