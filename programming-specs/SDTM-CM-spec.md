# CM — Concomitant Medications — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | CM |
| **Label** | Concomitant Medications |
| **Class** | INTERVENTIONS |
| **Structure** | One record per medication occurrence per subject |
| **Expected N** | 2,319 |
| **Key variables** | `STUDYID`, `USUBJID`, `CMSEQ` |
| **SDTMIG version** | v3.4 (§6.2) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

CM captures all non-study-drug medications taken by subjects from informed consent through end-of-study (including subsequent anti-cancer therapy added per AL-02 closure). The verbatim drug name is WHO-ATC-coded to a standardised name and ATC class; corticosteroids prescribed for irAE management are flagged in SUPPCM.CMIRAEFL. Downstream consumers: ADCM (PRIORFL, CONMEDFL, IRAECMFL, SUBSQTFL), T-CM-01 (conmeds by ATC class), T-EFF-08 (subsequent-therapy censoring of OS).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/conmed.csv` | CDASH CM form + `raw/16_subsequent_therapy.R` appended rows | One row per medication occurrence — verbatim drug, dates, ongoing flag, indication. Subsequent anti-cancer therapy rows are appended upstream with their start date capped at the subject's last-contact date (so a post-discontinuation therapy never starts after the subject's last known contact). |
| `raw/codelists/atc_conmed.csv` | WHO-ATC subset (~150 drugs) | Verbatim → standardised drug name, ATC code, indication class |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"CM"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | CMSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, CMSTDTC, CMTRT)` |
| 5 | CMTRT | Reported Name of Drug, Med, or Therapy | Char | 200 | CRF | — | `str_trim(DRUG_NAME_VERBATIM)` |
| 6 | CMDECOD | Standardized Medication Name | Char | 200 | Derived | WHO ATC | See §Derivations.D1 |
| 7 | CMATC | ATC Classification Code | Char | 8 | Derived | WHO ATC 2024 | See §Derivations.D1 — non-standard SDTM var carried on parent for back-compat; SDTMIG-compliant home is `SUPPCM.QNAM = "CMATC"` |
| 8 | CMINDC | Indication | Char | 200 | Derived | — | `ATC.INDICATION` if matched; else `str_to_upper(str_trim(raw.INDICATION))` |
| 9 | CMROUTE | Route of Administration | Char | 20 | Assigned | ROUTE | Constant `"ORAL"` (raw CRF does not carry route — assumption documented in AL-08) |
| 10 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `CMSTDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `CMSTDTC` missing/partial |
| 11 | CMSTDTC | Start Date/Time of Medication | Char | 10 | CRF | — | `START_DATE` (ISO 8601, direct) |
| 12 | CMENDTC | End Date/Time of Medication | Char | 10 | CRF | — | `END_DATE` (direct; NA if ongoing) |
| 13 | CMSTDY | Study Day of Start of Medication | Num | 8 | Derived | — | Study day of `CMSTDTC` vs `DM.RFSTDTC`: `CMSTDTC − RFSTDTC + 1` on/after RFSTDTC, else `CMSTDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 14 | CMENDY | Study Day of End of Medication | Num | 8 | Derived | — | Study day of `CMENDTC` vs `DM.RFSTDTC` (same rule as `CMSTDY`; `17_derive_timing.R`) |
| 15 | CMENRTPT | End Relative to Reference Time Point | Char | 20 | Derived | RELTMPT | See §Derivations.D2 |
| 16 | CMENTPT | End Reference Time Point | Char | 40 | Derived | — | `"RANDOMIZATION"` when `CMENRTPT` is non-missing; else NA (names the anchor for `CMENRTPT` — P21 SD1101) |
| 17 | CMCAT | Category for Medication | Char | 40 | Assigned | — | Constant `"CONCOMITANT MEDICATION"` |

## Derivations

### D1 — ATC coding (CMDECOD / CMATC / CMINDC)

```
match_atc(verbatim):
   v_up <- str_to_upper(str_trim(verbatim))
   idx  <- which(atc.V1_UPPER == v_up OR atc.V2_UPPER == v_up)
   if length(idx) == 0:
      fuzzy_v1 <- agrep(v_up, atc.V1_UPPER, max.distance = 0.2)
      fuzzy_v2 <- agrep(v_up, atc.V2_UPPER, max.distance = 0.2)
      idx <- unique(c(fuzzy_v1, fuzzy_v2))
   if length(idx) > 0:
      CMDECOD <- atc.DRUG_NAME[idx[1]]
      CMATC   <- atc.ATC_CODE[idx[1]]
      CMINDC  <- atc.INDICATION[idx[1]]
   else:
      CMDECOD <- v_up
      CMATC   <- NA
      CMINDC  <- NA
```

`atc_conmed.csv` columns: `ATC_CODE, ATC_NAME, DRUG_NAME, DRUG_NAME_VERBATIM_1, DRUG_NAME_VERBATIM_2, INDICATION_CLASS, INDICATION`. See `programs/sdtm/SDTM-MAPPING-SPEC.md` §6.1 for full lookup spec.

### D2 — CMENRTPT (ongoing flag)

```
CMENRTPT = case_when(
   ONGOING in {"Y","YES","TRUE","1"}      ~ "ONGOING",
   is.na(END_DATE) OR END_DATE == ""      ~ "ONGOING",
   TRUE                                   ~ "BEFORE"
)
```

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| CMDECOD | WHO Drug 2024 (subset) | `raw/codelists/atc_conmed.csv` |
| CMATC | WHO ATC 2024 | `raw/codelists/atc_conmed.csv` |
| CMROUTE | ROUTE (C66729) | CDISC CT 2024-03 — currently constant `"ORAL"` |
| CMENRTPT | RELTMPT (C66728) | CDISC CT 2024-03 — values `BEFORE` / `ONGOING` |
| CMCAT | Sponsor | Constant `"CONCOMITANT MEDICATION"` |

## QC Checks

- [ ] `nrow(cm) == 2319` (±0.1%; a subset are subsequent anti-cancer therapy appended by `raw/16_subsequent_therapy.R`, with start dates capped at last contact)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `CMSEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, CMSEQ)`
- [ ] `CMSTDTC` non-missing for all rows
- [ ] `CMENDTC >= CMSTDTC` where both non-missing
- [ ] `CMENRTPT ∈ {ONGOING, BEFORE}` — no other values
- [ ] ATC match rate ≥ 90% — `sum(!is.na(CMATC)) / nrow(cm) >= 0.90`
- [ ] Corticosteroid rate plausible (H02AB* ATC codes) — used by SUPPCM.CMIRAEFL
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-CM-spec.md` | `programs/sdtm/cm.R` | `datasets/sdtm/cm.parquet` |

SUPPCM (CMATC home, CMIRAEFL) — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §19 / `programs/sdtm/suppcm.R`.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `cm.R`: record count 2,222 → 2,319; added `CMENTPT` (RANDOMIZATION anchor for `CMENRTPT`, per P21 SD1101) to the variable table; noted subsequent-therapy start dates are capped at last contact upstream in `raw/16_subsequent_therapy.R`. |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH`, `CMSTDY`, `CMENDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/cm.parquet`. |
