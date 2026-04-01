# ROADMAP — CTX-NSCLC-301 Data Generation Pipeline

**Document:** ROADMAP.md  
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Last updated:** 2026-04-01  
**Status:** Phase 2 complete → Phase 3 (Simulated Database) next

---

## Executive Summary

End-to-end pipeline for generating a synthetic Phase 3 NSCLC clinical trial dataset conforming to CDISC standards (SDTMIG v3.4, ADaMIG v1.3), for contribution to `clinTrialData` R package.

**Pipeline sequence:**
```
1. Protocol         ✅ COMPLETE (v1.1, 2026-03-30)
   ↓
2. aCRF             ✅ COMPLETE (Gate 2 delivered 2026-04-01)
   ↓
3. Simulated Database ⏳ NEXT
   ↓
4. SDTM (19 domains)
   ↓
5. ADaM (6 datasets)
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
**Gate 2 (CRF Design):** ⏳ Pending LG review

**Purpose:** Define all data collection fields, visit windows, assessment timing, and SDTM variable mappings.

**Deliverables:**

| Item | Status | Location |
|------|--------|----------|
| CRF Excel Workbook | ✅ Done | `crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx` (21 sheets, 96 KB) |
| Field Definitions | ✅ Done | `crf/field_definitions.csv` (131 fields, 16 forms) |
| Visit Schedule | ✅ Done | `crf/visit_schedule.csv` (20 visit types) |
| Codelist Reference | ✅ Done | `crf/codelist_reference.csv` (218 entries, CDISC CT 2024-03) |
| CRF Visual Mockup (PDF) | ✅ Done | `crf/CRF_Preview.pdf` (287 KB) |
| CRF Visual Mockup (HTML) | ✅ Done | `crf/CRF_Preview.html` |
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

---

## Phase 3: Simulated Database ⏳

**Status:** NOT STARTED — next phase

**Purpose:** Generate realistic raw trial data (as if collected via eCRF) before SDTM transformation.

**Deliverables:**

| Item | Description | Output |
|------|-------------|--------|
| Raw data tables | CSV with raw entry values (pre-SDTM) | `data-raw/raw_data/` |
| Demographic data | 450 subjects with randomisation, baseline chars | `data-raw/raw_data/demographics.csv` |
| Exposure data | Dosing schedule, dose modifications, compliance | `data-raw/raw_data/dosing.csv` |
| Safety data | Adverse events, labs, vital signs | `data-raw/raw_data/safety.csv` |
| Efficacy data | Imaging assessments, tumour measurements, response | `data-raw/raw_data/efficacy.csv` |
| Disposition | Study completion/discontinuation reasons | `data-raw/raw_data/disposition.csv` |
| R generation scripts | Reproducible data generation | `data-raw/01_demographics.R`, etc. |

**Key characteristics:**
- 450 subjects (300 active, 150 placebo)
- ~18-month accrual period
- ~24-month minimum follow-up
- Realistic event rates (OS HR=0.65, PFS HR=0.55 vs placebo)
- Correlated variables (baseline characteristics → compliance → dropout)
- MCAR missing data pattern

**Technology:** R scripts using `set.seed()` for reproducibility

**Timeline:** ~7 days

---

## Phase 4: SDTM ⏳

**Status:** NOT STARTED

**Purpose:** Transform raw database into CDISC SDTM format (19 domains).

**Core domains (12):**

| Domain | Description | Est. Records |
|--------|-------------|---------|
| DM | Demographics | 450 |
| AE | Adverse Events | ~2,000–3,000 |
| CM | Concomitant Meds | ~1,000–2,000 |
| DS | Disposition | 450 |
| EX | Exposure | ~15,000+ |
| LB | Laboratory | ~10,000+ |
| RS | Disease Response | ~1,800 |
| TU | Tumour ID | ~500–1,000 |
| TR | Tumour Results | ~5,000+ |
| VS | Vital Signs | ~2,700 |
| MH | Medical History | ~450–900 |
| SU | Substance Use | 450 |

**Supplementary datasets (6):** SUPPDM, SUPPAE, SUPPEX, SUPPRS, SUPPTR, SUPPTU

**Relational dataset (1):** RELREC — links TU → TR → RS for RECIST 1.1 traceability

**Generation order (dependency chain):**
1. DM (backbone)
2. EX (drives exposure variables)
3. DS (drives censoring in ADTTE)
4. AE, CM, MH, SU, VS, LB (relatively independent)
5. TU → TR → RS (linked chain)
6. SUPP-- datasets
7. RELREC

**Technology:** R + admiral + admiralonco + metacore

**Timeline:** ~10 days

---

## Phase 5: ADaM ⏳

**Status:** NOT STARTED

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
| 3. Simulated DB | ⏳ Next | 7 | 7 |
| 4. SDTM | ⏳ | 10 | 17 |
| 5. ADaM | ⏳ | 7 | 24 |
| 6. TFLs | ⏳ | 5 | 29 |
| 7. CSR | ⏳ | 7 | 36 |
| 8. ADRG | ⏳ | 4 | 40 |

**Parallel validation & Define-XML:** +5 days (concurrent)  
**Realistic remaining timeline: ~6 weeks**

---

## Gate Reviews

| Gate | Phase | Status | Date |
|------|-------|--------|------|
| Gate 1 | CRF Strategy | ✅ PASSED | 2026-03-30 |
| Gate 2 | CRF Design | ⏳ Pending LG review | est. 2026-04-04 |
| Gate 3 | Simulated Database | ⏳ | — |
| Gate 4 | SDTM | ⏳ | — |
| Gate 5 | ADaM | ⏳ | — |
| Gate 6 | TFLs | ⏳ | — |
| Gate 7 | CSR + ADRG | ⏳ | — |

---

## Success Criteria

- [x] aCRF complete & approved
- [ ] Simulated data reproducible (via `set.seed()`)
- [ ] SDTM datasets conform to SDTMIG v3.4 & CDISC CT 2024-03
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
├── crf/                                    ✅ Phase 2 complete
│   ├── CRF-STRATEGY.md (v2.0 — locked)
│   ├── SIMULATED-TORIVUMAB-2026_CRF.xlsx  (21 sheets)
│   ├── field_definitions.csv              (131 fields)
│   ├── visit_schedule.csv                 (20 visits)
│   ├── codelist_reference.csv             (218 entries)
│   ├── CRF_Preview.pdf
│   ├── CRF_Preview.html
│   ├── CRF_Preview.Rmd
│   ├── build_crf_workbook.R
│   └── build_crf_pdf.R
├── data-raw/                               ⏳ Phase 3
│   ├── PROVENANCE.md
│   ├── 01_demographics.R
│   ├── 02_exposure.R
│   └── ... (19 scripts total)
├── sdtm/                                   ⏳ Phase 4
│   └── *.parquet (19 domains)
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

*Last updated: 2026-04-01*  
*Phase 2 complete — awaiting Gate 2 approval before Phase 3 kick-off*
