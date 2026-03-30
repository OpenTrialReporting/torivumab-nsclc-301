# ROADMAP — CTX-NSCLC-301 Data Generation Pipeline

**Document:** ROADMAP.md  
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Last updated:** 2026-03-30  
**Status:** Planning phase → Data generation phase

---

## Executive Summary

End-to-end pipeline for generating a synthetic Phase 3 NSCLC clinical trial dataset conforming to CDISC standards (SDTMIG v3.4, ADaMIG v1.3), for contribution to `clinTrialData` R package.

**Pipeline sequence (LOCKED):**
```
1. Protocol ✅ DONE
   ↓
2. aCRF (Annotated CRF)
   ↓
3. Simulated Database (raw trial data)
   ↓
4. SDTM (Study Data Tabulation Model)
   ↓
5. ADaM (Analysis Data Model)
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

## Phase 2: aCRF (Annotated Case Report Form) ⏳

**Status:** NOT STARTED

**Purpose:** Define all data collection fields, visit windows, assessment timing, and SDTM variable mappings.

**Deliverables:**
| Item | Description | Output |
|------|-------------|--------|
| aCRF document | Annotated form with SDTM mappings | `crf/aCRF.pdf` or `crf/aCRF.docx` |
| Field definitions | Variable names, labels, data types, ranges | `crf/field_definitions.csv` |
| Visit schedule | Baseline, on-treatment, follow-up windows | `crf/visit_schedule.csv` |
| Assessment windows | Timepoints for imaging, labs, safety | `crf/assessment_windows.csv` |
| Coding rules | MedDRA, CTCAE v5, WHO Drug guidance | `crf/coding_rules.md` |

**Key forms:**
- Demographics & eligibility
- Baseline characteristics (ECOG, medical history, prior therapy)
- On-treatment visits (dosing, safety, response assessment)
- Adverse events (MedDRA coding, CTCAE grade, attribution)
- Labs (standard panels, baseline/abnormal range cutoffs)
- Vital signs (BP, HR, temperature, respiration)
- Disposition (completion, discontinuation, reason)
- End-of-study/follow-up

**Timeline for Phase 2:** 3–5 days (document intensive, requires CDISC reference review)

---

## Phase 3: Simulated Database ⏳

**Status:** NOT STARTED

**Purpose:** Generate realistic raw trial data (as if collected via eCRF) before SDTM transformation.

**Deliverables:**
| Item | Description | Output |
|------|-------------|--------|
| Raw data tables | CSV/Excel with raw entry values (pre-SDTM) | `data-raw/raw_data/` |
| Demographic data | 450 subjects with randomisation, baseline chars | `data-raw/raw_data/demographics.csv` |
| Exposure data | Dosing schedule, dose modifications, compliance | `data-raw/raw_data/dosing.csv` |
| Safety data | Adverse events, labs, vital signs | `data-raw/raw_data/safety.csv` |
| Efficacy data | Imaging assessments, tumour measurements, response | `data-raw/raw_data/efficacy.csv` |
| Disposition | Study completion/discontinuation reasons | `data-raw/raw_data/disposition.csv` |
| R generation scripts | Reproducible data generation | `data-raw/01_demographics.R`, `02_efficacy.R`, etc. |

**Key characteristics:**
- 450 subjects (300 active, 150 placebo)
- ~18-month accrual period
- ~24-month minimum follow-up
- Realistic event rates (OS, PFS, AE)
- Correlated variables (e.g., baseline characteristics → compliance → dropout)
- Censoring patterns (e.g., lost to follow-up, end of study)

**Technology:** R scripts using `set.seed()` for reproducibility

**Timeline for Phase 3:** 5–7 days

---

## Phase 4: SDTM ⏳

**Status:** NOT STARTED

**Purpose:** Transform raw database into CDISC SDTM format (19 domains).

**Core domains (12):**
| Domain | Description | Records |
|--------|-------------|---------|
| DM | Demographics | 450 (1 per subject) |
| AE | Adverse Events | ~2,000–3,000 (varies by rate) |
| CM | Concomitant Meds | ~1,000–2,000 |
| DS | Disposition | 450 (1 per subject) |
| EX | Exposure | ~15,000+ (cycles × subjects) |
| LB | Laboratory | ~10,000+ (visits × tests × subjects) |
| RS | Disease Response | ~1,800 (visits × subjects) |
| TU | Tumour ID | ~500–1,000 (lesions across subjects) |
| TR | Tumour Results | ~5,000+ (lesions × visits) |
| VS | Vital Signs | ~2,700 (visits × subjects) |
| MH | Medical History | ~450–900 (conditions per subject) |
| SU | Substance Use | 450 (smoking status) |

**Supplementary datasets (6):**
SUPPDM, SUPPAE, SUPPEX, SUPPRS, SUPPTR, SUPPTU

**Relational dataset (1):**
RELREC — links TU → TR → RS for RECIST 1.1 traceability

**Generation order (dependency chain):**
1. DM (backbone — all others join to this)
2. EX (drives exposure variables)
3. DS (drives censoring in ADTTE)
4. AE, CM, MH, SU, VS, LB (relatively independent)
5. TU → TR → RS (linked chain)
6. SUPP-- datasets
7. RELREC

**Deliverables:**
| Item | Output |
|------|--------|
| R generation scripts | `data-raw/sdtm_01_dm.R`, `sdtm_02_ex.R`, ..., `sdtm_19_relrec.R` |
| SDTM datasets (Parquet) | `sdtm/dm.parquet`, `sdtm/ae.parquet`, ..., `sdtm/relrec.parquet` |
| SDTM datasets (SAS XPT) | Optional: `sdtm/*.xpt` for regulatory submission |
| SDTM validation report | Dataset specifications, variable counts, QC checks |

**Technology:** R + admiral + admiralonco + metacore

**Timeline for Phase 4:** 7–10 days

---

## Phase 5: ADaM ⏳

**Status:** NOT STARTED

**Purpose:** Derive analysis datasets from SDTM (6 datasets).

**Datasets:**
| Dataset | Description | Records |
|---------|-------------|---------|
| ADSL | Subject-level (demographics, treatment, disposition, baseline) | 450 |
| ADAE | Adverse events analysis (CTCAE grade, treatment-emergent flags) | ~2,000–3,000 |
| ADLB | Laboratory analysis (baseline, change from baseline, abnormal flags) | ~10,000+ |
| ADRS | Disease response (BOR, confirmed response, progression) | ~450–900 |
| ADTR | Tumour measurements (SLD, % change, nadir tracking) | ~5,000+ |
| ADTTE | Time-to-event (OS, PFS with censoring rules) | 450 |

**Key ADaM derivations:**
- **ADSL:** Analysis population flags (SAFFL, ITTFL, PPROTFL), baseline characteristics
- **ADTTE OS:** Event = death; censoring = last known alive date
- **ADTTE PFS:** Event = progression or death; censoring = last adequate assessment
- **ADRS BOR:** Best overall response (CR/PR/SD/PD); confirmed response = 2 consecutive PRs
- **ADTR SLD:** Sum of longest diameters; % change from nadir

**Deliverables:**
| Item | Output |
|------|--------|
| R generation scripts | `adam/01_adsl.R`, `adam/02_adae.R`, ..., `adam/06_adtte.R` |
| ADaM datasets (Parquet) | `adam/adsl.parquet`, `adam/adae.parquet`, ..., `adam/adtte.parquet` |
| ADaM datasets (SAS XPT) | Optional: `adam/*.xpt` |
| Specification document | Variable definitions, derivation rules per dataset |

**Technology:** R + admiral + admiralonco + xportr

**Timeline for Phase 5:** 5–7 days

---

## Phase 6: TFLs (Tables, Figures, Listings) ⏳

**Status:** NOT STARTED

**Purpose:** Generate publication-ready tables, figures, and listings from ADaM.

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

**Deliverables:**
| Item | Output |
|------|--------|
| R scripts (rtables/tern) | `tfl/t_*.R`, `tfl/f_*.R`, `tfl/l_*.R` |
| Output files (HTML/PDF) | `tfl/tables/`, `tfl/figures/`, `tfl/listings/` |
| TFL specification | Which ADaM variables used, filters, analyses per table |

**Technology:** R + rtables + tern + gt/flextable

**Timeline for Phase 6:** 3–5 days

---

## Phase 7: CSR (Clinical Study Report) ⏳

**Status:** NOT STARTED

**Purpose:** Comprehensive study report narrative and results summary.

**Sections:**
- Executive summary
- Background & rationale
- Study objectives & endpoints
- Study methods (design, population, treatment, assessments)
- Results (disposition, demographics, efficacy, safety)
- Discussion & conclusions
- References

**Deliverables:**
- CSR document (Word or PDF) with embedded TFLs

**Timeline for Phase 7:** 5–7 days (after TFLs complete)

---

## Phase 8: ADRG (Analysis Data Reviewer's Guide) ⏳

**Status:** NOT STARTED

**Purpose:** Technical guide to ADaM datasets for data users (biostatisticians, regulators).

**Contents:**
- Dataset overview & purposes
- Variable definitions & coding
- Derivation algorithms (with pseudocode)
- Missing data handling
- Analysis population flags
- Subgroup analysis approach
- References to specifications (CRF, SDTM, protocol)

**Deliverables:**
- ADRG document (Word or PDF)

**Timeline for Phase 8:** 3–4 days

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

## Total Timeline Estimate

| Phase | Days | Cumulative |
|-------|------|-----------|
| 1. Protocol | 0 (done) | — |
| 2. aCRF | 5 | 5 |
| 3. Simulated DB | 7 | 12 |
| 4. SDTM | 10 | 22 |
| 5. ADaM | 7 | 29 |
| 6. TFLs | 5 | 34 |
| 7. CSR | 7 | 41 |
| 8. ADRG | 4 | 45 |
| **Total** | | **~45 days** |

**Parallel validation & Define-XML:** +5 days (concurrent)  
**Final QC & documentation:** +3 days

**Realistic timeline: 6–8 weeks** (working on this full-time)

---

## Checkpoints & Gate Reviews

| Gate | Trigger | Decision |
|------|---------|----------|
| Gate 1 | aCRF complete | Approve visit schedule, coding rules, field mappings |
| Gate 2 | Simulated DB complete | Approve data characteristics, event rates, missing patterns |
| Gate 3 | SDTM complete | Approve domain structure, variable compliance, codelist conformance |
| Gate 4 | ADaM complete | Approve population flags, derivation logic, analysis readiness |
| Gate 5 | TFLs complete | Approve statistical outputs, figure quality, clinical relevance |
| Gate 6 | CSR + ADRG complete | Final approval for clinTrialData contribution |

---

## Decision Points Still Open

| # | Decision | Options | Status |
|---|----------|---------|--------|
| D-01 | aCRF format | PDF mock-up vs detailed specifications spreadsheet | ⏳ LG to decide |
| D-02 | MedDRA version | Use v27.0 or simplified synthetic coding? | ⏳ LG to decide |
| D-03 | Lab data realism | Realistic distributions vs simple uniform ranges? | ⏳ LG to decide |
| D-04 | Missing data patterns | MCAR (completely random) vs MNAR (dependent)? | ⏳ LG to decide |
| D-05 | Event rates | Conservative (match KEYNOTE-024) vs optimistic? | ⏳ LG to decide |

---

## Success Criteria

- [ ] aCRF complete & approved
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

## File Structure (Post-completion)

```
torivumab-nsclc-301/
├── protocol/
│   └── synopsis.md (v1.1) ✅
├── crf/
│   ├── aCRF.pdf (or .docx)
│   ├── field_definitions.csv
│   ├── visit_schedule.csv
│   ├── assessment_windows.csv
│   └── coding_rules.md
├── data-raw/
│   ├── PROVENANCE.md
│   ├── 01_demographics.R
│   ├── 02_exposure.R
│   ├── 03_disposition.R
│   ├── ...
│   ├── 19_relrec.R
│   └── raw_data/ (input CSVs)
├── sdtm/
│   ├── dm.parquet
│   ├── ae.parquet
│   └── ... (19 datasets)
├── adam/
│   ├── adsl.parquet
│   ├── adae.parquet
│   └── ... (6 datasets)
├── tfl/
│   ├── t_dm_01.R
│   ├── tables/
│   ├── figures/
│   └── listings/
├── define/
│   ├── define.xml
│   └── define.pdf
├── csr/
│   └── csr.pdf
├── adrg/
│   └── adrg.pdf
├── onco_phase3_solid/
│   └── (Parquet export for clinTrialData)
├── ROADMAP.md (this file)
├── README.md
└── .git/
```

---

*Last updated: 2026-03-30 19:14 UTC*  
*Locked & ready for Phase 2 (aCRF) kick-off*
