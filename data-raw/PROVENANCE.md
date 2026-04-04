# PROVENANCE.md — Data Generation Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

This is a **fully synthetic** clinical trial dataset generated for educational purposes.  
No real patient data was used. No real clinical trial is described.  
All sponsor names, drug names, investigator names, and study identifiers are fictional.

This dataset was generated with **AI assistance** using the methodology described below.  
Users should be aware that AI-generated data may contain subtle inconsistencies not present  
in real clinical trial data. It is intended as a learning and development resource, not as  
a template for regulatory submission.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-sonnet-4-6` |
| **Interface** | OpenClaw (Nova) — Telegram-connected AI assistant |
| **Role** | Protocol design, data generation scripts, ADaM derivations, TFL code |
| **Human oversight** | Lovemore Gakava — domain expert review at each phase gate |
| **Generation started** | 2026-03-22 |

---

## 3. Primary Sources & References

| Reference | Used for |
|---|---|
| KEYNOTE-024 (Reck et al., NEJM 2016; updated 2019) | Statistical assumptions: OS HR, PFS HR, median OS/PFS, sample size |
| SDTMIG v3.4 (CDISC, November 2021) | SDTM domain structure and variable definitions |
| SDTM v2.0 (CDISC) | Core SDTM model |
| ADaMIG v1.3 (CDISC) | ADaM dataset structure and derivation rules |
| CDISC Oncology Disease Response Supplement — RECIST 1.1 (2023) | TU/TR/RS domain implementation, RELREC structure |
| ADaM Oncology Examples Document (CDISC, 2024) | ADRS, ADTR, ADTTE derivation approach |
| CDISC Controlled Terminology 2024-03 | Codelists for all domains |
| RECIST 1.1 (Eisenhauer et al., EJC 2009) | Response criteria definitions |
| CTCAE v5.0 (NCI, 2017) | Adverse event grading |
| Define-XML v2.1 (CDISC) | Define-XML structure |
| pharmaverse documentation (admiral, admiralonco, metacore, xportr) | R package implementation |

---

## 4. Statistical Assumptions & Justification

| Parameter | Value | Source/Justification |
|---|---|---|
| Primary endpoint | Overall Survival (OS) | Standard for first-line NSCLC Phase 3 |
| Secondary endpoint | Progression-Free Survival (PFS) | Standard co-endpoint in PD-L1 trials |
| OS HR assumption | 0.65 | Conservative vs KEYNOTE-024 observed HR 0.62; reflects typical "me-too" entrant |
| Median OS — control | 14.0 months | KEYNOTE-024 chemotherapy arm |
| Median OS — experimental | 21.5 months | Derived from HR 0.65 assumption |
| PFS HR assumption | 0.55 | Conservative vs KEYNOTE-024 observed HR 0.50 |
| Median PFS — control | 6.0 months | KEYNOTE-024 chemotherapy arm |
| Median PFS — experimental | 11.0 months | Derived from HR 0.55 assumption |
| Power | 80% | Standard industry practice |
| Type I error (α) | 0.05 (two-sided) | Standard |
| Events required (OS) | ~320 deaths | Log-rank test, 80% power, HR 0.65 |
| Accrual period | 18 months | Typical multinational Phase 3 |
| Follow-up period | 24 months minimum | Sufficient for OS maturity |
| Total sample size | 450 subjects | 300 active : 150 placebo (2:1) |
| Dropout rate | ~10% | Accounted for in sample size inflation |

---

## 5. Randomisation & Stratification

| Factor | Levels |
|---|---|
| PD-L1 TPS | High (≥50%) — all subjects by inclusion; subgroup analysis only |
| Histology | Squamous / Non-squamous |
| Geographic region | North America / Europe / Asia-Pacific |
| Randomisation ratio | 2:1 (active:placebo) |
| Method | Permuted block randomisation, stratified |

---

## 6. Reproducibility

All R data generation scripts are in `data-raw/`.  
Every script uses `set.seed()` for full reproducibility.

Run `data-raw/00_run_all.R` from the project root to regenerate all outputs in dependency order.

| Script | Seed | Generates |
|---|---|---|
| `00_run_all.R` | (orchestrator) | Runs all scripts in order |
| `01_dm.R` | `set.seed(301)` | DM + SUPPDM domains + subject_backbone.csv |
| `02_ex.R` | `set.seed(302)` | EX domain |
| `03_ds.R` | `set.seed(303)` | DS domain |
| `04_ae.R` | `set.seed(304)` | AE domain |
| `05_cm.R` | `set.seed(305)` | CM domain |
| `06_mh.R` | `set.seed(306)` | MH domain |
| `07_su.R` | `set.seed(307)` | SU + SUPPSU domains |
| `08_vs.R` | `set.seed(308)` | VS domain |
| `09_lb.R` | `set.seed(309)` | LB domain (haem/chem/thyroid/urinalysis/biomarkers) |
| `10_pe.R` | `set.seed(310)` | PE domain |
| `11_tu.R` | `set.seed(311)` | TU domain + tu_lesion_map.csv |
| `12_tr.R` | `set.seed(312)` | TR domain + tr_sum_diam.csv |
| `13_rs.R` | `set.seed(313)` | RS domain (RECIST 1.1 BOR + per-visit) |
| `14_dd.R` | `set.seed(314)` | DD domain |

**R session info** will be captured at generation time via `sessionInfo()` and saved to  
`data-raw/session_info.txt`.

**Package versions** will be locked via `renv` — see `renv.lock` in repo root.

---

## 7. Limitations

- Synthetic data cannot fully replicate the complexity and messiness of real clinical trial data
- Correlation structures between variables are approximated, not derived from real patient data
- Rare events (e.g. uncommon AEs) may be under- or over-represented
- AI model knowledge has a training cutoff — CDISC standards were verified against primary sources where possible but may not reflect the very latest guidance
- This dataset should not be used for regulatory submission or real clinical decision-making

---

## 8. Citation

If using this dataset, please cite as:

> Gakava, L. (2026). *CTX-NSCLC-301: A synthetic Phase 3 NSCLC clinical trial dataset  
> conforming to CDISC SDTMIG v3.4 and ADaMIG v1.3.*  
> OpenTrialReporting/torivumab-nsclc-301. GitHub.  
> Generated with AI assistance (Claude Sonnet 4-6, Anthropic).  
> https://github.com/OpenTrialReporting/torivumab-nsclc-301

---

*Last updated: 2026-04-04*
