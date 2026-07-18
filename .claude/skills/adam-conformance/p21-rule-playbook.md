# ADaM Pinnacle 21 rule → fix playbook

Every entry was fixed in the 2026-07-18 remediation. Format:
**RULE** — message → root cause → fix (file).

## Analysis-visit timing

- **SD0051-equivalent / missing AVISIT** — BDS analysed by visit needs `AVISIT`/`AVISITN`.
  ADLB/ADEX/ADRS/ADTR lacked them; ADVS had `AVISITN` null for maintenance visits. Define
  the scheme once (`_visit_utils.R::derive_avisitn`), apply in all 5 BDS programs. Keep
  `VISIT`/`VISITNUM` where populated (traceability); drop VISITNUM where 100% null.
- **AD0046** ADY/ASTDY/AENDY = 0 — no day-0 convention. Use `_adam_utils.R::study_day`
  across all 10 sites (adae/adcm/adds/addv/adex/adlb/admh/adrs/adtr/advs).

## Baseline

- **AD0154** multiple baseline records per USUBJID/PARAMCD/BASETYPE — flag exactly one
  pre-treatment baseline. ADVS used a naïve `if_else` over all screening/C1D1 rows → many
  Y; fix to the last non-missing pre-treatment record (`advs.R`). ADTR: restrict ABLFL to
  the SDIAM analysis parameter, not per-lesion LDIAM.
- **AD0152** ABLFL='Y' but BASE≠AVAL — set BASE to the flagged record's AVAL (same fix as
  AD0154 for ADVS).

## Parameters, flags, values

- **AD0141** inconsistent PARAM within a PARAMCD — make PARAM generic per PARAMCD; ADEX
  CUMDOSE/RDI carried the drug name in PARAM → move drug to AEXTRT (`adex.R`).
- **AD0196** required PARAMCD null — ADLB inherited null LBTESTCD from SDTM (Sodium's raw
  test code was "NA", parsed as missing). Recover `SODIUM` at the SDTM LB source (`lb.R`).
- **AD0269** flag value not Y or null — TRTEMFL (adae) / ONTRTFL (adcm) used "N"; these are
  Y-only flags → Y or `NA_character_`.
- **AD0252** variable prohibited in ADaM — `AVAL` present in OCCDS ADAE/ADCM → remove it
  (grade stays in AETOXGRN).
- **AD0245** CNSR present but STARTDT not — ADTTE needs `STARTDT` (time-to-event origin;
  TRTSDT, or RSPDT for DOR). The value was already computed as `START_DT`; rename + select.
- **AD0047** required MedDRA hierarchy code vars absent — add AEPTCD/AEBDSYCD/AESOCCD/
  AEHLGT/AEHLGTCD/AEHLTCD/AELLTCD to SDTM AE (from the MedDRA subset match index) and carry
  into ADAE (`ae.R`, `adae.R`, labels in both label programs). Note: uncoded AEs get null
  codes → surfaces SD1449 (coverage), a separate Phase-2 item.

## Metadata (define.xml / labels / names)

- **SD1152** duplicate records per define key vars — the define key set must uniquely
  identify rows. Fix in `build_define.R` DOMAIN_META: ADTR += LNKID, ADEX += NCYCLE.
- **SD0059** define/dataset type mismatch — numeric ADaM date vars (R `Date`) declared
  `"date"` in define but stored numeric in XPT → `infer_datatype` returns `"integer"` for
  Date/POSIXt (`build_define.R`).
- **AD0018** label mismatch vs ADaM standard — force the exact CDISC label via the STANDARD
  map in `label_adam.R`. Read the expected string from the P21 config (do not guess):
  SUBJID="Subject Identifier for the Study", ITTFL="Intent-To-Treat Population Flag",
  TRT01P[N]/TRT01A[N]="…for Period 01[ (N)]", TRTSDT/EDT="Date of First/Last Exposure to
  Treatment", ASTDY/AENDY="Analysis Start/End Relative Day", AVALC="Analysis Value (C)",
  PARAMN="Parameter (N)", BASE="Baseline Value", ONTRTFL="On Treatment Record Flag",
  CMTRT="Reported Name of Drug, Med, or Therapy", AESTDTC/AEENDTC="Start/End Date/Time of
  Adverse Event", LSTALVDT="Date Last Known Alive", STARTDT="Time-to-Event Origin Date for
  Subject".
- **SD1324** define label ≠ dataset label — labels >40 chars truncate differently; truncate
  in `build_define.R` to match XPT; strip markdown that leaks into spec labels (IRAEFL).
- **SD0054/SD0060** name mismatch — >8-char var truncated in XPT (PCANCERFL→PCANCFL).

## Validation-setup artifacts (not data defects)

- **SD0061** (define references missing datasets) and **AD1024/25/26** (traceability
  skipped for missing DM/AE/EX): caused by validating ADaM **without** the SDTM datasets
  present. Validate ADaM + SDTM together → these go to 0.

## Deferred to Phase-2

- **SD1449** improve AE MedDRA coverage (verbatim terms with grade/word-order modifiers
  don't match the 73-term subset) so uncoded AEs stop having partial hierarchy population.
