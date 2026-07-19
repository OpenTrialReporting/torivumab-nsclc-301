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

Total delivered to end of 6c: **24 / 43 outputs**. (Phase 6d adds 14, Phase 6e adds 1.)

### 6d (2026-05-16) — 14 outputs, safety + listings

| ID | Kind | Title | Source |
|---|---|---|---|
| T-AE-01 | Table | Overall Summary of AEs | ADAE + ADSL |
| T-AE-02 | Table | TEAEs by SOC and PT (≥5% any arm) | ADAE TRTEMFL=Y |
| T-AE-03 | Table | Grade ≥3 TEAEs by SOC and PT | ADAE TRTEMFL=Y AND AETOXGRN≥3 |
| T-AE-04 | Table | Serious AEs by SOC and PT | ADAE TRTEMFL=Y AND AESER=Y |
| T-AE-05 | Table | Immune-Related AEs | ADAE IRAEFL=Y |
| T-AE-06 | Table | Adverse Events of Special Interest (AESI) | ADAE INNER JOIN `raw/codelists/aesi_meddra_pts.csv` (56 PTs / 12 categories; per-PT grade rule) |
| T-AE-07 | Table | Deaths (overall + cause) | ADSL DTHFL=Y + SDTM.DD |
| T-LB-01 | Table | Lab abnormalities shift (baseline → worst) | ADLB NRIND |
| T-LB-02 | Table | Lab CTCAE Grade ≥3 worst post-baseline | ADLB ATOXGRN |
| L-AE-01 | Listing | Serious Adverse Events | ADAE AESER=Y |
| L-AE-02 | Listing | Deaths | ADSL DTHFL=Y + SDTM.DD |
| L-AE-03 | Listing | AEs Leading to Discontinuation | ADAE AEACN ~ "WITHDRAWN" |
| L-LB-01 | Listing | Grade ≥3 Lab Abnormalities | ADLB ATOXGRN ≥ 3 |
| L-DS-01 | Listing | Major Protocol Deviations | ADSL PPROTFL=N |

### 6e (2026-05-17) — 1 output added, protocol deviations table

| ID | Kind | Title | SAP / Estimand |
|---|---|---|---|
| T-DV-01 | Table | Protocol Deviations by Category (sponsor-classified) | §3.2 (descriptive) — reads SDTM.DV |

**Phase 6 COMPLETE. All 43 of 43 outputs delivered (32 tables + 6 figures + 5 listings).**

Added infrastructure for Phase 6d:
- `build_ae_soc_pt_ft()` shared helper in `_helpers.R` — used by T-AE-02/03/04/05/06 (same SOC×PT structure, different filter)
- `write_listing_all_formats()` shared helper — DOCX in landscape orientation, smaller font (8pt), RTF + HTML siblings The pilot architecture is designed so adding a
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
| T-DS-02 | Real protocol-deviation counts now flow from SDTM.DV (added 2026-05-17): subcategories populated from sponsor-classified deviations. Closes AL-09. |
| T-DS-03 | IE1–IE3 all non-zero following ADCM.SUBSQTFL addition (subsequent anti-cancer therapy ~133 subjects). IE4 (≥2 consecutive missed tumour assessments) row remains 0 — accepted as AL-12 (no gap-detection logic in synthetic data). Closes AL-10. |
| T-EX-01 | Treatment duration medians: TRT 440d vs PBO 314d (+126d). Median cycles: 6 in both arms. Cumulative torivumab dose recovered. |

### Phase 6c (efficacy completion)

| Output | Result |
|---|---|
| T-EFF-02 | 12-month OS landmarks: TRT 70%+ vs PBO 55%; 24-month TRT ~45% vs PBO ~25% |
| T-EFF-04 | 12-month PFS landmarks: TRT ~55% vs PBO ~30% |
| T-EFF-05 | ORR (RE pop): TRT 39.1% vs PBO 15.1%; RD = 24.0 (95% CI 15.9, 32.0); p<0.001 |
| T-EFF-06 | DCR: TRT 82.7% vs PBO 68.4%; RD = 14.3; p<0.001 |
| T-EFF-07 | Median DoR: TRT 17.9m vs PBO 12.8m (descriptive only) |
| T-EFF-08 | OS in PP: HR 0.545 (95% CI 0.430, 0.690) — PP now distinct from ITT after real PPROTFL derivation (412/450 Y; 2026-05-17). Closes AL-02. |
| T-EFF-09 | OS landmark analysis: arm-difference probabilities at 6/12/18/24/30 months, all significant |
| T-EFF-10 | RMST(τ=30m): TRT − PBO = +4.56 months (estimand E1a) |
| T-EFF-11 | PFS-INV HR 0.522 (95% CI 0.420, 0.649); median TRT 13.67m vs PBO 7.06m. Reads PARAMCD='PFSINV' (Investigator) — distinct from T-EFF-03 PFS (BICR HR 0.568, median 10.94 / 5.55m) following BICR/Investigator separation in raw simulator (2026-05-17). Closes AL-04/AL-07. |
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

Produces all 43 outputs (32 tables × 3 formats + 6 figures + 5 listings × 3 formats) in `tfl/`
in ~5–8 seconds.

To add a new output:
1. Create `programs/tfl/<id>.R` that builds a flextable (table) or ggplot (figure)
2. End with `write_table_all_formats(ft, "ID", title, population, notes)` or `write_figure(plot, "ID")`
3. Add the filename to `00_run_tfl.R::tfl_programs`
4. (Optional) Add the output to `99_combine_outputs.R::PILOT_OUTPUTS` for the combined views

---

## 8. Open items

All 43 production outputs delivered. Two structural accepted limitations remain:

- **AL-06** (T-EFF-10): τ = 30 months (not SAP-proposed 36) bounded by max follow-up.
- **AL-12** (T-DS-03 IE4): ≥2 consecutive missed tumour assessments row shows 0 — no gap-detection logic in synthetic ADRS.

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
| 0.4 | 2026-05-16 | LG (w/ Claude Opus 4.7) | **Phase 6d complete — all 38 of 38 outputs delivered.** Added 9 safety tables (T-AE-01..07, T-LB-01/02) + 5 listings (L-AE-01/02/03, L-LB-01, L-DS-01). Two new shared helpers: `build_ae_soc_pt_ft()` (reused by T-AE-02/03/04/05/06) and `write_listing_all_formats()` (landscape DOCX + 8pt font for wide listings). Combined HTML/DOCX rendering extended for the new `kind == "listing"` output type. AESI categorisation uses an MedDRA-PT regex stand-in pending the SAP §4.6 deferred AESI list; documented in T-AE-06 footnote. |
| 0.5 | 2026-05-17 | LG (w/ Claude Opus 4.7) | **Phase 6e + AL closures — 43 of 43 outputs.** Added T-DV-01 (Protocol Deviations by Category) sourced from new SDTM.DV. **T-AE-06 (AESI)** rewritten to consume sponsor codelist `raw/codelists/aesi_meddra_pts.csv` (56 PTs / 12 categories with per-PT grade rule any/G2+/G3+) — closes AL-08. **T-EFF-08 (OS-PP)** now meaningful (HR 0.545) after real PPROTFL derivation — closes AL-02. **T-EFF-11 (PFSINV)** now reads PARAMCD='PFSINV' (Investigator) distinct from T-EFF-03 (BICR) — closes AL-04/AL-07. **T-DS-02** and **T-DS-03 IE1–IE3** now non-zero after SDTM.DV + ADCM.SUBSQTFL — closes AL-09/AL-10. Net effect: 7 AL closures (AL-02/03/04/07/08/09/10); AL-12 added for T-DS-03 IE4. |
| 0.6 | 2026-07-19 | LG (w/ Claude Opus 4.8 1M) | **Cascade repairs + realism from the SDTM/ADaM changes; all 43 outputs regenerated.** After the SDTM remediation dropped non-standard variables: `t_ae_07_deaths` / `l_ae_02_deaths` now read the cause of death from `DDORRES` (was `DDTERM`); `t_dv_01_deviations` breaks down by `DVDECOD` (was the dropped `DVSCAT`). For analysis-visit windowing (SAP §12.2), `t_vs_01_summary` filters `ANL01FL="Y"` so records windowed into a visit (incl. unscheduled rechecks) are not double-counted. The CTCAE haemoglobin grading fix removed 3,356 spurious Grade-4 HGB records, shrinking **L-LB-01 from 3,644 → 443 rows** and cutting full-suite runtime from ~15 min to ~1.4 min. |

---

*Last updated: 2026-07-19*
