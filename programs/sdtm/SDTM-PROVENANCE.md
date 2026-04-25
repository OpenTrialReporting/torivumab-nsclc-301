# SDTM-PROVENANCE.md — SDTM Mapping Development Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

The SDTM datasets in `datasets/sdtm/` are derived from simulated raw data in `raw/` via
mapping programs in `programs/sdtm/`. No real patient data is represented.

The mapping programs follow CDISC SDTM Implementation Guide v3.3 and the CDISC Oncology
Disease Response Supplement (RECIST 1.1, 2023), but have not been reviewed by a regulatory
authority and are not intended for regulatory submission.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-sonnet-4-6` |
| **Interface** | Cowork (Claude desktop app) |
| **Role** | Writing SDTM mapping programs, MedDRA/ATC coding logic, SUPPQUAL structure |
| **Human oversight** | Lovemore Gakava — confirmed domain scope, coding approach, SDTM IG alignment |
| **Programs written** | 2026-04-25 |

---

## 3. Package Stack

| Package | Role |
|---|---|
| `dplyr` / `tidyr` / `stringr` | Data transformation and variable derivation |
| `lubridate` | Date arithmetic (AGE, DTC conversion) |
| `arrow` | Parquet I/O for output datasets |
| `sdtm.oak` | Pharmaverse SDTM mapping utility (structured for drop-in use; fallback to dplyr where API uncertain) |

---

## 4. Domain Inventory

| Domain | File | SDTM IG Section | Records (approx.) | Status |
|---|---|---|---|---|
| DM — Demographics | `programs/sdtm/dm.R` | 6.2.1 | 450 | Scripted |
| DS — Disposition | `programs/sdtm/ds.R` | 6.2.2 | ~1,350 | Scripted |
| EX — Exposure | `programs/sdtm/ex.R` | 6.2.4 | ~5,000 | Scripted |
| AE — Adverse Events | `programs/sdtm/ae.R` | 6.2.5 | ~4,500 | Scripted |
| CM — Concomitant Meds | `programs/sdtm/cm.R` | 6.2.6 | ~3,000 | Scripted |
| LB — Lab Results | `programs/sdtm/lb.R` | 7.2.1 | ~27,000 | Scripted |
| VS — Vital Signs | `programs/sdtm/vs.R` | 7.2.3 | ~18,000 | Scripted |
| MH — Medical History | `programs/sdtm/mh.R` | 6.2.8 | ~1,800 | Scripted |
| PE — Physical Exam | `programs/sdtm/pe.R` | 7.3.1 | ~12,000 | Scripted |
| TU — Tumor ID | `programs/sdtm/tu.R` | Onco suppl. | ~3,000 | Scripted |
| TR — Tumor Results | `programs/sdtm/tr.R` | Onco suppl. | ~8,000 | Scripted |
| RS — Disease Response | `programs/sdtm/rs.R` | Onco suppl. | ~5,400 | Scripted |
| DD — Death Details | `programs/sdtm/dd.R` | Onco suppl. | ~180 | Scripted |
| SU — Substance Use | `programs/sdtm/su.R` | 6.2.10 | ~700 | Scripted |
| SUPPDM | `programs/sdtm/suppdm.R` | 8.4 | ~1,800 | Scripted |

---

## 5. Medical Coding

### 5.1 MedDRA (AE domain)

**Dictionary version:** Curated public-source subset (see `raw/codelists/meddra_oncology_subset.csv`).
Not a licensed MedDRA dictionary. Covers ~80 terms across 15 SOCs relevant to NSCLC immunotherapy.

**Coding logic (ae.R):**
1. Exact case-insensitive match: `AE_VERBATIM_TERM` → `LLT_NAME` in subset
2. Fuzzy fallback: `agrep(max.distance = 0.2)` to nearest LLT_NAME if no exact match
3. PT, HLT, SOC populated from matched row
4. `AECAT = "IMMUNE-RELATED"` if `IRAEFL == "Y"` in codelist or explicitly set in raw AE record

**Production note:** Replace `raw/codelists/meddra_oncology_subset.csv` with a licensed MedDRA
dictionary (all LLT/PT/HLT/HLGT/SOC levels) and a validated autocoding engine. The `ae.R` mapping
logic is structured to accept a full dictionary by changing only the codelist file path.

### 5.2 WHODrug / ATC (CM domain)

**Dictionary:** WHO ATC classification (freely published; see `raw/codelists/atc_conmed.csv`).
Covers ~40 supportive care medications common in NSCLC trials.

**Coding logic (cm.R):**
1. Case-insensitive match: `DRUG_NAME_VERBATIM` → `DRUG_NAME_VERBATIM_1` or `DRUG_NAME_VERBATIM_2`
2. `CMDECOD` = standardised drug name (`DRUG_NAME` from ATC lookup)
3. `CMATC` (study-specific SUPPQUAL) = `ATC_CODE`

**Production note:** Replace with a licensed WHODrug dictionary and autocoding. The ATC code is
stored as study-specific variable `CMATC` in SUPPCM (to be derived in a future phase).

### 5.3 CDISC Controlled Terminology

CDISC CT applied via `raw/codelists/cdisc_ct.csv`. Key codelists used:

| SDTM variable | Codelist | Version note |
|---|---|---|
| DM.SEX | C66742 (SEX) | CDISC CT |
| DM.RACE | C74456 (RACE) | CDISC CT |
| DM.ETHNIC | C66790 (ETHNIC) | CDISC CT |
| AE.AESEV | C99079 (AESEV) | CTCAE severity |
| AE.AEREL | C66767 (AEREL) | Causality |
| AE.AEACN | C66768 (AEACN) | Action taken |
| AE.AEOUT | C66769 (AEOUT) | Outcome |
| DS.DSDECOD | C66728 (DSDECOD) | Disposition decode |
| RS.RSSTRESC | C99158 (NRRESP) | RECIST response |
| LB.LBNRIND | C101854 (NRIND) | Normal range indicator |

---

## 6. Key Design Decisions

| ID | Decision | Choice | Rationale |
|---|---|---|---|
| SDTM-D-01 | SDTM IG version | v3.3 | Current version at time of build; aligns with FDA/PMDA submission expectations |
| SDTM-D-02 | Oncology domains | SDTM Oncology Disease Response Supplement (RECIST 1.1, 2023) | Required for TU, TR, RS, DD domains |
| SDTM-D-03 | MedDRA substitution | Curated 80-term public-source subset | Licensed dictionary unavailable; subset covers all simulated AE verbatim terms; structured for drop-in replacement |
| SDTM-D-04 | WHODrug substitution | WHO ATC classification | ATC codes are freely published; covers all simulated conmed drugs |
| SDTM-D-05 | Intermediate format | Parquet (arrow) | Efficient; no SAS dependency; XPT produced by xportr in ADaM phase for submission |
| SDTM-D-06 | SUPPQUAL structure | SUPPDM for DM non-standard variables | ECOGBSL, PDL1SCR, PDL1GRP, HISTSCAT — required for ADaM subgroup analyses |
| SDTM-D-07 | irAE flag in AE | AECAT = "IMMUNE-RELATED" | Aligns with ADAE IRAEFL derivation; SAP §4.5; consistent with KEYNOTE-024 reporting |

---

## 7. How to Run

```r
# From project root:
source("programs/sdtm/00_run_sdtm.R")

# Or:
Rscript programs/sdtm/00_run_sdtm.R
```

**Prerequisite:** Raw CSVs must exist in `raw/`. Run `programs/raw/00_simulate_raw.R` first.

---

## 8. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `programs/raw/RAW-PROVENANCE.md` | **Parent.** Raw CSVs are the input to these mapping programs. |
| `datasets/sdtm/` | **Output.** 15 parquet files produced by these programs. |
| `sap/shells/shells.yaml` | **Sibling.** Shell annotations reference SDTM variables; Phase 2 annotation update will cross-check. |
| `programs/adam/` | **Downstream.** ADaM programs read from datasets/sdtm/. |
| `adam/ADAM-PROVENANCE.md` | **Child.** ADaM derivation builds on these SDTM datasets. |

---

## 9. Open Items

| Item | Domain | Status |
|---|---|---|
| SUPPCM for ATC code | CM | CMATC derivable from cm.R; SUPPCM program not yet written |
| SUPPAE for additional AE qualifiers | AE | Add if regulatory reviewer requests supplemental AE data |
| BICR response assessments | RS | Add RSCAT="BICR" records if BICR data becomes available |
| LAB reference ranges | LB | Current ranges are generic; should be replaced with site-specific or sponsor-defined ranges |
| Define-XML | All | `define/` directory present; define.xml generation deferred to submission preparation phase |

---

## 10. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial. 15 domain mapping programs written. Curated MedDRA/ATC codelists in place. |
| 0.2 | — | — | Run programs and validate output datasets. Resolve open items. |
