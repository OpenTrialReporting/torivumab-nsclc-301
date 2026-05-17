# SUPPCM — Supplemental Qualifiers for CM — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPCM |
| **Label** | Supplemental Qualifiers for CM |
| **Class** | RELATIONSHIP |
| **Structure** | One record per CM record per QNAM |
| **Expected N** | 4,444 |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `IDVAR`, `IDVARVAL`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPCM carries two sponsor-defined CM-level qualifiers: the WHO ATC classification code (held as a SUPP rather than a parent CM variable for SDTMIG conformance), and an irAE-management indicator that flags corticosteroids prescribed for immune-related adverse event treatment. The irAE flag drives the concomitant-medication irAE summary (T-CM-02) and the ADCM `CMIRAEFL` analysis flag.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/cm.parquet` | Parent CM domain | Provides `USUBJID`, `CMSEQ`, denormalised `CMATC`, and `CMINDC` for the irAE indication regex match. |

## Variables

SUPP-- shape per SDTMIG §8.4 (consolidated in `programs/sdtm/SDTM-MAPPING-SPEC.md` §16, §19).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Assigned    | —      | Constant `"CTX-NSCLC-301"` |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —      | Constant `"CM"` |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —      | From parent CM |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —      | Constant `"CMSEQ"` |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Predecessor | —      | `as.character(CM.CMSEQ)` |
| 6 | QNAM     | Qualifier Variable Name      | Char | 8   | Assigned    | QNAM   | See §QNAM Definitions |
| 7 | QLABEL   | Qualifier Variable Label     | Char | 40  | Assigned    | QLABEL | See §QNAM Definitions |
| 8 | QVAL     | Data Value                   | Char | 200 | Derived     | —      | See §QNAM Definitions |
| 9 | QORIG    | Origin                       | Char | 20  | Assigned    | QORIG  | `"ASSIGNED"` for CMATC; `"DERIVED"` for CMIRAEFL |
| 10 | QEVAL   | Evaluator                    | Char | 20  | Assigned    | —      | `""` |

## QNAM Definitions

| QNAM | QLABEL | Type | Length | Source | Derivation logic |
|---|---|---|---|---|---|
| CMATC    | WHO ATC Classification Code     | Char | 8   | `CM.CMATC`            | Pass-through from parent denormalised `CMATC` (§6.1 of MAPPING-SPEC). Emit one row per CM record where `CMATC` is non-NA and non-blank. QORIG=`"ASSIGNED"`. |
| CMIRAEFL | Prescribed for irAE Management  | Char | 1   | `CM.CMATC`, `CM.CMINDC` | `"Y"` if `str_starts(CMATC, "H02AB")` (corticosteroid prefix: prednisolone, methylprednisolone, dexamethasone, hydrocortisone) AND `toupper(CMINDC)` matches regex `IMMUNE\|IRAE\|COLITIS\|PNEUMONITIS\|HEPATITIS\|THYROIDITIS`; else `"N"`. Always emitted (one row per CM record). QORIG=`"DERIVED"`. |

## Derivations

```r
cm <- read_parquet("datasets/sdtm/cm.parquet")

cortico_atc_prefix <- "H02AB"   # prednisolone, methylpred, dex, hydrocortisone

supp_records <- cm |>
  mutate(
    CMATC_clean = ifelse(is.na(CMATC) | trimws(CMATC) == "", NA_character_, CMATC),
    is_steroid  = !is.na(CMATC_clean) & startsWith(CMATC_clean, cortico_atc_prefix),
    indc_irae   = !is.na(CMINDC) & grepl(
      "IMMUNE|IRAE|COLITIS|PNEUMONITIS|HEPATITIS|THYROIDITIS",
      toupper(CMINDC)
    ),
    CMIRAEFL    = ifelse(is_steroid & indc_irae, "Y", "N")
  )

supp_atc <- supp_records |>
  filter(!is.na(CMATC_clean)) |>
  transmute(
    STUDYID = "CTX-NSCLC-301", RDOMAIN = "CM", USUBJID,
    IDVAR = "CMSEQ", IDVARVAL = as.character(CMSEQ),
    QNAM = "CMATC", QLABEL = "WHO ATC Classification Code",
    QVAL = CMATC_clean, QORIG = "ASSIGNED", QEVAL = ""
  )

supp_irae <- supp_records |>
  transmute(
    STUDYID = "CTX-NSCLC-301", RDOMAIN = "CM", USUBJID,
    IDVAR = "CMSEQ", IDVARVAL = as.character(CMSEQ),
    QNAM = "CMIRAEFL", QLABEL = "Prescribed for irAE Management",
    QVAL = CMIRAEFL, QORIG = "DERIVED", QEVAL = ""
  )

suppcm <- bind_rows(supp_atc, supp_irae) |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)
```

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## QC Checks

- [ ] `nrow(suppcm) == 4444`.
- [ ] `QNAM ∈ {CMATC, CMIRAEFL}` only.
- [ ] CMATC rows: `QVAL` non-blank and matches `CM.CMATC` for the joined `CMSEQ`.
- [ ] CMIRAEFL rows: `QVAL ∈ {"Y","N"}`, emitted for every parent CM record.
- [ ] `RDOMAIN == "CM"`, `IDVAR == "CMSEQ"` for all rows.
- [ ] `QORIG == "ASSIGNED"` for CMATC; `QORIG == "DERIVED"` for CMIRAEFL.
- [ ] Sort matches `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-SUPPCM-spec.md` → `programs/sdtm/suppcm.R` | `programs/sdtm/suppcm.R` → `datasets/sdtm/suppcm.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §19.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft (covers v0.2 back-fill of SUPPCM released 2026-05-16). |
