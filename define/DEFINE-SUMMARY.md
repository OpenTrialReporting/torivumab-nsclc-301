# Define-XML v2.1 — Inventory

**Study:** SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
**Generated:** 2026-07-19
**File:** `define/define.xml`
**Datasets:** 38  ·  **Variables:** 699

## Datasets

| Dataset | Class | Records | Variables | Structure |
|---------|-------|--------:|----------:|-----------|
| AE | EVENTS | 2,840 | 35 | One record per subject per adverse event |
| CM | INTERVENTIONS | 2,330 | 17 | One record per subject per medication per occurrence |
| DA | INTERVENTIONS | 18,463 | 17 | One record per subject per accountability measure per drug per visit |
| DD | EVENTS | 312 | 11 | One record per subject per death detail |
| DM | SPECIAL PURPOSE | 450 | 26 | One record per subject |
| DS | EVENTS | 1,350 | 11 | One record per subject per disposition event |
| DV | EVENTS | 337 | 10 | One record per subject per protocol deviation |
| EX | INTERVENTIONS | 13,403 | 15 | One record per subject per administration |
| LB | FINDINGS | 122,601 | 21 | One record per subject per lab test per visit |
| MH | EVENTS | 2,061 | 13 | One record per subject per medical history event |
| PE | FINDINGS | 25,596 | 13 | One record per subject per body system per visit |
| RELREC | RELATIONSHIP | 12,831 | 7 | One record per related record |
| RS | FINDINGS | 5,338 | 15 | One record per subject per assessment per visit |
| SE | SPECIAL PURPOSE | 1,348 | 12 | One record per subject per actual element |
| SU | INTERVENTIONS | 1,229 | 8 | One record per subject per substance use occurrence |
| SUPPAE | RELATIONSHIP | 11,360 | 10 | One record per parent record per qualifier |
| SUPPCM | RELATIONSHIP | 4,527 | 10 | One record per parent record per qualifier |
| SUPPDM | RELATIONSHIP | 1,799 | 10 | One record per subject per qualifier |
| SUPPLB | RELATIONSHIP | 245,202 | 10 | One record per parent record per qualifier |
| SUPPSU | RELATIONSHIP | 450 | 10 | One record per parent record per qualifier |
| TA | TRIAL DESIGN | 6 | 10 | One record per planned element per arm |
| TE | TRIAL DESIGN | 3 | 7 | One record per planned element |
| TR | FINDINGS | 6,136 | 17 | One record per subject per lesion per measurement per visit |
| TS | TRIAL DESIGN | 59 | 6 | One record per trial summary parameter value |
| TU | FINDINGS | 9,012 | 16 | One record per subject per lesion per visit (tumor identification) |
| VS | FINDINGS | 52,864 | 16 | One record per subject per vital sign measurement per visit |
| ADAE | OCCURRENCE DATA STRUCTURE | 2,840 | 51 | One record per subject per adverse event |
| ADCM | OCCURRENCE DATA STRUCTURE | 2,330 | 30 | One record per subject per concomitant medication occurrence |
| ADDS | OCCURRENCE DATA STRUCTURE | 1,350 | 24 | One record per subject per disposition event |
| ADDV | OCCURRENCE DATA STRUCTURE | 337 | 23 | One record per subject per protocol deviation |
| ADEX | BASIC DATA STRUCTURE | 16,097 | 27 | One record per subject per drug per administration or summary parameter |
| ADLB | BASIC DATA STRUCTURE | 122,601 | 37 | One record per subject per parameter per analysis visit |
| ADMH | OCCURRENCE DATA STRUCTURE | 2,061 | 23 | One record per subject per medical history condition |
| ADRS | BASIC DATA STRUCTURE | 3,569 | 21 | One record per subject per parameter per analysis visit |
| ADSL | SUBJECT LEVEL ANALYSIS DATASET | 450 | 33 | One record per subject |
| ADTR | BASIC DATA STRUCTURE | 9,255 | 27 | One record per subject per parameter per analysis visit per lesion |
| ADTTE | BASIC DATA STRUCTURE | 2,377 | 20 | One record per subject per time-to-event parameter |
| ADVS | BASIC DATA STRUCTURE | 52,864 | 30 | One record per subject per vital-sign parameter per analysis visit |

## Standards

- SDTMIG v3.4 (Final)
- ADaMIG v1.3 (Final)
- CDISC/NCI CT 2024-03-29 (SDTM + ADaM)

## Accepted-limitation annotations (def:CommentDef)

Accepted Pinnacle 21 findings that have a natural home are documented in
`define.xml` via a `def:CommentDef` referenced from the variable/dataset below
(the comment documents the finding; it does not suppress it).

| Comment OID | Finding(s) | Attached to |
|-------------|-----------|-------------|
| `COM.DA.UNITS` | SD0007 | `DA.DASTRESU`, `DA.DAORRESU` |
| `COM.CM.ATC` | SD0058 | `CM.CMATC` |
| `COM.SU.PACKYR` | SD0058 | `SU.SUPACKYR` |
| `COM.EX.VISIT` | SD1076 | `EX.VISIT`, `EX.VISITNUM` |
| `COM.PE.CLSIG` | SD1076 | `PE.PECLSIG` |
| `COM.DM.ARMNRS` | SD1149 | `DM.ARMNRS` |
| `COM.DM.UNDOSED` | SD0070, SD1343 | `DM.RFXSTDTC` |
| `COM.AE.DATES` | SD0080, SD1202, SD1204 | `AE.AESTDTC`, `AE.AEENDTC` |
| `COM.SU.NOTIMING` | SD1299 | `SU (dataset)` |

## Known limitations (v0.1)

- Codelist references stubbed; Value-Level Metadata not yet emitted.
- MethodDefs limited to inferred origin tags (Collected / Assigned / Derived).
- WhereClauseDefs not yet emitted (typical for ADTTE PARAMCD-based VLM).
- ItemDef OIDs are domain-scoped (e.g. `IT.DM.STUDYID`); the SHARED ItemDef
  pattern is deferred to a future iteration.

