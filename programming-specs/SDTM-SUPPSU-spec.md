# SUPPSU — Supplemental Qualifiers for SU — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPSU |
| **Label** | Supplemental Qualifiers for SU |
| **Class** | RELATIONSHIP |
| **Structure** | One record per subject per TOBACCO SU record per QNAM |
| **Expected N** | Real records under canonical STUDYID (one row per subject with a TOBACCO SU entry whose `SUSCAT` decodes to a recognised smoking status) |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `IDVAR`, `IDVARVAL`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPSU carries the sponsor-defined standardised smoking status (`SMKSTAT`) derived from the parent SU domain's tobacco entries. This is the v0.4 rebuild (2026-05-17) that closes accepted limitation AL-01: it replaces the legacy artifact (which carried the wrong `STUDYID = "TORIVUMAB-NSCLC-301"` and was produced by a script absent from the repo) with a generator that runs under the canonical `STUDYID = "CTX-NSCLC-301"` and is reproducibly orchestrated by `00_run_sdtm.R`.

`SMKSTAT` feeds the ADSL/T-DM-01 baseline characteristics smoking-status row and supports per-protocol-waiver / exemption analyses in the safety SAP.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/su.parquet` | Parent SU domain | Provides `USUBJID`, `SUSEQ`, `SUTRT`, `SUSCAT`. The TOBACCO records carry the smoking-status decode used by `SMKSTAT`. |

## Variables

SUPP-- shape per SDTMIG §8.4 (consolidated in `programs/sdtm/SDTM-MAPPING-SPEC.md` §16, §17).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Assigned    | —      | Constant `"CTX-NSCLC-301"` |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —      | Constant `"SU"` |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —      | From parent SU |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —      | Constant `"SUSEQ"` |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Predecessor | —      | `as.character(SU.SUSEQ)` of the parent TOBACCO row |
| 6 | QNAM     | Qualifier Variable Name      | Char | 8   | Assigned    | QNAM   | See §QNAM Definitions |
| 7 | QLABEL   | Qualifier Variable Label     | Char | 40  | Assigned    | QLABEL | See §QNAM Definitions |
| 8 | QVAL     | Data Value                   | Char | 200 | Derived     | SMKSTAT | Decoded smoking status — see §QNAM Definitions |
| 9 | QORIG    | Origin                       | Char | 20  | Assigned    | QORIG  | Constant `"CRF"` |
| 10 | QEVAL   | Evaluator                    | Char | 20  | Assigned    | —      | `""` |

## QNAM Definitions

| QNAM | QLABEL | Type | Length | Source | Derivation logic |
|---|---|---|---|---|---|
| SMKSTAT | Smoking Status | Char | 20 | `SU.SUSCAT` (for `SU.SUTRT == "TOBACCO"`) | Decoded mapping over a case-insensitive trimmed `SUSCAT`: <br>• `"CURRENT USER" \| "CURRENT"` → `"CURRENT SMOKER"` <br>• `"FORMER USER" \| "FORMER"` → `"EX-SMOKER"` <br>• `"NEVER USED" \| "NEVER"` → `"NEVER SMOKED"` <br>• else → drop the row. QORIG=`"CRF"`. |

Only TOBACCO SU records contribute; one SUPPSU row is emitted per subject per TOBACCO SU record whose `SUSCAT` decodes to a recognised value.

## Derivations

```r
su <- read_parquet("datasets/sdtm/su.parquet")

tobacco <- su |>
  filter(toupper(trimws(SUTRT)) == "TOBACCO") |>
  mutate(
    SMKSTAT = case_when(
      toupper(trimws(SUSCAT)) %in% c("CURRENT USER","CURRENT") ~ "CURRENT SMOKER",
      toupper(trimws(SUSCAT)) %in% c("FORMER USER","FORMER")   ~ "EX-SMOKER",
      toupper(trimws(SUSCAT)) %in% c("NEVER USED","NEVER")     ~ "NEVER SMOKED",
      TRUE                                                       ~ NA_character_
    )
  )

suppsu <- tobacco |>
  filter(!is.na(SMKSTAT)) |>
  arrange(USUBJID) |>
  transmute(
    STUDYID  = "CTX-NSCLC-301",
    RDOMAIN  = "SU",
    USUBJID,
    IDVAR    = "SUSEQ",
    IDVARVAL = as.character(SUSEQ),
    QNAM     = "SMKSTAT",
    QLABEL   = "Smoking Status",
    QVAL     = SMKSTAT,
    QORIG    = "CRF",
    QEVAL    = ""
  )
```

**Sort:** `(USUBJID)` then `(USUBJID, as.integer(IDVARVAL), QNAM)` if multiple TOBACCO records per subject.

## QC Checks

- [ ] All rows carry `STUDYID == "CTX-NSCLC-301"` (legacy `"TORIVUMAB-NSCLC-301"` must NOT appear — this is the AL-01 regression check).
- [ ] `QNAM == "SMKSTAT"` only; `QVAL ∈ {"CURRENT SMOKER","EX-SMOKER","NEVER SMOKED"}`.
- [ ] Every `USUBJID` in SUPPSU exists in parent SU under a TOBACCO record with matching `SUSEQ`.
- [ ] `RDOMAIN == "SU"`, `IDVAR == "SUSEQ"`, `QORIG == "CRF"` for all rows.
- [ ] `SMKSTAT` distribution covers all three categories (sanity check on simulator).
- [ ] No `NA` in `QVAL` (NAs are dropped upstream by design).

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-SUPPSU-spec.md` → `programs/sdtm/suppsu.R` | `programs/sdtm/suppsu.R` → `datasets/sdtm/suppsu.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §17.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft for the v0.4 SUPPSU rebuild that closes AL-01 (canonical STUDYID, in-repo generator). |
