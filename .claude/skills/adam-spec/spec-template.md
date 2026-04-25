# ADaM Spec Template — AD{XX}

Copy this whole file into `programming-specs/AD{XX}-spec.md` and fill in the placeholders. Keep the section order; regulators and reviewers scan by section heading.

---

## Header

| Field | Value |
|---|---|
| **Dataset** | AD{XX} |
| **Label** | e.g. "Subject-Level Analysis Dataset" |
| **Class** | SUBJECT LEVEL ANALYSIS DATASET / BASIC DATA STRUCTURE / OCCURRENCE DATA STRUCTURE / (ADAM OTHER) |
| **Structure** | e.g. "One record per subject" |
| **Expected N** | e.g. "450" — stated numerically so the R script can assert it |
| **Key variables** | e.g. `USUBJID`, `PARAMCD`, `AVISIT` |
| **Spec version** | 0.1 DRAFT / 1.0 LOCKED |
| **Spec author** | name |
| **Date** | YYYY-MM-DD |

## Purpose

One paragraph. What analyses does this dataset enable? Cite the SAP / protocol section.

## Dependencies

| Input | Source | Reason |
|---|---|---|
| SDTM.DM | `sdtm/dm.parquet` | Subject backbone, stratification |
| ADSL | `adam/adsl.parquet` | Treatment dates, population flags |
| ... | ... | ... |

## Variables

The 8-column variable table. Every variable defined in the dataset goes here, in logical order (identifiers → treatment → dates → analysis variables → flags).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Predecessor | — | `DM.STUDYID` |
| 2 | USUBJID | Unique Subject Identifier | Char | 30 | Predecessor | — | `DM.USUBJID` |
| 3 | SUBJID | Subject Identifier for the Study | Char | 10 | Predecessor | — | `DM.SUBJID` |
| ... | ... | ... | ... | ... | ... | ... | ... |

Column rules:
- **Type** — `Char` or `Num`. No "varchar", no "integer".
- **Length** — integer. For Num use the SAS default (8) unless otherwise specified.
- **Origin** — one of: `Predecessor`, `Assigned`, `Derived`, `Protocol`, `CRF`.
- **Codelist** — CDISC CT codelist name (e.g. `NY`, `SEX`, `RACE`) or a study codelist name, or `—` if not applicable.
- **Derivation** — either `SDTM.{DOMAIN}.{VAR}` for direct source, or a named admiral call (`derive_vars_merged(...)`), or `CUSTOM — see §Derivations.{N}`.

## Derivations

For every row flagged CUSTOM in the Variables table, and for every admiral call that needs non-default arguments, write a subsection here.

### D.1 {Variable name or derivation topic}

**Rule:** plain-English description of the derivation.

**Inputs:** source datasets / variables.

**Pseudocode:**
```r
# admiral call or hand-coded logic
```

**Edge cases:** missing, ties, boundary visits, screen-failures.

## Population Flags

Spelled out explicitly because every other ADaM dataset merges these from ADSL.

| Flag | Definition | Expected N |
|---|---|---|
| SAFFL | Received ≥1 dose of study treatment (`EX` rows exist) | e.g. 448 |
| ITTFL | Randomised | 450 |
| PPROTFL | Randomised AND no major protocol deviations | e.g. ≥405 |

## QC Checks

Bulleted list of checks the R script (or a companion QC script) must run.

- [ ] Record count equals Expected N.
- [ ] No duplicates on key variables.
- [ ] Every variable has label and length matching this spec (`xportr::xportr_length()`, `xportr::xportr_label()`).
- [ ] Population flag counts match the Population Flags table.
- [ ] Analysis-value variables (`AVAL`, `AVALC`) are non-missing where the spec requires.
- [ ] No out-of-codelist values in CDISC-coded variables.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/AD{XX}-spec.md` → `adam/ad{xx}.R` | `adam/ad{xx}.R` → `adam/ad{xx}.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | YYYY-MM-DD | name | Initial draft |
