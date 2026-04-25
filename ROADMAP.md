# ROADMAP — CTX-NSCLC-301 Data Generation Pipeline

**Document:** ROADMAP.md  
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Last updated:** 2026-04-07  
**Status:** Phase 3/4 COMPLETE — 16 SDTM Parquet domains generated, SDTMIG v3.4 labels attached → Gate 3 pending LG review → Phase 5 (ADaM) next

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
   ↓  (phases 3 & 4 unified: data-raw/ scripts produce raw CSV + SDTM parquet)
4. SDTM (14 domains + SUPPDM + SUPPSU) ✅ COMPLETE — 16 Parquet files, SDTMIG v3.4 labelled
   ↓
4.5. SAP + TFL shells ⏳ NEW — locks populations, endpoints, methods, and the list of T/F/L outputs
   ↓
5. ADaM (6 datasets) — every variable traces to a SAP analysis or a TFL shell
   ↓
6. TFLs (Tables, Figures, Listings)
   ↓
7. CSR (Clinical Study Report)
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
| PROVENANCE | ✅ Done | `data-raw/PROVENANCE.md` |

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

**Status:** Data generated and committed — 450 subjects, 16 SDTM Parquet domains, all SDTMIG v3.4 labels attached

> Phases 3 and 4 are unified: each `data-raw/` script generates both a raw CSV
> (`data-raw/raw_data/`) and an SDTM-ready Parquet file (`sdtm/`).

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
| `15_label_domains.R` | — | Labels | Attaches SDTMIG v3.4 variable labels to all 16 Parquet files |

**Backbone (`subject_backbone.csv`):** output of `01_dm.R` — joined by all downstream scripts; contains C1D1 date, PFS/OS event times, DTHFL, N_CYCLES, stratification variables.

**Key characteristics:**
- 450 subjects (300 active, 150 placebo), 60 sites, 3 regions
- 18-month accrual (2022-01-15 → 2023-07-15); data cutoff 2025-01-31
- OS HR=0.65 (TOR 21.5m vs PBO 14.0m), PFS HR=0.55 (TOR 11.0m vs PBO 6.0m)
- 10% administrative dropout (MCAR)
- SDTM Parquet output to `sdtm/`; raw CSV output to `data-raw/raw_data/`

---

## Phase 4: SDTM ✅ COMPLETE (2026-04-07)

**Status:** 16 Parquet domains generated and committed. SDTMIG v3.4 variable labels attached to all domains via `15_label_domains.R`.

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

**Pending (post-execution):** RELREC (links TU→TR→RS), additional SUPP-- datasets for AE/CM/LB, DA (Drug Accountability) domain.

**Technology:** R + arrow (Parquet output); admiral/admiralonco for ADaM phase

---

## Phase 4.5: SAP + TFL Shells ⏳ NEXT

**Status:** NOT STARTED — Gate 3.5 deliverable. Blocks Phase 5.

**Purpose:** Lock the statistical analysis plan and the list of T/F/L outputs *before* writing ADaM specs, so every ADaM variable traces to a required analysis.

**Deliverables:**

| Item | Location | Purpose |
|------|----------|---------|
| Statistical Analysis Plan | `sap/SAP.md` | Populations (ITT/Safety/PP), endpoints, statistical methods (stratified log-rank, Cox PH, CMH for ORR), censoring rules, subgroup definitions, missing-data handling, multiplicity strategy, data cutoff |
| TFL shells list | `tfl/TFL-SHELLS.md` | Numbered list: every T/F/L with title, population, source ADaM dataset, variables used, statistical method, mock layout |

**Why this phase exists:** Without a locked SAP, ADaM specs get written on assumed analyses — drift shows up at TFL time when variables are missing or wrongly derived (e.g. PFS censoring rule chosen in ADaM doesn't match the SAP).

**Scope note:** Condensed SAP (~10 pages) covering ICH E9 essentials, not a full 50-page regulatory document.

**Timeline:** ~3 days

---

## Phase 5: ADaM ⏳

**Status:** BLOCKED on Gate 3.5 (SAP + TFL shells).

**Approach:** Spec-first. See [`adam/PHASE-5-APPROACH.md`](adam/PHASE-5-APPROACH.md) for the full decision log (D-06 spec-first, D-07 pharmaverse stack, D-08 `adam-spec` skill) and build order. Every ADaM variable must trace to an analysis in the SAP or a TFL shell.

**Purpose:** Derive analysis datasets from SDTM (6 datasets).

**Datasets:**

| Dataset | Description | Est. Records |
|---------|-------------|---------|
| ADSL | Subject-level (demographics, treatment, disposition, baseline) | 450 |
| ADAE | Adverse events analysis (CTCAE grade, treatment-emergent flags) | ~2,000–3,000 |
| ADLB | Laboratory analysis (baseline, change from baseline, abnormal flags) | ~10,000+ |
| ADRS | Disease response (BOR, confirmed response, progression) | ~450–900 |
| ADTR | Tumour measurements (SLD, % change, nadir tracking) | ~5,000+ |
| ADTTE | Time-to-event (OS, PFS with censoring rules) | 450 |

**Key ADaM derivations:**
- **ADSL:** Population flags (SAFFL, ITTFL, PPROTFL), baseline characteristics
- **ADTTE OS:** Event = death; censoring = last known alive date
- **ADTTE PFS:** Event = progression or death; censoring = last adequate assessment
- **ADRS BOR:** Best overall response (CR/PR/SD/PD); confirmed response = 2 consecutive PRs
- **ADTR SLD:** Sum of longest diameters; % change from nadir

**Technology:** R + admiral + admiralonco + xportr

**Timeline:** ~7 days

---

## Phase 6: TFLs (Tables, Figures, Listings) ⏳

**Status:** NOT STARTED

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
- Generated during Phase 4 (SDTM) and Phase 5 (ADaM)
- Uses `metacore` + `xportr` R packages
- Output: `define/define.xml` and `define/define.pdf`

### Validation & QC
- Run after each phase completion
- SDTM: domain counts, variable completeness, codelist conformance
- ADaM: population counts, derivation logic review, missing data checks
- TFL: visual inspection, statistical sense-checks

---

## Timeline Estimate

| Phase | Status | Days | Cumulative |
|-------|--------|------|-----------|
| 1. Protocol | ✅ Done | — | — |
| 2. aCRF | ✅ Done | — | — |
| 3. Simulated DB | ✅ Done (2026-04-07) | — | — |
| 4. SDTM | ✅ Done — 16 domains, labelled (2026-04-07) | — | — |
| 4.5. SAP + TFL shells | ⏳ Next | 3 | 3 |
| 5. ADaM | ⏳ Blocked on 4.5 | 7 | 10 |
| 6. TFLs | ⏳ | 5 | 15 |
| 7. CSR | ⏳ | 7 | 22 |
| 8. ADRG | ⏳ | 4 | 26 |

**Parallel validation & Define-XML:** +5 days (concurrent)  
**Realistic remaining timeline: ~6 weeks**

---

## Gate Reviews

| Gate | Phase | Status | Date |
|------|-------|--------|------|
| Gate 1 | CRF Strategy | ✅ PASSED | 2026-03-30 |
| Gate 2 | CRF Design (aCRF) | ✅ PASSED | 2026-04-01 |
| Gate 3 | Simulated Database + SDTM | ⏳ Data ready — pending LG review | — |
| Gate 3.5 | SAP + TFL shells | ⏳ | — |
| Gate 4 | ADaM | ⏳ Blocked on Gate 3.5 | — |
| Gate 5 | TFLs | ⏳ | — |
| Gate 6 | CSR + ADRG | ⏳ | — |

---

## Success Criteria

- [x] aCRF complete & approved (Gate 2 — 2026-04-01)
- [x] Data generation scripts written (15 scripts, seeds 301–314) + `15_label_domains.R`
- [x] Simulated data executed & validated (2026-04-07)
- [x] SDTM datasets conform to SDTMIG v3.4 & CDISC CT 2024-03 (16 domains, all vars labelled)
- [ ] ADaM datasets pass admiral validation checks
- [ ] TFLs publication-ready (no manual edits)
- [ ] Define-XML v2.1 valid (via Define-XML viewer)
- [ ] CSR narratively coherent & statistically sound
- [ ] ADRG complete & referenced
- [ ] All 19 SDTM + 6 ADaM datasets submitted to clinTrialData in Parquet format
- [ ] Repository clean & fully documented on GitHub

---

## Repository Structure

```
torivumab-nsclc-301/
├── protocol/
│   └── synopsis.md (v1.1) ✅
├── crf/                                    ✅ Phase 2 complete (Gate 2 APPROVED)
│   ├── CRF-STRATEGY.md (v2.0 — locked)
│   ├── SIMULATED-TORIVUMAB-2026_CRF.xlsx  (21 sheets)
│   ├── field_definitions.csv              (131 fields, 16 forms)
│   ├── visit_schedule.csv                 (20 visit types)
│   ├── codelist_reference.csv             (233 entries, CDISC CT 2024-03)
│   ├── CRF_Annotated.html                 (self-contained aCRF, ~1.3 MB)
│   ├── CRF_Annotated.pdf                  (xelatex aCRF, ~94 KB)
│   ├── CRF_Annotated.Rmd                  (programmatic source)
│   ├── CRF_Preview.pdf / .html / .Rmd
│   ├── build_crf_workbook.R
│   └── build_crf_pdf.R
├── data-raw/                               ✅ Phase 3/4 COMPLETE
│   ├── PROVENANCE.md
│   ├── 00_run_all.R                       (orchestrator)
│   ├── 01_dm.R  …  14_dd.R               (14 domain scripts, seeds 301–314)
│   ├── 15_label_domains.R                 (SDTMIG v3.4 label attachment)
│   └── raw_data/                          (generated CSVs — gitignored)
├── sdtm/                                   ✅ 16 Parquet domains — SDTMIG v3.4 labelled
│   └── *.parquet (committed, 1.7 MB)
├── adam/                                   ⏳ Phase 5
│   └── *.parquet (6 datasets)
├── tfl/                                    ⏳ Phase 6
│   ├── t_*.R, f_*.R, l_*.R
│   ├── tables/, figures/, listings/
├── define/                                 ⏳ Phases 4-5
│   ├── define.xml (v2.1)
│   └── define.pdf
├── csr/                                    ⏳ Phase 7
│   └── csr.pdf
├── adrg/                                   ⏳ Phase 8
│   └── adrg.pdf
├── onco_phase3_solid/
│   └── (Parquet export for clinTrialData)
├── ROADMAP.md (this file)
├── AGENTS.md
├── PHASE-2-GATE-REVIEW.md
└── README.md
```

---

*Last updated: 2026-04-07*  
*Phases 3 & 4 complete — 16 SDTM Parquet domains generated, SDTMIG v3.4 labels attached → Gate 3 LG review → Phase 5 ADaM*
