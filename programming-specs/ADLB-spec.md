# ADLB — Laboratory Test Results BDS — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADLB |
| **Label** | Laboratory Test Results |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per parameter per analysis timepoint |
| **Expected N** | 136,242 records (one per subject × parameter × collected timepoint, incl. windowed unscheduled draws) |
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
| 11 | AVAL | Analysis Value | Num | 8 | Derived | — | `as.numeric(LB.LBSTRESN)` — standardised (SI) numeric result |
| 12 | AVALC | Analysis Value (C) | Char | 16 | Derived | — | `as.character(LB.LBORRES)` |
| 13 | AVALU | Analysis Value Units | Char | 16 | Derived | — | `LB.LBSTRESU` (standardised unit) |
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
| 26 | ATOXGR | Analysis Toxicity Grade | Char | 2 | Derived | NCI CTCAE | NCI CTCAE v5.0 grade from an explicit `case_when` on `AVAL` vs `ANRHI`/`ANRLO` (see Key Derivation Notes); `ATOXGRN` = `as.integer(ATOXGR)` |
| 27 | BTOXGR | Baseline Toxicity Grade | Char | 2 | Derived | NCI CTCAE | Toxicity grade at baseline (ABLFL = "Y") record |
| 28 | ANL01FL | Analysis Flag 01 (analysis record per visit) | Char | 1 | Derived | NY | `flag_anl01()`: `"Y"` on the record closest to the visit target day per `USUBJID × PARAMCD × AVISIT` (ties → later `ADT`; missing `AVAL` never selected) — one analysis record per windowed visit (SAP §12.2) |
| 29 | DTYPE | Derivation Type | Char | 8 | Derived | — | NA for observed records; "LOCF" etc. if imputation used (none planned per SAP-D) |
| 30 | AVISIT | Analysis Visit | Char | 40 | Derived | — | `derive_avisit_windowed(ADY, VISIT, VISITNUM, "TREATMENT")`: nearest scheduled visit by `ADY` (SAP §12.2 window reference); `EOT`/follow-up kept by collected role |
| 31 | AVISITN | Analysis Visit (N) | Num | 8 | Derived | — | Numeric key of the windowed `AVISIT` (SDTM VISITNUM scheme: `Baseline` 0, `C1D1…C6D1` 1…7, `MAINT_CnD1` 9+n, `TUMOR_ASSESS_WKn` n, EOT/FU 900/901/902) — SAP §12.2 |

## Key Derivation Notes

**Baseline definition (SAP §12.3):** the last non-missing assessment on or before TRTSDT (`ADT ≤ TRTSDT`), per `USUBJID × PARAMCD`, ties broken by `LBSEQ` — date-based, not visit-restricted (the baseline may be a Screening or a C1D1 pre-dose draw). Exactly one baseline per subject × parameter (P21 AD0154); the `ABLFL = "Y"` record carries `AVISIT = "Baseline"`, `AVISITN = 0`. If no pre-treatment assessment exists, ABLFL is not assigned and the subject is retained but excluded from CHG/PCHG.

**Unscheduled visits:** off-schedule assessments (SDTM `VISIT="UNSCHEDULED"`, `VISITNUM=998` — e.g. an off-schedule recheck of an abnormal safety lab) are windowed by `ADY` to the nearest scheduled analysis visit (SAP §12.2); `ANL01FL` selects the record closest to the visit target, so an unscheduled recheck becomes the analysis record only when the scheduled draw is missing. The collected `VISIT` is retained for traceability, and unscheduled records still contribute to worst-post-baseline analyses (T-LB-01/02).

**ATOXGR:** NCI CTCAE v5.0 grades derived by an explicit `case_when` on `AVAL` against `ANRHI`/`ANRLO` (hand-coded in `adlb.R` — no `admiral::derive_var_atoxgr_dir()` / `metacore` codelist call). Graded parameters — chemistry `ALT`/`AST` (>ULN-3x / >3-5x / >5-20x / >20x), `ALP` (>ULN-2.5x / >2.5-5x / >5-20x / >20x), `BILI` (>ULN-1.5x / >1.5-3x / >3-10x / >10x), `CREAT` (>ULN-1.5x / >1.5-3x / >3-6x / >6x); haematology `HGB` (g/dL: ≥LLN=0 / <LLN-10.0=1 / <10.0-8.0=2 / <8.0=3 — no lab-based Grade 4 for anaemia) and `NEUT` (≥LLN / <LLN-1.5 / <1.5-1.0 / <1.0-0.5 / <0.5). `ATOXGRN` carries the integer form. **HGB unit-bug fix:** grading now uses g/dL thresholds (data unit); the earlier g/L thresholds (100/80/65) flagged every low haemoglobin as Grade 4 and were corrected.

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
| 0.3 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Reconciled against `adlb.R`: `AVAL`/`AVALU` sourced from `LB.LBSTRESN`/`LBSTRESU`; `ATOXGR` derived by explicit CTCAE v5 `case_when` (added `ALP`; documented `HGB` g/dL unit-bug fix; `ATOXGRN` noted); N corrected to 136,242. Confirmed unified `ANL01FL` (`flag_anl01`, one record per USUBJID×PARAMCD×AVISIT) and date-based baseline (`AVISIT="Baseline"`/`AVISITN=0`). |
