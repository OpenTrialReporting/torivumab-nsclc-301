# ADDV — Protocol Deviations Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADDV |
| **Label** | Protocol Deviations Analysis Dataset |
| **Class** | OCCDS |
| **Structure** | One record per deviation per subject |
| **Expected N** | ~337 records across 190 subjects (~50 MAJOR / ~287 MINOR) |
| **Key variables** | `STUDYID`, `USUBJID`, `DVSEQ` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADDV is the analysis-ready representation of SDTM.DV. It supports the protocol-deviation summary (T-DV-01) and feeds the per-protocol population definition in ADSL: `PPROTFL = "Y"` iff `SAFFL = "Y"` AND no MAJOR deviation. With real DV data the PP population drops from a placeholder 449 → ~412, making the T-EFF-08 PP-population OS analysis a meaningful sensitivity (HR ≈ 0.545 in PP vs ≈ 0.576 in ITT).

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, randomisation date, population flags, treatment arm |
| SDTM.DV | `sdtm/dv.parquet` | Deviation records (337 records, 190 subjects); `DVCAT` ∈ {MAJOR, MINOR} |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `DV.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `DV.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `DV.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `DV.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | PPROTFL | Per-Protocol Population Flag | Char | 1 | Derived | NY | Merged from ADSL.PPROTFL |
| 8 | DTHFL | Subject Death Flag | Char | 1 | Derived | NY | Merged from ADSL.DTHFL |
| 9 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 10 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 11 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 12 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 13 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTSDT |
| 14 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTEDT |
| 15 | DVSEQ | Sequence Number | Num | 8 | Predecessor | — | `DV.DVSEQ` |
| 16 | DVTERM | Reported Term for the Deviation | Char | 200 | Predecessor | — | `DV.DVTERM` |
| 17 | DVDECOD | Standardized Deviation Term | Char | 200 | Predecessor | — | `DV.DVDECOD` |
| 18 | DVCAT | Category for Deviation | Char | 20 | Predecessor | DVCAT | `DV.DVCAT` — values: MAJOR, MINOR |
| 19 | DVSCAT | Subcategory for Deviation | Char | 40 | Predecessor | — | `DV.DVSCAT` |
| 20 | DVSEV | Deviation Severity | Char | 20 | Derived | DVCAT | `= DVCAT` (alias for clarity in analyses) |
| 21 | DVSTDTC | Start Date/Time of Deviation | Char | 20 | Predecessor | — | `DV.DVSTDTC` |
| 22 | ADT | Analysis Date | Num | 8 | Derived | — | `as.Date(DVSTDTC)` |
| 23 | ADY | Analysis Relative Day | Num | 8 | Derived | — | `as.integer(ADT - RANDDT) + 1` (relative to randomisation) |
| 24 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `"Y"` for all records |

## Derivations

### D1 — DVSEV (deviation severity alias)

**Rule:** `DVSEV = DVCAT`. Provided as a self-documenting analysis variable so SAP tables can reference severity without needing to know SDTM nomenclature.

**Pseudocode:**
```r
DVSEV = DVCAT   # "MAJOR" or "MINOR"
```

### D2 — MAJDVFL conceptual flag (used by ADSL.PPROTFL upstream)

**Rule:** A subject has a "major deviation" iff at least one row in ADDV has `DVSEV = "MAJOR"`. ADSL derives PPROTFL using this set:

**Pseudocode (executed in ADSL, not ADDV):**
```r
major_dev_subjects <- addv %>%
  filter(DVSEV == "MAJOR") %>%
  distinct(USUBJID) %>%
  pull(USUBJID)

adsl <- adsl %>%
  mutate(
    PPROTFL = if_else(
      SAFFL == "Y" & !(USUBJID %in% major_dev_subjects),
      "Y", "N"
    )
  )
```

**Expected impact:** With 190 subjects affected (~50 MAJOR deviation subjects after dedup), PPROTFL drops from 449 → ~412 (`Y`).

## QC Checks

- [ ] `nrow(addv) == 337` (real SDTM.DV row count).
- [ ] `n_distinct(USUBJID) == 190`.
- [ ] `DVCAT` ∈ {"MAJOR", "MINOR"} for every row; no other values.
- [ ] `DVSEV == DVCAT` for every row.
- [ ] `sum(DVSEV == "MAJOR")` ≈ 50 (±10).
- [ ] `n_distinct(addv$USUBJID[addv$DVSEV == "MAJOR"]) == nrow(adsl) - sum(adsl$PPROTFL == "Y" & adsl$SAFFL == "Y")` (counts reconcile to ADSL.PPROTFL).
- [ ] `ADT >= RANDDT` for all rows (deviations cannot precede randomisation).
- [ ] All `ANL01FL == "Y"`; no NAs.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADDV-spec.md` → `programs/adam/addv.R` | `programs/adam/addv.R` → `datasets/adam/addv.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
