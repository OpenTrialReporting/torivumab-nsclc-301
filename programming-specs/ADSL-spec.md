# ADSL — Subject-Level Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADSL |
| **Label** | Subject-Level Analysis Dataset |
| **Class** | SUBJECT LEVEL ANALYSIS DATASET |
| **Structure** | One record per subject |
| **Expected N** | 450 |
| **Key variables** | `USUBJID` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-20 |

## Purpose

ADSL is the subject-level backbone for all downstream analyses (efficacy, safety, PK/PD). It carries one record per randomised subject, consolidates treatment and disposition dates, and defines the population flags (SAFFL, ITTFL, PPROTFL) that every other ADaM dataset merges onto its rows.

This spec supports the efficacy endpoints in Protocol v1.1 §2 (OS primary; PFS, ORR secondary) and safety analyses in §7.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| SDTM.DM | `sdtm/dm.parquet` | Subject backbone, demographics, treatment arm, reference dates, death |
| SDTM.SUPPDM | `sdtm/suppdm.parquet` | Region (`REGION1`), histology stratum (`HISTSCAT`) |
| SDTM.DS | `sdtm/ds.parquet` | Randomisation date, end-of-study, discontinuation reason |
| SDTM.EX | `sdtm/ex.parquet` | First/last dose dates → TRTSDT / TRTEDT |
| SDTM.DD | `sdtm/dd.parquet` | Primary cause of death → DTHCAUS |
| Data cutoff | Protocol v1.1 §6 | 2025-01-31 — DCUTDT |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `DM.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `DM.USUBJID` |
| 3 | SUBJID | Subject Identifier for the Study | Char | 10 | Predecessor | — | `DM.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `DM.SITEID` |
| 5 | AGE | Age | Num | 8 | Predecessor | — | `DM.AGE` |
| 6 | AGEU | Age Units | Char | 10 | Predecessor | AGEU | `DM.AGEU` (="YEARS") |
| 7 | AGEGR1 | Pooled Age Group 1 | Char | 10 | Derived | AGEGR1 | CUSTOM — see §Derivations.D1 |
| 8 | AGEGR1N | Pooled Age Group 1 (N) | Num | 8 | Derived | — | 1=`<65`, 2=`65-<75`, 3=`>=75` |
| 9 | SEX | Sex | Char | 1 | Predecessor | SEX | `DM.SEX` |
| 10 | RACE | Race | Char | 60 | Predecessor | RACE | `DM.RACE` |
| 11 | ETHNIC | Ethnicity | Char | 40 | Predecessor | ETHNIC | `DM.ETHNIC` |
| 12 | COUNTRY | Country | Char | 3 | Predecessor | COUNTRY | `DM.COUNTRY` |
| 13 | REGION1 | Geographic Region 1 | Char | 10 | Derived | REGION1 | `derive_vars_merged()` from SUPPDM where QNAM="REGION1" |
| 14 | HISTSCAT | Histology Category | Char | 20 | Derived | HISTSCAT | `derive_vars_merged()` from SUPPDM where QNAM="HISTSCAT" |
| 15 | ARM | Description of Planned Arm | Char | 40 | Predecessor | ARM | `DM.ARM` |
| 16 | ARMCD | Planned Arm Code | Char | 20 | Predecessor | ARMCD | `DM.ARMCD` |
| 17 | ACTARM | Description of Actual Arm | Char | 40 | Predecessor | ARM | `DM.ACTARM` |
| 18 | ACTARMCD | Actual Arm Code | Char | 20 | Predecessor | ARMCD | `DM.ACTARMCD` |
| 19 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Assigned | TRT | = `ARM` |
| 20 | TRT01PN | Planned Treatment for Period 01 (N) | Num | 8 | Assigned | — | 1=TORIVUMAB, 2=PLACEBO |
| 21 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Assigned | TRT | = `ACTARM` |
| 22 | TRT01AN | Actual Treatment for Period 01 (N) | Num | 8 | Assigned | — | 1=TORIVUMAB, 2=PLACEBO |
| 23 | RFICDT | Informed Consent Date | Num | 8 | Derived | — | `derive_vars_dt(dtc = DM.RFICDTC)` |
| 24 | RANDDT | Date of Randomization | Num | 8 | Derived | — | CUSTOM — see §Derivations.D2 (DS where DSDECOD="RANDOMIZED") |
| 25 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | CUSTOM — see §Derivations.D3 (first EX.EXSTDTC) |
| 26 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | CUSTOM — see §Derivations.D4 (last non-missing EX.EXENDTC) |
| 27 | TRTDURD | Total Treatment Duration (Days) | Num | 8 | Derived | — | `derive_var_trtdurd()` |
| 28 | EOSDT | End of Study Date | Num | 8 | Derived | — | `derive_vars_dt()` from DS where DSCAT="STUDY DISCONTINUATION" OR DSDECOD="COMPLETED" |
| 29 | EOSSTT | End of Study Status | Char | 20 | Derived | EOSSTT | CUSTOM — see §Derivations.D5 |
| 30 | DCSREAS | Reason for Discontinuation from Study | Char | 40 | Derived | — | `DS.DSDECOD` on the end-of-study record |
| 31 | DTHDT | Date of Death | Num | 8 | Derived | — | `derive_vars_dt(dtc = DM.DTHDTC)` |
| 32 | DTHFL | Subject Death Flag | Char | 1 | Predecessor | NY | `DM.DTHFL` |
| 33 | DTHCAUS | Cause of Death | Char | 100 | Derived | — | `derive_var_dthcaus()` using DD domain as source |
| 34 | DCUTDT | Data Cutoff Date | Num | 8 | Assigned | — | `as.Date("2025-01-31")` |
| 35 | RANDFL | Randomized Population Flag | Char | 1 | Derived | NY | `Y` if RANDDT not missing |
| 36 | ITTFL | Intent-to-Treat Population Flag | Char | 1 | Derived | NY | = `RANDFL` |
| 37 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | `Y` if ≥1 EX record, else `N` |
| 38 | PPROTFL | Per-Protocol Population Flag | Char | 1 | Derived | NY | CUSTOM — see §Derivations.D6 |
| 39 | EFFFL | Efficacy Population Flag | Char | 1 | Derived | NY | = `ITTFL` (primary efficacy = ITT) |
| 40 | STRAT1 | Stratum 1: PD-L1 TPS | Char | 10 | Assigned | — | "≥50%" (all subjects — eligibility criterion) |
| 41 | STRAT2 | Stratum 2: Histology | Char | 20 | Derived | HISTSCAT | = `HISTSCAT` |
| 42 | STRAT3 | Stratum 3: Region | Char | 10 | Derived | REGION1 | = `REGION1` |

## Derivations

### D1 — AGEGR1 (pooled age group)

**Rule:** Categorical age grouping used for subgroup analyses per SAP.

**Pseudocode:**
```r
adsl <- adsl %>%
  mutate(
    AGEGR1 = case_when(
      AGE < 65            ~ "<65",
      AGE >= 65 & AGE < 75 ~ "65-<75",
      AGE >= 75           ~ ">=75",
      TRUE                ~ NA_character_
    ),
    AGEGR1N = case_when(
      AGEGR1 == "<65"    ~ 1,
      AGEGR1 == "65-<75" ~ 2,
      AGEGR1 == ">=75"   ~ 3
    )
  )
```

**Edge cases:** AGE is guaranteed non-missing in DM (eligibility). If absent, AGEGR1 = NA and QC flags the subject.

---

### D2 — RANDDT (randomisation date)

**Rule:** Date the subject was randomised to a treatment arm. Source is DS where `DSDECOD = "RANDOMIZED"`.

**Pseudocode:**
```r
rand_src <- ds %>%
  filter(DSDECOD == "RANDOMIZED") %>%
  transmute(USUBJID, RANDDT_dtc = DSSTDTC)

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = rand_src,
    by_vars     = exprs(USUBJID),
    new_vars    = exprs(RANDDT_dtc)
  ) %>%
  derive_vars_dt(new_vars_prefix = "RAND", dtc = RANDDT_dtc)
```

**Edge cases:** Every subject in this study is randomised (no screen failures in the synthetic data generator — see `data-raw/01_dm.R`). QC asserts RANDDT non-missing for all 450 rows.

---

### D3 — TRTSDT (first dose date)

**Rule:** Earliest `EXSTDTC` across all EX records for the subject.

**Pseudocode:**
```r
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex,
    filter_add  = EXDOSE > 0 & !is.na(EXSTDTC),
    by_vars     = exprs(USUBJID),
    new_vars    = exprs(TRTSDT_dtc = EXSTDTC),
    order       = exprs(EXSTDTC, EXSEQ),
    mode        = "first"
  ) %>%
  derive_vars_dt(new_vars_prefix = "TRTS", dtc = TRTSDT_dtc)
```

**Edge cases:**
- Subjects randomised but never dosed → TRTSDT = NA → SAFFL = "N".
- `EXDOSE > 0` filter excludes held/skipped cycles if recorded as 0-dose.

---

### D4 — TRTEDT (last dose date)

**Rule:** Latest `EXENDTC` (fall back to `EXSTDTC` if EXENDTC missing) across all EX records.

**Pseudocode:**
```r
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex %>% mutate(TRTEDT_dtc = coalesce(EXENDTC, EXSTDTC)),
    filter_add  = EXDOSE > 0 & !is.na(TRTEDT_dtc),
    by_vars     = exprs(USUBJID),
    new_vars    = exprs(TRTEDT_dtc),
    order       = exprs(TRTEDT_dtc, EXSEQ),
    mode        = "last"
  ) %>%
  derive_vars_dt(new_vars_prefix = "TRTE", dtc = TRTEDT_dtc)
```

---

### D5 — EOSSTT (end of study status)

**Rule:** One of `COMPLETED`, `DISCONTINUED`, `ONGOING`.

**Pseudocode:**
```r
eos_src <- ds %>%
  filter(DSCAT == "STUDY DISCONTINUATION" | DSDECOD == "COMPLETED") %>%
  group_by(USUBJID) %>%
  slice_max(order_by = DSSTDTC, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(USUBJID, EOSSTT_src = DSDECOD, EOSDT_dtc = DSSTDTC)

adsl <- adsl %>%
  derive_vars_merged(dataset_add = eos_src, by_vars = exprs(USUBJID)) %>%
  derive_vars_dt(new_vars_prefix = "EOS", dtc = EOSDT_dtc) %>%
  mutate(
    EOSSTT = case_when(
      EOSSTT_src == "COMPLETED" ~ "COMPLETED",
      !is.na(EOSSTT_src)        ~ "DISCONTINUED",
      TRUE                      ~ "ONGOING"
    )
  )
```

**Edge cases:** Subjects without a STUDY DISCONTINUATION or COMPLETED record by DCUTDT are `ONGOING`.

---

### D6 — PPROTFL (per-protocol flag)

**Rule:** Per-protocol population = ITT AND received ≥1 dose AND no major protocol deviations (`DS.DSDECOD = "PROTOCOL DEVIATION"` where `DSSCAT = "MAJOR"`).

**Pseudocode:**
```r
major_dev <- ds %>%
  filter(DSDECOD == "PROTOCOL DEVIATION" & DSSCAT == "MAJOR") %>%
  distinct(USUBJID) %>%
  mutate(MAJOR_DEV = "Y")

adsl <- adsl %>%
  derive_vars_merged(dataset_add = major_dev, by_vars = exprs(USUBJID)) %>%
  mutate(
    PPROTFL = case_when(
      ITTFL == "Y" & SAFFL == "Y" & is.na(MAJOR_DEV) ~ "Y",
      TRUE                                           ~ "N"
    )
  )
```

**Edge cases:** If the `DSSCAT = "MAJOR"` convention changes upstream in the SDTM generator, update D6 to match.

---

## Population Flags

| Flag | Definition | Expected N |
|---|---|---|
| RANDFL | Subject randomised (RANDDT not missing) | 450 |
| ITTFL | = RANDFL (all randomised) | 450 |
| SAFFL | Received ≥1 dose of study treatment | 450 (100% in synthetic data — all randomised subjects dosed; see `data-raw/02_ex.R`) |
| PPROTFL | ITT + SAFFL + no major protocol deviations | ≥405 (assumes ≤10% major deviations; actual value asserted at runtime) |
| EFFFL | = ITTFL (primary efficacy is ITT) | 450 |

## QC Checks

- [ ] `nrow(adsl) == 450`.
- [ ] `USUBJID` is unique across all rows.
- [ ] All flags ∈ {"Y", "N"}; no NAs.
- [ ] `TRTSDT >= RANDDT` for all SAFFL = "Y" rows.
- [ ] `TRTEDT >= TRTSDT` for all SAFFL = "Y" rows.
- [ ] `TRTDURD == as.numeric(TRTEDT - TRTSDT) + 1` for SAFFL = "Y" rows.
- [ ] `DTHFL == "Y"` iff `DTHDT` not missing.
- [ ] `EOSDT <= DCUTDT` for all non-ONGOING rows.
- [ ] `sum(ITTFL == "Y") == 450`, `sum(TRT01PN == 1) == 300`, `sum(TRT01PN == 2) == 150`.
- [ ] Variable labels, lengths, types match this spec via `xportr::xportr_length()` + `xportr::xportr_label()`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADSL-spec.md` → `adam/adsl.R` | `adam/adsl.R` → `adam/adsl.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Initial draft — spec-first, mapped to admiral 1.4.1. |
