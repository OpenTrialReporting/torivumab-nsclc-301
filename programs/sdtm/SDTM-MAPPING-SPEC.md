# SDTM Mapping Specification — Raw → SDTM
## CTX-NSCLC-301 — SIMULATED-TORIVUMAB-2026

> **Purpose.** This document specifies, at the variable level, how each SDTM
> dataset in `datasets/sdtm/` is derived from the raw CSVs in `raw/`. It is
> written to support **independent double programming**: a second programmer
> should be able to reproduce every SDTM dataset by reading only this spec
> (plus the raw data + codelists) and ignoring the reference R code in
> `programs/sdtm/*.R`.
>
> **Standards.** SDTMIG v3.4 · CDISC CT 2024-03 · CDISC Oncology Disease
> Response Supplement (RECIST 1.1, 2023) · MedDRA v27.0 · CTCAE v5.0.
>
> **Conventions used in derivation columns:**
> - `STUDYID` constant: `"CTX-NSCLC-301"`
> - `USUBJID = paste(STUDYID, SUBJECT_ID, sep="-")` for all subject-level joins
> - Dates: ISO 8601 (`YYYY-MM-DD`); already in this format in raw CSVs
> - `--SEQ`: per-USUBJID row_number after the documented sort order
> - String normalisation: `str_trim(x)` then `str_to_upper(x)` unless noted
> - Reference R is in `programs/sdtm/<domain>.R` — see only for tie-breaking
>   ambiguity (the spec is authoritative).

---

## Inventory

| # | Domain  | Class | Source CSV(s) | Output | Records |
|---|---------|-------|---------------|--------|--------:|
| 1 | DM      | Special purpose | `demographics.csv` | `dm.parquet` | 450 |
| 2 | DS      | Events | `demographics.csv` + `disposition.csv` | `ds.parquet` | 1,350 |
| 3 | EX      | Interventions | `exposure.csv` | `ex.parquet` | 11,710 |
| 4 | DA      | Interventions | `drug_accountability.csv` | `da.parquet` | 28,108 |
| 5 | AE      | Events | `adverse_events.csv` + `codelists/meddra_oncology_subset.csv` | `ae.parquet` | 2,837 |
| 6 | CM      | Interventions | `conmed.csv` + `codelists/atc_conmed.csv` | `cm.parquet` | 2,222 |
| 7 | MH      | Events | `medical_history.csv` + MedDRA | `mh.parquet` | 2,051 |
| 8 | SU      | Interventions | `substance_use.csv` | `su.parquet` | 1,236 |
| 9 | LB      | Findings | `labs.csv` | `lb.parquet` | 115,394 |
| 10 | VS     | Findings | `vital_signs.csv` | `vs.parquet` | 46,095 |
| 11 | PE     | Findings | `physical_exam.csv` | `pe.parquet` | 22,662 |
| 12 | TU     | Findings | `tumor_measurements.csv` | `tu.parquet` | 7,686 |
| 13 | TR     | Findings | `tumor_measurements.csv` | `tr.parquet` | 7,724 |
| 14 | RS     | Findings | `overall_response.csv` | `rs.parquet` | 2,260 |
| 15 | DD     | Events | `death.csv` | `dd.parquet` | 284 |
| 16 | SUPPDM | Relationship | `demographics.csv` | `suppdm.parquet` | 1,799 |
| 17 | SUPPSU | Relationship | `substance_use.csv` | `suppsu.parquet` | 450 |
| 18 | SUPPAE | Relationship | `adverse_events.csv` + `ae.parquet` | `suppae.parquet` | 8,511 |
| 19 | SUPPCM | Relationship | `cm.parquet` | `suppcm.parquet` | 4,444 |
| 20 | SUPPLB | Relationship | `lb.parquet` | `supplb.parquet` | 230,788 |
| 21 | RELREC | Relationship | `tu.parquet` + `tr.parquet` + `rs.parquet` | `relrec.parquet` | 17,708 |
| 22 | DV     | Special purpose | `protocol_deviations.csv` | `dv.parquet` | 337 |

**Execution order** matters for SUPP* and RELREC (they depend on parent
SDTM parquets being written first). See `programs/sdtm/00_run_sdtm.R` for
the canonical sequence; the parent → SUPP/RELREC dependency is the only
hard constraint.

---

# 1. DM — Demographics

**Source:** `raw/demographics.csv`  · **Output:** `datasets/sdtm/dm.parquet`
**SDTMIG section:** 5.1  · **Class:** Special purpose  · **Structure:** One record per subject
**Keys:** STUDYID, USUBJID

| # | SDTM var | Label | Type/Length | Source | Derivation | Codelist / Notes |
|---|----------|-------|-------------|--------|------------|------------------|
| 1 | STUDYID  | Study Identifier | Char/20 | Constant | `"CTX-NSCLC-301"` | — |
| 2 | DOMAIN   | Domain Abbreviation | Char/2 | Constant | `"DM"` | — |
| 3 | USUBJID  | Unique Subject Identifier | Char/40 | Derived | `paste(STUDYID, SUBJECT_ID, sep="-")` | — |
| 4 | SUBJID   | Subject Identifier for the Study | Char/8 | Derived | `sub(".*-", "", SUBJECT_ID)` — keep trailing 4-digit portion (e.g. "SITE005-0001" → "0001") | — |
| 5 | SITEID   | Study Site Identifier | Char/8 | `SITE_ID` | Direct copy | — |
| 6 | AGE      | Age | Num | Derived | `floor(as.numeric(INFORM_CONSENT_DATE - BIRTHDATE) / 365.25)` (integer years at consent) | — |
| 7 | AGEU     | Age Units | Char/10 | Constant | `"YEARS"` | C66781 (AGEU) |
| 8 | SEX      | Sex | Char/8 | `SEX` | trim + upper | C66731 (SEX) |
| 9 | RACE     | Race | Char/80 | `RACE` | trim + upper | C74456 (RACE) |
| 10 | ETHNIC  | Ethnicity | Char/40 | `ETHNIC` | trim + upper | C66790 (ETHNIC) |
| 11 | COUNTRY | Country | Char/3 | `COUNTRY` | trim + upper (kept as full country name, not ISO-3) | — |
| 12 | DMDTC   | Date/Time of Collection | Char/10 | `INFORM_CONSENT_DATE` | ISO 8601, direct copy | — |
| 13 | RFSTDTC | Subject Reference Start Date/Time | Char/10 | `RAND_DATE` | Direct copy | — |
| 14 | RFICDTC | Date/Time of Informed Consent | Char/10 | `INFORM_CONSENT_DATE` | Direct copy | — |
| 15 | ARM     | Description of Planned Arm | Char/40 | `TREATMENT_ARM` | Direct; override to `"SCREEN FAILURE"` if `SCREEN_FAIL ∈ {Y,1,TRUE}` | — |
| 16 | ACTARM  | Description of Actual Arm | Char/40 | `TREATMENT_ARM` | Same as ARM (no cross-over in this study) | — |
| 17 | ARMNRS  | Reason Arm/Epoch Not Collected | Char/40 | Derived | `"SCREEN FAILURE"` if `SCREEN_FAIL ∈ {Y,1,TRUE}`, else `NA` | — |

**Sort:** `USUBJID`. **No `--SEQ`** (one record per subject by SDTM definition).

---

# 2. DS — Disposition

**Source:** `raw/demographics.csv` + `raw/disposition.csv`  · **Output:** `datasets/sdtm/ds.parquet`
**SDTMIG section:** 6.2  · **Class:** Events  · **Structure:** One record per disposition event per subject
**Keys:** STUDYID, USUBJID, DSSEQ

Three record types are stacked per subject:

### 2.1 Record set A — Informed consent (one per subject, from demographics)
| Variable | Value |
|---|---|
| DSTERM, DSDECOD | `"INFORMED CONSENT OBTAINED"` |
| DSCAT | `"PROTOCOL MILESTONE"` |
| DSSCAT | NA |
| DSSTDTC | `INFORM_CONSENT_DATE` |

### 2.2 Record set B — Randomisation (one per non-screen-failure subject)
| Variable | Value |
|---|---|
| Filter | `!(SCREEN_FAIL ∈ {Y,1,TRUE})` |
| DSTERM, DSDECOD | `"RANDOMIZED"` |
| DSCAT | `"PROTOCOL MILESTONE"` |
| DSSCAT | NA |
| DSSTDTC | `RAND_DATE` |

### 2.3 Record set C — Disposition event (one per subject, from disposition.csv)
| Variable | Value |
|---|---|
| `completed` (helper) | `str_to_upper(str_trim(COMPLETION_STATUS)) ∈ {COMPLETED, COMPLETE, Y, YES}` |
| DSTERM | `completed ? "COMPLETED" : str_to_upper(str_trim(DISC_REASON))` |
| DSDECOD | `completed ? "COMPLETED" : map_disc_decode(DISC_REASON)` — see lookup below |
| DSCAT | `"DISPOSITION EVENT"` |
| DSSCAT | `completed ? NA : "STUDY DISCONTINUATION"` |
| DSSTDTC | `completed ? STUDY_COMPLETION_DATE : DISC_DATE` |

**`map_disc_decode` lookup** (case-insensitive on raw DISC_REASON after trim+upper):

| Raw → DSDECOD |
|---|
| `ADVERSE EVENT`, `AE` → `"ADVERSE EVENT"` |
| `WITHDRAWAL BY SUBJECT`, `WITHDREW CONSENT` → `"WITHDRAWAL BY SUBJECT"` |
| `PHYSICIAN DECISION` → `"PHYSICIAN DECISION"` |
| `LOST TO FOLLOW-UP` → `"LOST TO FOLLOW-UP"` |
| `DEATH` → `"DEATH"` |
| `PROGRESSIVE DISEASE` → `"PROGRESSIVE DISEASE"` |
| `PROTOCOL DEVIATION`, `PROTOCOL VIOLATION` → `"PROTOCOL DEVIATION"` |
| `OTHER` → `"OTHER"` |
| unmatched → trim+upper raw value (passthrough) |

### 2.4 Output structure

| # | SDTM var | Type/Length | Notes |
|---|----------|-------------|-------|
| 1 | STUDYID  | Char/20 | Constant |
| 2 | DOMAIN   | Char/2  | `"DS"` |
| 3 | USUBJID  | Char/40 | — |
| 4 | DSSEQ    | Num     | Per-USUBJID row_number **after** sort by `(USUBJID, DSSTDTC)` |
| 5 | DSTERM   | Char/200 | per above |
| 6 | DSDECOD  | Char/200 | per above |
| 7 | DSCAT    | Char/40  | per above |
| 8 | DSSCAT   | Char/40  | per above |
| 9 | DSSTDTC  | Char/10  | per above |

**Sort:** `(USUBJID, DSSTDTC)`. Expected ~3 records/subject (IC + RAND + disposition event); ~1,350 total for 450 subjects.

---

# 3. EX — Exposure

**Source:** `raw/exposure.csv`  · **Output:** `datasets/sdtm/ex.parquet`
**SDTMIG section:** 6.3  · **Class:** Interventions  · **Structure:** One record per administration per subject
**Keys:** STUDYID, USUBJID, EXSEQ

### 3.1 VISIT derivation helper (used in EX, LB, VS, PE, TU, TR, RS)

```
derive_visit(cycle, day):
  if cycle == 1  AND day == 1    → "C1D1",  VISITNUM = 1
  if cycle == 1  AND day == 15   → "C1D15", VISITNUM = 2
  if cycle >= 2                  → paste0("C", cycle, "D", day),
                                    VISITNUM = cycle + 1
  else → NA
```

### 3.2 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"EX"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | EXSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, EXSTDTC, EXTRT)` |
| 5 | EXTRT    | Char/40 | `DRUG_NAME` | trim + upper |
| 6 | EXDOSE   | Num     | `DOSE_MG` | `as.numeric` |
| 7 | EXDOSU   | Char/10 | `DOSE_UNIT` | trim + upper |
| 8 | EXROUTE  | Char/40 | Constant | `"INTRAVENOUS"` |
| 9 | EXSTDTC  | Char/10 | `START_DATE` | direct |
| 10 | EXENDTC | Char/10 | `END_DATE` | direct |
| 11 | VISITNUM | Num    | Derived | per §3.1 from `CYCLE_NUMBER`, `DAY_IN_CYCLE` |
| 12 | VISIT    | Char/20 | Derived | per §3.1 |
| 13 | EPOCH    | Char/20 | Constant | `"TREATMENT"` (all EX records are on-treatment by definition) |

**Sort:** `(USUBJID, EXSTDTC, EXTRT)` before sequencing.

---

# 4. DA — Drug Accountability

**Source:** `raw/drug_accountability.csv` (CDASH DA form)  · **Output:** `datasets/sdtm/da.parquet`
**SDTMIG section:** 6.5  · **Class:** Interventions  · **Structure:** One record per accountability test per drug per visit per subject
**Keys:** STUDYID, USUBJID, DASEQ

### 4.1 Long-form derivation

Each raw row is pivoted into 2 to 4 SDTM records based on `DOSE_FORM`:

| DOSE_FORM | DATESTCD records emitted | DATEST |
|-----------|--------------------------|--------|
| `VIAL`    (TORIVUMAB, PLACEBO) | DISPAMT, USEDAMT, RETAMT, LOSTAMT | "Amount Dispensed", "Amount Used", "Amount Returned", "Amount Lost" |
| `COMPOUNDED` (CARBOPLATIN, PEMETREXED) | DISPAMT, USEDAMT only | (RETAMT/LOSTAMT skipped — compounded drugs have no return/loss) |

### 4.2 Variable derivations

| # | SDTM var | Type/Length | Derivation |
|---|----------|-------------|------------|
| 1 | STUDYID  | Char/20  | Constant |
| 2 | DOMAIN   | Char/2   | `"DA"` |
| 3 | USUBJID  | Char/40  | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DASEQ    | Num      | Per-USUBJID row_number after sort `(USUBJID, DASTDTC, EXTRT, DATESTCD)` |
| 5 | DATESTCD | Char/8   | `"DISPAMT"`, `"USEDAMT"`, `"RETAMT"`, `"LOSTAMT"` |
| 6 | DATEST   | Char/40  | "Amount Dispensed" / "Amount Used" / "Amount Returned" / "Amount Lost" |
| 7 | DACAT    | Char/40  | Constant `"DRUG ACCOUNTABILITY"` |
| 8 | DAORRES  | Char/20  | `as.character(round(value, 2))` where `value` ← the matching raw column (AMT_DISPENSED / AMT_USED / AMT_RETURNED / AMT_LOST) |
| 9 | DAORRESU | Char/10  | `AMT_UNIT` (raw) — `"VIAL"` for vialed drugs, else `MG` / `MG/M2` |
| 10 | DASTRESC | Char/20 | Same as DAORRES |
| 11 | DASTRESN | Num     | `as.numeric(value)` |
| 12 | DASTRESU | Char/10 | Same as DAORRESU |
| 13 | DASTDTC  | Char/10 | `VISIT_DATE` (raw) |
| 14 | VISIT    | Char/20 | `VISIT_NAME` (raw) |
| 15 | EXTRT    | Char/40 | trim + upper `DRUG_NAME` |

**Sort:** `(USUBJID, DASTDTC, EXTRT, DATESTCD)` before sequencing.

---

# 5. AE — Adverse Events

**Source:** `raw/adverse_events.csv` + `raw/codelists/meddra_oncology_subset.csv`
**Output:** `datasets/sdtm/ae.parquet`
**SDTMIG section:** 6.1  · **Class:** Events  · **Structure:** One record per AE per subject
**Keys:** STUDYID, USUBJID, AESEQ

### 5.1 MedDRA coding (verbatim AE_VERBATIM_TERM → LLT/PT/HLT/SOC)

```
code_ae(verbatim, meddra_lookup):
  terms_upper <- str_to_upper(str_trim(verbatim))
  exact_idx   <- match(terms_upper, meddra_lookup$LLT_NAME_UPPER)
  for i in unmatched(exact_idx):
    fuzzy <- agrep(terms_upper[i], meddra_lookup$LLT_NAME_UPPER,
                   ignore.case = TRUE, max.distance = 0.2)
    if length(fuzzy) > 0: exact_idx[i] <- fuzzy[1]
  RETURN per-row:
    AEDECOD  = matched_PT_NAME    OR  terms_upper (if unmatched)
    AEBODSYS = matched_SOC_NAME   OR  NA
    AEHLT    = matched_HLT_NAME   OR  NA
    AELLT    = matched_LLT_NAME   OR  verbatim_term (preserved)
    IRAEFL   = matched_IRAEFL == "Y"  → "Y", else "N"
```

### 5.2 Helper mappers (all case-insensitive on trim+upper)

| Raw value | AESEV | AESER | AEREL | AEACN | AEOUT | AETOXGR |
|---|---|---|---|---|---|---|
| `MILD`, `1`, `GRADE 1` | MILD | — | — | — | — | 1 |
| `MODERATE`, `2`, `GRADE 2` | MODERATE | — | — | — | — | 2 |
| `SEVERE`, `3`, `GRADE 3` | SEVERE | — | — | — | — | 3 |
| `LIFE-THREATENING`, `4`, `GRADE 4` | LIFE-THREATENING | — | — | — | — | 4 |
| `FATAL`, `5`, `GRADE 5` | FATAL | — | — | — | — | 5 |
| `Y`, `YES`, `TRUE`, `1` | — | Y | — | — | — | — |
| `N`, `NO`, `FALSE`, `0` | — | N | — | — | — | — |
| `Y/YES/TRUE/RELATED/POSSIBLY RELATED/PROBABLY RELATED/DEFINITELY RELATED` | — | — | Y | — | — | — |
| `N/NO/FALSE/NOT RELATED/UNRELATED` | — | — | N | — | — | — |
| Contains `DOSE REDUC` | — | — | — | DOSE REDUCED | — | — |
| Contains `DOSE INTERR` or `DOSE INTERRUPTED` | — | — | — | DRUG INTERRUPTED | — | — |
| Contains `DISC` | — | — | — | DRUG WITHDRAWN | — | — |
| Contains `NONE` or `NOT` | — | — | — | NONE | — | — |
| Contains `RECOVER` or `RESOLV` | — | — | — | — | RECOVERED/RESOLVED | — |
| Contains `ONGOING` | — | — | — | — | NOT RECOVERED/NOT RESOLVED | — |
| Contains `SEQUELA` | — | — | — | — | RECOVERED/RESOLVED WITH SEQUELAE | — |
| Contains `FATAL` or `DEATH` | — | — | — | — | FATAL | — |

### 5.3 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20  | Constant | — |
| 2 | DOMAIN   | Char/2   | Constant | `"AE"` |
| 3 | USUBJID  | Char/40  | Derived | — |
| 4 | AESEQ    | Num      | Derived | Per-USUBJID row_number after sort `(USUBJID, AESTDTC)` |
| 5 | AETERM   | Char/200 | `AE_VERBATIM_TERM` | trim |
| 6 | AEDECOD  | Char/200 | MedDRA lookup | per §5.1 |
| 7 | AEBODSYS | Char/200 | MedDRA lookup | per §5.1 (SOC_NAME) |
| 8 | AESOC    | Char/200 | Derived | Same as AEBODSYS |
| 9 | AEHLT    | Char/200 | MedDRA lookup | per §5.1 |
| 10 | AELLT   | Char/200 | MedDRA lookup | per §5.1 |
| 11 | AESTDTC | Char/10  | `AE_START_DATE` | direct |
| 12 | AEENDTC | Char/10  | `AE_END_DATE`   | direct |
| 13 | AESEV   | Char/20  | `SEVERITY` | per §5.2 |
| 14 | AETOXGR | Char/1   | Derived | Map AESEV per §5.2 |
| 15 | AESER   | Char/1   | `SERIOUS` | per §5.2 |
| 16 | AEREL   | Char/1   | `RELATED_TO_STUDY_DRUG` | per §5.2 |
| 17 | AEACN   | Char/40  | `ACTION_TAKEN` | per §5.2 |
| 18 | AEOUT   | Char/40  | `OUTCOME` | per §5.2 |
| 19 | AECAT   | Char/40  | Derived | `IRAEFL == "Y"` → `"IMMUNE-RELATED"`, else raw `AECAT` (trim+upper) if present, else NA |
| 20 | AESDTH  | Char/1   | Derived | `"Y"` if `OUTCOME ∈ {FATAL, DEATH}`, else `"N"` |
| 21 | AESHOSP | Char/1   | NA | not collected |
| 22 | AESLIFE | Char/1   | NA | not collected |
| 23 | AESDISAB| Char/1   | NA | not collected |
| 24 | AESMIE  | Char/1   | NA | not collected |
| 25 | AESCONG | Char/1   | NA | not collected |
| 26 | AEDISCOD| Char/1   | `LEADING_TO_DISCONTINUATION` | `"Y"` if `∈ {Y, YES, TRUE, 1}`, else `"N"` |

**Sort:** `(USUBJID, AESTDTC)` before sequencing.

---

# 6. CM — Concomitant Medications

**Source:** `raw/conmed.csv` + `raw/codelists/atc_conmed.csv`
**Output:** `datasets/sdtm/cm.parquet`
**SDTMIG section:** 6.2  · **Class:** Interventions  · **Structure:** One record per medication occurrence per subject
**Keys:** STUDYID, USUBJID, CMSEQ

### 6.1 ATC coding (DRUG_NAME_VERBATIM → standardised name + ATC code)

ATC lookup CSV has columns: `ATC_CODE, ATC_NAME, DRUG_NAME, DRUG_NAME_VERBATIM_1, DRUG_NAME_VERBATIM_2, INDICATION_CLASS, INDICATION`.

```
match_atc(verbatim):
  v_up <- str_to_upper(str_trim(verbatim))
  idx  <- which(atc.V1_UPPER == v_up OR atc.V2_UPPER == v_up)
  if length(idx) == 0:
    fuzzy_v1 <- agrep(v_up, atc.V1_UPPER, ignore.case=TRUE, max.distance=0.2)
    fuzzy_v2 <- agrep(v_up, atc.V2_UPPER, ignore.case=TRUE, max.distance=0.2)
    idx <- unique(c(fuzzy_v1, fuzzy_v2))
  if length(idx) > 0:
    CMDECOD <- atc.DRUG_NAME[idx[1]]
    CMATC   <- atc.ATC_CODE[idx[1]]
    CMINDC  <- atc.INDICATION[idx[1]]
  else:
    CMDECOD <- v_up;  CMATC <- NA;  CMINDC <- NA
```

### 6.2 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"CM"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | CMSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, CMSTDTC, CMTRT)` |
| 5 | CMTRT    | Char/200| `DRUG_NAME_VERBATIM` | trim |
| 6 | CMDECOD  | Char/200| ATC lookup | per §6.1 |
| 7 | CMATC    | Char/8  | ATC lookup | per §6.1. **Note:** non-standard SDTM var carried on parent for back-compat; the SDTM-compliant home is `SUPPCM.QNAM = "CMATC"` (see §19) |
| 8 | CMINDC   | Char/200| ATC lookup or raw | `ATC.INDICATION` if matched, else `str_to_upper(str_trim(raw.INDICATION))` |
| 9 | CMROUTE  | Char/20 | Constant | `"ORAL"` (assumption — raw does not carry route) |
| 10 | CMSTDTC | Char/10 | `START_DATE` | direct |
| 11 | CMENDTC | Char/10 | `END_DATE`   | direct |
| 12 | CMENRTPT| Char/20 | Derived | `"ONGOING"` if `ONGOING ∈ {Y,YES,TRUE,1}` OR `END_DATE` missing, else `"BEFORE"` |
| 13 | CMCAT   | Char/40 | Constant | `"CONCOMITANT MEDICATION"` |

**Sort:** `(USUBJID, CMSTDTC, CMTRT)` before sequencing.

---

# 7. MH — Medical History

**Source:** `raw/medical_history.csv`  · **Output:** `datasets/sdtm/mh.parquet`
**SDTMIG section:** 6.4  · **Class:** Events  · **Structure:** One record per medical history condition per subject
**Keys:** STUDYID, USUBJID, MHSEQ

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"MH"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | MHSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, MHSTDTC)` |
| 5 | MHTERM   | Char/200| `CONDITION_VERBATIM` | trim |
| 6 | MHDECOD  | Char/200| Derived | `str_to_title(str_trim(CONDITION_VERBATIM))` — simplified coding; real implementations should MedDRA-code |
| 7 | MHCAT    | Char/40 | Derived | `"PRIMARY DIAGNOSIS"` if `PREEXISTING ∈ {Y,YES,TRUE,1}` AND verbatim matches `CANCER\|CARCINOMA\|TUMOU?R\|MALIGNANCY\|NSCLC\|SCLC\|MELANOMA\|LYMPHOMA`; else `"MEDICAL HISTORY"` |
| 8 | MHSTDTC  | Char/10 | `ONSET_DATE` | direct |
| 9 | MHENRTPT | Char/20 | Derived | `"ONGOING"` if `STATUS ∈ {ONGOING,ACTIVE,CURRENT}`; `"BEFORE"` if `STATUS ∈ {RESOLVED,INACTIVE,PAST,N}`; else NA |
| 10 | MHPRESP | Char/1  | Constant | `"Y"` (all conditions are pre-specified by collection) |
| 11 | MHOCCUR | Char/1  | Constant | `"Y"` (only present conditions are captured) |

**Sort:** `(USUBJID, MHSTDTC)` before sequencing.

---

# 8. SU — Substance Use

**Source:** `raw/substance_use.csv`  · **Output:** `datasets/sdtm/su.parquet`
**SDTMIG section:** 6 (Substance Use)  · **Class:** Interventions  · **Structure:** One record per substance per subject
**Keys:** STUDYID, USUBJID, SUSEQ

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"SU"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | SUSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, SUCAT)` |
| 5 | SUTRT    | Char/40 | `SUBSTANCE` | trim + upper |
| 6 | SUOCCUR  | Char/1  | Derived | `"Y"` if `USE_STATUS ∈ {CURRENT,EVER,YES,Y,FORMER,PAST}`; `"N"` if `∈ {NEVER,NO,N}`; else NA |
| 7 | SUCAT    | Char/40 | `SUBSTANCE` | trim + upper |
| 8 | SUSCAT   | Char/40 | `USE_STATUS` | trim + upper |
| 9 | SUSTDTC  | Char/10 | NA (not collected) | — |
| 10 | SUPACKYRS | Num   | `PACK_YEARS` | `as.numeric` (non-standard var; only meaningful for tobacco) |
| 11 | SUFREQ  | Char/40 | `FREQUENCY` | trim + upper |

**Sort:** `(USUBJID, SUCAT)` before sequencing.

---

# 9. DD — Death Details

**Source:** `raw/death.csv`  · **Output:** `datasets/sdtm/dd.parquet`
**SDTMIG section:** Oncology Death Details supplement  · **Class:** Events  · **Structure:** One record per death per subject
**Keys:** STUDYID, USUBJID, DDSEQ

Only subjects who died appear here. There is exactly one DD record per deceased subject (DDSEQ = 1).

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"DD"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | DDSEQ    | Num     | Constant | `1` (one DD record per subject) |
| 5 | DDTESTCD | Char/8  | Constant | `"DEATH"` |
| 6 | DDTEST   | Char/40 | Constant | `"Death"` |
| 7 | DDORRES  | Char/1  | Constant | `"Y"` |
| 8 | DDSTRESC | Char/1  | Constant | `"Y"` |
| 9 | DDDTC    | Char/10 | `DEATH_DATE` | direct |
| 10 | DDCAT   | Char/40 | Constant | `"PRIMARY CAUSE OF DEATH"` |
| 11 | DDTERM  | Char/200| `PRIMARY_CAUSE` | trim + upper |
| 12 | DDSCAT  | Char/200| Derived | `str_to_upper(str_trim(CAUSE_DETAIL))` if non-empty, else NA |

**Sort:** `USUBJID`.

---

## Shared VISIT lookup (used by LB, VS, PE, TU, TR, RS)

```
visit_map = {
  "SCREENING": 0, "SCR": 0,
  "C1D1": 1, "C1D15": 2, "C2D1": 3, "C3D1": 4, "C4D1": 5,
  "C5D1": 6, "C6D1": 7, "C7D1": 8, "C8D1": 9,
  "EOT": 99, "END OF TREATMENT": 99,
  "FU1": 100, "FU2": 101, "FOLLOW-UP 1": 100, "FOLLOW-UP 2": 101
}
get_visitnum(visit_name): visit_map[str_to_upper(str_trim(visit_name))]
                          → NA if not in map
```

---

# 10. LB — Laboratory Test Results

**Source:** `raw/labs.csv`  · **Output:** `datasets/sdtm/lb.parquet`
**SDTMIG section:** 7.2.1  · **Class:** Findings  · **Structure:** One record per lab test per visit per subject
**Keys:** STUDYID, USUBJID, LBSEQ

Haematology test codes: `HGB, NEUT, PLAT, WBC, LYMPH, RBC, HCT, MCH, MCHC, MCV` → `LBCAT = "HAEMATOLOGY"`; all others → `LBCAT = "CHEMISTRY"`.

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"LB"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | LBSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, LBDTC, LBTESTCD)` |
| 5 | LBTESTCD | Char/8  | `TEST_CODE` | trim + upper |
| 6 | LBTEST   | Char/40 | `TEST_NAME` | trim |
| 7 | LBCAT    | Char/40 | Derived | `"HAEMATOLOGY"` if `LBTESTCD ∈ haem_codes` (above), else `"CHEMISTRY"` |
| 8 | LBORRES  | Char/40 | `RESULT_VALUE` | `as.character` |
| 9 | LBORRESU | Char/40 | `RESULT_UNIT` | trim |
| 10 | LBSTRESC| Char/40 | `RESULT_VALUE` | `as.character` |
| 11 | LBSTRESN| Num     | `RESULT_VALUE` | `suppressWarnings(as.numeric)` |
| 12 | LBSTRESU| Char/40 | `RESULT_UNIT` | trim (assumed SI; no unit conversion here) |
| 13 | LBSTNRLO| Num     | `LOWER_NORMAL` | `as.numeric` |
| 14 | LBSTNRHI| Num     | `UPPER_NORMAL` | `as.numeric` |
| 15 | LBNRIND | Char/10 | Derived | `"HIGH"` if `ABNORMAL_FLAG ∈ {H,HIGH}`; `"LOW"` if `∈ {L,LOW}`; `"NORMAL"` if `∈ {N,NORMAL,""}`; else range-based: `LBSTRESN > LBSTNRHI` → HIGH; `LBSTRESN < LBSTNRLO` → LOW; non-missing → NORMAL; else NA |
| 16 | LBDTC   | Char/10 | `VISIT_DATE` | direct |
| 17 | VISITNUM| Num     | Derived | per VISIT lookup |
| 18 | VISIT   | Char/40 | `VISIT_NAME` | trim + upper |
| 19 | LBBLFL  | Char/1  | Derived | `"Y"` if `VISITNUM == 0` OR `VISIT ∈ {SCREENING, SCR}`, else NA |

**Sort:** `(USUBJID, LBDTC, LBTESTCD)` before sequencing.

---

# 11. VS — Vital Signs

**Source:** `raw/vital_signs.csv`  · **Output:** `datasets/sdtm/vs.parquet`
**SDTMIG section:** 7.2  · **Class:** Findings  · **Structure:** One record per vital sign per visit per subject
**Keys:** STUDYID, USUBJID, VSSEQ

### 11.1 Vital sign parameter metadata (pivot map)

| Raw column | VSTESTCD | VSTEST | VSORRESU = VSSTRESU |
|---|---|---|---|
| SYSTOLIC_BP | SYSBP | Systolic Blood Pressure | mmHg |
| DIASTOLIC_BP | DIABP | Diastolic Blood Pressure | mmHg |
| HEART_RATE  | HR    | Heart Rate              | beats/min |
| WEIGHT_KG   | WEIGHT| Weight                   | kg |
| HEIGHT_CM   | HEIGHT| Height                   | cm |
| TEMPERATURE_C | TEMP| Temperature              | C |
| RESP_RATE   | RESP  | Respiratory Rate         | breaths/min |

### 11.2 Pivot logic

```
1. Pivot raw wide → long: one row per (USUBJID, VISIT_NAME, VISIT_DATE, raw_param)
2. Drop rows where raw value is NA or empty string
3. Look up VSTESTCD/VSTEST/VSORRESU/VSSTRESU from the metadata above
4. Apply variable derivations below
```

### 11.3 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"VS"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | VSSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, VSDTC, VSTESTCD)` |
| 5 | VSTESTCD | Char/8  | per §11.1 | — |
| 6 | VSTEST   | Char/40 | per §11.1 | — |
| 7 | VSORRES  | Char/40 | `raw_value` | `as.character` |
| 8 | VSORRESU | Char/20 | per §11.1 | — |
| 9 | VSSTRESC | Char/40 | `raw_value` | `as.character` |
| 10 | VSSTRESN | Num    | `raw_value` | `suppressWarnings(as.numeric)` |
| 11 | VSSTRESU | Char/20 | per §11.1 | — |
| 12 | VSDTC    | Char/10 | `VISIT_DATE` | direct |
| 13 | VISITNUM | Num    | Derived | per VISIT lookup |
| 14 | VISIT    | Char/40 | `VISIT_NAME` | trim + upper |

**Sort:** `(USUBJID, VSDTC, VSTESTCD)` before sequencing.

---

# 12. PE — Physical Examination

**Source:** `raw/physical_exam.csv`  · **Output:** `datasets/sdtm/pe.parquet`
**SDTMIG section:** 7.3  · **Class:** Findings  · **Structure:** One record per body system per visit per subject
**Keys:** STUDYID, USUBJID, PESEQ

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"PE"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | PESEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, PEDTC, PETESTCD)` |
| 5 | PETESTCD | Char/8  | Derived | `str_sub(str_to_upper(str_replace_all(trim(BODY_SYSTEM), "[^A-Z0-9]", "")), 1, 8)` |
| 6 | PETEST   | Char/40 | `BODY_SYSTEM` | trim + upper |
| 7 | PEORRES  | Char/200| Derived | `paste(trim(FINDING), if FINDING_DETAIL not blank: paste0(" - ", trim(FINDING_DETAIL)))` |
| 8 | PENORM   | Char/1  | Derived | `"Y"` if `FINDING ∈ {NORMAL, WITHIN NORMAL LIMITS, WNL, NO ABNORMALITY DETECTED, NAD, UNREMARKABLE}` (trim+upper); else NA |
| 9 | PECLSIG  | Char/1  | Derived | `"Y"` if FINDING contains `"CLINICALLY SIGNIFICANT"`; `"N"` if `PENORM == "Y"`; else NA |
| 10 | PEDTC   | Char/10 | `VISIT_DATE` | direct |
| 11 | VISITNUM| Num     | Derived | per VISIT lookup |
| 12 | VISIT   | Char/40 | `VISIT_NAME` | trim + upper |

**Sort:** `(USUBJID, PEDTC, PETESTCD)` before sequencing.

---

# 13. TU — Tumor Identification

**Source:** `raw/tumor_measurements.csv`  · **Output:** `datasets/sdtm/tu.parquet`
**SDTMIG section:** Oncology Disease Response Supplement §9.1  · **Class:** Findings  · **Structure:** One record per identified lesion per visit per subject
**Keys:** STUDYID, USUBJID, TUSEQ

Each raw row generates a TU record (TU captures lesion *identification*, not measurements).

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"TU"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | TUSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, TUDTC, TULINKID)` |
| 5 | TUTESTCD | Char/8  | Constant | `"TUMIDENT"` |
| 6 | TUTEST   | Char/40 | Constant | `"Tumor Identification"` |
| 7 | TUORRES  | Char/200| Derived | `paste(trim(LESION_TYPE), trim(ANATOMICAL_LOCATION), sep=" - ")` |
| 8 | TULOC    | Char/200| `ANATOMICAL_LOCATION` | trim + upper |
| 9 | TUMETHOD | Char/40 | Constant | `"CT SCAN"` (raw does not carry method) |
| 10 | TUDTC   | Char/10 | `ASSESSMENT_DATE` | direct |
| 11 | VISITNUM| Num     | Derived | per VISIT lookup |
| 12 | VISIT   | Char/40 | `VISIT_NAME` | trim + upper |
| 13 | TUGRPID | Char/40 | Derived | `"TARGET"` if `LESION_TYPE ∈ {TARGET, TGT}`; `"NON-TARGET"` if `∈ {NON-TARGET, NONTARGET, NT}`; else trim+upper raw |
| 14 | TULINKID| Char/40 | `LESION_ID` | `as.character` (e.g., "TARGET_1", "NEW_1") |

**Sort:** `(USUBJID, TUDTC, TULINKID)` before sequencing.

---

# 14. TR — Tumor Results

**Source:** `raw/tumor_measurements.csv`  · **Output:** `datasets/sdtm/tr.parquet`
**SDTMIG section:** Oncology Disease Response Supplement §9.2  · **Class:** Findings  · **Structure:** One record per measurement per lesion per visit per subject
**Keys:** STUDYID, USUBJID, TRSEQ

Each raw row may produce 0, 1, or 2 TR records depending on which fields are populated. Three TRTESTCD types are emitted (logically OR'd):

### 14.1 TR record sets

| Set | Filter on raw row | TRTESTCD | TRTEST | TRORRES / TRSTRESC | TRSTRESN | TRSTRESU |
|---|---|---|---|---|---|---|
| **Target lesion measurement** | `TRGRPID == "TARGET"` AND `LONGEST_DIAMETER_MM` not NA | LDIAM | "Longest Diameter" | `as.character(LONGEST_DIAMETER_MM)` | `as.numeric(LONGEST_DIAMETER_MM)` | "mm" |
| **Non-target response** | `TRGRPID == "NON-TARGET"` AND `RESPONSE_CATEGORY` not NA/blank | OVRLRESP | "Overall Response" | trim+upper RESPONSE_CATEGORY | NA | NA |
| **New lesion flag** | `NEW_LESION ∈ {Y,YES,TRUE,1}` | NEWLSN | "New Lesion" | "Y" | NA | NA |

**Note:** `TRGRPID` derivation is identical to TU: `"TARGET"` / `"NON-TARGET"` / passthrough.
**Note:** `TRLINKID = as.character(LESION_ID)` (matches TULINKID for join).

### 14.2 Variable derivations

| # | SDTM var | Type/Length | Notes |
|---|----------|-------------|-------|
| 1 | STUDYID | Char/20 | Constant |
| 2 | DOMAIN  | Char/2  | `"TR"` |
| 3 | USUBJID | Char/40 | — |
| 4 | TRSEQ   | Num     | Per-USUBJID row_number after sort `(USUBJID, TRDTC, TRLINKID, TRTESTCD)` |
| 5 | TRTESTCD| Char/8  | per §14.1 |
| 6 | TRTEST  | Char/40 | per §14.1 |
| 7 | TRORRES | Char/40 | per §14.1 |
| 8 | TRSTRESC| Char/40 | per §14.1 |
| 9 | TRSTRESN| Num     | per §14.1 |
| 10 | TRSTRESU| Char/20 | per §14.1 |
| 11 | TRDTC  | Char/10 | `ASSESSMENT_DATE` direct |
| 12 | VISITNUM| Num    | per VISIT lookup |
| 13 | VISIT  | Char/40 | trim + upper |
| 14 | TRGRPID| Char/40 | per §14.1 |
| 15 | TRLINKID| Char/40| `as.character(LESION_ID)` |

**Sort:** `(USUBJID, TRDTC, TRLINKID, TRTESTCD)` before sequencing.

---

# 15. RS — Disease Response

**Source:** `raw/overall_response.csv`  · **Output:** `datasets/sdtm/rs.parquet`
**SDTMIG section:** Oncology Disease Response Supplement §9.3  · **Class:** Findings  · **Structure:** One overall-response record per assessment per subject
**Keys:** STUDYID, USUBJID, RSSEQ

### 15.1 Response numeric encoding (RSSTRESN)

| RSSTRESC (trim+upper) | RSSTRESN |
|---|---|
| CR, COMPLETE RESPONSE, COMPLETE REMISSION | 1 |
| PR, PARTIAL RESPONSE | 2 |
| SD, STABLE DISEASE | 3 |
| PD, PROGRESSIVE DISEASE | 4 |
| NE, NOT EVALUABLE, NED | 5 |
| (other) | NA |

### 15.2 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"RS"` |
| 3 | USUBJID  | Char/40 | Derived | — |
| 4 | RSSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, RSDTC)` |
| 5 | RSTESTCD | Char/8  | Constant | `"OVRLRESP"` |
| 6 | RSTEST   | Char/40 | Constant | `"Overall Response"` |
| 7 | RSCAT    | Char/40 | Constant | `"OVERALL RESPONSE"` |
| 8 | RSEVAL   | Char/40 | Constant | `"INVESTIGATOR"` (BICR not simulated in this study) |
| 9 | RSORRES  | Char/40 | `INVESTIGATOR_RESPONSE` | trim + upper |
| 10 | RSSTRESC| Char/40 | `INVESTIGATOR_RESPONSE` | trim + upper |
| 11 | RSSTRESN| Num     | Derived | per §15.1 |
| 12 | RSDTC   | Char/10 | `ASSESSMENT_DATE` | direct |
| 13 | VISITNUM| Num     | Derived | per VISIT lookup |
| 14 | VISIT   | Char/40 | `VISIT_NAME` | trim + upper |

**Sort:** `(USUBJID, RSDTC)` before sequencing.

---

## Shared SUPP-- variable shape (used by SUPPDM, SUPPSU, SUPPAE, SUPPCM, SUPPLB)

All SUPP datasets follow the same 10-column structure:

| # | Var | Type/Length | Notes |
|---|-----|-------------|-------|
| 1 | STUDYID  | Char/20 | Constant |
| 2 | RDOMAIN  | Char/2  | Parent domain abbreviation (DM, SU, AE, CM, LB) |
| 3 | USUBJID  | Char/40 | Foreign key to parent |
| 4 | IDVAR    | Char/8  | Name of identifying variable in parent (e.g. AESEQ, CMSEQ, LBSEQ); empty string for subject-level (DM) |
| 5 | IDVARVAL | Char/40 | Value of `IDVAR` for the parent row being qualified |
| 6 | QNAM     | Char/8  | Name of supplemental variable |
| 7 | QLABEL   | Char/40 | Human label for QNAM |
| 8 | QVAL     | Char/200| Data value (always char) |
| 9 | QORIG    | Char/20 | Origin: `"CRF"`, `"DERIVED"`, `"ASSIGNED"` |
| 10 | QEVAL   | Char/20 | Evaluator (typically blank for synthetic data) |

Only **QNAM, QLABEL, QVAL, QORIG, IDVAR, IDVARVAL** vary by domain; the rest follow the structure above.

---

# 16. SUPPDM — Supplemental Qualifiers for DM

**Source:** `raw/demographics.csv`  · **Output:** `datasets/sdtm/suppdm.parquet`
**SDTMIG section:** 8.4  · **Class:** Relationship  · **Structure:** One record per subject per QNAM
**Keys:** STUDYID, RDOMAIN, USUBJID, QNAM

Subject-level supplemental qualifiers (IDVAR / IDVARVAL = empty string).

### 16.1 QNAM definitions

| QNAM | QLABEL | Source column | QORIG |
|---|---|---|---|
| ECOGBSL  | ECOG Performance Status at Baseline | `ECOG_BASELINE` | CRF |
| PDL1SCR  | PD-L1 TPS Score                     | `PDL1_SCORE`    | CRF |
| PDL1GRP  | PD-L1 TPS Group                     | `PDL1_GROUP`    | CRF |
| HISTSCAT | Tumour Histology Stratum            | `HISTOLOGY`     | CRF |

### 16.2 Derivation logic (per QNAM, looping over the 4 entries above)

```
for each (qnam, qlabel, source_col, qorig) in QNAM_definitions:
  for each raw row where source_col is non-NA AND non-blank:
    EMIT SUPPDM row:
      STUDYID  = "CTX-NSCLC-301"
      RDOMAIN  = "DM"
      USUBJID  = paste(STUDYID, SUBJECT_ID, sep="-")
      IDVAR    = ""           # subject-level (no parent record index)
      IDVARVAL = ""
      QNAM     = qnam
      QLABEL   = qlabel
      QVAL     = as.character(source_value)
      QORIG    = qorig
      QEVAL    = ""
```

**Sort:** `(USUBJID, QNAM)`.

---

# 17. SUPPSU — Supplemental Qualifiers for SU

**Source:** `raw/substance_use.csv` (legacy)  · **Output:** `datasets/sdtm/suppsu.parquet`
**SDTMIG section:** 8.4

> ⚠️ **Open item.** The currently-committed `suppsu.parquet` was produced by
> a legacy script (note `STUDYID = "TORIVUMAB-NSCLC-301"`, not the current
> `"CTX-NSCLC-301"`) that does not exist in `programs/sdtm/`. The
> `00_run_sdtm.R` orchestrator therefore does not regenerate it. The
> committed parquet should be treated as observed truth until a successor
> script is written. The schema below documents the existing file so a
> double-programming spec can be written; a new generator should match.

**Observed structure:** One record per subject per QNAM.

| QNAM | QLABEL | Source | Notes |
|---|---|---|---|
| SMKSTAT | Smoking Status | `USE_STATUS` (when SUBSTANCE = "TOBACCO") | Values observed: `EX-SMOKER`, `CURRENT SMOKER`, `NEVER SMOKED`. QORIG = `"CRF"`. |

**Derivation per the legacy file:**
```
filter raw where SUBSTANCE = "TOBACCO" (or equivalent)
emit one row per subject:
  RDOMAIN  = "SU"
  IDVAR    = "SUSEQ"
  IDVARVAL = SUSEQ from parent SU record
  QNAM     = "SMKSTAT"
  QVAL     = as.character(USE_STATUS) mapped to {EX-SMOKER, CURRENT SMOKER, NEVER SMOKED}
  QORIG    = "CRF"
```

**Recommended action (out of scope for this spec):** Add `programs/sdtm/suppsu.R` so future pipeline runs regenerate it consistently with the current STUDYID.

---

# 18. SUPPAE — Supplemental Qualifiers for AE

**Source:** `datasets/sdtm/ae.parquet` + `raw/adverse_events.csv`  · **Output:** `datasets/sdtm/suppae.parquet`
**SDTMIG section:** 8.4
**Keys:** STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, QNAM

### 18.1 AESEQ re-derivation

The same per-USUBJID `row_number()` after sorting raw by `(USUBJID, AE_START_DATE)` that produces parent `AE.AESEQ`. This MUST match parent AE exactly — see AE spec §5.

### 18.2 QNAM definitions

| QNAM | QLABEL | Derivation | QORIG |
|---|---|---|---|
| IRAEFL  | Immune-Related AE Flag                | `"Y"` if `raw.AECAT` (trim+upper) == `"IMMUNE-RELATED"`; else `"N"` | DERIVED |
| AEDISFL | AE Led to Study Drug Discontinuation  | `"Y"` if `LEADING_TO_DISCONTINUATION ∈ {Y,YES,TRUE,1}`; else `"N"` | DERIVED |
| AEACTFL | Dose Modified Due to AE               | `"Y"` if `ACTION_TAKEN` (trim+upper) `∈ {DOSE REDUCED, DOSE INTERRUPTED, DRUG INTERRUPTED, DRUG WITHDRAWN, DOSE REDUCTION}`; else `"N"` | DERIVED |

### 18.3 Emission

```
for each raw AE row (in sorted order with row-number AESEQ):
  for each (qnam, qlabel) in QNAM_definitions:
    EMIT one SUPPAE row:
      RDOMAIN  = "AE"
      IDVAR    = "AESEQ"
      IDVARVAL = as.character(AESEQ)
      QVAL     = derived value (must be non-NA, non-empty)
      QORIG    = "DERIVED"
      QEVAL    = ""
```

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

---

# 19. SUPPCM — Supplemental Qualifiers for CM

**Source:** `datasets/sdtm/cm.parquet`  · **Output:** `datasets/sdtm/suppcm.parquet`
**SDTMIG section:** 8.4
**Keys:** STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, QNAM

### 19.1 QNAM definitions

| QNAM | QLABEL | Derivation | QORIG |
|---|---|---|---|
| CMATC    | WHO ATC Classification Code     | Pass through from parent CM.CMATC (which carries the inlined ATC code per §6.1) | ASSIGNED |
| CMIRAEFL | Prescribed for irAE Management  | `"Y"` if `CMATC` starts with `"H02AB"` (corticosteroids: prednisolone, methylprednisolone, dexamethasone, hydrocortisone) AND `CMINDC` (uppercased) matches regex `IMMUNE\|IRAE\|COLITIS\|PNEUMONITIS\|HEPATITIS\|THYROIDITIS`; else `"N"` | DERIVED |

### 19.2 Emission

```
for each CM record (parent):
  if CMATC is non-NA, non-blank: emit a CMATC SUPPCM row
  always emit a CMIRAEFL row (Y or N)
```

Per emitted row:
- `RDOMAIN = "CM"`, `IDVAR = "CMSEQ"`, `IDVARVAL = as.character(CMSEQ)`

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

---

# 20. SUPPLB — Supplemental Qualifiers for LB

**Source:** `datasets/sdtm/lb.parquet`  · **Output:** `datasets/sdtm/supplb.parquet`
**SDTMIG section:** 8.4
**Keys:** STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, QNAM

### 20.1 Biomarker codes (case-insensitive match against `LBTESTCD`)

```
BIOMARKER_CODES = c(
  "PDL1","PDL1TPS","PD_L1_TPS",
  "EGFR","EGFRMUT","EGFR_MUT",
  "ALK","ALKREARR","ALK_REARR",
  "ROS1","ROS1REARR","ROS1_REARR",
  "KRAS","KRASG12C","KRAS_G12C",
  "METEX14","MET_EX14",
  "RET","RETREARR","RET_REARR",
  "BRAF","BRAFV600E","BRAF_V600E",
  "NTRK","NTRKFUSE","NTRK_FUSE",
  "TMB"
)
```

### 20.2 QNAM definitions

| QNAM | QLABEL | Derivation | QORIG |
|---|---|---|---|
| BIOMRKFL  | Biomarker Test Indicator | `"Y"` if `LBTESTCD` (trim+upper) is in `BIOMARKER_CODES`, else `"N"` | DERIVED |
| CENTRALFL | Central Lab Indicator    | Same as BIOMRKFL (biomarkers are central; routine labs are local in this study) | DERIVED |

### 20.3 Emission

```
for each LB record (parent):
  emit two SUPPLB rows: one BIOMRKFL, one CENTRALFL
```

Per row: `RDOMAIN = "LB"`, `IDVAR = "LBSEQ"`, `IDVARVAL = as.character(LBSEQ)`.

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

---

# 21. RELREC — Related Records

**Source:** `datasets/sdtm/tu.parquet` + `tr.parquet` + `rs.parquet`  · **Output:** `datasets/sdtm/relrec.parquet`
**SDTMIG section:** 8.5  · **Class:** Relationship  · **Structure:** One record per related-record participant
**Keys:** STUDYID, USUBJID, RDOMAIN, RELID, IDVAR, IDVARVAL

Two relationship types are stacked:

### 21.1 Relationship A — Lesion identity (TU↔TR via LNKID)

For each lesion identified across visits, link the TU "one" record(s) to the corresponding TR "many" records:

```
relrec_lesion =
  UNION(
    SELECT FROM TU WHERE TULINKID not blank:
      RDOMAIN  = "TU"
      IDVAR    = "TULINKID"
      IDVARVAL = TULINKID
      RELTYPE  = "ONE"
      RELID    = paste0("LESION-", TULINKID)
    ,
    SELECT FROM TR WHERE TRLINKID not blank (DISTINCT on TRLINKID):
      RDOMAIN  = "TR"
      IDVAR    = "TRLINKID"
      IDVARVAL = TRLINKID
      RELTYPE  = "MANY"
      RELID    = paste0("LESION-", TRLINKID)
  )
```

### 21.2 Relationship B — Visit response (RS↔TR via assessment date)

For each RS assessment, link the RS "one" record to the TR "many" records performed at the same `(USUBJID, date)`:

```
rs_rows = SELECT FROM RS WHERE RSDTC not blank:
  RDOMAIN  = "RS"
  IDVAR    = "RSSEQ"
  IDVARVAL = as.character(RSSEQ)
  RELTYPE  = "ONE"
  RELID    = paste0("RESP-", USUBJID, "-", RSDTC)

tr_rows = SELECT FROM TR JOIN DISTINCT(RS.USUBJID, RS.RSDTC)
            ON USUBJID == USUBJID AND TRDTC == RSDTC:
  RDOMAIN  = "TR"
  IDVAR    = "TRSEQ"
  IDVARVAL = as.character(TRSEQ)
  RELTYPE  = "MANY"
  RELID    = paste0("RESP-", USUBJID, "-", TRDTC)

relrec_resp = UNION(rs_rows, tr_rows)
```

### 21.3 Final variable structure

| # | Var | Type/Length | Notes |
|---|-----|-------------|-------|
| 1 | STUDYID  | Char/20 | Constant |
| 2 | RDOMAIN  | Char/2  | Source domain of each row (TU/TR/RS) |
| 3 | USUBJID  | Char/40 | — |
| 4 | IDVAR    | Char/8  | per §21.1/§21.2 |
| 5 | IDVARVAL | Char/40 | per §21.1/§21.2 |
| 6 | RELTYPE  | Char/4  | "ONE" or "MANY" |
| 7 | RELID    | Char/100| per §21.1/§21.2 |

**Sort:** `(STUDYID, USUBJID, RELID, RDOMAIN, IDVARVAL)`.

---

# 22. DV — Protocol Deviations

**Source:** `raw/protocol_deviations.csv`  · **Output:** `datasets/sdtm/dv.parquet`
**SDTMIG section:** 6.3 (DV)  · **Class:** Special purpose  · **Structure:** One record per deviation per subject
**Keys:** STUDYID, USUBJID, DVSEQ

### 22.1 Variable derivations

| # | SDTM var | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | Constant | — |
| 2 | DOMAIN   | Char/2  | Constant | `"DV"` |
| 3 | USUBJID  | Char/40 | Derived | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DVSEQ    | Num     | Derived | Per-USUBJID row_number after sort `(USUBJID, DV_DATE)` |
| 5 | DVTERM   | Char/200 | `DV_TERM` | trim |
| 6 | DVDECOD  | Char/200 | `DV_DECODE` | trim + upper |
| 7 | DVCAT    | Char/20 | `DV_SEVERITY` | trim + upper — values: `MAJOR`, `MINOR` |
| 8 | DVSCAT   | Char/40 | `DV_CATEGORY` | trim + upper — deviation category (e.g. `ELIGIBILITY VIOLATION`, `VISIT WINDOW VIOLATION`) |
| 9 | DVSTDTC  | Char/10 | `DV_DATE`  | ISO 8601 direct |
| 10 | EPOCH   | Char/20 | `DV_EPOCH` | trim + upper — `SCREENING` / `TREATMENT` / `FOLLOW-UP` |

**Sort:** `(USUBJID, DV_DATE)` before sequencing.

**Note on data semantics:** `DVCAT` carries the SEVERITY (MAJOR/MINOR) — used by ADaM to derive `ADSL.PPROTFL` (Y when no MAJOR deviation). `DVSCAT` carries the deviation category for sub-categorical tables (T-DV-01).

---

## QC checks (recommended for double programming)

After both implementations are complete, compare on these features per domain
before declaring validation pass:

1. **Row counts** match the Inventory table (above) within ±0.1%.
2. **Variable list and order** identical (column-by-column).
3. **Variable labels** identical (sourced from `16_label_domains.R`).
4. **USUBJID set** identical per domain.
5. **Sort order** identical (re-sort both before binary comparison).
6. **Categorical value distributions** identical (e.g., `table(SDTM.AE$AESEV)`).
7. **Numeric variable summaries** identical to 6 significant figures
   (e.g., `summary(SDTM.LB$LBSTRESN)`).
8. **--SEQ** strictly increasing per USUBJID with no gaps.
9. **RELREC integrity:** every RELID has at least one ONE row and at least one MANY row.

Any divergence is an investigation item, not auto-pass with reconciliation
notes.

---

## Change log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Initial complete spec covering all 21 SDTM datasets (incl. v0.2/v0.3 back-fills: DA, RELREC, SUPPAE, SUPPCM, SUPPLB). SUPPSU flagged as legacy artifact pending successor script. |
| 0.2 | 2026-05-17 | LG (w/ Claude Opus 4.7) | Added §22 DV — Protocol Deviations. Sourced from new `raw/protocol_deviations.csv` simulator (~7% subjects with MAJOR, ~37% with MINOR). Removes accepted limitations AL-02/AL-03/AL-09. Total SDTM datasets now 22. |

---

*Last updated: 2026-05-16*
