---
name: sdtm-conformance
description: Use when making SDTM datasets pass Pinnacle 21 (SDTM-IG 3.4 FDA), remediating P21 SDTM findings, or building SDTM mapping programs to be conformant. Covers the validate→map→fix→verify loop, reading the real CDISC CT files, the XPT v5 traps, and a rule-by-rule fix playbook (CT2001/2/3, SD0051 VISITNUM, SD1022 QNAM, RELREC, units, etc.). Load `p21-rule-playbook.md` for the per-rule catalogue.
---

# sdtm-conformance

Project-local skill for making the SDTM datasets in `datasets/sdtm/` pass the
Pinnacle 21 Community validator (config **2508.1**, SDTM-IG 3.4 FDA, CDISC CT
**2026-03-27**). Distilled from the 2026-07-18 remediation that took SDTM from
~590K findings to ~5K.

Fixes go in the **SDTM mapping programs** (`programs/sdtm/*.R`) — never hand-edit
the parquet. Then regenerate and re-validate.

## The remediation loop (do it in this order)

1. **Export XPT + define.** `Rscript programs/export/build_xpt.R` writes `xpt/sdtm/*.xpt`;
   `programs/define/build_define.R` writes `define/define.xml`. (Both also run as the
   finalize step of `programs/adam/00_run_adam.R`.)
2. **Run Pinnacle 21** — SDTM-IG 3.4 (FDA) config, point it at `xpt/sdtm/` + `define/define.xml`.
   Drop the report in `qc/p21-reports/<date>/`.
3. **Parse the report from the `Details` sheet, not `Issue Summary`.** The Issue Summary
   sheet **merges the Severity cells**, so a naïve read shows almost nothing — you must
   LOCF-fill severity or (simpler) aggregate the `Details` sheet by `Pinnacle 21 ID`.
   Note: `Details` **caps display at 1000 rows per rule** — real counts are higher; get
   true totals from the `Found` column of the (fill-corrected) Issue Summary.
4. **Map each finding to its fix** — see `p21-rule-playbook.md`.
5. **For CT findings, verify the target value against the real CDISC CT** (next section) —
   never guess a codelist value.
6. **Fix in `programs/sdtm/<domain>.R`**, regenerate that domain, then run
   `programs/sdtm/16_label_domains.R` to re-apply labels, then rebuild define + XPT.
7. **VERIFY AT THE XPT LEVEL, not just the parquet** (see traps). Then re-run P21.

## Reading the real CDISC controlled terminology

The authoritative values live in the P21 install, **not** in `raw/codelists/cdisc_ct.csv`
(that project file contains some non-CDISC values, e.g. "Haemoglobin"):

```
<P21 dir>/configs/data/CDISC/SDTM/2026-03-27/SDTM Terminology.odm.xml
```

Extract a codelist by `Name=`. Small codelists use `<CodeListItem CodedValue="..">`
with a `<Decode><TranslatedText>` (the --TESTCD → --TEST decode); large enumerated
ones (Unit, Anatomical Location, Country) use `<EnumeratedItem CodedValue="..">` with
**no** decode. Always confirm each mapped value `%in%` the codelist before using it —
several are counter-intuitive:
- Metric units are lowercase (`mg`, `mg/m2`) but **`VIAL` is UPPERCASE**.
- `AESEV` is a 3-point scale (MILD/MODERATE/SEVERE) — life-threatening/fatal are *seriousness*.
- `--TEST` (name) must be the exact CDISC **Decode** of its `--TESTCD`, or CT2003 fires.

## XPT v5 traps (these cause SD0055/SD1324/SD0057/SD0058/SD1022)

- **Variable names ≤ 8 chars.** `CENTRALFL`(9)→`CENTLBFL`, `PCANCERFL`→`PCANCFL`,
  `SUPACKYRS`→`SUPACKYR`. A 9-char name silently truncates in the XPT → define/dataset
  name mismatch (SD0054/SD0060) or invalid QNAM (SD1022).
- **Labels ≤ 40 chars.** `build_define.R` and `build_xpt.R` both truncate to 40; keep the
  source labels ≤40 so define == XPT (SD1324).
- **QNAM must be ≤8 and a valid variable name.**
- **Non-standard variables** (`AEDISCOD`, `CMATC`, `SUPACKYR`, `PENORM`) trip SD0058 —
  the conformant home is a SUPP-- qualifier, not the parent domain.

## Regeneration discipline (learned the hard way)

- Re-running `16_label_domains.R` rewrites **all 22** SDTM parquet (arrow re-serialization),
  even unchanged ones. To keep commits focused, `git checkout HEAD -- datasets/sdtm/<d>.parquet`
  the byte-only-churned domains and keep only the ones with real content changes.
- **DANGER:** do not `git checkout` a domain you just fixed — that reverts your data and
  ships stale parquet with fixed code (a real bug we hit: COUNTRY/TRLNKID didn't clear and
  RELREC IDVAR stopped matching → SD0075). **After any regen, verify the fix in the XPT**
  (`haven::read_xpt`), because that is exactly what P21 reads.
- Inline `Rscript -e '...'` that reads parquet segfaults intermittently in this env — write
  the check to a `.R` file and run it.

## Cascade awareness

Some SDTM fixes flow into ADaM: `DM.SEX`→ADSL, `LB.LBTEST`→ADLB `PARAM`, SDTM `VISITNUM`
→ ADaM `AVISITN` (via `derive_avisitn` coalesce). Re-run `00_run_adam.R` after those and
check the ADaM layer too. DA/TU/DD/SU are **not** read by ADaM.

## Files in this skill
- `SKILL.md` — this file.
- `p21-rule-playbook.md` — per-rule (Pinnacle 21 ID → root cause → fix) catalogue.
