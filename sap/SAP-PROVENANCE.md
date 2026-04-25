# SAP-PROVENANCE.md — Statistical Analysis Plan Development Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

This SAP supports a **fully synthetic** clinical trial dataset generated for educational purposes.
No real trial is described. All sponsor names, drug names, and study identifiers are fictional.

This document was developed with **AI assistance** using the methodology described below.
The statistical methods are grounded in published regulatory guidance and industry standards, but
the SAP has not been reviewed by a regulatory authority and is not intended for regulatory submission.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-sonnet-4-6` |
| **Interface** | Cowork (Claude desktop app) |
| **Role** | Drafting SAP sections, proposing statistical methods, structuring estimands and censoring rules |
| **Human oversight** | Lovemore Gakava — domain expert review of all content; all methodological decisions confirmed by LG |
| **Drafting started** | 2026-04-20 |
| **SAP version recorded here** | v0.1 DRAFT |

### Division of labour

| Section | Drafted by | Reviewed / decided by |
|---|---|---|
| Study overview (§1) | AI (from Protocol v1.1) | LG — verified against synopsis.md |
| Objectives & hypotheses (§2) | AI (from Protocol v1.1 §2) | LG |
| Analysis populations (§3) | AI — proposed flag names, definitions, PP deviation categories | LG — confirmed flag names, PP deviation list |
| Endpoint derivations (§4) | AI — proposed admiral derivation logic and censoring rules per FDA 2018 guidance | LG — confirmed censoring hierarchy, ORR non-responder imputation rule |
| Statistical methods (§5) | AI — selected log-rank / Cox / KM / CMH per standard Phase 3 oncology SAP | LG — confirmed test choices, conf.type = "log-log", exposure-adjusted rates |
| Sample size reference (§6) | AI (from Protocol v1.1 §8.1) | LG |
| Missing data (§7) | AI — proposed derive_vars_dt() partial-date imputation and no-LOCF principle | LG — confirmed no-LOCF, PRO MMRM deferral |
| Multiplicity (§8) | AI — proposed graphical testing hierarchy (Maurer-Bretz 2013) | LG — confirmed OS → PFS → ORR → DoR chain |
| Interim analyses (§9) | AI — proposed IA triggers and O'Brien-Fleming Lan-DeMets boundaries | LG — confirmed futility non-binding, ~50%/75%/100% event triggers |
| Subgroup analyses (§10) | AI — proposed subgroup list from Protocol stratification factors | LG — flagged BECOG / PDL1GR gap; deferred TMB cutoff |
| Sensitivity analyses (§11) | AI — proposed RMST, landmark, weighted log-rank, Wilson CI | LG — confirmed τ = 36 months for RMST, ITT vs PP re-run |
| Reporting conventions (§12) | AI — proposed precision rules | LG — confirmed |
| Estimands (§13) | AI — structured ICH E9(R1) attributes; proposed intercurrent event strategies | LG — confirmed treatment policy for OS, composite for PFS / ORR |

---

## 3. Primary Sources & References

| Reference | Used for |
|---|---|
| Protocol v1.1 (`protocol/synopsis.md`) | Primary specification — objectives, endpoints, sample size, stratification |
| ICH E9(R1) Addendum on Estimands (2019) | Estimand framework (§13): population, endpoint, summary measure, intercurrent event strategies |
| FDA Guidance: Clinical Trial Endpoints for the Approval of Non-Small Cell Lung Cancer Drugs (2015) | OS as primary endpoint; ORR as supportive endpoint; acceptable censoring approaches |
| FDA Guidance: Considerations for the Design, Conduct, and Analysis of Observational Studies on PFS and OS (2018) | PFS censoring rules: new anti-cancer therapy → censor at last adequate assessment; ≥2 missed assessments → censor at last adequate before gap |
| EMA Guideline on the Evaluation of Anticancer Medicinal Products in Man (2018) | PFS confirmation requirements; BICR vs investigator |
| RECIST 1.1 (Eisenhauer et al., EJC 2009) | BOR definition; CR/PR confirmation (≥28 days); SD ≥8 weeks for DCR |
| CDISC Oncology Disease Response Supplement — RECIST 1.1 (2023) | PARAMCD naming (OS, PFS, DOR, CBOR, CBDCR); ADRS / ADTTE structure |
| Maurer & Bretz (2013) — Multiple Comparisons Using a Graphical Approach | Graphical testing procedure for multiplicity control (§8) |
| O'Brien & Fleming (1979); Lan & DeMets (1983) | Interim analysis alpha-spending function (§9) |
| KEYNOTE-024 (Reck et al., NEJM 2016; updated NEJM 2019) | Benchmark for OS HR (0.62 observed; 0.65 assumed here), PFS HR, median survival assumptions |
| admiral / admiralonco documentation (pharmaverse) | derive_param_tte(), derive_param_bor(), derive_param_confirmed_bor(), derive_var_trtemfl() function signatures and arguments |
| survival R package documentation | survfit(conf.type = "log-log"), survdiff(), coxph() usage |
| tern / rtables documentation | Safety table structures; TEAE incidence / exposure-adjusted rate conventions |

---

## 4. Key Methodological Decisions

These are decisions where alternatives were explicitly considered and a choice was made.
Decisions that required no deliberation (e.g. OS is primary — per protocol) are not listed here.

| ID | Decision | Alternatives considered | Choice made | Rationale |
|---|---|---|---|---|
| SAP-D-01 | OS censoring date | (a) last study contact only; (b) max(last contact, last assessment, DCO) | (b) max of three | FDA 2018 guidance recommends the most recent evidence of survival; avoids early artificial censoring |
| SAP-D-02 | PFS censoring — new anti-cancer therapy | (a) treat as event; (b) censor at therapy start; (c) censor at last adequate assessment before therapy | (c) last adequate assessment before therapy | Per FDA 2018; avoids informative censoring from therapy switch |
| SAP-D-03 | PFS censoring — missed assessments | (a) censor only if PD follows gap; (b) censor at last adequate if ≥1 missed; (c) ≥2 consecutive missed → censor | (c) ≥2 consecutive | Balance between penalising dropout and being overly conservative; pre-specified threshold |
| SAP-D-04 | ORR non-responder imputation | (a) exclude subjects with no post-baseline assessment; (b) count as non-responders | (b) non-responders | Pre-specified; avoids best-case bias from dropouts; consistent with FDA oncology precedent |
| SAP-D-05 | Multiplicity hierarchy | (a) Bonferroni; (b) fixed-sequence; (c) graphical (Maurer-Bretz) | (c) graphical | Allows full α propagation on reject; handles partial ordering; more flexible than fixed-sequence |
| SAP-D-06 | Interim futility | (a) binding; (b) non-binding | (b) non-binding | Preserves ability to continue even if conditional power is below threshold; recommended for SMC flexibility |
| SAP-D-07 | IA alpha-spending | (a) Pocock; (b) O'Brien-Fleming (Lan-DeMets) | (b) O'Brien-Fleming | Preserves more alpha for final analysis; standard for confirmatory Phase 3 with OS primary |
| SAP-D-08 | KM confidence interval type | (a) plain log; (b) log-log (Brookmeyer-Crowley); (c) arcsine | (b) log-log | Better coverage at extreme survival probabilities; widely used in oncology |
| SAP-D-09 | ORR CI method | (a) Wald; (b) Wilson; (c) Clopper-Pearson exact | (c) Clopper-Pearson as primary; Wilson as sensitivity | Clopper-Pearson is conservative and exact; Wilson as sensitivity per FDA preference |
| SAP-D-10 | RMST time horizon (τ) | 24 months; 36 months; 48 months | 36 months | Sufficient follow-up expected for most subjects; interpretable horizon for a ~21.5 month median OS |
| SAP-D-11 | SD definition for DCR | ≥6 weeks; ≥8 weeks | ≥8 weeks from randomisation | RECIST 1.1 specifies a minimum interval; 8 weeks is more stringent and standard in immunotherapy trials |

---

## 5. Open Items at v0.1

The following items are flagged in the SAP body but deferred to SAP lock (Gate 3.5 final approval):

| Item | Section | Status |
|---|---|---|
| Multiplicity transition matrix (`sap/multiplicity.csv`) | §8 | To be created and committed at SAP lock |
| AESI list (MedDRA PTs from Protocol §7.4) | §4.6 | Protocol §7.4 not yet drafted — to be added |
| irAE category definitions | §4.6 | To be added once AE coding convention is confirmed |
| Lab abbreviation and normal range reference table | §5.5 | Deferred — to be added with ADLB spec |
| ECOG PS (`BECOG`) on ADSL | §10 | Must be added to ADSL spec before Phase 5 code |
| PD-L1 TPS group (`PDL1GR`) on ADSL | §10 | Must be added to ADSL spec before Phase 5 code |
| TMB subgroup cutoff | §10 | Exploratory; deferred — no ADaM dataset specified |
| PRO analysis methods (MMRM, TTD) | §4.7 | Out of scope for Gate 3.5; future SAP amendment |

---

## 6. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `protocol/synopsis.md` (v1.1) | **Parent.** SAP operationalises the statistical sections (§8, §11) of the protocol. All sample size and endpoint definitions trace back here. |
| `sap/shells/TFL-SHELLS.md` (v0.1) | **Child.** Every analysis in this SAP corresponds to ≥1 shell in the TFL catalogue. Crosswalk in SAP §14. |
| `programming-specs/AD*-spec.md` | **Grandchild.** Every ADaM variable must trace to an analysis defined in this SAP or a TFL shell variable. |
| `data-raw/PROVENANCE.md` | **Sibling.** Records how the underlying synthetic SDTM data was generated; this document records how the analyses of that data are specified. |
| `sap/shells/SHELLS-PROVENANCE.md` | **Sibling.** Records how the TFL shell catalogue was developed. |

---

## 7. Limitations

- The SAP is based on a synthetic dataset; it has not been validated against real clinical trial data or reviewed by a regulatory statistician.
- AI model knowledge has a training cutoff — regulatory guidance was verified against primary sources where possible but may not reflect the very latest FDA/EMA publications.
- Exploratory endpoints (PROs, biomarkers, PK/ADA) are referenced but not fully specified — a future SAP amendment is required before those analyses can proceed.
- The multiplicity matrix and exact interim boundaries are placeholders; they must be computed by an independent statistician using actual observed information fractions.

---

## 8. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Initial draft. Aligned with Protocol v1.1 §8 and §11. Gate 3.5 deliverable. |
| 0.2 | — | — | SAP lock: add multiplicity.csv, AESI list, irAE categories, BECOG/PDL1GR ADSL flags. |

---

*Last updated: 2026-04-25*
