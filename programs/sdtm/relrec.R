# torivumab guidelines loaded
# =============================================================================
# Program    : relrec.R
# Dataset    : RELREC — Related Records
# SDTM IG ref: Section 8.5
# Reads from : datasets/sdtm/tu.parquet, tr.parquet, rs.parquet
# Writes to  : datasets/sdtm/relrec.parquet
# Notes      : Two relationship groups per subject:
#                 (a) Lesion identity — TU (one) ↔ TR (many) by LNKID
#                     RELID = "LESION-<lesion_id>"; IDVAR = TULINKID/TRLINKID
#                 (b) Visit response — RS (one) ↔ TR (many) by assessment date
#                     RELID = "RESP-<RSDTC>";       IDVAR = RSSEQ/TRSEQ
#              Per SDTMIG §8.5, RELREC defines record-level cross-domain
#              relationships beyond what implicit --LNKID variables convey.
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)

SDTM_DIR <- "datasets/sdtm"

tu <- as.data.frame(read_parquet(file.path(SDTM_DIR, "tu.parquet")))
tr <- as.data.frame(read_parquet(file.path(SDTM_DIR, "tr.parquet")))
rs <- as.data.frame(read_parquet(file.path(SDTM_DIR, "rs.parquet")))

# ---- Relationship A: TU(one) ↔ TR(many) by lesion id ----
tu_rows <- tu |>
  filter(!is.na(TULINKID), TULINKID != "") |>
  transmute(
    STUDYID,
    RDOMAIN  = "TU",
    USUBJID,
    IDVAR    = "TULINKID",
    IDVARVAL = as.character(TULINKID),
    RELID    = paste0("LESION-", TULINKID)
  ) |>
  distinct()   # AL-11 fix (2026-05-17): TU has one row per lesion per visit,
               # so distinct() collapses to one RELREC row per (USUBJID, lesion).

tr_lesion_rows <- tr |>
  filter(!is.na(TRLINKID), TRLINKID != "") |>
  transmute(
    STUDYID,
    RDOMAIN  = "TR",
    USUBJID,
    IDVAR    = "TRLINKID",
    IDVARVAL = as.character(TRLINKID),
    RELID    = paste0("LESION-", TRLINKID)
  ) |>
  distinct()

relrec_lesion <- bind_rows(tu_rows, tr_lesion_rows)

# ---- Relationship B: RS(one) ↔ TR(many) by assessment date ----
rs_rows <- rs |>
  filter(!is.na(RSDTC), RSDTC != "") |>
  transmute(
    STUDYID,
    RDOMAIN  = "RS",
    USUBJID,
    IDVAR    = "RSSEQ",
    IDVARVAL = as.character(RSSEQ),
    RELID    = paste0("RESP-", USUBJID, "-", RSDTC)
  )

# Match TR records at the same visit/date as each RS assessment
tr_resp_rows <- tr |>
  filter(!is.na(TRDTC), TRDTC != "") |>
  inner_join(
    rs |> select(USUBJID, RSDTC) |> distinct(),
    by = c("USUBJID" = "USUBJID", "TRDTC" = "RSDTC")
  ) |>
  transmute(
    STUDYID,
    RDOMAIN  = "TR",
    USUBJID,
    IDVAR    = "TRSEQ",
    IDVARVAL = as.character(TRSEQ),
    RELID    = paste0("RESP-", USUBJID, "-", TRDTC)
  )

relrec_resp <- bind_rows(rs_rows, tr_resp_rows)

sdtm_relrec <- bind_rows(relrec_lesion, relrec_resp) |>
  arrange(STUDYID, USUBJID, RELID, RDOMAIN, IDVARVAL) |>
  transmute(
    STUDYID,
    RDOMAIN,
    USUBJID,
    IDVAR,
    IDVARVAL,
    RELID
  ) |>
  distinct(STUDYID, USUBJID, RDOMAIN, IDVAR, IDVARVAL, RELID)
# AL-11 closure (2026-05-17): final distinct() on the full key tuple guarantees
# unique relationship rows after the bind_rows of lesion + response sets.

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_relrec, file.path(SDTM_DIR, "relrec.parquet"))
message(
  "RELREC written: ", nrow(sdtm_relrec), " records | ",
  n_distinct(sdtm_relrec$RELID), " relationship groups | ",
  n_distinct(sdtm_relrec$USUBJID), " subjects"
)
