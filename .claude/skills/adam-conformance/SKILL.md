---
name: adam-conformance
description: Use when making ADaM datasets pass Pinnacle 21 (ADaM-IG 1.3 FDA), remediating P21 ADaM findings, or building ADaM derivations to be conformant. Covers the validate→fix→verify loop (validating ADaM WITH SDTM present), 100% label coverage, reading exact CDISC labels from the P21 config, and a rule-by-rule fix playbook (AVISIT/AVISITN, study-day, baseline, dup keys, MedDRA codes, etc.). Load `p21-rule-playbook.md` for the catalogue. Complements `adam-spec` (which is for authoring specs).
---

# adam-conformance

Project-local skill for making the ADaM datasets in `datasets/adam/` pass the
Pinnacle 21 Community validator (config **2508.1**, ADaM-IG 1.3 FDA, CDISC CT
**2026-03-27**). Distilled from the 2026-07-18 remediation that took the ADaM
layer from 36,921 findings to ~0.

Sibling of `adam-spec` (that skill authors the `AD*-spec.md`; this one makes the
generated data conformant). Fixes go in `programs/adam/*.R` and
`programs/adam/label_adam.R` — regenerate via `00_run_adam.R`, never hand-edit parquet.

## The remediation loop

1. **Regenerate.** `Rscript programs/adam/00_run_adam.R` derives all 12 datasets, runs
   the `label_adam.R` label pass (hard-gates at 100% coverage), then builds define + XPT.
2. **Run Pinnacle 21 — ADaM-IG 1.3 (FDA) — WITH the SDTM datasets present.** Validating
   ADaM alone raises false positives: `SD0061` (define references the SDTM datasets that
   aren't in the folder) and `AD1024/25/26` (traceability rules skipped for missing
   DM/AE/EX). Put SDTM + ADaM XPT where P21 can see both.
3. **Parse from the `Details` sheet** (Issue Summary merges Severity cells; Details caps
   display at 1000/rule). Aggregate by `Pinnacle 21 ID`.
4. **Fix in the derivation program**, re-run, then **verify at the XPT level**
   (`haven::read_xpt`) — that is what P21 reads, and byte-churn/stale-parquet mistakes are
   easy to make (see the SDTM skill's regeneration discipline).

## 100% label coverage is a hard gate

`label_adam.R` resolves every column's label from three layers, highest wins:
1. **STANDARD** — CDISC-controlled labels that must match *exactly* (P21 **AD0018**). Read
   the expected string from the P21 config, not memory:
   `<P21 dir>/configs/data/CDISC/ADaM/2026-03-27/ADaM Terminology.odm.xml`, or the rule
   descriptions in `.../configs/2508.1/ADaM-IG 1.3 (FDA).xml` (e.g. `STARTDT` = "Time-to-
   Event Origin Date for Subject", `ONTRTFL` = "On Treatment Record Flag" — no hyphen).
2. **spec** — parsed from `AD*-spec.md` variable tables.
3. **SUPPLEMENT** — analysis vars absent from specs (ADY, AVISIT, TRT01PN, MedDRA codes…).

Any column left unlabelled **stops the run**. When you add a variable to a derivation,
add its label to STANDARD/SUPPLEMENT (or the spec) in the same change.

## Key conventions this layer enforces (see playbook for the rule map)

- **AVISIT/AVISITN** are *conditionally required* for by-visit BDS (ADLB/ADVS/ADRS/ADTR/
  ADEX). Derive via `programs/adam/_visit_utils.R::derive_avisitn()` — gap-free numeric
  ordering; it coalesces the (now-populated) SDTM VISITNUM.
- **Study day has no day 0.** Use `programs/adam/_adam_utils.R::study_day(dt, ref)` for
  every ADY/ASTDY/AENDY.
- **Baseline** = exactly one ABLFL='Y' per USUBJID/PARAMCD; BASE = that record's AVAL.
- **PARAM is 1:1 with PARAMCD** (generic PARAM; put the grouping dimension elsewhere, e.g.
  ADEX drug in AEXTRT).
- **Y-only flags** (TRTEMFL, ONTRTFL) are Y or null — never "N".
- **OCCDS datasets have no AVAL** (ADAE/ADCM) — that's a BDS variable.
- **Define key variables must be unique** per BDS dataset (`build_define.R` DOMAIN_META) or
  SD1152 duplicate-records fires (ADTR needs +LNKID, ADEX needs +NCYCLE).
- **Numeric ADaM date vars** (R `Date`) → declare `DataType="integer"` in define, not
  `"date"` (that's for ISO character dates) — SD0059.
- **Variable names ≤ 8, labels ≤ 40** (XPT v5), same as SDTM.

## Files in this skill
- `SKILL.md` — this file.
- `p21-rule-playbook.md` — per-rule (Pinnacle 21 ID → root cause → fix) catalogue.
