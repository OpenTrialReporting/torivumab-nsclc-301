# TFL Shells — Format Rationale

**Document:** `tfl/SHELLS-FORMAT-RATIONALE.md`
**Status:** DECISION MADE 2026-04-20 — Option C (YAML source-of-truth → rendered Markdown).
**Audience:** Anyone (human or AI assistant) picking up this repo or replicating the pipeline on a future study.

---

## The decision

**YAML as source of truth** (`tfl/shells.yaml`), **rendered to Markdown** (`tfl/TFL-SHELLS.md`) by `tfl/render_shells.R`, **validated** by `tfl/validate_shells.R`.

The three options that were on the table:

| Option | Source of truth | Human view |
|---|---|---|
| A. Markdown only | `tfl/TFL-SHELLS.md` | Same file |
| B. Markdown + parallel JSON/YAML | Two files kept in sync manually | Markdown |
| **C. YAML as source of truth + rendered Markdown** ← chosen | `tfl/shells.yaml` | Generated `tfl/TFL-SHELLS.md` |

---

## Why Option C (the primary driver: CDISC ARS)

The decisive argument is **CDISC Analysis Results Standard (ARS) alignment**.

ARS v1.0 is the emerging CDISC standard for machine-readable analysis metadata. It defines a hierarchy of objects:

```
ReferenceDocument  (SAP, Protocol)
AnalysisSet        (population filter — e.g. ITT, Safety)
DataSubset         (additional filter — e.g. subgroup)
AnalysisMethod     (stratified log-rank, Cox PH, CMH, Clopper-Pearson, …)
Analysis           (links a Method + AnalysisSet + DataSubset + Parameter to a Result)
Output             (the physical Table/Figure/Listing display)
```

Shells in Markdown can *describe* these relationships; shells in YAML can *be* these objects. Once shell metadata is structured, the same file can drive:

1. **ARS JSON serialisation** — a thin serialiser in R/Python emits compliant ARS v1.0 from the YAML. A future `tfl/render_ars.R` will do this.
2. **tern / rtables code generation** — the analysis set's filter, method's R function, and output's parameter code feed directly into `tern::build_table(...)` calls. The shell is the single source for the generated R script.
3. **Traceability matrix** — protocol section → SAP section → shell → ADaM dataset → ADaM variable → SDTM source. Every arrow is a structured reference, queryable by a single script.
4. **CSR cross-references** — each CSR table reference (`T-EFF-01`) resolves to the shell ID and its full context without a separate index.

With Markdown-only shells, every one of these downstream benefits costs a fragile regex parser or manual re-keying. Option A is a dead-end for a shell-driven pipeline.

---

## Secondary wins (also real, also structural)

1. **Programmatic iteration.** `yaml::read_yaml("tfl/shells.yaml")` returns a list in R; loop over it.
2. **Cross-validation at CI.** `validate_shells.R` asserts:
   - every output references a known `analysis_set`, `method`, and `reference_document` ID,
   - every ADaM-spec variable is cited by ≥1 shell (or flagged as orphan),
   - ID convention is followed,
   - no duplicate IDs.
3. **Reuse by downstream code.** `tfl/t_eff_os.R` reads the OS shell's title, population filter, and strata directly — one place to change them.
4. **Bulk edits at scale.** "Apply `conf.type = log-log` to every efficacy shell" is a structured update; on Markdown it's touching 10 prose sections.
5. **Diff-friendly reviews.** Two-line YAML diffs are read in seconds.
6. **Tooling ecosystem.** YAML validation, schema-aware autocomplete, JSON Schema.

---

## What we give up

1. **Narrative prose is split across fields.** Solution: every shell has a `notes:` free-form field; that is where the paragraph goes. Structured fields handle everything ARS cares about.
2. **Contributor onboarding cost.** Solution: top-of-file comment block in `shells.yaml` plus this rationale doc.
3. **Generator discipline.** Solution: banner in the generated `TFL-SHELLS.md` that says "do not edit directly"; `render_shells.R` is idempotent.
4. **Harder to read in an un-rendered PR diff.** Solution: most reviewers will view the rendered `TFL-SHELLS.md` on GitHub where it renders.

---

## Implementation files

```
tfl/
├── shells.yaml                  ← source of truth (35 outputs, 5 analysis sets, 18 methods, 3 ref docs)
├── render_shells.R              ← YAML → Markdown generator (≈130 lines)
├── validate_shells.R            ← schema + coverage checks (≈140 lines)
├── TFL-SHELLS.md                ← generated; "DO NOT EDIT" banner
└── SHELLS-FORMAT-RATIONALE.md   ← this file
```

### The YAML schema (summary)

Top-level keys:

- `meta` — study metadata (versions, author, date, gate).
- `analysis_sets` — array of `{id, label, definition, adsl_filter, treatment_var, expected_n}`.
- `methods` — array of `{id, name, description, strata?, r_package?, r_function?}`.
- `reference_documents` — array of `{id, title, path}`.
- `outputs` — array of:
  - `id` (pattern `{T|F|L}-{AREA}-NN`)
  - `kind` (`table` / `figure` / `listing`)
  - `title`
  - `analysis_set` (foreign key into `analysis_sets`)
  - `source_datasets` (array of ADaM / SDTM names)
  - `parameter_codes` (array of PARAMCDs when applicable)
  - `key_variables` (array of ADaM variable names)
  - `methods` (array of foreign keys into `methods`)
  - `sap_ref` (SAP section anchor)
  - `reference_documents` (array of foreign keys)
  - `layout` (free-form map — rows/columns/axes/features/sort)
  - `notes` (free-form paragraph)

### Illustrative entry

```yaml
- id: T-EFF-01
  kind: table
  title: "Overall Survival Analysis (Primary)"
  analysis_set: ITT
  source_datasets: [ADTTE]
  parameter_codes: [OS]
  key_variables: [TRT01P, AVAL, CNSR, STRAT2, STRAT3]
  methods: [M-STRAT-LOGRANK, M-COX-STRAT, M-KM-MEDIAN]
  sap_ref: "§5.1"
  reference_documents: [SAP-0.1, PROTO-1.1]
  layout:
    rows: "n, events, censored, median OS (95% CI), HR (95% CI), stratified log-rank p"
    columns: "TRT01P"
  notes: |
    Primary analysis. Triggered at ~320 OS events (event-driven, Protocol §8.1).
    Strata: histology (STRAT2), region (STRAT3).
```

Every field maps to an ARS concept. `analysis_set` is an ARS `AnalysisSet.id`; `methods` are ARS `AnalysisMethod.id`; `reference_documents` are ARS `ReferenceDocument.id`. When we add `render_ars.R`, the mapping is a direct structural transform — no semantic inference.

---

## When each option is the right call

| Situation | Best option |
|---|---|
| Small study, shells list under ~10 outputs, no CI, no ARS | A (Markdown only) |
| Platform / template repo that multiple studies will reuse | C |
| Any project where shells must drive downstream code or ARS output | **C** |
| Regulated submission with traceability matrix | **C** |
| Tight one-off timeline, shells won't be revisited | A or B |

This repo: 35 shells, pipeline will be reused, ARS is a stated goal → **C** is the only sensible choice.

---

## Replicating on another study

1. Copy `tfl/shells.yaml`, `render_shells.R`, `validate_shells.R` to the new repo.
2. Replace `meta` block, `analysis_sets`, `outputs` for the new study.
3. Keep `methods` (stratified log-rank, Cox, CMH, etc.) — they are cross-study reusable.
4. Add `tfl/render_ars.R` once you have a downstream system that ingests ARS JSON.

---

## Related prior art

The user has previously shipped TFL shells as JSON on another study. That experience informed the choice — Option C is not speculative; it is a known-working pattern being formalised into this repo's workflow.

---

## Change log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-04-20 | LG | Captured the Markdown-vs-YAML tradeoff (options A/B/C). |
| 0.2 | 2026-04-20 | LG | Decision made: Option C. ARS alignment promoted to primary driver. Implementation shipped (`shells.yaml` + `render_shells.R` + `validate_shells.R`). |
