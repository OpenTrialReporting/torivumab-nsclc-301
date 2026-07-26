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
| **SAP version** | 0.2 DRAFT |
| **SAP author** | Lovemore Gakava |
| **Date** | 2026-05-16 |
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

> **As simulated:** the delivered data is **1:1 (225 : 225)**, not the planned 2:1 —
> see the note at the top of `protocol/synopsis.md`. Analyses are unaffected in
> specification; only the arm denominators differ from the planned design.

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

\* In the synthetic data all 450 randomised subjects are dosed (see `programs/raw/03_exposure.R`).

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

### 12.2 Analysis visits (AVISIT / AVISITN)

Per ADaMIG v1.3, BDS datasets analysed by timepoint carry the analysis-visit
variables **`AVISIT`** (analysis visit label, character) and **`AVISITN`**
(numeric sort key). These are *conditionally required* for by-visit analysis and
are populated on every BDS finding dataset with a visit structure: **ADLB,
ADEX, ADRS, ADTR, ADVS**. Subject-level summary parameters (e.g. ADRS `BOR`/
`CBOR`, ADEX `CUMDOSE`/`RDI`) are not analysed by visit and carry `AVISIT`/
`AVISITN` = null.

**Windowing.** Each finding is assigned to its nearest scheduled analysis visit
by study day (`ADY`), using a **nearest-target partition**: every analysis visit
has a protocol target study day, and the boundary between two consecutive visits
is the midpoint between their targets, giving a complete, gap-free,
non-overlapping window per visit. An assessment therefore maps to the visit whose
window contains its `ADY`. The window reference is
`crf/analysis_visit_windows.csv` (generated by
`programs/adam/_build_visit_windows.R`) with two streams:

- **TREATMENT** (ADLB, ADVS) — Q3W schedule: `Baseline` (target day −14),
  `C1D1` (1), `C1D15` (15), induction `CnD1` (1 + (n−1)·21 for n = 2…6),
  maintenance `MAINT_CmD1` (1 + (5 + m)·21).
- **TUMOUR** (ADRS, ADTR) — RECIST schedule: `Baseline` (−14) and
  `TUMOR_ASSESS_WKw` (target 7·w days).

Both streams use `AVISIT = "Baseline"` for the pre-treatment window (`AVISITN = 0`)
— see §12.3.

**`AVISITN`** is the numeric key of the windowed `AVISIT`, equal to the SDTM
`VISITNUM` scheme (`Baseline` 0; induction `C1D1…C6D1` 1…7; maintenance
`MAINT_CnD1` = 9 + n; tumour `TUMOR_ASSESS_WKn` = n; EOT / FU1 / FU2
= 900 / 901 / 902).

**Event-driven visits** (`EOT`, `FU1`, `FU2`) are not day-windowed — they are
determined by protocol role and keep their collected label and SDTM `VISITNUM`.
**Subject-level parameters** (ADRS `BOR`/`CBOR`, ADEX `CUMDOSE`/`RDI`) carry
`AVISIT`/`AVISITN` = null.

**Unscheduled visits.** Off-schedule assessments (SDTM `VISIT = "UNSCHEDULED"`,
`VISITNUM = 998`; e.g. a recheck of an abnormal safety lab) are windowed by
`ADY` to their nearest scheduled analysis visit like any other record — they are
*not* treated as a separate `UNSCHEDULED` analysis visit. An unscheduled record
therefore becomes the analysis record for that visit (`ANL01FL = 'Y'`) only when
it is closest to the visit target — typically when the scheduled assessment is
missing; otherwise the scheduled draw keeps `ANL01FL = 'Y'` and the unscheduled
record is retained (`ANL01FL` = null) for listings and traceability, with its
collected `VISIT = "UNSCHEDULED"` preserved.

**Multiple records in one window / analysis flag.** `ANL01FL` uses **one rule for
every windowed BDS finding dataset** (ADLB, ADVS, ADRS, ADTR), implemented once as
`flag_anl01()`:

- **By-visit records** (`AVISIT` populated): exactly one record per
  `USUBJID × PARAMCD × AVISIT` is flagged **`ANL01FL = 'Y'`**. Where more than one
  assessment windows into the same visit (e.g. a late screening lab alongside the
  scheduled draw, or an unscheduled recheck), the record **closest to the visit
  target day** wins (ties → the later `ADT`); inside the `Baseline` visit the
  **`ABLFL = 'Y'` record** wins, so the baseline analysis value agrees with `BASE`
  (§12.3). Event visits (`EOT`/`FU`, no target day) select the latest record.
- **Subject-level records** (`AVISIT` null — ADRS `BOR`/`CBOR`): one record per
  `USUBJID × PARAMCD`; they are the analysis record for that parameter.
- Records with a missing `AVAL` are never flagged, so a missing value cannot win
  a window.
- Datasets whose structure is finer than one row per visit add that level to the
  key: **ADTR** is one record per *lesion* per visit, so `LNKID` joins the key.

By-visit summaries filter `ANL01FL = 'Y'`. The baseline flag `ABLFL` (§12.3) is
derived from the date rather than the window, and identifies the single baseline
record within the `Baseline` (`AVISITN = 0`) analysis visit.

**Non-by-visit datasets.** `ANL01FL` carries the **same definition** everywhere —
*the records selected for that dataset's primary analysis*. In the OCCDS datasets
(ADAE, ADCM, ADDS, ADDV, ADMH) and in ADEX / ADTTE there is no analysis visit to
de-duplicate, so every record in the dataset's **analysis population** is flagged.
Each states that population explicitly rather than assigning a bare `"Y"`:

| Dataset | `ANL01FL = 'Y'` when | Population |
|---|---|---|
| ADAE | `TRTEMFL = 'Y'` and `SAFFL = 'Y'` | Safety, treatment-emergent |
| ADCM | `SAFFL = 'Y'` | Safety |
| ADEX | `SAFFL = 'Y'` | Safety |
| ADMH | `ITTFL = 'Y'` | All randomised (baseline characteristic) |
| ADDS | `ITTFL = 'Y'` | All randomised |
| ADDV | `ITTFL = 'Y'` | All randomised |
| ADTTE | `ITTFL = 'Y'` | ITT (efficacy) |

So the flag never means "every row in the file": it always identifies the analysis
set, whether that is one record per visit (above) or one population of records
(here).

The derivation is implemented once in `programs/adam/_visit_utils.R`
(`derive_avisit_windowed()` for `AVISIT`/`AVISITN`, `flag_anl01()` for the
selection) and applied by ADLB, ADVS, ADRS and ADTR. Traceability: the SDTM
`VISIT` is retained alongside `AVISIT`/`AVISITN` (and `VISITNUM` in ADLB/ADEX/
ADVS; ADRS/ADTR omit `VISITNUM` as SDTM did not collect it). On this study the
windowing reproduces the collected visit for 99.7% of finding records; the
remainder are late-screening labs/vitals (`ADY` ≈ −6) that window to the
`C1D1` visit as their nearest scheduled timepoint.

### 12.3 Baseline definition (ABLFL / BASE)

For every by-visit BDS dataset (**ADLB, ADVS, ADTR**), **baseline is the last
non-missing analysis value on or before the date of first study treatment**
(`ADT ≤ TRTSDT`), selected per `USUBJID × PARAMCD` (ADTR additionally per target
lesion), with ties broken by the SDTM sequence number. That single record is
flagged **`ABLFL = "Y"`**.

The selection is **date-based, not visit-based**: the reference value is whichever
assessment is last before treatment — a Screening draw *or* a Cycle 1 Day 1
pre-dose draw — regardless of the collected `VISIT`. There is exactly one baseline
per subject × parameter (Pinnacle 21 AD0154); a subject with no pre-treatment
assessment has `ABLFL` null, is retained in the dataset, and is excluded from
change-from-baseline analyses.

Per CDISC ADaM convention (no controlled terminology governs `AVISIT`; the
convention is set by the ADaMIG BDS examples and the CDISC ADaM Pilot), the
`ABLFL = "Y"` record — and the pre-treatment window that contains it — carries
**`AVISIT = "Baseline"`, `AVISITN = 0`**. `BASE` is the `ABLFL` record's `AVAL`,
copied onto every record of the same subject/parameter; `CHG = AVAL − BASE` and
`PCHG = 100 × CHG / BASE`. Baseline value is carried into `BASE` only — no other
LOCF is applied (§10). ADRS response parameters (`OVR`/`BOR`/`CBOR`) are
categorical and carry no `BASE`/`ABLFL`.

### 12.4 Reporting precision

- Survival time in months to 1 decimal.
- Proportions to 1 decimal (e.g. 44.9%).
- HR and 95% CI to 3 decimals (e.g. 0.652).
- p-values: < 0.001 shown as `<0.001`; otherwise 3 decimals.

### 12.5 Software and reproducibility

- R ≥ 4.5.3, pharmaverse stack (`admiral`, `admiralonco`, `tern`, `rtables`), versions pinned in `adam/session_info_install.txt`.
- All analyses reproduce from committed SDTM Parquet → ADaM Parquet → TFL via `Rscript` in subprocess (see `programs/raw/00_simulate_raw.R` precedent).
- Random seeds: no analysis is simulation-based; the synthetic *data* uses seeds 301–316 (`programs/raw/`).

---

## 13. Estimands (ICH E9(R1))

### 13.1 Framework

Each clinical question in this trial is operationalised as an **estimand** — a precise description of the treatment effect reflecting the clinical question, structured by the five attributes specified in ICH E9(R1) (2019): *Population*, *Variable*, *Treatment*, *Intercurrent Event handling*, and *Population-level Summary*. For each estimand, this SAP also names the **estimator** (the statistical method that produces an estimate) and one or more **sensitivity estimands** addressing the same clinical question under alternative IE handling assumptions.

Strategies for handling intercurrent events follow ICH E9(R1) §A.4.3:

| Strategy | What it means | When used here |
|---|---|---|
| **Treatment policy** | Endpoint observed as occurred, regardless of IE | OS analyses (any-cause death is captured regardless of subsequent therapy) |
| **Hypothetical** | Estimate effect *as if* IE had not occurred | PFS censoring at new anti-cancer therapy or missed assessments (FDA 2018 guidance) |
| **Composite** | IE itself becomes part of the endpoint | ORR: no post-baseline assessment → non-responder |
| **While-on-treatment** | Endpoint considered only while on randomised treatment | OS sensitivity estimand (treatment-period effect) |
| **Principal stratum** | Subset population that would not experience IE | Not used in primary or sensitivity estimands |

### 13.2 Shared attributes

The **Population** attribute is defined per-estimand below; the **Treatment** attribute is shared:

| Treatment arm | Specification |
|---|---|
| Experimental | Torivumab 200 mg IV Q3W + chemotherapy backbone (carboplatin AUC5 + pemetrexed 500 mg/m² IV Q3W) for up to 6 induction cycles, then pemetrexed maintenance Q3W until PD/toxicity/withdrawal (max 35 cycles total) |
| Control      | Placebo IV Q3W + identical chemotherapy backbone, same duration rules |

### 13.3 Intercurrent event taxonomy

Pre-specified IEs anticipated in this trial, and the default handling strategy per endpoint family:

| Intercurrent event | OS | PFS | ORR | DOR |
|---|---|---|---|---|
| Treatment discontinuation (any reason) | Treatment policy | Treatment policy | Treatment policy | Treatment policy |
| Initiation of subsequent anti-cancer therapy | Treatment policy | Hypothetical (censor at last adequate assessment before therapy) | Treatment policy | Hypothetical |
| ≥2 consecutive missed scheduled tumour assessments | n/a | Hypothetical (censor at last adequate before gap) | Treatment policy | Hypothetical |
| No post-baseline tumour assessment | n/a | Hypothetical (censor at randomisation) | **Composite (non-responder)** | n/a (not a responder by definition) |
| Death before first response assessment | Event | Event | **Composite (non-responder)** | n/a |
| Withdrawal of consent from data collection | Censor at withdrawal date | Censor at last adequate assessment | Composite (non-responder) | Censor at withdrawal |

### 13.4 Primary estimand — Overall Survival (OS)

| Attribute | Specification |
|---|---|
| **Population** | All randomised subjects (ITT; `ITTFL = "Y"`) with treatment-naïve metastatic NSCLC, PD-L1 TPS ≥50%, no sensitising EGFR mutations or ALK rearrangements, ECOG PS 0–1 |
| **Variable** | Time (months) from randomisation to death from any cause; censored at last date known to be alive on or before `DCUTDT = 2025-01-31` |
| **Treatment** | As §13.2 |
| **Intercurrent events** | Treatment policy for all IEs (treatment discontinuation, subsequent anti-cancer therapy, palliative care). Death itself is the event, not an IE. Withdrawal of survival consent → censor at withdrawal date. |
| **Population-level summary** | Stratified hazard ratio (torivumab / placebo) with 95% CI; strata = histology (squamous/non-squamous) × region (NA/EU/APAC). Supplementary KM medians and 12/18/24-month survival probabilities per arm. |

**Estimator:** Stratified Cox proportional-hazards regression (`survival::coxph(Surv(AVAL, 1-CNSR) ~ TRT01PN + strata(STRAT2, STRAT3), data = adtte_os)`). KM estimates via `survival::survfit` with `conf.type = "log-log"` for medians (Brookmeyer–Crowley) and Greenwood SE for landmark probabilities. Stratified two-sided log-rank for the primary hypothesis test.

**Aligned sensitivity estimands:**

| Sensitivity estimand | Difference vs primary | Purpose | Estimator |
|---|---|---|---|
| **OS — Restricted Mean Survival Time (RMST)** | Population-level summary changes from HR to **difference in RMST at τ = 36 months** | Addresses PH assumption robustness; interpretable as "average months survived over 3 years" | `survRM2::rmst2()` with method = "augmented"; stratification handled via inverse-probability weighting |
| **OS — While-on-treatment** | Intercurrent event handling for subsequent anti-cancer therapy changes from *treatment policy* to **while-on-treatment** (censor at start of subsequent therapy or at TRTEDT + 30 days, whichever earlier) | Quantifies the effect of torivumab *during* the randomised treatment period, separate from any downstream therapy effects | Same Cox PH model with revised censoring rule in ADTTE `PARAMCD = "OSWOT"` |

### 13.5 Key secondary estimand — Progression-Free Survival (PFS)

| Attribute | Specification |
|---|---|
| **Population** | ITT (same as OS) |
| **Variable** | Time (months) from randomisation to earliest of (a) documented PD per RECIST 1.1 by **BICR**, or (b) death from any cause |
| **Treatment** | As §13.2 |
| **Intercurrent events** | New anti-cancer therapy before PD → **hypothetical** (censor at last adequate assessment before therapy); ≥2 consecutive missed scheduled assessments before PD → **hypothetical** (censor at last adequate before gap); treatment discontinuation without subsequent therapy → treatment policy (continue PFS follow-up) |
| **Population-level summary** | Stratified HR (torivumab / placebo) with 95% CI, same strata as OS |

**Estimator:** Stratified Cox PH on ADTTE `PARAMCD = "PFS"`. Censoring rules implemented per `admiral::derive_param_tte()` with FDA-2018-aligned event-/censor-source definitions (`pd_event`, `death_event`, `last_adeq_censor`, `rand_censor`).

**Sensitivity estimand:**

| Sensitivity estimand | Difference vs primary | Purpose | Estimator |
|---|---|---|---|
| **PFS by Investigator (PFSINV)** | Variable changes — uses Investigator-assessed PD (`RSEVAL = "INVESTIGATOR"`) rather than BICR | Assesses concordance of BICR with site read; standard regulatory sensitivity for blinded oncology trials | Same Cox PH model on ADTTE `PARAMCD = "PFSINV"` |

### 13.6 Key secondary estimand — Objective Response Rate (ORR)

| Attribute | Specification |
|---|---|
| **Population** | Response Evaluable (ITT with ≥1 post-baseline tumour assessment OR clinical progression before first assessment; `EFFFL = "Y"` on ADRS) |
| **Variable** | Binary indicator of confirmed Best Overall Response ∈ {CR, PR} per RECIST 1.1 by BICR; confirmation requires second CR/PR ≥28 days later with no intervening PD |
| **Treatment** | As §13.2 |
| **Intercurrent events** | No post-baseline assessment → **composite** (counted as non-responder); treatment discontinuation before adequate assessment → composite (non-responder); subsequent anti-cancer therapy before adequate assessment → composite (non-responder, pre-specified to avoid attribution bias) |
| **Population-level summary** | Stratified Mantel–Haenszel risk difference (torivumab − placebo) with 95% CI; strata = histology × region. Supplementary per-arm Clopper–Pearson exact 95% CI for the proportion. |

**Estimator:** `stats::mantelhaen.test()` on the 2 × 2 × stratum table; per-arm proportions via `binom.test()`. Sensitivity using Wilson score CI (`PropCIs::scoreci()`).

**Sensitivity estimand:**

| Sensitivity estimand | Difference vs primary | Purpose | Estimator |
|---|---|---|---|
| **ORR — ITT denominator** | Population changes from Response Evaluable to **full ITT**, retaining the composite IE handling | Removes the implicit best-case selection that Response Evaluable can introduce; conservative regulatory-style read | Same MH model with `ANL01FL = "Y"` (ITT) rather than `EFFFL = "Y"` |

### 13.7 Other secondary endpoints

**Duration of Response (DOR):**

| Attribute | Specification |
|---|---|
| Population | Confirmed responders only (subset of Response Evaluable) |
| Variable | Time from first confirmed CR/PR to earliest of PD (BICR) or death |
| Treatment | As §13.2 |
| Intercurrent events | Same as PFS (hypothetical for new therapy and missed assessments) |
| Population-level summary | KM median per arm with 95% CI; no formal between-arm hypothesis test (descriptive / hypothesis-generating) |

**Disease Control Rate (DCR):** Same structure as ORR but variable = confirmed BOR ∈ {CR, PR, SD}, where SD requires duration ≥8 weeks from randomisation. Same composite IE strategy.

**Safety endpoints:** Estimands here are descriptive rather than inferential. Three implicit estimands are operationalised:

| Safety estimand | IE handling | Summary |
|---|---|---|
| TEAE incidence | Treatment policy (count any AE with onset ≥ TRTSDT and ≤ TRTEDT + 30 d) | n (%) per arm |
| Exposure-adjusted TEAE rate | While-on-treatment (person-time = TRTEDT − TRTSDT + 1) | Events per 100 patient-years per arm |
| irAE-specific incidence and time-to-onset | Treatment policy for incidence; KM for time-to-onset / time-to-resolution | Per arm; descriptive |

### 13.8 Summary table

| # | Estimand | Population | Variable | IE strategy (key) | Summary measure | Estimator |
|---|---|---|---|---|---|---|
| E1 | OS — primary | ITT | TTE death | Treatment policy | Stratified HR | Stratified Cox PH |
| E1a | OS — RMST | ITT | TTE death (τ=36m) | Treatment policy | Difference in RMST | `survRM2::rmst2()` |
| E1b | OS — while-on-treatment | ITT | TTE death (censored at therapy/TRTEDT+30) | While-on-treatment for subsequent therapy | Stratified HR | Stratified Cox PH |
| E2 | PFS — primary | ITT | TTE PD (BICR) or death | Hypothetical (new tx, missed) | Stratified HR | Stratified Cox PH |
| E2a | PFS — Investigator | ITT | TTE PD (INV) or death | Same as E2 | Stratified HR | Stratified Cox PH |
| E3 | ORR — primary | Response Evaluable | Confirmed BOR ∈ {CR, PR} | Composite (non-responder) | Stratified MH RD | CMH test |
| E3a | ORR — ITT denom | ITT | Confirmed BOR ∈ {CR, PR} | Composite | Stratified MH RD | CMH test |
| E4 | DOR | Confirmed responders | TTE PD or death from first CR/PR | Hypothetical | KM median | `survival::survfit` |
| E5 | DCR | Response Evaluable | Confirmed BOR ∈ {CR, PR, SD≥8w} | Composite | Stratified MH RD | CMH test |
| S1 | TEAE incidence | Safety | Count of subjects with ≥1 TEAE | Treatment policy | n (%) | Descriptive |
| S2 | Exposure-adjusted TEAE | Safety | TEAE events per 100 PY | While-on-treatment | Rate | Descriptive |
| S3 | irAE time-to-onset | Safety | TTE first irAE | Treatment policy | KM median | `survival::survfit` |

---

## 14. Appendix — Crosswalk to TFL Shells

To be completed in `tfl/TFL-SHELLS.md`. Each numbered SAP method (§5.1 … §5.5, §10, §11) maps to one or more T/F/L outputs. Mapping is listed in the TFL shells document.

---

## 15. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Initial draft — aligned with Protocol v1.1 §8, §11. Gate 3.5 deliverable. |
| 0.2 | 2026-05-16 | LG (w/ Claude Opus 4.7) | §13 rewritten with full ICH E9(R1) estimand framework: framework intro + IE-strategy taxonomy (§13.1), shared population/treatment attributes (§13.2–§13.3), per-endpoint estimands with estimators and sensitivity estimands for OS (RMST, while-on-treatment), PFS (Investigator), ORR (ITT denominator), plus DOR/DCR/safety estimands (§13.4–§13.7), and a one-page summary table (§13.8). No changes to analytic methodology — only formalises what §5 already specifies. |
