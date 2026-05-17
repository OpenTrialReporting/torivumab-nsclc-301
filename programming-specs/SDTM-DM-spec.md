# DM — Demographics — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DM |
| **Label** | Demographics |
| **Class** | SPECIAL PURPOSE |
| **Structure** | One record per subject |
| **Expected N** | 450 |
| **Key variables** | `STUDYID`, `USUBJID` |
| **SDTMIG version** | v3.4 (§5.1) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DM holds one subject-level record per randomised subject and provides the demographic backbone, treatment arm assignment, and reference dates (informed consent, randomisation) that every downstream SDTM and ADaM dataset joins onto. ADSL inherits STUDYID/USUBJID/SUBJID/SITEID/AGE/SEX/RACE/ETHNIC/COUNTRY/ARM/ACTARM/RFICDTC verbatim from this domain; SUPPDM carries the non-standard subject-level qualifiers (ECOGBSL, PDL1SCR, PDL1GRP, HISTSCAT).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/demographics.csv` | CDASH DM form | One row per subject — birthdate, sex/race/ethnicity, country, informed consent date, randomisation date, treatment arm, screen-fail flag |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DM"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | SUBJID | Subject Identifier for the Study | Char | 8 | Derived | — | `sub(".*-", "", SUBJECT_ID)` — trailing 4-digit portion |
| 5 | SITEID | Study Site Identifier | Char | 8 | CRF | — | `as.character(SITE_ID)` |
| 6 | AGE | Age | Num | 8 | Derived | — | See §Derivations.D1 |
| 7 | AGEU | Age Units | Char | 10 | Assigned | AGEU (C66781) | Constant `"YEARS"` |
| 8 | SEX | Sex | Char | 8 | CRF | SEX (C66731) | `str_to_upper(str_trim(SEX))` |
| 9 | RACE | Race | Char | 80 | CRF | RACE (C74456) | `str_to_upper(str_trim(RACE))` |
| 10 | ETHNIC | Ethnicity | Char | 40 | CRF | ETHNIC (C66790) | `str_to_upper(str_trim(ETHNIC))` |
| 11 | COUNTRY | Country | Char | 3 | CRF | — | `str_to_upper(str_trim(COUNTRY))` (full country name, not ISO-3) |
| 12 | DMDTC | Date/Time of Collection | Char | 10 | CRF | — | `INFORM_CONSENT_DATE` (ISO 8601, direct) |
| 13 | RFSTDTC | Subject Reference Start Date/Time | Char | 10 | CRF | — | `RAND_DATE` (direct) |
| 14 | RFICDTC | Date/Time of Informed Consent | Char | 10 | CRF | — | `INFORM_CONSENT_DATE` (direct) |
| 15 | ARM | Description of Planned Arm | Char | 40 | CRF | ARM | See §Derivations.D2 |
| 16 | ACTARM | Description of Actual Arm | Char | 40 | CRF | ARM | Same as ARM (no cross-over) |
| 17 | ARMNRS | Reason Arm/Epoch Not Collected | Char | 40 | Derived | — | `"SCREEN FAILURE"` if `SCREEN_FAIL ∈ {Y,1,TRUE}`, else NA |

## Derivations

### D1 — AGE (integer years at informed consent)

```
birth_dt <- as.Date(BIRTHDATE)
ref_dt   <- as.Date(INFORM_CONSENT_DATE)
AGE      <- floor(as.numeric(ref_dt - birth_dt) / 365.25)   # integer years
```

Reference date is informed consent (NOT randomisation), per protocol §4. Both raw dates are ISO 8601 and guaranteed non-missing for in-scope subjects.

### D2 — ARM / ACTARM / ARMNRS (screen-failure handling)

```
ARM    <- TREATMENT_ARM
ACTARM <- TREATMENT_ARM
if SCREEN_FAIL in {"Y","1","TRUE"}:
   ARMNRS <- "SCREEN FAILURE"
   ARM    <- "SCREEN FAILURE"
   ACTARM <- "SCREEN FAILURE"
else:
   ARMNRS <- NA
```

In the current synthetic data generator (`programs/raw/01_demographics.R`), no subjects are SCREEN FAILURES — all 450 rows have a real arm. The branch is retained for spec completeness.

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §1 for the consolidated derivation table.

## Controlled Terminology

| SDTM variable | Codelist (NCI C-code) | Source |
|---|---|---|
| AGEU | C66781 | CDISC CT 2024-03 — fixed `"YEARS"` |
| SEX | C66731 | CDISC CT 2024-03 — values `M`, `F` (no `U`/`UNDIFFERENTIATED` in this study) |
| RACE | C74456 | CDISC CT 2024-03 |
| ETHNIC | C66790 | CDISC CT 2024-03 |
| ARM/ACTARM | Sponsor codelist | Values: `TORIVUMAB 1200 MG Q3W + CARBO/PEM`, `PLACEBO + CARBO/PEM`, `SCREEN FAILURE` |

## QC Checks

- [ ] `nrow(dm) == 450`
- [ ] `USUBJID` unique across all rows
- [ ] No duplicate `SUBJID` within a `SITEID`
- [ ] `AGE` numeric, non-missing, range `[18, 100]`
- [ ] `SEX ∈ {"M","F"}` — no missing
- [ ] `RFICDTC <= RFSTDTC` (consent precedes or equals randomisation) for all non-screen-failures
- [ ] `ARM == ACTARM` for all rows (no cross-over in this study)
- [ ] `ARMNRS` non-NA iff `ARM == "SCREEN FAILURE"` (currently 0 rows)
- [ ] `count(ARM)`: 300 TORIVUMAB arm, 150 PLACEBO arm (2:1 allocation)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-DM-spec.md` | `programs/sdtm/dm.R` | `datasets/sdtm/dm.parquet` |

Subject-level qualifiers (ECOGBSL, PDL1SCR, PDL1GRP, HISTSCAT) are split into `SUPPDM` per SDTMIG — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §16.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
