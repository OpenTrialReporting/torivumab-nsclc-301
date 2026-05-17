# LB — Laboratory Test Results — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | LB |
| **Label** | Laboratory Test Results |
| **Class** | FINDINGS |
| **Structure** | One record per lab test per visit per subject |
| **Expected N** | 115,394 |
| **Key variables** | `STUDYID`, `USUBJID`, `LBSEQ` |
| **SDTMIG version** | v3.4 (§7.2.1) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

LB holds every laboratory measurement (haematology, chemistry, biomarkers) collected at scheduled visits including screening, every on-treatment cycle, end-of-treatment, and follow-up. Each row is one (test × visit × subject). Normal-range comparison (`LBNRIND`) is performed at the SDTM layer using `LBSTNRLO/LBSTNRHI` so ADLB can compute CTCAE shifts unambiguously. Biomarker rows (PDL1, EGFR, KRAS, etc.) are flagged via `SUPPLB.BIOMRKFL/CENTRALFL`. Downstream consumers: ADLB (BASETYPE, ANRIND shifts, CTCAE grades), T-LB-01 (mean over visit), T-LB-02 (worst grade shift), T-LB-03 (biomarker subgroup overlay on efficacy).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/labs.csv` | CDASH LB form (local labs) + central lab (biomarkers) | One row per (subject, visit, test) — value, unit, normal range, abnormal flag |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"LB"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | LBSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, LBDTC, LBTESTCD)` |
| 5 | LBTESTCD | Lab Test or Examination Short Name | Char | 8 | CRF | LBTESTCD | `str_to_upper(str_trim(TEST_CODE))` |
| 6 | LBTEST | Lab Test or Examination Name | Char | 40 | CRF | LBTEST | `str_trim(TEST_NAME)` |
| 7 | LBCAT | Category for Lab Test | Char | 40 | Derived | — | See §Derivations.D1 |
| 8 | LBORRES | Result or Finding in Original Units | Char | 40 | CRF | — | `as.character(RESULT_VALUE)` |
| 9 | LBORRESU | Original Units | Char | 40 | CRF | UNIT | `str_trim(RESULT_UNIT)` |
| 10 | LBSTRESC | Character Result/Finding in Std Format | Char | 40 | CRF | — | `as.character(RESULT_VALUE)` |
| 11 | LBSTRESN | Numeric Result/Finding in Std Units | Num | 8 | Derived | — | `suppressWarnings(as.numeric(RESULT_VALUE))` |
| 12 | LBSTRESU | Standard Units | Char | 40 | CRF | UNIT | `str_trim(RESULT_UNIT)` (assumed SI; no unit conversion applied at SDTM layer) |
| 13 | LBSTNRLO | Reference Range Lower Limit-Std Units | Num | 8 | CRF | — | `as.numeric(LOWER_NORMAL)` |
| 14 | LBSTNRHI | Reference Range Upper Limit-Std Units | Num | 8 | CRF | — | `as.numeric(UPPER_NORMAL)` |
| 15 | LBNRIND | Reference Range Indicator | Char | 10 | Derived | NRIND | See §Derivations.D2 |
| 16 | LBDTC | Date/Time of Specimen Collection | Char | 10 | CRF | — | `VISIT_DATE` (ISO 8601, direct) |
| 17 | VISITNUM | Visit Number | Num | 8 | Derived | — | per shared VISIT lookup (§Derivations.D3) |
| 18 | VISIT | Visit Name | Char | 40 | CRF | — | `str_to_upper(str_trim(VISIT_NAME))` |
| 19 | LBBLFL | Baseline Flag | Char | 1 | Derived | NY | `"Y"` if `VISITNUM == 0` OR `VISIT ∈ {SCREENING, SCR}`; else NA |

## Derivations

### D1 — LBCAT (haematology vs chemistry)

```
haem_codes = {HGB, NEUT, PLAT, WBC, LYMPH, RBC, HCT, MCH, MCHC, MCV}
LBCAT = if LBTESTCD in haem_codes then "HAEMATOLOGY" else "CHEMISTRY"
```

Biomarker `LBTESTCD` values (PDL1, EGFR, KRAS, ALK, ...) fall under `CHEMISTRY` at the parent layer; the SUPPLB `BIOMRKFL`/`CENTRALFL` qualifiers carry the biomarker / central-lab semantics.

### D2 — LBNRIND (priority: raw flag, then range comparison)

```
LBNRIND = case_when(
   ABNORMAL_FLAG (trim+upper) in {"H","HIGH"}            ~ "HIGH",
   ABNORMAL_FLAG (trim+upper) in {"L","LOW"}             ~ "LOW",
   ABNORMAL_FLAG (trim+upper) in {"N","NORMAL",""}       ~ "NORMAL",
   !is.na(LBSTRESN) & !is.na(LBSTNRHI) & LBSTRESN > LBSTNRHI ~ "HIGH",
   !is.na(LBSTRESN) & !is.na(LBSTNRLO) & LBSTRESN < LBSTNRLO ~ "LOW",
   !is.na(LBSTRESN)                                       ~ "NORMAL",
   TRUE                                                    ~ NA
)
```

Range comparison is the fallback when raw `ABNORMAL_FLAG` is missing — guarantees `LBNRIND` is populated whenever a numeric result and range exist.

### D3 — VISIT lookup (shared with VS, PE, TU, TR, RS)

```
visit_map = {
   "SCREENING": 0, "SCR": 0,
   "C1D1": 1, "C1D15": 2, "C2D1": 3, "C3D1": 4, "C4D1": 5,
   "C5D1": 6, "C6D1": 7, "C7D1": 8, "C8D1": 9,
   "EOT": 99, "END OF TREATMENT": 99,
   "FU1": 100, "FU2": 101, "FOLLOW-UP 1": 100, "FOLLOW-UP 2": 101
}
VISITNUM = visit_map[str_to_upper(str_trim(VISIT_NAME))]   # NA if unmatched
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` "Shared VISIT lookup" block.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| LBTESTCD | LBTESTCD (C65047) + sponsor extensions for biomarkers | CDISC CT 2024-03 |
| LBTEST | LBTEST (C67154) + sponsor extensions | CDISC CT 2024-03 |
| LBCAT | Sponsor | Values: `HAEMATOLOGY`, `CHEMISTRY` |
| LBORRESU / LBSTRESU | UNIT (C71620) | CDISC CT 2024-03 — SI units assumed |
| LBNRIND | NRIND (C78736) | CDISC CT 2024-03 — values `HIGH`, `LOW`, `NORMAL` |
| LBBLFL | NY (C66742) | CDISC CT 2024-03 |

## QC Checks

- [ ] `nrow(lb) == 115394` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `LBSEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, LBSEQ)`
- [ ] `LBDTC` non-missing and ISO 8601 for all rows
- [ ] `LBSTRESC == LBORRES` (no unit conversion at SDTM)
- [ ] `LBSTRESU == LBORRESU` (same — SI assumed)
- [ ] `LBNRIND ∈ {HIGH, LOW, NORMAL}` for all rows with non-NA `LBSTRESN` and non-NA range
- [ ] `LBBLFL == "Y"` rate ≈ 1 / number_of_visits per (subject, test)
- [ ] `LBCAT ∈ {HAEMATOLOGY, CHEMISTRY}` — no other values
- [ ] `VISITNUM` non-missing for ≥99% of rows (small fraction may be unscheduled / repeat)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-LB-spec.md` | `programs/sdtm/lb.R` | `datasets/sdtm/lb.parquet` |

SUPPLB (BIOMRKFL, CENTRALFL) — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §20 / `programs/sdtm/supplb.R`.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
