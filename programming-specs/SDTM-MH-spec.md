# MH — Medical History — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | MH |
| **Label** | Medical History |
| **Class** | EVENTS |
| **Structure** | One record per medical-history condition per subject |
| **Expected N** | 2,051 |
| **Key variables** | `STUDYID`, `USUBJID`, `MHSEQ` |
| **SDTMIG version** | v3.4 (§6.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

MH captures every pre-existing or historical condition reported by the subject at screening — including the primary NSCLC diagnosis (flagged via `MHCAT = "PRIMARY DIAGNOSIS"`), comorbidities, and prior treatments captured as conditions. The primary-diagnosis subset is the source for ADSL-derivable disease characteristics (histology, prior lines, etc., when surfaced as MH conditions). Downstream consumers: ADMH (PRIORFL, PRIMDXFL), T-MH-01 (medical history by SOC), L-DISP-01 (primary diagnosis listing).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/medical_history.csv` | CDASH MH form | One row per condition per subject — verbatim term, onset date, preexisting flag, current status |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"MH"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | MHSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, MHSTDTC)` |
| 5 | MHTERM | Reported Term for the Medical History | Char | 200 | CRF | — | `str_trim(CONDITION_VERBATIM)` |
| 6 | MHDECOD | Dictionary-Derived Term | Char | 200 | Derived | (MedDRA in real studies) | See §Derivations.D1 — simplified title-case in this synthetic build |
| 7 | MHCAT | Category for Medical History | Char | 40 | Derived | — | See §Derivations.D2 |
| 8 | MHSTDTC | Start Date/Time of Medical History Event | Char | 10 | CRF | — | `ONSET_DATE` (ISO 8601, direct) |
| 9 | MHENRTPT | End Relative to Reference Time Point | Char | 20 | Derived | RELTMPT | See §Derivations.D3 |
| 10 | MHPRESP | Medical History Event Pre-specified | Char | 1 | Assigned | NY | Constant `"Y"` (all conditions are pre-specified by CRF design) |
| 11 | MHOCCUR | Medical History Occurrence | Char | 1 | Assigned | NY | Constant `"Y"` (only present conditions are captured) |

## Derivations

### D1 — MHDECOD (simplified coding)

```
MHDECOD = str_to_title(str_trim(CONDITION_VERBATIM))
```

**Production note:** Real implementations should MedDRA-code MHTERM (LLT→PT) using the same approach as AE.AEDECOD (see SDTM-AE-spec §D2). The current title-case simplification is acceptable for this synthetic dataset because MH downstream consumers (ADMH, T-MH-01) primarily filter on MHCAT and MHTERM rather than MHDECOD. See AL-10 for the open coding gap.

### D2 — MHCAT (primary diagnosis vs general history)

```
cancer_pattern = "CANCER|CARCINOMA|TUMOU?R|MALIGNANCY|NSCLC|SCLC|MELANOMA|LYMPHOMA"

MHCAT = case_when(
   PREEXISTING in {"Y","YES","TRUE","1"}
      AND str_detect(str_to_upper(CONDITION_VERBATIM), cancer_pattern)
      ~ "PRIMARY DIAGNOSIS",
   TRUE
      ~ "MEDICAL HISTORY"
)
```

**Rationale:** Any cancer-related preexisting condition is flagged as `PRIMARY DIAGNOSIS` so ADMH can pull the NSCLC diagnosis row reliably. Non-cancer or non-preexisting cancer history (e.g., prior basal cell carcinoma) fall under `MEDICAL HISTORY`.

### D3 — MHENRTPT (ongoing flag)

```
MHENRTPT = case_when(
   STATUS (trim+upper) in {"ONGOING","ACTIVE","CURRENT"}   ~ "ONGOING",
   STATUS (trim+upper) in {"RESOLVED","INACTIVE","PAST","N"} ~ "BEFORE",
   TRUE                                                     ~ NA
)
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §7 for the consolidated derivation table.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| MHDECOD | MedDRA v27.0 (in real studies) | Simplified title-case in this synthetic build (AL-10) |
| MHCAT | Sponsor | Values: `PRIMARY DIAGNOSIS`, `MEDICAL HISTORY` |
| MHENRTPT | RELTMPT (C66728) | CDISC CT 2024-03 — values `ONGOING`, `BEFORE` |
| MHPRESP / MHOCCUR | NY (C66742) | CDISC CT 2024-03 — both constant `"Y"` |

## QC Checks

- [ ] `nrow(mh) == 2051` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `MHSEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, MHSEQ)`
- [ ] `MHSTDTC` non-missing for all rows; ISO 8601 format
- [ ] Every subject has ≥1 row with `MHCAT == "PRIMARY DIAGNOSIS"` (NSCLC eligibility criterion)
- [ ] `MHCAT ∈ {PRIMARY DIAGNOSIS, MEDICAL HISTORY}` — no other values
- [ ] `MHENRTPT ∈ {ONGOING, BEFORE, NA}` — no other values
- [ ] `MHPRESP == "Y"` and `MHOCCUR == "Y"` for all rows
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-MH-spec.md` | `programs/sdtm/mh.R` | `datasets/sdtm/mh.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
