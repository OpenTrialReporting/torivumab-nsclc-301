# ADDS — Subject Disposition Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADDS |
| **Label** | Subject Disposition Analysis Dataset |
| **Class** | OCCDS |
| **Structure** | One record per disposition event per subject |
| **Expected N** | ~1,350 (~3 records / subject: informed consent + randomisation + disposition event) |
| **Key variables** | `STUDYID`, `USUBJID`, `DSSEQ` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADDS rolls up SDTM.DS into the disposition flow used in CONSORT-style figures (F-DS-01) and the End-of-Study / End-of-Treatment summary table (T-DS-01). It collapses the granular `DSCAT` × `DSDECOD` cross to a tractable `DSCATGY` rollup (Consent / Randomisation / Completed / Discontinued / Other) and exposes `EOTFL` to identify the single end-of-treatment record per subject.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, treatment arm |
| SDTM.DS | `sdtm/ds.parquet` | Disposition events, milestones, dates |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `DS.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `DS.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `DS.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `DS.SITEID` |
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
| 15 | DSSEQ | Sequence Number | Num | 8 | Predecessor | — | `DS.DSSEQ` |
| 16 | DSTERM | Reported Term for the Disposition Event | Char | 200 | Predecessor | — | `DS.DSTERM` |
| 17 | DSDECOD | Standardized Disposition Term | Char | 40 | Predecessor | DSDECOD | `DS.DSDECOD` |
| 18 | DSCAT | Category for Disposition Event | Char | 40 | Predecessor | DSCAT | `DS.DSCAT` |
| 19 | DSSCAT | Subcategory for Disposition Event | Char | 40 | Predecessor | — | `DS.DSSCAT` |
| 20 | DSCATGY | Disposition Category Rollup | Char | 20 | Derived | DSCATGY | See §Derivations.D1 |
| 21 | EOTFL | End-of-Treatment Record Flag | Char | 1 | Derived | NY | See §Derivations.D2 |
| 22 | ADT | Analysis Date | Num | 8 | Derived | — | `as.Date(DSSTDTC)` |
| 23 | ADY | Analysis Relative Day | Num | 8 | Derived | — | `as.integer(ADT - TRTSDT) + 1` |
| 24 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `if_else(ITTFL == "Y", "Y", NA)` — ITT / all randomised subjects (SAP §12.2); NA otherwise |

## Derivations

### D1 — DSCATGY (disposition rollup)

**Rule:** Single-pass classification of every DS row into one of five buckets used by CONSORT.

**Pseudocode:**
```r
DSCATGY = case_when(
  DSCAT == "PROTOCOL MILESTONE" & DSDECOD == "INFORMED CONSENT OBTAINED" ~ "Consent",
  DSCAT == "PROTOCOL MILESTONE" & DSDECOD == "RANDOMIZED"                ~ "Randomisation",
  DSCAT == "DISPOSITION EVENT"  & DSDECOD == "COMPLETED"                 ~ "Completed",
  DSCAT == "DISPOSITION EVENT"                                            ~ "Discontinued",
  TRUE                                                                    ~ "Other"
)
```

### D2 — EOTFL (end-of-treatment flag)

**Rule:** Flag `"Y"` on every record where `DSCATGY ∈ {Completed, Discontinued}`; `"N"` otherwise. By design each subject has exactly one EOTFL='Y' record (driven by the disposition-event row).

**Pseudocode:**
```r
EOTFL = if_else(DSCATGY %in% c("Completed", "Discontinued"), "Y", "N")
```

**Edge cases:** Subjects ongoing at DCUTDT have no DISPOSITION EVENT row → no EOTFL='Y' record. Downstream tables join EOTFL='Y' as `LEFT JOIN`, defaulting status to `ONGOING`.

## QC Checks

- [ ] `nrow(adds)` ≈ 1,350 (within ±5%); `n_distinct(USUBJID) == 450`.
- [ ] Every subject has exactly one `DSCATGY = "Consent"` record AND one `"Randomisation"` record.
- [ ] `sum(EOTFL == "Y") == n_distinct(USUBJID[EOTFL == "Y"])` (at most one EOTFL='Y' per subject).
- [ ] `EOTFL` ∈ {"Y", "N"} (no NAs); `ANL01FL` ∈ {"Y", NA} (`"Y"` on all ITT rows).
- [ ] `ADT >= RFICDT` for non-Consent records (i.e. dispositions follow consent).
- [ ] Variable labels, lengths, types match this spec.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADDS-spec.md` → `programs/adam/adds.R` | `programs/adam/adds.R` → `datasets/adam/adds.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refreshed to current pipeline: ANL01FL now = ITT population (`ITTFL`) as an explicit Y/null flag (was bare `"Y"`); N confirmed 1,350. |
