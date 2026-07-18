# onco_phase3_solid — clinTrialData submission bundle

> ⚠️ **FICTIONAL / educational data.** SIMULATED-TORIVUMAB-2026 (TORIVA-LUNG 301).
> All identifiers, subjects, drug names, and results are synthetic. Not for
> regulatory or registry use.

Release-ready Parquet export of this study, laid out exactly as the
[`clinTrialData`](https://github.com/Lovemore-Gakava/clinTrialData) R package
expects. Data is distributed via **GitHub Releases**, not committed inside the
package.

## Layout

```
onco_phase3_solid/
├── adam/   12 ADaM datasets  (*.parquet, ADaMIG v1.3)
├── sdtm/   22 SDTM domains   (*.parquet, SDTMIG v3.4)
└── metadata.json             (source / description / domains / n_subjects / version / license / source_url)
```

- **Study slug:** `onco_phase3_solid`
- **Subjects:** 450 (300 torivumab : 150 placebo, 2:1) — every subject present in `adam/adsl` and `sdtm/dm`
- **Key column:** all 34 datasets carry `USUBJID`
- **Version:** `v0.1.1`  ·  **License:** CC BY 4.0

The Parquet files here are byte-identical copies of `datasets/{adam,sdtm}/` in the
parent repo (the canonical build outputs).

## How to publish to a clinTrialData release

The upload runs from a clone of the `clinTrialData` package (it needs a GitHub
token with release-write access — cannot be done from this repo). Copy this
`onco_phase3_solid/` folder into the package's `inst/exampledata/`, then:

```r
source("data-raw/upload_to_release.R")

# 1. Upload the study data (zips onco_phase3_solid/ and attaches to the release)
upload_study_to_release("onco_phase3_solid", tag = "v0.1.1")

# 2. Generate + upload metadata.json (enables dataset_info())
generate_and_upload_metadata(
  source      = "onco_phase3_solid",
  description = "Synthetic Phase 3 NSCLC trial (torivumab anti-PD-L1, N=450); SDTMIG v3.4 + ADaMIG v1.3. Fictional / educational.",
  version     = "v0.1.1",
  license     = "CC BY 4.0",
  source_url  = "https://github.com/OpenTrialReporting/torivumab-nsclc-301",
  tag         = "v0.1.1"
)
```

> Note: `generate_and_upload_metadata()` recomputes `n_subjects` from the first
> Parquet file it finds. The `metadata.json` staged here reports the true study N
> (450, from ADSL/DM); regenerate if you prefer the script's value.
