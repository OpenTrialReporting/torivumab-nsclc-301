# TR — Tumor Results — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | TR |
| **Label** | Tumor / Lesion Results |
| **Class** | FINDINGS |
| **Structure** | One record per lesion measurement / response observation per visit per subject |
| **Expected N** | 7,724 |
| **Key variables** | `STUDYID`, `USUBJID`, `TRSEQ`; group keys `TRLINKID`, `TRTESTCD` |
| **SDTMIG version** | CDISC SDTM Oncology Disease Response Supplement §9.2 (RECIST 1.1, 2023) on SDTMIG v3.4 |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

TR holds the per-lesion **measurement and response** observations that underpin RECIST 1.1 assessments. Each raw assessment row generates 0–N TR records, partitioned across three TRTESTCD values: `LDIAM` (target lesion longest diameter, mm), `OVRLRESP` (non-target lesion response category), and `NEWLSN` (new-lesion flag). Together with `TU` (identification) and `RS` (overall response), TR is the SDTM substrate for `ADTR` (target-lesion ADaM) and for the BoR / DOR / BoTL derivations in `ADRS` and `ADTTE` (PFS).

This spec follows the CDISC SDTM Oncology Disease Response Supplement convention (RECIST 1.1, 2023).

## Source (Raw / Input) table

| Source | Type | Reason |
|---|---|---|
| `raw/tumor_measurements.csv` | CDASH Tumor Assessment form (radiology read) | Same source as `TU` (identification) — TR pivots it into measurement records |
| Shared VISIT lookup | `programs/sdtm/SDTM-MAPPING-SPEC.md` §"Shared VISIT lookup" | Maps `VISIT_NAME` → `VISITNUM` |

**Raw columns:** `SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME, LESION_ID, LESION_TYPE, ANATOMICAL_LOCATION, LONGEST_DIAMETER_MM, RESPONSE_CATEGORY, NEW_LESION`.

## Record Sets (long-form pivot)

Each raw row contributes records to up to three TRTESTCD types (logical OR; rows can produce 0, 1, or 2 records, never more given the raw shape):

| Set | Filter on raw row | TRTESTCD | TRTEST | TRORRES / TRSTRESC | TRSTRESN | TRSTRESU |
|---|---|---|---|---|---|---|
| **Target lesion** | `TRGRPID == "TARGET"` AND `LONGEST_DIAMETER_MM` not NA | `LDIAM` | "Longest Diameter" | `as.character(LONGEST_DIAMETER_MM)` | `as.numeric(LONGEST_DIAMETER_MM)` | `"mm"` |
| **Non-target response** | `TRGRPID == "NON-TARGET"` AND `RESPONSE_CATEGORY` not NA/blank | `OVRLRESP` | "Overall Response" | trim+upper `RESPONSE_CATEGORY` | NA | NA |
| **New lesion flag** | `NEW_LESION ∈ {Y, YES, TRUE, 1}` | `NEWLSN` | "New Lesion" | `"Y"` | NA | NA |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"TR"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | TRSEQ | Sequence Number | Num | 8 | Derived | — | `row_number()` per `USUBJID` after sort `(USUBJID, TRDTC, TRLINKID, TRTESTCD)` |
| 5 | TRTESTCD | Short Name of Measurement | Char | 8 | Derived | TRTESTCD | Per Record Sets table above |
| 6 | TRTEST | Name of Measurement | Char | 40 | Derived | TRTEST | Per Record Sets table above |
| 7 | TRORRES | Result in Original Units | Char | 40 | Derived | — | Per Record Sets table above |
| 8 | TRSTRESC | Standardised Result (character) | Char | 40 | Derived | — | Per Record Sets table above |
| 9 | TRSTRESN | Standardised Result (numeric) | Num | 8 | Derived | — | Per Record Sets table above (NA for OVRLRESP, NEWLSN) |
| 10 | TRSTRESU | Standardised Units | Char | 20 | Derived | UNIT | `"mm"` for LDIAM, NA otherwise |
| 11 | TRDTC | Date of Assessment | Char | 10 | Predecessor | ISO 8601 | `as.character(ASSESSMENT_DATE)` |
| 12 | VISITNUM | Visit Number | Num | 8 | Derived | VISITNUM | Shared VISIT lookup on `VISIT_NAME` |
| 13 | VISIT | Visit Name | Char | 40 | Predecessor | VISIT | `str_to_upper(str_trim(VISIT_NAME))` |
| 14 | TRGRPID | Group ID (TARGET / NON-TARGET / NEW) | Char | 40 | Derived | TRGRPID | See §Derivations.D1 — identical mapping to `TU.TUGRPID` |
| 15 | TRLINKID | Link Identifier (lesion key) | Char | 40 | Predecessor | — | `as.character(LESION_ID)` — joins to `TU.TULINKID` (RELREC Relationship A) |

## Derivations

### D1 — TRGRPID
```r
TRGRPID = case_when(
  str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT")                 ~ "TARGET",
  str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
  TRUE                                                                         ~ str_to_upper(str_trim(LESION_TYPE))
)
```

### D2 — Long-form pivot pseudocode (full)
```r
raw <- raw |> mutate(USUBJID, TRDTC = ASSESSMENT_DATE, TRGRPID = <D1>, TRLINKID = as.character(LESION_ID),
                     new_lesion_flag = str_to_upper(str_trim(NEW_LESION)) %in% c("Y","YES","TRUE","1"))

tr_target    <- raw |> filter(TRGRPID == "TARGET",     !is.na(LONGEST_DIAMETER_MM)) |>
                       mutate(TRTESTCD="LDIAM",    TRTEST="Longest Diameter",
                              TRORRES=as.character(LONGEST_DIAMETER_MM),
                              TRSTRESC=as.character(LONGEST_DIAMETER_MM),
                              TRSTRESN=as.numeric(LONGEST_DIAMETER_MM), TRSTRESU="mm")
tr_nontarget <- raw |> filter(TRGRPID == "NON-TARGET", !is.na(RESPONSE_CATEGORY),
                              str_trim(RESPONSE_CATEGORY) != "") |>
                       mutate(TRTESTCD="OVRLRESP", TRTEST="Overall Response",
                              TRORRES=str_to_upper(str_trim(RESPONSE_CATEGORY)),
                              TRSTRESC=TRORRES, TRSTRESN=NA_real_, TRSTRESU=NA_character_)
tr_newlesion <- raw |> filter(new_lesion_flag) |>
                       mutate(TRTESTCD="NEWLSN",   TRTEST="New Lesion",
                              TRORRES="Y", TRSTRESC="Y", TRSTRESN=NA_real_, TRSTRESU=NA_character_)

tr <- bind_rows(tr_target, tr_nontarget, tr_newlesion) |>
      arrange(USUBJID, TRDTC, TRLINKID, TRTESTCD) |>
      group_by(USUBJID) |> mutate(TRSEQ = row_number()) |> ungroup()
```

## Controlled Terminology

| Variable | CT codelist | Notes |
|---|---|---|
| TRTESTCD | C100945 (TRTESTCD, Oncology) | LDIAM, OVRLRESP, NEWLSN |
| TRTEST | C100946 (TRTEST, Oncology) | "Longest Diameter", "Overall Response", "New Lesion" |
| TRSTRESC (when TRTESTCD = OVRLRESP) | C99158 (NRRESP, lesion-level) | CR / NON-CR-NON-PD / PD / NE |
| TRSTRESU | UNIT (C71620) | `mm` only |
| TRGRPID | Study-specific (RECIST 1.1) | TARGET / NON-TARGET / NEW |
| VISIT, VISITNUM | Shared VISIT lookup | — |

## QC Checks

- [ ] `nrow(tr) ≈ 7,724` (within ±0.1%).
- [ ] `USUBJID` foreign key into `DM`.
- [ ] `TRSEQ` strictly increasing per `USUBJID` with no gaps starting at 1.
- [ ] `TRTESTCD ∈ {LDIAM, OVRLRESP, NEWLSN}` exclusively.
- [ ] When `TRTESTCD == "LDIAM"`: `TRSTRESN > 0` and `TRSTRESU == "mm"`.
- [ ] When `TRTESTCD ∈ {OVRLRESP, NEWLSN}`: `TRSTRESN` is NA and `TRSTRESU` is NA.
- [ ] Every `TRLINKID` exists in `TU.TULINKID` for the same `USUBJID` (RELREC A integrity).
- [ ] `TRDTC` parses as ISO 8601 date.
- [ ] Sort key `(USUBJID, TRDTC, TRLINKID, TRTESTCD)` reproduces row order.
- [ ] Variable labels / lengths / types align with this spec via `xportr::xportr_*()`.

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-TR-spec.md` | `programs/sdtm/tr.R` | `datasets/sdtm/tr.parquet` |

Downstream consumers: `RELREC` (Relationship A `TU↔TR`, Relationship B `RS↔TR` on assessment date), `ADTR` (target-lesion ADaM, `LDIAM` records only), `ADRS` (BoR derivation), `ADTTE` (PFS-INV / PFS-BICR).

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §14 for the consolidated cross-domain pseudocode and §21 for RELREC build.

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft — spec-first, mapped to `programs/sdtm/tr.R`. |
