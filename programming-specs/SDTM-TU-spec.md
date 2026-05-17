# TU — Tumor Identification — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | TU |
| **Label** | Tumor Identification |
| **Class** | FINDINGS |
| **Structure** | One record per identified lesion per assessment visit per subject |
| **Expected N** | 7,686 |
| **Key variables** | `STUDYID`, `USUBJID`, `TUSEQ`; group key `TULINKID` |
| **SDTMIG version** | CDISC SDTM Oncology Disease Response Supplement §9.1 (RECIST 1.1, 2023) on SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

TU captures the **identification** of each lesion (target, non-target, or new) at every tumour assessment visit. It establishes the lesion identity that `TR` (measurements / responses) and `RS` (overall response) reference via `TULINKID` (RELREC Relationship A — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §21.1). TU does **not** carry the measurements themselves — those live in `TR`. The domain is the SDTM source for `ADTR` (target-lesion analysis) and feeds the BoR / BoTL derivations in `ADRS`.

This spec follows the CDISC SDTM Oncology Disease Response Supplement convention (RECIST 1.1, 2023).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/tumor_measurements.csv` | CDASH Tumor Assessment form (radiology read) | One row per lesion per assessment |
| Shared VISIT lookup | `programs/sdtm/SDTM-MAPPING-SPEC.md` §"Shared VISIT lookup" | Maps `VISIT_NAME` → `VISITNUM` |

**Raw columns:** `SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME, LESION_ID, LESION_TYPE, ANATOMICAL_LOCATION, LONGEST_DIAMETER_MM, RESPONSE_CATEGORY, NEW_LESION`.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"TU"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | TUSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, TUDTC, TULINKID)` |
| 5 | TUTESTCD | Short Name of Measurement | Char | 8 | Assigned | TUTESTCD | Constant `"TUMIDENT"` |
| 6 | TUTEST | Name of Measurement | Char | 40 | Assigned | TUTEST | Constant `"Tumor Identification"` |
| 7 | TUORRES | Result in Original Units | Char | 200 | Derived | — | See §Derivations.D1 |
| 8 | TULOC | Anatomical Location | Char | 200 | Predecessor | LOC | `str_to_upper(str_trim(ANATOMICAL_LOCATION))` |
| 9 | TUMETHOD | Method of Assessment | Char | 40 | Assigned | METHOD | Constant `"CT SCAN"` (raw does not carry method) |
| 10 | TUDTC | Date of Assessment | Char | 10 | Predecessor | ISO 8601 | `as.character(ASSESSMENT_DATE)` |
| 11 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 12 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |
| 13 | TUGRPID | Group ID (TARGET / NON-TARGET / NEW) | Char | 40 | Derived | TUGRPID | See §Derivations.D2 |
| 14 | TULINKID | Link Identifier (lesion key) | Char | 40 | Predecessor | — | `as.character(LESION_ID)` — e.g. `"TARGET_1"`, `"NEW_1"` |

## Derivations

### D1 — TUORRES (free-text identification string)
```r
TUORRES = paste(str_trim(LESION_TYPE), str_trim(ANATOMICAL_LOCATION), sep = " - ")
# Example: "TARGET - LIVER"
```

### D2 — TUGRPID (lesion classification)
```r
TUGRPID = case_when(
  str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT")                 ~ "TARGET",
  str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
  TRUE                                                                         ~ str_to_upper(str_trim(LESION_TYPE))
)
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| TUTESTCD | C100945 (TUTESTCD, Oncology) | Only `TUMIDENT` |
| TUTEST | C100946 (TUTEST, Oncology) | Only `"Tumor Identification"` |
| TUMETHOD | C85492 (METHOD) | `CT SCAN` only |
| TUGRPID | Study-specific (RECIST 1.1) | TARGET / NON-TARGET / NEW |
| TULOC | C74456 (LOC) (subset) | LIVER, LUNG, LYMPH NODE, BONE, etc. |
| VISIT, VISITNUM | Shared VISIT lookup | SCREENING, C1D1, C2D1…C8D1, EOT, FU1, FU2 |

## QC Checks

- [ ] `nrow(tu) ≈ 7,686` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`; every subject with any tumour record exists in DM.
- [ ] `TUSEQ` strictly increasing per `USUBJID` with no gaps from 1.
- [ ] `TULINKID` non-missing for every row.
- [ ] `TUGRPID ∈ {TARGET, NON-TARGET, NEW}` (no unmapped values).
- [ ] Per RECIST 1.1: at baseline (`VISITNUM == 0`) each subject has ≥ 1 TARGET lesion; max 5 TARGET lesions, max 2 per organ — **not enforced in QC** but flagged in `T-EFF-04` listings if violated.
- [ ] `TUDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, TUDTC, TULINKID)` reproduces row order.
- [ ] Every `TULINKID` referenced from `TR.TRLINKID` exists in TU (RELREC Relationship A integrity).
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-TU-spec.md` | `programs/sdtm/tu.R` | `datasets/sdtm/tu.parquet` |

Downstream consumers: `TR` (RELREC A via `TULINKID`), `RELREC` (`programs/sdtm/relrec.R`), `ADTR` (target-lesion ADaM), `ADRS` (BoR derivation).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §13 for the consolidated cross-domain pseudocode.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/tu.R`. |
