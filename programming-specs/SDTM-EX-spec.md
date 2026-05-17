# EX — Exposure — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | EX |
| **Label** | Exposure |
| **Class** | INTERVENTIONS |
| **Structure** | One record per study-drug administration per subject |
| **Expected N** | 11,710 |
| **Key variables** | `STUDYID`, `USUBJID`, `EXSEQ` |
| **SDTMIG version** | v3.4 (§6.3) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

EX captures every administered dose of investigational product (TORIVUMAB or PLACEBO) and the SoC chemotherapy backbone (CARBOPLATIN, PEMETREXED). Each row represents one administration at a scheduled visit. Downstream consumers: ADSL.TRTSDT/TRTEDT (first/last `EXSTDTC`), ADSL.SAFFL (≥1 EX record), ADEX (dose intensity, RDI), DA (drug accountability cross-check), all PK/exposure-response analyses.

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/exposure.csv` | CDASH EX form | One row per administration per subject — drug name, dose, dose unit, cycle/day, start/end dates |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"EX"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | EXSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, EXSTDTC, EXTRT)` |
| 5 | EXTRT | Name of Treatment | Char | 40 | CRF | EXTRT | `str_to_upper(str_trim(DRUG_NAME))` — values: `TORIVUMAB`, `PLACEBO`, `CARBOPLATIN`, `PEMETREXED` |
| 6 | EXDOSE | Dose | Num | 8 | CRF | — | `as.numeric(DOSE_MG)` |
| 7 | EXDOSU | Dose Units | Char | 10 | CRF | UNIT | `str_to_upper(str_trim(DOSE_UNIT))` — values: `mg`, `mg/m2`, `AUC` |
| 8 | EXROUTE | Route of Administration | Char | 40 | Assigned | ROUTE | Constant `"INTRAVENOUS"` |
| 9 | EXSTDTC | Start Date/Time of Treatment | Char | 10 | CRF | — | `START_DATE` (ISO 8601, direct) |
| 10 | EXENDTC | End Date/Time of Treatment | Char | 10 | CRF | — | `END_DATE` (direct; typically same day as START_DATE for IV bolus/infusion) |
| 11 | VISITNUM | Visit Number | Num | 8 | Derived | — | See §Derivations.D1 |
| 12 | VISIT | Visit Name | Char | 20 | Derived | VISIT | See §Derivations.D1 |
| 13 | EPOCH | Epoch | Char | 20 | Assigned | EPOCH | Constant `"TREATMENT"` (all EX records are on-treatment by definition) |

## Derivations

### D1 — VISIT / VISITNUM (from CYCLE_NUMBER + DAY_IN_CYCLE)

```
derive_visit(cycle, day):
   if cycle == 1 AND day == 1   ~ "C1D1",       VISITNUM = 1
   if cycle == 1 AND day == 15  ~ "C1D15",      VISITNUM = 2
   if cycle >= 2                ~ paste0("C", cycle, "D", day),
                                   VISITNUM = cycle + 1
   else                          ~ NA
```

Maximum observed cycle in synthetic data is C8D1 → VISITNUM = 9. This same `derive_visit` is shared (via copy) by LB, VS, PE, TU, TR, RS. See `programs/sdtm/SDTM-MAPPING-SPEC.md` §3.1.

### D2 — EXSEQ

```
sort by (USUBJID, EXSTDTC, EXTRT)
EXSEQ <- row_number() within USUBJID
```

EXTRT is included in the sort key so that multi-drug visits (e.g., C1D1: TORIVUMAB + CARBOPLATIN + PEMETREXED on the same day) sort deterministically by drug name.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| EXTRT | Sponsor | Values: `TORIVUMAB`, `PLACEBO`, `CARBOPLATIN`, `PEMETREXED` |
| EXDOSU | UNIT (C71620) | CDISC CT 2024-03 — `mg`, `mg/m2`, `AUC` |
| EXROUTE | ROUTE (C66729) | CDISC CT 2024-03 — constant `INTRAVENOUS` |
| EPOCH | EPOCH (C99079) | CDISC CT 2024-03 — constant `TREATMENT` |
| VISIT | Sponsor visit codelist | `C1D1`, `C1D15`, `C2D1`, ..., `C8D1` |

## QC Checks

- [ ] `nrow(ex) == 11710` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID` AND `USUBJID ∈` (subjects with `ADSL.SAFFL == "Y"`)
- [ ] `EXSEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, EXSEQ)`
- [ ] `EXSTDTC` non-missing for all rows; `EXENDTC >= EXSTDTC` where non-missing
- [ ] `EXTRT ∈ {TORIVUMAB, PLACEBO, CARBOPLATIN, PEMETREXED}` — no other values
- [ ] `EXDOSE > 0` for all rows (no zero-dose / held rows)
- [ ] `EXROUTE == "INTRAVENOUS"` for all rows
- [ ] `EPOCH == "TREATMENT"` for all rows
- [ ] `VISITNUM` non-missing for all rows (every administration occurs on a scheduled visit)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-EX-spec.md` | `programs/sdtm/ex.R` | `datasets/sdtm/ex.parquet` |

EX is the source for ADSL.TRTSDT/TRTEDT (see `programming-specs/ADSL-spec.md` §Derivations.D3/D4) and the parent for DA (drug accountability — see `programs/sdtm/da.R`).

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
