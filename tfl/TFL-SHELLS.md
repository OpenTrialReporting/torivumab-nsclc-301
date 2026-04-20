# TFL Shells — SIMULATED-TORIVUMAB-2026

> ⚠️ **GENERATED FILE — DO NOT EDIT DIRECTLY.**
> Source of truth: [`tfl/shells.yaml`](shells.yaml).
> Regenerate with: `Rscript tfl/render_shells.R`
> Validate with: `Rscript tfl/validate_shells.R`

> ⚠️ **FICTIONAL EDUCATIONAL DOCUMENT — NOT FOR REGULATORY USE.**

---

## Administrative

| Field | Value |
|---|---|
| **Study** | SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301) |
| **SAP version** | v0.1 |
| **Protocol version** | v1.1 |
| **Shells version** | v0.1 |
| **Date** | 2026-04-20 |
| **Author** | Lovemore Gakava |
| **Gate** | 3.5 — blocks Phase 5 ADaM |
| **ARS alignment** | CDISC ARS v1.0 concepts (not yet serialised to ARS JSON) |
| **Format rationale** | [`SHELLS-FORMAT-RATIONALE.md`](SHELLS-FORMAT-RATIONALE.md) |

## Purpose

Authoritative catalogue of every Table, Figure, and Listing planned for the CSR.
Each output specifies the analysis set, source ADaM datasets, key variables, statistical methods, and a reference back to the SAP section that governs it.
Shells in this file drive the downstream `programming-specs/AD*-spec.md` coverage check and (eventually) the `tern`/`rtables` output code.

Schema aligns with CDISC ARS v1.0 concepts (analysis_sets / data_subsets / methods / reference_documents / outputs). This is not yet a full ARS JSON serialisation — the intent is that a future `render_ars.R` can emit ARS JSON directly from this same YAML.

## 1. Analysis Sets

| ID | Label | Definition | Filter | Treatment var | Expected N |
|---|---|---|---|---|---|
| ITT | Intent-to-Treat | All randomised patients, analysed as randomised | ADSL: `ITTFL == 'Y'` | `TRT01P` | 450 |
| SAFETY | Safety | All patients who received ≥1 dose, analysed as treated | ADSL: `SAFFL == 'Y'` | `TRT01A` | 450 |
| PP | Per-Protocol | ITT ∩ SAFFL ∩ no major protocol deviations | ADSL: `PPROTFL == 'Y'` | `TRT01P` | 405 |
| RESPEVAL | Response Evaluable | ITT with ≥1 post-baseline tumour assessment OR clinical progression before first assessment | ADSL: `ITTFL == 'Y'`<br>ADRS: `EFFFL == 'Y'` | `TRT01P` | 440 |
| RESPONDERS | Confirmed Responders | Subset of Response Evaluable with confirmed BOR ∈ {CR, PR} | ADSL: `ITTFL == 'Y'`<br>ADRS: `EFFFL == 'Y' & AVALC %in% c('CR','PR') & ANL01FL == 'Y'` | `TRT01P` | — |

## 2. Statistical Methods

| ID | Name | Description | R package · function |
|---|---|---|---|
| M-STRAT-LOGRANK | Stratified Log-Rank Test | Two-sided stratified log-rank test of treatment equality in time-to-event. | survival · `survdiff(..., rho = 0)` |
| M-COX-STRAT | Stratified Cox Proportional Hazards | Stratified Cox PH model to estimate HR and 95% CI. | survival · `coxph(Surv(AVAL,1-CNSR) ~ TRT01P + strata(STRAT2,STRAT3))` |
| M-KM-MEDIAN | Kaplan-Meier Median | Median survival with 95% CI using Brookmeyer-Crowley (log-log). | survival · `survfit(..., conf.type = 'log-log')` |
| M-KM-PROB | Kaplan-Meier Survival Probability | Survival probability at specified timepoints with Greenwood 95% CI. | survival · `summary(survfit(...), times = t)` |
| M-CMH-STRAT | Stratified Cochran-Mantel-Haenszel | Stratified MH test of proportion equality; MH risk difference + 95% CI. | stats · `mantelhaen.test(...)` |
| M-CLOPPER | Clopper-Pearson Exact 95% CI | Exact binomial confidence interval for proportions. | stats · `binom.test(...)` |
| M-WILSON | Wilson Score 95% CI | Wilson score interval for proportions — sensitivity for Clopper-Pearson. | DescTools · `BinomCI(..., method='wilson')` |
| M-RMST | Restricted Mean Survival Time | RMST at τ = 36 months; RMST difference with 95% CI. | survRM2 · `rmst2(..., tau = 36)` |
| M-LANDMARK | Landmark Survival Comparison | Difference in KM survival probability at landmark timepoints with 95% CI (log-log). | survival · `summary(survfit(...), times = c(12, 24))` |
| M-DESCR-CAT | Descriptive — Categorical | n (%) of subjects per level. | rtables |
| M-DESCR-CONT | Descriptive — Continuous | n, mean (SD), median, min, max per group. | rtables |
| M-EAIR | Exposure-Adjusted Incidence Rate | Events per 100 patient-years (person-time = TRTDURD summed). | tern |
| M-KM-TTE-ONSET | Time-to-Onset / Resolution (KM) | Kaplan-Meier for time to irAE onset or resolution. | survival |
| M-FOREST-SUBGROUP | Subgroup Forest (Unstratified Cox) | Per-subgroup unstratified Cox HR + 95% CI; overall stratified HR. | survival · `coxph per subgroup level` |
| M-SHIFT | Shift Table (Baseline → Worst Post-Baseline) | Cross-tabulation of BNRIND × worst ANRIND. | rtables |
| M-WATERFALL | Waterfall (Best % Change) | Per-subject bar of best % change from baseline SLD, sorted descending. | ggplot2 |
| M-SPIDER | Spider (Longitudinal % Change) | Per-subject line of % change from baseline SLD over time. | ggplot2 |
| M-SWIMMER | Swimmer Lane (Responders) | Per-responder horizontal lane with response episodes, PD, death markers. | ggplot2 |

## 3. Reference Documents

| ID | Title | Path |
|---|---|---|
| PROTO-1.1 | Protocol v1.1 | [`protocol/synopsis.md`](../protocol/synopsis.md) |
| SAP-0.1 | Statistical Analysis Plan v0.1 | [`sap/SAP.md`](../sap/SAP.md) |
| CRF-2.0 | CRF Strategy v2.0 | [`crf/CRF-STRATEGY.md`](../crf/CRF-STRATEGY.md) |

## 4. Outputs

Total: 35 outputs (24 tables, 6 figures, 5 listings).

### 4.1 Tables

#### T-DM-01 — Demographic and Baseline Characteristics

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADSL` |
| **Key variables** | `TRT01P`, `AGE`, `AGEGR1`, `SEX`, `RACE`, `ETHNIC`, `REGION1`, `HISTSCAT`, `BECOG`, `PDL1GR`, `STRAT1`, `STRAT2`, `STRAT3` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT]; Descriptive — Continuous [M-DESCR-CONT] |
| **SAP reference** | §3.1 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md), [Protocol v1.1](../protocol/synopsis.md) |
| **Layout — rows** | One row per baseline characteristic |
| **Layout — columns** | TRT01P arms + Total (three columns) |

**Notes:** Descriptive: n (%) for categorical; n, mean (SD), median, min, max for continuous.

#### T-DS-01 — Subject Disposition

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADSL` |
| **Key variables** | `ITTFL`, `SAFFL`, `PPROTFL`, `EFFFL`, `EOSSTT`, `DCSREAS`, `DTHFL`, `RFICDT`, `RANDDT`, `TRTSDT`, `TRTEDT`, `EOSDT` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §3 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Screened / Randomised / ITT / Safety / PP / Response Evaluable / Discontinued (by reason) / Completed / Ongoing / Died |
| **Layout — columns** | TRT01P |

**Notes:** Counts and percentages for each category.

#### T-DS-02 — Major Protocol Deviations

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADSL`, `SDTM.DS` |
| **Key variables** | `TRT01P`, `USUBJID` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §3.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Deviation category |
| **Layout — columns** | TRT01P + Total |

**Notes:** n (%) subjects with ≥1 major deviation by category. Source: SDTM.DS where DSDECOD='PROTOCOL DEVIATION' AND DSSCAT='MAJOR'.

#### T-EX-01 — Study Drug Exposure

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADSL` |
| **Key variables** | `TRT01A`, `TRTSDT`, `TRTEDT`, `TRTDURD`, `N_CYCLES`, `CUMDOSE` |
| **Methods** | Descriptive — Continuous [M-DESCR-CONT]; Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Median (min–max) treatment duration; mean (SD) cycles received; n (%) with ≥6/≥12/≥24 cycles; relative dose intensity |
| **Layout — columns** | TRT01A |

**Notes:** Exposure summaries computed from ADSL (TRTDURD, N_CYCLES, CUMDOSE) — no separate ADEX dataset in scope.

#### T-EFF-01 — Overall Survival Analysis (Primary)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Log-Rank Test [M-STRAT-LOGRANK]; Stratified Cox Proportional Hazards [M-COX-STRAT]; Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §5.1 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md), [Protocol v1.1](../protocol/synopsis.md) |
| **Layout — rows** | n, events, censored, median OS (95% CI), HR (95% CI), stratified log-rank p |
| **Layout — columns** | TRT01P |

**Notes:** Primary analysis. Triggered at ~320 OS events (event-driven, Protocol §8.1). Strata: histology (STRAT2), region (STRAT3).

#### T-EFF-02 — Kaplan-Meier Survival Probabilities — OS

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Kaplan-Meier Survival Probability [M-KM-PROB] |
| **SAP reference** | §5.1 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Timepoints 6, 12, 18, 24 months |
| **Layout — columns** | TRT01P — probability, 95% CI |

**Notes:** Greenwood 95% CI.

#### T-EFF-03 — Progression-Free Survival Analysis (BICR)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `PFS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Log-Rank Test [M-STRAT-LOGRANK]; Stratified Cox Proportional Hazards [M-COX-STRAT]; Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §5.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | n, events, censored, median PFS (95% CI), HR (95% CI), stratified log-rank p |
| **Layout — columns** | TRT01P |

**Notes:** Same structure as T-EFF-01 for PFS.

#### T-EFF-04 — Kaplan-Meier Probabilities — PFS

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `PFS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Kaplan-Meier Survival Probability [M-KM-PROB] |
| **SAP reference** | §5.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Timepoints 6, 12, 18, 24 months |
| **Layout — columns** | TRT01P — probability, 95% CI |

**Notes:** Greenwood 95% CI.

#### T-EFF-05 — Objective Response Rate (BICR)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Response Evaluable (RESPEVAL) |
| **Source datasets** | `ADRS`, `ADSL` |
| **Parameter codes** | `CBOR` |
| **Key variables** | `TRT01P`, `AVALC`, `ORRFL`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Cochran-Mantel-Haenszel [M-CMH-STRAT]; Clopper-Pearson Exact 95% CI [M-CLOPPER]; Wilson Score 95% CI [M-WILSON] |
| **SAP reference** | §5.3 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | N, n responders, ORR % (95% CI), risk difference (95% CI), CMH p; best response breakdown (CR/PR/SD/PD/NE) |
| **Layout — columns** | TRT01P |

**Notes:** Clopper-Pearson 95% CI primary; Wilson as sensitivity row. Subjects with no post-baseline assessment counted as non-responders (§4.3).

#### T-EFF-06 — Disease Control Rate

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Response Evaluable (RESPEVAL) |
| **Source datasets** | `ADRS`, `ADSL` |
| **Parameter codes** | `CBDCR` |
| **Key variables** | `TRT01P`, `AVALC`, `DCRFL`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Cochran-Mantel-Haenszel [M-CMH-STRAT]; Clopper-Pearson Exact 95% CI [M-CLOPPER] |
| **SAP reference** | §5.3 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Same as T-EFF-05 |
| **Layout — columns** | TRT01P |

**Notes:** Uses DCRFL. SD requires duration ≥8 weeks from randomisation.

#### T-EFF-07 — Duration of Response

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Confirmed Responders (RESPONDERS) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `DOR` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Kaplan-Meier Median [M-KM-MEDIAN]; Kaplan-Meier Survival Probability [M-KM-PROB] |
| **SAP reference** | §5.4 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Median DoR (95% CI); proportion with DoR ≥6 mo, ≥12 mo |
| **Layout — columns** | TRT01P |

**Notes:** No formal between-arm test (hypothesis-generating).

#### T-EFF-08 — OS in Per-Protocol Population (Sensitivity)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Per-Protocol (PP) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Log-Rank Test [M-STRAT-LOGRANK]; Stratified Cox Proportional Hazards [M-COX-STRAT]; Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §11 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Same as T-EFF-01 |
| **Layout — columns** | TRT01P |

**Notes:** Sensitivity — primary OS re-run on PP population.

#### T-EFF-09 — OS Landmark Analysis

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Landmark Survival Comparison [M-LANDMARK] |
| **SAP reference** | §11 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | 12 months, 24 months |
| **Layout — columns** | TRT01P probability, difference (95% CI) |

**Notes:** Difference in survival probability with 95% CI (log-log).

#### T-EFF-10 — Restricted Mean Survival Time (OS)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Restricted Mean Survival Time [M-RMST] |
| **SAP reference** | §11 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | RMST per arm; RMST difference (95% CI) |
| **Layout — columns** | TRT01P |

**Notes:** τ = 36 months.

#### T-EFF-11 — PFS by Investigator (Sensitivity)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `PFSINV` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR`, `STRAT2`, `STRAT3` |
| **Methods** | Stratified Log-Rank Test [M-STRAT-LOGRANK]; Stratified Cox Proportional Hazards [M-COX-STRAT]; Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §4.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Same as T-EFF-03 |
| **Layout — columns** | TRT01P |

**Notes:** Requires PARAMCD='PFSINV' in ADTTE.

#### T-AE-01 — Overall Summary of AEs

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADSL`, `ADAE` |
| **Key variables** | `TRT01A`, `TRTEMFL`, `AESER`, `AESDTH`, `AETOXGR`, `IRAEFL`, `AESI` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Any AE, any TEAE, any Grade ≥3 TEAE, any SAE, any irAE, any AE → discontinuation, any AE → death |
| **Layout — columns** | TRT01A + Total |

**Notes:** n (%) of subjects.

#### T-AE-02 — TEAEs by SOC and PT (≥5% any arm)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `TRT01A`, `AEBODSYS`, `AEDECOD`, `TRTEMFL` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | SOC (bold) → PT |
| **Layout — columns** | TRT01A |

**Notes:** Filtered to TRTEMFL='Y'. Include PTs where incidence ≥5% in either arm. Sorted by decreasing Torivumab-arm incidence.

#### T-AE-03 — Grade ≥3 TEAEs by SOC and PT

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `TRT01A`, `AEBODSYS`, `AEDECOD`, `TRTEMFL`, `AETOXGR` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | SOC → PT |
| **Layout — columns** | TRT01A |

**Notes:** Filtered to TRTEMFL='Y' AND AETOXGR ∈ {3,4,5}.

#### T-AE-04 — Serious Adverse Events by SOC and PT

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `TRT01A`, `AEBODSYS`, `AEDECOD`, `AESER` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | SOC → PT |
| **Layout — columns** | TRT01A |

**Notes:** Filtered to AESER='Y'.

#### T-AE-05 — Immune-Related AEs by Category

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `TRT01A`, `IRAEFL`, `IRAECAT`, `AETOXGR` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT]; Time-to-Onset / Resolution (KM) [M-KM-TTE-ONSET] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md), [Protocol v1.1](../protocol/synopsis.md) |
| **Layout — rows** | irAE category (pneumonitis/colitis/hepatitis/endocrinopathies/IRR) × grade |
| **Layout — columns** | TRT01A |

**Notes:** n (%) by category × grade; median time to onset and resolution (KM). Filtered to IRAEFL='Y'.

#### T-AE-06 — AESIs by Category

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `TRT01A`, `AESI`, `AETOXGR` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md), [Protocol v1.1](../protocol/synopsis.md) |
| **Layout — rows** | AESI category × grade |
| **Layout — columns** | TRT01A |

**Notes:** Category flag from MedDRA PT list in Protocol §7.4.

#### T-AE-07 — Deaths

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADSL`, `ADAE` |
| **Key variables** | `TRT01A`, `DTHFL`, `DTHDT`, `DTHCAUS`, `TRTEDT` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | All deaths; within 30 days of last dose; due to AE; due to disease progression; other |
| **Layout — columns** | TRT01A |

**Notes:** Mixed population: on-treatment denominator = Safety; all deaths denominator = ITT (noted per row).

#### T-LB-01 — Laboratory Abnormalities (Shift Table)

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADLB` |
| **Key variables** | `TRT01A`, `PARAMCD`, `BASE`, `AVAL`, `BNRIND`, `ANRIND` |
| **Methods** | Shift Table (Baseline → Worst Post-Baseline) [M-SHIFT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Baseline status (Normal/Low/High) |
| **Layout — columns** | Worst post-baseline status (Normal/Low/High) |

**Notes:** One panel per PARAMCD.

#### T-LB-02 — Laboratory CTCAE Grade ≥3

| Field | Value |
|---|---|
| **Kind** | table |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADLB` |
| **Key variables** | `TRT01A`, `PARAMCD`, `ATOXGR` |
| **Methods** | Descriptive — Categorical [M-DESCR-CAT] |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | PARAMCD |
| **Layout — columns** | TRT01A |

**Notes:** n (%) with ≥1 post-baseline ATOXGR ≥ 3 per PARAMCD.

### 4.2 Figures

#### F-EFF-01 — Kaplan-Meier Curve — OS

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §5.1 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — axes** | x = time (months), y = survival probability (0–1) |
| **Layout — features** | 95% CI bands (log-log); number-at-risk table at 0, 6, 12, 18, 24, 30, 36 months |
| **Layout — annotations** | stratified log-rank p, HR (95% CI) |

**Notes:** One curve per TRT01P.

#### F-EFF-02 — Kaplan-Meier Curve — PFS

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADTTE` |
| **Parameter codes** | `PFS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR` |
| **Methods** | Kaplan-Meier Median [M-KM-MEDIAN] |
| **SAP reference** | §5.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — axes** | x = time (months), y = progression-free probability |
| **Layout — features** | Same layout as F-EFF-01 |

**Notes:** Same structure as F-EFF-01 for PFS.

#### F-EFF-03 — Waterfall — Best Percent Change in SLD

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Response Evaluable (RESPEVAL) |
| **Source datasets** | `ADTR` |
| **Parameter codes** | `PCHG` |
| **Key variables** | `TRT01P`, `USUBJID`, `AVAL`, `PCHG` |
| **Methods** | Waterfall (Best % Change) [M-WATERFALL] |
| **SAP reference** | §5.3 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — axes** | x = subject (sorted), y = best % change from baseline |
| **Layout — features** | Reference lines at −30% (PR) and +20% (PD); coloured by TRT01P |

**Notes:** Restricted to subjects with measurable disease at baseline.

#### F-EFF-04 — Spider — SLD Change Over Time

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Response Evaluable (RESPEVAL) |
| **Source datasets** | `ADTR` |
| **Parameter codes** | `PCHG` |
| **Key variables** | `TRT01P`, `USUBJID`, `ADY`, `PCHG` |
| **Methods** | Spider (Longitudinal % Change) [M-SPIDER] |
| **SAP reference** | §5.3 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — axes** | x = weeks from baseline, y = % change from baseline SLD |
| **Layout — features** | One line per subject; coloured by TRT01P; optional faceting by arm |

#### F-EFF-05 — Forest — OS HR by Subgroup

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `ADSL`, `ADTTE` |
| **Parameter codes** | `OS` |
| **Key variables** | `TRT01P`, `AVAL`, `CNSR`, `HISTSCAT`, `REGION1`, `SEX`, `AGEGR1`, `BECOG`, `PDL1GR` |
| **Methods** | Subgroup Forest (Unstratified Cox) [M-FOREST-SUBGROUP] |
| **SAP reference** | §10 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | Subgroup levels |
| **Layout — columns** | n, events, HR (95% CI), forest plot |

**Notes:** Per-subgroup unstratified Cox HR; overall stratified HR at top. Square size ∝ subgroup n.

#### F-EFF-06 — Swimmer — Responders

| Field | Value |
|---|---|
| **Kind** | figure |
| **Analysis set** | Confirmed Responders (RESPONDERS) |
| **Source datasets** | `ADSL`, `ADRS`, `ADTTE` |
| **Parameter codes** | `CBOR`, `DOR` |
| **Key variables** | `TRT01P`, `USUBJID`, `AVISITN`, `AVALC`, `ADT` |
| **Methods** | Swimmer Lane (Responders) [M-SWIMMER] |
| **SAP reference** | §5.4 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — axes** | x = weeks from randomisation; one lane per responder |
| **Layout — features** | Response episodes; markers for PD, death, ongoing |

**Notes:** Confirmed responders only.

### 4.3 Listings

#### L-AE-01 — Serious Adverse Events

| Field | Value |
|---|---|
| **Kind** | listing |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `USUBJID`, `TRT01A`, `AEBODSYS`, `AEDECOD`, `ASTDT`, `AENDT`, `AETOXGR`, `AESER`, `AEACN`, `AEREL`, `AEOUT` |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | One row per SAE record |
| **Layout — sort** | USUBJID, ASTDT |

**Notes:** Filtered to AESER='Y'.

#### L-AE-02 — Deaths

| Field | Value |
|---|---|
| **Kind** | listing |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADSL` |
| **Key variables** | `USUBJID`, `TRT01A`, `DTHDT`, `DTHCAUS`, `TRTEDT`, `RANDDT`, `EOSSTT` |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | One row per subject with DTHFL='Y' |

**Notes:** Computed columns: days from last dose to death; days from randomisation to death.

#### L-AE-03 — AEs Leading to Discontinuation

| Field | Value |
|---|---|
| **Kind** | listing |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADAE` |
| **Key variables** | `USUBJID`, `TRT01A`, `AEDECOD`, `ASTDT`, `AETOXGR`, `AEREL`, `TRTEDT` |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | One row per AE |

**Notes:** Filtered to AEACN='DRUG WITHDRAWN'.

#### L-LB-01 — Grade ≥3 Laboratory Abnormalities

| Field | Value |
|---|---|
| **Kind** | listing |
| **Analysis set** | Safety (SAFETY) |
| **Source datasets** | `ADLB` |
| **Key variables** | `USUBJID`, `TRT01A`, `PARAMCD`, `AVISIT`, `ADT`, `AVAL`, `ANRLO`, `ANRHI`, `ATOXGR` |
| **SAP reference** | §5.5 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | One row per lab result |

**Notes:** Filtered to ATOXGR ≥ 3.

#### L-DS-01 — Major Protocol Deviations

| Field | Value |
|---|---|
| **Kind** | listing |
| **Analysis set** | Intent-to-Treat (ITT) |
| **Source datasets** | `SDTM.DS` |
| **Key variables** | `USUBJID`, `TRT01P`, `DSSTDTC` |
| **SAP reference** | §3.2 |
| **Reference documents** | [Statistical Analysis Plan v0.1](../sap/SAP.md) |
| **Layout — rows** | One row per deviation |

**Notes:** Filtered to DSDECOD='PROTOCOL DEVIATION' AND DSSCAT='MAJOR'. Shows deviation category and description.

## 5. ADaM Coverage Summary

Every variable in `programming-specs/AD*-spec.md` should be cited by ≥1 shell's `key_variables`. `validate_shells.R` enforces this — see its report output.

Distinct variables cited across all shells: **64**.

<details><summary>Full variable list</summary>

`ADT`, `ADY`, `AEACN`, `AEBODSYS`, `AEDECOD`, `AENDT`, `AEOUT`, `AEREL`, `AESDTH`, `AESER`, `AESI`, `AETOXGR`, `AGE`, `AGEGR1`, `ANRHI`, `ANRIND`, `ANRLO`, `ASTDT`, `ATOXGR`, `AVAL`, `AVALC`, `AVISIT`, `AVISITN`, `BASE`, `BECOG`, `BNRIND`, `CNSR`, `CUMDOSE`, `DCRFL`, `DCSREAS`, `DSSTDTC`, `DTHCAUS`, `DTHDT`, `DTHFL`, `EFFFL`, `EOSDT`, `EOSSTT`, `ETHNIC`, `HISTSCAT`, `IRAECAT`, `IRAEFL`, `ITTFL`, `N_CYCLES`, `ORRFL`, `PARAMCD`, `PCHG`, `PDL1GR`, `PPROTFL`, `RACE`, `RANDDT`, `REGION1`, `RFICDT`, `SAFFL`, `SEX`, `STRAT1`, `STRAT2`, `STRAT3`, `TRT01A`, `TRT01P`, `TRTDURD`, `TRTEDT`, `TRTEMFL`, `TRTSDT`, `USUBJID`

</details>

## 6. SAP → Output Crosswalk

| SAP § | Outputs |
|---|---|
| §10 | F-EFF-05 |
| §11 | T-EFF-08, T-EFF-09, T-EFF-10 |
| §3 | T-DS-01 |
| §3.1 | T-DM-01 |
| §3.2 | T-DS-02, L-DS-01 |
| §4.2 | T-EFF-11 |
| §5.1 | T-EFF-01, T-EFF-02, F-EFF-01 |
| §5.2 | T-EFF-03, T-EFF-04, F-EFF-02 |
| §5.3 | T-EFF-05, T-EFF-06, F-EFF-03, F-EFF-04 |
| §5.4 | T-EFF-07, F-EFF-06 |
| §5.5 | T-EX-01, T-AE-01, T-AE-02, T-AE-03, T-AE-04, T-AE-05, T-AE-06, T-AE-07, T-LB-01, T-LB-02, L-AE-01, L-AE-02, L-AE-03, L-LB-01 |

## 7. Change Log

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-04-20 | Regenerated from `tfl/shells.yaml` |

