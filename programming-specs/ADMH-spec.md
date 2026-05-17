# ADMH — Medical History Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADMH |
| **Label** | Medical History Analysis Dataset |
| **Class** | OCCDS |
| **Structure** | One record per medical history condition per subject |
| **Expected N** | ~2,061 |
| **Key variables** | `STUDYID`, `USUBJID`, `MHSEQ` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADMH supports the medical-history summary table (T-MH-01) and isolates the NSCLC primary-diagnosis row per subject (`PCANCERFL = "Y"`) needed by baseline disease-characteristic tables (T-DM-02). Ongoing-vs-prior conditions at study entry are flagged via `ONGOFL` / `PRIORFL` directly from `MHENRTPT`.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, treatment arm |
| SDTM.MH | `sdtm/mh.parquet` | Medical history conditions, MedDRA coding, end-relative-to-reference timepoint |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `MH.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `MH.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `MH.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `MH.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 8 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 9 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 10 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 11 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTSDT |
| 12 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTEDT |
| 13 | MHSEQ | Sequence Number | Num | 8 | Predecessor | — | `MH.MHSEQ` |
| 14 | MHTERM | Reported Term for the Medical History | Char | 200 | Predecessor | — | `MH.MHTERM` |
| 15 | MHDECOD | Standardized Medical History Term | Char | 200 | Predecessor | MedDRA PT | `MH.MHDECOD` |
| 16 | MHCAT | Category for Medical History | Char | 40 | Predecessor | — | `MH.MHCAT` |
| 17 | MHSTDTC | Start Date/Time of Medical History | Char | 20 | Predecessor | — | `MH.MHSTDTC` (may be partial: `YYYY` or `YYYY-MM`) |
| 18 | ASTDT | Analysis Start Date | Num | 8 | Derived | — | See §Derivations.D1 (no imputation; NA if MHSTDTC partial) |
| 19 | ASTDY | Analysis Start Relative Day | Num | 8 | Derived | — | `as.integer(ASTDT - TRTSDT) + 1` (NA where ASTDT NA) |
| 20 | PCANCERFL | Primary Cancer (NSCLC Diagnosis) Flag | Char | 1 | Derived | NY | See §Derivations.D2 |
| 21 | ONGOFL | Ongoing at Study Start Flag | Char | 1 | Derived | NY | `if_else(MHENRTPT == "ONGOING", "Y", "N")` |
| 22 | PRIORFL | Resolved Before Study Flag | Char | 1 | Derived | NY | `if_else(MHENRTPT == "BEFORE", "Y", "N")` |
| 23 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `"Y"` for all records |

## Derivations

### D1 — ASTDT (analysis start date, no imputation)

**Rule:** Per SAP §7, no imputation is performed for descriptive MH summaries. MHSTDTC values that are not full-precision dates (i.e. not 10-character `YYYY-MM-DD`) yield ASTDT = NA. ASTDY is NA wherever ASTDT is NA.

**Pseudocode:**
```r
ASTDT = as.Date(ifelse(nchar(MHSTDTC) == 10, MHSTDTC, NA_character_))
ASTDY = if_else(!is.na(ASTDT) & !is.na(TRTSDT),
                 as.integer(ASTDT - TRTSDT) + 1L,
                 NA_integer_)
```

**Edge cases:** Year-only and year-month dates are common in MH. Tables that need a count of subjects with prior history regardless of date should use PRIORFL, not ASTDT.

### D2 — PCANCERFL (primary cancer flag)

**Rule:** Flag `"Y"` on the NSCLC primary-diagnosis row. The SDTM convention is `MHCAT == "PRIMARY DIAGNOSIS"`.

**Pseudocode:**
```r
PCANCERFL = if_else(MHCAT == "PRIMARY DIAGNOSIS", "Y", "N")
```

**Edge cases:** Each subject is expected to have exactly one `PCANCERFL = "Y"` row (the NSCLC seed condition). QC asserts `n_distinct(USUBJID[PCANCERFL == "Y"]) == 450`.

## QC Checks

- [ ] `nrow(admh)` ≈ 2,061 (±5%); `n_distinct(USUBJID) == 450`.
- [ ] Every subject has exactly one `PCANCERFL == "Y"` row.
- [ ] `PCANCERFL`, `ONGOFL`, `PRIORFL`, `ANL01FL` ∈ {"Y", "N"}; no NAs.
- [ ] `ASTDY` is NA wherever `ASTDT` is NA, and finite elsewhere.
- [ ] No row has both `ONGOFL == "Y"` AND `PRIORFL == "Y"`.
- [ ] Variable labels, lengths, types match this spec.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADMH-spec.md` → `programs/adam/admh.R` | `programs/adam/admh.R` → `datasets/adam/admh.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
