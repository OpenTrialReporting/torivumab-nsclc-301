# Pinnacle 21 SDTM — Phase-2 remediation (the "tail")

Continues the 2026-07-18 remediation. This pass cleared the deferred structural
tail and — once the Community **CLI** was wired up (`qc/run_p21.sh`) — was
iterated against real validator output rather than expectations.

**Validated SDTM result: 18,410 → 10,981 → 10,891 findings** (engine 2508.1,
SDTM-IG 3.4 FDA, CDISC CT 2026-03-27; the last step is the Phase-3 cleanup
below). Of the 10,891, **10,873 are the accepted SD0007** DA standard-units
warning; the remaining **18 are low-severity** and every one is an accepted,
documented limitation.

Re-run any time with: `qc/run_p21.sh sdtm --build`

## Cleared (confirmed by CLI re-validation)

| Rule | Was | Fix |
|---|---:|---|
| SD1097 | 2,841 | Treatment-emergent flag `AETRTEM` added to **SUPPAE** (the FDA business rule P21 checks — EPOCH alone did not satisfy it) |
| SD1449 | 2,196 | AE MedDRA coded to 100%: modifier-stripping normalisation + LLT→PT match; fixed the unquoted-comma bug in the dictionary (Respiratory SOC → also fixed non-numeric codes / SD0055) + 4 real PTs |
| SD0022 | 1,229 | Dropped the all-null `SU.SUSTDTC` (lifetime substance-use history has no start date) — removed the start-time-point findings entirely |
| SD1135 | 636 | Negative EX study days: `RFSTDTC = min(randomisation, first dose)` so a dose given the day before randomisation is day 1, not −1 |
| SD0021 / SD1333 | 410 / 410 | `AEENDTC` imputed for RECOVERED/RESOLVED AEs (severity-based duration, capped at death/exit) |
| SD0009 | 191 | SAE criteria populated so every serious AE has ≥1 `Y` |
| CT2001 | 138 | `DM.DTHFL` set to Y/null only (never N — "Yes only" codelist) |
| SD1132 | 60 | `AESER` promoted to Y when a death/life-threatening criterion is Y |
| SD1040 | 48 | Dropped redundant `DV.DVSCAT` (1:1 with DVDECOD) and `DD.DDSCAT` |
| SD2xxx / CT2002 / CT2003 | ~30 | Completed the FDA-required TS parameter set with exact CDISC decodes (incl. the SD2232 SSTDTC **Reject**, INTMODEL/INTTYPE/PCLAS) |
| CT2005 / SD1274 | 1 / 28 | DS "OTHER" → `PHYSICIAN DECISION` (valid NCOMPLT) |
| SD1111/1112/1113/1115 | 4 | Trial Design domains **SE / TA / TE / TS** created (TS clears the only Reject) |
| SD1077 / SD1083 / SD1087 / SD1091 | ~30 | `EPOCH` + `--DY` study-day variables across all domains |
| SD0055, SD1073, SD1078, SD1099, SD1101, SD1147, SD1201, SD0057(part) | ~30 | Numeric MedDRA codes, DA `DASTDTC→DADTC`, dropped all-null permissibles, SU `SUCAT`, `CM/MH --ENTPT`, AE de-dup, DM expected reference vars |

## Phase 3 (2026-07-19) — structural cleanup A–E

A further pass drove the low-severity tail down and split the define per standard.
**SDTM 10,981 → 10,891 · ADaM 10,931 → 10,890.** Every remaining non-SD0007
finding is now an accepted, documented limitation (9 SDTM rules / 8 ADaM rules).

| # | Fix | Rules cleared |
|---|---|---|
| — | Variable order → SDTMIG 3.4 sequence (`16_label_domains.R` `SDTM_ORDER`) | **SD1079** 32→0 |
| B | AE/CM dates clamped inside the participation window at the raw layer (exit-date cap in `04_adverse_events.R`; subsequent-therapy start capped at last contact in `16_subsequent_therapy.R`). RNG-neutral (clamps results, not `sample()` args) so the diff is surgical | **SD0080** 14→0, **SD1202** 17→0, **SD1204** 6→0 |
| C | Added Expected variables `EX.EXDOSFRM`, `LB.LBORNRLO/HI` (character), `LB.LBLOBXFL`, `PE.PESTRESC`, `TR.TRORRESU/TRMETHOD/TREVAL/TRLOBXFL` | **SD0057** 17→8 |
| D | Define split per standard: `define/sdtm/define.xml` (SDTM-only) for the SDTM run; combined `define/define.xml` for the ADaM run. `run_p21.sh` points each run at its own | **SD0061** 12→0 |

Rejected on evidence: modelling the never-dosed subject 0277 as *ASSIGNED, NOT
TREATED* (nulling ACTARM) — it removed SD0070/SD1343/SD1149 but introduced
SD1366/SD1373/SD1375/SD2237 **and ADaM AD1011×60**, a net loss, so 0277 is kept
as randomised-untreated and those three findings stay accepted. Populating
`TS.TSVALCD/TSVCDREF` was likewise reverted — it triggered SD2240–SD2266
(per-parameter reference-code checks) that cannot be satisfied for a synthetic
investigational product (no real UNII/SNOMED codes).

## Residual (18, low-severity) — accepted / documented

**SDTM 10,891 across 9 rules · ADaM 10,890 across 8 rules** (engine 2508.1).

| Rule | Found | Disposition |
|---|---:|---|
| **SD0007** | 10,873 | **Accepted** — DA standard units legitimately differ by product (mg/m² BSA chemo, mg flat dose, VIAL biologic). Warning; no fabricated conversions. |
| SD0057 | 8 | Expected (not Required) variables absent (`DM.ACTARMUD`, `TS.TSVALCD/TSVCDREF`, …). Adding them only trades for SD1149 / SD2240-series. |
| SD1076 | 3 | `EX.VISIT/VISITNUM` (kept for ADEX joins) + `PE.PECLSIG` — permissible Note severity. |
| SD0058 | 2 | `CM.CMATC` + `SU.SUPACKYR` — documented sponsor extensions (conformant home SUPPCM/SUPPSU). |
| SD0070 / SD1343 | 1 / 1 | The one randomised-but-never-dosed subject (0277, died 4 days after screening). |
| SD1149 | 1 | `DM.ARMNRS` correctly all-null (everyone randomised). |
| SD1299 | 1 | SU has no timing variable — acceptable for undated lifetime history. |
| SD1485 | 1 | `LC` is not an SDTM-IG 3.4 domain (SDTM run only). |

### Annotated in the define (def:CommentDef)

The accepted limitations that have a natural home are documented in `define.xml`
itself, generated by `programs/define/build_define.R` (a `def:CommentDef`
referenced via `def:CommentOID` on the relevant variable or dataset — survives
rebuild, P21-verified well-formed):

| Rule(s) | Comment OID | Attached to |
|---|---|---|
| SD0007 | `COM.DA.UNITS` | `DA.DASTRESU`, `DA.DAORRESU` |
| SD0058 | `COM.CM.ATC` / `COM.SU.PACKYR` | `CM.CMATC` / `SU.SUPACKYR` |
| SD1076 | `COM.EX.VISIT` / `COM.PE.CLSIG` | `EX.VISIT`, `EX.VISITNUM` / `PE.PECLSIG` |
| SD1149 | `COM.DM.ARMNRS` | `DM.ARMNRS` |
| SD0070 / SD1343 | `COM.DM.UNDOSED` | `DM.RFXSTDTC` |
| SD1299 | `COM.SU.NOTIMING` | `SU` dataset (ItemGroupDef) |
| SD1485 | `COM.LB.NOLC` | `LB` dataset (ItemGroupDef) |

Two items have no natural define home and are documented only here: **SD0057**
(Expected variables that are absent — nothing to annotate) and the residual
**SD0007** count. The comments document the findings for reviewers; they do
**not** suppress them — every rule above is still reported by Pinnacle 21. The
former `COM.AE.DATES` annotation was retired: those date findings (SD0080/SD1202/
SD1204) are now genuinely fixed at the raw layer, not merely accepted.

## Tooling

`qc/run_p21.sh [sdtm|adam|both] [--build]` drives the bundled Community CLI
head-less; `qc/p21_summary.R` prints true per-rule Found totals. Reports land in
`qc/p21-reports/pinnacle21-cli-<stamp>-<std>.xlsx`.

**ADaM run — SD1005 handled.** When SDTM is loaded as supporting data inside an
ADaM run, the SDTM cross-domain check `SD1005 Invalid STUDYID` (STUDYID must
match DM) misfires and flags every non-DM SDTM record (~540K) even though the
STUDYID is a valid constant that the standalone SDTM run passes cleanly.
`run_p21.sh` works around this by temporarily deactivating SD1005 in the SDTM
sub-config for the ADaM run only (restored immediately via a trap; the rule stays
active for the SDTM run). ADaM result: **552,388 → 10,890 findings** — dominated
by the accepted SD0007 linked-SDTM warning, with the ADaM datasets themselves
essentially clean (no AD-rule findings). Traceability (ADSL↔DM etc.) still runs.
The ADaM run uses the combined `define/define.xml` (both standards present, so no
SD0061); the SDTM run uses the SDTM-only `define/sdtm/define.xml`.

## Cascade

DM `RFSTDTC` = min(randomisation, first dose), which shifts study-day math in
ADaM — the full ADaM pipeline is re-run after any SDTM change (ADAE = 2,840). The
Phase-3 AE/CM date clamps were made RNG-neutral (clamping sampled *results*, not
the `sample()` arguments — R's post-3.6 rejection sampler consumes a variable
number of draws per call), so regenerating raw touched only `adverse_events.csv`
and `conmed.csv`, not the whole simulated dataset.
