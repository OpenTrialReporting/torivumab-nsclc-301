# SDTM Pinnacle 21 rule → fix playbook

Every entry below was fixed in the 2026-07-18 remediation. Format:
**RULE** — message → root cause → fix (file).

## Controlled terminology (verify each value in the CDISC CT ODM first)

- **CT2001** value not in *non-extensible* codelist:
  - `DM.SEX` MALE/FEMALE → **M/F** (`dm.R`).
  - `AE.AEACN` "NONE" → **DOSE NOT CHANGED** (`ae.R map_acn`).
  - `AE.AESEV` "LIFE-THREATENING" → **SEVERE** (3-point scale). Compute `AETOXGR` (grade
    4/5) *before* collapsing AESEV in the same `mutate` so grade is preserved (`ae.R`).
- **CT2002** value not in *extensible* codelist:
  - Units: `MG`→`mg`, `MG/M2`→`mg/m2`, keep `VIAL` **UPPERCASE** (`da.R`, `ex.R`). Do NOT
    lowercase VIAL — it is the valid CDISC UNIT value.
  - `LB.LBTEST` → CDISC names keyed by LBTESTCD (HGB→Hemoglobin, WBC→Leukocytes,
    BILI→Bilirubin, ALT→"Alanine Aminotransferase"…) (`lb.R`).
  - `DA.DATEST`/`DATESTCD`: names → CDISC decodes ("Dispensed Amount", not "Amount
    Dispensed"); drop **USEDAMT** (not a CDISC DA test code) (`da.R`).
  - `TU.TULOC` → CDISC *Anatomical Location* terms (BONE-PELVIS→PELVIC BONE, LEFT
    LUNG→LUNG, LEFT LOWER LOBE→"LUNG, LEFT LOWER LOBE", LYMPH NODE-AXILLARY→AXILLARY
    LYMPH NODE, PLEURAL EFFUSION→PLEURA, PERICARDIAL EFFUSION→PERICARDIUM) (`tu.R`).
  - `DD.DDTESTCD`/`DDTEST` "DEATH"/"Death" → **PRCDTH** / "Primary Cause of Death" (`dd.R`).
  - `TR.TRTESTCD` OVRLRESP/NEWLSN are not Tumor-Result tests → remove those record sets;
    keep only LDIAM. Overall response lives in RS (`tr.R`). Regenerate RELREC after.
- **CT2003** --TESTCD/--TEST pair mismatch: fix by setting --TEST to the exact CT Decode
  of --TESTCD (LB and DA above resolve this).
- **CT2005** DS codelists: `DS.DSSCAT` "STUDY DISCONTINUATION" → **STUDY PARTICIPATION**
  (valid values: STUDY PARTICIPATION / STUDY TREATMENT) (`ds.R`).
- **SD1322** `DM.COUNTRY` full name → ISO-3166 alpha-3 / GENC (AUSTRALIA→AUS, UNITED
  STATES→USA, GERMANY→DEU, SOUTH KOREA→KOR…) (`dm.R`).

## Structural / timing

- **SD0051** inconsistent VISIT within VISITNUM: assign a **complete, unique** VISITNUM for
  every visit so VISIT↔VISITNUM is a bijection *within each domain*. Extend `get_visitnum`
  (shared across lb/pe/rs/tr/tu/vs): SCREENING/BASELINE=0, induction C1D1..C6D1=1..7,
  `MAINT_CnD1`=9+n, `*_ASSESS_WKn`=week#, EOT/FU=900/901/902 (above the week range so
  MAINT_ASSESS_WK99 doesn't collide with EOT). Use prefix/suffix `sub()` not backreferences.
- **SD1022** invalid QNAM: QNAM must be ≤8 chars — `CENTRALFL`(9)→`CENTLBFL` (`supplb.R`).
- **SD1066/SD1067/SD1026** RELREC RELTYPE populated with USUBJID/IDVARVAL: RELREC has two
  mutually-exclusive forms. Record-level (RELID + USUBJID/IDVARVAL) must have RELTYPE
  **blank**; dataset-level (RELTYPE ONE/MANY) has USUBJID/IDVARVAL blank. These lesion/
  response links are record-level → set RELTYPE null but keep the column (`relrec.R`).
- **SD0057** expected variable not found: e.g. RELREC RELTYPE must be *present* (blank ok);
  `TRLNKID`/`TULNKID` are the CDISC names — rename `TRLINKID`/`TULINKID` everywhere
  (tr/tu/relrec/adtr/labels). Remaining (DM ARMCD/ACTARMCD/DTHFL/DTHDTC/RF*DTC, LB
  LBLOBXFL/LBORNR*, EX EXDOSFRM, DS DSSTDY, EPOCH) need real derivations — Phase-2.
- **SD0058** variable not in SDTM model: `TRLINKID`/`TULINKID` (rename fixes); `AEDISCOD`/
  `CMATC`/`SUPACKYR`/`PENORM` are non-standard → move to SUPP-- (Phase-2).
- **SD0075** invalid IDVAR: IDVAR must name a variable that exists in the referenced domain.
  Caused here by RELREC IDVAR="TRLNKID" while stale TR still had TRLINKID — a
  regenerate-and-verify-at-XPT discipline failure, not a code bug.
- **SD0054 / SD0060** define↔dataset name mismatch: a >8-char name truncated in XPT
  (PCANCERFL→PCANCFL, SUPACKYRS→SUPACKYR).

## Content

- **SD1249** EXDOSE≠0 when EXTRT='PLACEBO': set `EXDOSE=0` for placebo (`ex.R`); cascades to
  ADEX (placebo dose amount 0 — acceptable).
- **SD1448** RSSTRESN populated when RSSTRESC non-numeric: a categorical RECIST response
  has no numeric result — drop `RS.RSSTRESN` (`rs.R`); derive ADRS `AVAL` from the response
  code instead (`adrs.R`).
- **SD1039** SUCAT redundant with SUTRT: drop `SU.SUCAT` from output (`su.R`).

## Deferred to Phase-2 (need a modeling decision, not a value swap)

- **SD0007** DA mixed standard units (mg/m2 vs VIAL for the same test across drugs).
- **SD1097 / SD1077** treatment-emergent / EPOCH: need `DM.RFXSTDTC`/`RFXENDTC` derived
  from EX (DM runs before EX in the pipeline → needs a raw-dosing read or a post-EX pass),
  then epoch boundaries.
- **SD1449** AE MedDRA coverage (only ~23% of verbatim terms match the 73-term subset;
  uncoded AEs have verbatim AEDECOD + null hierarchy → partial-population flag).
- **SD0022 / SD0021 / SD1333** SU/AE time-points; **SD0009** AE serious-criterion qualifier;
  **SD0080** AE after disposition; **SD1040** DVSCAT/DDSCAT redundant; **SD1079** variable
  order; **SD1274** DSTERM='OTHER'; **SD0055** MedDRA-code var type (Num vs Char).
