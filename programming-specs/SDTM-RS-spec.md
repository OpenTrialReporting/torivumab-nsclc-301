# RS — Disease Response — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | RS |
| **Label** | Disease Response |
| **Class** | FINDINGS |
| **Structure** | One overall-response record per assessment per reader (`RSEVAL`) per subject |
| **Expected N** | 2,260 |
| **Key variables** | `STUDYID`, `USUBJID`, `RSSEQ`; sort grouping `(USUBJID, RSDTC, RSEVAL)` |
| **SDTMIG version** | CDISC SDTM Oncology Disease Response Supplement §9.3 (RECIST 1.1, 2023) on SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

RS holds the **overall RECIST 1.1 response** per scheduled tumour assessment, separately for each reader stream (Investigator and Independent Assessor / BICR). Together with `TU` (identification) and `TR` (per-lesion measurements), RS is the SDTM substrate for `ADRS` (BoR / DoR), `ADTTE` PFS endpoints (PFS-INV and PFS-BICR), and the supportive ORR tables (T-EFF-03 INV, T-EFF-11 BICR).

**Dual-reader design (RECIST 1.1, blinded independent central review).**
Since v0.3 of the SDTM mapping spec (2026-05-17), each assessment carries one row per reader stream:
- `RSEVAL = "INVESTIGATOR"` — site-reported assessment.
- `RSEVAL = "INDEPENDENT ASSESSOR"` — BICR-reported assessment.

The raw simulator `programs/raw/10_overall_response.R` emits BICR rows in addition to investigator rows with ~10 % discordance and a conservative tilt (BICR is more likely to call SD where INV calls PR, and PD where INV calls SD — i.e., the BICR stream is biased to report a less favourable outcome, reflecting real-world adjudication bias). This dual-stream design closes accepted limitations AL-04 (`PFSINV` derivable) and AL-07 (`T-EFF-11` ≠ `T-EFF-03`).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/overall_response.csv` | CDASH Overall Response form (per reader) | One row per (subject, assessment date, reader); since 2026-05-17 raw emits both INV + BICR streams |
| Shared VISIT lookup | `programs/sdtm/SDTM-MAPPING-SPEC.md` §"Shared VISIT lookup" | Maps `VISIT_NAME` → `VISITNUM` |

**Raw columns:** `SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME, INVESTIGATOR_RESPONSE, ASSESSMENT_TYPE`.

Despite the legacy column name `INVESTIGATOR_RESPONSE`, the column carries the response for **whichever reader** the row represents (the reader identity is in `ASSESSMENT_TYPE`).

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"RS"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | RSSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, RSDTC, RSEVAL)` |
| 5 | RSTESTCD | Short Name of Measurement | Char | 8 | Assigned | RSTESTCD | Constant `"OVRLRESP"` |
| 6 | RSTEST | Name of Measurement | Char | 40 | Assigned | RSTEST | Constant `"Overall Response"` |
| 7 | RSCAT | Category | Char | 40 | Assigned | — | Constant `"OVERALL RESPONSE"` |
| 8 | RSEVAL | Evaluator (reader stream) | Char | 40 | Derived | RSEVAL | See §Derivations.D1 — `"INVESTIGATOR"` or `"INDEPENDENT ASSESSOR"` |
| 9 | RSORRES | Result in Original Units | Char | 40 | Predecessor | NRRESP | `str_to_upper(str_trim(INVESTIGATOR_RESPONSE))` |
| 10 | RSSTRESC | Standardised Result (character) | Char | 40 | Predecessor | NRRESP | `str_to_upper(str_trim(INVESTIGATOR_RESPONSE))` |
| 11 | RSSTRESN | Standardised Result (numeric) | Num | 8 | Derived | — | See §Derivations.D2 |
| 12 | RSDTC | Date of Assessment | Char | 10 | Predecessor | ISO 8601 | `as.character(ASSESSMENT_DATE)` |
| 13 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 14 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |

## Derivations

### D1 — RSEVAL (reader stream)
**Rule:** Reader identity is mapped from raw `ASSESSMENT_TYPE` to SDTM CT-compliant strings. Default falls back to INVESTIGATOR if raw value is missing or unexpected (defensive — does not occur post-2026-05-17 simulator changes).
```r
RSEVAL = case_when(
  str_to_upper(str_trim(ASSESSMENT_TYPE)) == "BICR"         ~ "INDEPENDENT ASSESSOR",
  str_to_upper(str_trim(ASSESSMENT_TYPE)) == "INVESTIGATOR" ~ "INVESTIGATOR",
  TRUE                                                       ~ "INVESTIGATOR"
)
```

### D2 — RSSTRESN (numeric encoding of response)
**Rule:** Standard CDISC-aligned numeric ordering for response categories.

| RSSTRESC (trim+upper) | RSSTRESN |
|---|---|
| CR, COMPLETE RESPONSE, COMPLETE REMISSION | 1 |
| PR, PARTIAL RESPONSE | 2 |
| SD, STABLE DISEASE | 3 |
| PD, PROGRESSIVE DISEASE | 4 |
| NE, NOT EVALUABLE, NED | 5 |
| (other) | NA |

### D3 — Sort + sequencing
```r
rs <- rs |> arrange(USUBJID, RSDTC, RSEVAL) |>
            group_by(USUBJID) |> mutate(RSSEQ = row_number()) |> ungroup()
```
Both INV and BICR rows for the same `(USUBJID, RSDTC)` co-exist; `RSEVAL` breaks the tie. Alphabetical order places `"INDEPENDENT ASSESSOR"` before `"INVESTIGATOR"`.

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| RSTESTCD | C100945 (RSTESTCD, Oncology) | Only `OVRLRESP` |
| RSTEST | C100946 (RSTEST, Oncology) | Only `"Overall Response"` |
| RSCAT | Study-specific | Single value `"OVERALL RESPONSE"` |
| RSEVAL | C78735 (EVAL) | `INVESTIGATOR` / `INDEPENDENT ASSESSOR` |
| RSSTRESC | C99158 (NRRESP, RECIST 1.1) | CR / PR / SD / PD / NE |
| VISIT, VISITNUM | Shared VISIT lookup | — |

## QC Checks

- [ ] `nrow(rs) ≈ 2,260` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`.
- [ ] `RSSEQ` strictly increasing per `USUBJID`, no gaps starting at 1.
- [ ] `RSEVAL ∈ {"INVESTIGATOR", "INDEPENDENT ASSESSOR"}` only.
- [ ] Both reader streams present: `sum(RSEVAL == "INVESTIGATOR") > 0` AND `sum(RSEVAL == "INDEPENDENT ASSESSOR") > 0`.
- [ ] For most subjects, each `RSDTC` has both an INV row and a BICR row (1:1 paired) — discordance shows up as different `RSSTRESC` on otherwise paired rows, not as missing rows.
- [ ] `RSSTRESC ∈ {CR, PR, SD, PD, NE}`; no other values.
- [ ] `RSSTRESN ∈ {1, 2, 3, 4, 5}` aligned to `RSSTRESC` per §D2 (1:1 mapping).
- [ ] Discordance rate (INV vs BICR response per subject visit) ≈ 10 % overall, with the BICR-conservative bias documented in `programs/raw/10_overall_response.R`.
- [ ] `RSDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, RSDTC, RSEVAL)` reproduces row order.
- [ ] Every `(USUBJID, RSDTC)` pair appears in `RELREC` Relationship B linking RS → TR — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §21.2.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-RS-spec.md` | `programs/sdtm/rs.R` | `datasets/sdtm/rs.parquet` |

Downstream consumers:
- `ADRS` — BoR, DoR per `RSEVAL` (one record per subject per reader).
- `ADTTE` — `PFS-INV` (filter `RSEVAL == "INVESTIGATOR"`), `PFS-BICR` (filter `RSEVAL == "INDEPENDENT ASSESSOR"`).
- `T-EFF-03` ORR by Investigator (`RSEVAL == "INVESTIGATOR"`).
- `T-EFF-11` ORR by BICR (`RSEVAL == "INDEPENDENT ASSESSOR"`).
- `RELREC` Relationship B links each RS row to the same-date TR rows.

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §15 for the consolidated cross-domain pseudocode and §21.2 for RELREC.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/rs.R`. Captures dual-reader (`RSEVAL`) design introduced 2026-05-17 (closes AL-04, AL-07). |
