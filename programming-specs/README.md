# Programming Specifications

Per-dataset specifications for the 22 raw-derived SDTM domains and 12 ADaM datasets
produced by this study (the 4 trial-design domains TS/TA/TE/SE carry no derivation
spec; `datasets/sdtm/` holds 26 domains in total). Each spec is the authoritative description of one dataset:
variable list (8-column table), origins, codelists, derivation pseudocode, QC
checks, traceability, and change log.

These per-dataset specs are intended for QC double programming (a second
programmer should be able to re-derive the dataset from the spec alone) and for
inclusion in the Define-XML / ADRG submission package. They complement — but do
not replace — the consolidated mapping specs:

| Layer | Consolidated mapping spec | Per-dataset specs |
|---|---|---|
| Raw → SDTM | [`programs/sdtm/SDTM-MAPPING-SPEC.md`](../programs/sdtm/SDTM-MAPPING-SPEC.md) | `SDTM-*-spec.md` (this directory) |
| SDTM → ADaM | [`programs/adam/ADAM-MAPPING-SPEC.md`](../programs/adam/ADAM-MAPPING-SPEC.md) | `AD*-spec.md` (this directory) |

The consolidated specs hold the full pseudocode and cross-domain helpers; the
per-dataset specs cross-reference back into the consolidated spec where pseudocode
is shared (e.g. `--SEQ` derivation, VISIT lookup, MedDRA coding).

---

## SDTM domain specs (22)

| Domain | Class | Records | Spec |
|---|---|---:|---|
| DM | SPECIAL PURPOSE | 450 | [SDTM-DM-spec.md](SDTM-DM-spec.md) |
| AE | EVENTS | 2,840 | [SDTM-AE-spec.md](SDTM-AE-spec.md) |
| CM | INTERVENTIONS | 2,319 | [SDTM-CM-spec.md](SDTM-CM-spec.md) |
| DA | INTERVENTIONS | 18,463 | [SDTM-DA-spec.md](SDTM-DA-spec.md) |
| DD | FINDINGS (Onco) | 312 | [SDTM-DD-spec.md](SDTM-DD-spec.md) |
| DS | EVENTS | 1,350 | [SDTM-DS-spec.md](SDTM-DS-spec.md) |
| DV | EVENTS | 337 | [SDTM-DV-spec.md](SDTM-DV-spec.md) |
| EX | INTERVENTIONS | 13,403 | [SDTM-EX-spec.md](SDTM-EX-spec.md) |
| LB | FINDINGS | 136,242 | [SDTM-LB-spec.md](SDTM-LB-spec.md) |
| MH | EVENTS | 2,061 | [SDTM-MH-spec.md](SDTM-MH-spec.md) |
| PE | FINDINGS | 25,596 | [SDTM-PE-spec.md](SDTM-PE-spec.md) |
| RS | FINDINGS (Onco) | 5,338 | [SDTM-RS-spec.md](SDTM-RS-spec.md) |
| SU | INTERVENTIONS | 1,229 | [SDTM-SU-spec.md](SDTM-SU-spec.md) |
| TR | FINDINGS (Onco) | 6,136 | [SDTM-TR-spec.md](SDTM-TR-spec.md) |
| TU | FINDINGS (Onco) | 9,012 | [SDTM-TU-spec.md](SDTM-TU-spec.md) |
| VS | FINDINGS | 52,920 | [SDTM-VS-spec.md](SDTM-VS-spec.md) |
| RELREC | RELATIONSHIP | 12,831 | [SDTM-RELREC-spec.md](SDTM-RELREC-spec.md) |
| SUPPAE | RELATIONSHIP | 11,360 | [SDTM-SUPPAE-spec.md](SDTM-SUPPAE-spec.md) |
| SUPPCM | RELATIONSHIP | 4,516 | [SDTM-SUPPCM-spec.md](SDTM-SUPPCM-spec.md) |
| SUPPDM | RELATIONSHIP | 1,799 | [SDTM-SUPPDM-spec.md](SDTM-SUPPDM-spec.md) |
| SUPPLB | RELATIONSHIP | 272,484 | [SDTM-SUPPLB-spec.md](SDTM-SUPPLB-spec.md) |
| SUPPSU | RELATIONSHIP | 450 | [SDTM-SUPPSU-spec.md](SDTM-SUPPSU-spec.md) |

## ADaM dataset specs (12)

| Dataset | Class | Records | Spec |
|---|---|---:|---|
| ADSL | SUBJECT LEVEL ANALYSIS DATASET | 450 | [ADSL-spec.md](ADSL-spec.md) |
| ADAE | OCCURRENCE DATA STRUCTURE | 2,840 | [ADAE-spec.md](ADAE-spec.md) |
| ADCM | OCCURRENCE DATA STRUCTURE | 2,319 | [ADCM-spec.md](ADCM-spec.md) |
| ADDS | OCCURRENCE DATA STRUCTURE | 1,350 | [ADDS-spec.md](ADDS-spec.md) |
| ADDV | OCCURRENCE DATA STRUCTURE | 337 | [ADDV-spec.md](ADDV-spec.md) |
| ADEX | BASIC DATA STRUCTURE | 16,097 | [ADEX-spec.md](ADEX-spec.md) |
| ADLB | BASIC DATA STRUCTURE | 136,242 | [ADLB-spec.md](ADLB-spec.md) |
| ADMH | OCCURRENCE DATA STRUCTURE | 2,061 | [ADMH-spec.md](ADMH-spec.md) |
| ADRS | BASIC DATA STRUCTURE | 3,569 | [ADRS-spec.md](ADRS-spec.md) |
| ADTR | BASIC DATA STRUCTURE | 9,255 | [ADTR-spec.md](ADTR-spec.md) |
| ADTTE | BASIC DATA STRUCTURE | 2,377 | [ADTTE-spec.md](ADTTE-spec.md) |
| ADVS | BASIC DATA STRUCTURE | 52,920 | [ADVS-spec.md](ADVS-spec.md) |

---

## Spec template

All per-dataset specs share the following structure:

```
# {DOMAIN} — {Label} — {SDTM|ADaM} Programming Specification

## Header              -- 8-row table (dataset, label, class, structure,
                         expected N, key vars, IG version, spec version,
                         author, date)
## Purpose             -- one paragraph
## Source / Dependencies -- table of input datasets
## Variables           -- 8-column table:
                         # | Variable | Label | Type | Length | Origin |
                         Codelist | Derivation
## Derivations         -- named sub-rules with pseudocode (D1, D2, ...)
## Controlled Terminology -- codelist references
## QC Checks           -- checklist for the double-programmer
## Traceability        -- spec → code → output
## Change Log          -- version / date / author / change
```

## Standards

| Standard | Version | Used by |
|---|---|---|
| CDISC SDTMIG | v3.4 | SDTM specs |
| CDISC ADaMIG | v1.3 | ADaM specs |
| CDISC Oncology Disease Response Supplement | 2023 | TU, TR, RS, DD specs |
| CDISC CT | 2024-03 | All controlled-term columns |
| MedDRA | v27.0 | AE, MH |
| WHO ATC | (current) | CM |
| CTCAE | v5.0 | AE.AESEV |
| RECIST | 1.1 | TU, TR, RS |

## Double programming

The QC workflow requires a second programmer to re-derive every dataset from
its per-dataset spec **without reading** `programs/sdtm/*.R` or
`programs/adam/*.R`. The consolidated mapping specs are permitted as a
secondary reference. See [`qc/VALIDATION-PLAN.md`](../qc/VALIDATION-PLAN.md)
§1–§4 for the full QC protocol and `qc/*-PROGRAMMING-TRACKER.xlsx` for the
per-dataset progress trackers.
