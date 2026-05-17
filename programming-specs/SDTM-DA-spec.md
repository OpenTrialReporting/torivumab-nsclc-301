# DA — Drug Accountability — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DA |
| **Label** | Drug Accountability |
| **Class** | INTERVENTIONS |
| **Structure** | One record per accountability test per drug per visit per subject |
| **Expected N** | 28,108 |
| **Key variables** | `STUDYID`, `USUBJID`, `DASEQ` |
| **SDTMIG version** | v3.4 (§6.5 Drug Accountability) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DA captures the per-visit accountability quantities (dispensed, used, returned, lost) for each study drug. The domain provides the audit trail required by ICH GCP §8.2.16 for IP accountability and is the SDTM source for the supply-management listings (L-DA-01) and the compliance summary (T-EXP-02). DA does **not** drive efficacy / safety endpoints — its role is regulatory / operational completeness.

Each raw dispensation event is pivoted long-form into 2–4 SDTM records depending on dose form (vialed product carries return / loss columns; compounded product does not).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/drug_accountability.csv` | CDASH DA form | One row per dispensation per drug per visit |

**Raw columns:** `SUBJECT_ID, VISIT_NAME, VISIT_DATE, DRUG_NAME, DOSE_FORM, AMT_DISPENSED, AMT_USED, AMT_RETURNED, AMT_LOST, AMT_UNIT, COMPLIANCE_PCT, ACCOUNTABILITY_DATE, DISPENSED_BY`.

## Long-form pivot

Each raw row is exploded into one row per accountability test (`DATESTCD`):

| DOSE_FORM | Drugs | DATESTCD records emitted | DATEST |
|---|---|---|---|
| `VIAL` | TORIVUMAB, PLACEBO | DISPAMT, USEDAMT, RETAMT, LOSTAMT | "Amount Dispensed", "Amount Used", "Amount Returned", "Amount Lost" |
| `COMPOUNDED` | CARBOPLATIN, PEMETREXED | DISPAMT, USEDAMT (RETAMT / LOSTAMT skipped — compounded drugs have no return/loss) | as above |

Rows where the source value is NA are dropped.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DA"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DASEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, DASTDTC, EXTRT, DATESTCD)` |
| 5 | DATESTCD | Short Name of Test | Char | 8 | Derived | DATESTCD | `DISPAMT` / `USEDAMT` / `RETAMT` / `LOSTAMT` (see Long-form pivot) |
| 6 | DATEST | Name of Test | Char | 40 | Derived | DATEST | "Amount Dispensed" / "Amount Used" / "Amount Returned" / "Amount Lost" |
| 7 | DACAT | Category | Char | 40 | Assigned | — | Constant `"DRUG ACCOUNTABILITY"` |
| 8 | DAORRES | Result in Original Units (char) | Char | 20 | Derived | — | `format(round(value, 2), nsmall = 0, trim = TRUE)` where `value` = matching raw column |
| 9 | DAORRESU | Result Units | Char | 10 | Predecessor | UNIT | `AMT_UNIT` — `VIAL` for vialed products; `MG` or `MG/M2` for compounded |
| 10 | DASTRESC | Standardised Result (character) | Char | 20 | Derived | — | Same as `DAORRES` |
| 11 | DASTRESN | Standardised Result (numeric) | Num | 8 | Derived | — | `as.numeric(value)` |
| 12 | DASTRESU | Standardised Units | Char | 10 | Predecessor | UNIT | Same as `DAORRESU` |
| 13 | DASTDTC | Date of Accountability | Char | 10 | Predecessor | ISO 8601 | `as.character(VISIT_DATE)` |
| 14 | VISIT | Visit Name | Char | 20 | Predecessor | VISIT | `VISIT_NAME` (passthrough) |
| 15 | EXTRT | Treatment | Char | 40 | Derived | — | `str_to_upper(str_trim(DRUG_NAME))` |

## Derivations

### D1 — Long-form pivot (full pseudocode)
```r
raw <- raw |> mutate(
  STUDYID    = "CTX-NSCLC-301",
  USUBJID    = paste(STUDYID, SUBJECT_ID, sep = "-"),
  EXTRT      = str_to_upper(str_trim(DRUG_NAME)),
  has_return = DOSE_FORM == "VIAL",   # TORIVUMAB, PLACEBO
  has_loss   = DOSE_FORM == "VIAL"
)

da_long <- raw |>
  select(STUDYID, USUBJID, EXTRT, VISIT_NAME, VISIT_DATE, AMT_UNIT,
         has_return, has_loss,
         DISPAMT = AMT_DISPENSED, USEDAMT = AMT_USED,
         RETAMT  = AMT_RETURNED,  LOSTAMT = AMT_LOST) |>
  pivot_longer(c(DISPAMT, USEDAMT, RETAMT, LOSTAMT),
               names_to = "DATESTCD", values_to = "value") |>
  filter(!(DATESTCD %in% c("RETAMT", "LOSTAMT") & !has_return),
         !is.na(value)) |>
  mutate(
    DOMAIN   = "DA",
    DATEST   = recode(DATESTCD,
                      DISPAMT = "Amount Dispensed",
                      USEDAMT = "Amount Used",
                      RETAMT  = "Amount Returned",
                      LOSTAMT = "Amount Lost"),
    DACAT    = "DRUG ACCOUNTABILITY",
    DAORRES  = format(round(value, 2), nsmall = 0, trim = TRUE),
    DAORRESU = AMT_UNIT,
    DASTRESC = DAORRES,
    DASTRESN = as.numeric(value),
    DASTRESU = AMT_UNIT,
    DASTDTC  = as.character(VISIT_DATE),
    VISIT    = VISIT_NAME
  ) |>
  arrange(USUBJID, DASTDTC, EXTRT, DATESTCD) |>
  group_by(USUBJID) |> mutate(DASEQ = row_number()) |> ungroup()
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| DATESTCD | C100945 (subset; non-standard codes permitted for DA) | DISPAMT, USEDAMT, RETAMT, LOSTAMT |
| DATEST | C100946 (subset) | "Amount Dispensed" / "Amount Used" / "Amount Returned" / "Amount Lost" |
| DACAT | Study-specific | `"DRUG ACCOUNTABILITY"` |
| DAORRESU, DASTRESU | UNIT (C71620) | `VIAL`, `MG`, `MG/M2` |
| EXTRT | Study-specific | `TORIVUMAB`, `PLACEBO`, `CARBOPLATIN`, `PEMETREXED` |
| VISIT | Shared VISIT lookup | — |

## QC Checks

- [ ] `nrow(da) ≈ 28,108` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`; coverage is all subjects in the safety population.
- [ ] `DASEQ` strictly increasing per `USUBJID`, no gaps starting at 1.
- [ ] `DATESTCD ∈ {DISPAMT, USEDAMT, RETAMT, LOSTAMT}` only.
- [ ] `RETAMT` / `LOSTAMT` rows appear only when `EXTRT ∈ {TORIVUMAB, PLACEBO}` (vialed products).
- [ ] `DASTRESN >= 0` for every row (no negative accountability quantities).
- [ ] `DASTRESN <= DAORRES_max_dispensed * 1.01` sanity bound (USEDAMT/RETAMT/LOSTAMT cannot exceed dispensed plus rounding).
- [ ] For each `(USUBJID, DASTDTC, EXTRT)`: `DISPAMT == USEDAMT + RETAMT + LOSTAMT` for vialed product (allowing 1-unit rounding tolerance). For compounded product: `DISPAMT == USEDAMT` (allowing 1 mg rounding tolerance).
- [ ] `DASTDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, DASTDTC, EXTRT, DATESTCD)` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-DA-spec.md` | `programs/sdtm/da.R` | `datasets/sdtm/da.parquet` |

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §4 for the consolidated cross-domain pseudocode and §22.1 (SDTM-PROVENANCE) for back-fill history (introduced 2026-05-16; finalised same day as CRF→SDTM 1:1).

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/da.R`. |
