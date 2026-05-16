# TFL-PROVENANCE.md — Tables, Figures & Listings Development Record
# CTX-NSCLC-301 — SIMULATED-TORIVUMAB-2026

---

## 1. Disclosure

The TFL outputs in `tfl/` are produced by the R scripts in `programs/tfl/`
from the ADaM datasets in `datasets/adam/`. They visualise a fully synthetic
clinical trial and **are not intended for regulatory submission**.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-opus-4-7` |
| **Interface** | Claude Code (terminal) |
| **Role** | Phase 6a infrastructure scaffolding, table/figure code, output writers |
| **Human oversight** | Lovemore Gakava — confirmed pilot scope (5 outputs) and triple-format delivery (RTF + DOCX + HTML + PNG) |
| **Scripts written** | 2026-05-16 |

---

## 3. Phase 6 — Output Scope

### 6a (2026-05-16) — 5 outputs, pilot

| ID | Kind | Title | SAP / Estimand |
|---|---|---|---|
| T-DM-01  | Table  | Demographic and Baseline Characteristics  | §3 (descriptive) |
| T-EFF-01 | Table  | Overall Survival Analysis (Primary)        | §5.1 / E1 |
| T-EFF-03 | Table  | Progression-Free Survival (BICR)           | §5.2 / E2 |
| F-EFF-01 | Figure | Kaplan-Meier Curve — Overall Survival       | §5.1 / E1 |
| F-EFF-02 | Figure | Kaplan-Meier Curve — Progression-Free Surv. | §5.2 / E2 |

### 6b (2026-05-16) — 4 outputs, disposition + exposure

| ID | Kind | Title | SAP / Estimand |
|---|---|---|---|
| T-DS-01 | Table | Subject Disposition           | §3 (descriptive) |
| T-DS-02 | Table | Major Protocol Deviations     | §3.2 (descriptive) |
| T-DS-03 | Table | Intercurrent Events Summary    | §13.3 (IE taxonomy) |
| T-EX-01 | Table | Study Drug Exposure           | §5.5 (descriptive) |

### 6c (2026-05-16) — 15 outputs, all remaining efficacy

| ID | Kind | Title | SAP / Estimand |
|---|---|---|---|
| T-EFF-02 | Table  | KM Probabilities — OS                         | §5.1 / E1 supplement |
| T-EFF-04 | Table  | KM Probabilities — PFS                        | §5.2 / E2 supplement |
| T-EFF-05 | Table  | Objective Response Rate                       | §5.3 / E3 |
| T-EFF-06 | Table  | Disease Control Rate                          | §5.3 / E5 |
| T-EFF-07 | Table  | Duration of Response                          | §5.4 / E4 |
| T-EFF-08 | Table  | OS in Per-Protocol Population (Sensitivity)   | §11 sensitivity |
| T-EFF-09 | Table  | OS Landmark Analysis (Sensitivity)            | §11 sensitivity |
| T-EFF-10 | Table  | OS Restricted Mean Survival Time              | §13.4 / E1a |
| T-EFF-11 | Table  | PFS by Investigator (Sensitivity)             | §13.5 / E2a |
| T-EFF-12 | Table  | OS While-on-Treatment (Sensitivity)           | §13.4 / E1b |
| T-EFF-13 | Table  | ORR ITT Denominator (Sensitivity)             | §13.6 / E3a |
| F-EFF-03 | Figure | Waterfall — Best % Change in SLD              | §5.3 |
| F-EFF-04 | Figure | Spider — SLD Over Time                        | §5.3 |
| F-EFF-05 | Figure | Forest — OS HR by Subgroup                    | §10 subgroup |
| F-EFF-06 | Figure | Swimmer — Responder Timelines                 | §5.4 |

Total delivered so far: **24 / 38 outputs**. Remaining 14 (Phase 6d):
T-AE-01..07, T-LB-01/02, L-AE-01/02/03, L-LB-01, L-DS-01 — all safety/labs/listings. The pilot architecture is designed so adding a
new output is a single new script in `programs/tfl/` plus one line in
`00_run_tfl.R::tfl_programs`.

---

## 4. Architecture

```
programs/tfl/
├── 00_run_tfl.R              Orchestrator (sources scripts in order)
├── _helpers.R                Shared utilities (formatters, writers, theming)
├── _km_plot.R                Shared KM-curve helper (used by F-EFF-01/02)
├── t_dm_01_demographics.R    } One script per output
├── t_eff_01_os.R             } Sources _helpers.R, produces a flextable
├── t_eff_03_pfs.R            } or ggplot, calls write_table_all_formats()
├── f_eff_01_km_os.R          } or write_figure()
├── f_eff_02_km_pfs.R
├── 99_combine_outputs.R      Builds TFL-OUTPUTS.html + .docx aggregations
└── TFL-PROVENANCE.md         (this file)

tfl/
├── tables/                   Per-output triplets (RTF + DOCX + HTML)
│   ├── T-DM-01.rtf|.docx|.html
│   ├── T-EFF-01.rtf|.docx|.html
│   └── T-EFF-03.rtf|.docx|.html
├── figures/                  PNG only, 300 dpi
│   ├── F-EFF-01.png
│   └── F-EFF-02.png
├── TFL-OUTPUTS.html          Combined browser view (all 5 outputs)
└── TFL-OUTPUTS.docx          Combined Word view (cover + per-output pages)
```

### Why three formats per table?

| Format | Audience | Rationale |
|---|---|---|
| RTF | Regulatory / pharma traditional | Industry-standard format used by SAS pipelines; opens in Word / LibreOffice |
| DOCX | Stakeholder review | Native Word format; supports modern formatting and is easy to comment on |
| HTML | Internal review | Browser-renderable; trivial to share via web; no Word license required |

PNG-only for figures: Word / LibreOffice / browsers can all render PNG, and
at 300 dpi (2400 × 1800 px for the 8 × 6 inch KM plots) the same file
serves both web and print-quality needs.

---

## 5. Package Stack

| Package | Role | Version (at write time) |
|---|---|---|
| `arrow`     | Parquet I/O (ADaM input)        | 23.0.1.2 |
| `dplyr`     | Data manipulation               | 1.2.1    |
| `tidyr`     | Data reshaping                  | 1.3.2    |
| `flextable` | Table rendering (RTF/DOCX/HTML) | 0.9.11   |
| `officer`   | DOCX document assembly          | 0.7.3    |
| `ggplot2`   | Figure rendering                | 4.0.2    |
| `survival`  | Cox PH, KM, log-rank            | 3.8.3    |
| `patchwork` | KM-curve + risk-table composition | 1.3.2 |
| `scales`    | Axis formatting                 | 1.4.0    |

**Pharmaverse `rtables` / `tern` not used.** The flextable + officer + ggplot
stack covers all rendering needs and is already part of the shells doc
pipeline (`sap/shells/render_shells_doc.R`), so the toolchain is consistent
across Phase 4.5 (shells) and Phase 6 (production TFLs).

---

## 6. Validation results

### Phase 6a (efficacy)

| Output | Result |
|---|---|
| T-DM-01 | 32 rows × 3 arm columns; population N=450 ITT recovered |
| T-EFF-01 | HR 0.576 (95% CI 0.458, 0.724), p<0.001, OS TRT 21.4m vs PBO 14.8m. Matches protocol target HR 0.65 (within CI) and median TRT 21.5m. |
| T-EFF-03 | HR 0.504 (95% CI 0.405, 0.628), p<0.001, PFS TRT 13.7m vs PBO 7.1m. PFS_TRT median +3.2m above protocol target — documented in RAW-PROVENANCE §10.5 (interval-censoring drift). |
| F-EFF-01 | KM curve rendered at 300 dpi (2400 × 1800), median + HR + log-rank annotation, number-at-risk table |
| F-EFF-02 | Same structure as F-EFF-01, 24-month x-axis range |

All three Cox HRs are within 95% CIs of protocol-assumed values, confirming
the v0.3 Tier A+B simulation flows through to the analysis layer intact.

### Phase 6b (disposition + exposure)

| Output | Result |
|---|---|
| T-DS-01 | 449 dosed / 449 PP / 89 completed / 361 discontinued (251 PD + 71 AE + 28 Other + 9 WBS + 2 PD) / 312 deaths — totals reconcile with raw simulation |
| T-DS-02 | 1 major deviation (the single randomised-never-dosed placebo subject). Other subcategories (eligibility violations, prohibited conmed, missed assessments) appear as 0 — the synthetic data does not generate explicit SDTM.DS protocol-deviation records, noted in footnote. |
| T-DS-03 | 361 treatment discontinuations, 18 with no post-baseline assessment, 18 deaths before first assessment, 9 withdrawals — subsequent therapy + missed-assessment rows = 0 (synthetic-data limitation noted in footnote). |
| T-EX-01 | Treatment duration medians: TRT 440d vs PBO 314d (+126d). Median cycles: 6 in both arms. Cumulative torivumab dose recovered. |

### Phase 6c (efficacy completion)

| Output | Result |
|---|---|
| T-EFF-02 | 12-month OS landmarks: TRT 70%+ vs PBO 55%; 24-month TRT ~45% vs PBO ~25% |
| T-EFF-04 | 12-month PFS landmarks: TRT ~55% vs PBO ~30% |
| T-EFF-05 | ORR (RE pop): TRT 39.1% vs PBO 15.1%; RD = 24.0 (95% CI 15.9, 32.0); p<0.001 |
| T-EFF-06 | DCR: TRT 82.7% vs PBO 68.4%; RD = 14.3; p<0.001 |
| T-EFF-07 | Median DoR: TRT 17.9m vs PBO 12.8m (descriptive only) |
| T-EFF-08 | OS in PP: HR 0.576 (matches T-EFF-01 to 3 sig figs — PP and ITT identical in this dataset) |
| T-EFF-09 | OS landmark analysis: arm-difference probabilities at 6/12/18/24/30 months, all significant |
| T-EFF-10 | RMST(τ=30m): TRT − PBO = +4.56 months (estimand E1a) |
| T-EFF-11 | PFS-INV HR 0.504 (identical to T-EFF-03 — BICR not simulated in synthetic data, footnote explains) |
| T-EFF-12 | OS-WOT HR 0.485 (95% CI 0.378, 0.624) — stronger than full OS HR 0.576 as expected; estimand E1b |
| T-EFF-13 | ORR ITT-denom: TRT 38.2% vs PBO 14.2%; RD 24.0 (≈identical to T-EFF-05 since only 18 NoPBA subjects across 450) |
| F-EFF-03 | Waterfall — 432 evaluable subjects with best-response data; visible TRT vs PBO separation |
| F-EFF-04 | Spider — 449 subjects, 3,183 SLD records over 24 months |
| F-EFF-05 | Forest — 11 subgroups: Overall, Sex, Age, Histology, Region, ECOG PS, PD-L1 group |
| F-EFF-06 | Swimmer — 118 confirmed responders with treatment / response / PD / death markers |

---

## 7. How to Run

```bash
# From project root:
Rscript programs/tfl/00_run_tfl.R
```

Produces all 11 output files (9 table-format triplets + 2 PNG) in `tfl/`
in ~1.5 seconds.

To add a new output:
1. Create `programs/tfl/<id>.R` that builds a flextable (table) or ggplot (figure)
2. End with `write_table_all_formats(ft, "ID", title, population, notes)` or `write_figure(plot, "ID")`
3. Add the filename to `00_run_tfl.R::tfl_programs`
4. (Optional) Add the output to `99_combine_outputs.R::PILOT_OUTPUTS` for the combined views

---

## 8. Open items / Phase 6c-d roadmap

Phase 6b items (T-DS-01/02/03, T-EX-01) all delivered 2026-05-16. Remaining:

- T-EFF-02 / T-EFF-04 — Landmark survival probabilities for OS / PFS
- T-EFF-05 / T-EFF-06 — ORR / DCR (need ADRS responder flags)
- T-EFF-07 — DoR among responders
- T-EFF-08 — OS in PP population (sensitivity)
- T-EFF-09 — OS landmark sensitivity
- T-EFF-10 — OS RMST (estimand E1a) — requires `survRM2` package
- T-EFF-11 — PFS by Investigator (estimand E2a)
- T-EFF-12 — OS WOT (estimand E1b) — ADTTE PARAMCD='OSWOT' is in place
- T-EFF-13 — ORR ITT denominator (estimand E3a)
- T-AE-01..07 — Safety tables (require ADAE)
- T-LB-01 / T-LB-02 — Lab abnormalities (require ADLB shift logic)
- F-EFF-03 — Waterfall plot (best % change in SLD)
- F-EFF-04 — Spider plot (SLD over time)
- F-EFF-05 — Forest plot (subgroup OS HRs)
- F-EFF-06 — Swimmer plot (responder duration)
- L-AE-01 / L-AE-02 / L-AE-03 — AE listings
- L-LB-01 — Grade ≥3 lab abnormalities listing
- L-DS-01 — Major protocol deviations listing

Estimated effort to add the remaining 33: ~6–8 hours total at the current
pace (~10–15 min per straightforward table, ~30 min per figure).

---

## 9. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `sap/SAP.md` (v0.2) | **Parent.** Defines analyses, populations, methods, estimands. |
| `sap/shells/shells.yaml` (v0.3) | **Sibling.** Pre-locked shell catalogue. Each TFL output traces back to a shell. |
| `programming-specs/AD*-spec.md` | **Upstream.** ADaM variable definitions consumed by the TFL scripts. |
| `datasets/adam/*.parquet` | **Input.** Phase 5 ADaM datasets. |
| `tfl/` | **Output.** Production TFL deliverables. |
| `csr/` | **Downstream (Phase 7).** CSR §11 (Results) will reference these tables and figures. |

---

## 10. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Initial Phase 6a pilot: scaffolded `programs/tfl/`, built shared helpers + KM-curve helper, produced 5 outputs in RTF + DOCX + HTML (tables) and PNG (figures). Two combined deliverables: `tfl/TFL-OUTPUTS.html` and `tfl/TFL-OUTPUTS.docx`. Full pipeline runs in 1.3 seconds. All three Cox HRs within 95% CIs of protocol-assumed values. |
| 0.2 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Phase 6b: added 4 disposition+exposure tables (T-DS-01, T-DS-02, T-DS-03, T-EX-01). Now 9 of 38 outputs delivered. Two synthetic-data limitations noted as footnotes: (a) no explicit SDTM.DS protocol-deviation records, so T-DS-02 subcategories beyond "randomised but never dosed" appear as 0; (b) no subsequent anti-cancer therapy in CM, so T-DS-03 rows for subsequent therapy and missed-assessment IEs appear as 0. |
| 0.3 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Phase 6c: added all 15 remaining efficacy outputs — 11 tables (T-EFF-02/04/05/06/07/08/09/10/11/12/13) + 4 figures (F-EFF-03/04/05/06). Now 24 of 38 outputs delivered. Added shared helpers in `_helpers.R`: `km_landmark_probs`, `stratified_cox`, `stratified_logrank`, `add_region`. Installed `survRM2` for T-EFF-10 RMST. Synthetic-data limitations noted in footnotes: T-EFF-11 PFSINV ≡ PFS (no separate BICR simulated); T-EFF-10 τ=30m instead of SAP-proposed 36m (bounded by max follow-up). Phase 6d (safety + listings) remaining: 14 outputs. |

---

*Last updated: 2026-05-16*
