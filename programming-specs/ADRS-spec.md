# ADRS — Oncology Response Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADRS |
| **Label** | Oncology Response Analysis Dataset |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per response parameter per visit (plus one BOR/CBOR record per subject) |
| **Expected N** | ~6,300 records (estimated; OVR per visit + BOR + CBOR × 450 subjects) |
| **Key variables** | `USUBJID`, `PARAMCD`, `ADT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADRS supports all tumour response analyses: ORR (T-EFF-05), DCR (T-EFF-06), BOR table (T-EFF-07), response waterfall (F-EFF-03), and swimmer plot (F-EFF-06). Parameters derived: per-visit Overall Response (OVR), Best Overall Response (BOR), Confirmed BOR (CBOR), and Confirmed Disease Control (CBDCR). Responder flag (RSPFL) feeds ADTTE for DoR start date. Per CDISC Oncology Disease Response Supplement RECIST 1.1 (2023) and SAP §4.3.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags |
| ADTR | `adam/adtr.parquet` | SLD values; needed by `admiralonco::derive_param_bor()` for tumour size criteria |
| SDTM.RS | `sdtm/rs.parquet` | Per-visit overall response assessments (RSCAT = "OVERALL RESPONSE") |

## Parameters Derived

| PARAMCD | PARAM | Description |
|---|---|---|
| OVR | Overall Response by Investigator | Per-visit CR/PR/SD/PD/NE from SDTM RS |
| BOR | Best Overall Response | Best response ignoring confirmation; `admiralonco::derive_param_bor()` |
| CBOR | Confirmed Best Overall Response | CR/PR confirmed ≥28 days; SD ≥8 weeks from TRTSDT; `admiralonco::derive_param_confirmed_bor()` |
| CBDCR | Confirmed Disease Control | CBOR ∈ {CR, PR, SD}; binary yes/no |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `RS.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `RS.USUBJID` |
| 3 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL |
| 4 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL |
| 5 | TRT01P | Planned Treatment | Char | 40 | Derived | — | Merged from ADSL |
| 6 | TRT01A | Actual Treatment | Char | 40 | Derived | — | Merged from ADSL |
| 7 | TRTSDT | Date of First Dose | Date | — | Derived | — | Merged from ADSL |
| 8 | TRTEDT | Date of Last Dose | Date | — | Derived | — | Merged from ADSL |
| 9 | PARAM | Parameter Description | Char | 200 | Derived | — | See Parameters table above |
| 10 | PARAMCD | Parameter Code | Char | 8 | Derived | — | OVR / BOR / CBOR / CBDCR |
| 11 | VISIT | Visit Name | Char | 40 | Predecessor | — | `RS.VISIT` (NA for BOR/CBOR derived records) |
| 12 | VISITNUM | Visit Number | Num | 8 | Predecessor | — | `RS.VISITNUM` (NA for BOR/CBOR) |
| 13 | ADT | Analysis Date | Date | — | Derived | — | `admiral::derive_vars_dt(RS.RSDTC)` |
| 14 | AVAL | Analysis Value (numeric) | Num | 8 | Derived | — | CR=1, PR=2, SD=3, PD=4, NE=5 (ordinal ranking) |
| 15 | AVALC | Analysis Value (character) | Char | 8 | Derived | NRRESP | CR / PR / SD / PD / NE |
| 16 | RSPFL | Responder Flag | Char | 1 | Derived | NY | `if_else(PARAMCD == "CBOR" & AVALC %in% c("CR","PR"), "Y", NA)` |
| 17 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | "Y" for all records contributing to primary ORR analysis |

## Key Derivation Notes

**BOR:** `admiralonco::derive_param_bor()` — takes the best (lowest ordinal rank) OVR response across all post-baseline visits. Subjects with no post-baseline assessment: AVALC = "NE" per SAP-D-04 (non-responder imputation).

**CBOR:** `admiralonco::derive_param_confirmed_bor()` — CR or PR requires a second confirmatory OVR assessment ≥28 days later; SD requires onset ≥56 days (8 weeks) after TRTSDT. Confirmation period per SAP §4.3 and RECIST 1.1.

**ORR denominator:** All ITT subjects (ITTFL = "Y"), including those with no post-baseline assessment (counted as non-responders per SAP-D-04). RSPFL = "Y" only for confirmed CR/PR (CBOR-based).

**DCR:** Disease Control Rate = CR + PR + SD in CBOR. Derived as a separate CBDCR parameter; SD requires ≥8 weeks from TRTSDT.

## Shell Cross-Reference

| Shell ID | Shell title | ADRS variables used |
|---|---|---|
| T-EFF-05 | Objective Response Rate (ORR) | RSPFL, PARAMCD = "CBOR", AVALC, ITTFL |
| T-EFF-06 | Disease Control Rate (DCR) | PARAMCD = "CBDCR", AVALC, ITTFL |
| T-EFF-07 | Best Overall Response — Category Summary | PARAMCD = "CBOR", AVALC, ITTFL |
| F-EFF-03 | Waterfall Plot | RSPFL merged onto ADTR |
| F-EFF-06 | Swimmer Plot | RSPFL, ADT (date of first response) |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. BICR assessment handling deferred — add RSCAT = "BICR" parameter set if BICR data present. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. Add BICR OVR/BOR/CBOR if BICR collected. |
