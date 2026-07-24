# ADTTE — Time-to-Event Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADTTE |
| **Label** | Time-to-Event Analysis Dataset |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per TTE parameter |
| **Expected N** | 2,377 records (OS, OSWOT, PFS, PFSINV, TTR at 450 subjects each + DOR restricted to confirmed responders) |
| **Key variables** | `USUBJID`, `PARAMCD` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADTTE supports all time-to-event efficacy analyses: OS (T-EFF-01, F-EFF-01), OSWOT (T-EFF-12, sensitivity estimand E1b), PFS (T-EFF-03, F-EFF-02), DoR (T-EFF-08), TTR (T-EFF-09), and the subgroup forest plots (F-EFF-05). PFS is derived from BICR (Independent Assessor) PD dates for the primary analysis (estimand E2), with PFSINV derived from Investigator PD dates as the sensitivity analysis (estimand E2a). Censoring rules follow FDA 2018 guidance and are fully specified in SAP §4.1–§4.4, §13.4 and §13.5. Parameters: OS, OSWOT, PFS, PFSINV, DOR, TTR.

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
| OSWOT | Overall Survival - While-on-Treatment Sensitivity | TRTSDT | Death on or within 30 days of last study treatment (TRTEDT + 30 days) | min(TRTEDT + 30 days, LSTALVDT). Synthetic data limitation: no subsequent anti-cancer therapy is captured in CM, so the full SAP §13.4 censoring rule (min of TRTEDT + 30d AND subsequent therapy start) reduces to TRTEDT + 30d only. | ITT |
| PFS | Progression-Free Survival (BICR) | TRTSDT | Confirmed PD (BICR / RSEVAL="INDEPENDENT ASSESSOR") or death (whichever first) | Per FDA 2018 hierarchy (SAP-D-02, SAP-D-03) | ITT |
| PFSINV | Progression-Free Survival (Investigator) | TRTSDT | Confirmed PD (Investigator / RSEVAL="INVESTIGATOR") or death (whichever first) | Per FDA 2018 hierarchy (SAP-D-02, SAP-D-03) | ITT |
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
| 12 | PARAMCD | Parameter Code | Char | 8 | Derived | — | OS / OSWOT / PFS / PFSINV / DOR / TTR |
| 13 | STARTDT | Time-to-Event Origin Date | Date | — | Derived | — | `TRTSDT` (OS/OSWOT/PFS/PFSINV/TTR); `RSPDT` (DOR); TTE origin per P21 AD0245 |
| 14 | ADT | Analysis Date (event or censor) | Date | — | Derived | — | Event or censor date, set per parameter |
| 15 | AVAL | Analysis Value (days) | Num | 8 | Derived | — | `ADT − STARTDT` in days (STARTDT = TRTSDT for OS/OSWOT/PFS/PFSINV/TTR; RSPDT for DOR) |
| 16 | AVALU | Unit of AVAL | Char | 8 | Derived | — | "DAYS" |
| 17 | CNSR | Censoring Indicator | Num | 8 | Derived | — | 0 = event, 1 = censored |
| 18 | EVNTDESC | Event or Censoring Description | Char | 200 | Derived | — | e.g. "DEATH", "PROGRESSIVE DISEASE", "CENSORED - LAST KNOWN ALIVE" |
| 19 | SRCDOM | Source Data Domain | Char | 8 | Derived | — | DD / ADRS / RS-INV / DS / ADSL |
| 20 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `if_else(ITTFL == "Y", "Y", NA)` — ITT population (SAP §12.2); NA otherwise |

## Key Derivation Notes

**OS censoring (SAP-D-01):** Last known alive date = max(last study treatment date TRTEDT, last known alive date LSTALVDT from ADSL). Subjects lost to follow-up before DCO are censored at last known alive date. Derived by explicit event/censor logic in `adtte.R` (not `derive_param_tte()`).

**PFS reader (SAP §13.5):** PFS (primary, estimand E2) uses BICR PD dates — earliest `RS.RSDTC` where `RSEVAL = "INDEPENDENT ASSESSOR"` and `RSSTRESC = "PD"`. PFSINV (sensitivity, estimand E2a) uses the same logic on Investigator records (`RSEVAL = "INVESTIGATOR"`). Both censor at the last overall-response assessment date for the matching reader (else the OS censor). BICR vs Investigator discordance is ~10%.

**PFS event hierarchy (SAP-D-02, SAP-D-03):**
1. Confirmed PD (RSSTRESC = "PD") on or before DCO
2. Death without confirmed PD
3. Censor at: (a) last adequate assessment if new anti-cancer therapy starts (SAP-D-02), or (b) last adequate assessment before ≥2 consecutive missed visits (SAP-D-03), or (c) last adequate assessment

**DOR start date:** Date of first confirmed CR or PR (RSPDT from ADRS, PARAMCD = "CBOR"). Only subjects with RSPFL = "Y" receive a DOR record. Subjects who respond and subsequently have PD/death: event. Subjects who respond but have no PD/death: censored at last adequate response assessment.

**AVAL in days:** `as.numeric(ADT − STARTDT)` where STARTDT = TRTSDT for OS/OSWOT/PFS/PFSINV/TTR and STARTDT = RSPDT for DOR. Months can be derived as AVAL / 30.4375 in TFL scripts — not stored in ADTTE.

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
| 0.3 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refreshed to current pipeline: added PFSINV (Investigator sensitivity, RSEVAL split); PFS now BICR-primary; added STARTDT variable; ANL01FL = ITT population; Expected N corrected to 2,377; removed stale `derive_param_tte()` references (code uses explicit logic). |
