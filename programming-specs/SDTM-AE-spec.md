# AE — Adverse Events — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | AE |
| **Label** | Adverse Events |
| **Class** | EVENTS |
| **Structure** | One record per adverse event per subject |
| **Expected N** | 2,840 |
| **Key variables** | `STUDYID`, `USUBJID`, `AESEQ` |
| **SDTMIG version** | v3.4 (§6.1) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

AE captures every treatment-emergent and pre-treatment adverse event recorded on the CDASH AE CRF. The verbatim term is MedDRA-coded (v27.0) to LLT/PT/HLT/SOC; severity is mapped to CTCAE v5.0 grades; irAE flagging carries forward to SUPPAE.IRAEFL. Downstream consumers: ADAE (TEAE flag, AOCCFL, irAE analyses), all safety TFLs (T-AE-01 through T-AE-05, T-SAE-01, T-IRAE-01).

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/adverse_events.csv` | CDASH AE form | One row per AE per subject — verbatim term, dates, severity, seriousness, action, outcome, relationship |
| `raw/codelists/meddra_oncology_subset.csv` | MedDRA v27.0 oncology-relevant subset | LLT → PT → HLT → SOC lookup; carries pre-marked `IRAEFL` per term |

## Variables

Variable order below matches the program output (SDTMIG v3.4 AE order: topic, MedDRA hierarchy LLT→PT→HLT→HLGT→BODSYS→SOC with numeric codes, category, severity/grade, seriousness, action/causality/outcome, SAE criteria, timing). `AESTDY`/`AEENDY`/`EPOCH` are appended later by `17_derive_timing.R`.

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"AE"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | AESEQ | Sequence Number | Num | 8 | Derived | — | See §Derivations.D1 |
| 5 | AETERM | Reported Term for the Adverse Event | Char | 200 | CRF | — | `str_trim(AE_VERBATIM_TERM)` |
| 6 | AELLT | Lowest Level Term | Char | 200 | Derived | MedDRA LLT | See §Derivations.D2 (verbatim preserved if unmatched) |
| 7 | AELLTCD | Lowest Level Term Code | Num | 8 | Derived | MedDRA | Numeric LLT code (P21 SD0055) |
| 8 | AEDECOD | Dictionary-Derived Term | Char | 200 | Derived | MedDRA PT | See §Derivations.D2 |
| 9 | AEPTCD | Preferred Term Code | Num | 8 | Derived | MedDRA | Numeric PT code |
| 10 | AEHLT | High Level Term | Char | 200 | Derived | MedDRA HLT | See §Derivations.D2 |
| 11 | AEHLTCD | High Level Term Code | Num | 8 | Derived | MedDRA | Numeric HLT code |
| 12 | AEHLGT | High Level Group Term | Char | 200 | Derived | MedDRA HLGT | See §Derivations.D2 |
| 13 | AEHLGTCD | High Level Group Term Code | Num | 8 | Derived | MedDRA | Numeric HLGT code |
| 14 | AEBODSYS | Body System or Organ Class | Char | 200 | Derived | MedDRA SOC | See §Derivations.D2 |
| 15 | AEBDSYCD | Body System or Organ Class Code | Num | 8 | Derived | MedDRA | Numeric SOC code |
| 16 | AESOC | Primary System Organ Class | Char | 200 | Derived | MedDRA SOC | Same as AEBODSYS |
| 17 | AESOCCD | Primary System Organ Class Code | Num | 8 | Derived | MedDRA | Same as AEBDSYCD |
| 18 | AECAT | Category for Adverse Event | Char | 40 | Derived | — | `"IMMUNE-RELATED"` if `IRAEFL=="Y"`; else trim+upper raw AECAT if present; else NA |
| 19 | AESEV | Severity/Intensity | Char | 20 | Derived | AESEV | See §Derivations.D3, then collapsed to the 3-point CTCAE scale (LIFE-THREATENING/FATAL → SEVERE; grade retained in AETOXGR, P21 CT2001) |
| 20 | AETOXGR | Standard Toxicity Grade | Char | 1 | Derived | CTCAE v5.0 | Map pre-collapse AESEV: MILD=1, MODERATE=2, SEVERE=3, LIFE-THREATENING=4, FATAL=5 |
| 21 | AESER | Serious Event | Char | 1 | Derived | NY | Map raw `SERIOUS` to `Y/N`; promoted to `"Y"` if `AESDTH=="Y"` or `AESLIFE=="Y"` (P21 SD1132) |
| 22 | AEACN | Action Taken with Study Treatment | Char | 40 | Derived | ACN | See §Derivations.D3 |
| 23 | AEREL | Causality | Char | 1 | Derived | NY | See §Derivations.D3 (RELATED_TO_STUDY_DRUG mapping) |
| 24 | AEOUT | Outcome of Adverse Event | Char | 40 | Derived | OUT | See §Derivations.D3 |
| 25 | AESCONG | Congenital Anomaly or Birth Defect | Char | 1 | Assigned | NY | Constant `"N"` |
| 26 | AESDISAB | Persist/Significant Disability/Incapacity | Char | 1 | Assigned | NY | Constant `"N"` |
| 27 | AESDTH | Results in Death | Char | 1 | Derived | NY | `"Y"` if `OUTCOME ∈ {FATAL, DEATH}` or `AESEV=="FATAL"`; else `"N"` |
| 28 | AESHOSP | Requires/Prolongs Hospitalization | Char | 1 | Derived | NY | `"Y"` if `AESER=="Y"` & `AESDTH=="N"` & `AESLIFE=="N"` (carries residual seriousness); else `"N"` |
| 29 | AESLIFE | Is Life Threatening | Char | 1 | Derived | NY | `"Y"` if pre-collapse `AESEV=="LIFE-THREATENING"`; else `"N"` |
| 30 | AESMIE | Other Medically Important Event | Char | 1 | Assigned | NY | Constant `"N"` |
| 31 | AESTDTC | Start Date/Time of AE | Char | 10 | CRF | — | `AE_START_DATE` (ISO 8601, direct) |
| 32 | AEENDTC | End Date/Time of AE | Char | 10 | Derived | — | See §Derivations.D4 (direct `AE_END_DATE`, else severity-based imputation for resolved AEs, capped at death/exit; NA if ongoing) |

`AEDISCOD` (AE led to drug discontinuation) is **not** output — it is non-standard (P21 SD0058) and carried in `SUPPAE.AEDISFL`.

## Derivations

### D1 — AESEQ (sequence per subject)

```
sort by (USUBJID, AESTDTC)
AESEQ <- row_number() within each USUBJID
```

This sort key MUST be identical to the one used in `programs/sdtm/suppae.R` so that SUPPAE.IDVARVAL matches the parent AE.AESEQ.

### D2 — MedDRA coding (AELLT/AEDECOD/AEHLT/AEHLGT/AEBODSYS/AESOC + numeric codes)

The collected verbatim terms carry severity/status decorations (e.g. `"GRADE 3 NEUTROPENIA"`, `"MILD NAUSEA NOS"`, `"DYSPNOEA (ONGOING)"`). `normalize_term()` strips these leading/trailing modifiers (loop until stable) to recover the base medical concept, then matches LLT first and falls back to PT. This deterministic normalisation replaces the old fuzzy `agrep` and takes coverage from ~23% to **100%** against the curated oncology subset — every concept resolves to a real dictionary LLT/PT with a **numeric** code (P21 SD1449 population; SD0055 numeric codes).

```
base <- normalize_term(AE_VERBATIM_TERM)          # strip grade/severity/status
idx  <- match(base, meddra$LLT_NAME_UPPER)         # exact LLT match
idx[is.na(idx)] <- match(base[...], meddra$PT_NAME_UPPER)   # PT fallback

if matched:
   AELLT/AELLTCD     <- meddra LLT name / code
   AEDECOD/AEPTCD    <- meddra PT  name / code
   AEHLT/AEHLTCD     <- meddra HLT  name / code
   AEHLGT/AEHLGTCD   <- meddra HLGT name / code
   AEBODSYS/AEBDSYCD <- meddra SOC  name / code
   AESOC/AESOCCD     <- same as AEBODSYS / AEBDSYCD
   IRAEFL            <- meddra IRAEFL   # used by AECAT and SUPPAE.IRAEFL
else (should be 0 rows):
   AELLT <- verbatim (preserved); all *CD <- NA; IRAEFL <- "N"
```

All numeric `*CD` variables are `as.numeric()` of the dictionary codes. See `programs/sdtm/SDTM-MAPPING-SPEC.md` §5.1 for the full MedDRA lookup spec.

### D4 — AEENDTC (imputation for resolved AEs, capped at exit)

The CRF left `AEENDTC` blank for some AEs whose outcome is RECOVERED/RESOLVED. A resolved event must have an end date, so impute a plausible short duration by severity (MILD 3d / MODERATE 7d / SEVERE-plus 14d from onset), **capped at the subject's death/exit date** (death caps hardest; else the latest of disposition `DISC_DATE`, `LAST_CONTACT_DATE`, `STUDY_COMPLETION_DATE`). Genuinely ongoing/unknown-outcome AEs keep a blank end date. AE start dates are likewise never later than this cap.

```
cap      <- min(death_date, last_disposition_contact)   # per subject
dur_days <- recode(severity, MILD=3, MODERATE=7, .default=14)
imp_end  <- min(ae_start + dur_days, cap)
AEENDTC  <- case_when(
   !is.na(ae_end)                                ~ ae_end,
   is.na(ae_end) & AEOUT == "RECOVERED/RESOLVED" ~ imp_end,
   TRUE                                          ~ NA)
```

### D3 — Controlled-term mappers (AESEV, AESER, AEREL, AEACN, AEOUT)

Case-insensitive on trim+upper of raw value:

| Raw value | AESEV | AESER | AEREL | AEACN | AEOUT |
|---|---|---|---|---|---|
| `MILD/1/GRADE 1` | MILD | — | — | — | — |
| `MODERATE/2/GRADE 2` | MODERATE | — | — | — | — |
| `SEVERE/3/GRADE 3` | SEVERE | — | — | — | — |
| `LIFE-THREATENING/4/GRADE 4` | LIFE-THREATENING | — | — | — | — |
| `FATAL/5/GRADE 5` | FATAL | — | — | — | — |
| `Y/YES/TRUE/1` | — | Y | — | — | — |
| `N/NO/FALSE/0` | — | N | — | — | — |
| `Y/YES/TRUE/RELATED/POSSIBLY RELATED/PROBABLY RELATED/DEFINITELY RELATED` | — | — | Y | — | — |
| `N/NO/FALSE/NOT RELATED/UNRELATED` | — | — | N | — | — |
| contains `DOSE REDUC` | — | — | — | DOSE REDUCED | — |
| contains `DOSE INTERR` | — | — | — | DRUG INTERRUPTED | — |
| contains `DISC` | — | — | — | DRUG WITHDRAWN | — |
| contains `NONE/NOT` | — | — | — | NONE | — |
| contains `RECOVER/RESOLV` | — | — | — | — | RECOVERED/RESOLVED |
| contains `ONGOING` | — | — | — | — | NOT RECOVERED/NOT RESOLVED |
| contains `SEQUELA` | — | — | — | — | RECOVERED/RESOLVED WITH SEQUELAE |
| contains `FATAL/DEATH` | — | — | — | — | FATAL |

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §5.2 for the canonical mapper table.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| AELLT/AEDECOD/AEHLT/AEHLGT/AEBODSYS/AESOC (+ numeric `*CD` codes) | MedDRA v27.0 | `raw/codelists/meddra_oncology_subset.csv` (oncology-relevant subset, ~3,500 LLTs); 100% coded, numeric codes per SD0055 |
| AESEV | AESEV (C66769) | CDISC CT 2024-03 |
| AETOXGR | CTCAE v5.0 | NCI CTCAE — integer grades 1-5 stored as character |
| AESER/AEREL | NY (C66742) | CDISC CT 2024-03 |
| AEACN | ACN (C66767) | CDISC CT 2024-03 |
| AEOUT | OUT (C66768) | CDISC CT 2024-03 |

## QC Checks

- [ ] `nrow(ae) == 2840` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `AESEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, AESEQ)`
- [ ] `AESTDTC` non-missing for all rows; `AEENDTC >= AESTDTC` where non-missing; `AEENDTC <= subject death/exit date`
- [ ] `AESEV ∈ {MILD, MODERATE, SEVERE}` (3-point CTCAE scale after collapse)
- [ ] `AETOXGR ∈ {"1","2","3","4","5"}`; grades 4/5 correspond to AESLIFE/AESDTH
- [ ] `AESER`, `AEREL`, `AESDTH`, `AESLIFE`, `AESHOSP`, `AESCONG`, `AESDISAB`, `AESMIE ∈ {Y, N}` (never null)
- [ ] Every serious AE (`AESER=="Y"`) has ≥1 SAE criterion `"Y"`
- [ ] MedDRA coverage 100%: `AEPTCD` non-missing (numeric) for all rows
- [ ] AECAT == "IMMUNE-RELATED" rate ≈ 18-22% of AE rows (target ≈25% in TORIVUMAB arm)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-AE-spec.md` | `programs/sdtm/ae.R` | `datasets/sdtm/ae.parquet` |

SUPPAE (IRAEFL, AEDISFL, AEACTFL, AETRTEM) — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §18 / `programs/sdtm/suppae.R`.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Spec refresh vs `ae.R`: record count 2,837 → 2,840; rebuilt variable table to actual output (full MedDRA hierarchy with numeric `*CD` codes incl. AEHLGT; SAE criteria now populated Y/N not NA; `AEDISCOD` dropped to SUPPAE); D2 now deterministic normalisation → 100% coding (was fuzzy agrep); added D4 AEENDTC imputation capped at death/exit; AESEV collapsed to 3-point scale (grade in AETOXGR); updated CT and QC. |
