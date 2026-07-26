# onco_phase3_solid — clinTrialData submission bundle

> ⚠️ **FICTIONAL / educational data.** SIMULATED-TORIVUMAB-2026 (TORIVA-LUNG 301,
> `STUDYID = CTX-NSCLC-301`). All identifiers, subjects, drug names, and results
> are synthetic. Not for regulatory or registry use.

Release-ready Parquet export of this study, laid out exactly as the
[`clinTrialData`](https://github.com/Lovemore-Gakava/clinTrialData) R package
expects. Data is distributed via **GitHub Releases**, not committed inside the
package.

## Layout

```
onco_phase3_solid/
├── adam/   12 ADaM datasets  (*.parquet, ADaMIG v1.3)
├── sdtm/   26 SDTM domains   (*.parquet, SDTMIG v3.4)
└── metadata.json             (source / description / domains / n_subjects / version / license / source_url)
```

- **Study slug:** `onco_phase3_solid`
- **Subjects:** 450 (225 torivumab + chemo : 225 placebo + chemo, 1:1) — every
  subject present in `adam/adsl` and `sdtm/dm`
- **Key column:** `USUBJID` on all datasets except the three trial-design
  domains that have no subject axis (`ta`, `te`, `ts`); `se` does carry `USUBJID`
- **Rows:** 812,681 across 38 datasets  ·  **Variables:** 708, 100 % labelled
- **Version:** `v0.1.2`  ·  **License:** CC BY 4.0

The Parquet files here are byte-identical copies of `datasets/{adam,sdtm}/` in the
parent repo (the canonical build outputs).

## Contents

| Domain | Datasets |
|---|---|
| `adam/` (12) | adae, adcm, adds, addv, adex, adlb, admh, adrs, adsl, adtr, adtte, advs |
| `sdtm/` (26) | ae, cm, da, dd, dm, ds, dv, ex, lb, mh, pe, relrec, rs, se, su, suppae, suppcm, suppdm, supplb, suppsu, ta, te, tr, ts, tu, vs |

## Changes since v0.1.1 (2026-07-18)

Every dataset was rebuilt; the whole bundle is new content, not a patch.

- **+4 SDTM trial-design domains** — `ts`, `ta`, `te`, `se` (22 → 26 domains)
- **Pinnacle 21 remediation** — SDTM variables reordered to SDTMIG 3.4 sequence
  (12 domains), plus the structural/CT clean-up passes; SDTM 10,891 and ADaM
  10,890 findings, of which 10,873 are the single accepted `SD0007` DA-units
  warning
- **Analysis-visit windowing** — date-based `AVISIT`/`AVISITN` per SAP §12.2,
  baseline as `AVISIT = "Baseline"` / `AVISITN = 0`, and a single unified
  `ANL01FL` rule across all windowed BDS datasets
- **New data** — alkaline phosphatase (ALP) as a full lab analyte; unscheduled
  lab and vitals visits generated raw-first
- **Fixes** — CTCAE haemoglobin grading unit bug (removed spurious Grade 4s)

## How to publish to a clinTrialData release

The upload runs from a clone of the `clinTrialData` package (it needs a GitHub
token with release-write access — cannot be done from this repo). Copy this
`onco_phase3_solid/` folder into the package's `inst/exampledata/` — **staged
only, never committed**, since `inst/exampledata/` is not build/git-ignored and a
committed copy would ship the whole trial inside the CRAN tarball. Then:

```r
source("data-raw/upload_to_release.R")

# 1. Create the release if it does not exist yet
piggyback::pb_new_release(repo = "Lovemore-Gakava/clinTrialData", tag = "v0.1.2")

# 2. Upload the study data (zips onco_phase3_solid/ and attaches to the release)
upload_study_to_release("onco_phase3_solid", tag = "v0.1.2")

# 3. Upload the curated metadata.json as-is
piggyback::pb_upload(
  file      = "inst/exampledata/onco_phase3_solid/metadata.json",
  repo      = "Lovemore-Gakava/clinTrialData",
  tag       = "v0.1.2",
  name      = "onco_phase3_solid_metadata.json",
  overwrite = TRUE
)
```

Notes:

- Upload the curated `metadata.json` directly rather than calling
  `generate_and_upload_metadata()`. The subject count is now correct upstream
  (`.count_subjects()` prefers `adsl`/`dm`, so it reads 450), but the regenerated
  description would replace the curated one.
- `download_study()` resolves `version = "latest"` to the newest release and
  looks for assets **in that release only**. A new tag must therefore carry the
  other studies' assets too (`cdisc_pilot`, `cdisc_pilot_extended`), exactly as
  `v0.1.1` re-carried everything from `v0.1.0` — otherwise
  `download_study("cdisc_pilot")` breaks against latest.

## Verify after publishing

```r
library(clinTrialData)
list_available_studies()                       # onco_phase3_solid @ v0.1.2
dataset_info("onco_phase3_solid")              # 12 adam / 26 sdtm, n=450
download_study("onco_phase3_solid", force = TRUE)
db <- connect_clinical_data("onco_phase3_solid")
```
