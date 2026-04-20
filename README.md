# SIMULATED-TORIVUMAB-2026 — Torivumab Phase 3 NSCLC Study

> ⚠️ **FICTIONAL EDUCATIONAL DOCUMENT — NOT FOR REGULATORY USE.**  
> All identifiers, patient data, drug names, and results are completely synthetic.  
> Celindra Therapeutics and torivumab are fictional. Do NOT submit to any regulatory authority or clinical registry.

A fully synthetic, end-to-end oncology Phase 3 clinical trial dataset conforming to CDISC standards.  
Developed as a contribution to the [`clinTrialData`](https://github.com/Lovemore-Gakava/clinTrialData) R package.

---

## Study Overview

| | |
|---|---|
| **Study ID** | SIMULATED-TORIVUMAB-2026 |
| **Short Title** | TORIVA-LUNG 301 |
| **Sponsor** | Celindra Therapeutics *(fictional)* |
| **Drug** | Torivumab 200 mg IV Q3W (anti-PD-L1 monoclonal antibody) *(fictional)* |
| **Indication** | Advanced/metastatic NSCLC, Stage IIIB/IV |
| **Population** | First-line, PD-L1 TPS ≥50%, no EGFR/ALK mutations |
| **Design** | Randomised, double-blind, placebo-controlled, multinational |
| **N** | 450 subjects (300 torivumab : 150 placebo, 2:1) |
| **Primary Endpoint** | Overall Survival (OS) |
| **Secondary Endpoints** | PFS, ORR, Safety |
| **Response Criteria** | RECIST 1.1 |
| **Treatment Duration** | Up to 35 cycles (~2 years) or until PD/unacceptable toxicity |

---

## Pipeline Progress

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Protocol Synopsis | ✅ Complete (v1.1, 2026-03-30) |
| 2 | Annotated CRF (aCRF) | ✅ Complete — Gate 2 APPROVED (2026-04-01) |
| 3 | Simulated Database | ✅ Complete (2026-04-07) |
| 4 | SDTM (16 domains + SUPP) | ✅ Complete — 16 Parquet domains, SDTMIG v3.4 labelled |
| 4.5 | SAP + TFL shells | ⏳ Next — Gate 3.5 (blocks ADaM) |
| 5 | ADaM (6 datasets) | ⏳ Blocked on Gate 3.5 — spec-first approach ([see `adam/PHASE-5-APPROACH.md`](adam/PHASE-5-APPROACH.md)) |
| 6 | TFLs | ⏳ |
| 7 | CSR | ⏳ |
| 8 | ADRG | ⏳ |

See [ROADMAP.md](ROADMAP.md) for full details and timelines.

---

## Repository Structure

```
torivumab-nsclc-301/
├── protocol/
│   └── synopsis.md (v1.1 — locked) ✅
│
├── crf/                                         ✅ Phase 2 complete — Gate 2 APPROVED
│   ├── CRF-STRATEGY.md (v2.0 — locked)
│   ├── SIMULATED-TORIVUMAB-2026_CRF.xlsx       21-sheet CRF workbook
│   ├── field_definitions.csv                    131 fields across 16 forms
│   ├── visit_schedule.csv                       20 visit types with windows
│   ├── codelist_reference.csv                   233 entries (CDISC CT 2024-03)
│   ├── CRF_Annotated.html                       Self-contained aCRF (~1.3 MB)
│   ├── CRF_Annotated.pdf                        PDF aCRF (xelatex, ~94 KB)
│   ├── CRF_Annotated.Rmd                        Programmatic aCRF source
│   ├── CRF_Preview.pdf / .html / .Rmd           Visual mockup
│   ├── build_crf_workbook.R
│   └── build_crf_pdf.R
│
├── data-raw/                                    ✅ Phase 3/4 complete
│   ├── PROVENANCE.md
│   ├── 00_run_all.R                             Pipeline orchestrator
│   ├── 01_dm.R … 14_dd.R                       14 domain scripts (seeds 301–314)
│   └── 15_label_domains.R                      SDTMIG v3.4 label attachment
│
├── sdtm/                                        ✅ 16 Parquet domains — SDTMIG v3.4 labelled
│   └── *.parquet  (committed, 1.7 MB)
│
├── sap/                                          ⏳ Phase 4.5 — Gate 3.5
│   └── SAP.md                                    Statistical Analysis Plan (populations, endpoints, methods)
│
├── tfl/                                          ⏳ Phase 4.5 (shells) + Phase 6 (code)
│   ├── TFL-SHELLS.md                             List of all planned T/F/L outputs
│   ├── t_*.R, f_*.R, l_*.R                       Phase 6 code
│   └── tables/, figures/, listings/              Phase 6 output
│
├── adam/                                        ⏳ Phase 5 — spec-first, blocked on Gate 3.5
│   ├── PHASE-5-APPROACH.md                       Decision log (D-06, D-07, D-08, D-09)
│   ├── adsl.R … adtte.R                          6 derivation scripts
│   └── *.parquet                                 6 datasets
│
├── programming-specs/                            ⏳ Phase 5 — one spec per ADaM dataset
│   └── AD{SL,AE,LB,TR,RS,TTE}-spec.md
│
├── define/                                      ⏳ Phases 4–5
│   ├── define.xml (v2.1)
│   └── define.pdf
│
├── csr/                                         ⏳ Phase 7
├── adrg/                                        ⏳ Phase 8
├── onco_phase3_solid/                           Final Parquet export for clinTrialData
│
├── ROADMAP.md
├── AGENTS.md
└── PHASE-2-GATE-REVIEW.md
```

---

## Standards

| Standard | Version | Purpose |
|----------|---------|---------|
| CDASH | v2.1 | CRF data collection |
| SDTMIG | v3.4 | Study data tabulation |
| ADaMIG | v1.3 | Analysis data model |
| CDISC CT | 2024-03 | Controlled terminology |
| RECIST | 1.1 | Oncology response criteria |
| Define-XML | v2.1 | Dataset metadata |
| MedDRA | v27.0 | Adverse event coding |
| CTCAE | v5.0 | Toxicity grading |

---

## Pharmaverse Stack

`admiral` · `admiralonco` · `metacore` · `metatools` · `xportr` · `rtables` · `tern` · `teal`

---

## License

Synthetic data — educational use only. CC BY 4.0.
