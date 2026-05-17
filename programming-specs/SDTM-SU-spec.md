# SU — Substance Use — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SU |
| **Label** | Substance Use |
| **Class** | INTERVENTIONS |
| **Structure** | One record per substance per subject |
| **Expected N** | 1,236 |
| **Key variables** | `STUDYID`, `USUBJID`, `SUSEQ` |
| **SDTMIG version** | v3.4 (§6 Substance Use) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SU collects the subject's history of tobacco, alcohol, and (for completeness) other substance use captured on the CDASH SU form at screening. The domain feeds baseline characteristics tables (T-DM-02 / smoking status crosstabs) and supports the eligibility audit trail; pack-years on the tobacco record is preserved as `SUPACKYRS` for downstream subgroup analyses. SU does **not** drive any efficacy or safety endpoint — its purpose is regulatory completeness per SDTMIG v3.4 (Substance Use class).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/substance_use.csv` | CDASH SU form | One row per (subject, substance) |

**Raw columns:** `SUBJECT_ID, SUBSTANCE, USE_STATUS, PACK_YEARS, FREQUENCY`.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"SU"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | SUSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, SUCAT)` |
| 5 | SUTRT | Reported Name of Substance | Char | 40 | Predecessor | — | `str_to_upper(str_trim(SUBSTANCE))` |
| 6 | SUOCCUR | Substance Use Occurrence | Char | 1 | Derived | NY | See §Derivations.D1 |
| 7 | SUCAT | Category for Substance Use | Char | 40 | Predecessor | SUCAT | `str_to_upper(str_trim(SUBSTANCE))` (TOBACCO / ALCOHOL / …) |
| 8 | SUSCAT | Subcategory for Substance Use | Char | 40 | Predecessor | — | `str_to_upper(str_trim(USE_STATUS))` |
| 9 | SUSTDTC | Start Date/Time of Substance Use | Char | 10 | NA | — | Not collected (always NA per CDASH form) |
| 10 | SUPACKYRS | Pack-Years (study-specific) | Num | 8 | Predecessor | — | `suppressWarnings(as.numeric(PACK_YEARS))` — meaningful only for TOBACCO rows |
| 11 | SUFREQ | Substance Use Frequency | Char | 40 | Predecessor | SUFREQ | `str_to_upper(str_trim(FREQUENCY))` |

## Derivations

### D1 — SUOCCUR
**Rule:** Boolean occurrence flag mapped from free-text `USE_STATUS`.
```r
SUOCCUR = case_when(
  USE_STATUS_up %in% c("CURRENT", "EVER", "YES", "Y", "FORMER", "PAST") ~ "Y",
  USE_STATUS_up %in% c("NEVER", "NO", "N")                              ~ "N",
  TRUE                                                                   ~ NA_character_
)
```
(where `USE_STATUS_up = str_to_upper(str_trim(USE_STATUS))`)

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| SUTRT, SUCAT | C66781 (SUCAT subset) | Study uses TOBACCO, ALCOHOL |
| SUSCAT | Study-specific (CURRENT / FORMER / NEVER / …) | Lifted from raw `USE_STATUS` |
| SUOCCUR | NY (C66742) | Y / N / NA |
| SUFREQ | C71113 (FREQ) | DAILY / WEEKLY / OCCASIONAL / … |
| SUPACKYRS | — | Non-CDISC, study-specific numeric variable; promoted to SUPP via `SUPPSU` if needed |

**Note (SUPPSU):** The legacy `suppsu.R` historically mirrored `SUPACKYRS` as a SUPPSU `QNAM`. Since v0.4 (2026-05-17), `SUPACKYRS` is carried natively on the parent SU row and SUPPSU is reserved for true non-standard exemption qualifiers — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §17 and SDTM-PROVENANCE §4.

## QC Checks

- [ ] `nrow(su) ≈ 1,236` (within ±0.1%).
- [ ] `USUBJID` non-missing; foreign key into `DM`.
- [ ] `SUSEQ` strictly increasing per `USUBJID`, no gaps starting at 1.
- [ ] `SUOCCUR ∈ {Y, N, NA}` only.
- [ ] `SUPACKYRS` is non-missing only when `SUCAT == "TOBACCO"`.
- [ ] `SUCAT` values are a subset of the expected CDISC SUCAT codelist (TOBACCO, ALCOHOL).
- [ ] Sort key `(USUBJID, SUCAT)` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-SU-spec.md` | `programs/sdtm/su.R` | `datasets/sdtm/su.parquet` |

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §8 for cross-domain pseudocode and §17 for SUPPSU context.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/su.R`. |
