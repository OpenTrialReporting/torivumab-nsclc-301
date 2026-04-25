# ADAE — Adverse Event Analysis Dataset — Programming Specification

## Header

| Field | Value |
|---|---|
| **Dataset** | ADAE |
| **Label** | Adverse Event Analysis Dataset |
| **Class** | BASIC DATA STRUCTURE |
| **Structure** | One record per subject per adverse event |
| **Expected N** | ~4,500 records (estimated; ~10 AEs/subject × 450 subjects) |
| **Key variables** | `USUBJID`, `AESEQ` |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-04-25 |

## Purpose

ADAE supports all safety analyses: overall TEAE incidence (T-AE-01), AE by SOC/PT (T-AE-02), Grade ≥3 AEs (T-AE-03), SAEs (T-AE-04), irAEs (T-AE-05), AESIs (T-AE-06), and AE-related deaths (T-AE-07). The TRTEMFL flag defines the treatment-emergent window per SAP §4.5 (onset ≥ TRTSDT and ≤ TRTEDT + 30 days).

## Dependencies

| Input | Source | Reason |
|---|---|---|
| ADSL | `adam/adsl.parquet` | Treatment dates (TRTSDT, TRTEDT), population flags |
| SDTM.AE | `sdtm/ae.parquet` | AE records, MedDRA coding, severity, seriousness |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `AE.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `AE.USUBJID` |
| 3 | SUBJID | Subject Identifier | Char | 10 | Predecessor | — | `AE.SUBJID` |
| 4 | SITEID | Study Site Identifier | Char | 10 | Predecessor | — | `AE.SITEID` |
| 5 | SAFFL | Safety Population Flag | Char | 1 | Derived | NY | Merged from ADSL.SAFFL |
| 6 | ITTFL | ITT Population Flag | Char | 1 | Derived | NY | Merged from ADSL.ITTFL |
| 7 | TRT01P | Planned Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01P |
| 8 | TRT01A | Actual Treatment for Period 01 | Char | 40 | Derived | — | Merged from ADSL.TRT01A |
| 9 | TRTSDT | Date of First Exposure to Treatment | Date | — | Derived | — | Merged from ADSL.TRTSDT |
| 10 | TRTEDT | Date of Last Exposure to Treatment | Date | — | Derived | — | Merged from ADSL.TRTEDT |
| 11 | AESEQ | Sequence Number | Num | 8 | Predecessor | — | `AE.AESEQ` |
| 12 | AEDECOD | Dictionary-Derived Term | Char | 200 | Predecessor | MedDRA PT | `AE.AEDECOD` |
| 13 | AEBODSYS | Body System or Organ Class | Char | 200 | Predecessor | MedDRA SOC | `AE.AEBODSYS` |
| 14 | AEHLT | High Level Term | Char | 200 | Predecessor | MedDRA HLT | `AE.AEHLT` |
| 15 | AELLT | Lowest Level Term | Char | 200 | Predecessor | MedDRA LLT | `AE.AELLT` |
| 16 | AESTDTC | Start Date/Time of AE | Char | 20 | Predecessor | — | `AE.AESTDTC` |
| 17 | AEENDTC | End Date/Time of AE | Char | 20 | Predecessor | — | `AE.AEENDTC` |
| 18 | ASTDT | Analysis Start Date | Date | — | Derived | — | `admiral::derive_vars_dt(AESTDTC)` |
| 19 | AENDT | Analysis End Date | Date | — | Derived | — | `admiral::derive_vars_dt(AEENDTC)` |
| 20 | AESEV | Severity/Intensity | Char | 8 | Predecessor | AESEV | `AE.AESEV` |
| 21 | AETOXGR | Standard Toxicity Grade | Char | 2 | Predecessor | NCI CTCAE | `AE.AETOXGR` |
| 22 | AETOXGRN | Standard Toxicity Grade (N) | Num | 8 | Derived | — | `as.integer(AETOXGR)` |
| 23 | AESER | Serious Event | Char | 1 | Predecessor | NY | `AE.AESER` |
| 24 | AEREL | Causality | Char | 16 | Predecessor | — | `AE.AEREL` |
| 25 | AEACN | Action Taken with Study Treatment | Char | 32 | Predecessor | — | `AE.AEACN` |
| 26 | AEOUT | Outcome of Adverse Event | Char | 32 | Predecessor | — | `AE.AEOUT` |
| 27 | AECAT | Category for Adverse Event | Char | 40 | Predecessor | — | `AE.AECAT` |
| 28 | TRTEMFL | Treatment Emergent Analysis Flag | Char | 1 | Derived | NY | `admiral::derive_var_trtemfl()`: ASTDT ≥ TRTSDT and ASTDT ≤ TRTEDT + 30 days |
| 29 | IRAEFL | Immune-Related AE Flag *(study-specific)* | Char | 1 | Derived | NY | `if_else(AECAT == "IMMUNE-RELATED", "Y", "N")` |
| 30 | ANL01FL | Analysis Flag 01 (TEAE analysis) | Char | 1 | Derived | NY | `if_else(TRTEMFL == "Y", "Y", NA)` |
| 31 | AVAL | Analysis Value | Num | 8 | Derived | — | `AETOXGRN` (for grade shift analyses) |
| 32 | AESCONG | Congenital Anomaly/Birth Defect | Char | 1 | Predecessor | NY | `AE.AESCONG` |
| 33 | AESDTH | Results in Death | Char | 1 | Predecessor | NY | `AE.AESDTH` |
| 34 | AESHOSP | Requires/Prolongs Hospitalisation | Char | 1 | Predecessor | NY | `AE.AESHOSP` |
| 35 | AESLIFE | Is Life Threatening | Char | 1 | Predecessor | NY | `AE.AESLIFE` |
| 36 | AESDISAB | Causes Persistent Disability/Incapacity | Char | 1 | Predecessor | NY | `AE.AESDISAB` |
| 37 | AESMIE | Other Medically Important Serious Event | Char | 1 | Predecessor | NY | `AE.AESMIE` |

## Key Derivation Notes

**TRTEMFL treatment window:** Per SAP §4.5 — AE is treatment-emergent if ASTDT ≥ TRTSDT and ASTDT ≤ TRTEDT + 30 days. Uses `admiral::derive_var_trtemfl(end_window = 30)`.

**IRAEFL:** Study-specific flag based on CRF field `AE.AECAT`. Immune-related AEs are those coded with AECAT = "IMMUNE-RELATED". Not a CDISC standard variable — must be documented in define.xml as study-specific.

**Missing AESTDTC:** Partial dates imputed using `admiral::derive_vars_dt()` with imputation = "first". If day is missing, imputed to 1st of month. If month is missing, imputed to January. ASTDTF captures imputation flag.

## Shell Cross-Reference

| Shell ID | Shell title | ADAE variables used |
|---|---|---|
| T-AE-01 | Overview of Treatment-Emergent Adverse Events | TRTEMFL, AESER, AESDTH, AEREL, AEACN |
| T-AE-02 | Treatment-Emergent Adverse Events by SOC and PT | TRTEMFL, AEBODSYS, AEDECOD, AETOXGRN, ANL01FL |
| T-AE-03 | Grade ≥3 Treatment-Emergent Adverse Events | TRTEMFL, AETOXGRN ≥ 3 |
| T-AE-04 | Serious Adverse Events | AESER, AESDTH, AEREL |
| T-AE-05 | Immune-Related Adverse Events | IRAEFL, AETOXGRN, AECAT |
| T-AE-06 | Adverse Events of Special Interest | AECAT = "AESI" (TBD) |
| T-AE-07 | Deaths | AESDTH, AEOUT = "FATAL" |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. Preliminary — confirm IRAEFL coding with CRF team. |
| 0.2 | — | — | Confirm after Phase 5 ADaM delivery. |
