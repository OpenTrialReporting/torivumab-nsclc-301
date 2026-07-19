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
| **Spec version recorded here** | v0.5 (12 ADaMs delivered; 2026-05-17) |

### Division of labour

| Deliverable | Drafted by | Reviewed / decided by |
|---|---|---|
| programs/adam/PHASE-5-APPROACH.md (D-06 to D-09) | AI — proposed spec-first approach, pharmaverse stack, build order | LG — confirmed all four decisions |
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
| 1 | ADSL | `programs/adam/adsl.R` | DM, DS, EX, SUPPDM, DV | ✅ Complete (real PPROTFL from SDTM.DV as of 2026-05-17) |
| 2 | ADAE | `programs/adam/adae.R` | ADSL + AE + SUPPAE | ✅ Complete |
| 3 | ADLB | `programs/adam/adlb.R` | ADSL + LB + SUPPLB | ✅ Complete |
| 4 | ADTR | `programs/adam/adtr.R` | ADSL + TR, TU | ✅ Complete |
| 5 | ADRS | `programs/adam/adrs.R` | ADSL + ADTR + RS (Investigator) | ✅ Complete |
| 6 | ADTTE | `programs/adam/adtte.R` | ADSL + ADRS + DS, DD, RS (BICR+INV), ADCM | ✅ Complete — 6 PARAMCDs: OS, OSWOT, PFS (BICR), PFSINV (Investigator), DOR, TTR |
| 7 | ADCM | `programs/adam/adcm.R` | ADSL + CM + SUPPCM | ✅ Complete (incl. real SUBSQTFL from subsequent therapy raw simulator) |
| 8 | ADDS | `programs/adam/adds.R` | ADSL + DS | ✅ Complete |
| 9 | ADDV | `programs/adam/addv.R` | ADSL + DV | ✅ Complete (real SDTM.DV; no longer placeholder) |
| 10 | ADEX | `programs/adam/adex.R` | ADSL + EX + DA | ✅ Complete |
| 11 | ADMH | `programs/adam/admh.R` | ADSL + MH | ✅ Complete |
| 12 | ADVS | `programs/adam/advs.R` | ADSL + VS | ✅ Complete |

**Gate 4 exit criteria (PASSED 2026-04-25 for items 1-6; extended 2026-05-17 for items 7-12):** All 12 datasets written, validated via `xportr`, and Parquet outputs committed.
OS/PFS HRs reconcile with raw-simulator seed assumptions (OS 0.567, PFS BICR 0.568, PFSINV 0.522; targets 0.65 / 0.55).

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
| ADaM-D-08 | Parquet as intermediate format | Parquet for all intermediate and final ADaM files | Efficient; no SAS dependency for intermediate work; XPT produced by xportr for submission | programs/adam/PHASE-5-APPROACH.md |

---

## 6. Open Items at v0.1

| Item | Dataset | Status |
|---|---|---|
| ~~BECOG (ECOG PS) on ADSL~~ | ADSL | ✅ Resolved — ECOG derived from SUPPDM.ECOGBSL |
| ~~PDL1GR (PD-L1 TPS group) on ADSL~~ | ADSL | ✅ Resolved — PDL1CAT/PDL1SCR derived from SUPPDM |
| ~~IRAEFL source confirmation~~ | ADAE | ✅ Resolved — sourced from SUPPAE.IRAEFL |
| Partial SLD handling rule | ADTR | Accepted: include partial visit SLD per RECIST 1.1 convention |
| ~~BICR response assessments~~ | ADRS / ADTTE | ✅ Resolved 2026-05-17 — BICR reader added in raw simulator; SDTM.RS now carries RSEVAL; ADTTE derives both PFS (BICR primary) and PFSINV (Investigator sensitivity) |
| ATOXGR reference codelist | ADLB | Accepted limitation — generic high/low flags used; full CTCAE v5 lab thresholds deferred |
| PARAMCD codelist for LB | ADLB | Implemented via LBTESTCD → PARAMCD lookup in `adlb.R` |
| Unit conversion table | ADLB | Accepted — uses original units; SI conversion deferred to v1.0 |

---

## 7. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `sap/SAP.md` (v0.1) | **Parent.** Every ADaM variable traces to an analysis in the SAP. No variable without a SAP reference. |
| `sap/shells/shells.yaml` | **Sibling.** TFL shell annotations cite ADaM variables; `validate_shells.R` cross-checks against specs. |
| `programming-specs/AD*-spec.md` | **Spec layer.** One spec per dataset; spec precedes and governs the R script. |
| `programs/adam/ad*.R` | **Implementation.** R scripts implement the spec; must reconcile with spec before Gate 4. |
| `datasets/adam/adsl.parquet` … `advs.parquet` | **Outputs.** 12 Parquet files; also exported to XPT via `xportr` for submission package. |
| `programs/raw/RAW-PROVENANCE.md` | **Parent of inputs.** Records how the raw + SDTM parquet files were generated. |
| `sap/SAP-PROVENANCE.md` | **Sibling.** SAP development record; the ADaM specs operationalise the SAP. |

---

## 8. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-25 | LG | Initial draft. Six R stubs and five specs scaffolded. Phase 5 work begins. Open items listed above. |
| 0.2 | 2026-04-25 | LG (w/ Claude Opus 4.7) | Gate 4 PASSED. All 6 efficacy/safety derivation scripts complete (ADSL, ADAE, ADLB, ADTR, ADRS, ADTTE). Open items resolved or accepted. |
| 0.3 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Re-derived from SDTM v0.3 (raw v0.3 covariate-driven + Weibull KM shape). Cox HRs reconcile: OS 0.567 (target 0.65), PFS 0.522 (target 0.55). admiral 1.4.1. |
| 0.4 | 2026-05-17 | LG (w/ Claude Opus 4.7) | **6 new pharma-standard descriptive ADaMs added:** ADCM, ADDS, ADDV, ADEX, ADMH, ADVS. Total 12 ADaM datasets. Spec coverage extended in `programs/adam/ADAM-MAPPING-SPEC.md` §7–§12. |
| 0.5 | 2026-05-17 | LG (w/ Claude Opus 4.7) | **AL closures:** ADSL.PPROTFL now real-derived from SDTM.DV (SAFFL=Y AND no MAJOR deviation; ~412/450 Y); ADDV sources real SDTM.DV (~337 records, 190 subjects); ADCM.SUBSQTFL real (~133 subsequent-therapy CM rows); ADTTE gains PFSINV PARAMCD derived from RSEVAL='INVESTIGATOR' (PFS continues from RSEVAL='INDEPENDENT ASSESSOR'). Final stats: PFS BICR HR 0.568 (median 10.94 / 5.55 mo), PFSINV HR 0.522 (median 13.67 / 7.06 mo). Closes AL-02/03/04/07/10 at the ADaM layer. |
| 0.6 | 2026-07-18 | LG (w/ Claude Opus 4.8) | **Variable labels attached to all 12 datasets (issue #14).** New `programs/adam/label_adam.R` (sourced last by `00_run_adam.R`) applies ADaMIG v1.3 labels sourced from the `AD*-spec.md` variable tables + a curated SUPPLEMENT for analysis vars absent from the specs (ADY, TRT01PN, ICDT, …). Coverage 107/333 (32%) → **333/333 (100%)**; fixes 5 fully-unlabelled datasets (adex, adlb, adrs, adtr, adtte). Mechanism matches SDTM `16_label_domains.R` — labels serialised into the arrow parquet R-metadata, recovered by `arrow::read_parquet()`. |
| 0.7 | 2026-07-18 | LG (w/ Claude Opus 4.8) | **AVISIT/AVISITN added to all 5 BDS finding datasets (issue #24).** ADLB/ADEX/ADRS/ADTR had no `AVISIT`/`AVISITN`; ADVS had them but `AVISITN` was null for all maintenance visits. Now defined in SAP §12.2 + the 5 specs, and derived via shared `programs/adam/_visit_utils.R::derive_avisitn()` (VISITNUM where populated, else `MAINT_CnD1`→7+n / `TUMOR_ASSESS_WKn`→n / BASELINE→0). Coverage: all by-visit BDS rows now have gap-free AVISIT/AVISITN. Per ADaMIG traceability rule, SDTM `VISIT`/`VISITNUM` retained where populated (ADLB/ADEX/ADVS); `VISITNUM` dropped from ADRS/ADTR (SDTM RS/TR 100% null). define.xml regenerated (623 vars). Bundle republished to clinTrialData **v0.1.1**. |
| 0.8 | 2026-07-19 | LG (w/ Claude Opus 4.8 1M) | **Analysis-visit windowing (SAP §12.2) + AVISITN correction + CTCAE HGB fix.** Replaced `AVISIT = VISIT` with date-based nearest-scheduled-visit windowing: `_build_visit_windows.R` → `crf/analysis_visit_windows.csv` (TREATMENT + TUMOUR streams, midpoint boundaries); `_visit_utils.R::derive_avisit_windowed()` maps `ADY` → `AVISIT`/`AVISITN`, and `flag_anl01()` sets `ANL01FL` on the record closest to the visit target — resolving multiple records per window (incl. unscheduled rechecks) without double-counting. Applied in ADLB/ADVS/ADRS/ADTR; the ADLB/ADVS/ADRS define keys gain `ADT` (clears P21 SD1152). **Corrected the maintenance `AVISITN` from the stale 7+n to 9+n** (matches SDTM `VISITNUM`; the 0.7 label-fallback was dead code). **Fixed CTCAE haemoglobin grading** — g/L thresholds (100/80/65) applied to g/dL values had graded every low HGB as Grade 4; corrected to g/dL (ANRLO / 10.0 / 8.0), so Grade 4 3,356 → 0 and Grade ≥3 records 3,644 → 443. Unscheduled records (SDTM `VISIT="UNSCHEDULED"`) window to their nearest scheduled visit. P21 ADaM 10,931 (validated via `qc/run_p21.sh`, spurious cross-standard SD1005 auto-suppressed). |

---

*Last updated: 2026-07-19*
