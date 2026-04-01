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
| 2 | Annotated CRF (aCRF) | ✅ Complete (2026-04-01) — Gate 2 review pending |
| 3 | Simulated Database | ⏳ Next |
| 4 | SDTM (19 domains) | ⏳ |
| 5 | ADaM (6 datasets) | ⏳ |
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
├── crf/                                         ✅ Phase 2 complete
│   ├── CRF-STRATEGY.md (v2.0 — locked)
│   ├── SIMULATED-TORIVUMAB-2026_CRF.xlsx       21-sheet annotated CRF workbook
│   ├── field_definitions.csv                    131 fields across 16 forms
│   ├── visit_schedule.csv                       20 visit types with windows
│   ├── codelist_reference.csv                   218 entries (CDISC CT 2024-03)
│   ├── CRF_Preview.pdf                          Visual mockup for review
│   ├── build_crf_workbook.R                     Reproducible Excel generation
│   └── build_crf_pdf.R                          Reproducible PDF generation
│
├── data-raw/                                    ⏳ Phase 3
│   ├── PROVENANCE.md
│   └── *.R  (generation scripts, 1 per domain)
│
├── sdtm/                                        ⏳ Phase 4
│   └── *.parquet  (19 domains)
│
├── adam/                                        ⏳ Phase 5
│   └── *.parquet  (6 datasets)
│
├── tfl/                                         ⏳ Phase 6
│   ├── t_*.R, f_*.R, l_*.R
│   └── tables/, figures/, listings/
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
