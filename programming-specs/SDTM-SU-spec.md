# SU — Substance Use — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SU |
| **Label** | Substance Use |
| **Class** | INTERVENTIONS |
| **Structure** | One record per substance per subject |
| **Expected N** | 1,229 |
| **Key variables** | `STUDYID`, `USUBJID`, `SUSEQ` |
| **SDTMIG version** | v3.4 (§6 Substance Use) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SU collects the subject's history of tobacco, alcohol, and (for completeness) other substance use captured on the CDASH SU form at screening. The domain feeds baseline characteristics tables (T-DM-02 / smoking status crosstabs) and supports the eligibility audit trail; pack-years on the tobacco record is preserved as `SUPACKYR` for downstream subgroup analyses. SU does **not** drive any efficacy or safety endpoint — its purpose is regulatory completeness per SDTMIG v3.4 (Substance Use class).

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
| 4 | SUSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, SUCAT)` — sort applied while `SUCAT` still holds the raw substance, before it is set to the constant below |
| 5 | SUTRT | Reported Name of Substance | Char | 40 | Predecessor | — | `str_to_upper(str_trim(SUBSTANCE))` (TOBACCO / ALCOHOL / …) |
| 6 | SUCAT | Category for Substance Use | Char | 40 | Assigned | — | Constant `"SUBSTANCE USE HISTORY"` (so `SUSCAT` is a valid, non-redundant subcategory — P21 SD1099/SD1039) |
| 7 | SUSCAT | Subcategory for Substance Use | Char | 40 | Predecessor | — | `str_to_upper(str_trim(USE_STATUS))` — carries the use status (CURRENT / FORMER / NEVER / …) |
| 8 | SUPACKYR | Pack-Years (study-specific) | Num | 8 | Predecessor | — | `suppressWarnings(as.numeric(PACK_YEARS))` — meaningful only for TOBACCO rows |

> Dropped from output vs. earlier drafts (code is source of truth): `SUOCCUR` (all-missing — P21 SD1078/SD1147), `SUSTDTC` (all-null for lifetime substance-use history — SD1078/SD0022), and `SUFREQ` (not in the SU model — SD0058). `SUPACKYRS` was renamed to the 8-char SDTM-valid `SUPACKYR`.

## Derivations

### D1 — SUOCCUR (computed helper; dropped from output)
**Rule:** Boolean occurrence flag mapped from free-text `USE_STATUS`. Computed for QC but **not** written to the SDTM output (all-missing after mapping — P21 SD1078/SD1147).
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
| SUTRT | C66781 (SUCAT subset) | Study uses TOBACCO, ALCOHOL |
| SUCAT | Sponsor | Constant `"SUBSTANCE USE HISTORY"` |
| SUSCAT | Study-specific (CURRENT / FORMER / NEVER / …) | Lifted from raw `USE_STATUS` |
| SUPACKYR | — | Non-CDISC, study-specific numeric variable; conformant home would be `SUPPSU` |

**Note (SUPPSU):** The legacy `suppsu.R` historically mirrored `SUPACKYRS` as a SUPPSU `QNAM`. Since v0.4 (2026-05-17), `SUPACKYRS` is carried natively on the parent SU row and SUPPSU is reserved for true non-standard exemption qualifiers — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §17 and SDTM-PROVENANCE §4.

## QC Checks

- [ ] `nrow(su) ≈ 1,229` (within ±0.1%).
- [ ] `USUBJID` non-missing; foreign key into `DM`.
- [ ] `SUSEQ` strictly increasing per `USUBJID`, no gaps starting at 1.
- [ ] `SUPACKYR` is non-missing only when `SUTRT == "TOBACCO"`.
- [ ] `SUCAT == "SUBSTANCE USE HISTORY"` for all rows; `SUTRT` values are a subset of {TOBACCO, ALCOHOL}.
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
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `su.R`: record count 1,236 → 1,229; reconciled variable table to actual output — dropped `SUOCCUR`/`SUSTDTC`/`SUFREQ` (P21 SD1078/SD1147/SD0058), renamed `SUPACKYRS` → `SUPACKYR`, and set `SUCAT` to the constant "SUBSTANCE USE HISTORY" (SUSCAT now carries use status); updated CT and QC. |
