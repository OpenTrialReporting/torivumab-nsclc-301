# DA — Drug Accountability — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | DA |
| **Label** | Drug Accountability |
| **Class** | INTERVENTIONS |
| **Structure** | One record per accountability test per drug per visit per subject |
| **Expected N** | 18,463 |
| **Key variables** | `STUDYID`, `USUBJID`, `DASEQ` |
| **SDTMIG version** | v3.4 (§6.5 Drug Accountability) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

DA captures the per-visit accountability quantities (dispensed, used, returned, lost) for each study drug. The domain provides the audit trail required by ICH GCP §8.2.16 for IP accountability and is the SDTM source for the supply-management listings (L-DA-01) and the compliance summary (T-EXP-02). DA does **not** drive efficacy / safety endpoints — its role is regulatory / operational completeness.

Each raw dispensation event is pivoted long-form into 1–3 SDTM records depending on dose form (vialed product carries return / loss columns; compounded product does not). `USEDAMT` (Amount Used) is **not** emitted — it is not a CDISC DA test code (P21 CT2002/CT2003).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/drug_accountability.csv` | CDASH DA form | One row per dispensation per drug per visit |

**Raw columns:** `SUBJECT_ID, VISIT_NAME, VISIT_DATE, DRUG_NAME, DOSE_FORM, AMT_DISPENSED, AMT_USED, AMT_RETURNED, AMT_LOST, AMT_UNIT, COMPLIANCE_PCT, ACCOUNTABILITY_DATE, DISPENSED_BY`.

## Long-form pivot

Each raw row is exploded into one row per accountability test (`DATESTCD`):

| DOSE_FORM | Drugs | DATESTCD records emitted | DATEST |
|---|---|---|---|
| `VIAL` | TORIVUMAB, PLACEBO | DISPAMT, RETAMT, LOSTAMT | "Dispensed Amount", "Returned Amount", "Lost Amount" |
| `COMPOUNDED` | CARBOPLATIN, PEMETREXED | DISPAMT only (RETAMT / LOSTAMT skipped — compounded drugs have no return/loss) | "Dispensed Amount" |

Rows where the source value is NA are dropped.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"DA"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | DASEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, DADTC, EXTRT, DATESTCD)` (`EXTRT` used in the sort only; not output) |
| 5 | DATESTCD | Short Name of Test | Char | 8 | Derived | DATESTCD | `DISPAMT` / `RETAMT` / `LOSTAMT` (see Long-form pivot; `USEDAMT` excluded) |
| 6 | DATEST | Name of Test | Char | 40 | Derived | DATEST | "Dispensed Amount" / "Returned Amount" / "Lost Amount" (exact CDISC DATEST decodes) |
| 7 | DACAT | Category | Char | 40 | Assigned | — | Constant `"DRUG ACCOUNTABILITY"` |
| 8 | DAORRES | Result in Original Units (char) | Char | 20 | Derived | — | `format(round(value, 2), nsmall = 0, trim = TRUE)` where `value` = matching raw column |
| 9 | DAORRESU | Result Units | Char | 10 | Predecessor | UNIT | `recode(AMT_UNIT, "MG"="mg", "MG/M2"="mg/m2")` — `VIAL` for vialed products; `mg` / `mg/m2` for compounded |
| 10 | DASTRESC | Standardised Result (character) | Char | 20 | Derived | — | Same as `DAORRES` |
| 11 | DASTRESN | Standardised Result (numeric) | Num | 8 | Derived | — | `as.numeric(value)` |
| 12 | DASTRESU | Standardised Units | Char | 10 | Predecessor | UNIT | Same as `DAORRESU` |
| 13 | VISITNUM | Visit Number | Num | 8 | Derived | — | Cycle number parsed from `VISIT_NAME` (`as.integer(sub("D1$","", sub("^C","", VISIT_NAME)))`); bijective with `VISIT` (P21 SD0057/SD0051) |
| 14 | VISIT | Visit Name | Char | 20 | Predecessor | VISIT | `VISIT_NAME` (passthrough) |
| 15 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `DADTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `DADTC` missing/partial |
| 16 | DADTC | Date of Collection | Char | 10 | Predecessor | ISO 8601 | `as.character(VISIT_DATE)` — DA is a Findings domain; timing var is `DADTC`, not `DASTDTC` (prohibited — P21 SD1073; `DADTC` Expected — SD0057) |
| 17 | DADY | Study Day of Collection | Num | 8 | Derived | — | Study day of `DADTC` vs `DM.RFSTDTC`: `DADTC − RFSTDTC + 1` on/after RFSTDTC, else `DADTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |

> `EXTRT` (name of treatment) is used to make the `DASEQ` sort deterministic but is **not** in the SDTM DA model (P21 SD0058), so it is dropped from output; a `SUPPDA.EXTRT` could carry per-product identity if a reviewer needs the accountability split.

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
         DISPAMT = AMT_DISPENSED,
         RETAMT  = AMT_RETURNED,  LOSTAMT = AMT_LOST) |>
  pivot_longer(c(DISPAMT, RETAMT, LOSTAMT),   # USEDAMT dropped — not a CDISC DA test (CT2002/CT2003)
               names_to = "DATESTCD", values_to = "value") |>
  filter(!(DATESTCD %in% c("RETAMT", "LOSTAMT") & !has_return),
         !is.na(value)) |>
  mutate(
    DOMAIN   = "DA",
    DATEST   = case_when(                       # exact CDISC DATEST decodes
      DATESTCD == "DISPAMT" ~ "Dispensed Amount",
      DATESTCD == "RETAMT"  ~ "Returned Amount",
      DATESTCD == "LOSTAMT" ~ "Lost Amount"),
    DACAT    = "DRUG ACCOUNTABILITY",
    DAORRES  = format(round(value, 2), nsmall = 0, trim = TRUE),
    DAORRESU = recode(AMT_UNIT, "MG" = "mg", "MG/M2" = "mg/m2"),   # CDISC UNIT
    DASTRESC = DAORRES,
    DASTRESN = as.numeric(value),
    DASTRESU = recode(AMT_UNIT, "MG" = "mg", "MG/M2" = "mg/m2"),
    DADTC    = as.character(VISIT_DATE),        # Findings timing var (not DASTDTC)
    VISIT    = VISIT_NAME,
    VISITNUM = as.integer(sub("D1$", "", sub("^C", "", VISIT_NAME)))
  ) |>
  arrange(USUBJID, DADTC, EXTRT, DATESTCD) |>
  group_by(USUBJID) |> mutate(DASEQ = row_number()) |> ungroup()
  # EXTRT dropped from the final transmute (P21 SD0058)
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| DATESTCD | C100945 (subset) | DISPAMT, RETAMT, LOSTAMT |
| DATEST | C100946 (subset) | "Dispensed Amount" / "Returned Amount" / "Lost Amount" |
| DACAT | Study-specific | `"DRUG ACCOUNTABILITY"` |
| DAORRESU, DASTRESU | UNIT (C71620) | `VIAL`, `mg`, `mg/m2` |
| VISITNUM, VISIT | Shared VISIT lookup | Bijective cycle number ↔ visit name |

## QC Checks

- [ ] `nrow(da) ≈ 18,463` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`; coverage is all subjects in the safety population.
- [ ] `DASEQ` strictly increasing per `USUBJID`, no gaps starting at 1.
- [ ] `DATESTCD ∈ {DISPAMT, RETAMT, LOSTAMT}` only (`USEDAMT` excluded).
- [ ] `RETAMT` / `LOSTAMT` rows appear only for vialed products (TORIVUMAB, PLACEBO); compounded products emit `DISPAMT` only.
- [ ] `DASTRESN >= 0` for every row (no negative accountability quantities).
- [ ] `DASTRESN <= DAORRES_max_dispensed * 1.01` sanity bound (RETAMT/LOSTAMT cannot exceed dispensed plus rounding).
- [ ] `DADTC` parses as ISO 8601 date; `DASTDTC` is absent (prohibited in DA — P21 SD1073).
- [ ] `VISITNUM` is a single bijective value per `VISIT` (P21 SD0051).
- [ ] Sort key `(USUBJID, DADTC, EXTRT, DATESTCD)` reproduces row order.
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
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `da.R` (built from `raw/drug_accountability.csv`): record count 28,108 → 18,463; dropped `USEDAMT` test (not CDISC — CT2002/CT2003) and `EXTRT` (not in DA model — SD0058); timing var `DASTDTC` → `DADTC` (SD1073/SD0057); added `VISITNUM`; DATEST decodes to "Dispensed/Returned/Lost Amount"; units CDISC-cased; updated pivot table, derivation, CT, and QC. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `DADY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/da.parquet`. |
