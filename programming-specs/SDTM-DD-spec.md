# DD — Death Details — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DD |
| **Label** | Death Details |
| **Class** | FINDINGS |
| **Structure** | One record per death per subject (single `PRCDTH` finding) |
| **Expected N** | 312 |
| **Key variables** | `STUDYID`, `USUBJID`, `DDSEQ` |
| **SDTMIG version** | CDISC SDTMIG Oncology Supplement (Death Details) on top of SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DD records the **primary cause of death** for every deceased subject, carried as the result (`DDORRES`/`DDSTRESC`) of the `PRCDTH` (Primary Cause of Death) test. It is the SDTM source for `ADSL.DTHCAUS` (via `admiral::derive_var_dthcaus()`) and underpins the cause-of-death sub-table in T-EFF-01 / L-DTH-01 listings. Only subjects who died on-study or in survival follow-up appear (one record per subject). Source data are collected on the dedicated CDASH Death CRF.

This spec follows the CDISC SDTM Oncology Disease Response Supplement convention of carrying death details in their own FINDINGS-class domain rather than mixing them with `DS`.

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/death.csv` | CDASH Death CRF | One row per deceased subject |

**Raw columns:** `SUBJECT_ID, DEATH_DATE, PRIMARY_CAUSE, CAUSE_DETAIL`.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DD"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DDSEQ | Sequence Number | Num | 8 | Assigned | — | Constant `1` (one DD per subject) |
| 5 | DDTESTCD | Short Name of Measurement | Char | 8 | Assigned | DDTESTCD | Constant `"PRCDTH"` (Primary Cause of Death) |
| 6 | DDTEST | Name of Measurement | Char | 40 | Assigned | DDTEST | Constant `"Primary Cause of Death"` |
| 7 | DDORRES | Result in Original Units | Char | 200 | Predecessor | — | `str_to_upper(str_trim(PRIMARY_CAUSE))` — the cause of death is the result of the `PRCDTH` test |
| 8 | DDSTRESC | Standardised Result (character) | Char | 200 | Derived | — | Same as `DDORRES` |
| 9 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `DDDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `DDDTC` missing/partial |
| 10 | DDDTC | Date of Death | Char | 10 | Predecessor | ISO 8601 | `as.character(DEATH_DATE)` |
| 11 | DDDY | Study Day of Death | Num | 8 | Derived | — | Study day of `DDDTC` vs `DM.RFSTDTC`: `DDDTC − RFSTDTC + 1` on/after RFSTDTC, else `DDDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |

> Dropped from output vs. earlier drafts (code is source of truth): `DDTERM` (non-standard — cause is now carried in the standard `DDORRES`, P21 SD0058), `DDCAT`, and `DDSCAT` (permissible/redundant "UNKNOWN" — SD1076/SD1040). `DDORRES`/`DDSTRESC` no longer carry the "Y" presence flag.

## Derivations

### D1 — DDORRES / DDSTRESC (cause of death)
**Rule:** The result of the `PRCDTH` test is the reported primary cause of death, carried in the standard `DDORRES` (and copied to `DDSTRESC`). No presence "Y" flag and no non-standard `DDTERM` are emitted.
```r
DDORRES  = str_to_upper(str_trim(PRIMARY_CAUSE))
DDSTRESC = str_to_upper(str_trim(PRIMARY_CAUSE))
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| DDTESTCD | C124296 (DDTESTCD, Oncology suppl.) | Only `PRCDTH` used here |
| DDTEST | C124297 (DDTEST, Oncology suppl.) | Only `"Primary Cause of Death"` |
| DDORRES, DDSTRESC | Free text mapped from raw `PRIMARY_CAUSE`; expected values include `"DISEASE PROGRESSION"`, `"ADVERSE EVENT"`, `"OTHER"`, `"UNKNOWN"` | Cause of death (result of the `PRCDTH` test) |

## QC Checks

- [ ] `nrow(dd) ≈ 312` (within ±0.1%).
- [ ] `n_distinct(USUBJID) == nrow(dd)` (exactly one row per dead subject).
- [ ] `DDSEQ == 1` for every row.
- [ ] `DDDTC` parses as ISO 8601 date; not in the future of `DCUTDT` (2025-01-31).
- [ ] Every `DD.USUBJID` exists in `DM` with `DM.DTHFL == "Y"` and `DM.DTHDTC` non-missing.
- [ ] `DDDTC == DM.DTHDTC` for every row (cross-domain consistency).
- [ ] `DDTESTCD == "PRCDTH"` and `DDTEST == "Primary Cause of Death"` for every row.
- [ ] `DDORRES == DDSTRESC`, both upper-case, trimmed; no NA values (cause of death present).
- [ ] Sort key `USUBJID` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-DD-spec.md` | `programs/sdtm/dd.R` | `datasets/sdtm/dd.parquet` |

Downstream consumers: `ADSL` (`DTHCAUS`, `DTHDT`), `ADTTE` (OS event reason listing), `ADAE` (FATAL outcome cross-check).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §9 for the consolidated cross-domain pseudocode.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/dd.R`. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `dd.R`: record count 284 → 312; test changed `DEATH` → `PRCDTH` ("Primary Cause of Death"); cause of death moved from non-standard `DDTERM` into the standard `DDORRES`/`DDSTRESC` (result of the `PRCDTH` test, P21 SD0058); dropped `DDTERM`/`DDCAT`/`DDSCAT`; updated derivations, CT, and QC. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `DDDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/dd.parquet`. |
