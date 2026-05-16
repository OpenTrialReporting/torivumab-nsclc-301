# ADaM Mapping Specification — SDTM → ADaM
## CTX-NSCLC-301 — SIMULATED-TORIVUMAB-2026

> **Purpose.** This document specifies, at the variable level, how each ADaM
> dataset in `datasets/adam/` is derived from the SDTM datasets in
> `datasets/sdtm/`. It is the second-half complement to `programs/sdtm/SDTM-MAPPING-SPEC.md`
> (which covers raw → SDTM). Together the two specs enable end-to-end
> **independent double programming**: a second programmer should reproduce
> every ADaM dataset from these two specs + the ADaM-IG v1.3 + the raw data,
> without consulting `programs/adam/*.R`.
>
> **Standards.** ADaMIG v1.3 · CDISC CT 2024-03 · ADaM Oncology Examples
> (CDISC, 2024) · FDA 2018 PFS censoring guidance · SAP v0.2 (`sap/SAP.md`).
> Estimand attribute references (E1, E1a, E1b, E2, E2a, E3, E3a, E4, E5)
> point to `sap/SAP.md` §13.
>
> **Conventions:**
> - "Direct from `SDTM.X.Y`" means take the parent column verbatim after the
>   ADSL merge.
> - "Direct from `ADSL.X`" means carry the ADSL-level value through to every
>   row of the derived dataset.
> - Dates parsed as `as.Date(<DTC>)` unless noted; missing → NA, no imputation
>   unless explicitly stated.
> - `ANL01FL = "Y"` always reflects the primary analysis population per
>   PARAMCD per SAP §3. Never `"N"` — populate `"Y"` or leave NA.
> - Per ADaMIG v1.3, `STUDYID`, `USUBJID`, key sequence variables, and arm
>   variables are mandatory. All other variables permissible.

---

## Inventory

| # | Dataset | Class | Source SDTM | Output | Records |
|---|---------|-------|-------------|--------|--------:|
| 1 | ADSL  | Subject-Level Analysis Dataset | DM + SUPPDM + EX + DS + DD | `adsl.parquet`  | 450 |
| 2 | ADAE  | Occurrence Data Structure       | AE + ADSL                  | `adae.parquet`  | 2,841 |
| 3 | ADLB  | Basic Data Structure            | LB + ADSL                  | `adlb.parquet`  | 122,601 |
| 4 | ADTR  | Basic Data Structure            | TR + ADSL                  | `adtr.parquet`  | 9,378 |
| 5 | ADRS  | Basic Data Structure            | RS + ADSL + ADTR           | `adrs.parquet`  | 3,662 |
| 6 | ADTTE | Basic Data Structure            | ADSL + ADRS + DS + DD      | `adtte.parquet` | 1,918 |
| 7 | ADDS  | Occurrence Data Structure       | DS + ADSL                  | `adds.parquet`  | 1,350 |
| 8 | ADDV  | Occurrence Data Structure       | DV + ADSL                  | `addv.parquet` | 337 |
| 9 | ADEX  | Basic Data Structure            | EX + ADSL                  | `adex.parquet`  | 16,097 |
| 10 | ADCM | Occurrence Data Structure       | CM + SUPPCM + ADSL         | `adcm.parquet`  | 2,197 |
| 11 | ADVS | Basic Data Structure            | VS + ADSL                  | `advs.parquet`  | 52,864 |
| 12 | ADMH | Occurrence Data Structure       | MH + ADSL                  | `admh.parquet`  | 2,061 |

**Dependency order** (mandatory): ADSL first; all other datasets independent
after ADSL except ADRS (needs ADTR) and ADTTE (needs ADRS). The
`00_run_adam.R` orchestrator respects this.

---

# 1. ADSL — Subject-Level Analysis Dataset

**SDTM inputs:** DM, SUPPDM, EX, DS, DD
**ADaMIG class:** SUBJECT LEVEL ANALYSIS DATASET
**Structure:** One record per subject
**Keys:** STUDYID, USUBJID
**Output:** `datasets/adam/adsl.parquet` · **Expected N:** 450 (all randomised)

### 1.1 Pre-processing steps

**Step A — Pivot SUPPDM wide.**

```
suppdm_wide =
  SELECT STUDYID, USUBJID,
         MAX(CASE WHEN QNAM='ECOGBSL'  THEN QVAL END) AS ECOGBSL,
         MAX(CASE WHEN QNAM='PDL1SCR'  THEN QVAL END) AS PDL1SCR,
         MAX(CASE WHEN QNAM='PDL1GRP'  THEN QVAL END) AS PDL1GRP,
         MAX(CASE WHEN QNAM='HISTSCAT' THEN QVAL END) AS HISTSCAT
  FROM SUPPDM
  WHERE QNAM IN ('ECOGBSL', 'PDL1SCR', 'PDL1GRP', 'HISTSCAT')
  GROUP BY STUDYID, USUBJID
```

**Step B — Treatment start/end dates from EX.**

```
ex_doses = SELECT FROM EX WHERE EXDOSE not NULL AND as.numeric(EXDOSE) > 0
trts =
  SELECT STUDYID, USUBJID,
         MIN(as.Date(EXSTDTC)) AS TRTSDT,
         MAX(as.Date(EXENDTC)) AS TRTEDT
  FROM ex_doses
  GROUP BY STUDYID, USUBJID
```

**Step C — Death date from DD.**

```
dd_death = SELECT STUDYID, USUBJID,
                  MIN(as.Date(DDDTC)) AS DTHDT
           FROM DD
           WHERE DDDTC not NULL AND nchar(trim(DDDTC)) >= 10
           GROUP BY STUDYID, USUBJID
```

**Step D — Last known alive date from DS disposition events.**

```
ds_last = SELECT STUDYID, USUBJID,
                 MAX(as.Date(DSSTDTC)) AS LSTALVDT
          FROM DS
          WHERE DSCAT = 'DISPOSITION EVENT' AND DSSTDTC not NULL
          GROUP BY STUDYID, USUBJID
```

**Step E — Left-join all four onto DM.**

```
adsl = DM
       LEFT JOIN suppdm_wide ON (STUDYID, USUBJID)
       LEFT JOIN trts        ON (STUDYID, USUBJID)
       LEFT JOIN dd_death    ON (STUDYID, USUBJID)
       LEFT JOIN ds_last     ON (STUDYID, USUBJID)
```

### 1.2 Variable derivations

| # | Variable | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | DM | Direct |
| 2 | USUBJID  | Char/40 | DM | Direct |
| 3 | SUBJID   | Char/8  | DM | Direct |
| 4 | SITEID   | Char/8  | DM | Direct |
| 5 | AGE      | Num     | DM | Direct |
| 6 | AGEGR1   | Char/8  | Derived | `"<65"` if `AGE < 65`; `">=65"` if `AGE ≥ 65`; else NA |
| 7 | AGEU     | Char/10 | DM | Direct (`"YEARS"`) |
| 8 | SEX      | Char/8  | DM | Direct |
| 9 | RACE     | Char/80 | DM | Direct |
| 10 | ETHNIC  | Char/40 | DM | Direct |
| 11 | COUNTRY | Char/40 | DM | Direct |
| 12 | ARM     | Char/40 | DM | Direct |
| 13 | ACTARM  | Char/40 | DM | Direct |
| 14 | TRT01P  | Char/40 | Derived | `= ARM` |
| 15 | TRT01A  | Char/40 | Derived | `= ACTARM` |
| 16 | TRT01PN | Num     | Derived | `1` if `ARM = "Torivumab + Chemotherapy"`; `2` if `ARM = "Placebo + Chemotherapy"`; else NA |
| 17 | TRT01AN | Num     | Derived | `= TRT01PN` (no cross-over) |
| 18 | ICDT    | Date    | Derived | `as.Date(DM.RFICDTC)` |
| 19 | RANDDT  | Date    | Derived | `as.Date(DM.RFSTDTC)` |
| 20 | TRTSDT  | Date    | EX-derived | First treatment date (Step B) |
| 21 | TRTEDT  | Date    | EX-derived | Last treatment date (Step B) |
| 22 | TRTDURD | Num     | Derived | `as.integer(TRTEDT - TRTSDT) + 1` |
| 23 | ITTFL   | Char/1  | Derived | `"Y"` if `ARMNRS is NULL OR ARMNRS != "SCREEN FAILURE"`; else `"N"` |
| 24 | SAFFL   | Char/1  | Derived | `"Y"` if `TRTSDT is not NULL`; else `"N"` |
| 25 | PPROTFL | Char/1  | Derived | `"Y"` if `TRTSDT is not NULL`; else `"N"` (in this synthetic dataset PP = SAF; real studies would subtract major-deviation subjects) |
| 26 | DTHFL   | Char/1  | Derived | `"Y"` if `DTHDT is not NULL`; else `"N"` |
| 27 | DTHDT   | Date    | DD-derived | Step C |
| 28 | LSTALVDT| Date    | DS-derived | Step D |
| 29 | ECOG    | Num     | SUPPDM   | `as.integer(ECOGBSL)` |
| 30 | PDL1CAT | Char/40 | SUPPDM   | `= PDL1GRP` |
| 31 | PDL1SCR | Num     | SUPPDM   | `as.numeric(PDL1SCR)` |
| 32 | HISTCAT | Char/40 | SUPPDM   | `= HISTSCAT` |

**Sort:** `USUBJID`. **Expected: 450 rows.**

---

# 2. ADAE — Adverse Event Analysis Dataset

**SDTM inputs:** AE + ADSL
**ADaMIG class:** OCCURRENCE DATA STRUCTURE
**Structure:** One record per AE per subject
**Keys:** STUDYID, USUBJID, AESEQ
**Output:** `datasets/adam/adae.parquet` · **Expected N:** ~2,841 (one per AE row)
**Estimand support:** S1–S3 (safety descriptive estimands, SAP §13.7)

### 2.1 Pre-processing — ADSL merge

```
adsl_vars = SELECT STUDYID, USUBJID, SUBJID, SITEID,
                   TRTSDT, TRTEDT, TRTDURD, SAFFL, ITTFL,
                   TRT01P, TRT01A, TRT01PN, TRT01AN
            FROM ADSL

adae = AE LEFT JOIN adsl_vars ON (STUDYID, USUBJID)
```

### 2.2 Variable derivations

| # | Variable | Type/Length | Source | Derivation |
|---|----------|-------------|--------|------------|
| 1 | STUDYID  | Char/20 | AE | Direct |
| 2 | USUBJID  | Char/40 | AE | Direct |
| 3 | SUBJID, SITEID | Char | ADSL | Direct |
| 4 | SAFFL, ITTFL | Char/1 | ADSL | Direct |
| 5 | TRT01P, TRT01A, TRT01PN, TRT01AN | various | ADSL | Direct |
| 6 | TRTSDT, TRTEDT | Date | ADSL | Direct |
| 7 | TRTDURD | Num | ADSL | Direct |
| 8 | AESEQ   | Num | AE | Direct |
| 9 | AETERM, AEDECOD, AEBODSYS, AEHLT, AELLT, AESOC | Char | AE | Direct |
| 10 | AECAT  | Char/40 | AE | Direct |
| 11 | AESTDTC, AEENDTC | Char/10 | AE | Direct |
| 12 | ASTDT  | Date | Derived | `as.Date(AESTDTC)` |
| 13 | AENDT  | Date | Derived | `as.Date(AEENDTC)` |
| 14 | ASTDY  | Num  | Derived | `as.integer(ASTDT - TRTSDT) + 1` (if TRTSDT non-NA) |
| 15 | AENDY  | Num  | Derived | `as.integer(AENDT - TRTSDT) + 1` (if AENDT and TRTSDT non-NA, else NA) |
| 16 | AESEV  | Char/20 | AE | Direct |
| 17 | AETOXGR| Char/1  | AE (or backfill) | Direct if present; else map AESEV: MILD→1, MODERATE→2, SEVERE→3, LIFE-THREATENING→4, FATAL→5 |
| 18 | AETOXGRN | Num    | Derived | `suppressWarnings(as.integer(AETOXGR))` |
| 19 | AESER  | Char/1  | AE | Direct |
| 20 | AESERFL| Char/1  | Derived | `"Y"` if `AESER == "Y"`; else `"N"` (NA → `"N"`) |
| 21 | AEREL, AEACN, AEOUT | Char | AE | Direct |
| 22 | AESDTH, AESHOSP, AESLIFE, AESDISAB, AESMIE, AESCONG | Char/1 | AE | Direct |
| 23 | **TRTEMFL** | Char/1 | Derived | `"Y"` if `ASTDT not NULL AND TRTSDT not NULL AND ASTDT ≥ TRTSDT AND ASTDT ≤ TRTEDT + 30 days`; else `"N"` |
| 24 | **IRAEFL**  | Char/1 | Derived | `"Y"` if `toupper(trim(AECAT)) == "IMMUNE-RELATED"`; else `"N"` (NA → `"N"`) |
| 25 | **ANL01FL** | Char/1 | Derived | `"Y"` if `TRTEMFL == "Y" AND SAFFL == "Y"`; else NA |
| 26 | AVAL    | Num   | Derived | `= AETOXGRN` (numeric grade for tabulation) |

**Sort:** `(USUBJID, AESEQ)`. **Expected: 2,841 rows.**

---

# 3. ADLB — Laboratory Analysis Dataset

**SDTM inputs:** LB + ADSL
**ADaMIG class:** BASIC DATA STRUCTURE
**Structure:** One record per subject per parameter per analysis visit
**Keys:** STUDYID, USUBJID, PARAMCD, AVISITN
**Output:** `datasets/adam/adlb.parquet` · **Expected N:** ~122,601

### 3.1 Pre-processing

```
adsl_vars = SELECT STUDYID, USUBJID, SUBJID, SITEID,
                   TRTSDT, TRTEDT, SAFFL, ITTFL,
                   TRT01P, TRT01A, TRT01PN, TRT01AN
            FROM ADSL

adlb_raw = LB LEFT JOIN adsl_vars ON (STUDYID, USUBJID)
```

### 3.2 Parameter mapping

```
PARAM   = LBTEST
PARAMCD = LBTESTCD
PARAMN  = integer index of PARAMCD in sorted-unique order across the dataset
```

### 3.3 Visit standardisation

```
AVISIT  = VISIT  (already standardised in LB)
AVISITN = VISITNUM
ADT     = as.Date(LBDTC)
ADY     = as.integer(ADT - TRTSDT) + 1   (NA if either is NA)
```

### 3.4 Baseline and change derivations

**Baseline value** per (USUBJID, PARAMCD): last non-missing LBSTRESN with `LBBLFL == "Y"`. If no baseline, BASE = NA.

```
baseline = SELECT USUBJID, PARAMCD,
                  last(LBSTRESN) over visits where LBBLFL = 'Y' AS BASE,
                  last(LBNRIND) over visits where LBBLFL = 'Y'  AS BTOXGR  -- repurposed
           FROM adlb_raw
           GROUP BY USUBJID, PARAMCD

adlb = adlb_raw LEFT JOIN baseline ON (USUBJID, PARAMCD)

CHG  = AVAL - BASE       (NA if either side NA)
PCHG = (AVAL - BASE) / BASE * 100    (NA if BASE NA or BASE == 0)
```

### 3.5 Variable list (29 vars)

| # | Var | Type | Source | Derivation |
|---|-----|------|--------|------------|
| 1-7 | STUDYID, USUBJID, SUBJID, SITEID, SAFFL, ITTFL, TRT01P/A/PN/AN | Char/Num | ADSL | Direct |
| 8 | TRTSDT, TRTEDT | Date | ADSL | Direct |
| 9 | LBSEQ | Num | LB | Direct |
| 10 | PARAM | Char/40 | LB | `= LBTEST` |
| 11 | PARAMCD | Char/8 | LB | `= LBTESTCD` |
| 12 | PARAMN | Num | Derived | Integer rank of PARAMCD (alphabetical) |
| 13 | ADT | Date | Derived | `as.Date(LBDTC)` |
| 14 | ADY | Num  | Derived | `as.integer(ADT - TRTSDT) + 1` |
| 15 | AVISIT | Char/40 | LB | `= VISIT` |
| 16 | AVISITN| Num     | LB | `= VISITNUM` |
| 17 | AVAL   | Num     | LB | `= LBSTRESN` |
| 18 | AVALC  | Char/40 | LB | `= LBSTRESC` |
| 19 | AVALU  | Char/20 | LB | `= LBSTRESU` |
| 20 | BASE   | Num     | Derived | per §3.4 |
| 21 | BASEC  | Char/40 | Derived | `as.character(BASE)` |
| 22 | CHG    | Num     | Derived | `AVAL - BASE` |
| 23 | PCHG   | Num     | Derived | `(AVAL - BASE) / BASE * 100` |
| 24 | ABLFL  | Char/1  | LB | `= LBBLFL` |
| 25 | ANRIND | Char/10 | LB | `= LBNRIND` |
| 26 | BTOXGR | Char/10 | Derived | LBNRIND at baseline (carried forward via baseline join) |
| 27 | DTYPE  | Char/8  | NA (no analysis-derived imputations in this dataset) | — |
| 28 | ANL01FL| Char/1  | Derived | `"Y"` for all rows (primary analysis includes all available) |
| 29 | AETOXGR/CTCAE columns | Char | Derived | Per LB CTCAE grading rules (not yet implemented here; placeholder) |

**Sort:** `(USUBJID, PARAMCD, AVISITN)`. **Expected: ~122,601 rows.**

---

# 4. ADTR — Tumor Results Analysis Dataset

**SDTM inputs:** TR + ADSL
**ADaMIG class:** BASIC DATA STRUCTURE
**Structure:** One record per subject per parameter per analysis visit
**Keys:** STUDYID, USUBJID, PARAMCD, AVISITN
**Output:** `datasets/adam/adtr.parquet` · **Expected N:** ~9,378

### 4.1 Parameters

Two computed PARAMCDs are derived from TR:

| PARAMCD | PARAM | Derivation |
|---|---|---|
| SDIAM | Sum of Diameters (target lesions) | For each (USUBJID, TRDTC): `sum(TRSTRESN)` across `TRTESTCD = "LDIAM"` rows |
| LDIAM | Longest Diameter (per target lesion) | Direct pass-through of `TR.TRTESTCD = "LDIAM"` rows |

### 4.2 Pre-processing

```
adsl_vars = SELECT USUBJID, TRTSDT, TRTEDT, TRT01P/A/PN/AN, SAFFL, ITTFL FROM ADSL
tr_target = SELECT FROM TR WHERE TRTESTCD = "LDIAM" AND TRGRPID = "TARGET"

sdiam =
  SELECT USUBJID, TRDTC, VISIT, VISITNUM,
         sum(TRSTRESN) AS AVAL
  FROM tr_target
  GROUP BY USUBJID, TRDTC, VISIT, VISITNUM

ldiam =
  SELECT USUBJID, TRDTC, VISIT, VISITNUM, TRLINKID,
         TRSTRESN AS AVAL
  FROM tr_target

adtr = UNION(sdiam_records, ldiam_records) LEFT JOIN adsl_vars
```

### 4.3 Baseline + change derivations

**BASE** = AVAL at the first SDIAM/LDIAM record where `TRDTC < TRTSDT` (screening). If no pre-treatment record, use the C1D1 record.

```
CHG  = AVAL - BASE
PCHG = (AVAL - BASE) / BASE * 100      (if BASE > 0)
NADIR = running minimum of AVAL within (USUBJID, PARAMCD) up to current visit
```

### 4.4 Variable derivations

| Variable | Source / Derivation |
|---|---|
| STUDYID, USUBJID, SUBJID, SITEID | ADSL Direct |
| SAFFL, ITTFL | ADSL Direct |
| TRT01P/A/PN/AN, TRTSDT, TRTEDT | ADSL Direct |
| PARAM = "Sum of Diameters" or "Longest Diameter" | per §4.1 |
| PARAMCD = "SDIAM" or "LDIAM" | per §4.1 |
| AVISIT = VISIT, AVISITN = VISITNUM, ADT = as.Date(TRDTC) | Direct |
| AVAL | per §4.1/§4.2 |
| AVALU = "mm" | Constant |
| BASE | per §4.3 |
| CHG, PCHG | per §4.3 |
| NADIR | per §4.3 |
| ANL01FL = "Y" | All records (primary analysis) |
| ABLFL = "Y" if record is baseline | Derived per BASE selection |

**Sort:** `(USUBJID, PARAMCD, AVISITN, TRLINKID)`. **Expected: ~9,378 rows.**

---

# 5. ADRS — Disease Response Analysis Dataset

**SDTM inputs:** RS + ADSL + ADTR
**ADaMIG class:** BASIC DATA STRUCTURE
**Structure:** One record per subject per parameter (or per visit per parameter)
**Keys:** STUDYID, USUBJID, PARAMCD, AVISITN (or AVAL for derived params)
**Output:** `datasets/adam/adrs.parquet` · **Expected N:** ~3,662

### 5.1 Parameters

Three PARAMCDs are emitted:

| PARAMCD | PARAM | Granularity | Source / Derivation |
|---|---|---|---|
| OVR  | Overall Response per visit             | One per RS record per visit  | Direct from RS.RSSTRESC; values: CR, PR, SD, PD, NE |
| BOR  | Best Overall Response (unconfirmed)    | One per subject              | For each USUBJID: best response across all OVR records using RECIST 1.1 ordering (CR > PR > SD > PD > NE) |
| CBOR | Confirmed Best Overall Response        | One per subject              | Same as BOR but a CR or PR must be confirmed at a subsequent assessment ≥28 days later with no intervening PD. Otherwise downgrade to next-best non-confirmed-required response. |

### 5.2 BOR derivation logic

```
for each USUBJID:
  ordered = sort(OVR records by ADT)
  if any record == "CR":
    if exists later record (>= 28 days after first CR) with response in {"CR"}:
      CBOR = "CR"
    else: CBOR = "SD" (downgrade) or "PR" depending on other obs
    BOR  = "CR"  (unconfirmed counts toward BOR)
  else if any record == "PR":
    if exists later record (>= 28 days after first PR) with response in {"PR","CR"}:
      CBOR = "PR"
    else: CBOR = "SD"
    BOR  = "PR"
  else if any record == "SD":
    BOR = "SD",  CBOR = "SD" (no confirmation needed)
  else if any record == "PD":
    BOR = "PD",  CBOR = "PD"
  else:
    BOR = "NE",  CBOR = "NE"
```

ORRFL = "Y" if CBOR ∈ {"CR", "PR"}; else "N".

### 5.3 Variable list

| Variable | Source / Derivation |
|---|---|
| STUDYID, USUBJID, SUBJID, SITEID, SAFFL, ITTFL, TRT01P/A/PN/AN | ADSL Direct |
| TRTSDT, TRTEDT | ADSL Direct |
| PARAM, PARAMCD | per §5.1 |
| AVISIT, AVISITN | RS.VISIT, RS.VISITNUM (for OVR); for BOR/CBOR: "BEST OVERALL", AVISITN = NA |
| ADT  | `as.Date(RS.RSDTC)` (for OVR); date of first attaining BOR (for BOR/CBOR) |
| AVAL | numeric encoding: CR=1, PR=2, SD=3, PD=4, NE=5 |
| AVALC| character response code |
| ANL01FL | "Y" for all records |
| RSPFL  | "Y" for the OVR record at the first CR or PR; else "N" (subject-level on BOR/CBOR) |

**Sort:** `(USUBJID, PARAMCD, AVISITN)`. **Expected: ~3,662 rows.**

---

# 6. ADTTE — Time-to-Event Analysis Dataset

**SDTM inputs:** ADSL + ADRS + DS + DD
**ADaMIG class:** BASIC DATA STRUCTURE
**Structure:** One record per subject per time-to-event parameter
**Keys:** STUDYID, USUBJID, PARAMCD
**Output:** `datasets/adam/adtte.parquet` · **Expected N:** ~1,918 (5 params × 450, minus DOR restricted to responders)
**Estimand support:** E1 (OS), E1a (OSWOT via separate PARAMCD), E1b (OSWOT), E2 (PFS BICR), E2a (PFSINV), E4 (DOR)

### 6.1 Parameters

| PARAMCD | PARAM | Population | Start | Event | Censor | Estimand |
|---|---|---|---|---|---|---|
| OS     | Overall Survival | ITT | TRTSDT | Death (any cause) | `CENSOR_OS = pmax(TRTEDT, LSTALVDT, na.rm=TRUE)` | E1 |
| OSWOT  | Overall Survival — While-on-Treatment | ITT | TRTSDT | Death on or within 30 days of TRTEDT | `pmin(TRTEDT + 30 days, ADCM.SUBSQTDT, LSTALVDT)` | E1b |
| PFS    | Progression-Free Survival (BICR) | ITT | TRTSDT | Earliest of (PD from SDTM.RS WHERE RSEVAL='INDEPENDENT ASSESSOR' or death) | Last adequate BICR assessment OR CENSOR_OS | E2 |
| PFSINV | Progression-Free Survival (Investigator) | ITT | TRTSDT | Earliest of (PD from SDTM.RS WHERE RSEVAL='INVESTIGATOR' or death) | Last adequate Investigator assessment OR CENSOR_OS | E2a |
| DOR    | Duration of Response | Confirmed responders (`RSPDT not NULL`) | RSPDT (first CR/PR) | PD or death after RSPDT | Last adequate assessment OR CENSOR_OS | E4 |
| TTR    | Time to Response | ITT | TRTSDT | RSPDT (first confirmed CR/PR) | Last adequate assessment OR CENSOR_OS | descriptive |

### 6.2 Pre-processing

```
subj = ADSL
       MUTATE DTHDT = as.Date(DTHDT),
              TRTSDT = as.Date(TRTSDT), TRTEDT = as.Date(TRTEDT),
              LSTALVDT = as.Date(LSTALVDT),
              CENSOR_OS = pmax(TRTEDT, LSTALVDT, na.rm = TRUE)

# Reader-stratified PD dates (AL-04/AL-07 closure 2026-05-17)
pd_dates_bicr =
  SELECT USUBJID, MIN(as.Date(RSDTC)) AS PDDT
  FROM SDTM.RS
  WHERE RSEVAL = 'INDEPENDENT ASSESSOR' AND RSSTRESC = 'PD'
  GROUP BY USUBJID

pd_dates_inv =
  SELECT USUBJID, MIN(as.Date(RSDTC)) AS PDDT
  FROM SDTM.RS
  WHERE RSEVAL = 'INVESTIGATOR' AND RSSTRESC = 'PD'
  GROUP BY USUBJID

last_assess_bicr / last_assess_inv = analogous MAX(RSDTC) filtered by RSEVAL

first_resp =
  SELECT USUBJID, ADT AS RSPDT
  FROM ADRS WHERE PARAMCD = 'CBOR' AND AVALC IN ('CR','PR') AND ADT not NULL

subj = subj LEFT JOIN pd_dates, last_assess, first_resp ON USUBJID
```

### 6.3 Per-parameter derivation

#### 6.3.1 OS
```
adtte_os = subj
  MUTATE PARAMCD = 'OS',
         PARAM   = 'Overall Survival',
         CNSR    = if DTHFL = 'Y' then 0 else 1,
         ADT     = if DTHFL = 'Y' then DTHDT else CENSOR_OS,
         EVNTDESC = if DTHFL = 'Y' then 'DEATH' else 'CENSORED - LAST KNOWN ALIVE',
         SRCDOM  = if DTHFL = 'Y' then 'DD' else 'ADSL'
```

#### 6.3.2 OSWOT
```
adtte_oswot = subj
  MUTATE OSWOT_CUT    = TRTEDT + 30,
         OSWOT_CENSOR = pmin(OSWOT_CUT, LSTALVDT, na.rm = TRUE),
         OSWOT_EVENT  = DTHFL == 'Y' AND DTHDT not NULL AND DTHDT <= OSWOT_CUT,
         PARAMCD      = 'OSWOT',
         PARAM        = 'Overall Survival - While-on-Treatment Sensitivity',
         CNSR         = if OSWOT_EVENT then 0 else 1,
         ADT          = if OSWOT_EVENT then DTHDT else OSWOT_CENSOR,
         EVNTDESC     = case:
                          OSWOT_EVENT → 'DEATH ON/WITHIN 30D OF LAST DOSE'
                          LSTALVDT < OSWOT_CUT → 'CENSORED - LOST BEFORE TRTEDT+30D'
                          else → 'CENSORED - ALIVE AT TRTEDT+30D'
         SRCDOM       = if OSWOT_EVENT then 'DD' else 'ADSL'
```

#### 6.3.3 PFS
```
adtte_pfs = subj
  MUTATE PFS_EVENT_DT = pmin(PDDT, DTHDT, na.rm = TRUE),
         PFS_EVENT    = PFS_EVENT_DT not NULL,
         PARAMCD      = 'PFS',
         PARAM        = 'Progression-Free Survival',
         CNSR         = if PFS_EVENT then 0 else 1,
         ADT          = if PFS_EVENT then PFS_EVENT_DT
                        else coalesce(LAST_OVR_DT, CENSOR_OS),
         EVNTDESC     = case:
                          PDDT not NULL AND (DTHDT NULL OR PDDT <= DTHDT) → 'PROGRESSIVE DISEASE'
                          DTHDT not NULL → 'DEATH'
                          else → 'CENSORED - LAST TUMOUR ASSESSMENT'
         SRCDOM       = case:
                          EVNTDESC = 'PROGRESSIVE DISEASE' → 'ADRS'
                          EVNTDESC = 'DEATH'               → 'DD'
                          else → 'ADRS'
```

#### 6.3.4 DOR (responders only)
```
adtte_dor = subj WHERE RSPDT not NULL
  MUTATE DOR_EVENT_DT = pmin(
           if PDDT  > RSPDT then PDDT  else NULL,
           if DTHDT > RSPDT then DTHDT else NULL,
           na.rm = TRUE),
         DOR_EVENT = DOR_EVENT_DT not NULL,
         PARAMCD   = 'DOR',
         PARAM     = 'Duration of Response',
         CNSR      = if DOR_EVENT then 0 else 1,
         ADT       = if DOR_EVENT then DOR_EVENT_DT
                     else coalesce(LAST_OVR_DT, CENSOR_OS)
```

#### 6.3.5 TTR (ITT — non-responders censored)
```
adtte_ttr = subj
  MUTATE TTR_EVENT = RSPDT not NULL,
         PARAMCD   = 'TTR',
         PARAM     = 'Time to Response',
         CNSR      = if TTR_EVENT then 0 else 1,
         ADT       = if TTR_EVENT then RSPDT
                     else coalesce(LAST_OVR_DT, CENSOR_OS),
         EVNTDESC  = if TTR_EVENT then 'CONFIRMED RESPONSE' else 'CENSORED - NO RESPONSE',
         SRCDOM    = 'ADRS'
```

### 6.4 AVAL derivation (days)

```
add_aval(dat, start_var):
  AVAL  = as.numeric(as.Date(ADT) - as.Date(start_var))
  AVALU = "DAYS"

adtte_os, adtte_oswot, adtte_pfs, adtte_ttr → AVAL relative to TRTSDT
adtte_dor                                    → AVAL relative to RSPDT
```

### 6.5 Final stack

```
adtte = bind_rows(adtte_os, adtte_oswot, adtte_pfs, adtte_dor, adtte_ttr)
        MUTATE ANL01FL = 'Y'
        SELECT 19 columns (below)
        ORDER BY (USUBJID, PARAMCD)
```

### 6.6 Variable list (19 vars)

| # | Var | Type | Notes |
|---|-----|------|-------|
| 1-4 | STUDYID, USUBJID, SAFFL, ITTFL | Direct from ADSL |
| 5-8 | TRT01P, TRT01A, TRT01PN, TRT01AN | Direct from ADSL |
| 9-10 | TRTSDT, TRTEDT | Direct from ADSL |
| 11 | PARAM | Per §6.1 |
| 12 | PARAMCD | Per §6.1 |
| 13 | ADT | Per §6.3 |
| 14 | AVAL | Per §6.4 |
| 15 | AVALU | "DAYS" |
| 16 | CNSR | Per §6.3 (0 = event, 1 = censor) |
| 17 | EVNTDESC | Per §6.3 |
| 18 | SRCDOM | Per §6.3 |
| 19 | ANL01FL | "Y" for all rows |

**Sort:** `(USUBJID, PARAMCD)`. **Expected: 1,918 rows.**

---

## QC checks (recommended for double programming)

After both implementations are complete, compare on these features per dataset:

1. **Row counts** match Inventory table within ±0.1%.
2. **Variable list and order** identical.
3. **Variable labels** identical (sourced from per-spec dictionaries).
4. **USUBJID set** identical per PARAMCD.
5. **PARAMCD distribution** identical for BDS datasets.
6. **Population flag totals** identical:
   - ITTFL = 'Y' count
   - SAFFL = 'Y' count
   - PPROTFL = 'Y' count
   - DTHFL = 'Y' count
7. **Cox PH HR validation** on ADTTE:
   - OS HR within ±0.05 of expected (~0.567 in current synthetic data)
   - PFS HR within ±0.05 of expected (~0.504)
   - OSWOT HR within ±0.10 of expected (~0.476)
8. **TRTEMFL counts** on ADAE match expected ratios per arm.
9. **CBOR distribution** on ADRS matches expected ORR ratios.
10. **Date integrity:** for every TTE record, `ADT ≥ start_date` (no negative AVAL).

---

# 7. ADDS — Subject Disposition Analysis Dataset

**SDTM inputs:** DS + ADSL · **Class:** OCCDS · **Structure:** One record per disposition event per subject · **Keys:** STUDYID, USUBJID, DSSEQ
**Output:** `datasets/adam/adds.parquet` · **Expected N:** 1,350 (~3 records / subject: IC + RAND + disposition event)

### 7.1 Variable derivations

| Var | Source / Derivation |
|---|---|
| STUDYID..TRT01AN | Direct from DS + ADSL merge |
| TRTSDT, TRTEDT | ADSL direct |
| DSSEQ, DSTERM, DSDECOD, DSCAT, DSSCAT | DS direct |
| ADT | `as.Date(DSSTDTC)` |
| ADY | `as.integer(ADT - TRTSDT) + 1` |
| **DSCATGY** | Derived rollup: `"Consent"` if `DSCAT='PROTOCOL MILESTONE' AND DSDECOD='INFORMED CONSENT OBTAINED'`; `"Randomisation"` if same cat with `DSDECOD='RANDOMIZED'`; `"Completed"` if `DSCAT='DISPOSITION EVENT' AND DSDECOD='COMPLETED'`; `"Discontinued"` if `DSCAT='DISPOSITION EVENT'` (else); else `"Other"`. |
| **EOTFL** | `"Y"` if `DSCATGY ∈ {Completed, Discontinued}`; else `"N"` (End-of-Treatment record flag) |
| ANL01FL | `"Y"` for all records |

**Sort:** `(USUBJID, DSSEQ)`. **Expected: 1,350 rows.**

---

# 8. ADDV — Protocol Deviations Analysis Dataset

**SDTM inputs:** DV + ADSL · **Class:** OCCDS · **Structure:** One record per deviation per subject · **Keys:** STUDYID, USUBJID, DVSEQ
**Output:** `datasets/adam/addv.parquet` · **Expected N:** ~337 (190 subjects affected; ~50 MAJOR / ~287 MINOR)

### 8.1 Pre-processing

```
adsl_vars = SELECT STUDYID, USUBJID, SUBJID, SITEID, TRTSDT, TRTEDT,
                   SAFFL, ITTFL, PPROTFL, DTHFL,
                   TRT01P, TRT01A, TRT01PN, TRT01AN, RANDDT
            FROM ADSL

addv = DV LEFT JOIN adsl_vars ON (STUDYID, USUBJID)
```

### 8.2 Variable derivations

| Var | Source / Derivation |
|---|---|
| STUDYID..TRT01AN | DV + ADSL merge |
| TRTSDT, TRTEDT | ADSL direct |
| DVSEQ, DVTERM, DVDECOD, DVCAT, DVSCAT, DVSTDTC | DV direct |
| ADT | `as.Date(DVSTDTC)` |
| ADY | `as.integer(ADT - RANDDT) + 1` |
| **DVSEV** | `= DVCAT` (alias for clarity in analyses — MAJOR / MINOR) |
| ANL01FL | `"Y"` for all records |

**Sort:** `(USUBJID, DVSEQ)`. **Expected: ~337 rows.**

### 8.3 Impact on ADSL.PPROTFL (2026-05-17 update)

`ADSL.PPROTFL` is now derived as:
```
PPROTFL = "Y" if SAFFL='Y' AND USUBJID NOT IN (subjects with any MAJOR deviation)
        = "N" otherwise
```

Previously `PPROTFL` was a placeholder alias for `SAFFL` (because no DV
existed). With real deviations the PP population drops from 449 → ~412,
making T-EFF-08 (OS in PP) a meaningful sensitivity analysis: HR 0.545 in
PP vs 0.576 in ITT — direction and magnitude as expected when excluding
deviators.

---

# 9. ADEX — Exposure Analysis Dataset

**SDTM inputs:** EX + ADSL · **Class:** BDS · **Structure:** One record per administration + one summary record per subject per drug per parameter · **Keys:** STUDYID, USUBJID, PARAMCD, AEXTRT
**Output:** `datasets/adam/adex.parquet` · **Expected N:** ~16,097

### 9.1 Parameters

| PARAMCD | PARAM | Granularity | Derivation |
|---|---|---|---|
| DOSEAMT | Dose Amount per Administration | One row per `SDTM.EX` record | `AVAL = as.numeric(EXDOSE)`; `AVALU = EXDOSU`; `NCYCLE = row_number()` per `(USUBJID, AEXTRT)` ordered by `ADT` |
| CUMDOSE | Cumulative Dose | One row per `(USUBJID, AEXTRT)` | `AVAL = sum(DOSEAMT.AVAL)` per group |
| RDI | Relative Dose Intensity (%) | One row per `(USUBJID, AEXTRT)` | `AVAL = 100 × actual_cumulative / planned_cumulative` |

### 9.2 Planned cumulative dose

| Drug | Planned per cycle | Notes |
|---|---|---|
| TORIVUMAB | 200 mg | Fixed flat dose |
| PLACEBO | 200 mg | Matched placebo |
| CARBOPLATIN, PEMETREXED | Per-subject mean of actual doses | Synthetic-data simplification (real study: per-cycle BSA / AUC calculation) |

`planned_cumulative = planned_per_cycle × n_administrations`. RDI capped at NA if `planned_cumulative = 0`.

### 9.3 Variable list

| Var | Source / Derivation |
|---|---|
| STUDYID..TRT01AN | EX + ADSL merge |
| TRTSDT, TRTEDT, TRTDURD | ADSL direct |
| AEXSEQ | Per-USUBJID row_number for DOSEAMT records (NA for CUMDOSE/RDI) |
| AEXTRT | `EXTRT` (drug name, upper-case) |
| PARAM, PARAMCD, AVAL, AVALU | Per §9.1 |
| ADT | `as.Date(EXSTDTC)` for DOSEAMT; `max(ADT)` per group for CUMDOSE/RDI |
| ADY, NCYCLE, VISIT, VISITNUM | Per administration |
| ANL01FL | `"Y"` |

**Sort:** `(USUBJID, AEXTRT, ADT)` for DOSEAMT; `(USUBJID, AEXTRT)` for summaries.

---

# 10. ADCM — Concomitant Medications Analysis Dataset

**SDTM inputs:** CM + SUPPCM + ADSL · **Class:** OCCDS · **Structure:** One record per medication occurrence per subject · **Keys:** STUDYID, USUBJID, CMSEQ
**Output:** `datasets/adam/adcm.parquet` · **Expected N:** 2,197

### 10.1 Pre-processing

```
suppcm_wide = SUPPCM pivoted on QNAM → columns CMATC, CMIRAEFL
# Rename SUPPCM's CMATC to CMATC_SUPP to avoid collision with CM.CMATC

adcm = CM LEFT JOIN ADSL_vars LEFT JOIN suppcm_wide(rename) ON (USUBJID, CMSEQ)
adcm$CMATC = coalesce(adcm$CMATC, adcm$CMATC_SUPP)
```

### 10.2 Derived flags

| Var | Derivation |
|---|---|
| ASTDT, AENDT | `as.Date(CMSTDTC)`, `as.Date(CMENDTC)` |
| ASTDY | `as.integer(ASTDT - TRTSDT) + 1` |
| AENDY | `as.integer(AENDT - TRTSDT) + 1` (NA if AENDT NA) |
| **ONTRTFL** | `"Y"` if `ASTDT ≤ TRTEDT AND (AENDT NULL OR AENDT ≥ TRTSDT)`; else `"N"` |
| **PRIORFL** | `"Y"` if `ASTDT < TRTSDT AND AENDT < TRTSDT`; else `"N"` |
| **CONFL** | Same as ONTRTFL (concomitant ≡ on-treatment in this study) |
| **CMIRAEFL** | From SUPPCM `QNAM='CMIRAEFL'`; default `"N"` if NA |
| ANL01FL | `"Y"` |
| AVAL | NA (OCCDS — no analysis value) |

**Sort:** `(USUBJID, CMSEQ)`. **Expected: 2,197 rows.**

---

# 11. ADVS — Vital Signs Analysis Dataset

**SDTM inputs:** VS + ADSL · **Class:** BDS · **Structure:** One record per subject per parameter per visit · **Keys:** STUDYID, USUBJID, PARAMCD, AVISITN
**Output:** `datasets/adam/advs.parquet` · **Expected N:** 52,864

### 11.1 Parameter mapping

```
PARAM   = VS.VSTEST
PARAMCD = VS.VSTESTCD     (SYSBP, DIABP, HR, WEIGHT, HEIGHT, TEMP, RESP)
PARAMN  = integer rank of PARAMCD (alphabetical)
```

### 11.2 Visit + analysis-value derivations

```
ADT     = as.Date(VS.VSDTC)
ADY     = as.integer(ADT - TRTSDT) + 1
AVISIT  = VS.VISIT
AVISITN = VS.VISITNUM
AVAL    = VS.VSSTRESN
AVALC   = VS.VSSTRESC
AVALU   = VS.VSSTRESU

ABLFL = "Y" if AVISIT in {SCREENING, SCR, C1D1} AND ADT <= TRTSDT, else NA
```

### 11.3 Baseline + change

```
baseline = last AVAL per (USUBJID, PARAMCD) where ABLFL='Y' AND AVAL not NA
adVS = adVS LEFT JOIN baseline → BASE
CHG  = AVAL - BASE
PCHG = 100 × (AVAL - BASE) / BASE   (NA if BASE NA or 0)
```

`ANL01FL = "Y"` for all records. **Sort:** `(USUBJID, PARAMCD, AVISITN, ADT)`.

---

# 12. ADMH — Medical History Analysis Dataset

**SDTM inputs:** MH + ADSL · **Class:** OCCDS · **Structure:** One record per condition per subject · **Keys:** STUDYID, USUBJID, MHSEQ
**Output:** `datasets/adam/admh.parquet` · **Expected N:** 2,061

### 12.1 Date handling (partial dates)

`MHSTDTC` may be partial (`YYYY` or `YYYY-MM`). Per SAP §7, no imputation for descriptive MH summary. Therefore:

```
ASTDT = as.Date(MHSTDTC)  if nchar(MHSTDTC) == 10
        NA                 otherwise
ASTDY = as.integer(ASTDT - TRTSDT) + 1   (NA where ASTDT NA)
```

### 12.2 Derived flags

| Var | Derivation |
|---|---|
| **PCANCERFL** | `"Y"` if `MHCAT == "PRIMARY DIAGNOSIS"`; else `"N"` (NSCLC diagnosis flag) |
| **ONGOFL** | `"Y"` if `MHENRTPT == "ONGOING"`; else `"N"` |
| **PRIORFL** | `"Y"` if `MHENRTPT == "BEFORE"`; else `"N"` |
| ANL01FL | `"Y"` |

Other variables (MHSEQ, MHTERM, MHDECOD, MHCAT, MHSTDTC) carry through unchanged from MH.

**Sort:** `(USUBJID, MHSEQ)`. **Expected: 2,061 rows.**

---

## Change log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Initial complete spec covering all 6 ADaM datasets (ADSL, ADAE, ADLB, ADTR, ADRS, ADTTE) with source → target traceability, derivation pseudocode, and QC check list for double programming. Aligned with v0.3 ADTTE (5 PARAMCDs including OSWOT for estimand E1b). |
| 0.2 | 2026-05-17 | LG (w/ Claude Opus 4.7) | Added §7–§12 for the 6 pharma-standard descriptive datasets: ADDS (disposition rollup, EOTFL), ADDV (deviations — synth-data limited), ADEX (DOSEAMT/CUMDOSE/RDI), ADCM (CMATC coalesce, ONTRTFL/PRIORFL/CONFL/CMIRAEFL), ADVS (baseline+change), ADMH (PCANCERFL/ONGOFL/PRIORFL, partial-date handling). ADaM total now 12 datasets. |
| 0.3 | 2026-05-17 | LG (w/ Claude Opus 4.7) | §8 ADDV rewritten — now sources real SDTM.DV (337 records, 190 subjects) instead of placeholder ADSL.PPROTFL. ADSL.PPROTFL redefined as "SAFFL=Y AND no MAJOR deviation" — PP population drops 449 → 412. T-EFF-08 (OS in PP) now meaningful: HR 0.545 vs ITT HR 0.576. Removes accepted limitations AL-02/AL-03/AL-09. |
| 0.4 | 2026-05-17 | LG (w/ Claude Opus 4.7) | §6 ADTTE: PFS PD dates now derive from SDTM.RS filtered by `RSEVAL='INDEPENDENT ASSESSOR'` (BICR primary); new PARAMCD `PFSINV` derives from `RSEVAL='INVESTIGATOR'` (estimand E2a sensitivity). ADTTE record count now 2,368 across 6 parameters (was 5). ADRS continues to use Investigator records for OVR/BOR/CBOR. Closes AL-04 + AL-07. §6 ADCM gains `SUBSQTFL` derivation (CMINDC ∈ {SUBSEQUENT ANTI-CANCER THERAPY, ANTINEOPLASTIC AGENTS}); OSWOT censoring extended to `pmin(TRTEDT+30d, SUBSQTDT, LSTALVDT)`. Closes AL-02 + AL-10. |

---

*Last updated: 2026-05-17*
