# PE — Physical Examination — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | PE |
| **Label** | Physical Examination |
| **Class** | FINDINGS |
| **Structure** | One record per body system per visit per subject |
| **Expected N** | 25,596 |
| **Key variables** | `STUDYID`, `USUBJID`, `PESEQ` |
| **SDTMIG version** | v3.4 (§7.3.1) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

PE captures the protocol-mandated physical examination findings per body system per scheduled visit. Each row records the examiner's free-text observation, a normality flag (`PENORM`) and a clinically-significant flag (`PECLSIG`). The domain supports baseline characterisation listings (L-PE-01) and on-treatment safety review of new physical findings. PE is **not** an analysis driver in this study (no ADaM consumes PE directly); its role is regulatory completeness of SDTM in line with SDTMIG v3.4 §7.3.1.

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/physical_exam.csv` | CDASH PE form | One row per (subject, visit, body system, finding) |
| Shared VISIT lookup | `programs/sdtm/SDTM-MAPPING-SPEC.md` §"Shared VISIT lookup" | Maps `VISIT_NAME` → `VISITNUM` |

**Raw columns:** `SUBJECT_ID, VISIT_NAME, VISIT_DATE, BODY_SYSTEM, FINDING, FINDING_DETAIL`.

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"PE"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | PESEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, PEDTC, PETESTCD)` |
| 5 | PETESTCD | Short Name of Measurement | Char | 8 | Derived | PETESTCD | See §Derivations.D1 |
| 6 | PETEST | Name of Measurement | Char | 40 | Derived | PETEST | `str_to_upper(str_trim(BODY_SYSTEM))` |
| 7 | PEORRES | Result or Finding in Original Units | Char | 200 | Derived | — | See §Derivations.D2 |
| 8 | PESTRESC | Character Result/Finding in Std Format | Char | 200 | Derived | — | See §Derivations.D3 — `"NORMAL"`/`"ABNORMAL"` standardised result (expected var, P21 SD0057) |
| 9 | PECLSIG | Clinically Significant Finding | Char | 1 | Derived | NY | See §Derivations.D4 |
| 10 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `PEDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `PEDTC` missing/partial |
| 11 | PEDTC | Date of Examination | Char | 10 | Predecessor | ISO 8601 | `as.character(VISIT_DATE)` |
| 12 | PEDY | Study Day of Examination | Num | 8 | Derived | — | Study day of `PEDTC` vs `DM.RFSTDTC`: `PEDTC − RFSTDTC + 1` on/after RFSTDTC, else `PEDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 13 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 14 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |

> `PENORM` (Normal Range Indicator) is derived internally as a helper (see D3) but is **not** output — it is not in the SDTM PE model (P21 SD0058); the normal/abnormal result is carried in `PESTRESC`.

## Derivations

### D1 — PETESTCD
**Rule:** Up to 8-character SDTM testcd derived from `BODY_SYSTEM`.
```r
PETESTCD = str_sub(
  str_to_upper(str_replace_all(str_trim(BODY_SYSTEM), "[^A-Z0-9]", "")),
  1, 8
)
```
Example: `"HEAD, EYES, ENT"` → `"HEADEYES"`; `"CARDIOVASCULAR"` → `"CARDIOVA"`.

### D2 — PEORRES
**Rule:** Concatenate finding plus detail when detail present.
```r
PEORRES = paste0(
  str_trim(FINDING),
  if_else(is.na(FINDING_DETAIL) | str_trim(FINDING_DETAIL) == "",
          "",
          paste0(" - ", str_trim(FINDING_DETAIL)))
)
```

### D3 — PENORM (helper) → PESTRESC
**Rule:** Derive the internal `PENORM` helper (`"Y"` when the finding is a controlled-normal string, else NA), then standardise it to `PESTRESC` = `"NORMAL"`/`"ABNORMAL"`. Only `PESTRESC` is output (`PENORM` is dropped — not in the PE model).
```r
PENORM = if_else(
  str_to_upper(str_trim(FINDING)) %in% c(
    "NORMAL", "WITHIN NORMAL LIMITS", "WNL",
    "NO ABNORMALITY DETECTED", "NAD", "UNREMARKABLE"
  ),
  "Y", NA_character_
)
PESTRESC = ifelse(PENORM == "Y" & !is.na(PENORM), "NORMAL", "ABNORMAL")
```

### D4 — PECLSIG
**Rule:** `"Y"` if finding contains the phrase `"CLINICALLY SIGNIFICANT"`; `"N"` for any normal finding; otherwise NA (abnormal but not adjudicated CS).
```r
PECLSIG = case_when(
  str_detect(str_to_upper(str_trim(FINDING)), "CLINICALLY SIGNIFICANT") ~ "Y",
  PENORM == "Y" ~ "N",
  TRUE ~ NA_character_
)
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| PESTRESC | — (study-specific) | `NORMAL` / `ABNORMAL` |
| PECLSIG | NY (C66742) | Y / N / NA |
| VISITNUM, VISIT | Study-specific VISIT (see Shared VISIT lookup) | SCREENING, C1D1, C1D15, C2D1…C8D1, EOT, FU1, FU2 |
| PETESTCD / PETEST | Study-specific (derived from raw `BODY_SYSTEM`) | Not formally CDISC-CT bound — production studies should map to CDISC `PETESTCD` (C100946) |

## QC Checks

- [ ] `nrow(pe) ≈ 25,596` (within ±0.1%).
- [ ] `USUBJID` is non-missing on every row; foreign key into `DM`.
- [ ] `PESEQ` strictly increasing per `USUBJID` with no gaps starting at 1.
- [ ] `PETESTCD` length ≤ 8 chars; values are upper-case A-Z0-9 only.
- [ ] `PEDTC` parses as ISO 8601 date (`YYYY-MM-DD`).
- [ ] `VISITNUM` non-missing for every `VISIT` that matches the shared lookup table.
- [ ] `PESTRESC ∈ {NORMAL, ABNORMAL}`; `PECLSIG ∈ {Y, N, NA}`; no other values.
- [ ] No row has both `PESTRESC == "NORMAL"` and `PECLSIG == "Y"` (mutually exclusive by construction).
- [ ] Sort key `(USUBJID, PEDTC, PETESTCD)` reproduces the row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-PE-spec.md` | `programs/sdtm/pe.R` | `datasets/sdtm/pe.parquet` |

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §11 for the consolidated cross-domain pseudocode.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/pe.R`. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `pe.R`: record count 22,662 → 25,596; added expected var `PESTRESC` (NORMAL/ABNORMAL, P21 SD0057); `PENORM` demoted to internal helper (dropped from output, SD0058); updated derivations, CT, and QC. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `PEDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/pe.parquet`. |
