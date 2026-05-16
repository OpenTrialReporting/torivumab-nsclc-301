# Define-XML v2.1 — Inventory

**Study:** SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
**Generated:** 2026-05-16
**File:** `define/define.xml`
**Datasets:** 27  ·  **Variables:** 447

## Datasets

| Dataset | Class | Records | Variables | Structure |
|---------|-------|--------:|----------:|-----------|
| AE | EVENTS | 2,837 | 24 | One record per subject per adverse event |
| CM | INTERVENTIONS | 2,222 | 13 | One record per subject per medication per occurrence |
| DA | INTERVENTIONS | 28,108 | 15 | One record per subject per accountability measure per drug per visit |
| DD | EVENTS | 284 | 12 | One record per subject per death detail |
| DM | SPECIAL PURPOSE | 450 | 17 | One record per subject |
| DS | EVENTS | 1,350 | 9 | One record per subject per disposition event |
| EX | INTERVENTIONS | 11,710 | 13 | One record per subject per administration |
| LB | FINDINGS | 115,394 | 19 | One record per subject per lab test per visit |
| MH | EVENTS | 2,051 | 11 | One record per subject per medical history event |
| PE | FINDINGS | 22,662 | 12 | One record per subject per body system per visit |
| RELREC | RELATIONSHIP | 17,708 | 7 | One record per related record |
| RS | FINDINGS | 2,260 | 14 | One record per subject per assessment per visit |
| SU | INTERVENTIONS | 1,236 | 11 | One record per subject per substance use occurrence |
| SUPPAE | RELATIONSHIP | 8,511 | 10 | One record per parent record per qualifier |
| SUPPCM | RELATIONSHIP | 4,444 | 10 | One record per parent record per qualifier |
| SUPPDM | RELATIONSHIP | 1,799 | 10 | One record per subject per qualifier |
| SUPPLB | RELATIONSHIP | 230,788 | 10 | One record per parent record per qualifier |
| SUPPSU | RELATIONSHIP | 450 | 10 | One record per parent record per qualifier |
| TR | FINDINGS | 7,724 | 15 | One record per subject per lesion per measurement per visit |
| TU | FINDINGS | 7,686 | 14 | One record per subject per lesion per visit (tumor identification) |
| VS | FINDINGS | 46,095 | 14 | One record per subject per vital sign measurement per visit |
| ADAE | OCCURRENCE DATA STRUCTURE | 2,837 | 45 | One record per subject per adverse event |
| ADLB | BASIC DATA STRUCTURE | 115,394 | 35 | One record per subject per parameter per analysis visit |
| ADRS | BASIC DATA STRUCTURE | 3,160 | 20 | One record per subject per parameter per analysis visit |
| ADSL | SUBJECT LEVEL ANALYSIS DATASET | 450 | 32 | One record per subject |
| ADTR | BASIC DATA STRUCTURE | 7,947 | 26 | One record per subject per parameter per analysis visit |
| ADTTE | BASIC DATA STRUCTURE | 1,450 | 19 | One record per subject per time-to-event parameter |

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

