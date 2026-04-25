# Statistical Analysis Plan (SAP) — SIMULATED-TORIVUMAB-2026

> ⚠️ **FICTIONAL EDUCATIONAL DOCUMENT — NOT FOR REGULATORY USE.**
> This SAP supports a fully synthetic Phase 3 NSCLC dataset developed for the `clinTrialData` R package.
> Celindra Therapeutics, torivumab, and all results are fictional.

---

## Administrative

| Field | Value |
|---|---|
| **Document** | `sap/SAP.md` |
| **Study** | SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301) — TORIVA-LUNG 301 |
| **Protocol reference** | Protocol v1.1 (2026-03-30), `protocol/synopsis.md` |
| **Sponsor** | Celindra Therapeutics *(fictional)* |
| **SAP version** | 0.1 DRAFT |
| **SAP author** | Lovemore Gakava |
| **Date** | 2026-04-20 |
| **Gate** | 3.5 — blocks Phase 5 ADaM |
| **Finalisation rule** | SAP must be locked *before* database lock and unblinding (ICH E9) |

### Purpose of this document

This SAP operationalises the statistical considerations in Protocol v1.1 §8 and the SAP-required methods in §11 into analysis-ready specifications. It defines the population flags, endpoint derivations, censoring rules, statistical methods, and subgroup definitions that the downstream ADaM datasets and TFL outputs must implement.

### Dependencies and downstream use

| Downstream artefact | How it uses this SAP |
|---|---|
| `tfl/TFL-SHELLS.md` | One T/F/L per analysis defined here |
| `programming-specs/AD*-spec.md` | Every ADaM variable traces to an analysis in this SAP or to a TFL shell variable |
| `adam/*.R` | Derivations implement this SAP's rules |
| CSR §11 | Efficacy results reference sections here by §number |
| ADRG | Reviewer's guide cites this SAP as the statistical source of truth |

---

## 1. Study Overview (reference only)

CTX-NSCLC-301 is a Phase 3, randomised (2:1), double-blind, placebo-controlled, multinational trial of torivumab 200 mg IV Q3W vs placebo in previously untreated advanced/metastatic NSCLC with PD-L1 TPS ≥50% and no EGFR/ALK aberrations. Planned N = 450 (300 torivumab : 150 placebo). Stratification at randomisation: histology (squamous vs non-squamous), region (NA / EU / APAC). Data cutoff: 2025-01-31.

Full design: Protocol §3.

---

## 2. Objectives and Hypotheses

### 2.1 Primary objective and hypothesis

**Objective:** Compare Overall Survival (OS) between torivumab and placebo arms in the ITT population.

**Null hypothesis (H₀):** OS hazard ratio (torivumab / placebo) = 1, i.e. no difference.
**Alternative (H₁):** OS HR ≠ 1 (two-sided).

**Test:** Stratified log-rank, two-sided α = 0.05 (with interim-analysis alpha spending — see §9).

### 2.2 Secondary objectives

| # | Objective | Null hypothesis |
|---|---|---|
| S1 | Compare PFS (BICR-assessed, RECIST 1.1) between arms | PFS HR = 1 |
| S2 | Compare Objective Response Rate (ORR = CR + PR, BICR) between arms | ORR difference = 0 |
| S3 | Describe Duration of Response (DoR) in responders | No formal hypothesis test |
| S4 | Compare Disease Control Rate (DCR = CR + PR + SD) | DCR difference = 0 |
| S5 | Characterise safety and tolerability | Descriptive |

### 2.3 Exploratory objectives

PROs (EORTC QLQ-C30/LC13, EQ-5D-5L), PD-L1/TMB biomarker–efficacy relationships, PK, ADA, histology and region subgroup efficacy. Exploratory analyses are hypothesis-generating; no formal α.

---

## 3. Analysis Populations

All flags are stored on ADSL and inherited by downstream ADaM datasets.

| Population | ADSL flag | Definition | Expected N |
|---|---|---|---|
| Randomised / ITT | `ITTFL = "Y"` | All randomised patients, analysed as randomised | 450 |
| Safety | `SAFFL = "Y"` | Received ≥1 dose of study drug, analysed as treated | 450* |
| Per-Protocol (PP) | `PPROTFL = "Y"` | ITT ∩ SAFFL ∩ no major protocol deviations | ≥405 |
| Response Evaluable | `EFFFL = "Y"` on ADRS (not ADSL) | ITT with ≥1 post-baseline tumour assessment OR clinical progression before first assessment | ~440 |

\* In the synthetic data all 450 randomised subjects are dosed (see `data-raw/02_ex.R`).

### 3.1 Treatment assignment rule

- For efficacy analyses (ITT, PP, Response Evaluable): analysis by **randomised arm** (`TRT01P`).
- For safety analyses: analysis by **actual arm received** (`TRT01A`). In a double-blind trial with no cross-over, `TRT01P == TRT01A` for all dosed subjects.

### 3.2 Major protocol deviations (for PP)

A major deviation is one that could reasonably have affected the primary efficacy assessment. Pre-specified categories:

- Enrolment despite one or more violated eligibility criteria.
- Randomised but never dosed.
- Received prohibited concomitant medication during the on-treatment period.
- Missed ≥2 consecutive scheduled tumour assessments before the analysis cutoff.

Final list of major deviations is locked at the database-lock deviation review meeting; counts and reasons are reported in Table T-DS-02.

---

## 4. Endpoint Definitions and Derivations

Each endpoint defines: (i) how it is derived from SDTM; (ii) censoring / handling rules; (iii) the ADaM parameter that will carry it.

### 4.1 Overall Survival (OS) — Primary

**Definition:** Time from randomisation to death from any cause.

**Derivation:**
- Start: `RANDDT` (ADSL).
- Event: `DTHFL = "Y"` in ADSL (date = `DTHDT`). Event date = `DTHDT`.
- Censoring rule: Subjects without a recorded death are censored at the **last date known to be alive**, defined as `max(last study contact date, last tumour assessment date, data cutoff date)`, bounded above by `DCUTDT = 2025-01-31`.
- Time to event: `AVAL = DTHDT - RANDDT + 1` (days). `AVAL` is converted to months as `AVAL / 30.4375` for reporting.
- `CNSR`: 0 if death, 1 if censored.

**ADaM target:** ADTTE `PARAMCD = "OS"`, `PARAM = "Overall Survival (days)"`.

**admiral derivation:** `derive_param_tte()` with `event = death_event`, `censor_conditions = list(lastalive_censor)` from `admiralonco`.

### 4.2 Progression-Free Survival (PFS) — Secondary S1

**Definition:** Time from randomisation to the earliest of (a) documented radiological progression per RECIST 1.1 by BICR, or (b) death from any cause.

**Derivation:**
- Start: `RANDDT`.
- Event:
  - Progression: earliest `RS.RSSTRESC = "PD"` where `RSEVAL = "INDEPENDENT ASSESSOR"` (BICR).
  - Death: `DTHDT`.
  - Event date = earliest of the two dates above.
- Censoring rule (pre-specified, per FDA 2018 guidance):
  - No events → censored at **last adequate tumour assessment date** (`max(RS.RSDTC)` with non-missing response).
  - New anti-cancer therapy before PD → censored at last adequate assessment **before** therapy start.
  - ≥2 consecutive missed scheduled assessments before PD → censored at last adequate assessment before the gap.

**ADaM target:** ADTTE `PARAMCD = "PFS"`.

**admiral derivation:** `derive_param_tte()` with `event = pd_event` + `death_event`, `censor_conditions = list(lasta_censor, rand_censor)`.

**Sensitivity:** PFS by Investigator assessment (`PARAMCD = "PFSINV"`).

### 4.3 Objective Response Rate (ORR) — Secondary S2

**Definition:** Proportion of subjects in the Response Evaluable population with a confirmed Best Overall Response (BOR) of CR or PR per RECIST 1.1 by BICR.

**Derivation:**
- BOR (unconfirmed): `admiralonco::derive_param_bor()` using RS records with `RSEVAL = "INDEPENDENT ASSESSOR"`.
- Confirmed BOR: `admiralonco::derive_param_confirmed_bor()` — confirmation = a second CR or PR at a subsequent assessment ≥28 days later with no intervening PD.
- `ORR` flag: 1 if confirmed BOR ∈ {CR, PR}, 0 otherwise.

**ADaM target:** ADRS `PARAMCD = "CBOR"` (confirmed BOR); ADSL carries `ORRFL = "Y"/"N"` for the responder/non-responder flag.

**Responder imputation:** Subjects with no post-baseline assessment are counted as **non-responders** (pre-specified; avoids best-case bias).

### 4.4 Duration of Response (DoR) — Secondary S3

**Definition:** Among responders (confirmed CR or PR), time from the date of first documented response to the earliest of (a) radiological progression, or (b) death from any cause.

- Population: responders only (subset of Response Evaluable).
- Start: date of first CR/PR that was subsequently confirmed.
- Event / censoring: same rules as PFS.

**ADaM target:** ADTTE `PARAMCD = "DOR"`.

### 4.5 Disease Control Rate (DCR) — Secondary S4

**Definition:** Proportion of Response Evaluable subjects with confirmed BOR ∈ {CR, PR, SD}, where SD requires a duration ≥8 weeks from randomisation to meet stability.

**ADaM target:** ADRS `PARAMCD = "CBDCR"`; ADSL `DCRFL`.

### 4.6 Safety Endpoints — Secondary S5

Descriptive only; no formal testing.

- **Treatment-Emergent AE (TEAE):** AE with onset date ≥ `TRTSDT` and ≤ `TRTEDT + 30 days`. admiral: `derive_var_trtemfl()`.
- **Serious AE (SAE):** `AESER = "Y"`.
- **irAE:** AE flagged as immune-related in SUPPAE (`QNAM = "IRAEFL"`, `QVAL = "Y"`).
- **AESI:** AE with MedDRA PT in the protocol §7.4 AESI list.
- **Grade ≥3 AE:** `AETOXGR ∈ {3, 4, 5}`.

Summaries by arm (TRT01A), by SOC/PT, by CTCAE grade. Incidence and exposure-adjusted rates (events per 100 patient-years).

### 4.7 Exploratory Endpoints

Listed in Protocol §2.3. Analyses are descriptive or hypothesis-generating:

- PROs: Mixed Model for Repeated Measures (MMRM) for QLQ-C30 Global Health Status; Time to Deterioration (TTD) by Kaplan-Meier.
- PD-L1 TPS (continuous) / TMB-high vs -low: subgroup OS/PFS HRs; continuous biomarker interaction tests.
- PK/ADA: descriptive; deferred to PK substudy.

These are flagged in this SAP but **not in scope for Gate 3.5** — no corresponding ADaM dataset is specified now. They can be added in a future SAP amendment.

---

## 5. Statistical Methods

### 5.1 Primary analysis — OS

- **Test:** Stratified log-rank test, two-sided, α as per alpha-spending (see §9).
- **Stratification factors:** Histology (squamous / non-squamous); Region (NA / EU / APAC).
- **Effect estimate:** Stratified Cox proportional hazards model, same strata, yielding HR (torivumab / placebo) and 95% CI.
- **Kaplan-Meier summaries:** Median OS and 95% CI per arm using the Brookmeyer-Crowley method (R: `survival::survfit` with `conf.type = "log-log"`). Survival probabilities at 12 / 18 / 24 months with Greenwood 95% CI.
- **Analysis population:** ITT.
- **Analysis timing:** When ~320 OS events accrue (event-driven, Protocol §8.1).
- **Software:** R ≥ 4.5.3, `survival` ≥ 3.7, `tern`.

### 5.2 PFS (S1)

Same methods as OS, applied to PFS event + censoring definitions in §4.2. Analysis population: ITT.

### 5.3 ORR and DCR (S2, S4)

- **Test:** Cochran-Mantel-Haenszel (CMH) test stratified by histology and region.
- **Effect estimate:** Stratified risk difference (Mantel-Haenszel), with 95% CI.
- **Point estimates per arm:** Proportion with Clopper-Pearson exact 95% CI. Wilson score CI as a sensitivity summary.
- **Analysis population:** Response Evaluable (ORR and DCR).

### 5.4 DoR (S3)

Kaplan-Meier; median DoR with 95% CI per arm; restricted to confirmed responders. No formal between-arm test (hypothesis-generating).

### 5.5 Safety (S5)

Descriptive. For each AE summary:
- Incidence = n (%) of subjects with ≥1 event, by arm.
- Exposure-adjusted incidence = events per 100 patient-years (person-time = TRTEDT - TRTSDT + 1, summed across subjects).
- Presented by MedDRA SOC and PT (≥5% threshold for inclusion in the primary AE table per arm).
- Time to onset and time to resolution for irAEs using Kaplan-Meier.

Analysis population: Safety.

---

## 6. Sample Size (reference)

From Protocol §8.1:

| Parameter | Value |
|---|---|
| Primary endpoint | OS |
| HR (alternative) | 0.65 |
| Control median OS | 14.0 months |
| Experimental median OS | 21.5 months |
| Two-sided α | 0.05 |
| Power | 80% |
| Randomisation | 2:1 |
| Required events | ~320 OS deaths |
| Planned N | 450 (300 torivumab : 150 placebo) |
| Dropout assumption | 10% |

Study is event-driven — accrual fixed at 450, follow-up flexed to accumulate 320 events.

---

## 7. Missing Data Handling

| Variable / context | Rule |
|---|---|
| OS death date | If only partial date (e.g. YYYY-MM), impute mid-month per ADaM `derive_vars_dt()` with `highest_imputation = "M"`. If fully missing, treat as censored at last known alive date. |
| PFS progression date | Same imputation rule; fully missing → treat as censored (never an event). |
| Last tumour assessment date | No imputation; use raw date. If entirely absent → censor at `RANDDT`. |
| ORR with no post-baseline assessment | Subject counted as **non-responder** (pre-specified; see §4.3). |
| Baseline lab values | Last non-missing pre-treatment value per PARAMCD. No imputation beyond that. |
| AE outcome missing | Treat as "unresolved" in summaries. |
| PROs (exploratory) | MMRM (inherently handles missing at random); multiple imputation as sensitivity. Out of scope for Gate 3.5. |

Blanket principle: no Last-Observation-Carried-Forward (LOCF) for efficacy endpoints. LOCF limited to baseline-carrying for lab/vitals only.

---

## 8. Multiplicity Control

Familywise two-sided α = 0.05 across the primary and three key secondary efficacy endpoints. Graphical testing procedure (Maurer-Bretz 2013) in the hierarchy:

```
  OS  ─(full α on reject)──►  PFS  ─(full α on reject)──►  ORR  ─(full α on reject)──►  DoR
```

- Each endpoint is tested at two-sided α = 0.05 (with OS spending applied at interim).
- Full α propagates to the next endpoint only if the current one rejects H₀.
- Transition matrix and exact weights are stored in `sap/multiplicity.csv` (to be added at SAP lock).

No alpha spent on exploratory endpoints.

---

## 9. Interim Analyses

Conducted by the independent unblinded statistician; SMC review only.

| Analysis | Trigger | Purpose | α boundary |
|---|---|---|---|
| IA1 — Futility | ~50% OS events (~160 deaths) | Non-binding futility. Stop recommendation if conditional power < 10%. | No α spent |
| IA2 — Efficacy | ~75% OS events (~240 deaths) | Potential early stopping for efficacy | O'Brien-Fleming (Lan-DeMets); approx. two-sided p < 0.00100 |
| Final | ~320 OS events | Primary analysis | Residual α, approx. two-sided p < 0.0464 |

Exact boundaries computed by the independent statistician using the O'Brien-Fleming spending function at the observed information fraction at each interim.

---

## 10. Subgroup Analyses

For OS (and descriptively for PFS, ORR), HR estimates and 95% CI are reported by the following subgroups. Forest plot (F-EFF-05). Treatment × subgroup interaction tests are exploratory (not adjusted for multiplicity).

| Subgroup | Levels | ADSL variable |
|---|---|---|
| Histology (stratification) | Squamous / Non-squamous | `HISTSCAT` / `STRAT2` |
| Region (stratification) | NA / EU / APAC | `REGION1` / `STRAT3` |
| Sex | M / F | `SEX` |
| Age group | <65 / ≥65 | `AGEGR1` (binary collapse from current 3-level definition) |
| ECOG PS | 0 / 1 | To be added to ADSL (`BECOG` — derive from VS/FA at baseline) |
| PD-L1 TPS | 50–74% / ≥75% | To be added to ADSL (`PDL1GR` — derive from LB biomarker results) |
| TMB | High / Low (cutoff TBD) | Exploratory; deferred |

**Gate 3.5 impact:** `BECOG` and `PDL1GR` must be added to the ADSL spec before Phase 5 code is written.

---

## 11. Sensitivity Analyses

| Endpoint | Sensitivity |
|---|---|
| OS | Landmark at 12 / 24 months (difference in survival probability, 95% CI by Greenwood). Weighted log-rank test. Restricted Mean Survival Time (RMST) at τ = 36 months. |
| PFS | BICR-confirmed (requiring radiological confirmation of PD at next scheduled assessment). PFS by Investigator. |
| ORR | Wilson score CI in place of Clopper-Pearson. |
| ITT vs PP | Primary OS analysis re-run on PP population. |

---

## 12. Data Handling and Reporting Conventions

### 12.1 Data cutoff

`DCUTDT = 2025-01-31` (Protocol §6). All events occurring after DCUTDT are censored or excluded from the analysis.

### 12.2 Visit windows

Analysis visit windows for protocol assessments (tumour imaging Q6W for 54 weeks, then Q9W; labs / vitals Q3W on treatment). Specific window rules for ADLB / ADRS to be defined in each dataset spec, consistent with the CRF visit schedule at `crf/visit_schedule.csv`.

### 12.3 Reporting precision

- Survival time in months to 1 decimal.
- Proportions to 1 decimal (e.g. 44.9%).
- HR and 95% CI to 3 decimals (e.g. 0.652).
- p-values: < 0.001 shown as `<0.001`; otherwise 3 decimals.

### 12.4 Software and reproducibility

- R ≥ 4.5.3, pharmaverse stack (`admiral`, `admiralonco`, `tern`, `rtables`), versions pinned in `adam/session_info_install.txt`.
- All analyses reproduce from committed SDTM Parquet → ADaM Parquet → TFL via `Rscript` in subprocess (see `data-raw/00_run_all.R` precedent).
- Random seeds: no analysis is simulation-based; the synthetic *data* uses seeds 301–314 (`data-raw/`).

---

## 13. Estimands (ICH E9(R1))

Primary estimand for OS:

| Attribute | Specification |
|---|---|
| **Population** | All randomised subjects with PD-L1 TPS ≥50% NSCLC per Protocol §4 |
| **Endpoint variable** | Time from randomisation to death from any cause |
| **Summary measure** | Stratified HR (torivumab / placebo) |
| **Intercurrent events** | Treatment discontinuation, new anti-cancer therapy — handled by **treatment policy** strategy (events after these are included) |

Primary estimand for PFS:

| Attribute | Specification |
|---|---|
| **Population** | Same as OS |
| **Endpoint variable** | Time from randomisation to earliest of PD (BICR) or death |
| **Summary measure** | Stratified HR |
| **Intercurrent events** | New anti-cancer therapy before PD → **composite** strategy (censor at last adequate assessment before therapy); ≥2 missed assessments → **composite** (censor at last adequate before gap) |

Primary estimand for ORR:

| Attribute | Specification |
|---|---|
| **Population** | Response Evaluable |
| **Endpoint variable** | Confirmed BOR ∈ {CR, PR} (binary) |
| **Summary measure** | Stratified MH risk difference |
| **Intercurrent events** | No post-baseline assessment → **composite** (counted as non-responder) |

---

## 14. Appendix — Crosswalk to TFL Shells

To be completed in `tfl/TFL-SHELLS.md`. Each numbered SAP method (§5.1 … §5.5, §10, §11) maps to one or more T/F/L outputs. Mapping is listed in the TFL shells document.

---

## 15. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Initial draft — aligned with Protocol v1.1 §8, §11. Gate 3.5 deliverable. |
