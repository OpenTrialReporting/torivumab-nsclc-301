# DD — Death Details — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DD |
| **Label** | Death Details |
| **Class** | FINDINGS |
| **Structure** | One record per death per subject (single `DEATH` finding) |
| **Expected N** | 284 |
| **Key variables** | `STUDYID`, `USUBJID`, `DDSEQ` |
| **SDTMIG version** | CDISC SDTMIG Oncology Supplement (Death Details) on top of SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DD records the **primary cause of death** for every deceased subject, alongside an optional secondary cause detail. It is the SDTM source for `ADSL.DTHCAUS` (via `admiral::derive_var_dthcaus()`) and underpins the cause-of-death sub-table in T-EFF-01 / L-DTH-01 listings. Only subjects who died on-study or in survival follow-up appear (one record per subject). Source data are collected on the dedicated CDASH Death CRF.

This spec follows the CDISC SDTM Oncology Disease Response Supplement convention of carrying death details in their own FINDINGS-class domain rather than mixing them with `DS`.

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/death.csv` | CDASH Death CRF | One row per deceased subject |

**Raw columns:** `SUBJECT_ID, DEATH_DATE, PRIMARY_CAUSE, CAUSE_DETAIL`.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DD"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DDSEQ | Sequence Number | Num | 8 | Assigned | — | Constant `1` (one DD per subject) |
| 5 | DDTESTCD | Short Name of Measurement | Char | 8 | Assigned | DDTESTCD | Constant `"DEATH"` |
| 6 | DDTEST | Name of Measurement | Char | 40 | Assigned | DDTEST | Constant `"Death"` |
| 7 | DDORRES | Result in Original Units | Char | 1 | Assigned | NY | Constant `"Y"` (presence of death) |
| 8 | DDSTRESC | Standardised Result (character) | Char | 1 | Assigned | NY | Constant `"Y"` |
| 9 | DDDTC | Date of Death | Char | 10 | Predecessor | ISO 8601 | `as.character(DEATH_DATE)` |
| 10 | DDCAT | Category | Char | 40 | Assigned | — | Constant `"PRIMARY CAUSE OF DEATH"` |
| 11 | DDTERM | Reported Term for Cause | Char | 200 | Predecessor | — | `str_to_upper(str_trim(PRIMARY_CAUSE))` |
| 12 | DDSCAT | Subcategory (cause detail) | Char | 200 | Derived | — | See §Derivations.D1 |

## Derivations

### D1 — DDSCAT (cause detail)
**Rule:** Populate from `CAUSE_DETAIL` when present (trim/upper); otherwise NA.
```r
DDSCAT = if_else(
  !is.na(CAUSE_DETAIL) & str_trim(CAUSE_DETAIL) != "",
  str_to_upper(str_trim(CAUSE_DETAIL)),
  NA_character_
)
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| DDTESTCD | C124296 (DDTESTCD, Oncology suppl.) | Only `DEATH` used here |
| DDTEST | C124297 (DDTEST, Oncology suppl.) | Only `"Death"` |
| DDORRES, DDSTRESC | NY (C66742) | Always `"Y"` (record presence implies death occurred) |
| DDCAT | Study-specific | Single value `"PRIMARY CAUSE OF DEATH"` |
| DDTERM | Free text mapped from raw `PRIMARY_CAUSE`; expected values include `"DISEASE PROGRESSION"`, `"ADVERSE EVENT"`, `"OTHER"`, `"UNKNOWN"` | — |

## QC Checks

- [ ] `nrow(dd) ≈ 284` (within ±0.1%).
- [ ] `n_distinct(USUBJID) == nrow(dd)` (exactly one row per dead subject).
- [ ] `DDSEQ == 1` for every row.
- [ ] `DDDTC` parses as ISO 8601 date; not in the future of `DCUTDT` (2025-01-31).
- [ ] Every `DD.USUBJID` exists in `DM` with `DM.DTHFL == "Y"` and `DM.DTHDTC` non-missing.
- [ ] `DDDTC == DM.DTHDTC` for every row (cross-domain consistency).
- [ ] `DDORRES == "Y"` and `DDSTRESC == "Y"` for every row.
- [ ] `DDTERM` is upper-case, trimmed; no NA values.
- [ ] Sort key `USUBJID` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-DD-spec.md` | `programs/sdtm/dd.R` | `datasets/sdtm/dd.parquet` |

Downstream consumers: `ADSL` (`DTHCAUS`, `DTHDT`), `ADTTE` (OS event reason listing), `ADAE` (FATAL outcome cross-check).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §9 for the consolidated cross-domain pseudocode.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/dd.R`. |
