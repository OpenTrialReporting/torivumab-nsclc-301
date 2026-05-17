# SUPPLB — Supplemental Qualifiers for LB — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | SUPPLB |
| **Label** | Supplemental Qualifiers for LB |
| **Class** | RELATIONSHIP |
| **Structure** | One record per LB record per QNAM |
| **Expected N** | 230,788 |
| **Key variables** | `STUDYID`, `RDOMAIN`, `USUBJID`, `IDVAR`, `IDVARVAL`, `QNAM` |
| **SDTMIG version** | v3.4 (§8.4) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

SUPPLB carries two sponsor-defined LB-level qualifiers required by the biomarker SAP: a biomarker test indicator (`BIOMRKFL`) that flags PD-L1, EGFR, ALK, ROS1, KRAS G12C, MET ex14, RET, BRAF V600E, NTRK, and TMB tests; and a central-lab indicator (`CENTRALFL`) that mirrors `BIOMRKFL` because biomarker assays are run centrally in this study while routine labs are local.

## Source (Raw / Input)

| Input | Source | Reason |
|---|---|---|
| `datasets/sdtm/lb.parquet` | Parent LB domain | Provides `USUBJID`, `LBSEQ`, `LBTESTCD` for the biomarker membership test. |

## Variables

SUPP-- shape per SDTMIG §8.4 (consolidated in `programs/sdtm/SDTM-MAPPING-SPEC.md` §16, §20).

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID  | Study Identifier             | Char | 20  | Assigned    | —      | Constant `"CTX-NSCLC-301"` |
| 2 | RDOMAIN  | Related Domain Abbreviation  | Char | 2   | Assigned    | —      | Constant `"LB"` |
| 3 | USUBJID  | Unique Subject Identifier    | Char | 40  | Predecessor | —      | From parent LB |
| 4 | IDVAR    | Identifying Variable         | Char | 8   | Assigned    | —      | Constant `"LBSEQ"` |
| 5 | IDVARVAL | Identifying Variable Value   | Char | 40  | Predecessor | —      | `as.character(LB.LBSEQ)` |
| 6 | QNAM     | Qualifier Variable Name      | Char | 8   | Assigned    | QNAM   | See §QNAM Definitions |
| 7 | QLABEL   | Qualifier Variable Label     | Char | 40  | Assigned    | QLABEL | See §QNAM Definitions |
| 8 | QVAL     | Data Value                   | Char | 200 | Derived     | NY     | `"Y"` / `"N"` per QNAM logic |
| 9 | QORIG    | Origin                       | Char | 20  | Assigned    | QORIG  | Constant `"DERIVED"` |
| 10 | QEVAL   | Evaluator                    | Char | 20  | Assigned    | —      | `""` |

## QNAM Definitions

| QNAM | QLABEL | Type | Length | Source | Derivation logic |
|---|---|---|---|---|---|
| BIOMRKFL  | Biomarker Test Indicator | Char | 1 | `LB.LBTESTCD` | `"Y"` if `toupper(trim(LBTESTCD))` is in the biomarker code set (see below); else `"N"`. |
| CENTRALFL | Central Lab Indicator    | Char | 1 | derived from `BIOMRKFL` | Equals `BIOMRKFL` (biomarkers are central; routine labs are local). |

**Biomarker code set** (case-insensitive match against `LBTESTCD`):

```
PDL1, PDL1TPS, PD_L1_TPS,
EGFR, EGFRMUT, EGFR_MUT,
ALK,  ALKREARR, ALK_REARR,
ROS1, ROS1REARR, ROS1_REARR,
KRAS, KRASG12C, KRAS_G12C,
METEX14, MET_EX14,
RET,  RETREARR, RET_REARR,
BRAF, BRAFV600E, BRAF_V600E,
NTRK, NTRKFUSE,  NTRK_FUSE,
TMB
```

Both QNAMs are emitted for every parent LB record (long form via `pivot_longer`), yielding 2 × `nrow(LB)` rows.

## Derivations

```r
lb <- read_parquet("datasets/sdtm/lb.parquet")

biomarker_codes <- c(
  "PDL1","PDL1TPS","PD_L1_TPS",
  "EGFR","EGFRMUT","EGFR_MUT",
  "ALK","ALKREARR","ALK_REARR",
  "ROS1","ROS1REARR","ROS1_REARR",
  "KRAS","KRASG12C","KRAS_G12C",
  "METEX14","MET_EX14",
  "RET","RETREARR","RET_REARR",
  "BRAF","BRAFV600E","BRAF_V600E",
  "NTRK","NTRKFUSE","NTRK_FUSE",
  "TMB"
)

lb_flagged <- lb |>
  mutate(
    LBTESTCD_UP = toupper(trimws(LBTESTCD)),
    BIOMRKFL    = ifelse(LBTESTCD_UP %in% biomarker_codes, "Y", "N"),
    CENTRALFL   = ifelse(BIOMRKFL == "Y", "Y", "N")
  )

supplb <- lb_flagged |>
  pivot_longer(c(BIOMRKFL, CENTRALFL), names_to = "QNAM", values_to = "QVAL") |>
  transmute(
    STUDYID  = "CTX-NSCLC-301", RDOMAIN = "LB", USUBJID,
    IDVAR    = "LBSEQ", IDVARVAL = as.character(LBSEQ),
    QNAM,
    QLABEL   = case_when(
      QNAM == "BIOMRKFL"  ~ "Biomarker Test Indicator",
      QNAM == "CENTRALFL" ~ "Central Lab Indicator"
    ),
    QVAL, QORIG = "DERIVED", QEVAL = ""
  ) |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)
```

**Sort:** `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## QC Checks

- [ ] `nrow(supplb) == 230788` (= 2 × 115,394 LB rows).
- [ ] `QNAM ∈ {BIOMRKFL, CENTRALFL}` only; every parent LB record contributes both.
- [ ] `QVAL ∈ {"Y","N"}`, no missing.
- [ ] `RDOMAIN == "LB"`, `IDVAR == "LBSEQ"`, `QORIG == "DERIVED"` for all rows.
- [ ] For matched parent rows: `BIOMRKFL == "Y"` iff `LBTESTCD` (uppercased) is in the biomarker code set.
- [ ] `BIOMRKFL == CENTRALFL` for every parent LB record (invariant for this study).
- [ ] Sort matches `(USUBJID, as.integer(IDVARVAL), QNAM)`.

## Traceability

| Spec → Code | Code → Output |
|---|---|
| `programming-specs/SDTM-SUPPLB-spec.md` → `programs/sdtm/supplb.R` | `programs/sdtm/supplb.R` → `datasets/sdtm/supplb.parquet` |

Consolidated mapping reference: `programs/sdtm/SDTM-MAPPING-SPEC.md` §20.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft (covers v0.2 back-fill of SUPPLB released 2026-05-16). |
