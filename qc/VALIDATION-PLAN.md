# Validation Plan — SIMULATED-TORIVUMAB-2026

> **Status:** v0.1 DRAFT — 2026-05-16
> **Scope:** Phases 3–6 deliverables (raw → SDTM → ADaM → Define-XML → TFLs).
> Phase 7 (CSR) and Phase 8 (ADRG) are out of scope until those phases are written.
> **Synthetic data:** Source-data verification (SDV) is **not in scope** — there
> is no source. All validation focuses on derivation correctness, CDISC
> compliance, statistical reproducibility, and visual/structural fidelity.
> **Not for regulatory submission.**

---

## 1. Validation philosophy

Every output in this project must be reproducible by **two independent
mechanisms**:

1. **Re-running the committed code** must produce byte-identical outputs
   (modulo line-ending normalisation) — verified by
   `programs/qc/run_reproducibility_check.R`.
2. **An independent QC programmer** must re-derive the output from the
   written specification alone — verified by visual/numerical comparison
   between the primary and QC outputs.

If either mechanism fails, the output cannot be locked.

The mapping specs in `programs/sdtm/SDTM-MAPPING-SPEC.md`,
`programs/adam/ADAM-MAPPING-SPEC.md`, and `sap/shells/shells.yaml` are the
**contract** between primary and QC. QC programmers must not read the
primary R code before they begin.

---

## 2. Layered approach

Different layers have different acceptance criteria. The strategy is:

| Layer | Type | Tools | Acceptance |
|---|---|---|---|
| Raw simulation | Reproducibility from seed | `validate_covariate_effects.R` + byte-diff against committed CSVs | All 14 CSVs identical (modulo line endings); Cox HRs within input 95% CIs |
| SDTM | Independent double programming + CDISC structural | Per spec, `waldo::compare()` + Pinnacle 21 | Row count match within ±0.1%; var-by-var identical; Pinnacle 21 errors = 0 |
| ADaM | Independent double programming + statistical reproducibility | Per spec, `waldo::compare()` + Cox HR tolerance | Var-list identical; ANL01FL never "N"; Cox HRs within ±0.05 of primary; KM medians within ±0.5 mo |
| Define-XML | Schema + content validation | xml2 schema validation + Pinnacle 21 Define-XML mode | XML well-formed; ItemGroupDef count matches dataset count; every ItemRef has a corresponding ItemDef |
| TFL | Cell-by-cell match + visual review | `extract_tfl_values.R` + `compareDF` | Every numeric cell matches to printed precision; layout matches shell DOCX; figures pass biostat visual review |
| Cross-cutting | Pipeline reproducibility | `run_reproducibility_check.R` | End-to-end re-run is byte-identical |

---

## 3. Roles and responsibilities

Three independent humans (or pairs):

| Role | Responsibilities |
|---|---|
| **Primary programmer** | Writes code per spec; produces output; marks tracker as `Programmed — pending QC`. Available to answer QC questions but does **not** advise on approach. |
| **QC programmer** | Reads only the mapping spec (`SDTM-MAPPING-SPEC.md`, `ADAM-MAPPING-SPEC.md`, `shells.yaml`) and CDISC standards. Re-derives independently in a fresh codebase. Runs comparison tooling and files findings on the tracker. |
| **Reviewer** | Biostatistician + Data Manager. Adjudicates ambiguity, reviews accepted-limitation findings, signs off on lock via the `Sign-off` sheet. |

A QC failure does not automatically mean the primary code is wrong — it
may mean the spec is ambiguous. The reviewer adjudicates.

---

## 4. Tooling

### 4.1 Required external tools

| Tool | Purpose | License |
|---|---|---|
| **Pinnacle 21 Community** | CDISC structural validation (SDTM, ADaM, Define-XML) | Free |
| R packages: `waldo`, `diffdf`, `arrow`, `survival`, `survRM2`, `openxlsx2`, `officer` | Comparison + numerical + DOCX parsing | CRAN |

Pinnacle 21 should be run after **both** primary and QC SDTM/ADaM
implementations are complete, on each separately. The Pinnacle 21 reports
themselves form QC evidence.

### 4.2 Built-in scripts

| Script | Purpose |
|---|---|
| `programs/qc/build_trackers.R` | Regenerates the three Excel trackers (overwrites — do not run blindly once QC data is entered) |
| `programs/qc/run_reproducibility_check.R` | Re-runs the full pipeline into a staging directory and diffs against committed outputs |
| `programs/qc/compare_sdtm.R` | Wraps `waldo::compare()` + `diffdf::diffdf()` for primary-vs-QC SDTM directories; emits markdown report |
| `programs/qc/compare_adam.R` | Same as above for ADaM |
| `programs/qc/extract_tfl_values.R` | Parses `tfl/tables/*.docx` and extracts numeric cells to CSV for diffing |

---

## 5. Phased execution

Recommended order, assuming one QC programmer and one reviewer working in parallel with the primary team:

| Phase | What | Duration |
|---|---|---|
| **A.** Reproducibility check | Run `run_reproducibility_check.R` on the as-committed state | 1 day |
| **B.** Raw + SDTM double programming | 21 domains × 1 QC programmer per `SDTM-MAPPING-SPEC.md` | 5–7 days |
| **C.** Pinnacle 21 SDTM scan | Run against the QC-passed SDTM directory | 0.5 day |
| **D.** ADaM double programming | 6 datasets × 1 QC programmer per `ADAM-MAPPING-SPEC.md` | 3–5 days |
| **E.** Pinnacle 21 ADaM scan | Same approach as Phase C | 0.5 day |
| **F.** TFL numerical match | 38 outputs; `extract_tfl_values.R` for cell extraction | 5–7 days |
| **G.** Statistical sense checks | Biostat review of HRs / medians / ORR / waterfall direction | 1 day |
| **H.** Lock + sign-off | Populate signature blocks on each tracker | 0.5 day |

**Total: 15–22 working days** for a single QC programmer + reviewer pair.

Phases A, B, C are blocking. Once SDTM is locked, D–E can begin while F
runs in parallel (TFL programmers only need ADaM locked, not Pinnacle 21).

---

## 6. Acceptance criteria — per layer

### 6.1 Raw

- All 14 CSVs in `raw/` byte-identical to committed state (modulo line endings)
- `validate_covariate_effects.R` reports:
  - All Cox HRs within 95% CI of input values
  - All marginal medians within ±2.5 months of protocol targets (PFS_TRT may be +3.3 — **accepted**, see §8)

### 6.2 SDTM

- Per-domain row count: primary vs QC within ±0.1%
- Variable list, order, type, length: identical
- Per-variable value comparison: 100% match for all character variables;
  numeric variables match to 6 significant figures
- `--SEQ` strictly increasing per `USUBJID` with no gaps
- USUBJID set identical across all domains for the same subject
- Pinnacle 21: zero errors; warnings reviewed and either resolved or
  documented as accepted limitation

### 6.3 ADaM

- All SDTM acceptance criteria above plus:
- `ANL01FL = "Y"` or NA (never `"N"`)
- `SAFFL`, `ITTFL`, `PPROTFL`, `DTHFL` = "Y" or "N" — counts match between
  primary and QC exactly
- Cox HRs within ±0.05 of primary on:
  - OS (PARAMCD='OS')
  - PFS (PARAMCD='PFS')
  - OSWOT (PARAMCD='OSWOT')
- KM medians within ±0.5 months of primary
- Per-parameter row counts match exactly

### 6.4 Define-XML

- XML well-formed (xml2 parses without error)
- ItemGroupDef count = number of datasets in `datasets/sdtm/` + `datasets/adam/`
- Every `ItemRef` has a corresponding `ItemDef`
- Every `--leaf` `xlink:href` resolves to an actual file (or future XPT)
- Pinnacle 21 Define-XML check: no errors

### 6.5 TFLs

- Every numeric cell in every table matches primary to printed precision
- Layout matches `sap/shells/TFL-SHELLS-DOC.docx`:
  - Row labels identical
  - Column headers identical
  - Section/indent hierarchy preserved
- Figures pass biostat visual review (HR direction sane, KM curves
  monotonic non-increasing, waterfall ordered, etc.)
- Footnotes referencing `sap/SAP.md` resolve to the correct section
- DRAFT watermark present on every output

### 6.6 Cross-cutting

- `run_reproducibility_check.R` reports 100% byte-match for all parquets
  and PNGs (text files allowed line-ending normalisation)

---

## 7. Documentation

Findings are recorded in three places:

1. **The trackers** (`qc/*-PROGRAMMING-TRACKER.xlsx`):
   - `Status` column moves through the workflow
   - `Findings / issues` records every divergence found
   - `Resolution` records how each was resolved
   - `Lock date` populated only when QC has passed
2. **Pinnacle 21 reports** — committed to `qc/p21-reports/<date>/` (folder
   to be created at first scan)
3. **Comparison reports** — `compare_sdtm.R` etc. write timestamped
   markdown reports to `qc/reports/<date>/`

A QC programmer should never edit the primary `programs/` code. All
fixes must be made by the primary programmer in response to a tracker
finding; QC then re-runs the comparison.

---

## 8. Accepted limitations (pre-loaded into trackers)

These are intentional simplifications of the synthetic data — **not** QC
defects. The trackers are pre-populated with these notes so QC
programmers don't waste time re-discovering them.

| ID | Layer | Limitation | Documented in |
|---|---|---|---|
| AL-01 | SDTM | `SUPPSU` is a legacy artifact (STUDYID prefix `TORIVUMAB-NSCLC-301`, not `CTX-NSCLC-301`); no generator script exists in `programs/sdtm/` | `SDTM-MAPPING-SPEC.md` §17 |
| AL-02 | SDTM | `cm.parquet` does not contain post-trial anti-cancer therapy (only supportive-care meds); affects T-DS-03 + T-EFF-12 | `SDTM-MAPPING-SPEC.md` §6 + `RAW-PROVENANCE.md` |
| AL-03 | SDTM | `SDTM.DS` does not carry explicit `DSCAT='PROTOCOL DEVIATION'` records; only PPROTFL='N' is derivable | `SDTM-MAPPING-SPEC.md` §2 |
| AL-04 | ADaM | `PARAMCD='PFSINV'` not derived because the synthetic data has no separate BICR vs Investigator assessment | `ADAM-MAPPING-SPEC.md` §6 |
| AL-05 | Raw | `PFS_TRT` marginal KM median is +3.3 months above protocol target (10.5) due to interval-censoring + the higher RECIST-derived ORR | `RAW-PROVENANCE.md` §10.5 caveat 1 |
| AL-06 | TFL | T-EFF-10 uses τ = 30 months (not the SAP-proposed 36 months) bounded by max follow-up | `t_eff_10_os_rmst.R` footnote |
| AL-07 | TFL | T-EFF-11 (PFS-INV) ≡ T-EFF-03 (PFS) since no separate BICR exists in synthetic data | `t_eff_11_pfs_inv.R` footnote |
| AL-08 | TFL | T-AE-06 (AESI) uses an MedDRA-PT regex stand-in pending the SAP §4.6 deferred AESI list | `t_ae_06_aesi.R` footnote |
| AL-09 | TFL | T-DS-02 subcategories beyond "randomised but never dosed" all show 0 (synthetic data has no granular deviation records) | `t_ds_02_deviations.R` footnote |
| AL-10 | TFL | T-DS-03 rows for subsequent anti-cancer therapy + missed assessments all show 0 (synthetic data limitation) | `t_ds_03_intercurrent_events.R` footnote |
| AL-11 | SDTM | `relrec.parquet` contains duplicate rows (~5 per multi-visit lesion) because `programs/sdtm/relrec.R` emits one row per TU/TR record rather than one per unique lesion-id × subject. Functionally harmless for cross-domain joins but `diffdf` cannot establish unique keys. Documented; a future relrec.R revision should `distinct()` on (USUBJID, RDOMAIN, IDVARVAL). | `programs/qc/compare_sdtm.R` fallback path uses `identical()` to compare instead. |

QC programmers may still raise findings on any of these if they spot
something deeper than the accepted scope — the limitation only covers
the specific behaviour described.

---

## 9. Sign-off workflow

Each tracker has a `Sign-off` sheet with seven roles:

```
Lead programmer               → confirms primary code is final
Lead QC programmer            → confirms QC comparison passed
Biostatistician               → confirms analysis is per SAP
Data manager                  → confirms ADaM is per spec
Project manager               → confirms timeline + budget
Quality assurance             → confirms validation evidence package complete
Sponsor representative        → final business approval
```

All seven signatures + dates required to move every row in the tracker
to `Locked`. Once locked, any change to the underlying dataset / output
triggers re-QC (the cycle restarts).

---

## 10. Project-specific considerations

1. **This is synthetic data.** No source data verification. No clinical
   data quality review of patient records.
2. **No regulatory submission target.** The validation evidence package
   is for educational reference / pharmaverse package contribution
   (`clinTrialData`), not FDA / EMA review.
3. **AI assistance was used throughout authoring.** AI-generated code,
   specs, and provenance are part of the audit trail. AI-generated
   findings (e.g. a future hypothetical `programs/qc/llm_review.R`) must
   be reviewed by a human before being filed as defects.
4. **Pinnacle 21 may flag synthetic-data idiosyncrasies** (e.g. AESEV
   coding, CDISC CT mismatches in MedDRA subset). These should be
   triaged with the SDTM lead before adding to the limitations list.

---

## 11. Change log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-16 | LG (w/ Claude Opus 4.7) | Initial draft. Multi-layer strategy, role definitions, tooling, phased execution, 10 pre-loaded accepted limitations, sign-off workflow. |

---

*Last updated: 2026-05-16*
