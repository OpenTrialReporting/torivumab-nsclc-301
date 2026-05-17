# RELREC — Related Records — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | RELREC |
| **Label** | Related Records |
| **Class** | RELATIONSHIP |
| **Structure** | One record per related-record participant (deduped) |
| **Expected N** | Deduped per unique relationship (see §QC; v0.4 dedup 2026-05-17 closes AL-11) |
| **Key variables** | `STUDYID`, `USUBJID`, `RDOMAIN`, `RELID`, `IDVAR`, `IDVARVAL` |
| **SDTMIG version** | v3.4 (§8.5) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

RELREC declares record-level cross-domain relationships beyond what implicit `--LNKID` variables already convey, per SDTMIG §8.5. For CTX-NSCLC-301 it carries two stacked relationship sets that are essential for tumour-response traceability:

1. **Lesion identity** — links each TU "one" row (lesion identity record) to its TR "many" rows (per-visit measurements) through `TULINKID`/`TRLINKID`.
2. **Visit response** — links each RS "one" row (overall response assessment) to the TR "many" rows performed on the same `(USUBJID, date)`.

This deduped output is the v0.4 rebuild (2026-05-17) that closes AL-11.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/tu.parquet` | TU domain | Lesion identity records (provides `TULINKID`). |
| `datasets/sdtm/tr.parquet` | TR domain | Per-visit lesion measurements (provides `TRLINKID`, `TRSEQ`, `TRDTC`). |
| `datasets/sdtm/rs.parquet` | RS domain | Overall response assessments (provides `RSSEQ`, `RSDTC`). |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Predecessor | —      | From parent TU/TR/RS |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —      | `"TU"` / `"TR"` / `"RS"` per row |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —      | From parent domain |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —      | `"TULINKID"` / `"TRLINKID"` (lesion) or `"RSSEQ"` / `"TRSEQ"` (response) |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Derived     | —      | Value of `IDVAR` in parent (see §Derivations) |
| 6 | RELTYPE  | Relationship Type            | Char | 4   | Assigned    | RELTYPE | `"ONE"` or `"MANY"` |
| 7 | RELID    | Relationship Identifier      | Char | 100 | Derived     | —      | `"LESION-<linkid>"` or `"RESP-<USUBJID>-<date>"` |

## Relationship Definitions

### Relationship A — Lesion identity (TU ↔ TR via LNKID)

For each lesion identified across visits, link the TU "one" record(s) to the corresponding TR "many" records via `TULINKID`/`TRLINKID`.

| Side | Source | RDOMAIN | IDVAR | IDVARVAL | RELTYPE | RELID |
|---|---|---|---|---|---|---|
| ONE  | `TU` where `TULINKID` non-blank | `"TU"` | `"TULINKID"` | `as.character(TULINKID)` | `"ONE"`  | `paste0("LESION-", TULINKID)` |
| MANY | `TR` where `TRLINKID` non-blank | `"TR"` | `"TRLINKID"` | `as.character(TRLINKID)` | `"MANY"` | `paste0("LESION-", TRLINKID)` |

Each side is deduplicated via `distinct()` so the AL-11 fix collapses one row per (USUBJID, lesion) per side rather than per (USUBJID, lesion, visit).

### Relationship B — Visit response (RS ↔ TR via assessment date)

For each RS assessment, link the RS "one" record to the TR "many" records performed at the same `(USUBJID, date)`.

| Side | Source | RDOMAIN | IDVAR | IDVARVAL | RELTYPE | RELID |
|---|---|---|---|---|---|---|
| ONE  | `RS` where `RSDTC` non-blank                                | `"RS"` | `"RSSEQ"` | `as.character(RSSEQ)` | `"ONE"`  | `paste0("RESP-", USUBJID, "-", RSDTC)` |
| MANY | `TR INNER JOIN distinct(RS.USUBJID, RS.RSDTC) ON USUBJID = USUBJID AND TR.TRDTC = RS.RSDTC` | `"TR"` | `"TRSEQ"` | `as.character(TRSEQ)` | `"MANY"` | `paste0("RESP-", USUBJID, "-", TRDTC)` |

## Derivations

```r
tu <- read_parquet("datasets/sdtm/tu.parquet")
tr <- read_parquet("datasets/sdtm/tr.parquet")
rs <- read_parquet("datasets/sdtm/rs.parquet")

# --- A. Lesion identity ---
tu_rows <- tu |>
  filter(!is.na(TULINKID), TULINKID != "") |>
  transmute(STUDYID, RDOMAIN="TU", USUBJID,
            IDVAR="TULINKID", IDVARVAL=as.character(TULINKID),
            RELTYPE="ONE",  RELID=paste0("LESION-", TULINKID)) |>
  distinct()                                   # AL-11 fix (2026-05-17)

tr_lesion_rows <- tr |>
  filter(!is.na(TRLINKID), TRLINKID != "") |>
  transmute(STUDYID, RDOMAIN="TR", USUBJID,
            IDVAR="TRLINKID", IDVARVAL=as.character(TRLINKID),
            RELTYPE="MANY", RELID=paste0("LESION-", TRLINKID)) |>
  distinct()

relrec_lesion <- bind_rows(tu_rows, tr_lesion_rows)

# --- B. Visit response ---
rs_rows <- rs |>
  filter(!is.na(RSDTC), RSDTC != "") |>
  transmute(STUDYID, RDOMAIN="RS", USUBJID,
            IDVAR="RSSEQ", IDVARVAL=as.character(RSSEQ),
            RELTYPE="ONE", RELID=paste0("RESP-", USUBJID, "-", RSDTC))

tr_resp_rows <- tr |>
  filter(!is.na(TRDTC), TRDTC != "") |>
  inner_join(rs |> select(USUBJID, RSDTC) |> distinct(),
             by = c("USUBJID"="USUBJID", "TRDTC"="RSDTC")) |>
  transmute(STUDYID, RDOMAIN="TR", USUBJID,
            IDVAR="TRSEQ", IDVARVAL=as.character(TRSEQ),
            RELTYPE="MANY", RELID=paste0("RESP-", USUBJID, "-", TRDTC))

relrec_resp <- bind_rows(rs_rows, tr_resp_rows)

# --- Combine, dedup, sort ---
relrec <- bind_rows(relrec_lesion, relrec_resp) |>
  distinct(STUDYID, USUBJID, RDOMAIN, IDVAR, IDVARVAL, RELTYPE, RELID) |>
  arrange(STUDYID, USUBJID, RELID, RDOMAIN, IDVARVAL) |>
  transmute(STUDYID, RDOMAIN, USUBJID, IDVAR, IDVARVAL, RELTYPE, RELID)
```

**Sort:** `(STUDYID, USUBJID, RELID, RDOMAIN, IDVARVAL)`.

## QC Checks

- [ ] No duplicate rows on `(STUDYID, USUBJID, RDOMAIN, IDVAR, IDVARVAL, RELTYPE, RELID)` — AL-11 regression check.
- [ ] Every `RELID` has ≥1 `RELTYPE == "ONE"` row AND ≥1 `RELTYPE == "MANY"` row (RELREC integrity per SDTMIG).
- [ ] All `LESION-*` rows have `RDOMAIN ∈ {"TU","TR"}` and `IDVAR ∈ {"TULINKID","TRLINKID"}`.
- [ ] All `RESP-*` rows have `RDOMAIN ∈ {"RS","TR"}` and `IDVAR ∈ {"RSSEQ","TRSEQ"}`.
- [ ] Every `USUBJID` in RELREC exists in DM.
- [ ] Sort matches `(STUDYID, USUBJID, RELID, RDOMAIN, IDVARVAL)`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-RELREC-spec.md` → `programs/sdtm/relrec.R` | `programs/sdtm/relrec.R` → `datasets/sdtm/relrec.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §21.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft for the v0.4 RELREC rebuild — adds final `distinct()` on (STUDYID, USUBJID, RDOMAIN, IDVAR, IDVARVAL, RELTYPE, RELID) closing AL-11. |
