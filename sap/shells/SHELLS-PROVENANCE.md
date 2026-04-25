# TFL-PROVENANCE.md — TFL Shells Development Record
# CTX-NSCLC-301 — Torivumab Phase 3 NSCLC Study

---

## 1. Disclosure

These TFL shells support a **fully synthetic** clinical trial dataset generated for educational purposes.
No real trial is described. All sponsor names, drug names, and study identifiers are fictional.

The shell catalogue was developed with **AI assistance** using the methodology described below.
The output specifications are grounded in standard oncology Phase 3 trial reporting conventions
and CDISC Analysis Results Standard (ARS) v1.0 concepts, but have not been reviewed by a
regulatory authority and are not intended for regulatory submission.

---

## 2. AI Model

| Property | Value |
|---|---|
| **Model** | `anthropic/claude-sonnet-4-6` |
| **Interface** | Cowork (Claude desktop app) |
| **Role** | Drafting shell specifications, proposing output structure and layout, generating shells.yaml and render/validate scripts |
| **Human oversight** | Lovemore Gakava — domain expert review of all shells; all output scope and layout decisions confirmed by LG |
| **Drafting started** | 2026-04-20 |
| **Shells version recorded here** | v0.1 |

### Division of labour

| Deliverable | Drafted by | Reviewed / decided by |
|---|---|---|
| Output catalogue scope (35 outputs) | AI — proposed based on SAP sections and standard Phase 3 oncology practice | LG — confirmed scope; chose not to include PK/ADA outputs at Gate 3.5 |
| Analysis set definitions | AI (from SAP §3) | LG |
| Statistical method registry | AI — proposed 18 methods drawn from SAP §5 | LG — confirmed method IDs and R function citations |
| Individual shell specifications | AI — proposed title, analysis set, source datasets, key variables, layout, SAP crosswalk | LG — reviewed each shell for correctness and completeness |
| YAML schema design | AI — proposed top-level structure aligned with CDISC ARS v1.0 | LG — confirmed schema; see SHELLS-FORMAT-RATIONALE.md for decision record |
| `render_shells.R` | AI | LG — reviewed output |
| `validate_shells.R` | AI | LG — reviewed checks |
| `SHELLS-FORMAT-RATIONALE.md` | AI — drafted options A/B/C and rationale | LG — made final decision (Option C); updated change log |

---

## 3. Primary Sources & References

| Reference | Used for |
|---|---|
| `sap/SAP.md` (v0.1) | **Primary driver.** Every shell maps to a SAP section via `sap_ref`. Scope of outputs is bounded by analyses defined in the SAP. |
| `protocol/synopsis.md` (v1.1) | Study design context for output titles, population labels, and endpoint descriptions |
| CDISC Analysis Results Standard (ARS) v1.0 | YAML schema concepts: AnalysisSet, DataSubset, AnalysisMethod, Analysis, Output; `sap_ref` and `reference_documents` foreign keys |
| ICH E3 Structure and Content of Clinical Study Reports (1995) | Section mapping for CSR tables (Disposition, Efficacy, Safety); output ID prefix conventions (T-DM, T-DS, T-EFF, T-AE, T-LB) |
| FDA Guidance: Clinical Trial Endpoints for the Approval of NSCLC Drugs (2015) | Required efficacy outputs: KM curves, ORR table, forest plot; BICR vs investigator labelling |
| KEYNOTE-024 CSR (published data, NEJM 2016 supplementary) | Benchmark for standard output structure in a first-line PD-L1 NSCLC Phase 3 study |
| tern / rtables documentation (pharmaverse) | Table layout conventions: row/column structure, exposure-adjusted rates, shift table format |
| RECIST 1.1 (Eisenhauer et al., EJC 2009) | Response category labels (CR, PR, SD, PD, NE); waterfall/spider plot conventions |
| Common oncology TFL conventions (pharmaverse admiralonco vignettes) | Swimmer lane plot, waterfall plot, spider plot standard implementations |
| LG prior experience — JSON-based TFL shells on a previous study | Informed Option C (YAML source-of-truth) decision; see SHELLS-FORMAT-RATIONALE.md |

---

## 4. Shell Catalogue — Scope Decisions

### 4.1 What is included

| Category | Count | Rationale |
|---|---|---|
| Demography & baseline (T-DM) | 1 table | Standard first table in any Phase 3 CSR |
| Disposition (T-DS) | 2 tables | Subject flow + major protocol deviations |
| Efficacy — primary + secondary (T-EFF) | 7 tables | OS, PFS (each with KM probs), ORR, DCR, DoR |
| Safety (T-AE) | 7 tables | Overall TEAE; SOC/PT; Grade ≥3; SAE; irAE; AESI; Deaths |
| Lab abnormalities (T-LB) | 2 tables | Shift table; Grade ≥3 by CTCAE |
| Exposure (T-EX) | 1 table | Dose intensity and duration |
| Efficacy figures (F-EFF) | 6 figures | KM OS, KM PFS, Waterfall, Spider, Forest, Swimmer |
| Listings (L-AE, L-DS, L-LB) | 5 listings | SAE, Deaths, AE→D/C, Grade ≥3 labs, Major deviations |
| **Total** | **35 outputs** | |

### 4.2 What is explicitly excluded at Gate 3.5

| Output type | Reason for exclusion |
|---|---|
| PRO outputs (EORTC QLQ-C30/LC13, EQ-5D-5L) | Exploratory; no ADaM dataset specified for Gate 3.5 |
| PK / ADA tables | PK substudy deferred; no ADPC/ADADA datasets planned |
| Biomarker subgroup figures (continuous PD-L1, TMB) | Exploratory; TMB cutoff not defined; no ADSL variable yet |
| Investigator-assessed PFS table | Included as a sensitivity annotation in T-EFF-03 notes; standalone table deferred |
| Individual subject data listings for efficacy | Not standard for CSR body; available on request |

---

## 5. Key Format and Architecture Decisions

These are documented in full in `sap/shells/SHELLS-FORMAT-RATIONALE.md`. Summarised here for provenance:

| ID | Decision | Choice | Date |
|---|---|---|---|
| TFL-D-01 | Source-of-truth format for shells | YAML (`shells.yaml`) rendered to Markdown (`TFL-SHELLS.md`) — Option C | 2026-04-20 |
| TFL-D-02 | ARS alignment | YAML schema maps directly to CDISC ARS v1.0 concepts; not yet serialised to ARS JSON | 2026-04-20 |
| TFL-D-03 | Output ID convention | `{T\|F\|L}-{AREA}-{NN}` (e.g. T-EFF-01, F-EFF-01, L-AE-01) | 2026-04-20 |
| TFL-D-04 | Validation approach | `validate_shells.R` at CI: checks referential integrity, ID convention, orphan ADaM variables | 2026-04-20 |
| TFL-D-05 | TFL code generation approach | Phase 6 R scripts (`t_*.R`, `f_*.R`, `l_*.R`) will read directly from `shells.yaml`; one place to change layout or population | 2026-04-20 |
| TFL-D-06 | Forest plot ordering | Subgroups ordered as: stratification factors first (histology, region), then clinical (sex, age, ECOG), then biomarkers (PD-L1, TMB) | 2026-04-20 |
| TFL-D-07 | Waterfall baseline definition | Best % change from baseline sum of longest diameters (SLD); baseline = last pre-treatment assessment | 2026-04-20 |

---

## 6. Relationship to Other Documents

| Document | Relationship |
|---|---|
| `sap/SAP.md` (v0.1) | **Parent.** Every shell has a `sap_ref` pointing to the SAP section that governs it. No output exists without a SAP analysis. |
| `sap/shells/shells.yaml` | **Source of truth.** `TFL-SHELLS.md` is generated from this file; do not edit the Markdown directly. |
| `programming-specs/AD*-spec.md` | **Child.** `validate_shells.R` checks that every ADaM variable in the specs is cited by ≥1 shell. Orphan variables are flagged as potentially unnecessary. |
| `adam/*.R` | **Grandchild.** TFL code in Phase 6 reads shell metadata directly from `shells.yaml` to obtain population filters, strata, and method parameters. |
| `sap/SAP-PROVENANCE.md` | **Sibling.** Records how the SAP was developed; this document records how the outputs of that SAP were catalogued. |
| `data-raw/PROVENANCE.md` | **Sibling.** Records how the underlying synthetic SDTM data was generated. |

---

## 7. Limitations

- Shells were developed against a synthetic dataset; they have not been validated against real study data or reviewed by a regulatory authority.
- ARS JSON serialisation is not yet implemented (`render_ars.R` is planned for a future phase); the YAML schema is ARS-aligned but not ARS-compliant until the serialiser is written.
- AI-proposed output layouts (row/column structure) are based on common oncology conventions but may require adjustment to match a specific sponsor's house style or a regulatory reviewer's expectations.
- Five listings and all PRO/PK/biomarker outputs are deferred; the catalogue is not complete until those are added in a future SAP amendment.

---

## 8. Annotation Approach

### 8.1 Observation

Standard industry practice is for TFL shells to be **annotated** — each row, column, and
statistic in the visual mock-up is labelled with the ADaM source that will produce it: the
dataset name, the WHERE clause (PARAMCD, population flag), the variable name, and the
derivation function. This is the primary reference document for TFL programmers when writing
`t_*.R`, `f_*.R`, and `l_*.R` scripts in Phase 6.

The complication — noted from experience on prior studies — is that shells are created
**before** the ADaM datasets exist. This creates a gap:

| Stage | What exists | What shells can reference |
|---|---|---|
| Gate 3.5 (now) | Programming specs (`AD*-spec.md`) | Intended variable names — CDISC-standard names + any study-specific names defined in the spec |
| After Phase 5 delivery | ADaM Parquet files | Actual variable names in the delivered data — may differ from spec if study-specific derivations diverged |
| Phase 6 (TFL programming) | Locked ADaM | Confirmed annotations — programmers validate the shells against the data before coding |

An additional complication is **CDISC standard updates and study-specific variables**: the
CDISC ADaM oncology supplements (ADRS, ADTR, ADTTE) define standard variable names, but
almost every study adds study-specific supplementary variables (e.g. `IRAEFL`, `IRAECAT`,
`PDL1GR`, `BECOG`) that are not in the standard and must be documented in the
`programming-specs/AD*-spec.md` files. Annotations based purely on the CDISC standard will
be incomplete at Gate 3.5; they require a study-specific layer on top.

### 8.2 Decision

**Two-phase annotation approach:**

**Phase 1 — Spec-based (now, Gate 3.5):**
Add a structured `annotations:` block to each output in `tfl/shells.yaml`. Populate using:
- CDISC ADaM standard variable names (ADaMIG v1.3, oncology supplements)
- Study-specific variable names from `programming-specs/AD*-spec.md` (as they are written)
- Clearly mark as `"Preliminary — confirm after Phase 5 ADaM delivery"`

This gives ~80% of the annotation at the right time. Programmers and reviewers can see
the intended source for every displayed statistic before ADaM programming begins.

**Phase 2 — Data-confirmed (after Phase 5):**
After ADaM Parquet files are delivered, re-run `validate_shells.R`. Any variable cited in
`annotations.rows` that is absent from the delivered ADaM is flagged as a discrepancy.
Update the relevant `annotations:` blocks in `shells.yaml`, regenerate `TFL-SHELLS-DOC.docx`,
and record the changes in the shell change log. This step is mandatory before Phase 6 TFL
programming begins.

**Alternatives considered and rejected:**

| Option | Reason rejected |
|---|---|
| Annotate only after ADaM delivery | Leaves programmers without source references during spec and review phases; feedback loops are lost |
| Maintain a separate annotation spreadsheet | Breaks single-source-of-truth principle; annotations drift from shells |
| Skip annotation entirely | Not acceptable — study teams require annotated shells for sign-off and regulatory inspection readiness |
| Full ARS JSON annotation now | ARS JSON serialisation is deferred (`render_ars.R` is planned); the `annotations:` YAML block is ARS-aligned and will feed the serialiser when it is written |

### 8.3 Annotation Schema

Each output in `tfl/shells.yaml` carries an `annotations:` block with the following fields:

```yaml
annotations:
  note: "Preliminary v0.1 — based on AD*-spec.md; confirm after Phase 5 ADaM delivery."
  population: "ADSL: <flag>='Y'  |  analysis by <TRT01P|TRT01A>"
  primary_dataset: "<DATASET> WHERE <PARAMCD/filter>"   # tables/figures; omit for listings
  rows:
    - row: "<displayed row label>"
      dataset: <ADSL|ADAE|ADTTE|ADRS|ADTR|ADLB>
      where: "<filter expression>"       # PARAMCD, CNSR, flag, etc.
      variable: <VARIABLE_NAME>
      derivation: "<function / formula>"
```

**Schema rationale:**
- `note` — explicit caveat so no reviewer treats Phase 1 annotations as final
- `population` — maps the analysis set filter to the ADSL flag; constant across all rows in that output
- `primary_dataset` — the main ADaM dataset driving the output (shorthand for programmers)
- `rows` — row-level mapping: one entry per *distinct statistic type* (not every displayed cell)
  - `row` — matches the displayed row label in the shell (allows `validate_shells.R` to cross-check)
  - `dataset` — the ADaM dataset supplying this row's data
  - `where` — the additional filter beyond the population flag
  - `variable` — the ADaM variable being summarised or derived from
  - `derivation` — the statistical function, admiral call, or formula

**Study-specific variables** that are not in the CDISC standard are marked with a
`# study-specific` comment in the YAML.

### 8.4 Iterative Update Process

```
Gate 3.5    →  annotations: block added to shells.yaml (Phase 1, spec-based)
                render_shells_doc.R regenerated → TFL-SHELLS-DOC.docx updated
                Shells sent for stakeholder review with "PRELIMINARY" annotation banner

Phase 5     →  ADaM Parquet delivered
                validate_shells.R run → discrepancy report produced
                LG reviews discrepancies → shells.yaml annotations updated
                shells.yaml version bumped (0.1 → 0.2)
                TFL-SHELLS-DOC.docx regenerated

Phase 6     →  TFL programmers use annotated shells as source reference
                Any further annotation corrections recorded in shells change log
```

### 8.5 Relationship to CDISC ARS

The `annotations.rows` entries map directly to ARS v1.0 `AnalysisResult` concept:
- `dataset` + `where` → ARS `DataSubset`
- `variable` → ARS result variable
- `derivation` → ARS `AnalysisMethod` parameter

When `render_ars.R` is implemented in a future phase, the `annotations:` blocks will feed
the ARS JSON serialisation alongside the `methods:` and `analysis_sets:` blocks.

---

## 9. Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Initial draft. 35 outputs specified. Aligned with SAP v0.1. Gate 3.5 deliverable. |
| 0.2 | 2026-04-25 | LG | Added §8 Annotation Approach. Documented two-phase annotation decision. Added `annotations:` schema to `shells.yaml` for all 35 outputs. Updated `render_shells_doc.R` and regenerated `TFL-SHELLS-DOC.docx`. |
| 0.3 | — | — | Post-Phase 5: confirm annotations against delivered ADaM Parquet. Bump to v0.2 shells. |
| 0.4 | — | — | Add PRO shells (EORTC, EQ-5D) once SAP amendment covers exploratory endpoints. |
| 0.5 | — | — | Add ARS JSON serialisation (`render_ars.R`) once downstream system is confirmed. |

---

*Last updated: 2026-04-25*
