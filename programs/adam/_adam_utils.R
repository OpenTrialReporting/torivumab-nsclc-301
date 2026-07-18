# =============================================================================
# Program    : _adam_utils.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Purpose    : Shared ADaM derivation helpers.
#
#   study_day(dt, ref) — CDISC study/analysis day with NO day zero
#   (Pinnacle 21 AD0046). Day of / after the reference = (dt - ref) + 1;
#   day before the reference = (dt - ref). There is no day 0: the day
#   immediately before ref is -1, the reference day itself is +1.
#
# Sourced by the BDS/OCCDS derivation programs that derive ADY/ASTDY/AENDY.
# =============================================================================

study_day <- function(dt, ref) {
  d <- as.integer(dt - ref)
  dplyr::if_else(is.na(d), NA_integer_, dplyr::if_else(d >= 0L, d + 1L, d))
}
