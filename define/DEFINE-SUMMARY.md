# Define-XML v2.1 — Inventory

**Study:** SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
**Generated:** 2026-07-18
**File:** `define/define.xml`
**Datasets:** 34  ·  **Variables:** 633

## Datasets

| Dataset | Class | Records | Variables | Structure |
|---------|-------|--------:|----------:|-----------|
| AE | EVENTS | 2,841 | 33 | One record per subject per adverse event |
| CM | INTERVENTIONS | 2,330 | 13 | One record per subject per medication per occurrence |
| DA | INTERVENTIONS | 18,463 | 15 | One record per subject per accountability measure per drug per visit |
| DD | EVENTS | 312 | 12 | One record per subject per death detail |
| DM | SPECIAL PURPOSE | 450 | 17 | One record per subject |
| DS | EVENTS | 1,350 | 9 | One record per subject per disposition event |
| DV | EVENTS | 337 | 10 | One record per subject per protocol deviation |
| EX | INTERVENTIONS | 13,403 | 13 | One record per subject per administration |
| LB | FINDINGS | 122,601 | 19 | One record per subject per lab test per visit |
| MH | EVENTS | 2,061 | 11 | One record per subject per medical history event |
| PE | FINDINGS | 25,596 | 12 | One record per subject per body system per visit |
| RELREC | RELATIONSHIP | 15,744 | 6 | One record per related record |
| RS | FINDINGS | 5,338 | 13 | One record per subject per assessment per visit |
| SU | INTERVENTIONS | 1,229 | 10 | One record per subject per substance use occurrence |
| SUPPAE | RELATIONSHIP | 8,523 | 10 | One record per parent record per qualifier |
| SUPPCM | RELATIONSHIP | 4,527 | 10 | One record per parent record per qualifier |
| SUPPDM | RELATIONSHIP | 1,799 | 10 | One record per subject per qualifier |
| SUPPLB | RELATIONSHIP | 245,202 | 10 | One record per parent record per qualifier |
| SUPPSU | RELATIONSHIP | 450 | 10 | One record per parent record per qualifier |
| TR | FINDINGS | 9,049 | 15 | One record per subject per lesion per measurement per visit |
| TU | FINDINGS | 9,012 | 14 | One record per subject per lesion per visit (tumor identification) |
| VS | FINDINGS | 52,864 | 14 | One record per subject per vital sign measurement per visit |
| ADAE | OCCURRENCE DATA STRUCTURE | 2,841 | 51 | One record per subject per adverse event |
| ADCM | OCCURRENCE DATA STRUCTURE | 2,330 | 30 | One record per subject per concomitant medication occurrence |
| ADDS | OCCURRENCE DATA STRUCTURE | 1,350 | 24 | One record per subject per disposition event |
| ADDV | OCCURRENCE DATA STRUCTURE | 337 | 24 | One record per subject per protocol deviation |
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

## Known limitations (v0.1)

- Codelist references stubbed; Value-Level Metadata not yet emitted.
- MethodDefs limited to inferred origin tags (Collected / Assigned / Derived).
- WhereClauseDefs not yet emitted (typical for ADTTE PARAMCD-based VLM).
- ItemDef OIDs are domain-scoped (e.g. `IT.DM.STUDYID`); the SHARED ItemDef
  pattern is deferred to a future iteration.

