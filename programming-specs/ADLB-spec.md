# ADLB — Laboratory Test Results BDS — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADLB |
| **Label** | Laboratory Test Results |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per parameter per analysis timepoint |
| **Expected N** | ~27,000 records (estimated; ~60 lab parameters × 450 subjects × ~1 record/visit) |
| **Key variables** | `USUBJID`, `PARAMCD`, `VISITNUM`, `ADT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADLB supports laboratory abnormality analyses: shift tables (T-LB-01) and Grade ≥3 lab abnormalities by CTCAE (T-LB-02). Baseline and change from baseline are derived for all parameters. CTCAE toxicity grading (ATOXGR) is derived for haematology and chemistry panels.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, treatment arm |
| SDTM.LB | `sdtm/lb.parquet` | Lab results, units, normal ranges, visit dates |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `LB.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `LB.USUBJID` |
| 3 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 4 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 5 | TRT01P | Planned Treatment | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 6 | TRT01A | Actual Treatment | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 7 | TRTSDT | Date of First Dose | Date | — | Derived | — | Merged from ADSL.TRTSDT |
| 8 | TRTEDT | Date of Last Dose | Date | — | Derived | — | Merged from ADSL.TRTEDT |
| 9 | PARAM | Parameter Description | Char | 200 | Derived | — | Mapped from `LB.LBTEST` via PARAMCD lookup |
| 10 | PARAMCD | Parameter Code | Char | 8 | Derived | — | Mapped from `LB.LBTESTCD` per ADaMIG lab PARAMCD convention |
| 11 | AVAL | Analysis Value | Num | 8 | Derived | — | `as.numeric(LB.LBORRES)`; SI units preferred |
| 12 | AVALC | Analysis Value (C) | Char | 16 | Derived | — | `LB.LBORRES` (character) |
| 13 | AVALU | Analysis Value Units | Char | 16 | Derived | — | `LB.LBORRESU` |
| 14 | ANRLO | Analysis Normal Range Lower Limit | Num | 8 | Predecessor | — | `as.numeric(LB.LBSTNRLO)` |
| 15 | ANRHI | Analysis Normal Range Upper Limit | Num | 8 | Predecessor | — | `as.numeric(LB.LBSTNRHI)` |
| 16 | LBDTC | Date/Time of Specimen Collection | Char | 20 | Predecessor | — | `LB.LBDTC` |
| 17 | ADT | Analysis Date | Date | — | Derived | — | `admiral::derive_vars_dt(LBDTC)` |
| 18 | VISIT | Visit Name | Char | 40 | Predecessor | — | `LB.VISIT` |
| 19 | VISITNUM | Visit Number | Num | 8 | Predecessor | — | `LB.VISITNUM` |
| 20 | ABLFL | Baseline Record Flag | Char | 1 | Derived | NY | Last non-missing AVAL on or before TRTSDT: `admiral::derive_var_extreme_flag(mode="last")` |
| 21 | BASE | Baseline Value | Num | 8 | Derived | — | `admiral::derive_var_base()` from ABLFL record |
| 22 | CHG | Change from Baseline | Num | 8 | Derived | — | `admiral::derive_var_chg()`: AVAL − BASE |
| 23 | PCHG | Percent Change from Baseline | Num | 8 | Derived | — | `admiral::derive_var_pchg()`: (CHG / BASE) × 100 |
| 24 | BNRIND | Baseline Reference Range Indicator | Char | 8 | Derived | BNRIND | L/N/H based on BASE vs ANRLO/ANRHI |
| 25 | ANRIND | Analysis Reference Range Indicator | Char | 8 | Derived | ANRIND | L/N/H based on AVAL vs ANRLO/ANRHI |
| 26 | ATOXGR | Analysis Toxicity Grade | Char | 2 | Derived | NCI CTCAE | `admiral::derive_var_atoxgr_dir()` using NCI CTCAE v5 grading criteria |
| 27 | BTOXGR | Baseline Toxicity Grade | Char | 2 | Derived | NCI CTCAE | Toxicity grade at baseline (ABLFL = "Y") record |
| 28 | ANL01FL | Analysis Flag 01 (on-treatment records) | Char | 1 | Derived | NY | `if_else(!is.na(AVAL) & ADT >= TRTSDT, "Y", NA)` |
| 29 | DTYPE | Derivation Type | Char | 8 | Derived | — | NA for observed records; "LOCF" etc. if imputation used (none planned per SAP-D) |

## Key Derivation Notes

**Baseline definition:** Last non-missing assessment on or before TRTSDT. If no pre-treatment assessment exists, ABLFL is not assigned. Subjects without a baseline are still retained in ADLB but excluded from CHG/PCHG analyses.

**ATOXGR:** NCI CTCAE v5 grading applied to haematology (haemoglobin, neutrophils, platelets, lymphocytes) and chemistry (ALT, AST, bilirubin, creatinine, alkaline phosphatase) panels. Uses `admiral::derive_var_atoxgr_dir()`. CTCAE thresholds stored in a reference codelist (to be loaded via `metacore`).

**No LOCF:** Per SAP §7 (SAP-D decision on missing data) — no last-observation-carried-forward imputation. DTYPE is not set to "LOCF".

**Units:** SI units used for all numeric AVAL values. Conversion from conventional units applied where LBSTRESU differs from SI (e.g. creatinine mg/dL → μmol/L). Lookup table to be provided in Phase 5.

## Shell Cross-Reference

| Shell ID | Shell title | ADLB variables used |
|---|---|---|
| T-LB-01 | Haematology and Chemistry Shift Tables | ABLFL, BNRIND, ANRIND, PARAMCD, ANL01FL |
| T-LB-02 | Grade ≥3 Laboratory Abnormalities (CTCAE) | ATOXGR ≥ 3, BTOXGR, PARAMCD, TRTEMFL (via ADAE cross-ref) |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. CTCAE thresholds and unit conversion table deferred to Phase 5. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. Add PARAMCD codelist mapping. |
