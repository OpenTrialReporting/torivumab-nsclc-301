# ADTR — Tumor Results BDS — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADTR |
| **Label** | Tumor Results |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per tumor parameter per assessment visit |
| **Expected N** | ~5,400 records (estimated; ~12 visits × 450 subjects × 1 SLD record/visit) |
| **Key variables** | `USUBJID`, `PARAMCD`, `VISITNUM`, `ADT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADTR is an intermediate oncology BDS dataset that derives per-visit Sum of Longest Diameters (SLD) from SDTM TR/TU. It feeds ADRS for BOR/confirmed response derivation and is the source for waterfall (F-EFF-03) and spider (F-EFF-04) figures. Per CDISC Oncology Disease Response Supplement (RECIST 1.1, 2023).

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, treatment arm |
| SDTM.TR | `sdtm/tr.parquet` | Target lesion diameter measurements (TRTESTCD = "LDIAM") |
| SDTM.TU | `sdtm/tu.parquet` | Tumor identifier records (links lesion to anatomical location) |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `TR.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `TR.USUBJID` |
| 3 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 4 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 5 | TRT01P | Planned Treatment | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 6 | TRT01A | Actual Treatment | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 7 | TRTSDT | Date of First Dose | Date | — | Derived | — | Merged from ADSL.TRTSDT |
| 8 | TRTEDT | Date of Last Dose | Date | — | Derived | — | Merged from ADSL.TRTEDT |
| 9 | PARAM | Parameter Description | Char | 200 | Derived | — | "Sum of Longest Diameters (mm)" for PARAMCD = "SDIAM" |
| 10 | PARAMCD | Parameter Code | Char | 8 | Derived | — | "SDIAM" (per CDISC RECIST 1.1 supplement) |
| 11 | VISIT | Visit Name | Char | 40 | Predecessor | — | `TR.VISIT` |
| 12 | VISITNUM | Visit Number | Num | 8 | Predecessor | — | `TR.VISITNUM` |
| 13 | ADT | Analysis Date | Date | — | Derived | — | `admiral::derive_vars_dt(TR.TRDTC)` |
| 14 | AVAL | Analysis Value (SLD, mm) | Num | 8 | Derived | — | Sum of `TR.TRSTRESN` for TRTESTCD = "LDIAM" and TRGRPID = "TARGET" per visit |
| 15 | ABLFL | Baseline Record Flag | Char | 1 | Derived | NY | Last non-missing SLD on or before TRTSDT |
| 16 | BASE | Baseline SLD Value | Num | 8 | Derived | — | `admiral::derive_var_base()` from ABLFL record |
| 17 | CHG | Change from Baseline (mm) | Num | 8 | Derived | — | `admiral::derive_var_chg()`: AVAL − BASE |
| 18 | PCHG | Percent Change from Baseline | Num | 8 | Derived | — | `admiral::derive_var_pchg()`: (CHG / BASE) × 100 |
| 19 | NADIR | Minimum Post-Baseline SLD | Num | 8 | Derived | — | `min(AVAL)` for ADT > TRTSDT, merged onto all records per subject |
| 20 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `if_else(!is.na(AVAL), "Y", NA)` |

## Key Derivation Notes

**SLD computation:** Sum of `TR.TRSTRESN` (longest diameter in mm) across all target lesions (TRGRPID = "TARGET", TRTESTCD = "LDIAM") at each visit. A subject must have ≥1 measurable target lesion at baseline per RECIST 1.1. Visits with missing measurements for any lesion are handled per SAP §4.3 (partial SLD documented with note).

**Baseline:** Last assessment on or before TRTSDT with at least one measurable target lesion. Naïve screen failures without a post-randomisation assessment are retained with ABLFL = NA.

**Nadir:** Minimum post-baseline SLD across all on-treatment visits. Used in waterfall figure (best % change = (min(AVAL) − BASE) / BASE × 100) and as denominator in RECIST response thresholds.

**Non-target and new lesions:** Handled separately in SDTM RS; not summed in ADTR. ADTR is exclusively target lesion SLD. Overall response (BOR) incorporates non-target and new lesion status in ADRS.

## Shell Cross-Reference

| Shell ID | Shell title | ADTR variables used |
|---|---|---|
| F-EFF-03 | Waterfall Plot — Best % Change from Baseline in SLD | PCHG (at NADIR), TRT01P, RSPFL (from ADRS) |
| F-EFF-04 | Spider Plot — % Change from Baseline by Visit | PCHG by ADT, TRT01P, USUBJID |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. Partial SLD handling to be confirmed with CDM. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. Add non-target lesion parameter if needed. |
