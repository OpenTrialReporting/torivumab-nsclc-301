# AGENTS.md — SIMULATED-TORIVUMAB-2026

Context guide for AI coding assistants and human contributors working on the fictional Phase 3 NSCLC clinical trial dataset project.

---

## Project Overview

**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Type:** Fully synthetic Phase 3 NSCLC clinical trial dataset  
**Purpose:** Educational reference for CDISC standards + pharmaverse stack development  
**Contribution:** Candidate dataset for `clinTrialData` R package

⚠️ **CRITICAL:** This is a completely fictional study. All identifiers, patient data, and results are synthetic. **Do NOT submit to regulatory authorities or clinical registries.**

---

## Phase Roadmap

Current phase: **Phase 3/4 data generation — scripts written, pending execution**

```
Phase 1: Protocol ✅ DONE
   ↓
Phase 2: aCRF (Annotated Case Report Form) ✅ DONE — Gate 2 APPROVED (2026-04-01)
   ↓
Phase 3: Simulated Database (synthetic raw data) ✅ SCRIPTS WRITTEN (2026-04-04)
   ↓ (data-raw/ scripts also produce SDTM parquet — phases 3 & 4 unified)
Phase 4: SDTM (14 domains + SUPPDM + SUPPSU) ✅ SCRIPTS WRITTEN (2026-04-04)
   ↓
Phase 5: ADaM (6 datasets) ⏳ NEXT
   ↓
Phase 6: TFLs (Tables, Figures, Listings)
   ↓
Phase 7: CSR (Clinical Study Report)
   ↓
Phase 8: ADRG (Analysis Data Reviewer's Guide)
```

> **To generate data:** run `source("data-raw/00_run_all.R")` from the project root.
> Requires: `{dplyr}`, `{lubridate}`, `{arrow}`, `{purrr}` (all in renv.lock)

## CDISC & Clinical Standards

### Standards & Versions (LOCKED)
| Standard | Version | Purpose |
|----------|---------|---------|
| CDASH | v2.1 | Case Report Form structure (collection) |
| SDTMIG | v3.4 | Study Data Tabulation Model (submission) |
| ADaMIG | v1.3 | Analysis Data Model (analysis) |
| CDISC CT | 2024-03 | Controlled Terminology codelists |
| RECIST | 1.1 | Oncology response criteria |
| Define-XML | v2.1 | Dataset metadata |
| MedDRA | v27.0 | Adverse event coding |
| CTCAE | v5.0 | Toxicity grading |

### Study Design (LOCKED)
- **Indication:** Non-Small Cell Lung Cancer (NSCLC)
- **Phase:** 3, randomised, double-blind, placebo-controlled
- **Population:** 450 subjects (300 active, 150 placebo), 2:1 ratio
- **Stratification:** PD-L1 TPS (≥50% required), Histology (squamous/non-squamous), Region (NA/EU/APAC)
- **Primary endpoint:** Overall Survival (OS)
- **Secondary:** PFS, ORR, Safety
- **Response criteria:** RECIST 1.1 (Blinded Independent Central Review)
- **Accrual:** ~18 months
- **Follow-up:** ≥24 months minimum

### Biomarker Testing (LB Domain)
All patients require baseline testing:
- **PD-L1 TPS:** ≥50% (22C3 pharmDx, central lab) — ELIGIBILITY CRITERION
- **EGFR mutations:** Absence of sensitising mutations — EXCLUSION CRITERION
- **ALK rearrangement:** Absence of ALK fusions — EXCLUSION CRITERION
- **Other mutations (testing required, not exclusion):** ROS1, KRAS G12C, MET exon 14, RET, BRAF V600E, NTRK
- **TMB (optional):** If genomic panel used

### Pharmaverse Stack
Recommended tools for data generation:

| Package | Use | Integration |
|---------|-----|-------------|
| {admiral} | ADaM derivation logic | Core SDTM → ADaM transformation |
| {admiralonco} | Oncology-specific ADaM | RECIST 1.1, response, TU/TR/RS derivation |
| {metacore} | Metadata specifications | CRF → SDTM mapping, variable control |
| {metatools} | Spec validation | Pre-generation validation of metadata |
| {xportr} | XPT transport format | SDTM/ADaM → submission-ready XPT files |
| {rtables} | Table rendering | TFL production |
| {tern} | Analysis functions | Efficacy/safety summaries |
| {teal} | Interactive apps | Optional: exploratory data review |

---

## Project Structure

```
torivumab-nsclc-301/
├── protocol/
│   └── synopsis.md (v1.1 — LOCKED)
├── crf/
│   ├── CRF-STRATEGY.md (v2.0 — LOCKED)
│   ├── field_definitions.csv (Phase 2 deliverable)
│   ├── visit_schedule.csv (Phase 2 deliverable)
│   └── codelist_reference.csv (Phase 2 deliverable)
├── data-raw/
│   ├── PROVENANCE.md (data generation record)
│   ├── 01_demographics.R (DM domain)
│   ├── 02_exposure.R (EX domain)
│   ├── 03_disposition.R (DS domain)
│   ├── ... (19 SDTM domains total)
│   └── raw_data/ (input CSVs for synthetic generation)
├── sdtm/
│   ├── dm.parquet
│   ├── ae.parquet
│   └── ... (19 domains total)
├── adam/
│   ├── adsl.parquet
│   ├── adae.parquet
│   └── ... (6 datasets total)
├── tfl/
│   ├── t_*.R (tables)
│   ├── f_*.R (figures)
│   └── l_*.R (listings)
├── define/
│   ├── define.xml (v2.1)
│   └── define.pdf
├── csr/
│   └── csr.pdf (Clinical Study Report)
├── adrg/
│   └── adrg.pdf (Analysis Data Reviewer's Guide)
├── onco_phase3_solid/
│   └── (Parquet export for clinTrialData)
├── ROADMAP.md (Phase workflow)
├── AGENTS.md (this file)
├── README.md (project overview)
└── git (all committed for reproducibility)
```

---

## CRF Design (Phase 2 — COMPLETE ✅)

### CDASH Version Alignment
- **aCRF:** CDASH v2.1 (OpenClinica Form Library)
- **Target SDTM:** SDTMIG v3.4
- **Target ADaM:** ADaMIG v1.3

**Traceability:** CRF variable names map directly to SDTM (e.g., AETERM → AETERM)

### CDASH Forms Selected

**Foundational (13 forms):**
1. DM — Demographics
2. DS — Disposition
3. IE — Inclusion/Exclusion Criteria
4. EC — Exposure as Collected (dosing, compliance)
5. DA — Drug Accountability
6. AE — Adverse Events
7. CM — Concomitant Medications
8. MH — Medical History
9. SU — Substance Use (Tobacco)
10. VS — Vital Signs
11. LB — Laboratory Test Results (includes biomarkers: PD-L1, mutations, TMB)
12. PE — Physical Examination
13. DD — Death Details

**Custom Oncology (3 forms):**
14. TU — Tumour Identification (baseline lesions, RECIST 1.1)
15. TR — Tumour Results (lesion measurements per visit)
16. RS — Disease Response (overall response per RECIST 1.1)

### Visit Schedule (LOCKED)
```
SCREENING (Day -28 to 0)
├── Screening Visit (Week -4)
│   └── Forms: DM, IE, MH, SU, VS, LB, PE, DS (eligibility check)
│
TREATMENT (Day 1 to ~EOT, ~18 month accrual + 24 month FU)
├── Baseline/Cycle 1 Day 1 (Week 1)
│   └── Forms: DM, EC (dose 1), VS, LB, PE, DS
├── Cycle 1 Days 8, 15, 22 (Weeks 2-4)
│   └── Forms: EC, VS, AE, CM (every visit)
├── Imaging Visits (Q6W for 18W, then Q12W)
│   └── Forms: TU, TR, RS (RECIST 1.1 assessment)
├── End-of-Cycle (every 21 days)
│   └── Forms: AE summary, dose modifications, LB (labs)
└── End-of-Treatment (~30 days post last dose)
    └── Forms: VS, LB (final safety), DS (completion reason)
│
OFF-TREATMENT FOLLOW-UP (Months 3, 6, 12, long-term)
├── Safety FU-01 to FU-03
│   └── Forms: AE, DS, VS
└── Long-Term Survival FU (Q12W by phone)
    └── Forms: Vital status only
```

### Key Fields & Codelists

**Demographics (DM):**
- SITEID, SUBJID, USUBJID, AGE, SEX, RACE, ETHNIC, COUNTRY, ARM, ACTARM

**Biomarkers (LB domain):**
- LBTESTCD = PD-L1_TPS, EGFR_MUT, ALK_REARR, ROS1_REARR, KRAS_G12C, MET_EX14, RET_REARR, BRAF_V600E, NTRK_FUSE, TMB
- Values per CDISC CT 2024-03 (or documented synonyms for synthetic data)

**Adverse Events (AE):**
- AETERM, AEDECOD (MedDRA v27.0), AESEV, AESOC, AETOXGR (CTCAE v5.0), AEREL, AESER, AEACN

**Efficacy (TU, TR, RS):**
- TU: TULOC (lesion location), TUSTRESC (measurement method: CT/MRI)
- TR: TRTESTCD, TRORRES (longest diameter mm), TRSTRESC (% change)
- RS: RSTEST ("Overall Response"), RSORRES (CR/PR/SD/PD per RECIST 1.1)

---

## Data Generation (Phase 3 — UPCOMING)

### Synthetic Data Principles
- **Realistic but fictional:** Event rates match KEYNOTE-024 (OS HR 0.65, PFS HR 0.55)
- **Reproducible:** All R scripts use `set.seed()` for full reproducibility
- **Traceable:** Every dataset includes ORIGFIL, DATE, VERSION metadata
- **Compliant:** All SDTM/ADaM rules enforced (no manual edits)

### Generation Order (Dependency Chain)
1. DM (demographics — backbone, all others join to this)
2. EX (exposure — drives ADSL variables, compliance)
3. DS (disposition — drives ADTTE censoring rules)
4. AE, CM, MH, SU, VS, LB (independent from DM/EX/DS)
5. TU → TR → RS (linked chain for RECIST 1.1)
6. SUPP-- datasets (supplementary, alongside parents)
7. RELREC (links TU → TR → RS records)
8. ADaM (derive from SDTM: ADSL, ADAE, ADLB, ADRS, ADTR, ADTTE)
9. TFLs (tables, figures, listings from ADaM)

### Key Decisions (LOCKED)
| Decision | Value | Rationale |
|----------|-------|-----------|
| Missing Data Pattern | MCAR (completely random) | Simplifies generation; can add MNAR later if needed |
| Event Rates | Conservative (match KEYNOTE-024) | Realistic, benchmarked against real oncology trials |
| Lab Data Realism | Realistic distributions with outliers | Statistical validity for analysis workflows |
| MedDRA Version | v27.0 (or simplified synthetic) | Current standard; synthetic acceptable for POC |
| Parquet Format | Primary output | Lightweight, language-neutral, CDISC-compatible |

---

## Code Standards

### R Coding Style
- **Naming:** snake_case for functions, PascalCase for data objects
- **Documentation:** roxygen2 comments required for all functions
- **Testing:** `testthat` for unit tests, `snapshot_accept()` for dataset comparisons
- **Execution:** All scripts reproducible via `set.seed()`; no external dependencies outside renv.lock

### SDTM/ADaM Derivation
- **Never hardcode:** All logic reads from metadata (CRF specs, controlled terminology)
- **Preserve lineage:** Track source variables (ORIG*) in output
- **Flag variables:** ANL01FL, SAFFL, ITTFL take "Y" or NA — never "N"
- **ASEQ derivation:** Always last step before finalization
- **Censoring rules:** Locked per protocol, documented in SAP

### File Naming Convention
```
Phase 3 scripts:
├── data_raw/01_demographics.R       # DM domain
├── data_raw/02_exposure.R           # EX domain
├── data_raw/03_disposition.R        # DS domain
├── data_raw/...
├── data_raw/19_relrec.R             # RELREC linking
├── adam/01_adsl.R                   # ADSL dataset
├── adam/02_adae.R                   # ADAE dataset
└── adam/...
```

---

## Testing & Validation

### SDTM Validation Checklist
- [ ] All 19 domains present
- [ ] No duplicate records
- [ ] USUBJID consistency across domains
- [ ] Variable names match SDTMIG v3.4
- [ ] Codelists conform to CDISC CT 2024-03
- [ ] RECIST 1.1 TU/TR/RS logic validated
- [ ] RELREC correctly links lesion measurements

### ADaM Validation Checklist
- [ ] SAFFL (safety population) correctly flagged
- [ ] ITTFL (intent-to-treat) correctly flagged
- [ ] ASEQ sequential and correct
- [ ] ADTTE: OS and PFS derivation verified
- [ ] ADRS: BOR (Best Overall Response) logic validated
- [ ] ADTR: SLD (Sum of Longest Diameters) calculations correct
- [ ] Missing data patterns documented

### Regulatory Readiness
- [ ] Define-XML v2.1 valid (via xportr)
- [ ] All datasets SDTM/ADaM compliant
- [ ] CDISC Controlled Terminology aligned
- [ ] Audit trail complete (source → derived)
- [ ] SAP matches implemented analysis

---

## AI Assistant Guidance

If you are an AI assistant working on this project:

1. **Read this file and the ROADMAP first** — Understand the 8-phase workflow
2. **Current phase:** Phase 3 (Simulated Database) — Gate 2 approval pending; do NOT start Phase 3 scripts until LG approves Gate 2
3. **Respect the locked decisions:**
   - Protocol (v1.1) is final — no changes
   - CRF Strategy (v2.0) is final — no changes
   - Visit schedule is locked — no changes
4. **Standards are non-negotiable:**
   - CDASH v2.1 → SDTMIG v3.4 → ADaMIG v1.3 (traceability required)
   - RECIST 1.1 for response assessment
   - MedDRA v27.0 for AE coding
   - CTCAE v5.0 for toxicity grading
5. **Use pharmaverse as reference:**
   - {admiral} + {admiralonco} derivation patterns
   - {metacore} for metadata specs
   - {xportr} for submission-ready output
6. **Never hardcode clinical logic** — Metadata-driven only
7. **Test thoroughly:**
   - Unit tests for every derivation
   - Snapshot tests for dataset output
   - Cross-check against real clinical trial precedents (KEYNOTE-024, KEYNOTE-042)
8. **Document as you code:**
   - roxygen2 comments in R files
   - PROVENANCE.md updates for methodology changes
   - SAP updates as analysis logic evolves
9. **Add the comment `# torivumab guidelines loaded` at the top of new R files** — Confirms this AGENTS.md was read
10. **Flag ambiguities:** If a spec is unclear, raise it in GitHub Issues — don't guess

---

## Gate Review Process

Each phase must pass a Gate Review before proceeding:

**Gate 1 (CRF Strategy):** ✅ PASSED 2026-03-30
- [ ] All CDASH forms selected
- [ ] Visit schedule defined with windows
- [ ] All protocol data elements mapped
- [ ] Biomarker testing (LB) specified
- [ ] Codelists referenced to CDISC CT

**Gate 2 (CRF Design):** ⏳ Pending LG review (deliverables submitted 2026-04-01)
- [x] Excel CRF workbook complete (`crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx` — 21 sheets)
- [x] Field definitions CSV exported (`crf/field_definitions.csv` — 131 fields)
- [x] Visit schedule CSV exported (`crf/visit_schedule.csv` — 20 visits)
- [x] Codelist reference CSV exported (`crf/codelist_reference.csv` — 218 entries)
- [x] PDF mockup created (`crf/CRF_Preview.pdf`)
- [ ] LG approval — pending
- [ ] Ready for Phase 3 (Simulated Database)

**Future Gates (3–8):**
- Gate 3: Simulated database complete + validated
- Gate 4: SDTM datasets + Define-XML ready
- Gate 5: ADaM datasets + SAP finalized
- Gate 6: TFLs production-ready
- Gate 7: CSR narrative + results + discussion
- Gate 8: ADRG + clinTrialData package ready

---

## Questions & Discussions

For questions about:
- **Study design:** See `protocol/synopsis.md`
- **CRF structure:** See `crf/CRF-STRATEGY.md`
- **CDISC standards:** See references section below
- **Pharmaverse integration:** See {admiral} + {admiralonco} documentation
- **AI strategy:** admiraldev #547 (pharmaverse community discussion)

---

## References

### CDISC Standards
- [SDTMIG v3.4](https://www.cdisc.org/standards/foundational/sdtmig)
- [ADaMIG v1.3](https://www.cdisc.org/standards/foundational/adam)
- [CDISC Controlled Terminology 2024-03](https://www.cdisc.org/standards/terminology)
- [CDISC Oncology Disease Response Supplement (RECIST 1.1, 2023)](https://www.cdisc.org/standards/specialized/cdash-oncology)
- [Define-XML v2.1](https://www.cdisc.org/standards/data-exchange/define-xml)

### Clinical Trial References
- [KEYNOTE-024 (Reck et al., NEJM 2016; updated 2019)](https://www.nejm.org/doi/full/10.1056/NEJMoa1605643) — OS HR 0.60, PFS HR 0.50
- [KEYNOTE-042 (Langer et al., NEJM 2020)](https://www.nejm.org/doi/full/10.1056/NEJMoa1916015) — PFS HR 0.80

### Pharmaverse Documentation
- [{admiral} package](https://pharmaverse.github.io/admiral/)
- [{admiralonco} package](https://pharmaverse.github.io/admiralonco/)
- [{metacore} package](https://pharmaverse.github.io/metacore/)
- [{xportr} package](https://pharmaverse.github.io/xportr/)

### AI Strategy
- [pharmaverse blog: AGENTS.md & AI-Assisted Programming](https://pharmaverse.github.io/blog/)
- [rOpenSci AI Policy](https://ropensci.org/blog/2026/02/26/ropensci-ai-policy/)

---

⚠️ **REMINDER:** This is a fictional educational dataset. Do NOT submit to regulatory authorities or clinical registries.

---

*Last updated: 2026-04-01*  
*For AI-assisted CDISC standards development*
