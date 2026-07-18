# ROADMAP — CTX-NSCLC-301 Data Generation Pipeline

**Document:** ROADMAP.md  
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Last updated:** 2026-05-17
**Status:** Phase 6 TFLs COMPLETE (43 outputs); 22 SDTM domains; 12 ADaM datasets (6 efficacy/safety + 6 pharma-standard descriptive); Define-XML v2.1 draft regenerated (34 datasets / 613 variables); 7 accepted limitations closed (AL-02/03/04/07/08/09/10). Phase 7 (CSR) next.

---

## Executive Summary

End-to-end pipeline for generating a synthetic Phase 3 NSCLC clinical trial dataset conforming to CDISC standards (SDTMIG v3.4, ADaMIG v1.3), for contribution to `clinTrialData` R package.

**Pipeline sequence:**
```
1. Protocol         ✅ COMPLETE (v1.1, 2026-03-30)
   ↓
2. aCRF             ✅ COMPLETE — Gate 2 APPROVED (2026-04-01)
   ↓
3. Simulated Database ✅ COMPLETE (2026-04-07)
   ↓  (phases 3 & 4 unified: programs/raw/ scripts produce raw CSV + SDTM parquet)
4. SDTM (22 domains incl. DA + DV + RELREC + SUPPAE/CM/LB/DM/SU) ✅ COMPLETE — 22 Parquet files, SDTMIG v3.4 labelled (DV added 2026-05-17)
   ↓
4.5. SAP + TFL shells ✅ COMPLETE — Gate 3.5 PASSED (2026-04-20)
   ↓
5. ADaM (12 datasets — 6 efficacy/safety + 6 descriptive) ✅ COMPLETE — all 12 Parquets in datasets/adam/ (descriptive added 2026-05-17)
   ↓
6. TFLs (Tables, Figures, Listings) ✅ COMPLETE (43 outputs in RTF + DOCX + HTML + PNG; 2026-05-16)
   ↓
7. CSR (Clinical Study Report) ⏳ NEXT
   ↓
8. ADRG (Analysis Data Reviewer's Guide)
```

---

## Phase 1: Protocol ✅

**Status:** COMPLETE (v1.1, 2026-03-30)

| Item | Status | Location |
|------|--------|----------|
| Protocol synopsis | ✅ Done | `protocol/synopsis.md` (949 lines) |
| Study design | ✅ Locked | Section 3 of synopsis |
| Objectives | ✅ Locked | Section 2 of synopsis |
| Population | ✅ Locked | Section 4 of synopsis |
| Endpoints | ✅ Locked | Section 2 of synopsis |
| Statistical assumptions | ✅ Locked | Section 8 of synopsis |
| PROVENANCE | ✅ Done | `programs/raw/RAW-PROVENANCE.md` |

**Deliverables locked:**
- Study design: Phase 3, 2:1 randomisation, 450 subjects (300 active, 150 placebo)
- Primary endpoint: Overall Survival (OS)
- Secondary endpoints: PFS, ORR, Safety
- Response criteria: RECIST 1.1
- Standards: SDTMIG v3.4, ADaMIG v1.3, CDISC CT 2024-03, Define-XML v2.1

---

## Phase 2: aCRF (Annotated Case Report Form) ✅

**Status:** COMPLETE (2026-04-01) — Gate 2 deliverables submitted, pending LG approval

**Gate 1 (CRF Strategy):** ✅ APPROVED 2026-03-30 (see `PHASE-2-GATE-REVIEW.md`)  
**Gate 2 (CRF Design):** ✅ APPROVED 2026-04-01

**Purpose:** Define all data collection fields, visit windows, assessment timing, and SDTM variable mappings.

**Deliverables:**

| Item | Status | Location |
|------|--------|----------|
| CRF Excel Workbook | ✅ Done | `crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx` (21 sheets, 96 KB) |
| Field Definitions | ✅ Done | `crf/field_definitions.csv` (131 fields, 16 forms) |
| Visit Schedule | ✅ Done | `crf/visit_schedule.csv` (20 visit types) |
| Codelist Reference | ✅ Done | `crf/codelist_reference.csv` (233 entries, CDISC CT 2024-03) |
| CRF Visual Mockup (PDF) | ✅ Done | `crf/CRF_Preview.pdf` (287 KB) |
| CRF Visual Mockup (HTML) | ✅ Done | `crf/CRF_Preview.html` |
| Annotated CRF (HTML) | ✅ Done | `crf/CRF_Annotated.html` (~1.3 MB, self-contained) |
| Annotated CRF (PDF) | ✅ Done | `crf/CRF_Annotated.pdf` (~94 KB, xelatex) |
| Annotated CRF (Rmd) | ✅ Done | `crf/CRF_Annotated.Rmd` (programmatic, field_definitions.csv driven) |
| CRF Strategy | ✅ Locked | `crf/CRF-STRATEGY.md` (v2.0) |
| Build scripts | ✅ Done | `crf/build_crf_workbook.R`, `crf/build_crf_pdf.R` |

**Forms delivered (16 total):**

| # | Domain | Form | Type |
|---|--------|------|------|
| 1 | DM | Demographics | Foundational CDASH |
| 2 | DS | Disposition | Foundational CDASH |
| 3 | IE | Inclusion/Exclusion Criteria | Foundational CDASH |
| 4 | EC | Exposure as Collected | Foundational CDASH |
| 5 | DA | Drug Accountability | Foundational CDASH |
| 6 | AE | Adverse Events | Foundational CDASH |
| 7 | CM | Concomitant Medications | Foundational CDASH |
| 8 | MH | Medical History | Foundational CDASH |
| 9 | SU | Substance Use (Tobacco) | Foundational CDASH |
| 10 | VS | Vital Signs | Foundational CDASH |
| 11 | LB | Laboratory Test Results (Clinical + Biomarkers) | Foundational CDASH |
| 12 | PE | Physical Examination | Foundational CDASH |
| 13 | DD | Death Details | Foundational CDASH |
| 14 | TU | Tumour Identification | Custom Oncology (RECIST 1.1) |
| 15 | TR | Tumour Results | Custom Oncology (RECIST 1.1) |
| 16 | RS | Disease Response | Custom Oncology (RECIST 1.1) |

**Decisions locked:**

| Decision | Resolution |
|----------|------------|
| D-01: aCRF format | Both Excel workbook (.xlsx) + PDF visual mockup |
| D-02: MedDRA version | MedDRA v27.0 (preferred terms; coded centrally by DM) |
| D-03: Lab data realism | Realistic distributions with outliers (not uniform ranges) |
| D-04: Missing data pattern | MCAR (missing completely at random) for POC |
| D-05: Event rates | Conservative — match KEYNOTE-024 (OS HR=0.65, PFS HR=0.55) |
| D-06: ADaM authoring | Spec-first — every dataset has `programming-specs/AD{XX}-spec.md` before `adam/ad{xx}.R` |
| D-07: ADaM toolchain | Pharmaverse: `admiral` + `admiralonco` + `metacore` + `metatools` + `xportr` |
| D-08: Spec conventions | Reusable project-local skill at `.claude/skills/adam-spec/` |
| D-09: SAP before ADaM | Locked SAP + TFL shells list gate ADaM spec writing (Gate 3.5 added 2026-04-20) |

---

## Phase 3: Simulated Database ✅ COMPLETE (2026-04-07)

**Status:** Data generated and committed — 450 subjects, 22 SDTM Parquet domains, all SDTMIG v3.4 labels attached (15 base + DV + DA + RELREC + SUPPAE/CM/LB/SU)

> Phases 3 and 4 are split: `programs/raw/*.R` generates raw CSVs in `raw/`,
> then `programs/sdtm/*.R` reads those CSVs and writes SDTM Parquet files to
> `datasets/sdtm/`. (Legacy unified scripts in `data-raw/` were deleted
> 2026-05-17 — see `programs/raw/RAW-PROVENANCE.md` change log v0.1.)

**Purpose:** Generate realistic raw trial data (as if collected via eCRF) and SDTM domains.

**Scripts delivered:**

| Script | Seed | Domain | Key outputs |
|--------|------|--------|-------------|
| `00_run_all.R` | — | Orchestrator | Runs all scripts in subprocesses; saves `session_info.txt` |
| `01_dm.R` | 301 | DM + SUPPDM | 450 subjects, 2:1 randomisation, backbone, OS/PFS times |
| `02_ex.R` | 302 | EX | Q3W dosing, dose holds, infusion datetimes |
| `03_ds.R` | 303 | DS | IC → Randomised → EOT → FU → Death milestones |
| `04_ae.R` | 304 | AE | 26 AE types; irAEs overrepresented in TOR; MedDRA v27.0; CTCAE v5.0 |
| `05_cm.R` | 305 | CM | Background meds + corticosteroids for irAE mgmt |
| `06_mh.R` | 306 | MH | NSCLC comorbidity profile; MedDRA v27.0 |
| `07_su.R` | 307 | SU + SUPPSU | Tobacco; 38% current / 62% former; pack-years |
| `08_vs.R` | 308 | VS | BP, HR, Temp, Weight (decline post-progression), ECOG PS |
| `09_lb.R` | 309 | LB | Haem + Chem + Thyroid + Urinalysis + 10 biomarkers (PD-L1 TPS, mutations) |
| `10_pe.R` | 310 | PE | 9 body systems at SCR/C1D1/EOT |
| `11_tu.R` | 311 | TU | RECIST 1.1 target (2–5) + non-target (0–3) lesions |
| `12_tr.R` | 312 | TR | Per-visit lesion measurements; exponential growth/decay model |
| `13_rs.R` | 313 | RS | RECIST 1.1 BICR: per-visit + BOR; CR/PR confirmation required |
| `14_dd.R` | 314 | DD | Cause of death; 90% disease progression |
| `15_protocol_deviations.R` | 315 | Raw DV | Eligibility waivers + dose mods + missed doses + window violations (used by SDTM.DV) |
| `16_subsequent_therapy.R` | 316 | Raw subsequent CM | Post-discontinuation anti-cancer regimens (drives ADCM.SUBSQTFL + OS-WOT censoring) |
| `15_label_domains.R` | — | Labels | Attaches SDTMIG v3.4 variable labels to all 22 Parquet files |

**Backbone (`subject_backbone.csv`):** output of `01_dm.R` — joined by all downstream scripts; contains C1D1 date, PFS/OS event times, DTHFL, N_CYCLES, stratification variables.

**Key characteristics:**
- 450 subjects (300 active, 150 placebo), 60 sites, 3 regions
- 18-month accrual (2022-01-15 → 2023-07-15); data cutoff 2025-01-31
- OS HR=0.65 (TOR 21.5m vs PBO 14.0m), PFS HR=0.55 (TOR 11.0m vs PBO 6.0m)
- 10% administrative dropout (MCAR)
- SDTM Parquet output to `datasets/sdtm/`; raw CSV output to `raw/`

---

## Phase 4: SDTM ✅ COMPLETE (2026-04-07)

**Status:** 22 Parquet domains generated and committed (16 base + 6 back-filled). SDTMIG v3.4 variable labels attached to all domains via `15_label_domains.R`.

**Domains produced and committed:**

| Domain | Script | Output |
|--------|--------|--------|
| DM | `01_dm.R` | `sdtm/dm.parquet` |
| SUPPDM | `01_dm.R` | `sdtm/suppdm.parquet` |
| EX | `02_ex.R` | `sdtm/ex.parquet` |
| DS | `03_ds.R` | `sdtm/ds.parquet` |
| AE | `04_ae.R` | `sdtm/ae.parquet` |
| CM | `05_cm.R` | `sdtm/cm.parquet` |
| MH | `06_mh.R` | `sdtm/mh.parquet` |
| SU | `07_su.R` | `sdtm/su.parquet` |
| SUPPSU | `07_su.R` | `sdtm/suppsu.parquet` |
| VS | `08_vs.R` | `sdtm/vs.parquet` |
| LB | `09_lb.R` | `sdtm/lb.parquet` |
| PE | `10_pe.R` | `sdtm/pe.parquet` |
| TU | `11_tu.R` | `sdtm/tu.parquet` |
| TR | `12_tr.R` | `sdtm/tr.parquet` |
| RS | `13_rs.R` | `sdtm/rs.parquet` |
| DD | `14_dd.R` | `sdtm/dd.parquet` |

**Back-fill completed 2026-05-16 (SDTM v0.2):**
- DA (Drug Accountability) — 24,613 records via `programs/sdtm/da.R`
- RELREC (TU↔TR by lesion + RS↔TR by visit) — 17,708 records / 2,266 groups via `programs/sdtm/relrec.R`
- SUPPAE (IRAEFL, AEDISFL, AEACTFL) — 8,511 records via `programs/sdtm/suppae.R`
- SUPPCM (CMATC, CMIRAEFL) — 4,444 records via `programs/sdtm/suppcm.R`
- SUPPLB (BIOMRKFL, CENTRALFL) — 230,788 records via `programs/sdtm/supplb.R`

**v0.3 extension completed 2026-05-17:**
- DV (Protocol Deviations) — sponsor-classified deviations via `programs/sdtm/dv.R` (replaces DS=PROT placeholder; drives T-DV-01)
- SUPPSU rebuilt under canonical STUDYID with SMKSTAT QNAM (CURRENT SMOKER / EX-SMOKER / NEVER SMOKED, decoded from SU.SUSCAT) via `programs/sdtm/suppsu.R` (closes AL-01)
- RELREC dedupe — duplicate group records collapsed via `programs/sdtm/relrec.R` (closes AL-11)

All back-filled and v0.3 domains attached SDTMIG v3.4 variable labels via `programs/sdtm/16_label_domains.R`.

**Technology:** R + arrow (Parquet output); admiral/admiralonco for ADaM phase

---

## Phase 4.5: SAP + TFL Shells ✅ COMPLETE (2026-04-20) — Gate 3.5 PASSED

**Status:** COMPLETE — SAP locked, ARS-aligned TFL shells delivered, ADSL spec-first kickoff included.

**Deliverables:**

| Item | Location | Status |
|------|----------|--------|
| Statistical Analysis Plan | `sap/SAP.md` | ✅ Locked |
| SAP Provenance | `sap/SAP-PROVENANCE.md` | ✅ Done |
| TFL shells (YAML + DOC) | `sap/shells/` | ✅ Locked — ARS-aligned |
| Shells provenance | `sap/shells/SHELLS-PROVENANCE.md` | ✅ Done |
| ADSL spec (draft) | `programming-specs/ADSL-spec.md` | ✅ Drafted (back-validated against SAP) |

**Why this phase exists:** Without a locked SAP, ADaM specs get written on assumed analyses — drift shows up at TFL time when variables are missing or wrongly derived (e.g. PFS censoring rule chosen in ADaM doesn't match the SAP).

---

## Phase 5: ADaM ✅ COMPLETE (2026-04-25; extended 2026-05-17) — Gate 4 PASSED

**Status:** COMPLETE — all 12 ADaM datasets scripted, executed, and committed (6 efficacy/safety from Gate 4; 6 pharma-standard descriptive added 2026-05-17).

**Approach:** Spec-first using the pharmaverse stack (`admiral` + `admiralonco` + `metacore` + `metatools` + `xportr`). See [`programs/adam/PHASE-5-APPROACH.md`](programs/adam/PHASE-5-APPROACH.md) for the full decision log.

**Datasets delivered:**

| Dataset | Script | Parquet | Description |
|---------|--------|---------|-------------|
| ADSL | `programs/adam/adsl.R` | `datasets/adam/adsl.parquet` | Subject-level — population flags (real PPROTFL), treatment, disposition, baseline |
| ADAE | `programs/adam/adae.R` | `datasets/adam/adae.parquet` | Adverse events — CTCAE grade, treatment-emergent flags |
| ADLB | `programs/adam/adlb.R` | `datasets/adam/adlb.parquet` | Laboratory — baseline, change from baseline, abnormal flags |
| ADTR | `programs/adam/adtr.R` | `datasets/adam/adtr.parquet` | Tumour measurements — SLD, % change, nadir tracking |
| ADRS | `programs/adam/adrs.R` | `datasets/adam/adrs.parquet` | Disease response — BOR, confirmed response, progression (Investigator) |
| ADTTE | `programs/adam/adtte.R` | `datasets/adam/adtte.parquet` | Time-to-event — 6 PARAMCDs: OS, OSWOT, PFS (BICR), PFSINV (Investigator), DOR, TTR |
| ADCM | `programs/adam/adcm.R` | `datasets/adam/adcm.parquet` | Concomitant medications — ATC class, irAE-mgmt flag, real SUBSQTFL |
| ADDS | `programs/adam/adds.R` | `datasets/adam/adds.parquet` | Disposition — DCSREAS, EOTSTT, EOSSTT |
| ADDV | `programs/adam/addv.R` | `datasets/adam/addv.parquet` | Protocol deviations — DVCAT, DVDECOD, MAJDVFL |
| ADEX | `programs/adam/adex.R` | `datasets/adam/adex.parquet` | Exposure — cumulative dose, intensity, duration |
| ADMH | `programs/adam/admh.R` | `datasets/adam/admh.parquet` | Medical history — ongoing/historical, MedDRA-coded |
| ADVS | `programs/adam/advs.R` | `datasets/adam/advs.parquet` | Vital signs — baseline, change, abnormal flags |

**Orchestrator:** `programs/adam/00_run_adam.R`

**Programming specs:** `programming-specs/ADSL-spec.md` through `ADTTE-spec.md` (efficacy/safety set; descriptive ADaMs derive from SDTM directly via `programs/adam/ADAM-MAPPING-SPEC.md`)

**Technology:** R + admiral + admiralonco + xportr

---

## Phase 6: TFLs (Tables, Figures, Listings) ✅ COMPLETE

**Status:** Phase 6 COMPLETE (2026-05-16; extended 2026-05-17 with T-DV-01) — **all 43 of 43 outputs delivered** (32 tables + 6 figures + 5 listings) in RTF + DOCX + HTML + PNG. Production-ready pipeline.

**Phase 6a (efficacy pilot):**
- `programs/tfl/00_run_tfl.R` orchestrator, `_helpers.R` shared utilities, `_km_plot.R` KM helper
- T-DM-01 (Demographics), T-EFF-01 (OS), T-EFF-03 (PFS), F-EFF-01 (KM-OS), F-EFF-02 (KM-PFS)
- Cox HR validation: OS 0.576 (CI 0.458–0.724, target 0.65 ✓), PFS 0.504 (CI 0.405–0.628, target 0.55 ✓)

**Phase 6b (disposition + exposure):**
- T-DS-01 (Subject Disposition), T-DS-02 (Major Protocol Deviations)
- T-DS-03 (Intercurrent Events Summary — operationalises SAP §13.3)
- T-EX-01 (Study Drug Exposure)

**Phase 6c (efficacy completion — 15 outputs):**
- T-EFF-02/04 (KM landmark probabilities OS/PFS), T-EFF-05/06/07 (ORR/DCR/DoR)
- Sensitivity estimands: T-EFF-08 (OS-PP), T-EFF-09 (OS Landmark), T-EFF-10 (OS RMST = E1a), T-EFF-11 (PFS-INV = E2a), T-EFF-12 (OS-WOT = E1b), T-EFF-13 (ORR-ITT = E3a)
- Figures: F-EFF-03 (Waterfall), F-EFF-04 (Spider), F-EFF-05 (Forest), F-EFF-06 (Swimmer)
- All 11 sensitivity Cox/MH HRs computed; ORR TRT 39.1% vs PBO 15.1% (RD 24.0, p<0.001)

Combined `tfl/TFL-OUTPUTS.html` + `tfl/TFL-OUTPUTS.docx` updated with all 24 outputs.

**Phase 6d (safety + listings — 14 outputs):**
- Tables: T-AE-01 (overall), T-AE-02 (SOC×PT ≥5%), T-AE-03 (G3+), T-AE-04 (SAE), T-AE-05 (irAE), T-AE-06 (AESI), T-AE-07 (Deaths), T-LB-01 (shift), T-LB-02 (G3+ labs)
- Listings: L-AE-01 (SAEs), L-AE-02 (Deaths), L-AE-03 (AEs leading to disc), L-LB-01 (G3+ labs), L-DS-01 (deviations)
- All listings render in landscape DOCX + RTF + HTML

**Combined deliverables (all 43 outputs):**
- `tfl/TFL-OUTPUTS.html` (browser view)
- `tfl/TFL-OUTPUTS.docx` (Word view with cover + per-output cross-references)
- 96 standalone table/listing files + 6 PNG figures in `tfl/`

**Tables:**
- T-DM-01: Demographic and baseline characteristics (ITT)
- T-DS-01: Subject disposition
- T-AE-01: Treatment-emergent adverse events summary
- T-AE-02: AEs by SOC and PT (≥5% any arm)
- T-AE-03: Grade 3+ AEs
- T-LB-01: Laboratory abnormalities
- T-EFF-01: Overall survival analysis
- T-EFF-02: Progression-free survival analysis
- T-EFF-03: Objective response rate with 95% CI

**Figures:**
- F-EFF-01: Kaplan-Meier curve — OS
- F-EFF-02: Kaplan-Meier curve — PFS
- F-EFF-03: Waterfall plot — best % change from baseline SLD
- F-EFF-04: Spider plot — SLD change over time

**Listings:**
- L-AE-01: Serious adverse events
- L-AE-02: Deaths
- L-LB-01: Laboratory values

**Technology:** R + rtables + tern + gt/flextable

**Timeline:** ~5 days

---

## QC layer — Validation strategy + tooling + trackers ✅ IN PLACE

**Status:** Strategy committed, tooling executable, GitHub issues #1–#9 open for execution.

**Strategy:** [`qc/VALIDATION-PLAN.md`](qc/VALIDATION-PLAN.md) — 11-section SOP covering scope (raw → SDTM → ADaM → Define-XML → TFL), roles (primary / QC / reviewer), layered acceptance criteria, phased execution (15–22 working days), and 11 pre-loaded accepted limitations.

**Trackers** (Excel, regenerated by `programs/qc/build_trackers.R`):

| File | Rows | Source of truth |
|---|---|---|
| `qc/SDTM-PROGRAMMING-TRACKER.xlsx` | 22 | All SDTM domains; 2 pre-loaded with AL notes (SUPPSU, RELREC) |
| `qc/ADAM-PROGRAMMING-TRACKER.xlsx` | 12 | All ADaM datasets |
| `qc/TFL-PROGRAMMING-TRACKER.xlsx`  | 43 | All shells; 2 pre-loaded with AL notes (T-EFF-10, T-DS-03); each row tagged with SAP estimand ID |

Each workbook has 3 sheets: tracker grid (with status dropdown + colour fills), status legend, sign-off block (7 roles).

**R scripts** (`programs/qc/`):

| Script | Purpose |
|---|---|
| `build_trackers.R` | Regenerates the 3 trackers from current state |
| `run_reproducibility_check.R` | Re-runs full pipeline into staging dir, byte-diffs every output |
| `compare_sdtm.R` | Wraps `diffdf` for primary-vs-QC SDTM comparison |
| `compare_adam.R` | Same for ADaM + Cox HR + KM median tolerance check |
| `extract_tfl_values.R` | Parses all 32 TFL DOCX into a 64,054-cell CSV for diffing |
| `_compare_helpers.R` | Shared key-resolution + fallback logic |

**Execution as GitHub issues** ([all 9](https://github.com/OpenTrialReporting/torivumab-nsclc-301/issues)):

| # | Phase | What | Effort |
|---|---|---|---|
| #1 | A | Reproducibility check (byte-diff full pipeline) | 1 day |
| #2 | B | SDTM independent double programming (22 domains) | 5–7 days |
| #3 | C | Pinnacle 21 SDTM compliance scan | 0.5 day |
| #4 | D | ADaM independent double programming (12 datasets) | 6–9 days |
| #5 | E | Pinnacle 21 ADaM compliance scan | 0.5 day |
| #6 | F | TFL numerical match (43 outputs) | 6–8 days |
| #7 | G | Biostatistician statistical sense check | 1 day |
| #8 | H | Lock + sign-off (populate 7-role signature blocks) | 0.5 day |
| #9 | — | ~~Defect: AL-11 RELREC dedupe~~ — CLOSED 2026-05-17 (dedupe fixed in `programs/sdtm/relrec.R`) | — |

**Total: 15–22 working days** for one QC programmer + reviewer pair.

---

## Phase 7: CSR (Clinical Study Report) ⏳

**Status:** NOT STARTED

**Sections:**
- Executive summary
- Background & rationale
- Study objectives & endpoints
- Study methods (design, population, treatment, assessments)
- Results (disposition, demographics, efficacy, safety)
- Discussion & conclusions
- References

**Timeline:** ~7 days (after TFLs complete)

---

## Phase 8: ADRG (Analysis Data Reviewer's Guide) ⏳

**Status:** NOT STARTED

**Contents:**
- Dataset overview & purposes
- Variable definitions & coding
- Derivation algorithms (with pseudocode)
- Missing data handling
- Analysis population flags
- Subgroup analysis approach
- References to specifications (CRF, SDTM, protocol)

**Timeline:** ~4 days

---

## Parallel Activities

### Define-XML v2.1
- ✅ v0.1 draft generated 2026-05-16; regenerated 2026-05-17 (`programs/define/build_define.R`)
- Covers all 22 SDTM domains + 12 ADaM datasets = 34 ItemGroupDefs, 613 variables
- Toolchain: `xml2` + `arrow` + `labelled` (pharmaverse `metacore`/`xportr` not required for v0.1)
- Outputs: `define/define.xml` + `define/DEFINE-SUMMARY.md`
- **Known gaps (v0.1):** Value-Level Metadata, full CodeListDef references, MethodDef chains, WhereClauseDef blocks — see `define/DEFINE-SUMMARY.md`. PDF rendering deferred (requires CDISC `define2-1-0.xsl` stylesheet transformation).

### Validation & QC
- Run after each phase completion
- SDTM: domain counts, variable completeness, codelist conformance
- ADaM: population counts, derivation logic review, missing data checks
- TFL: visual inspection, statistical sense-checks

### Future pilots (not gated)
- **SDTMIG v4.0 sibling pilot** — produce a parallel `datasets/sdtm_v4/` + `define/define_v4.xml` alongside the v3.4 baseline, demonstrating SUPP-- removal and v4.0 naming conventions for educational/comparison purposes. ADaM/TFL/ARM continue to consume v3.4. Tracked in a separate GitHub issue.

---

## Timeline Estimate

| Phase | Status | Days | Cumulative |
|-------|--------|------|-----------|
| 1. Protocol | ✅ Done (2026-03-30) | — | — |
| 2. aCRF | ✅ Done (2026-04-01) | — | — |
| 3. Simulated DB | ✅ Done (2026-04-07) | — | — |
| 4. SDTM | ✅ Done — 22 domains, labelled (2026-04-07; back-fill 2026-05-16; DV added 2026-05-17) | — | — |
| 4.5. SAP + TFL shells | ✅ Done — Gate 3.5 PASSED (2026-04-20) | — | — |
| 5. ADaM | ✅ Done — Gate 4 PASSED (2026-04-25; extended to 12 datasets 2026-05-17) | — | — |
| 6. TFLs | ✅ Done — 43 outputs (2026-05-16; T-DV-01 added 2026-05-17) | — | — |
| 7. CSR | ⏳ Next | 7 | 7 |
| 8. ADRG | ⏳ | 4 | 11 |

**Parallel validation & Define-XML:** +5 days (concurrent)
**Realistic remaining timeline: ~4–5 weeks**

---

## Gate Reviews

| Gate | Phase | Status | Date |
|------|-------|--------|------|
| Gate 1 | CRF Strategy | ✅ PASSED | 2026-03-30 |
| Gate 2 | CRF Design (aCRF) | ✅ PASSED | 2026-04-01 |
| Gate 3 | Simulated Database + SDTM | ✅ PASSED | 2026-04-07 |
| Gate 3.5 | SAP + TFL shells | ✅ PASSED | 2026-04-20 |
| Gate 4 | ADaM | ✅ PASSED | 2026-04-25 |
| Gate 5 | TFLs | ✅ PASSED | 2026-05-16 |
| Gate 6 | CSR + ADRG | ⏳ | — |

---

## Success Criteria

- [x] aCRF complete & approved (Gate 2 — 2026-04-01)
- [x] Data generation scripts written (15 scripts, seeds 301–314) + `15_label_domains.R`
- [x] Simulated data executed & validated (2026-04-07)
- [x] SDTM datasets conform to SDTMIG v3.4 & CDISC CT 2024-03 (22 domains, all vars labelled)
- [x] SAP locked + ARS-aligned TFL shells delivered (Gate 3.5 — 2026-04-20)
- [x] All 6 efficacy/safety ADaM programming specs written (`programming-specs/`)
- [x] All 12 ADaM R scripts run end-to-end (`programs/adam/`)
- [x] All 12 ADaM Parquet datasets committed (`datasets/adam/`) — Gate 4 PASSED 2026-04-25 (efficacy/safety); extended to 12 on 2026-05-17 (descriptive)
- [x] SDTM back-fill complete — DA, RELREC, SUPPAE/CM/LB added (2026-05-16); DV added + SUPPSU rebuilt + RELREC deduped (2026-05-17); 22 domains total
- [x] Raw simulation v0.3 — Tier A (covariate-driven hazards) + Tier B (Weibull KM shape) (2026-05-16); v0.4 adds protocol deviations + subsequent therapy (2026-05-17)
- [x] Define-XML v2.1 v0.1 draft generated (covers 34 datasets / 613 vars; VLM/CodeLists deferred)
- [x] ADaM re-derived from v0.4 SDTM (admiral 1.4.1) — Cox HR recovers protocol targets: OS 0.567 (target 0.65), PFS BICR 0.568 + PFSINV 0.522 (target 0.55), median OS TRT 21.4m ≈ 21.5m target
- [x] Double-programming mapping specs: `programs/sdtm/SDTM-MAPPING-SPEC.md` (raw → SDTM, 22 domains) + `programs/adam/ADAM-MAPPING-SPEC.md` (SDTM → ADaM, 12 datasets) — self-contained for independent re-derivation
- [x] TFLs publication-ready — 43 outputs, no manual edits
- [x] 7 accepted limitations closed (AL-01/02/03/04/07/08/09/10/11); AL-12 added (IE4 missed-assessment gap)
- [ ] Define-XML v2.1 v1.0 (VLM + full CodeList refs + PDF render)
- [ ] CSR narratively coherent & statistically sound
- [ ] ADRG complete & referenced
- [~] All 22 SDTM + 12 ADaM datasets submitted to clinTrialData in Parquet format — submission bundle staged in `onco_phase3_solid/` (34 Parquet + `metadata.json`, slug `onco_phase3_solid`, v0.1.0, N=450) ready for GitHub Release upload; release upload itself runs from the clinTrialData package clone (see `onco_phase3_solid/README.md`)
- [ ] Repository clean & fully documented on GitHub

---

## Repository Structure

```
torivumab-nsclc-301/
├── protocol/
│   └── synopsis.md (v1.1) ✅
├── crf/                                    ✅ Phase 2 complete (Gate 2 APPROVED 2026-04-01)
│   ├── CRF-STRATEGY.md (v2.0 — locked)
│   ├── SIMULATED-TORIVUMAB-2026_CRF.xlsx  (21 sheets)
│   ├── field_definitions.csv              (131 fields, 16 forms)
│   ├── visit_schedule.csv                 (20 visit types)
│   └── codelist_reference.csv             (233 entries, CDISC CT 2024-03)
├── programs/                               ✅ All derivation code — clean code/data separation
│   ├── raw/                               Phase 3: simulate eCRF data
│   │   ├── 00_simulate_raw.R             (orchestrator, set.seed = 20260301)
│   │   └── 01_demographics.R … 13_physical_exam.R
│   ├── sdtm/                              Phase 4: map raw → SDTM
│   │   ├── 00_run_sdtm.R                 (orchestrator)
│   │   └── dm.R, ae.R, ex.R … dv.R       (22 domain scripts)
│   └── adam/                              ✅ Phase 5 COMPLETE (Gate 4 PASSED 2026-04-25; extended 2026-05-17)
│       ├── 00_run_adam.R                 (orchestrator)
│       ├── adsl.R, adae.R, adlb.R, adtr.R, adrs.R, adtte.R   (6 efficacy/safety)
│       ├── adcm.R, adds.R, addv.R, adex.R, admh.R, advs.R   (6 pharma-standard descriptive)
│       └── PHASE-5-APPROACH.md
├── datasets/                               Outputs only — no code
│   ├── sdtm/  *.parquet (22 domains)      ✅ SDTMIG v3.4 labelled (v0.2 back-fill 2026-05-16; v0.3 DV 2026-05-17)
│   └── adam/  *.parquet (12 datasets)     ✅ Generated 2026-04-25 (6); extended 2026-05-17 (+6)
├── programming-specs/                      ✅ Per-dataset specs (34 total)
│   ├── README.md                           Inventory + template + standards
│   ├── SDTM-{DM,AE,CM,DS,EX,LB,MH,VS,PE,SU,DD,TU,TR,RS,DA,DV,
│   │   SUPPDM,SUPPAE,SUPPCM,SUPPLB,SUPPSU,RELREC}-spec.md   (22 SDTM)
│   └── ADSL,ADAE,ADCM,ADDS,ADDV,ADEX,ADLB,ADMH,ADRS,ADTR,ADTTE,ADVS-spec.md   (12 ADaM)
├── sap/                                    ✅ Phase 4.5 — Gate 3.5 PASSED 2026-04-20
│   ├── SAP.md (locked)
│   ├── SAP-PROVENANCE.md
│   └── shells/
│       ├── shells.yaml / TFL-SHELLS.md
│       └── SHELLS-PROVENANCE.md
├── tfl/                                    ✅ Phase 6 COMPLETE (43/43 outputs)
│   ├── tables/  *.rtf|.docx|.html   (32 tables × 3 formats)
│   ├── figures/  *.png              (6 figures @ 300 dpi)
│   ├── listings/ *.html|.docx|.rtf  (5 listings × 3 formats)
│   ├── TFL-OUTPUTS.html             (combined browser view)
│   └── TFL-OUTPUTS.docx             (combined Word view)
├── define/                                 ✅ v0.1 draft 2026-05-16 (VLM deferred to v1.0)
│   ├── define.xml (v2.1)
│   └── DEFINE-SUMMARY.md
├── programs/define/                        ✅ Define-XML builder
│   └── build_define.R
├── csr/                                    ⏳ Phase 7
│   └── csr.pdf
├── onco_phase3_solid/                          ✅ clinTrialData submission bundle (v0.1.0)
│   ├── adam/  *.parquet (12)  ·  sdtm/  *.parquet (22)
│   ├── metadata.json                            (source/domains/n_subjects=450/version/license)
│   └── README.md                                (release-upload commands)
├── ROADMAP.md (this file)
├── AGENTS.md
├── PHASE-2-GATE-REVIEW.md
└── README.md
```

---

*Last updated: 2026-05-17*
*Phases 1–6 complete (22 SDTM, 12 ADaM, 43 TFL) + Define-XML v0.1 (34/613) + 7 ALs closed — Gates 1–5 all PASSED → Phase 7 CSR next*
