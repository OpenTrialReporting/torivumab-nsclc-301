# ADVS — Vital Signs Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADVS |
| **Label** | Vital Signs Analysis Dataset |
| **Class** | BDS |
| **Structure** | One record per subject per parameter per visit |
| **Expected N** | ~52,864 |
| **Key variables** | `STUDYID`, `USUBJID`, `PARAMCD`, `AVISITN` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

ADVS supports the vital-signs summary by visit (T-VS-01) and the change-from-baseline tables (T-VS-02). It carries baseline (BASE), change (CHG) and percent change (PCHG) per parameter per subject so safety analyses can render shift summaries without re-deriving baseline per table.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags, treatment arm |
| SDTM.VS | `sdtm/vs.parquet` | Vital sign measurements, standard units, visit |

## Parameters

| PARAMCD | PARAM (VSTEST) | Notes |
|---|---|---|
| SYSBP | Systolic Blood Pressure | mmHg |
| DIABP | Diastolic Blood Pressure | mmHg |
| HR | Heart Rate | beats/min |
| WEIGHT | Weight | kg |
| HEIGHT | Height | cm (typically single screening reading) |
| TEMP | Temperature | C |
| RESP | Respiratory Rate | breaths/min |

`PARAMN = integer rank of PARAMCD` (alphabetical, derived via `match()` on sorted unique values).

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `VS.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `VS.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `VS.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `VS.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 8 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 9 | TRT01PN | Planned Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01PN |
| 10 | TRT01AN | Actual Treatment (N) | Num | 8 | Derived | — | Merged from ADSL.TRT01AN |
| 11 | TRTSDT | Date of First Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTSDT |
| 12 | TRTEDT | Date of Last Exposure to Treatment | Num | 8 | Derived | — | Merged from ADSL.TRTEDT |
| 13 | VSSEQ | Sequence Number | Num | 8 | Predecessor | — | `VS.VSSEQ` |
| 14 | PARAM | Parameter | Char | 100 | Derived | — | `VS.VSTEST` |
| 15 | PARAMCD | Parameter Code | Char | 10 | Derived | VSTESTCD | `VS.VSTESTCD` |
| 16 | PARAMN | Parameter Number | Num | 8 | Derived | — | `match(PARAMCD, sort(unique(PARAMCD)))` |
| 17 | ADT | Analysis Date | Num | 8 | Derived | — | `as.Date(VS.VSDTC)` |
| 18 | ADY | Analysis Relative Day | Num | 8 | Derived | — | `as.integer(ADT - TRTSDT) + 1` |
| 19 | VISIT | Visit Name | Char | 40 | Predecessor | — | `VS.VISIT` (retained for traceability) |
| 20 | VISITNUM | Visit Number | Num | 8 | Predecessor | — | `VS.VISITNUM` |
| 21 | AVISIT | Analysis Visit | Char | 40 | Derived | — | `derive_avisit_windowed(ADY, VISIT, VISITNUM, "TREATMENT")`: nearest scheduled visit by `ADY` (SAP §12.2 window reference); `EOT`/follow-up kept by collected role |
| 22 | AVISITN | Analysis Visit (N) | Num | 8 | Derived | — | Numeric key of the windowed `AVISIT` (SDTM VISITNUM scheme: SCREENING 0, `C1D1…C6D1` 1…7, `MAINT_CnD1` 9+n, `TUMOR_ASSESS_WKn` n, EOT/FU 900/901/902) — SAP §12.2 |
| 23 | AVAL | Analysis Value | Num | 8 | Derived | — | `VS.VSSTRESN` |
| 24 | AVALC | Analysis Value (Char) | Char | 40 | Derived | — | `VS.VSSTRESC` |
| 25 | AVALU | Analysis Value Unit | Char | 10 | Derived | — | `VS.VSSTRESU` |
| 26 | BASE | Baseline Value | Num | 8 | Derived | — | See §Derivations.D2 |
| 27 | CHG | Change from Baseline | Num | 8 | Derived | — | `AVAL - BASE` |
| 28 | PCHG | Percent Change from Baseline | Num | 8 | Derived | — | `100 * (AVAL - BASE) / BASE` (NA if BASE NA or 0) |
| 29 | ABLFL | Baseline Record Flag | Char | 1 | Derived | NY | See §Derivations.D1 |
| 30 | ANL01FL | Analysis Flag 01 (analysis record per visit) | Char | 1 | Derived | NY | `flag_anl01()`: `"Y"` on the record closest to the visit target day per `USUBJID × PARAMCD × AVISIT` (ties → later `ADT`) — one analysis record per windowed visit (SAP §12.2) |

## Derivations

### D1 — ABLFL (baseline-record flag)

**Rule:** `"Y"` if the record is at a screening or Cycle 1 Day 1 visit AND occurs on or before the first dose; otherwise NA (left blank to align with ADaM convention for baseline flags).

**Pseudocode:**
```r
ABLFL = if_else(
  AVISIT %in% c("SCREENING", "SCR", "C1D1") & ADT <= TRTSDT,
  "Y", NA_character_
)
```

### D2 — BASE (baseline value)

**Rule:** Per (USUBJID, PARAMCD), the last non-missing `AVAL` among records with `ABLFL = "Y"` (ordered by ADT). Merged back onto every row of the same (USUBJID, PARAMCD).

**Pseudocode:**
```r
baseline <- advs %>%
  filter(ABLFL == "Y", !is.na(AVAL)) %>%
  arrange(USUBJID, PARAMCD, ADT) %>%
  group_by(USUBJID, PARAMCD) %>%
  summarise(BASE = last(AVAL), .groups = "drop")

advs <- advs %>% left_join(baseline, by = c("USUBJID", "PARAMCD"))
```

### D3 — CHG / PCHG (change and percent change)

**Pseudocode:**
```r
CHG  = AVAL - BASE
PCHG = if_else(!is.na(BASE) & BASE != 0,
                100 * (AVAL - BASE) / BASE,
                NA_real_)
```

**Edge cases:** Where no qualifying baseline record exists (subject missed screening for that parameter), BASE = NA → CHG and PCHG are NA. PCHG is NA where BASE = 0 (avoids divide-by-zero — typical only for derived parameters that ADVS does not currently carry).

## QC Checks

- [ ] `nrow(advs)` ≈ 52,864 (±1%).
- [ ] `PARAMCD` ∈ {SYSBP, DIABP, HR, WEIGHT, HEIGHT, TEMP, RESP}; no others.
- [ ] `ABLFL` is "Y" or NA only (never "N").
- [ ] For (USUBJID, PARAMCD) groups with any post-baseline row: `BASE` is non-missing OR no qualifying screening record existed.
- [ ] `CHG == AVAL - BASE` (where both non-missing).
- [ ] `PCHG` is NA wherever `BASE` is NA or 0.
- [ ] All `ANL01FL == "Y"`.
- [ ] Variable labels, lengths, types match this spec.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/ADVS-spec.md` → `programs/adam/advs.R` | `programs/adam/advs.R` → `datasets/adam/advs.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
