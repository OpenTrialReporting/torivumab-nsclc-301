# SUPPDM — Supplemental Qualifiers for DM — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPDM |
| **Label** | Supplemental Qualifiers for DM |
| **Class** | RELATIONSHIP |
| **Structure** | One record per subject per QNAM |
| **Expected N** | 1,799 |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPDM carries non-standard, sponsor-defined subject-level qualifiers that are conceptually part of DM but do not fit a standard SDTMIG DM variable. For CTX-NSCLC-301 it carries the baseline ECOG performance status, PD-L1 TPS score and group, and tumour histology stratum — all of which feed downstream ADaM derivations (ADSL.HISTSCAT, STRAT2; T-DM-01 baseline table).

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `raw/demographics.csv` | Subject-level CRF feed | Provides `ECOG_BASELINE`, `PDL1_SCORE`, `PDL1_GROUP`, `HISTOLOGY` columns. |

## Variables

SUPP-- shape per SDTMIG §8.4 (see `programs/sdtm/SDTM-MAPPING-SPEC.md` §16 for the consolidated shape).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Assigned    | —        | Constant `"CTX-NSCLC-301"` |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —        | Constant `"DM"` |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —        | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —        | `""` (subject-level) |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Assigned    | —        | `""` (subject-level) |
| 6 | QNAM     | Qualifier Variable Name      | Char | 8   | Assigned    | QNAM     | See §QNAM Definitions |
| 7 | QLABEL   | Qualifier Variable Label     | Char | 40  | Assigned    | QLABEL   | See §QNAM Definitions |
| 8 | QVAL     | Data Value                   | Char | 200 | Predecessor | —        | `as.character(raw[[source_col]])` |
| 9 | QORIG    | Origin                       | Char | 20  | Assigned    | QORIG    | `"CRF"` |
| 10 | QEVAL   | Evaluator                    | Char | 20  | Assigned    | —        | `""` |

## QNAM Definitions

| QNAM | QLABEL | Type | Length | Source column | Derivation logic |
|---|---|---|---|---|---|
| ECOGBSL  | ECOG Performance Status at Baseline | Char | 200 | `ECOG_BASELINE` | Direct pass-through. QORIG=`"CRF"`. |
| PDL1SCR  | PD-L1 TPS Score                     | Char | 200 | `PDL1_SCORE`    | Direct pass-through (numeric coerced to char). QORIG=`"CRF"`. |
| PDL1GRP  | PD-L1 TPS Group                     | Char | 200 | `PDL1_GROUP`    | Direct pass-through (e.g. `"50-100"`). QORIG=`"CRF"`. |
| HISTSCAT | Tumour Histology Stratum            | Char | 200 | `HISTOLOGY`     | Direct pass-through (`SQUAMOUS` / `NON-SQUAMOUS`). QORIG=`"CRF"`. |

A SUPPDM row is emitted for each (QNAM × raw row) where the source column is non-NA and non-blank.

## Derivations

```r
raw <- read.csv("raw/demographics.csv") |>
  mutate(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"))

supp_vars <- tribble(
  ~QNAM,      ~QLABEL,                               ~raw_col,
  "ECOGBSL",  "ECOG Performance Status at Baseline", "ECOG_BASELINE",
  "PDL1SCR",  "PD-L1 TPS Score",                     "PDL1_SCORE",
  "PDL1GRP",  "PD-L1 TPS Group",                     "PDL1_GROUP",
  "HISTSCAT", "Tumour Histology Stratum",            "HISTOLOGY"
)

# For each (QNAM, source col), emit one long row per non-blank raw value
supp_long <- bind_rows(lapply(seq_len(nrow(supp_vars)), function(i) {
  raw |>
    filter(!is.na(.data[[supp_vars$raw_col[i]]]),
           str_trim(as.character(.data[[supp_vars$raw_col[i]]])) != "") |>
    transmute(
      STUDYID, RDOMAIN = "DM", USUBJID,
      IDVAR = "", IDVARVAL = "",
      QNAM   = supp_vars$QNAM[i],
      QLABEL = supp_vars$QLABEL[i],
      QVAL   = as.character(.data[[supp_vars$raw_col[i]]]),
      QORIG  = "CRF", QEVAL = ""
    )
})) |>
  arrange(USUBJID, QNAM)
```

**Sort:** `(USUBJID, QNAM)`.

## QC Checks

- [ ] `nrow(suppdm) == 1799`.
- [ ] `n_distinct(USUBJID) == 450` and every subject in DM appears for QNAM=`HISTSCAT` (eligibility-mandated).
- [ ] `QNAM ∈ {ECOGBSL, PDL1SCR, PDL1GRP, HISTSCAT}` only.
- [ ] `IDVAR == "" & IDVARVAL == ""` for all rows (subject-level).
- [ ] `QORIG == "CRF"` for all rows.
- [ ] Variable lengths/labels match this spec via `xportr::xportr_*`.
- [ ] Sort order is `(USUBJID, QNAM)`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-SUPPDM-spec.md` → `programs/sdtm/suppdm.R` | `programs/sdtm/suppdm.R` → `datasets/sdtm/suppdm.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §16.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
