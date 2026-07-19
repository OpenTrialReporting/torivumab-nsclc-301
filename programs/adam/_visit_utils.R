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

# -----------------------------------------------------------------------------
# Analysis-visit WINDOWING (SAP §12.2)
# -----------------------------------------------------------------------------
# Each finding is mapped to its nearest scheduled analysis visit by study day
# (ADY), using the gap-free nearest-target partition in
# crf/analysis_visit_windows.csv (built by _build_visit_windows.R). Event-driven
# visits (EOT, follow-up) are not day-windowed and keep their collected label /
# SDTM VISITNUM. Two streams: TREATMENT (ADLB/ADVS Q3W) and TUMOUR (ADRS/ADTR
# RECIST). derive_avisit_windowed() returns AVISIT, AVISITN and the visit target
# day (ATPTREF) used by flag_anl01() to pick one record per analysis visit.

# UNSCHEDULED is deliberately NOT an event visit: it is windowed by ADY to the
# nearest scheduled analysis visit, so an off-schedule recheck contributes to
# that visit only if it is the record closest to target (else the scheduled draw
# keeps ANL01FL='Y' and the unscheduled record is retained, ANL01FL=NA, for
# listings). The collected SDTM VISIT ("UNSCHEDULED") is preserved for traceability.
EVENT_VISITS <- c("EOT", "FU1", "FU2", "FOLLOW-UP")

.load_visit_windows <- function(stream) {
  path <- file.path("crf", "analysis_visit_windows.csv")
  w <- utils::read.csv(path, stringsAsFactors = FALSE)
  w <- w[w$STREAM == stream, ]
  w$WLO[is.na(w$WLO) | w$WLO == ""] <- -Inf
  w$WHI[is.na(w$WHI) | w$WHI == ""] <-  Inf
  w[order(w$TARGET_DY), ]
}

derive_avisit_windowed <- function(ady, collected_visit, visitnum, stream) {
  w  <- .load_visit_windows(stream)
  cv <- as.character(collected_visit)
  vn <- suppressWarnings(as.numeric(visitnum))
  d  <- suppressWarnings(as.numeric(ady))

  # window every record by ADY into the nearest scheduled visit
  idx <- findInterval(d, c(-Inf, w$WHI))            # 1..nrow(w)
  idx <- pmin(pmax(idx, 1L), nrow(w))
  avisit  <- w$AVISIT[idx]
  avisitn <- w$AVISITN[idx]
  target  <- w$TARGET_DY[idx]

  # subject-level records (no collected visit, e.g. ADRS BOR/CBOR): not windowed
  is_sl <- is.na(cv) | cv == ""
  avisit[is_sl]  <- NA_character_
  avisitn[is_sl] <- NA_integer_
  target[is_sl]  <- NA_real_
  # event-driven visits: keep collected label + its SDTM VISITNUM, no target
  is_evt <- !is_sl & toupper(cv) %in% EVENT_VISITS
  avisit[is_evt]  <- cv[is_evt]
  avisitn[is_evt] <- vn[is_evt]
  target[is_evt]  <- NA_real_
  # records with no ADY cannot be windowed -> fall back to collected label
  na_d <- is.na(d) & !is_evt & !is_sl
  avisit[na_d]  <- cv[na_d]
  avisitn[na_d] <- vn[na_d]
  target[na_d]  <- NA_real_

  data.frame(AVISIT = avisit, AVISITN = as.integer(avisitn),
             ATPTREF = as.numeric(target), stringsAsFactors = FALSE)
}

# One analysis record per subject x parameter x analysis visit: the record
# closest to the visit target day (ties -> later ADT). Event visits (no target)
# select the latest record. Only `eligible` records (default: non-missing AVAL)
# can be flagged, so a missing value never wins the window. Requires columns
# USUBJID, <param>, AVISIT, ADY, ATPTREF, ADT; returns "Y"/NA aligned to df rows.
flag_anl01 <- function(df, param = "PARAMCD", eligible = !is.na(df$AVAL)) {
  n <- nrow(df)
  fl <- rep(NA_character_, n)
  keep <- which(eligible & !is.na(df$AVISIT))
  if (!length(keep)) return(fl)
  sub  <- df[keep, , drop = FALSE]
  key  <- paste(sub$USUBJID, sub[[param]], sub$AVISIT, sep = "\r")
  dist <- ifelse(is.na(sub$ATPTREF), 0, abs(as.numeric(sub$ADY) - sub$ATPTREF))
  adt  <- as.numeric(as.Date(sub$ADT))
  ord  <- order(key, dist, -adt, seq_along(key))   # per key: nearest, then latest
  chosen <- !duplicated(key[ord])                  # first row per key in this order
  fl[keep[ord[chosen]]] <- "Y"
  fl
}
