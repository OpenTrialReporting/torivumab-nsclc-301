---
name: adam-spec
description: Use when authoring, reviewing, or updating an ADaM programming specification in programming-specs/AD*-spec.md. Enforces the 8-column variable table, maps each derivation to a named admiral function, and keeps conventions consistent across ADSL/ADAE/ADLB/ADTR/ADRS/ADTTE.
---

# adam-spec

A project-local skill for authoring ADaMIG v1.3 programming specifications that compile cleanly to `admiral`-based R code and to Define-XML v2.1.

## When to invoke

Invoke this skill whenever you are:
- Drafting a new `programming-specs/AD{XX}-spec.md` for any of: ADSL, ADAE, ADLB, ADTR, ADRS, ADTTE.
- Reviewing an existing spec for completeness before Gate 4.
- Updating a spec because a derivation rule changed (e.g. new censoring rule for PFS).

Do **not** invoke for SDTM domain specs — SDTM uses SDTMIG v3.4 conventions and this repo generates SDTM from `data-raw/` scripts, not from specs.

## What the skill enforces

Every ADaM spec in this repo must:

1. **Use the 8-column variable table** from `spec-template.md`. No ad-hoc columns.
2. **Cite a derivation source for every variable row**: either a named `admiral::derive_*()` call from `admiral-function-catalogue.md`, a direct SDTM source variable, or an explicit "custom derivation" block with rationale.
3. **Follow the spec section order** in `spec-template.md` (Header → Purpose → Dependencies → Variables → Derivations → Population Flags → QC Checks → Traceability).
4. **Resolve every codelist reference** to CDISC CT 2024-03 or a study-specific codelist declared in the spec.
5. **Declare expected N** at the top so the downstream R script can assert it.

## How to use

1. Read `spec-template.md` — copy its structure into the new spec file.
2. Read `admiral-function-catalogue.md` — pick the admiral function for each derivation *before* writing the description.
3. Fill the Variables table row-by-row. For each row, the "Derivation" column must either:
   - name an admiral function (e.g. `derive_vars_merged_lookup(DM on USUBJID)`), or
   - cite a direct source (e.g. `DM.AGE`), or
   - say `CUSTOM — see §Derivations.X`.
4. Any row flagged CUSTOM must have a matching block in the Derivations section with pseudocode.
5. Before finalising: walk the QC Checks section — each population flag should have a count assertion, each event variable should have a missing/not-missing rule.

## Common traps this skill guards against

- **Missing TRTSDT/TRTEDT on subjects who were randomised but never dosed.** Spec must state the rule (usually: `TRTSDT = first EX.EXSTDTC; TRTEDT = last EX.EXENDTC; NA if no EX rows`).
- **PFS censoring ambiguity.** Spec must pick one censoring rule from `admiralonco` source objects (e.g. `lastalive_censor` vs `lasta_censor`) and cite it.
- **Confirmed response logic silently diverging from RECIST 1.1.** Use `derive_param_confirmed_bor()` / `derive_param_confirmed_resp()` — do not hand-code.
- **Baseline derivation drift across ADLB / ADVS / ADTR.** All baseline flags go through `derive_var_base()` with the same `filter` expression.

## Files in this skill

- `SKILL.md` — this file.
- `spec-template.md` — the canonical section skeleton and 8-column variable table.
- `admiral-function-catalogue.md` — mapping from ADaM derivation patterns to specific admiral / admiralonco functions (verified against admiral 1.4.1 / admiralonco 1.4.0).
