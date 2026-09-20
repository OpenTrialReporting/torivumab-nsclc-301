# Cross-table reconciliation map

Tables built from the same ADaM data must agree. Check these pairs whenever you
change a safety table, and recompute both sides — agreement in a previous run is
not evidence for this one.

Figures are from the 2026-09-20 data cutoff (`datasets/adam/`, safety N=449:
225 torivumab / 224 placebo; ITT N=450).

## Must agree — verify on every change

**T-AE-03/04/05 have no overall row** — they start at SOC level. So compare the
T-AE-01 row against `n_distinct(USUBJID)` recomputed under the sibling table's own
filter, which is what that table is built from:

| T-AE-01 row | Recompute over ADAE `SAFFL=='Y' & TRTEMFL=='Y'` and … | Expected (tori / pbo) |
|---|---|---|
| Grade ≥ 3 TEAE | `AETOXGRN >= 3` (the T-AE-03 filter) | 156 / 129 |
| Serious TEAE | `AESER == 'Y'` (the T-AE-04 filter) | 105 / 89 |
| Immune-related TEAE | `IRAEFL == 'Y'` (the T-AE-05 filter) | 63 / 10 |
| Any treatment-emergent AE | no further filter | 225 / 223 |

T-AE-02 *does* carry an overall row, so compare it directly: T-AE-01 "Any TEAE" and
T-AE-02 "Any treatment-emergent AE" must both read 225 / 223.

Column Ns on every safety table header come from ADSL `SAFFL=='Y'`: 225 / 224.

T-AE-01 derives these independently of `build_ae_soc_pt_ft()`, so **T-AE-01 vs
T-AE-03/04/05 is the check that would have caught the swapped arms.** Before the
fix, T-AE-01 said irAEs were 63 torivumab / 10 placebo while T-AE-05 said 3 / 19.
Run this pair first.

## Known contradictions — upstream data, do not patch in a table program

### 1. Fatal AEs absent from ADAE

`SDTM.DD` gives cause `ADVERSE EVENT` for **76 subjects**. Across their 501 ADAE
records: `AETOXGRN == 5` → 0, `AESDTH == 'Y'` → 0, `AEOUT == 'FATAL'` → 0 (every
record reads `RECOVERED/RESOLVED` or `UNKNOWN`; max grade is 4).

Consequence: T-AE-01's "Grade 5 (fatal) TEAE" row is structurally `0 (0.0)` in both
arms while T-AE-07 reports 76 AE-caused deaths (16.9%). The two tables contradict
each other and both are `define/arm.xml` deliverables.

This is why T-AE-01's shell no longer annotates an `AESDTH`-based "any AE → death"
row — it could not be satisfied. Fix belongs in ADAE derivation, not here.

### 2. AE discontinuations do not reconcile with disposition

| Source | Basis | Subjects |
|---|---|---|
| T-AE-01 "TEAE leading to study drug discontinuation" | `AEACN` contains `DRUG WITHDRAWN` | 261 (57.9%) |
| T-DS-01 "Adverse event" | `ADDS.DSDECOD == 'ADVERSE EVENT'` | 71 (15.8%) |

A definitional gap (event-level action vs primary discontinuation reason) would make
disposition a near-subset. It is not: only **38** subjects appear in both, and **33
of the 71** who discontinued for an AE per disposition have no drug-withdrawn AE in
ADAE at all. That is a cross-domain consistency failure between `ADAE.AEACN` and the
DS/ADDS disposition data.

## Explicable differences — not bugs

- **T-AE-07 vs T-DS-01 deaths (311 vs 312).** T-AE-07 is safety population (224
  placebo); T-DS-01 is ITT (225). The one randomised-but-untreated subject died.
- **T-DS-01 column Ns (225/225/450) vs safety tables (225/224/449).** Disposition is
  ITT-based by design.
- **SOC subtotal ≠ sum of its PT rows.** Subtotals count distinct subjects; a subject
  with two PTs in one SOC counts once. Footnoted on the SOC/PT tables.
- **T-AE-02 contains rows below its own ≥5% threshold** (Colitis, Pruritus at 3.6%
  total) *only if* a Total column is present — the threshold is evaluated per
  treatment arm. The shells specify no Total column for T-AE-02; one was proposed and
  reverted for this reason.
