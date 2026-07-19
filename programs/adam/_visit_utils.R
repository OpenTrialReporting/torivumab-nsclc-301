# =============================================================================
# Program    : _visit_utils.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Shared derivation of the ADaM analysis-visit numeric ordering
#              variable AVISITN, per the scheme defined in the SAP
#              (§ Analysis Visits) and the BDS programming specs.
#
#              AVISIT is the analysis visit label (= VISIT for scheduled
#              visits). AVISITN is its numeric sort key. Where the SDTM
#              VISITNUM is populated it is authoritative; where SDTM did not
#              collect VISITNUM (maintenance cycles, tumour-assessment weeks)
#              AVISITN is derived deterministically from the visit label so the
#              ordering is complete and gap-free:
#
#                SCREENING            -> 0     (from VISITNUM)
#                C1D1..C6D1 induction -> 1..7   (from VISITNUM)
#                MAINT_CnD1           -> 9 + n  (matches SDTM get_visitnum)
#                BASELINE             -> 0
#                TUMOR_ASSESS_WKn     -> n
#                EOT / FU1 / FU2      -> 900 / 901 / 902 (from VISITNUM)
#                subject-level params -> NA     (no analysis visit)
#
#              AVISITN equals SDTM VISITNUM wherever it is populated (the
#              authoritative source); the label-based branches below are a
#              defensive fallback for the rare visit with no collected VISITNUM
#              and use the same numbering scheme so the two paths never disagree.
#
#              Sourced by adlb.R, adex.R, adrs.R, adtr.R, advs.R.
# =============================================================================

source(file.path("programs", "adam", "_adam_utils.R"))  # provides study_day()

derive_avisitn <- function(avisit, visitnum) {
  vn <- suppressWarnings(as.numeric(visitnum))
  av <- as.character(avisit)
  # Parse the numeric suffix only where the label matches; NA elsewhere (avoids
  # as.numeric() coercion warnings, since case_when evaluates every branch).
  num_from <- function(pattern, x) {
    m <- grepl(pattern, x)
    out <- rep(NA_real_, length(x))
    out[m] <- as.numeric(sub(pattern, "\\1", x[m]))
    out
  }
  out <- dplyr::case_when(
    !is.na(vn)                               ~ vn,
    is.na(av)                                ~ NA_real_,
    av == "BASELINE"                         ~ 0,
    grepl("^MAINT_C[0-9]+D1$", av)           ~ 9 + num_from("^MAINT_C([0-9]+)D1$", av),
    grepl("^TUMOR_ASSESS_WK[0-9]+$", av)     ~ num_from("^TUMOR_ASSESS_WK([0-9]+)$", av),
    TRUE                                     ~ NA_real_
  )
  as.integer(out)
}
