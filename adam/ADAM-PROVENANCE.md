# ADAM-PROVENANCE.md — ADaM Development Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

These ADaM datasets support a **fully synthetic** clinical trial dataset generated for educational purposes.
No real trial is described. All sponsor names, drug names, and study identifiers are fictional.

The ADaM programming specifications and derivation scripts were developed with **AI assistance** using
the methodology described below. The derivation logic is grounded in CDISC ADaMIG v1.3, CDISC Oncology
Disease Response Supplement (RECIST 1.1, 2023), and the pharmaverse admiral/admiralonco documentation,
but has not been validated against real clinical trial data or reviewed by a regulatory authority.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-sonnet-4-6` |
| **Interface** | Cowork (Claude desktop app) |
| **Role** | Drafting programming specifications, scaffolding R derivation scripts, admiral function selection |
| **Human oversight** | Lovemore Gakava — domain expert review of all specs; all derivation decisions confirmed by LG |
| **Phase 5 started** | 2026-04-25 |
| **Spec version recorded here** | v0.1 DRAFT |

### Division of labour

| Deliverable | Drafted by | Reviewed / decided by |
|---|---|---|
| PHASE-5-APPROACH.md (D-06 to D-09) | AI — proposed spec-first approach, pharmaverse stack, build order | LG — confirmed all four decisions |
| ADSL-spec.md | AI (draft 2026-04-20) | LG — back-validated against SAP at Gate 3.5 (D-09) |
| ADAE-spec.md | AI — proposed variables, TRTEMFL window, IRAEFL coding | LG — to review; IRAEFL source to confirm with CDM |
| ADLB-spec.md | AI — proposed baseline definition, ATOXGR approach, no-LOCF | LG — to review; CTCAE threshold codelist deferred |
| ADTR-spec.md | AI — proposed SLD summation, nadir, CDISC RECIST PARAMCD | LG — to review; partial SLD handling to confirm with CDM |
| ADRS-spec.md | AI — proposed OVR/BOR/CBOR/CBDCR using admiralonco | LG — to review; BICR handling deferred |
| ADTTE-spec.md | AI — proposed OS/PFS/DOR/TTR with FDA 2018 censoring hierarchy | LG — to review; BECOG/PDL1GR ADSL gap flagged |
| R derivation scripts (6 stubs) | AI — scaffolded with admiral function calls and section structure | LG — to complete and validate in Phase 5 |

---

## 3. Package Stack

All ADaM derivations use the pharmaverse open-source stack. Package versions to be pinned in
`adam/session_info.txt` on first run.

| Package | Role | Key functions used |
|---|---|---|
| `admiral` | Core ADaM derivation engine | `derive_vars_merged()`, `derive_vars_dt()`, `derive_var_base()`, `derive_var_chg()`, `derive_var_extreme_flag()`, `derive_param_tte()`, `derive_var_trtemfl()` |
| `admiralonco` | Oncology-specific derivations | `derive_param_bor()`, `derive_param_confirmed_bor()`, `derive_param_bor_adtr()` |
| `metacore` | Metadata governance | Spec → code → Define-XML pipeline; drives `xportr` labelling |
| `metatools` | Metadata utilities | `derive_vars_suppqual()`, codelist application |
| `xportr` | XPT export + conformance | `xportr_label()`, `xportr_length()`, `xportr_type()` |
| `arrow` | Parquet I/O | `read_parquet()`, `write_parquet()` |
| `dplyr` / `lubridate` | Data manipulation | Throughout all scripts |

**First derivation choice is always an existing `admiral` function.** Hand-coded `mutate()` / `case_when()` is documented as "custom derivation — no admiral equivalent" in the spec.

---

## 4. Build Order

Upstream datasets first. ADSL is the foundational dataset — every other ADaM merges ADSL population
flags and treatment dates onto its own rows.

| # | Dataset | Script | Depends on | Status |
|---|---|---|---|---|
| 1 | ADSL | `adam/adsl.R` | DM, DS, EX, SUPPDM | 🔲 Stub — ready to complete |
| 2 | ADAE | `adam/adae.R` | ADSL + AE | 🔲 Stub — ready to complete |
| 3 | ADLB | `adam/adlb.R` | ADSL + LB | 🔲 Stub — ready to complete |
| 4 | ADTR | `adam/adtr.R` | ADSL + TR, TU | 🔲 Stub — ready to complete |
| 5 | ADRS | `adam/adrs.R` | ADSL + ADTR + RS | 🔲 Stub — ready to complete |
| 6 | ADTTE | `adam/adtte.R` | ADSL + ADRS + DS, DD | 🔲 Stub — ready to complete |

**Gate 4 exit criteria:** All 6 datasets written, validated via `xportr`, and Parquet outputs committed.
OS/PFS HRs reconcile with data-raw seed assumptions (HR ≈ 0.65 / 0.55 ±0.1).

---

## 5. Key Derivation Decisions

| ID | Decision | Choice | Rationale | SAP ref |
|---|---|---|---|---|
| ADaM-D-01 | OS censoring date source | max(last study contact, last response assessment, DCO) | FDA 2018 guidance; most recent evidence of survival | SAP-D-01 |
| ADaM-D-02 | PFS — new anti-cancer therapy | Censor at last adequate assessment before therapy start | FDA 2018; avoids informative censoring | SAP-D-02 |
| ADaM-D-03 | PFS — missed assessments | Censor at last adequate if ≥2 consecutive missed | SAP pre-specified threshold | SAP-D-03 |
| ADaM-D-04 | ORR non-responder imputation | No post-baseline assessment → non-responder (CNSR = non-event) | Avoids best-case bias | SAP-D-04 |
| ADaM-D-05 | CR/PR confirmation window | ≥28 days; SD ≥8 weeks from TRTSDT | RECIST 1.1; SAP §4.3 | SAP §4.3 |
| ADaM-D-06 | IRAEFL source | `AE.AECAT == "IMMUNE-RELATED"` | CRF field; confirm with CDM team | ADAE spec |
| ADaM-D-07 | ATOXGR derivation | NCI CTCAE v5 via `admiral::derive_var_atoxgr_dir()` | Standardised grading; avoids custom thresholds | ADLB spec |
| ADaM-D-08 | Parquet as intermediate format | Parquet for all intermediate and final ADaM files | Efficient; no SAS dependency for intermediate work; XPT produced by xportr for submission | PHASE-5-APPROACH.md |

---

## 6. Open Items at v0.1

| Item | Dataset | Status |
|---|---|---|
| BECOG (ECOG PS) on ADSL | ADSL | Missing from spec; required for forest plot subgroups (SAP §10) |
| PDL1GR (PD-L1 TPS group) on ADSL | ADSL | Missing from spec; required for forest plot subgroups |
| IRAEFL source confirmation | ADAE | AECAT coding to be confirmed with CDM/CRF team |
| Partial SLD handling rule | ADTR | To be confirmed: include partial visit SLD or exclude? |
| BICR response assessments | ADRS | BICR data (RSCAT = "BICR") present in sdtm/rs.parquet? Check and add if so |
| ATOXGR reference codelist | ADLB | NCI CTCAE v5 grade thresholds table to be loaded via metacore |
| PARAMCD codelist for LB | ADLB | Mapping from LBTESTCD to PARAMCD per ADaMIG convention |
| Unit conversion table | ADLB | Conventional → SI unit conversions for chemistry parameters |

---

## 7. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `sap/SAP.md` (v0.1) | **Parent.** Every ADaM variable traces to an analysis in the SAP. No variable without a SAP reference. |
| `sap/shells/shells.yaml` | **Sibling.** TFL shell annotations cite ADaM variables; `validate_shells.R` cross-checks against specs. |
| `programming-specs/AD*-spec.md` | **Spec layer.** One spec per dataset; spec precedes and governs the R script. |
| `adam/ad*.R` | **Implementation.** R scripts implement the spec; must reconcile with spec before Gate 4. |
| `adam/adsl.parquet` … `adtte.parquet` | **Outputs.** Six Parquet files; also exported to XPT via `xportr` for submission package. |
| `data-raw/PROVENANCE.md` | **Parent of inputs.** Records how the SDTM parquet files were generated. |
| `sap/SAP-PROVENANCE.md` | **Sibling.** SAP development record; the ADaM specs operationalise the SAP. |

---

## 8. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. Six R stubs and five specs scaffolded. Phase 5 work begins. Open items listed above. |
| 0.2 | — | — | Complete derivation scripts; resolve open items; Gate 4 validation. |

---

*Last updated: 2026-04-25*
