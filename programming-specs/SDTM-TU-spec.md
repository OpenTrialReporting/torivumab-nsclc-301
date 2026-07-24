# TU — Tumor Identification — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | TU |
| **Label** | Tumor Identification |
| **Class** | FINDINGS |
| **Structure** | One record per identified lesion per assessment visit per subject |
| **Expected N** | 9,012 |
| **Key variables** | `STUDYID`, `USUBJID`, `TUSEQ`; group key `TULNKID` |
| **SDTMIG version** | CDISC SDTM Oncology Disease Response Supplement §9.1 (RECIST 1.1, 2023) on SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

TU captures the **identification** of each lesion (target, non-target, or new) at every tumour assessment visit. It establishes the lesion identity that `TR` (measurements / responses) and `RS` (overall response) reference via `TULNKID` (RELREC Relationship A — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §21.1). TU does **not** carry the measurements themselves — those live in `TR`. The domain is the SDTM source for `ADTR` (target-lesion analysis) and feeds the BoR / BoTL derivations in `ADRS`.

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
| 4 | TUSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, TUDTC, TULNKID)` |
| 5 | TUTESTCD | Short Name of Measurement | Char | 8 | Assigned | TUTESTCD | Constant `"TUMIDENT"` |
| 6 | TUTEST | Name of Measurement | Char | 40 | Assigned | TUTEST | Constant `"Tumor Identification"` |
| 7 | TUORRES | Result in Original Units | Char | 200 | Derived | — | See §Derivations.D1 |
| 8 | TULOC | Anatomical Location | Char | 200 | Derived | LOC | `dplyr::recode()` of upper-trimmed `ANATOMICAL_LOCATION` to CDISC Anatomical Location submission values (P21 CT2002) — see §Derivations.D3 |
| 9 | TUMETHOD | Method of Assessment | Char | 40 | Assigned | METHOD | Constant `"CT SCAN"` (raw does not carry method) |
| 10 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `TUDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `TUDTC` missing/partial |
| 11 | TUDTC | Date of Assessment | Char | 10 | Predecessor | ISO 8601 | `as.character(ASSESSMENT_DATE)` |
| 12 | TUDY | Study Day of Assessment | Num | 8 | Derived | — | Study day of `TUDTC` vs `DM.RFSTDTC`: `TUDTC − RFSTDTC + 1` on/after RFSTDTC, else `TUDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 13 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 14 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |
| 15 | TUGRPID | Group ID (TARGET / NON-TARGET / NEW) | Char | 40 | Derived | TUGRPID | See §Derivations.D2 |
| 16 | TULNKID | Link Identifier (lesion key) | Char | 40 | Predecessor | — | `as.character(LESION_ID)` — e.g. `"TARGET_1"`, `"NEW_1"` |

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

### D3 — TULOC (CDISC Anatomical Location recode)
**Rule:** Upper-trimmed raw `ANATOMICAL_LOCATION` is recoded to CDISC Anatomical Location (C74456 / LOC) submission values so P21 CT2002 passes (raw free-text values are not all submission-valid).
```r
TULOC = dplyr::recode(str_to_upper(str_trim(ANATOMICAL_LOCATION)),
  "BONE - PELVIS" = "PELVIC BONE", "BONE - RIB" = "RIB", "BONE - VERTEBRA" = "VERTEBRA",
  "LEFT LUNG" = "LUNG", "RIGHT LUNG" = "LUNG",
  "LEFT LOWER LOBE" = "LUNG, LEFT LOWER LOBE", "RIGHT LOWER LOBE" = "LUNG, RIGHT LOWER LOBE",
  "RIGHT UPPER LOBE" = "LUNG, RIGHT UPPER LOBE",
  "LYMPH NODE - AXILLARY" = "AXILLARY LYMPH NODE", "LYMPH NODE - HILAR" = "HILAR LYMPH NODE",
  "LYMPH NODE - MEDIASTINAL" = "MEDIASTINAL LYMPH NODE",
  "LYMPH NODE - SUPRACLAVICULAR" = "SUPRACLAVICULAR LYMPH NODE",
  "PERICARDIAL EFFUSION" = "PERICARDIUM", "PLEURAL EFFUSION" = "PLEURA")
# Values not listed pass through unchanged (already submission-valid).
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| TUTESTCD | C100945 (TUTESTCD, Oncology) | Only `TUMIDENT` |
| TUTEST | C100946 (TUTEST, Oncology) | Only `"Tumor Identification"` |
| TUMETHOD | C85492 (METHOD) | `CT SCAN` only |
| TUGRPID | Study-specific (RECIST 1.1) | TARGET / NON-TARGET / NEW |
| TULOC | C74456 (LOC) (subset) | Recoded to submission values per §D3 (e.g. LUNG, VERTEBRA, MEDIASTINAL LYMPH NODE, PELVIC BONE) |
| VISIT, VISITNUM | Shared VISIT lookup | SCREENING, C1D1, C2D1…C8D1, EOT, FU1, FU2 |

## QC Checks

- [ ] `nrow(tu) ≈ 9,012` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`; every subject with any tumour record exists in DM.
- [ ] `TUSEQ` strictly increasing per `USUBJID` with no gaps from 1.
- [ ] `TULNKID` non-missing for every row.
- [ ] `TUGRPID ∈ {TARGET, NON-TARGET, NEW}` (no unmapped values).
- [ ] Per RECIST 1.1: at baseline (`VISITNUM == 0`) each subject has ≥ 1 TARGET lesion; max 5 TARGET lesions, max 2 per organ — **not enforced in QC** but flagged in `T-EFF-04` listings if violated.
- [ ] `TUDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, TUDTC, TULNKID)` reproduces row order.
- [ ] Every `TULNKID` referenced from `TR.TRLNKID` exists in TU (RELREC Relationship A integrity).
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-TU-spec.md` | `programs/sdtm/tu.R` | `datasets/sdtm/tu.parquet` |

Downstream consumers: `TR` (RELREC A via `TULNKID`), `RELREC` (`programs/sdtm/relrec.R`), `ADTR` (target-lesion ADaM), `ADRS` (BoR derivation).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §13 for the consolidated cross-domain pseudocode.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/tu.R`. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refresh vs current `tu.R`: Expected N 7,686 → 9,012; link-id variable named `TULNKID` (was `TULINKID`) throughout; `TULOC` now recoded to CDISC Anatomical Location submission values (new §D3, P21 CT2002) rather than plain upper-trim. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `TUDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/tu.parquet`. |
