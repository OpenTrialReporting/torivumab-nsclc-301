# VS — Vital Signs — SDTM Programming Specification

## Header

| Field | Value |
|---|---|
| **Domain** | VS |
| **Label** | Vital Signs |
| **Class** | FINDINGS |
| **Structure** | One record per vital-sign parameter per visit per subject |
| **Expected N** | 52,920 |
| **Key variables** | `STUDYID`, `USUBJID`, `VSSEQ` |
| **SDTMIG version** | v3.4 (§7.2) |
| **Spec version** | 0.1 DRAFT |
| **Spec author** | Lovemore Gakava |
| **Date** | 2026-05-17 |

## Purpose

VS captures the seven vital-sign parameters (systolic BP, diastolic BP, heart rate, weight, height, temperature, respiratory rate) measured at scheduled visits. The raw CRF stores values wide (one column per parameter); the SDTM mapper pivots long so each parameter is its own row. Downstream consumers: ADVS (BASETYPE, ANRIND), T-VS-01 (mean by visit), safety narratives that reference vital-sign trends.

## Source (Raw / Input)

| Input | Source | Purpose |
|---|---|---|
| `raw/vital_signs.csv` | CDASH VS form | One row per (subject, visit) wide — `SYSTOLIC_BP`, `DIASTOLIC_BP`, `HEART_RATE`, `WEIGHT_KG`, `HEIGHT_CM`, `TEMPERATURE_C`, `RESP_RATE` |

## Variables

| # | Variable | Label | Type | Length | Origin | Codelist | Derivation |
|---|---|---|---|---|---|---|---|
| 1 | STUDYID | Study Identifier | Char | 20 | Assigned | — | Constant `"CTX-NSCLC-301"` |
| 2 | DOMAIN | Domain Abbreviation | Char | 2 | Assigned | — | Constant `"VS"` |
| 3 | USUBJID | Unique Subject Identifier | Char | 40 | Derived | — | `paste(STUDYID, SUBJECT_ID, sep="-")` |
| 4 | VSSEQ | Sequence Number | Num | 8 | Derived | — | Per-USUBJID `row_number()` after sort `(USUBJID, VSDTC, VSTESTCD)` |
| 5 | VSTESTCD | Vital Signs Test Short Name | Char | 8 | Derived | VSTESTCD | per §Derivations.D1 (parameter metadata) |
| 6 | VSTEST | Vital Signs Test Name | Char | 40 | Derived | VSTEST | per §Derivations.D1 |
| 7 | VSORRES | Result or Finding in Original Units | Char | 40 | CRF | — | `as.character(raw_value)` |
| 8 | VSORRESU | Original Units | Char | 20 | Derived | UNIT | per §Derivations.D1 |
| 9 | VSSTRESC | Character Result/Finding in Std Format | Char | 40 | CRF | — | `as.character(raw_value)` |
| 10 | VSSTRESN | Numeric Result/Finding in Std Units | Num | 8 | Derived | — | `suppressWarnings(as.numeric(raw_value))` |
| 11 | VSSTRESU | Standard Units | Char | 20 | Derived | UNIT | per §Derivations.D1 (same as VSORRESU — no conversion) |
| 12 | EPOCH | Epoch | Char | 20 | Derived | EPOCH | Trial epoch from the treatment window (`17_derive_timing.R`): `SCREENING` before first dose, `TREATMENT` from first dose through last-dose day (inclusive), `FOLLOW-UP` after; assigned from `VSDTC` vs `DM.RFXSTDTC`/`RFXENDTC`; NA when `VSDTC` missing/partial |
| 13 | VSDTC | Date/Time of Measurements | Char | 10 | CRF | — | `VISIT_DATE` (ISO 8601, direct) |
| 14 | VSDY | Study Day of Measurements | Num | 8 | Derived | — | Study day of `VSDTC` vs `DM.RFSTDTC`: `VSDTC − RFSTDTC + 1` on/after RFSTDTC, else `VSDTC − RFSTDTC` (no day 0); NA if missing/partial (`17_derive_timing.R`) |
| 15 | VISITNUM | Visit Number | Num | 8 | Derived | — | per shared VISIT lookup (§Derivations.D2) |
| 16 | VISIT | Visit Name | Char | 40 | CRF | — | `str_to_upper(str_trim(VISIT_NAME))` |

## Derivations

### D1 — Parameter pivot (wide → long)

**Parameter metadata table:**

| Raw column | VSTESTCD | VSTEST | VSORRESU = VSSTRESU |
|---|---|---|---|
| SYSTOLIC_BP | SYSBP | Systolic Blood Pressure | mmHg |
| DIASTOLIC_BP | DIABP | Diastolic Blood Pressure | mmHg |
| HEART_RATE | HR | Heart Rate | beats/min |
| WEIGHT_KG | WEIGHT | Weight | kg |
| HEIGHT_CM | HEIGHT | Height | cm |
| TEMPERATURE_C | TEMP | Temperature | C |
| RESP_RATE | RESP | Respiratory Rate | breaths/min |

**Pivot logic:**
```
1. pivot raw wide -> long: one row per (USUBJID, VISIT_NAME, VISIT_DATE, col_name)
2. drop rows where raw_value is NA or empty string
3. join parameter metadata to populate VSTESTCD / VSTEST / VSORRESU / VSSTRESU
4. populate VSORRES / VSSTRESC / VSSTRESN
5. sort + sequence
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` §11.1-§11.3 for the full pivot spec.

### D2 — VISIT lookup (shared with LB, PE, TU, TR, RS)

```
visit_map = {
   "SCREENING": 0, "SCR": 0,
   "C1D1": 1, "C1D15": 2, "C2D1": 3, "C3D1": 4, "C4D1": 5,
   "C5D1": 6, "C6D1": 7, "C7D1": 8, "C8D1": 9,
   "EOT": 900, "END OF TREATMENT": 900,
   "FU1": 901, "FU2": 902, "FOLLOW-UP 1": 901, "FOLLOW-UP 2": 902
}
VISITNUM = visit_map[str_to_upper(str_trim(VISIT_NAME))]
# label-derived where not in visit_map (unique per VISIT -> P21 SD0051 bijection):
#   BASELINE            -> 0
#   MAINT_CnD1          -> 9 + n
#   TUMOR_ASSESS_WKn    -> n
#   UNSCHEDULED         -> 998   (single UNSCHEDULED<->998 mapping; an off-schedule
#                                 safety recheck of an abnormal on-treatment value)
```

See `programs/sdtm/SDTM-MAPPING-SPEC.md` "Shared VISIT lookup" block.

## Controlled Terminology

| SDTM variable | Codelist | Source |
|---|---|---|
| VSTESTCD | VSTESTCD (C66741) | CDISC CT 2024-03 — values used: `SYSBP`, `DIABP`, `HR`, `WEIGHT`, `HEIGHT`, `TEMP`, `RESP` |
| VSTEST | VSTEST (C67153) | CDISC CT 2024-03 |
| VSORRESU / VSSTRESU | UNIT (C71620) | CDISC CT 2024-03 — `mmHg`, `beats/min`, `kg`, `cm`, `C`, `breaths/min` |
| VISIT | Sponsor visit codelist | Shared with EX, LB, PE, TU, TR, RS |

## QC Checks

- [ ] `nrow(vs) == 52920` (±0.1%)
- [ ] All `USUBJID ∈ DM.USUBJID`
- [ ] `VSSEQ` strictly increasing per `USUBJID` with no gaps
- [ ] No duplicate keys `(USUBJID, VSSEQ)`
- [ ] No duplicate `(USUBJID, VSDTC, VSTESTCD)` triples (one measurement per parameter per visit)
- [ ] `VSDTC` non-missing and ISO 8601 for all rows
- [ ] `VSTESTCD ∈ {SYSBP, DIABP, HR, WEIGHT, HEIGHT, TEMP, RESP}` — no other values
- [ ] `VSORRESU == VSSTRESU` for all rows (no unit conversion at SDTM layer)
- [ ] `VSSTRESN` non-NA where `VSSTRESC` parses as numeric
- [ ] Plausibility ranges (physiologic sanity): `SYSBP ∈ [60,260]`, `DIABP ∈ [30,160]`, `HR ∈ [30,200]`, `WEIGHT ∈ [30,250]`, `HEIGHT ∈ [120,220]`, `TEMP ∈ [33,42]`, `RESP ∈ [6,40]`
- [ ] `VISITNUM` non-missing for ≥99% of rows
- [ ] Variable lengths/labels conform via `xportr::xportr_length()` + `xportr::xportr_label()`

## Traceability

| Spec | Code | Output |
|---|---|---|
| `programming-specs/SDTM-VS-spec.md` | `programs/sdtm/vs.R` | `datasets/sdtm/vs.parquet` |

## Change Log

| Version | Date | Author | Change |
|---|---|---|---|
| 0.1 | 2026-05-17 | Lovemore Gakava | Initial draft. |
| 0.2 | 2026-07-24 | LG (w/ Claude Opus 4.8 1M) | Refresh to current pipeline: Expected N 46,095 → 52,920 (unscheduled safety rechecks now generated raw-first). Corrected the stale D2 VISIT lookup to match `vs.R`: EOT/END OF TREATMENT → 900, FU1/FU2 → 901/902, plus the label-derived `BASELINE→0`, `MAINT_CnD1→9+n`, `TUMOR_ASSESS_WKn→n`, and `UNSCHEDULED→998` bijection (P21 SD0051). |
| 0.3 | 2026-07-25 | LG (w/ Claude Opus 4.8 1M) | Added the cross-domain timing variables `EPOCH` and `VSDY` to the variable table (derived in `17_derive_timing.R`) at their real column positions to match `datasets/sdtm/vs.parquet`. |
