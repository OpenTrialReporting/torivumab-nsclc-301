---
name: tfl-review
description: Use when reviewing, QC-ing, or changing any TFL output in programs/tfl/ or tfl/ — safety tables, efficacy tables, listings, figures — or before merging a PR that touches them. Covers the arm-mapping trap that shipped reversed treatment arms in three safety tables, the shell-to-program agreement contract, cross-table reconciliation, and the regenerate-and-recompute verification loop. Load `cross-table-reconciliation.md` for the table pairs that must agree.
---

# tfl-review

Project-local skill for reviewing the TFL layer (`programs/tfl/` → `tfl/tables/`,
`tfl/figures/`). Distilled from the 2026-09-20 review that found swapped treatment
arms in three shipped safety tables, a missing SAP estimand, and shell/catalogue
drift.

Sibling of `adam-conformance` (that skill makes the data conformant; this one checks
what the tables say about it). A table can be perfectly conformant and still be wrong.

## The trap that actually shipped — arm mapping

`group_by()` sorts its keys, so `pivot_wider(names_from = TRT01A)` emits arm columns
**alphabetically** — `Placebo + Chemotherapy` before `Torivumab + Chemotherapy` —
regardless of data order. Renaming them positionally silently swaps the arms:

```r
# WRONG — col 3 is Placebo, not Torivumab
names(inc) <- c("SOC", "PT", "TRT", "PBO")

# RIGHT — and guard the missing-arm case, as t_cm_01/t_mh_01 do
if (!trt_col %in% names(inc)) inc[[trt_col]] <- 0L
inc <- inc |> rename(TRT = !!trt_col, PBO = !!pbo_col)
```

This shipped in `build_ae_soc_pt_ft()` and reversed **T-AE-03, T-AE-04 and T-AE-05**.
T-AE-05 reported endocrine irAEs as 19 on placebo vs 3 on torivumab — clinically
impossible for a checkpoint inhibitor, and it contradicted T-AE-01.

**Why the existing QC missed it.** Every routine check still passes under a swap:
column Ns come from ADSL by name, no percentage exceeds 100, SOC ≥ PT holds, and
shuffling input row order changes nothing because the reshape keys are sorted. A
spot-check only catches it if you happen to pick an arm-asymmetric row — pick
Thrombocytopenia in T-AE-04 (14 vs 14) and it sails through.

**So check it directly:** take the most arm-asymmetric row in the table (largest
absolute between-arm difference), recompute both arms with `n_distinct(USUBJID)`,
and confirm the column *labelled* with the active arm carries the active arm's count.

## Verification loop

1. **Regenerate** — `source("programs/tfl/_helpers.R")` then source the program(s).
   Never hand-edit anything in `tfl/`.
2. **Recompute independently** from `datasets/adam/*.parquet` with plain dplyr — do
   not read numbers back out of the flextable and call that a check.
3. **Compare cell by cell**, not by eye. Report the mismatch count, including zero.
4. **Rebuild dependants** — `99_combine_outputs.R` for `tfl/TFL-OUTPUTS.*`, and the
   shell catalogue if `shells.yaml` changed (see below).

R packages resolve from the system library and match `uvr.lock`; `uvr` itself cannot
bootstrap here (no CLI, no package, no `.uvr/`, `repos` unset). Check versions against
the lock before trusting a regenerated submission artefact.

## Shell ↔ program agreement

`sap/shells/shells.yaml` is the source of truth. `TFL-SHELLS.md` / `.html` /
`-DOC.docx` are generated — **never hand-edit them**:

```
render_shells.R  →  render_shells_html.R  →  render_shells_doc.R
```

Before changing a table, read its shell entry; it overrides defaults. After changing
one, check all four agree:

- `layout.rows` lists exactly the rows the program emits, in output order.
- `annotations.rows` likewise, with the derivation the program actually uses.
- `key_variables` names variables that exist in the data *and* in `AD*-spec.md`.
- `methods` cites every method used — and no orphans.

Both have drifted in real life: `shells.yaml`'s `meta:` block sat at v0.1 while the
rendered catalogue said v0.3, so re-rendering silently reverted real content; and
T-AE-01's row list cited `any AESI`, a variable in neither ADAE nor `ADAE-spec.md`.
Run `Rscript sap/shells/validate_shells.R` — it passes on both, so it is a floor,
not a ceiling.

## Numbers and their footnotes

- **Denominators come from ADSL**, filtered to the analysis set — never from the
  count of subjects appearing in ADAE.
- **Footnotes must state the filters the program actually applies.** T-AE-02's read
  `WHERE TRTEMFL='Y'` while the program also filtered `SAFFL='Y'`.
- **Percentages need their denominator named** when it is not the column N.
- **A threshold in the title must be the threshold in the code.** If a "≥5% in any
  arm" table can contain a 3.6% row, say which column the threshold applies to.
- **Pooling arms across a randomised comparison is almost always wrong.** A Total
  column on a SOC/PT table dilutes the drug signal; the shells specify it for
  T-AE-01 only, deliberately.

## Format parity

`write_table_all_formats()` writes DOCX, RTF and HTML, but **RTF carries the table
grid only** — no title, no population line, no footnotes (`_helpers.R:382`, by
design, assuming regulatory wrapping supplies them). A footnote-only change
therefore leaves the RTF byte-identical. That is expected, not a failed write.

## Cross-table reconciliation

Tables built from the same data must agree, and several here do not. Check the pairs
in `cross-table-reconciliation.md` before approving any safety-table change — two
live contradictions are recorded there, both upstream data issues rather than TFL
bugs, so do not "fix" them in a table program.

## Scope discipline

Fixing a table is not licence to change the analysis. Adding a row the shell
specifies but the program never emitted, or implementing a missing SAP method, is a
separate change with its own review — say so rather than folding it into a bug fix.
