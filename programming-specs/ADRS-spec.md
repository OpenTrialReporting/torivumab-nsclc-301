# ADRS — Oncology Response Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADRS |
| **Label** | Oncology Response Analysis Dataset |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per response parameter per visit (plus one BOR/CBOR record per subject) |
| **Expected N** | 3,569 records (per-visit OVR + one BOR + one CBOR per subject) |
| **Key variables** | `USUBJID`, `PARAMCD`, `ADT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADRS supports all tumour response analyses: ORR (T-EFF-05), DCR (T-EFF-06), BOR table (T-EFF-07), response waterfall (F-EFF-03), and swimmer plot (F-EFF-06). Parameters derived: per-visit Overall Response (OVR), Best Overall Response (BOR), and Confirmed BOR (CBOR); disease-control rate (DCR) is computed from CBOR ∈ {CR, PR, SD} at analysis time and is not stored as a separate ADRS parameter. Responder flag (RSPFL) feeds ADTTE for DoR start date. Per CDISC Oncology Disease Response Supplement RECIST 1.1 (2023) and SAP §4.3.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags |
| ADTR | `adam/adtr.parquet` | SLD / tumour-size values available for response cross-checks (RECIST 1.1 tumour-size criteria) |
| SDTM.RS | `sdtm/rs.parquet` | Per-visit overall response assessments; ADRS filters `RSEVAL == "INVESTIGATOR"` (SDTM.RS also carries BICR / `INDEPENDENT ASSESSOR` records, consumed by ADTTE) |

## Parameters Derived

| PARAMCD | PARAM | Description |
|---|---|---|
| OVR | Overall Response by Investigator (RECIST 1.1) | Per-visit CR/PR/SD/PD/NE from SDTM RS (`RSEVAL == "INVESTIGATOR"`) |
| BOR | Best Overall Response (RECIST 1.1) | Best (lowest ordinal rank) OVR across post-baseline visits; SD counts only if ≥8 weeks (`ADY ≥ 57`) from TRTSDT; no post-baseline assessment ⇒ NE |
| CBOR | Confirmed Best Overall Response (RECIST 1.1) | CR/PR require a confirmatory OVR of equal-or-better ≥28 days later; SD ≥8 weeks from TRTSDT; PD needs no confirmation |

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
| 10 | PARAMCD | Parameter Code | Char | 8 | Derived | — | OVR / BOR / CBOR |
| 11 | VISIT | Visit Name | Char | 40 | Predecessor | — | `RS.VISIT` (NA for subject-level BOR/CBOR). Retained for traceability; SDTM `VISITNUM` dropped — RS did not collect it (100% null) |
| 12 | AVISIT | Analysis Visit | Char | 40 | Derived | — | `derive_avisit_windowed(ADY, VISIT, ., "TUMOUR")`: nearest RECIST assessment by `ADY` (SAP §12.2); NA for subject-level BOR/CBOR |
| 13 | AVISITN | Analysis Visit (N) | Num | 8 | Derived | — | Numeric key of the windowed `AVISIT` (`Baseline` 0, `TUMOR_ASSESS_WKn` n) — SAP §12.2 |
| 14 | ADT | Analysis Date | Date | — | Derived | — | `admiral::derive_vars_dt(RS.RSDTC)` |
| 15 | AVAL | Analysis Value (numeric) | Num | 8 | Derived | — | CR=1, PR=2, SD=3, PD=4, NE=5 (ordinal ranking) |
| 16 | AVALC | Analysis Value (character) | Char | 8 | Derived | NRRESP | CR / PR / SD / PD / NE |
| 17 | RSPFL | Responder Flag | Char | 1 | Derived | NY | `"Y"`/`"N"` for BOR and CBOR (`AVALC ∈ {CR, PR}` ⇒ `"Y"`); `NA` for per-visit OVR. Confirmed responders (CBOR) feed ADTTE DoR start |
| 18 | ANL01FL | Analysis Flag 01 (analysis record per visit) | Char | 1 | Derived | NY | `flag_anl01()` — the shared rule (SAP §12.2): one record per `USUBJID × PARAMCD × AVISIT` for the by-visit `OVR` records, and one per `USUBJID × PARAMCD` for the subject-level `BOR`/`CBOR` records (which have `AVISIT` = null) |

## Key Derivation Notes

**Reader (BICR vs Investigator):** SDTM.RS now carries both Investigator and BICR (`RSEVAL == "INDEPENDENT ASSESSOR"`) assessments (~10% discordance). ADRS derives OVR/BOR/CBOR from the **Investigator** reader (`RSEVAL == "INVESTIGATOR"`) to preserve the established response semantics; the BICR reader is consumed directly by ADTTE for the primary PFS endpoint (Investigator PD feeds the PFSINV sensitivity analysis). A future SAP amendment can switch ADRS to BICR.

**BOR:** hand-coded in `adrs.R` (not `admiralonco`) — the best (lowest ordinal rank) OVR across all post-baseline visits, with an SD that counts only if observed ≥8 weeks (`ADY ≥ 57`) from TRTSDT. Subjects with no post-baseline assessment: AVALC = "NE" per SAP-D-04 (non-responder imputation).

**CBOR:** hand-coded in `adrs.R` (not `admiralonco`) — CR or PR requires a confirmatory OVR of equal-or-better response ≥28 days later; SD requires onset ≥8 weeks after TRTSDT; PD needs no confirmation. Confirmation period per SAP §4.3 and RECIST 1.1.

**ORR denominator:** All ITT subjects (ITTFL = "Y"), including those with no post-baseline assessment (counted as non-responders per SAP-D-04). RSPFL = "Y" only for confirmed CR/PR (CBOR-based).

**DCR:** Disease Control Rate = CR + PR + SD in CBOR. Computed at analysis time from the CBOR parameter (`AVALC ∈ {CR, PR, SD}`) — **not** stored as a separate ADRS parameter; SD requires ≥8 weeks from TRTSDT.

## Shell Cross-Reference

| Shell ID | Shell title | ADRS variables used |
|---|---|---|
| T-EFF-05 | Objective Response Rate (ORR) | RSPFL, PARAMCD = "CBOR", AVALC, ITTFL |
| T-EFF-06 | Disease Control Rate (DCR) | PARAMCD = "CBOR", AVALC ∈ {CR, PR, SD}, ITTFL |
| T-EFF-07 | Best Overall Response — Category Summary | PARAMCD = "CBOR", AVALC, ITTFL |
| F-EFF-03 | Waterfall Plot | RSPFL merged onto ADTR |
| F-EFF-06 | Swimmer Plot | RSPFL, ADT (date of first response) |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. BICR assessment handling deferred — add RSCAT = "BICR" parameter set if BICR data present. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. Add BICR OVR/BOR/CBOR if BICR collected. |
| 0.3 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Reconciled against `adrs.R`: N = 3,569; documented the Investigator-vs-BICR reader split (ADRS = Investigator; BICR → ADTTE PFS); OVR/BOR/CBOR are hand-coded (not `admiralonco`); removed CBDCR as a stored parameter (DCR computed from CBOR at analysis); `ANL01FL` = `flag_anl01` (one record per USUBJID×PARAMCD×AVISIT for by-visit OVR, one per USUBJID×PARAMCD for subject-level BOR/CBOR); `RSPFL` set "Y"/"N" on BOR & CBOR, NA on OVR. |
