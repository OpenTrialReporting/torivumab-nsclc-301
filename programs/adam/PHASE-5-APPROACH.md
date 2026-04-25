# Phase 5 (ADaM) — Approach & Decisions

**Document:** `adam/PHASE-5-APPROACH.md`
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)
**Status:** APPROVED 2026-04-20 (revised same day to add SAP-first ordering, D-09)
**Audience:** Anyone (human or AI assistant) extending this repo or replicating the pipeline on a new study.

---

## TL;DR

We build all six ADaM datasets **spec-first** using the pharmaverse stack (`admiral` + `admiralonco` + `metacore` + `metatools` + `xportr`). A reusable project-local skill at `.claude/skills/adam-spec/` encodes the spec template so every dataset uses the same structure. Each spec maps every derivation to a named `admiral::derive_*()` call before any R code is written.

**Precondition (D-09):** No ADaM spec is finalised until the Statistical Analysis Plan (`sap/SAP.md`) and the TFL shells list (`sap/shells/TFL-SHELLS.md`) are locked at Gate 3.5. Every ADaM variable must trace to either an analysis in the SAP or a variable used by a TFL shell — this is what prevents ADaM specs from drifting away from the analyses they are supposed to support.

---

## Decisions

### D-09: SAP + TFL shells lock before ADaM specs

**Decision:** The Statistical Analysis Plan (`sap/SAP.md`) and the TFL shells list (`sap/shells/TFL-SHELLS.md`) must be written and LG-approved at Gate 3.5 before any ADaM spec is finalised.

**Why:**
- ADaM variables exist to serve analyses. Deciding derivations without the analyses locked produces drift — PFS censoring rules, baseline windows, subgroup definitions all get invented in ADaM and then conflict with the SAP at TFL time.
- The TFL shells list tells us *exactly* which variables each dataset must carry. Specs narrow accordingly; we avoid carrying "maybe useful" variables.
- SAP and TFL shells are also stand-alone regulatory artefacts used in CSR and ADRG — the work is not overhead.
- Rejected alternative: *ADaM spec first, SAP written to match the data*. Cheaper short-term, but reverses the cause-and-effect and is not how regulated industry operates.

**How to apply:**
- No merge to main for a new ADaM spec unless the analyses it supports are traceable to a SAP section or TFL shell.
- If the SAP changes after an ADaM spec is locked, the spec gets a new version in its change log and the R script is re-validated against it.
- `programming-specs/ADSL-spec.md` (drafted 2026-04-20 before this decision) remains as a draft and is back-validated against the SAP once the SAP is written.

---

### D-06: Spec-first for all 6 ADaM datasets

**Decision:** Write a complete specification at `programming-specs/AD{XX}-spec.md` before writing the R derivation script at `adam/ad{xx}.R`. Gate 4 (ADaM) requires both to exist and reconcile.

**Why:**
- Spec-first matches regulated-industry practice (FDA/PMDA expect programming specs as submission artefacts).
- It forces the modeller to decide derivation rules *before* discovering them in code, which is where subtle bugs hide (e.g. treatment-emergent window boundaries, censoring rules for PFS).
- Specs are the stable reference point for the Define-XML and the ADRG in Phases 5–8; the R code will change, the contract should not.
- Rejected alternative: *code-first with auto-extracted specs*. Faster to iterate but specs drift from code and the derivation reasoning is lost.

**How to apply:**
- Every file in `adam/` must have a matching `programming-specs/AD{XX}-spec.md`.
- Every row in the spec's Variables table must cite an admiral function or a deterministic source rule.
- Change the spec before the code; treat the spec diff as the source of truth in review.

---

### D-07: Pharmaverse stack (admiral + metacore + xportr)

**Decision:** ADaM derivations use `admiral` (core) + `admiralonco` (oncology endpoints) + `admiraldev` (dev helpers). Metadata governance uses `metacore` + `metatools`. Export to SAS transport (XPT) and labelling uses `xportr`.

**Why:**
- `admiral` is the pharmaverse reference implementation; its derivations are pre-validated and maintained by Roche/GSK/J&J contributors, which saves us re-deriving standards like `derive_vars_merged_lookup()`, `derive_param_bor()`, and `derive_var_ontrtfl()`.
- `admiralonco` ships RECIST 1.1 BOR/confirmed-response logic — exactly our primary endpoint territory.
- `metacore` lets us drive the spec → code → Define-XML pipeline from one metadata object, avoiding three parallel sources of truth.
- `xportr` adds SDTMIG/ADaMIG length and label conformance that regulators check.

**How to apply:**
- First derivation choice is always an existing `admiral` function. Hand-coded `mutate()` / `case_when()` is a fallback, documented in the spec as "custom derivation — no admiral equivalent".
- Pin versions in `adam/session_info_install.txt` when the stack is first installed; all future runs use those versions until a deliberate upgrade.

---

### D-08: Reusable `adam-spec` skill

**Decision:** The spec template and admiral-function catalogue live in `.claude/skills/adam-spec/` as a project-local Claude Code skill. It is invoked whenever a new ADaM spec is drafted or reviewed.

**Why:**
- Every spec follows the same 8-column variable table (Name, Label, Type, Length, Origin, Codelist, Source, Derivation). Baking that into a skill prevents drift between ADSL, ADAE, ADLB, etc.
- New contributors (human or AI) get the conventions for free by invoking the skill — no need to reverse-engineer them from an existing spec.
- The skill is portable: copying `.claude/skills/adam-spec/` into another study repo gives that repo the same conventions.

**How to apply:**
- Always invoke the skill when creating or reviewing a spec in `programming-specs/`.
- If a new convention emerges during Phase 5 that applies to all datasets, update the skill, not an individual spec.

---

## Build Order

**Precondition:** `sap/SAP.md` + `sap/shells/TFL-SHELLS.md` locked at Gate 3.5. Do not start any row below until Gate 3.5 passes.

Upstream datasets first. ADSL is the foundational dataset — every other ADaM dataset merges `ADSL` variables (`TRT01P`, `SAFFL`, `ITTFL`, `RANDDT`, etc.) onto its own rows.

| # | Dataset | Depends on | Why this order |
|---|---------|-----------|----------------|
| 1 | ADSL    | SDTM DM, DS, EX, SV | Subject-level truth; population flags defined here once. |
| 2 | ADAE    | ADSL + SDTM AE      | Needs TRTSDT/TRTEDT for TEAE flagging. |
| 3 | ADLB    | ADSL + SDTM LB      | Needs baseline visit and TRTSDT for baseline/change. |
| 4 | ADTR    | ADSL + SDTM TR, TU  | Nadir tracking needs subject-level treatment arm. |
| 5 | ADRS    | ADSL + ADTR + SDTM RS | Confirmed BOR derivation uses ADTR-derived SLD. |
| 6 | ADTTE   | ADSL + ADRS + SDTM DS, DD | OS/PFS censoring rules pull death date + last response date. |

---

## Folder Layout (Phase 5)

```
adam/
├── PHASE-5-APPROACH.md           ← this file
├── session_info_install.txt      ← pinned pharmaverse versions
├── adsl.R                        ← derivation script per dataset
├── adae.R
├── adlb.R
├── adtr.R
├── adrs.R
├── adtte.R
└── *.parquet                     ← output (6 datasets)

programming-specs/
├── ADSL-spec.md                  ← one spec per dataset
├── ADAE-spec.md
├── ADLB-spec.md
├── ADTR-spec.md
├── ADRS-spec.md
└── ADTTE-spec.md

.claude/skills/adam-spec/
├── SKILL.md                      ← when to invoke + how to use
├── spec-template.md              ← the 8-column template
└── admiral-function-catalogue.md ← which admiral fn for which derivation
```

---

## Definition of Done (per dataset)

A dataset is considered complete when **all** of the following are true:

1. `programming-specs/AD{XX}-spec.md` exists, every variable row cites a source.
2. `adam/ad{xx}.R` runs cleanly in a fresh R session via `Rscript` (no loose `.RData`).
3. `adam/ad{xx}.parquet` is committed; row count matches the spec's expected N.
4. Variable labels, lengths, types match the spec (verified via `xportr::xportr_length()` + `xportr::xportr_label()`).
5. Session info appended to `adam/session_info.txt` on run.

---

## Gate 4 (ADaM) Exit Criteria

- All 6 specs written and LG-approved.
- All 6 R scripts run end-to-end from the committed SDTM parquet inputs.
- All 6 Parquet outputs committed.
- ADSL population counts reconcile with Protocol Section 8 (SAFFL=450, ITTFL=450, PPROTFL≥405 assumed 10% dropout).
- OS/PFS HR in ADTTE reconcile with the seeds used in `data-raw/01_dm.R` (HR=0.65 / 0.55 ±0.1).

---

## Replicating This Approach on Another Study

1. Copy `.claude/skills/adam-spec/` into the new repo's `.claude/skills/`.
2. Copy this file as the template for the new study's Phase 5 approach doc; update study name.
3. Install the pharmaverse stack (see the skill's `admiral-function-catalogue.md` for the command).
4. Work through the Build Order tabl