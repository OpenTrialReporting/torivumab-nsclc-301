# ADCM — Concomitant Medications Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADCM |
| **Label** | Concomitant Medications Analysis Dataset |
| **Class** | OCCDS |
| **Structure** | One record per medication occurrence per subject |
| **Expected N** | 2,197 |
| **Key variables** | `STUDYID`, `USUBJID`, `CMSEQ` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADCM supports descriptive concomitant medication summaries (T-CM-01 / T-CM-02) and the irAE-management cross-tab (T-AE-05 support). It also carries `SUBSQTFL`, the post-treatment subsequent-anti-cancer-therapy flag used to censor OSWOT (ADTTE PARAMCD=OSWOT) for estimand E1b — closing accepted limitation AL-02. On-treatment / prior / concomitant timing flags are derived against `ADSL.TRTSDT` / `ADSL.TRTEDT`.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates (TRTSDT, TRTEDT), population flags, treatment arm |
| SDTM.CM | `sdtm/cm.parquet` | Medication records, ATC code, indication, route |
| SDTM.SUPPCM | `sdtm/suppcm.parquet` | `CMATC` fallback, `CMIRAEFL` (irAE-management indicator) |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `CM.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `CM.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `CM.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `CM.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 8 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 9 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 10 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 11 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTSDT |
| 12 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTEDT |
| 13 | CMSEQ | Sequence Number | Num | 8 | Predecessor | — | `CM.CMSEQ` |
| 14 | CMTRT | Reported Name of Medication | Char | 200 | Predecessor | — | `CM.CMTRT` |
| 15 | CMDECOD | Standardized Medication Name | Char | 200 | Predecessor | WHO-DD | `CM.CMDECOD` |
| 16 | CMATC | Anatomical Therapeutic Chemical Class | Char | 20 | Derived | ATC | `coalesce(CM.CMATC, SUPPCM.CMATC)` |
| 17 | CMINDC | Indication | Char | 200 | Predecessor | — | `CM.CMINDC` |
| 18 | CMROUTE | Route of Administration | Char | 40 | Predecessor | ROUTE | `CM.CMROUTE` |
| 19 | CMSTDTC | Start Date/Time of Medication | Char | 20 | Predecessor | — | `CM.CMSTDTC` |
| 20 | CMENDTC | End Date/Time of Medication | Char | 20 | Predecessor | — | `CM.CMENDTC` |
| 21 | ASTDT | Analysis Start Date | Num | 8 | Derived | — | `as.Date(CMSTDTC)` |
| 22 | AENDT | Analysis End Date | Num | 8 | Derived | — | `as.Date(CMENDTC)` |
| 23 | ASTDY | Analysis Start Day | Num | 8 | Derived | — | `as.integer(ASTDT - TRTSDT) + 1` |
| 24 | AENDY | Analysis End Day | Num | 8 | Derived | — | `as.integer(AENDT - TRTSDT) + 1` (NA if AENDT NA) |
| 25 | PRIORFL | Prior Medication Flag | Char | 1 | Derived | NY | See §Derivations.D1 |
| 26 | CONFL | Concomitant Medication Flag | Char | 1 | Derived | NY | = ONTRTFL (concomitant ≡ on-treatment in this study) |
| 27 | ONTRTFL | On-Treatment Medication Flag | Char | 1 | Derived | NY | See §Derivations.D2 |
| 28 | CMIRAEFL | irAE-Management Medication Flag | Char | 1 | Derived | NY | SUPPCM QNAM='CMIRAEFL'; default `"N"` if missing |
| 29 | SUBSQTFL | Subsequent Anti-Cancer Therapy Flag | Char | 1 | Derived | NY | See §Derivations.D3 |
| 30 | ANL01FL | Analysis Flag 01 | Char | 1 | Derived | NY | `"Y"` for all records |
| 31 | AVAL | Analysis Value | Num | 8 | Derived | — | `NA` (OCCDS — no analysis value) |

## Derivations

### D1 — PRIORFL (prior-medication flag)

**Rule:** Medication started AND ended strictly before TRTSDT.

**Pseudocode:**
```r
PRIORFL = if_else(
  !is.na(ASTDT) & !is.na(TRTSDT) &
    ASTDT < TRTSDT &
    (!is.na(AENDT) & AENDT < TRTSDT),
  "Y", "N"
)
```

### D2 — ONTRTFL (on-treatment flag)

**Rule:** Medication overlaps any part of the treatment window `[TRTSDT, TRTEDT]`. An open-ended medication (AENDT NA) that started by TRTEDT is considered on-treatment.

**Pseudocode:**
```r
ONTRTFL = if_else(
  !is.na(ASTDT) & !is.na(TRTSDT) &
    ASTDT <= TRTEDT &
    (is.na(AENDT) | AENDT >= TRTSDT),
  "Y", "N"
)
CONFL = ONTRTFL
```

### D3 — SUBSQTFL (subsequent anti-cancer therapy flag) — closes AL-02

**Rule:** Flag `"Y"` when `CMINDC` (upper-cased) is one of `{"SUBSEQUENT ANTI-CANCER THERAPY", "ANTINEOPLASTIC AGENTS"}`. Used downstream by ADTTE OSWOT censoring (`pmin(TRTEDT+30d, SUBSQTDT, LSTALVDT)`).

**Pseudocode:**
```r
SUBSQTFL = if_else(
  !is.na(CMINDC) &
    toupper(CMINDC) %in% c("SUBSEQUENT ANTI-CANCER THERAPY",
                            "ANTINEOPLASTIC AGENTS"),
  "Y", "N"
)
```

**Edge cases:** If CMINDC vocabulary expands (e.g. additional WHO-DD strings for subsequent therapy), update D3 and re-run ADTTE OSWOT.

## QC Checks

- [ ] `nrow(adcm) == 2197` (within ±1%).
- [ ] All ONTRTFL, PRIORFL, CONFL, CMIRAEFL, SUBSQTFL, ANL01FL ∈ {"Y", "N"}; no NAs.
- [ ] `ONTRTFL == "Y"` implies `ASTDT <= TRTEDT`.
- [ ] `PRIORFL == "Y"` implies `AENDT < TRTSDT`.
- [ ] `CONFL == ONTRTFL` for every row.
- [ ] `CMATC` non-missing rate matches expected SUPPCM coverage.
- [ ] `sum(SUBSQTFL == "Y")` > 0 (synthetic data seeds ≥1 subsequent therapy per arm).
- [ ] Variable labels, lengths, types match this spec.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADCM-spec.md` → `programs/adam/adcm.R` | `programs/adam/adcm.R` → `datasets/adam/adcm.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
