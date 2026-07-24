# LB — Laboratory Test Results — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | LB |
| **Label** | Laboratory Test Results |
| **Class** | FINDINGS |
| **Structure** | One record per lab test per visit per subject |
| **Expected N** | 136,242 |
| **Key variables** | `STUDYID`, `USUBJID`, `LBSEQ` |
| **SDTMIG version** | v3.4 (§7.2.1) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

LB holds every laboratory measurement (haematology, chemistry, biomarkers) collected at scheduled visits including screening, every on-treatment cycle, end-of-treatment, and follow-up. Each row is one (test × visit × subject). Normal-range comparison (`LBNRIND`) is performed at the SDTM layer using `LBSTNRLO/LBSTNRHI` so ADLB can compute CTCAE shifts unambiguously. Biomarker rows (PDL1, EGFR, KRAS, etc.) are flagged via `SUPPLB.BIOMRKFL/CENTLBFL`. Downstream consumers: ADLB (BASETYPE, ANRIND shifts, CTCAE grades), T-LB-01 (mean over visit), T-LB-02 (worst grade shift), T-LB-03 (biomarker subgroup overlay on efficacy).

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
| 6 | LBTEST | Lab Test or Examination Name | Char | 40 | Derived | LBTEST | `dplyr::recode(LBTESTCD, ...)` — CDISC submission values keyed by `LBTESTCD` (ALB=Albumin, **ALP=Alkaline Phosphatase**, ALT, AST, BILI, CREAT, HGB=Hemoglobin, K=Potassium, NEUT, PLAT, SODIUM, WBC=Leukocytes); `.default = str_trim(TEST_NAME)` (P21 CT2002/CT2003 pair) |
| 7 | LBCAT | Category for Lab Test | Char | 40 | Derived | — | See §Derivations.D1 |
| 8 | LBORRES | Result or Finding in Original Units | Char | 40 | CRF | — | `as.character(RESULT_VALUE)` |
| 9 | LBORRESU | Original Units | Char | 40 | CRF | UNIT | `str_trim(RESULT_UNIT)` |
| 10 | LBORNRLO | Reference Range Lower Limit-Orig Units | Char | 40 | CRF | — | `as.character(LOWER_NORMAL)` — CHARACTER as-collected (P21 SD0057); orig-unit range = std-unit range (no SI conversion) |
| 11 | LBORNRHI | Reference Range Upper Limit-Orig Units | Char | 40 | CRF | — | `as.character(UPPER_NORMAL)` — CHARACTER as-collected (P21 SD0057) |
| 12 | LBSTRESC | Character Result/Finding in Std Format | Char | 40 | CRF | — | `as.character(RESULT_VALUE)` |
| 13 | LBSTRESN | Numeric Result/Finding in Std Units | Num | 8 | Derived | — | `suppressWarnings(as.numeric(RESULT_VALUE))` |
| 14 | LBSTRESU | Standard Units | Char | 40 | CRF | UNIT | `str_trim(RESULT_UNIT)` (assumed SI; no unit conversion applied at SDTM layer) |
| 15 | LBSTNRLO | Reference Range Lower Limit-Std Units | Num | 8 | CRF | — | `suppressWarnings(as.numeric(LOWER_NORMAL))` |
| 16 | LBSTNRHI | Reference Range Upper Limit-Std Units | Num | 8 | CRF | — | `suppressWarnings(as.numeric(UPPER_NORMAL))` |
| 17 | LBNRIND | Reference Range Indicator | Char | 10 | Derived | NRIND | See §Derivations.D2 |
| 18 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `LBDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `LBDTC` missing/partial |
| 19 | LBDTC | Date/Time of Specimen Collection | Char | 10 | CRF | — | `VISIT_DATE` (ISO 8601, direct) |
| 20 | LBDY | Study Day of Specimen Collection | Num | 8 | Derived | — | Study day of `LBDTC` vs `DM.RFSTDTC`: `LBDTC − RFSTDTC + 1` on/after RFSTDTC, else `LBDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 21 | VISITNUM | Visit Number | Num | 8 | Derived | — | per shared VISIT lookup (§Derivations.D3) |
| 22 | VISIT | Visit Name | Char | 40 | CRF | — | `str_to_upper(str_trim(VISIT_NAME))` |
| 23 | LBLOBXFL | Last Observation Before Exposure Flag | Char | 1 | Derived | NY | `= LBBLFL` — baseline/screening record is the last observation before first dose (P21 SD0057) |
| 24 | LBBLFL | Baseline Flag | Char | 1 | Derived | NY | `"Y"` if `VISITNUM == 0` OR `VISIT ∈ {SCREENING, SCR}`; else NA |

## Derivations

### D1 — LBCAT (haematology vs chemistry)

```
haem_codes = {HGB, NEUT, PLAT, WBC, LYMPH, RBC, HCT, MCH, MCHC, MCV}
LBCAT = if LBTESTCD in haem_codes then "HAEMATOLOGY" else "CHEMISTRY"
```

Biomarker `LBTESTCD` values (PDL1, EGFR, KRAS, ALK, ...) fall under `CHEMISTRY` at the parent layer; the SUPPLB `BIOMRKFL`/`CENTLBFL` qualifiers carry the biomarker / central-lab semantics.

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
   "EOT": 900, "END OF TREATMENT": 900,
   "FU1": 901, "FU2": 902, "FOLLOW-UP 1": 901, "FOLLOW-UP 2": 902
}
VISITNUM = visit_map[str_to_upper(str_trim(VISIT_NAME))]
# label-derived where not in visit_map (unique per VISIT -> P21 SD0051 bijection):
#   BASELINE            -> 0
#   MAINT_CnD1          -> 9 + n
#   TUMOR_ASSESS_WKn    -> n
#   UNSCHEDULED         -> 998   (single UNSCHEDULED<->998 mapping; date/seq disambiguate)
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

- [ ] `nrow(lb) == 136242` (±0.1%)
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

SUPPLB (BIOMRKFL, CENTLBFL) — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §20 / `programs/sdtm/supplb.R`.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refresh to current pipeline: Expected N 115,394 → 136,242 (ALP analyte added, +11,491). Documented ALP in the `LBTESTCD → LBTEST` recode and `LBCAT=CHEMISTRY` default. Added expected variables `LBORNRLO`/`LBORNRHI` (character orig-unit ranges) and `LBLOBXFL` (P21 SD0057). Corrected SUPPLB central-lab QNAM reference `CENTRALFL → CENTLBFL`. `UNSCHEDULED → VISITNUM 998` bijection already documented in D3. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `LBDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/lb.parquet`. |
