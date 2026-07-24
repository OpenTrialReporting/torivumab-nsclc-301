# TR — Tumor Results — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | TR |
| **Label** | Tumor / Lesion Results |
| **Class** | FINDINGS |
| **Structure** | One target-lesion longest-diameter (`LDIAM`) measurement per lesion per visit per subject |
| **Expected N** | 6,136 |
| **Key variables** | `STUDYID`, `USUBJID`, `TRSEQ`; group key `TRLNKID` (`TRTESTCD` constant `"LDIAM"`) |
| **SDTMIG version** | CDISC SDTM Oncology Disease Response Supplement §9.2 (RECIST 1.1, 2023) on SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

TR holds the per-lesion **target-lesion longest-diameter measurements** (`TRTESTCD == "LDIAM"`, mm) that underpin RECIST 1.1 assessments. Together with `TU` (identification) and `RS` (overall response), TR is the SDTM substrate for `ADTR` (target-lesion ADaM) and for the BoR / DOR / BoTL derivations in `ADRS` and `ADTTE` (PFS).

**Scope — LDIAM only.** `tr.R` retains only target-lesion `LDIAM` records. Non-target **overall response** (`OVRLRESP`) and **new-lesion** (`NEWLSN`) flags are *not* valid TR (Tumor/Lesion Results) test codes — those response assessments belong in `RS`, where the overall response already reflects them. Dropping them keeps TR clean of P21 CT2002 (`TRTESTCD`/`TRTEST`) findings.

This spec follows the CDISC SDTM Oncology Disease Response Supplement convention (RECIST 1.1, 2023).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/tumor_measurements.csv` | CDASH Tumor Assessment form (radiology read) | Same source as `TU` (identification) — TR pivots it into measurement records |
| Shared VISIT lookup | `programs/sdtm/SDTM-MAPPING-SPEC.md` §"Shared VISIT lookup" | Maps `VISIT_NAME` → `VISITNUM` |

**Raw columns:** `SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME, LESION_ID, LESION_TYPE, ANATOMICAL_LOCATION, LONGEST_DIAMETER_MM, RESPONSE_CATEGORY, NEW_LESION`.

## Record Set (target-lesion measurement)

TR contains a single record set. A raw row contributes one `LDIAM` record when it is a target lesion with a non-missing longest diameter:

| Set | Filter on raw row | TRTESTCD | TRTEST | TRORRES / TRSTRESC | TRSTRESN | TRSTRESU |
|---|---|---|---|---|---|---|
| **Target lesion** | `TRGRPID == "TARGET"` AND `LONGEST_DIAMETER_MM` not NA | `LDIAM` | "Longest Diameter" | `as.character(LONGEST_DIAMETER_MM)` | `as.numeric(LONGEST_DIAMETER_MM)` | `"mm"` |

Non-target `OVRLRESP` and `NEWLSN` sets described in earlier drafts are **no longer produced** (see §Purpose — they belong in `RS`).

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"TR"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | TRSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, TRDTC, TRLNKID, TRTESTCD)` |
| 5 | TRTESTCD | Short Name of Measurement | Char | 8 | Derived | TRTESTCD | Constant `"LDIAM"` |
| 6 | TRTEST | Name of Measurement | Char | 40 | Derived | TRTEST | Constant `"Longest Diameter"` |
| 7 | TRORRES | Result in Original Units | Char | 40 | Derived | — | `as.character(LONGEST_DIAMETER_MM)` |
| 8 | TRORRESU | Original Units | Char | 20 | Assigned | UNIT | Constant `"mm"` (P21 SD0057) |
| 9 | TRSTRESC | Standardised Result (character) | Char | 40 | Derived | — | `as.character(LONGEST_DIAMETER_MM)` |
| 10 | TRSTRESN | Standardised Result (numeric) | Num | 8 | Derived | — | `as.numeric(LONGEST_DIAMETER_MM)` |
| 11 | TRSTRESU | Standardised Units | Char | 20 | Assigned | UNIT | Constant `"mm"` |
| 12 | TRMETHOD | Method of Assessment | Char | 40 | Assigned | METHOD | Constant `"CT SCAN"` (RECIST imaging method, P21 SD0057) |
| 13 | TRLOBXFL | Last Obs Before Exposure Flag | Char | 1 | Derived | NY | `"Y"` when `VISITNUM == 0` (screening = last tumour assessment before first dose), else NA (P21 SD0057) |
| 14 | TREVAL | Evaluator | Char | 40 | Assigned | EVAL | Constant `"INVESTIGATOR"` (local investigator read, P21 SD0057) |
| 15 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `TRDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `TRDTC` missing/partial |
| 16 | TRDTC | Date of Assessment | Char | 10 | Predecessor | ISO 8601 | `as.character(ASSESSMENT_DATE)` |
| 17 | TRDY | Study Day of Assessment | Num | 8 | Derived | — | Study day of `TRDTC` vs `DM.RFSTDTC`: `TRDTC − RFSTDTC + 1` on/after RFSTDTC, else `TRDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 18 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 19 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |
| 20 | TRGRPID | Group ID | Char | 40 | Derived | TRGRPID | See §Derivations.D1 — constant `"TARGET"` (only target lesions retained); identical mapping to `TU.TUGRPID` |
| 21 | TRLNKID | Link Identifier (lesion key) | Char | 40 | Predecessor | — | `as.character(LESION_ID)` — joins to `TU.TULNKID` (RELREC Relationship A) |

## Derivations

### D1 — TRGRPID
```r
TRGRPID = case_when(
  str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT")                 ~ "TARGET",
  str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
  TRUE                                                                         ~ str_to_upper(str_trim(LESION_TYPE))
)
```

### D2 — Target-lesion record build (pseudocode)
```r
raw <- raw |> mutate(USUBJID, TRDTC = ASSESSMENT_DATE, TRGRPID = <D1>, TRLNKID = as.character(LESION_ID))

tr_target <- raw |> filter(TRGRPID == "TARGET", !is.na(LONGEST_DIAMETER_MM)) |>
                    mutate(TRTESTCD="LDIAM",   TRTEST="Longest Diameter",
                           TRORRES=as.character(LONGEST_DIAMETER_MM), TRORRESU="mm",
                           TRSTRESC=as.character(LONGEST_DIAMETER_MM),
                           TRSTRESN=as.numeric(LONGEST_DIAMETER_MM), TRSTRESU="mm",
                           TRMETHOD="CT SCAN", TREVAL="INVESTIGATOR",
                           TRLOBXFL=ifelse(VISITNUM == 0L & !is.na(VISITNUM), "Y", NA_character_))

tr <- tr_target |>                                  # OVRLRESP / NEWLSN sets no longer produced (belong in RS)
      arrange(USUBJID, TRDTC, TRLNKID, TRTESTCD) |>
      group_by(USUBJID) |> mutate(TRSEQ = row_number()) |> ungroup()
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| TRTESTCD | C100945 (TRTESTCD, Oncology) | `LDIAM` only |
| TRTEST | C100946 (TRTEST, Oncology) | "Longest Diameter" only |
| TRORRESU, TRSTRESU | UNIT (C71620) | `mm` only |
| TRMETHOD | C85492 (METHOD) | `CT SCAN` only |
| TREVAL | C78735 (EVAL) | `INVESTIGATOR` only |
| TRLOBXFL | C66742 (NY) | `Y` / null |
| TRGRPID | Study-specific (RECIST 1.1) | `TARGET` only (non-target/new not retained) |
| VISIT, VISITNUM | Shared VISIT lookup | — |

## QC Checks

- [ ] `nrow(tr) ≈ 6,136` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`.
- [ ] `TRSEQ` strictly increasing per `USUBJID` with no gaps starting at 1.
- [ ] `TRTESTCD == "LDIAM"` for every row (no `OVRLRESP` / `NEWLSN`).
- [ ] `TRSTRESN > 0`, `TRSTRESU == "mm"`, and `TRORRESU == "mm"` on every row.
- [ ] `TREVAL == "INVESTIGATOR"` and `TRMETHOD == "CT SCAN"` on every row.
- [ ] `TRLOBXFL == "Y"` only when `VISITNUM == 0`; null otherwise.
- [ ] Every `TRLNKID` exists in `TU.TULNKID` for the same `USUBJID` (RELREC A integrity).
- [ ] `TRDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, TRDTC, TRLNKID, TRTESTCD)` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-TR-spec.md` | `programs/sdtm/tr.R` | `datasets/sdtm/tr.parquet` |

Downstream consumers: `RELREC` (Relationship A `TU↔TR`, Relationship B `RS↔TR` on assessment date), `ADTR` (target-lesion ADaM, `LDIAM` records only), `ADRS` (BoR derivation), `ADTTE` (PFS-INV / PFS-BICR).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §14 for the consolidated cross-domain pseudocode and §21 for RELREC build.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/tr.R`. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refresh vs current `tr.R`: TR now LDIAM-only (dropped `OVRLRESP`/`NEWLSN` sets → moved to RS); Expected N 7,724 → 6,136; added expected vars `TRORRESU`, `TRMETHOD`, `TREVAL`, `TRLOBXFL` (P21 SD0057); link-id variable named `TRLNKID` (was `TRLINKID`); updated Record Set, D2 pivot, CT and QC accordingly. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `TRDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/tr.parquet`. |
