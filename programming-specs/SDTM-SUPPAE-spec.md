# SUPPAE — Supplemental Qualifiers for AE — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPAE |
| **Label** | Supplemental Qualifiers for AE |
| **Class** | RELATIONSHIP |
| **Structure** | One record per AE per QNAM |
| **Expected N** | 11,360 |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `IDVAR`, `IDVARVAL`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPAE carries four sponsor-defined AE-level qualifiers that are required by the safety SAP but are not standard SDTM AE variables: an immune-related AE flag, an "AE led to study drug discontinuation" flag, a "dose modified due to AE" flag, and a treatment-emergent flag (AE onset on/after first study treatment). These flags feed ADAE (AETOXGR analysis, TEAE/irAE subgroup tables T-AE-04/05) and the safety pop summaries.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/ae.parquet` | Parent AE domain | Provides `USUBJID`, parent `AESEQ` for `IDVARVAL` linkage. |
| `raw/adverse_events.csv` | Raw CRF feed | Provides `AECAT`, `LEADING_TO_DISCONTINUATION`, `ACTION_TAKEN`, `AE_START_DATE` used to derive flags. |
| `datasets/sdtm/dm.parquet` | DM domain | Provides `RFXSTDTC` (first study-treatment date) for the `AETRTEM` treatment-emergent flag. |

## Variables

SUPP-- shape per SDTMIG §8.4 (consolidated in `programs/sdtm/SDTM-MAPPING-SPEC.md` §16, §18).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Assigned    | —      | Constant `"CTX-NSCLC-301"` |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —      | Constant `"AE"` |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —      | From parent AE |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —      | Constant `"AESEQ"` |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Derived     | —      | `as.character(AESEQ)` from re-derived AESEQ (see §Derivations) |
| 6 | QNAM     | Qualifier Variable Name      | Char | 8   | Assigned    | QNAM   | See §QNAM Definitions |
| 7 | QLABEL   | Qualifier Variable Label     | Char | 40  | Assigned    | QLABEL | See §QNAM Definitions |
| 8 | QVAL     | Data Value                   | Char | 200 | Derived     | NY     | `"Y"` / `"N"` per QNAM logic |
| 9 | QORIG    | Origin                       | Char | 20  | Assigned    | QORIG  | Constant `"DERIVED"` |
| 10 | QEVAL   | Evaluator                    | Char | 20  | Assigned    | —      | `""` |

## QNAM Definitions

| QNAM | QLABEL | Type | Length | Source | Derivation logic |
|---|---|---|---|---|---|
| IRAEFL  | Immune-Related AE Flag                | Char | 1 | `raw.AECAT`                     | `"Y"` if `toupper(trim(AECAT)) == "IMMUNE-RELATED"`; else `"N"`. |
| AEDISFL | AE Led to Study Drug Discontinuation  | Char | 1 | `raw.LEADING_TO_DISCONTINUATION`| `map_yn(.)`: `"Y"` if value ∈ {Y, YES, TRUE, 1}; else `"N"`. |
| AEACTFL | Dose Modified Due to AE               | Char | 1 | `raw.ACTION_TAKEN`              | `"Y"` if `toupper(trim(.))` ∈ {DOSE REDUCED, DOSE INTERRUPTED, DRUG INTERRUPTED, DRUG WITHDRAWN, DOSE REDUCTION}; else `"N"`. |
| AETRTEM | Treatment Emergent Analysis Flag      | Char | 1 | `raw.AE_START_DATE`, `DM.RFXSTDTC` | `"Y"` if first-dose date (`RFXSTDTC`) is non-missing AND `as.Date(AE_START_DATE) >= RFXSTDTC`; else `"N"` (P21 SD1097 — FDA business rule requires a treatment-emergent flag in SUPPAE). |

All four QNAMs are emitted for every parent AE record (long form via `pivot_longer`).

## Derivations

```r
ae  <- read_parquet("datasets/sdtm/ae.parquet")
raw <- read.csv("raw/adverse_events.csv") |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-")) |>
  # Mirror ae.R dedup EXACTLY so re-derived AESEQ aligns with parent AE.AESEQ.
  arrange(USUBJID, AE_START_DATE, AE_VERBATIM_TERM, dplyr::desc(AE_END_DATE)) |>
  distinct(USUBJID, AE_VERBATIM_TERM, AE_START_DATE, SEVERITY, SERIOUS,
           ACTION_TAKEN, OUTCOME, .keep_all = TRUE)

# First-dose date per subject for the treatment-emergent flag.
rfxst <- read_parquet("datasets/sdtm/dm.parquet") |>
  transmute(USUBJID, rfxst = as.Date(RFXSTDTC))

# Re-derive AESEQ identically to parent AE: arrange (USUBJID, AE_START_DATE),
# then row_number() per subject. This MUST match parent AE.AESEQ.
raw_with_flags <- raw |>
  arrange(USUBJID, AE_START_DATE) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  left_join(rfxst, by = "USUBJID") |>
  transmute(
    USUBJID, AESEQ,
    IRAEFL  = ifelse(toupper(trimws(AECAT)) == "IMMUNE-RELATED", "Y", "N"),
    AEDISFL = ifelse(map_yn(LEADING_TO_DISCONTINUATION) == "Y", "Y", "N"),
    AEACTFL = case_when(
      toupper(trimws(ACTION_TAKEN)) %in%
        c("DOSE REDUCED","DOSE INTERRUPTED","DRUG INTERRUPTED",
          "DRUG WITHDRAWN","DOSE REDUCTION") ~ "Y",
      TRUE ~ "N"
    ),
    AETRTEM = ifelse(!is.na(rfxst) & as.Date(AE_START_DATE) >= rfxst, "Y", "N")
  )

supp_long <- raw_with_flags |>
  pivot_longer(c(IRAEFL, AEDISFL, AEACTFL, AETRTEM), names_to = "QNAM", values_to = "QVAL") |>
  mutate(
    STUDYID  = "CTX-NSCLC-301",
    RDOMAIN  = "AE",
    IDVAR    = "AESEQ",
    IDVARVAL = as.character(AESEQ),
    QLABEL   = case_when(
      QNAM == "IRAEFL"  ~ "Immune-Related AE Flag",
      QNAM == "AEDISFL" ~ "AE Led to Study Drug Discontinuation",
      QNAM == "AEACTFL" ~ "Dose Modified Due to AE",
      QNAM == "AETRTEM" ~ "Treatment Emergent Analysis Flag"
    ),
    QORIG    = "DERIVED",
    QEVAL    = ""
  ) |>
  filter(!is.na(QVAL), QVAL != "") |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)
```

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## QC Checks

- [ ] `nrow(suppae) == 11360` (4 QNAMs × 2,840 AE rows).
- [ ] `n_distinct(USUBJID, IDVARVAL)` equals `nrow(ae)`; the re-derived `AESEQ` matches parent `AE.AESEQ` exactly.
- [ ] `QNAM ∈ {IRAEFL, AEDISFL, AEACTFL, AETRTEM}` only and each parent AE has all four.
- [ ] `QVAL ∈ {"Y", "N"}` with no missing.
- [ ] `RDOMAIN == "AE"`, `IDVAR == "AESEQ"`, `QORIG == "DERIVED"` for all rows.
- [ ] Sort matches `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-SUPPAE-spec.md` → `programs/sdtm/suppae.R` | `programs/sdtm/suppae.R` → `datasets/sdtm/suppae.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §18.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft (covers v0.2 back-fill of SUPPAE released 2026-05-16). |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `suppae.R`: added fourth QNAM `AETRTEM` (treatment-emergent flag, AE onset ≥ `DM.RFXSTDTC`; P21 SD1097); added `dm.parquet` source; record count 8,511 → 11,360 (4 QNAMs × 2,840 AEs); updated derivation, QNAM table, and QC. |
