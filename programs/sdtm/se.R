# =============================================================================
# Program    : se.R
# Domain     : SE — Subject Elements
# SDTM IG ref: Section 5.3 (Special Purpose)
# Reads from : datasets/sdtm/dm.parquet
# Writes to  : datasets/sdtm/se.parquet
# Notes      : One record per subject per actual element, with dates taken from
#              the DM reference window (consent -> first dose -> last dose ->
#              participation end). SE provides the element boundaries used by
#              17_derive_timing.R to assign EPOCH to every observation. Presence
#              of SE clears P21 SD1111.
# =============================================================================

library(dplyr)
library(arrow)

SDTM_DIR <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

dm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dm.parquet")))

# Element boundaries per subject. Screening runs from informed consent to first
# study treatment; Treatment spans first to last dose; Follow-up runs from last
# dose to end of participation. Undosed subjects have Screening only.
se <- dm |>
  transmute(
    STUDYID, USUBJID,
    ic   = RFICDTC,
    rand = RFSTDTC,
    fdos = RFXSTDTC,
    ldos = RFXENDTC,
    pend = RFENDTC
  ) |>
  rowwise() |>
  mutate(rows = list({
    scrn_end <- dplyr::coalesce(fdos, pend, rand)
    out <- tibble::tibble(
      ETCD    = "SCRN", ELEMENT = "Screening", TAETORD = 1L, EPOCH = "SCREENING",
      SESTDTC = dplyr::coalesce(ic, rand), SEENDTC = scrn_end
    )
    if (!is.na(fdos)) {
      out <- dplyr::bind_rows(out, tibble::tibble(
        ETCD = "TRT", ELEMENT = "Treatment", TAETORD = 2L, EPOCH = "TREATMENT",
        SESTDTC = fdos, SEENDTC = dplyr::coalesce(ldos, pend, fdos)))
      fu_start <- dplyr::coalesce(ldos, fdos)
      if (!is.na(pend) && !is.na(fu_start) && pend > fu_start) {
        out <- dplyr::bind_rows(out, tibble::tibble(
          ETCD = "FU", ELEMENT = "Follow-up", TAETORD = 3L, EPOCH = "FOLLOW-UP",
          SESTDTC = fu_start, SEENDTC = pend))
      }
    }
    out
  })) |>
  ungroup() |>
  tidyr::unnest(rows) |>
  group_by(USUBJID) |>
  mutate(SESEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID, DOMAIN = "SE", USUBJID, SESEQ,
    ETCD, ELEMENT, SESTDTC, SEENDTC, TAETORD, EPOCH
  ) |>
  arrange(USUBJID, SESEQ)

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(se, file.path(SDTM_DIR, "se.parquet"))
message("SE written: ", nrow(se), " subject-element records (",
        dplyr::n_distinct(se$USUBJID), " subjects)")
