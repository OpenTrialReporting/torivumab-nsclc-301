# ADTTE — Time-to-Event Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADTTE |
| **Label** | Time-to-Event Analysis Dataset |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per TTE parameter |
| **Expected N** | ~1,800 records (4 parameters × 450 subjects; DoR/TTR restricted to responders ~225) |
| **Key variables** | `USUBJID`, `PARAMCD` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADTTE supports all time-to-event efficacy analyses: OS (T-EFF-01, F-EFF-01), PFS (T-EFF-03, F-EFF-02), DoR (T-EFF-08), TTR (T-EFF-09), and the subgroup forest plots (F-EFF-05). Censoring rules follow FDA 2018 guidance and are fully specified in SAP §4.1–§4.4. Parameters: OS, PFS, DOR, TTR.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, death flag |
| ADRS | `adam/adrs.parquet` | PD date (for PFS event), first response date (for DOR start, TTR event) |
| SDTM.DS | `sdtm/ds.parquet` | Disposition dates (last study contact, discontinuation) |
| SDTM.DD | `sdtm/dd.parquet` | Death date (primary source for OS event date) |

## Parameters Derived

| PARAMCD | PARAM | Start Date | Event | Censor | Population |
|---|---|---|---|---|---|
| OS | Overall Survival | TRTSDT | Death (any cause) | Last known alive date = max(last contact, last assessment, DCO) | ITT |
| PFS | Progression-Free Survival | TRTSDT | Confirmed PD or death (whichever first) | Per FDA 2018 hierarchy (SAP-D-02, SAP-D-03) | ITT |
| DOR | Duration of Response | First confirmed CR/PR date (RSPDT) | PD or death | Last adequate assessment if no PD/death | Confirmed responders (RSPFL="Y") |
| TTR | Time to Response | TRTSDT | First confirmed CR/PR | Last adequate assessment if no response | ITT (non-responders censored) |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | From ADSL |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | From ADSL |
| 3 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL |
| 4 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL |
| 5 | TRT01P | Planned Treatment | Char | 40 | Derived | — | Merged from ADSL |
| 6 | TRT01A | Actual Treatment | Char | 40 | Derived | — | Merged from ADSL |
| 7 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL |
| 8 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL |
| 9 | TRTSDT | Date of First Dose | Date | — | Derived | — | Merged from ADSL |
| 10 | TRTEDT | Date of Last Dose | Date | — | Derived | — | Merged from ADSL |
| 11 | PARAM | Parameter Description | Char | 200 | Derived | — | See Parameters table |
| 12 | PARAMCD | Parameter Code | Char | 8 | Derived | — | OS / PFS / DOR / TTR |
| 13 | ADT | Analysis Date (event or censor) | Date | — | Derived | — | `admiral::derive_param_tte()` — event or censor date |
| 14 | AVAL | Analysis Value (days) | Num | 8 | Derived | — | `ADT − TRTSDT` (for OS/PFS/TTR); `ADT − RSPDT` (for DOR); in days |
| 15 | AVALU | Unit of AVAL | Char | 8 | Derived | — | "DAYS" |
| 16 | CNSR | Censoring Indicator | Num | 8 | Derived | — | 0 = event, 1 = censored; set by `admiral::derive_param_tte()` |
| 17 | EVNTDESC | Event or Censoring Description | Char | 200 | Derived | — | e.g. "DEATH", "PROGRESSIVE DISEASE", "CENSORED — LAST KNOWN ALIVE" |
| 18 | SRCDOM | Source Data Domain | Char | 8 | Derived | — | DD / ADRS / DS / ADSL |
| 19 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | "Y" for all records; primary analysis population per PARAMCD |

## Key Derivation Notes

**OS censoring (SAP-D-01):** Last known alive date = max(last study contact date from DS, last response assessment date from RS, data cutoff date). Uses `admiral::derive_param_tte()` with multiple censor_source() inputs. Subjects lost to follow-up before DCO are censored at last known alive date.

**PFS event hierarchy (SAP-D-02, SAP-D-03):**
1. Confirmed PD (RSCAT = "OVERALL RESPONSE", AVALC = "PD") on or before DCO
2. Death without confirmed PD
3. Censor at: (a) last adequate assessment if new anti-cancer therapy starts (SAP-D-02), or (b) last adequate assessment before ≥2 consecutive missed visits (SAP-D-03), or (c) last adequate assessment

**DOR start date:** Date of first confirmed CR or PR (RSPDT from ADRS, PARAMCD = "CBOR"). Only subjects with RSPFL = "Y" receive a DOR record. Subjects who respond and subsequently have PD/death: event. Subjects who respond but have no PD/death: censored at last adequate response assessment.

**AVAL in days:** `as.numeric(ADT − TRTSDT)` for OS/PFS/TTR; `as.numeric(ADT − RSPDT)` for DOR. Months can be derived as AVAL / 30.4375 in TFL scripts — not stored in ADTTE.

**Subgroup variables:** Forest plot subgroups (REGION, HISTSCAT, BECOG, PDL1GR) merged from ADSL. These must be present on ADSL before ADTTE is finalised (see ADSL open items: BECOG, PDL1GR).

## Shell Cross-Reference

| Shell ID | Shell title | ADTTE variables used |
|---|---|---|
| T-EFF-01 | Overall Survival — KM Table | OS: AVAL, CNSR, TRT01P, ITTFL |
| T-EFF-03 | Progression-Free Survival — KM Table | PFS: AVAL, CNSR, TRT01P, ITTFL |
| T-EFF-08 | Duration of Response | DOR: AVAL, CNSR, TRT01P, RSPFL |
| T-EFF-09 | Time to Response | TTR: AVAL, CNSR, TRT01P, ITTFL |
| F-EFF-01 | KM Curve — Overall Survival | OS: AVAL, CNSR, TRT01P |
| F-EFF-02 | KM Curve — Progression-Free Survival | PFS: AVAL, CNSR, TRT01P |
| F-EFF-05 | Forest Plot — Subgroup OS/PFS HRs | OS/PFS: AVAL, CNSR, TRT01PN + subgroup flags |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. BECOG and PDL1GR must be added to ADSL before subgroup forest plot can be finalised. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. Validate OS/PFS HR against protocol assumptions (HR 0.65 / 0.55). |
