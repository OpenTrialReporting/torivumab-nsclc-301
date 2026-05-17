# ADEX — Exposure Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADEX |
| **Label** | Exposure Analysis Dataset |
| **Class** | BDS |
| **Structure** | One record per administration (DOSEAMT) + one summary record per subject per drug per parameter (CUMDOSE, RDI) |
| **Expected N** | ~16,097 |
| **Key variables** | `STUDYID`, `USUBJID`, `PARAMCD`, `AEXTRT` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADEX supports the exposure summary (T-EX-01) and relative-dose-intensity tables (T-EX-02). It carries one row per administration (PARAMCD=DOSEAMT) and two per-subject per-drug summary rows (CUMDOSE, RDI), so a single dataset answers both "what was administered" and "how completely was the planned regimen delivered".

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, treatment duration, population flags, treatment arm |
| SDTM.EX | `sdtm/ex.parquet` | Per-administration dose records, drug name, dose unit, visit |

## Parameters

| PARAMCD | PARAM | Granularity | Derivation |
|---|---|---|---|
| DOSEAMT | Dose Amount per Administration | One row per SDTM.EX record | `AVAL = as.numeric(EXDOSE)`; `AVALU = EXDOSU`; `NCYCLE = row_number()` per (USUBJID, AEXTRT) ordered by ADT |
| CUMDOSE | Cumulative Dose — `{AEXTRT}` | One row per (USUBJID, AEXTRT) | `AVAL = sum(DOSEAMT.AVAL)` per group |
| RDI | Relative Dose Intensity — `{AEXTRT}` (%) | One row per (USUBJID, AEXTRT) | `AVAL = 100 × actual_cumulative / planned_cumulative` |

### Planned cumulative dose

| Drug | Planned per cycle | Notes |
|---|---|---|
| TORIVUMAB | 200 mg | Fixed flat dose |
| PLACEBO | 200 mg | Matched placebo |
| CARBOPLATIN, PEMETREXED | Per-subject mean of actual doses × n_admin | Synthetic-data simplification (real study: per-cycle BSA / AUC) |

`planned_cumulative = planned_per_cycle × n_administrations`. RDI = NA if planned_cumulative ≤ 0.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `EX.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `EX.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `EX.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `EX.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 8 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 9 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 10 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 11 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTSDT |
| 12 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTEDT |
| 13 | TRTDURD | Total Treatment Duration (Days) | Num | 8 | Derived | — | Merged from ADSL.TRTDURD |
| 14 | AEXSEQ | Analysis Sequence Number for EX | Num | 8 | Derived | — | `row_number()` per (USUBJID, AEXTRT) for DOSEAMT; NA for CUMDOSE/RDI |
| 15 | AEXTRT | Analysis Treatment | Char | 40 | Derived | — | `EX.EXTRT` |
| 16 | PARAM | Parameter | Char | 100 | Derived | — | See Parameters table |
| 17 | PARAMCD | Parameter Code | Char | 10 | Derived | — | DOSEAMT / CUMDOSE / RDI |
| 18 | AVAL | Analysis Value | Num | 8 | Derived | — | See Parameters table |
| 19 | AVALU | Analysis Value Unit | Char | 10 | Derived | — | `EX.EXDOSU` for DOSEAMT/CUMDOSE; `"%"` for RDI |
| 20 | ADT | Analysis Date | Num | 8 | Derived | — | `as.Date(EXSTDTC)` for DOSEAMT; `max(ADT)` per group for CUMDOSE; `TRTEDT` for RDI |
| 21 | ADY | Analysis Relative Day | Num | 8 | Derived | — | `as.integer(ADT - TRTSDT) + 1` |
| 22 | NCYCLE | Cycle Number | Num | 8 | Derived | — | `row_number()` per (USUBJID, AEXTRT) for DOSEAMT; `max(NCYCLE)` for CUMDOSE; `n_admin` for RDI |
| 23 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `EX.VISIT` (NA for CUMDOSE/RDI) |
| 24 | VISITNUM | Visit Number | Num | 8 | Predecessor | — | `EX.VISITNUM` (NA for CUMDOSE/RDI) |
| 25 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `"Y"` for all records |

## Derivations

### D1 — DOSEAMT (per-administration record)

**Pseudocode:**
```r
ex_admin <- ex %>%
  left_join(adsl_vars, by = c("STUDYID","USUBJID")) %>%
  mutate(
    PARAM   = "Dose Amount per Administration",
    PARAMCD = "DOSEAMT",
    AVAL    = as.numeric(EXDOSE),
    AVALU   = EXDOSU,
    ADT     = as.Date(EXSTDTC),
    ADY     = as.integer(ADT - TRTSDT) + 1L,
    AEXTRT  = EXTRT
  ) %>%
  arrange(USUBJID, AEXTRT, ADT) %>%
  group_by(USUBJID, AEXTRT) %>%
  mutate(AEXSEQ = row_number(), NCYCLE = AEXSEQ) %>%
  ungroup()
```

### D2 — CUMDOSE (cumulative dose summary)

**Pseudocode:**
```r
ex_cumdose <- ex_admin %>%
  group_by(USUBJID, AEXTRT) %>%
  summarise(
    AVAL   = sum(AVAL, na.rm = TRUE),
    AVALU  = first(AVALU),
    NCYCLE = max(NCYCLE),
    ADT    = max(ADT),
    .groups = "drop"
  ) %>%
  mutate(PARAM = paste0("Cumulative Dose — ", AEXTRT), PARAMCD = "CUMDOSE")
```

### D3 — RDI (relative dose intensity %)

**Rule:** `RDI = 100 × actual_cumulative / planned_cumulative`. Planned per cycle is fixed for TORIVUMAB/PLACEBO (200 mg) and derived from the per-subject mean of actual doses for CARBOPLATIN / PEMETREXED.

**Pseudocode:**
```r
PLANNED_PER_CYCLE <- c(TORIVUMAB = 200, PLACEBO = 200)

planned_cum <- ex_admin %>%
  group_by(USUBJID, AEXTRT) %>%
  summarise(
    actual_cum   = sum(AVAL, na.rm = TRUE),
    n_admin      = n(),
    avg_per_dose = mean(AVAL, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    planned_cum = case_when(
      AEXTRT %in% names(PLANNED_PER_CYCLE) ~ PLANNED_PER_CYCLE[AEXTRT] * n_admin,
      TRUE                                  ~ avg_per_dose * n_admin
    ),
    RDI = ifelse(planned_cum > 0, 100 * actual_cum / planned_cum, NA_real_)
  )
```

**Edge cases:** When `planned_cum == 0` (subject randomised but no dose), RDI = NA. ADT for RDI rows is set to `TRTEDT` so KM-style time joins remain well-defined.

## QC Checks

- [ ] `nrow(adex)` ≈ 16,097 (±1%).
- [ ] PARAMCD ∈ {DOSEAMT, CUMDOSE, RDI}; no others.
- [ ] For every (USUBJID, AEXTRT): at most one CUMDOSE row and at most one RDI row.
- [ ] `sum(adex$PARAMCD == "CUMDOSE")` == `sum(adex$PARAMCD == "RDI")`.
- [ ] `AVAL >= 0` for DOSEAMT and CUMDOSE; `AVAL` ∈ [0, 200] typically for RDI.
- [ ] `ADT >= TRTSDT` for every DOSEAMT row.
- [ ] All `ANL01FL == "Y"`.
- [ ] Variable labels, lengths, types match this spec.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADEX-spec.md` → `programs/adam/adex.R` | `programs/adam/adex.R` → `datasets/adam/adex.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
