# ADTR — Tumor Results BDS — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADTR |
| **Label** | Tumor Results |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per tumour parameter per lesion per assessment visit (SDIAM: one per subject/visit; LDIAM: one per target lesion/visit) |
| **Expected N** | 9,255 records (SDIAM one per subject/visit + LDIAM one per target lesion/visit) |
| **Key variables** | `USUBJID`, `PARAMCD`, `VISITNUM`, `ADT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADTR is an intermediate oncology BDS dataset that derives per-visit Sum of Longest Diameters (SLD, PARAMCD `SDIAM`) from SDTM TR/TU, and also retains the per-target-lesion longest diameters (PARAMCD `LDIAM`, one row per lesion per visit, keyed by `LNKID`). It feeds ADRS for BOR/confirmed response derivation and is the source for waterfall (F-EFF-03) and spider (F-EFF-04) figures. Per CDISC Oncology Disease Response Supplement (RECIST 1.1, 2023).

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
| 7 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 8 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 9 | TRTSDT | Date of First Dose | Date | — | Derived | — | Merged from ADSL.TRTSDT |
| 10 | TRTEDT | Date of Last Dose | Date | — | Derived | — | Merged from ADSL.TRTEDT |
| 11 | PARAM | Parameter Description | Char | 200 | Derived | — | "Sum of Longest Diameters (mm)" (SDIAM) / "Longest Diameter (mm)" (LDIAM) |
| 12 | PARAMCD | Parameter Code | Char | 8 | Derived | — | `SDIAM` (per-subject/visit SLD) or `LDIAM` (per target lesion) |
| 13 | AVALU | Analysis Value Units | Char | 8 | Derived | — | "mm" |
| 14 | VISIT | Visit Name | Char | 40 | Predecessor | — | `TR.VISIT` (BASELINE / TUMOR_ASSESS_WKn). Retained for traceability; SDTM `VISITNUM` dropped — TR did not collect it (100% null) |
| 15 | AVISIT | Analysis Visit | Char | 40 | Derived | — | `derive_avisit_windowed(ADY, VISIT, ., "TUMOUR")`: nearest RECIST assessment by `ADY` (SAP §12.2); the `ABLFL="Y"` record is relabelled `AVISIT="Baseline"` |
| 16 | AVISITN | Analysis Visit (N) | Num | 8 | Derived | — | Numeric key of the windowed `AVISIT` (`Baseline` 0, `TUMOR_ASSESS_WKn` n) — SAP §12.2 |
| 17 | ADT | Analysis Date | Date | — | Derived | — | `as.Date(TR.TRDTC)` |
| 18 | ADY | Analysis Relative Day | Num | 8 | Derived | — | `study_day(ADT, TRTSDT)` |
| 19 | AVAL | Analysis Value (mm) | Num | 8 | Derived | — | SDIAM: sum of `TR.TRSTRESN` over TRGRPID = "TARGET", TRTESTCD = "LDIAM" per visit; LDIAM: the lesion's `TR.TRSTRESN` |
| 20 | BASE | Baseline SLD Value | Num | 8 | Derived | — | `admiral::derive_var_base()` from ABLFL record (SDIAM) |
| 21 | CHG | Change from Baseline (mm) | Num | 8 | Derived | — | `admiral::derive_var_chg()`: AVAL − BASE |
| 22 | PCHG | Percent Change from Baseline | Num | 8 | Derived | — | `admiral::derive_var_pchg()`: (CHG / BASE) × 100 |
| 23 | NADIR | Minimum Post-Baseline SLD | Num | 8 | Derived | — | `min(AVAL)` for PARAMCD = "SDIAM" & ADT > TRTSDT, merged onto all records per subject |
| 24 | ABLFL | Baseline Record Flag | Char | 1 | Derived | NY | Last non-missing, non-zero SDIAM on or before TRTSDT, per `USUBJID × PARAMCD × LNKID` |
| 25 | ANL01FL | Analysis Flag 01 (analysis record per visit) | Char | 1 | Derived | NY | `flag_anl01(extra_key = LNKID)` — the shared by-visit rule (SAP §12.2): one record per `USUBJID × PARAMCD × LNKID × AVISIT`, baseline record inside the Baseline visit else closest to target (ties → later `ADT`). `LNKID` joins the key because ADTR is one record per **lesion** per visit |
| 26 | LNKID | Link ID (lesion identifier) | Char | 20 | Predecessor | — | `TR.TRLNKID` (populated for LDIAM lesion rows; NA on SDIAM summary rows) |
| 27 | N_TGT | Number of Target Lesions | Num | 8 | Derived | — | Count of target lesions summed into SDIAM (NA on LDIAM rows) |

## Key Derivation Notes

**SLD computation:** Sum of `TR.TRSTRESN` (longest diameter in mm) across all target lesions (TRGRPID = "TARGET", TRTESTCD = "LDIAM") at each visit. A subject must have ≥1 measurable target lesion at baseline per RECIST 1.1. Visits with missing measurements for any lesion are handled per SAP §4.3 (partial SLD documented with note).

**Baseline (SAP §12.3):** the last SLD assessment on or before TRTSDT (`ADT ≤ TRTSDT`) with at least one measurable target lesion — date-based, not visit-restricted. The `ABLFL = "Y"` record carries `AVISIT = "Baseline"`, `AVISITN = 0`. Naïve screen failures without a post-randomisation assessment are retained with ABLFL = NA.

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
| 0.3 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Reconciled against `adtr.R`: N = 9,255; documented the per-lesion `LDIAM` parameter and `LNKID`/`N_TGT`/`AVALU`/`ADY`/`TRT01PN`/`TRT01AN` variables (structure = one row per lesion per visit for LDIAM, one per subject/visit for SDIAM); `ANL01FL` = `flag_anl01(extra_key = LNKID)` replacing the bespoke post-baseline-SDIAM rule; `ATPTREF` now assigned by windowing; date-based baseline with baseline visit `AVISIT="Baseline"`/`AVISITN=0`. |
