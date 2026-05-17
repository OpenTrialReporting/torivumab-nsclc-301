# AE — Adverse Events — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | AE |
| **Label** | Adverse Events |
| **Class** | EVENTS |
| **Structure** | One record per adverse event per subject |
| **Expected N** | 2,837 |
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

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"AE"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | AESEQ | Sequence Number | Num | 8 | Derived | — | See §Derivations.D1 |
| 5 | AETERM | Reported Term for the Adverse Event | Char | 200 | CRF | — | `str_trim(AE_VERBATIM_TERM)` |
| 6 | AEDECOD | Dictionary-Derived Term | Char | 200 | Derived | MedDRA PT | See §Derivations.D2 |
| 7 | AEBODSYS | Body System or Organ Class | Char | 200 | Derived | MedDRA SOC | See §Derivations.D2 |
| 8 | AESOC | Primary System Organ Class | Char | 200 | Derived | MedDRA SOC | Same as AEBODSYS |
| 9 | AEHLT | High Level Term | Char | 200 | Derived | MedDRA HLT | See §Derivations.D2 |
| 10 | AELLT | Lowest Level Term | Char | 200 | Derived | MedDRA LLT | See §Derivations.D2 |
| 11 | AESTDTC | Start Date/Time of AE | Char | 10 | CRF | — | `AE_START_DATE` (ISO 8601, direct) |
| 12 | AEENDTC | End Date/Time of AE | Char | 10 | CRF | — | `AE_END_DATE` (direct; may be NA for ongoing) |
| 13 | AESEV | Severity/Intensity | Char | 20 | Derived | AESEV | See §Derivations.D3 |
| 14 | AETOXGR | Standard Toxicity Grade | Char | 1 | Derived | CTCAE v5.0 | Map AESEV: MILD=1, MODERATE=2, SEVERE=3, LIFE-THREATENING=4, FATAL=5 |
| 15 | AESER | Serious Event | Char | 1 | CRF | NY | Map raw `SERIOUS` to `Y/N` |
| 16 | AEREL | Causality | Char | 1 | CRF | NY | See §Derivations.D3 (RELATED_TO_STUDY_DRUG mapping) |
| 17 | AEACN | Action Taken with Study Treatment | Char | 40 | Derived | ACN | See §Derivations.D3 |
| 18 | AEOUT | Outcome of Adverse Event | Char | 40 | Derived | OUT | See §Derivations.D3 |
| 19 | AECAT | Category for Adverse Event | Char | 40 | Derived | — | `"IMMUNE-RELATED"` if `IRAEFL=="Y"`; else trim+upper raw AECAT if present; else NA |
| 20 | AESDTH | Results in Death | Char | 1 | Derived | NY | `"Y"` if `OUTCOME ∈ {FATAL, DEATH}`; else `"N"` |
| 21 | AESHOSP | Requires/Prolongs Hospitalization | Char | 1 | — | NY | NA (not collected) |
| 22 | AESLIFE | Is Life Threatening | Char | 1 | — | NY | NA (not collected) |
| 23 | AESDISAB | Persist/Significant Disability/Incapacity | Char | 1 | — | NY | NA (not collected) |
| 24 | AESMIE | Other Medically Important Event | Char | 1 | — | NY | NA (not collected) |
| 25 | AESCONG | Congenital Anomaly or Birth Defect | Char | 1 | — | NY | NA (not collected) |
| 26 | AEDISCOD | AE Led to Drug Discontinuation | Char | 1 | CRF | NY | `"Y"` if `LEADING_TO_DISCONTINUATION ∈ {Y,YES,TRUE,1}`; else `"N"` (non-standard SDTM var; SDTMIG home is `SUPPAE.AEDISFL`) |

## Derivations

### D1 — AESEQ (sequence per subject)

```
sort by (USUBJID, AESTDTC)
AESEQ <- row_number() within each USUBJID
```

This sort key MUST be identical to the one used in `programs/sdtm/suppae.R` so that SUPPAE.IDVARVAL matches the parent AE.AESEQ.

### D2 — MedDRA coding (AEDECOD / AEBODSYS / AESOC / AEHLT / AELLT)

```
v_up <- str_to_upper(str_trim(AE_VERBATIM_TERM))
idx  <- match(v_up, meddra$LLT_NAME_UPPER)          # exact LLT match
for each unmatched i:
   fuzz <- agrep(v_up[i], meddra$LLT_NAME_UPPER, max.distance = 0.2)
   if length(fuzz) > 0: idx[i] <- fuzz[1]

if matched:
   AEDECOD  <- meddra$PT_NAME[idx]
   AEBODSYS <- meddra$SOC_NAME[idx]
   AESOC    <- meddra$SOC_NAME[idx]
   AEHLT    <- meddra$HLT_NAME[idx]
   AELLT    <- meddra$LLT_NAME[idx]
   IRAEFL   <- meddra$IRAEFL[idx]   # used by AECAT and SUPPAE.IRAEFL
else:
   AEDECOD  <- v_up
   AEBODSYS <- NA;  AESOC <- NA;  AEHLT <- NA
   AELLT    <- AE_VERBATIM_TERM (preserved verbatim)
   IRAEFL   <- "N"
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §5.1 for the full MedDRA lookup spec.

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
| AEDECOD/AEBODSYS/AESOC/AEHLT/AELLT | MedDRA v27.0 | `raw/codelists/meddra_oncology_subset.csv` (oncology-relevant subset, ~3,500 LLTs) |
| AESEV | AESEV (C66769) | CDISC CT 2024-03 |
| AETOXGR | CTCAE v5.0 | NCI CTCAE — integer grades 1-5 stored as character |
| AESER/AEREL | NY (C66742) | CDISC CT 2024-03 |
| AEACN | ACN (C66767) | CDISC CT 2024-03 |
| AEOUT | OUT (C66768) | CDISC CT 2024-03 |

## QC Checks

- [ ] `nrow(ae) == 2837` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `AESEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, AESEQ)`
- [ ] `AESTDTC` non-missing for all rows; `AEENDTC >= AESTDTC` where non-missing
- [ ] `AESEV ∈ {MILD, MODERATE, SEVERE, LIFE-THREATENING, FATAL}`
- [ ] `AETOXGR ∈ {"1","2","3","4","5"}` and consistent with AESEV
- [ ] `AESER`, `AEREL`, `AEDISCOD`, `AESDTH ∈ {Y, N}`
- [ ] `AESDTH == "Y"` iff `AEOUT == "FATAL"`
- [ ] AECAT == "IMMUNE-RELATED" rate ≈ 18-22% of AE rows (target ≈25% in TORIVUMAB arm)
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-AE-spec.md` | `programs/sdtm/ae.R` | `datasets/sdtm/ae.parquet` |

SUPPAE (IRAEFL, AEDISFL, AEACTFL) — see `programs/sdtm/SDTM-MAPPING-SPEC.md` §18 / `programs/sdtm/suppae.R`.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
