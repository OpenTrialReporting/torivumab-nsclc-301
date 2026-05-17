# SUPPAE — Supplemental Qualifiers for AE — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPAE |
| **Label** | Supplemental Qualifiers for AE |
| **Class** | RELATIONSHIP |
| **Structure** | One record per AE per QNAM |
| **Expected N** | 8,511 |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `IDVAR`, `IDVARVAL`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPAE carries three sponsor-defined AE-level qualifiers that are required by the safety SAP but are not standard SDTM AE variables: an immune-related AE flag, an "AE led to study drug discontinuation" flag, and a "dose modified due to AE" flag. These flags feed ADAE (AETOXGR analysis, irAE subgroup tables T-AE-04/05) and the safety pop summaries.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/ae.parquet` | Parent AE domain | Provides `USUBJID`, parent `AESEQ` for `IDVARVAL` linkage. |
| `raw/adverse_events.csv` | Raw CRF feed | Provides `AECAT`, `LEADING_TO_DISCONTINUATION`, `ACTION_TAKEN` used to derive flags. |

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

All three QNAMs are emitted for every parent AE record (long form via `pivot_longer`).

## Derivations

```r
ae  <- read_parquet("datasets/sdtm/ae.parquet")
raw <- read.csv("raw/adverse_events.csv") |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"))

# Re-derive AESEQ identically to parent AE: arrange (USUBJID, AE_START_DATE),
# then row_number() per subject. This MUST match parent AE.AESEQ.
raw_with_flags <- raw |>
  arrange(USUBJID, AE_START_DATE) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  transmute(
    USUBJID, AESEQ,
    IRAEFL  = ifelse(toupper(trimws(AECAT)) == "IMMUNE-RELATED", "Y", "N"),
    AEDISFL = ifelse(map_yn(LEADING_TO_DISCONTINUATION) == "Y", "Y", "N"),
    AEACTFL = case_when(
      toupper(trimws(ACTION_TAKEN)) %in%
        c("DOSE REDUCED","DOSE INTERRUPTED","DRUG INTERRUPTED",
          "DRUG WITHDRAWN","DOSE REDUCTION") ~ "Y",
      TRUE ~ "N"
    )
  )

supp_long <- raw_with_flags |>
  pivot_longer(c(IRAEFL, AEDISFL, AEACTFL), names_to = "QNAM", values_to = "QVAL") |>
  mutate(
    STUDYID  = "CTX-NSCLC-301",
    RDOMAIN  = "AE",
    IDVAR    = "AESEQ",
    IDVARVAL = as.character(AESEQ),
    QLABEL   = case_when(
      QNAM == "IRAEFL"  ~ "Immune-Related AE Flag",
      QNAM == "AEDISFL" ~ "AE Led to Study Drug Discontinuation",
      QNAM == "AEACTFL" ~ "Dose Modified Due to AE"
    ),
    QORIG    = "DERIVED",
    QEVAL    = ""
  ) |>
  filter(!is.na(QVAL), QVAL != "") |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)
```

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## QC Checks

- [ ] `nrow(suppae) == 8511` (3 QNAMs × 2,837 AE rows).
- [ ] `n_distinct(USUBJID, IDVARVAL)` equals `nrow(ae)`; the re-derived `AESEQ` matches parent `AE.AESEQ` exactly.
- [ ] `QNAM ∈ {IRAEFL, AEDISFL, AEACTFL}` only and each parent AE has all three.
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
