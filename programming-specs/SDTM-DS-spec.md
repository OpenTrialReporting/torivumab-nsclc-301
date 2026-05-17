# DS — Disposition — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DS |
| **Label** | Disposition |
| **Class** | EVENTS |
| **Structure** | One record per disposition event per subject |
| **Expected N** | 1,350 |
| **Key variables** | `STUDYID`, `USUBJID`, `DSSEQ` |
| **SDTMIG version** | v3.4 (§6.2) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DS records the protocol milestones and study-discontinuation events that drive ADSL population flags and reference dates: informed consent, randomisation, and end-of-study disposition. Three stacked record sets per subject produce ~3 rows × 450 subjects = 1,350 records. Downstream consumers: ADSL.RANDDT (DSDECOD="RANDOMIZED"), ADSL.EOSDT/EOSSTT/DCSREAS (DSCAT="DISPOSITION EVENT"), ADSL.PPROTFL (joined with DV).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/demographics.csv` | CDASH DM form | Informed-consent date (rec set A); randomisation date (rec set B, non-screen-failures only) |
| `raw/disposition.csv` | CDASH DS form | End-of-study disposition event (rec set C) — completion status, discontinuation reason, end date |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DS"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DSSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, DSSTDTC)` |
| 5 | DSTERM | Reported Term for the Disposition Event | Char | 200 | Derived | — | See §Derivations.D1 |
| 6 | DSDECOD | Standardized Disposition Term | Char | 200 | Derived | NCOMPLT/DSDECOD | See §Derivations.D1 + `map_disc_decode` |
| 7 | DSCAT | Category for Disposition Event | Char | 40 | Derived | — | `"PROTOCOL MILESTONE"` (rec A/B) or `"DISPOSITION EVENT"` (rec C) |
| 8 | DSSCAT | Subcategory for Disposition Event | Char | 40 | Derived | — | NA for milestones; `"STUDY DISCONTINUATION"` for non-completers in rec C; NA for completers |
| 9 | DSSTDTC | Start Date/Time of Disposition Event | Char | 10 | CRF | — | `INFORM_CONSENT_DATE` (A), `RAND_DATE` (B), `STUDY_COMPLETION_DATE` or `DISC_DATE` (C) |

## Derivations

### D1 — Three stacked record sets

**Set A — Informed consent (one per subject, from demographics):**
```
DSTERM   = "INFORMED CONSENT OBTAINED"
DSDECOD  = "INFORMED CONSENT OBTAINED"
DSCAT    = "PROTOCOL MILESTONE"
DSSCAT   = NA
DSSTDTC  = INFORM_CONSENT_DATE
```

**Set B — Randomisation (one per non-screen-failure subject):**
```
filter: NOT (SCREEN_FAIL in {"Y","1","TRUE"})
DSTERM   = "RANDOMIZED"
DSDECOD  = "RANDOMIZED"
DSCAT    = "PROTOCOL MILESTONE"
DSSCAT   = NA
DSSTDTC  = RAND_DATE
```

**Set C — End-of-study disposition (one per subject, from disposition.csv):**
```
completed = str_to_upper(str_trim(COMPLETION_STATUS)) in {COMPLETED, COMPLETE, Y, YES}
DSTERM   = completed ? "COMPLETED" : str_to_upper(str_trim(DISC_REASON))
DSDECOD  = completed ? "COMPLETED" : map_disc_decode(DISC_REASON)
DSCAT    = "DISPOSITION EVENT"
DSSCAT   = completed ? NA : "STUDY DISCONTINUATION"
DSSTDTC  = completed ? STUDY_COMPLETION_DATE : DISC_DATE
```

**`map_disc_decode` lookup (case-insensitive on trim+upper of `DISC_REASON`):**

| Raw → DSDECOD |
|---|
| `ADVERSE EVENT`, `AE` → `"ADVERSE EVENT"` |
| `WITHDRAWAL BY SUBJECT`, `WITHDREW CONSENT` → `"WITHDRAWAL BY SUBJECT"` |
| `PHYSICIAN DECISION` → `"PHYSICIAN DECISION"` |
| `LOST TO FOLLOW-UP` → `"LOST TO FOLLOW-UP"` |
| `DEATH` → `"DEATH"` |
| `PROGRESSIVE DISEASE` → `"PROGRESSIVE DISEASE"` |
| `PROTOCOL DEVIATION`, `PROTOCOL VIOLATION` → `"PROTOCOL DEVIATION"` |
| `OTHER` → `"OTHER"` |
| (unmatched) → trim+upper raw value (passthrough) |

**Final assembly:**
```
ds <- bind_rows(rec_A, rec_B, rec_C)
   |> arrange(USUBJID, DSSTDTC)
   |> group_by(USUBJID) |> mutate(DSSEQ = row_number()) |> ungroup()
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §2 for the consolidated derivation table.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| DSDECOD | NCOMPLT (C66727) + sponsor extensions for milestones | CDISC CT 2024-03; milestone terms `INFORMED CONSENT OBTAINED` / `RANDOMIZED` are sponsor-defined per SDTMIG convention |
| DSCAT | Sponsor | Values: `PROTOCOL MILESTONE`, `DISPOSITION EVENT` |
| DSSCAT | Sponsor | Value: `STUDY DISCONTINUATION` (when applicable) |

## QC Checks

- [ ] `nrow(ds) == 1350` (≈ 3 × 450)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `DSSEQ` strictly increasing per `USUBJID` (1, 2, 3) with no gaps
- [ ] No duplicate keys `(USUBJID, DSSEQ)`
- [ ] Every subject has exactly one `DSDECOD == "INFORMED CONSENT OBTAINED"` row
- [ ] Every non-screen-failure subject has exactly one `DSDECOD == "RANDOMIZED"` row (currently all 450)
- [ ] Every subject has exactly one `DSCAT == "DISPOSITION EVENT"` row
- [ ] `DSSTDTC` non-missing for all rows; ISO 8601 format
- [ ] `DSDECOD` for non-completers ∈ documented map keys (no unmapped raw passthroughs)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-DS-spec.md` | `programs/sdtm/ds.R` | `datasets/sdtm/ds.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
