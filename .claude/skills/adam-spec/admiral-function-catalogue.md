# admiral Function Catalogue

Verified against `admiral 1.4.1` + `admiralonco 1.4.0` + `xportr 0.5.0` (installed 2026-04-20, see `adam/session_info_install.txt`).

When authoring a spec, pick the first admiral function that matches your derivation pattern. If nothing in this catalogue fits, write `CUSTOM — see §Derivations.X` in the spec and justify in the Derivations block.

---

## Install

```r
install.packages(
  c("admiral", "admiralonco", "admiraldev",
    "metacore", "metatools", "xportr",
    "pharmaversesdtm", "pharmaverseadam"),
  repos = "https://cloud.r-project.org",
  dependencies = TRUE
)
```

---

## Merging SDTM onto ADaM

| Derivation need | admiral function | Notes |
|---|---|---|
| Merge subject-level SDTM vars (e.g. DM) onto ADaM | `derive_vars_merged()` | One-to-one join by USUBJID. |
| Merge looked-up values (e.g. race groupings) | `derive_vars_merged_lookup()` | Supports fallback for missing keys. |
| Derive event flags by looking across two datasets | `derive_var_merged_exist_flag()` | Returns Y/N flag. |
| First/last/max occurrence of an event | `derive_var_extreme_flag()` / `derive_vars_extreme_event()` | Combined with `new_vars` or `order`. |

## Dates and durations

| Derivation need | admiral function | Notes |
|---|---|---|
| Convert ISO 8601 `--DTC` to date | `derive_vars_dt()` | Imputation rules supported. |
| Convert `--DTC` to datetime | `derive_vars_dtm()` | Preserves time. |
| Study day | `derive_vars_dy()` | Relative to a reference date (typically TRTSDT). |
| Age in years from birthdate | `derive_var_age_years()` / `derive_vars_aage()` | |
| Duration between two dates | `derive_vars_duration()` | Specify `out_unit`. |
| Treatment duration (days) | `derive_var_trtdurd()` | TRTSDT → TRTEDT. |

## Treatment variables (ADSL)

| Derivation need | admiral function | Notes |
|---|---|---|
| TRTSDT (first dose date) | `derive_vars_merged()` with `filter_add` + `new_vars = exprs(TRTSDT = ...)` | Source: SDTM.EX, first non-missing EXSTDTC. |
| TRTEDT (last dose date) | `derive_vars_merged()` | Last non-missing EXENDTC. |
| TRT01P / TRT01A | Direct from DM.ARM / DM.ACTARM | Assign labels via `mutate()`. |
| Death date / DTHCAUS | `derive_var_dthcaus()` | Takes multiple date sources. |

## Analysis flags

| Derivation need | admiral function | Notes |
|---|---|---|
| Baseline flag (ABLFL) | `derive_var_extreme_flag()` | last/first pre-treatment record per PARAMCD. |
| On-treatment flag (ONTRTFL) | `derive_var_ontrtfl()` | Date in \[TRTSDT, TRTEDT + window\]. |
| Treatment-emergent flag (TRTEMFL, AE) | `derive_var_trtemfl()` | AE onset ≥ TRTSDT and ≤ TRTEDT+30d (default). |
| Analysis-value comparison flag | `derive_vars_crit_flag()` | CRITy / CRITyFL. |

## Baseline / change / shift (ADLB, ADVS, ADTR)

| Derivation need | admiral function | Notes |
|---|---|---|
| BASE | `derive_var_base()` | Carries baseline AVAL onto post-baseline records. |
| CHG (change from baseline) | `derive_var_chg()` | AVAL - BASE. |
| PCHG (% change from baseline) | `derive_var_pchg()` | (AVAL - BASE) / BASE × 100. |
| Analysis reference range indicator | `derive_var_anrind()` | LOW/NORMAL/HIGH. |
| Analysis toxicity grade | `derive_var_atoxgr()` / `derive_var_atoxgr_dir()` | CTCAE. |
| Shift variable (baseline → post) | `derive_var_shift()` | |
| LOCF imputation | `derive_locf_records()` | |

## Parameter derivation (ADLB computed params, vitals)

| Derivation need | admiral function | Notes |
|---|---|---|
| BMI / BSA | `derive_param_bmi()` / `derive_param_bsa()` | |
| QTc | `derive_param_qtc()` | Methods: Bazett, Fridericia, Sagie. |
| Computed parameter | `derive_param_computed()` | General form. |
| Absolute WBC from differential | `derive_param_wbc_abs()` | |

## Oncology-specific (ADRS, ADTR, ADTTE) — admiralonco

| Derivation need | admiralonco function | Notes |
|---|---|---|
| Best Overall Response (unconfirmed) | `derive_param_bor()` | Uses source objects: `bor_cr`, `bor_pr`, `bor_sd`, `bor_pd`, `bor_ne`, `bor_non_crpd`. |
| Confirmed BOR (RECIST 1.1) | `derive_param_confirmed_bor()` | Requires ≥2 consecutive CR or PR separated by ≥`ref_confirm` days. |
| Response flag (any responder) | `derive_param_response()` | |
| Confirmed response flag | `derive_param_confirmed_resp()` | |
| Clinical benefit flag | `derive_param_clinbenefit()` | CR + PR + SD (≥N weeks). |
| Filter to records up to first PD | `filter_pd()` | |

## Time-to-event (ADTTE)

| Derivation need | admiral function | Notes |
|---|---|---|
| Generic TTE parameter (OS, PFS, …) | `derive_param_tte()` | Core engine — takes `event_conditions`, `censor_conditions`. |
| Death event source | `admiralonco::death_event` (prebuilt) | For OS. |
| PD event source | `admiralonco::pd_event` (prebuilt) | For PFS. |
| Randomisation censor | `admiralonco::rand_censor` | For ITT analyses from randomisation. |
| Last tumour assessment censor | `admiralonco::lasta_censor` | For PFS if no PD observed. |
| Last known alive censor | `admiralonco::lastalive_censor` | For OS if not deceased. |

## Export / Submission-readiness — xportr

| Need | xportr function |
|---|---|
| Apply length from metadata | `xportr_length()` |
| Apply label from metadata | `xportr_label()` |
| Apply type (Char/Num) from metadata | `xportr_type()` |
| Apply display format | `xportr_format()` |
| Order columns by metadata | `xportr_order()` |
| Write .xpt (SAS transport) | `xportr_write()` |

## Metadata governance — metacore / metatools

| Need | function |
|---|---|
| Build a metacore object from spec CSV / Excel | `metacore::spec_to_metacore()` |
| Filter metacore to one dataset | `metacore::select_dataset()` |
| Check variable set matches spec | `metatools::check_variables()` |
| Drop non-spec variables | `metatools::drop_unspec_vars()` |
| Create from metacore object | `metatools::create_var_from_codelist()` |

---

## What to do when nothing fits

If a derivation genuinely has no admiral equivalent:

1. State that in the spec's Derivations section: "No admiral function for this rule — hand-coded."
2. Write the logic with `dplyr::mutate()` / `case_when()` directly in `adam/ad{xx}.R`.
3. Keep the logic contained in a named helper function at the top of the script, so reviewers can find it.

Do **not** reimplement logic that admiral already provides — the whole point of the stack is validated, auditable derivations.
