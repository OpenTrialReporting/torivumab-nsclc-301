# SDTM-PROVENANCE.md — SDTM Mapping Development Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

The SDTM datasets in `datasets/sdtm/` are derived from simulated raw data in `raw/` via
mapping programs in `programs/sdtm/`. No real patient data is represented.

The mapping programs follow CDISC SDTM Implementation Guide v3.4 (variable labels attached
via `16_label_domains.R`) and the CDISC Oncology Disease Response Supplement (RECIST 1.1,
2023), but have not been reviewed by a regulatory authority and are not intended for
regulatory submission.

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

| Domain | File | SDTM IG Section | Records | Status |
|---|---|---|---|---|
| DM — Demographics | `programs/sdtm/dm.R` | 6.2.1 | 450 | Scripted |
| DS — Disposition | `programs/sdtm/ds.R` | 6.2.2 | 1,350 | Scripted |
| EX — Exposure | `programs/sdtm/ex.R` | 6.2.4 | 11,710 | Scripted |
| DA — Drug Accountability | `programs/sdtm/da.R` ← `raw/drug_accountability.csv` | 6.5 | 28,108 | Scripted (v0.2 back-fill 2026-05-16; CRF→SDTM 1:1 since v0.3 same day) |
| AE — Adverse Events | `programs/sdtm/ae.R` | 6.2.5 | 2,837 | Scripted |
| CM — Concomitant Meds | `programs/sdtm/cm.R` | 6.2.6 | 2,222 | Scripted |
| LB — Lab Results | `programs/sdtm/lb.R` | 7.2.1 | 115,394 | Scripted |
| VS — Vital Signs | `programs/sdtm/vs.R` | 7.2.3 | 46,095 | Scripted |
| MH — Medical History | `programs/sdtm/mh.R` | 6.2.8 | 2,051 | Scripted |
| PE — Physical Exam | `programs/sdtm/pe.R` | 7.3.1 | 22,662 | Scripted |
| TU — Tumor ID | `programs/sdtm/tu.R` | Onco suppl. | 7,686 | Scripted |
| TR — Tumor Results | `programs/sdtm/tr.R` | Onco suppl. | 7,724 | Scripted |
| RS — Disease Response | `programs/sdtm/rs.R` | Onco suppl. | 2,260 | Scripted |
| DD — Death Details | `programs/sdtm/dd.R` | Onco suppl. | 284 | Scripted |
| SU — Substance Use | `programs/sdtm/su.R` | 6.2.10 | 1,236 | Scripted |
| DV — Protocol Deviations | `programs/sdtm/dv.R` ← `raw/protocol_deviations.csv` | 6.5 | ~337 | Scripted (v0.4 2026-05-17; closes AL-03) |
| SUPPDM | `programs/sdtm/suppdm.R` | 8.4 | 1,799 | Scripted |
| SUPPAE | `programs/sdtm/suppae.R` | 8.4 | 8,511 | Scripted (v0.2 back-fill 2026-05-16) |
| SUPPCM | `programs/sdtm/suppcm.R` | 8.4 | 4,444 | Scripted (v0.2 back-fill 2026-05-16) |
| SUPPLB | `programs/sdtm/supplb.R` | 8.4 | 230,788 | Scripted (v0.2 back-fill 2026-05-16) |
| SUPPSU | `programs/sdtm/suppsu.R` | 8.4 | one SMKSTAT row per tobacco-using subject | Scripted (v0.4 rebuild 2026-05-17; closes AL-01) |
| RELREC | `programs/sdtm/relrec.R` | 8.5 | deduped per unique relationship | Scripted (v0.2 back-fill 2026-05-16; deduped v0.4 2026-05-17; closes AL-11) |

**Total: 22 SDTM datasets.**

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
| SDTM-D-01 | SDTM IG version | v3.4 | Locked at protocol time; aligns with FDA/PMDA submission expectations and AGENTS.md standards table |
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
| `programs/sdtm/SDTM-MAPPING-SPEC.md` | **Companion.** Variable-level mapping spec written for independent double programming — covers all 22 SDTM datasets from raw inputs. The R scripts in this directory are one implementation; the spec is the authoritative description. |
| `programs/raw/RAW-PROVENANCE.md` | **Parent.** Raw CSVs are the input to these mapping programs. |
| `datasets/sdtm/` | **Output.** 22 parquet files produced by these programs. |
| `sap/shells/shells.yaml` | **Sibling.** Shell annotations reference SDTM variables; Phase 2 annotation update will cross-check. |
| `programs/adam/` | **Downstream.** ADaM programs read from datasets/sdtm/. |
| `adam/ADAM-PROVENANCE.md` | **Child.** ADaM derivation builds on these SDTM datasets. |

---

## 9. Open Items

| Item | Domain | Status |
|---|---|---|
| ~~SUPPCM for ATC code~~ | CM | ✅ Resolved 2026-05-16 — `programs/sdtm/suppcm.R` writes CMATC + CMIRAEFL. CMATC remains denormalised on parent CM for ADaM back-compat. |
| ~~SUPPAE for additional AE qualifiers~~ | AE | ✅ Resolved 2026-05-16 — `programs/sdtm/suppae.R` writes IRAEFL, AEDISFL, AEACTFL. |
| ~~BICR response assessments~~ | RS | ✅ Resolved 2026-05-17 — `programs/raw/10_overall_response.R` emits both INVESTIGATOR and INDEPENDENT ASSESSOR reads (~10% discordance, conservative tilt). SDTM.RS now carries `RSEVAL`; downstream ADTTE derives PFS (BICR) + PFSINV (Investigator). |
| LAB reference ranges | LB | Current ranges are generic; should be replaced with site-specific or sponsor-defined ranges |
| Parent-domain label gaps | AE/CM/DD/SU | Pre-existing: AEDISCOD, CMATC, DDSCAT, SUPACKYRS not in label dictionary; `suppsu` has no entry. Cosmetic — does not block submission readiness. |
| Define-XML v1.0 | All | ✅ v0.1 draft 2026-05-16 (`programs/define/build_define.R` → `define/define.xml`). v1.0 still requires Value-Level Metadata, full CodeListDef references, MethodDef chains, WhereClauseDef blocks, and XSL→PDF rendering. |

---

## 10. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial. 15 domain mapping programs written. Curated MedDRA/ATC codelists in place. |
| 0.2 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Back-fill: added DA (24,613 rec), RELREC (17,708 rec / 2,266 groups), SUPPAE (8,511), SUPPCM (4,444), SUPPLB (230,788). Extended `00_run_sdtm.R` orchestrator + `16_label_domains.R` label dictionary. Resolved SUPPAE/SUPPCM open items. Generated Define-XML v0.1 (`define/define.xml`, 27 ItemGroupDefs, 446 ItemDefs). DA initially derived from `raw/exposure.csv` as an architectural shortcut. |
| 0.3 | 2026-05-16 | LG (w/ Claude Opus 4.7) | DA lineage corrected: added `programs/raw/14_drug_accountability.R` (CDASH DA form simulator → `raw/drug_accountability.csv`, 11,710 rows incl. simulated vial losses). Rewrote `programs/sdtm/da.R` to read the new raw CSV. DA now 28,108 records (gained LOSTAMT test + VISIT variable). Define-XML refreshed: 447 variables. |
| 0.4 | 2026-05-17 | LG (w/ Claude Opus 4.7) | **22 domains.** Added SDTM.DV (Protocol Deviations) via `programs/sdtm/dv.R` ← `raw/protocol_deviations.csv` (closes AL-03). Rebuilt SUPPSU via dedicated `programs/sdtm/suppsu.R` under canonical STUDYID with the standardised SMKSTAT QNAM (CURRENT SMOKER / EX-SMOKER / NEVER SMOKED) decoded from SU.SUSCAT (closes AL-01). Deduped RELREC via `distinct()` on (STUDYID, USUBJID, RDOMAIN, RSUBJID, IDVAR, IDVARVAL, RELTYPE, RELID) (closes AL-11). Added BICR reader to SDTM.RS (`RSEVAL ∈ {INVESTIGATOR, INDEPENDENT ASSESSOR}`) via upstream `programs/raw/10_overall_response.R` (enables AL-04/AL-07 closure downstream). Define-XML refreshed: 34 ItemGroupDefs / 613 variables. |
| 0.5 | 2026-07-19 | LG (w/ Claude Opus 4.8 1M) | **Pinnacle 21 remediation (SDTM ~590K → 10,981; residual dominated by the accepted SD0007 DA-units warning) + DD cause fix + unscheduled visits.** Created Trial Design domains **TS/TA/TE/SE** (clears the SD1115 Reject); `EPOCH` + `--DY` study-days via new `17_derive_timing.R`; DM expected reference/arm/death vars (`ARMCD`/`RFXSTDTC`/`DTHDTC`/…); DA `DASTDTC → DADTC` + `VISITNUM`; AE MedDRA coded 100% (fixed an unquoted-comma bug in `meddra_oncology_subset.csv` + normalisation) with numeric codes, treatment-emergent `AETRTEM` in SUPPAE, imputed recovered-AE end dates, de-dup; DS `OTHER → PHYSICIAN DECISION`; SU/DV/DD/CM/MH/PE cleanups. **DD:** cause of death moved from the non-standard `DDTERM` to the standard `DDORRES` (result of the `PRCDTH` test). **Unscheduled visits:** `lb.R`/`vs.R` map `VISIT="UNSCHEDULED"`, `VISITNUM=998` — a single label↔number bijection so P21 **SD0051** stays clean; records disambiguated by date/seq. Validated with the bundled Community CLI (`qc/run_p21.sh`, engine 2508.1, CT 2026-03-27). Define-XML regenerated (38 datasets incl. Trial Design; `def:CommentDef` annotations for accepted limitations). |
