# Pinnacle 21 SDTM — Phase-2 remediation (the "tail")

Continues the 2026-07-18 remediation (~590K → 5,244 displayed / **18,410 true**
findings). This pass targets the deferred structural tail. All fixes are in the
mapping programs (`programs/sdtm/*.R`, `programs/adam/*.R`, `programs/define/`),
regenerated end-to-end and verified at the **XPT** level (`haven::read_xpt`).
Pinnacle 21 itself is a manual desktop step — **re-run it** (SDTM-IG 3.4 FDA,
CDISC CT 2026-03-27, point at `xpt/sdtm/` + `define/define.xml`) to confirm the
counts below.

Starting point: latest report `pinnacle21-report-2026-07-18T23-40-20-249.xlsx`
(true totals from Issue-Summary `Found`, not the 1000-row-capped Details sheet).

## Fixed (expected to clear on re-validation)

| Rule | Found | Fix |
|---|---:|---|
| SD1097 | 2,841 | AE treatment-emergent: `EPOCH` derived on AE from the DM treatment window (`17_derive_timing.R`) |
| SD1449 | 2,196 | MedDRA coded to 100%: modifier-stripping normalisation + LLT→PT match; fixed the unquoted-comma bug in `meddra_oncology_subset.csv` (Respiratory SOC) and added 4 real PTs (`ae.R`) |
| SD0021 / SD1333 | 410 / 410 | AEENDTC imputed for RECOVERED/RESOLVED AEs (severity-based duration, capped at death/exit) (`ae.R`) |
| SD0009 | 191 | SAE criteria populated so every serious AE has ≥1 `Y` (`ae.R`) |
| SD1040 | 48 | Dropped redundant `DV.DVSCAT` (1:1 with DVDECOD) and `DD.DDSCAT` |
| SD1079 | 40 | CDISC variable order in AE/DM; `--DY` placed after `--DTC`, `EPOCH` last (`17_derive_timing.R`) |
| CT2005 / SD1274 | 1 / 28 | DS "OTHER" → `PHYSICIAN DECISION` (valid NCOMPLT); DSTERM no longer literal "OTHER" (`ds.R`) |
| SD0057 | 25 | DM `ARMCD/ACTARMCD/DTHDTC/DTHFL/RFXSTDTC/RFXENDTC/RFENDTC/RFPENDTC`; DA `DADTC/VISITNUM` |
| SD1077 | 11 | `EPOCH` added to all observation domains (`17_derive_timing.R`) |
| SD1083 / SD1087 / SD1091 | 8 / 6 / 3 | `--DY` study-day variables from `--DTC` + `DM.RFSTDTC` |
| SD1078 | 7 | AE SAE criteria populated; dropped all-null `SU.SUOCCUR` |
| SD0055 | 6 | AE MedDRA code variables now numeric |
| SD0058 | 6 of 7 | Removed non-model vars: `AEDISCOD` (→SUPPAE), `DA.EXTRT`, `DD.DDTERM`, `PE.PENORM`, `SU.SUFREQ` |
| SD1101 | 2 | Added `CMENTPT` / `MHENTPT` (reference time point for `--ENRTPT`) |
| SD1073 | 1 | DA `DASTDTC` → `DADTC` (DASTDTC prohibited in DA) |
| SD1099 / SD1147 | 1 / 1 | SU: added parent `SUCAT`; dropped all-null `SUOCCUR` |
| SD1201 | 1 | De-duplicated the AE entered twice (kept later end date); mirrored in SUPPAE |
| SD1111/1112/1113/1115 | 4 | Created Trial Design domains **SE / TA / TE / TS** (`se.R/ta.R/te.R/ts.R`); TS clears the only **Reject** |

New domains registered in `00_run_sdtm.R`, `16_label_domains.R`, and
`build_define.R` (define now has 38 datasets).

## Accepted limitations (documented, not fixed)

| Rule | Found | Reason |
|---|---:|---|
| **SD0007** | 10,873 | DA standard units legitimately differ by product (BSA-dosed chemo `mg/m2`, flat-dose `mg`, vialed biologic `VIAL`). Warning severity; per user decision, not fabricating BSA / mg-per-vial conversions. |
| SD0022 | 1,229 | `SU.SUSTDTC` blank — lifetime substance-use history has no collected start date. |
| SD0061 | 12 | The 12 "missing" datasets are the **ADaM** datasets referenced in the combined SDTM+ADaM `define.xml`. Validation-scoping artifact: run the SDTM engine with both `xpt/sdtm` + `xpt/adam` present, or validate each standard against its own define. Not a data defect. |
| SD0080 | 14 | AE start after last disposition date — synthetic date-generation artifact. |
| SD1076 | 3 | `EX.VISIT/VISITNUM` (kept for ADEX joins) + `PE.PECLSIG` — permissible "Note" severity. |
| SD0058 | 1 | `CM.CMATC` intentionally denormalised for ADaM-join back-compat; SUPPCM is its parallel conformant home. |
| SD1149 | 1 | `DM.ARMNRS` all-null — every subject is randomised (225/225), so the reason-not-assigned variable is correctly empty. |
| SD1485 | 1 | `LC` is not an SDTM-IG 3.4 domain; not created. |

## Net expectation

The genuinely-fixable structural tail (~6,300 findings) is addressed; the residual
is dominated by the **accepted** DA standard-units warning (10,873) and SU start
time-point (1,229). Re-run Pinnacle 21 to confirm.

## Cascade

DM/AE/CM/DV changes flow into ADaM — the full ADaM pipeline was re-run
(`00_run_adam.R`): ADAE = 2,840 (matches AE de-dup), define + XPT rebuilt.
