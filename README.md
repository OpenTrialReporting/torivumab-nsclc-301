# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

A fully synthetic, end-to-end oncology Phase 3 clinical trial dataset conforming to CDISC standards.  
Developed as a contribution to the [`clinTrialData`](https://github.com/Lovemore-Gakava/clinTrialData) R package.

## Study Overview

| | |
|---|---|
| **Sponsor** | Celindra Therapeutics |
| **Drug** | Torivumab (anti-PD-L1 monoclonal antibody) |
| **Study ID** | CTX-NSCLC-301 |
| **Indication** | Non-Small Cell Lung Cancer (NSCLC) |
| **Phase** | 3 |
| **Design** | Randomised, double-blind, placebo-controlled |
| **Population** | First-line, PD-L1 TPS ≥50%, no EGFR/ALK mutations |
| **Primary endpoint** | Overall Survival (OS) |
| **N** | ~450 subjects |

## Repository Structure

```
torivumab-nsclc-301/
├── protocol/        # Study synopsis and protocol document
├── crf/             # Case report forms
├── data-raw/        # R scripts for synthetic data generation
├── sdtm/            # SDTM datasets (19 domains)
├── adam/            # ADaM datasets (6 datasets)
├── tfl/             # Tables, figures and listings
├── csr/             # Clinical study report
├── define/          # Define-XML v2.1
└── onco_phase3_solid/  # Final Parquet files for clinTrialData
```

## Standards

- SDTM v2.0 / SDTMIG v3.4
- ADaM v1.3 / ADaMIG v1.3
- CDISC Controlled Terminology 2024-03
- RECIST 1.1
- Define-XML v2.1

## Pharmaverse Stack

`admiral` · `admiralonco` · `metacore` · `metatools` · `xportr` · `rtables` · `tern` · `teal`

## License

Synthetic data — educational use only. CC BY 4.0.
