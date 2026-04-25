# CRF Strategy — SIMULATED-TORIVUMAB-2026

**Document:** CRF-STRATEGY.md  
**Study:** SIMULATED-TORIVUMAB-2026 (torivumab-nsclc-301)  
**Date:** 2026-03-30  
**Status:** LOCKED — Ready for CRF design execution

---

## 1. Executive Summary

Define the Case Report Form (CRF) strategy for a synthetic Phase 3 NSCLC clinical trial.
The CRF is the data collection instrument — what questions/fields are asked on what visits.

**Approach:** Adapt CDISC CDASH templates (OpenClinica Form Library) for oncology Phase 3 design.

---

## 2. CRF Purpose & Scope

### Purpose
Collect raw trial data at clinical sites that will be transformed into SDTM domains during data management.

### Scope
- **Study design:** Phase 3, randomised, double-blind, placebo-controlled
- **Population:** 450 subjects (300 active, 150 placebo)
- **Treatment:** Torivumab 200 mg IV Q3W or matching placebo
- **Duration:** ~18 months accrual + ~24 months minimum follow-up
- **Response assessment:** RECIST 1.1 (imaging every 6 weeks for first 18 weeks, then Q12W)
- **Safety monitoring:** Adverse events, labs, vital signs per visit

---

## 3. CDASH Standards & Reference

### Versions (LOCKED)
| Standard | Version | Alignment | Released |
|----------|---------|-----------|----------|
| **CDASH Model** | **v1.1** | Cumulative; backward compatible with all SDTMIG versions | 2019 |
| **CDASHIG** | **v2.1** | References SDTMIG v3.2 but compatible with SDTMIG v3.4 | Nov 2019 |
| **SDTMIG** (our target) | **v3.4** | Referenced for SDTM domain structure | Nov 2021 |
| **ADaMIG** (our target) | **v1.3** | Referenced for ADaM derivation | 2023 |
| **CDISC CT** | **2024-03** | Latest submission values (SDTM & ADaM) | 2024 |
| **Response Criteria** | **RECIST 1.1** | CDISC Oncology Disease Response Supplement | 2023 |

### Rationale & Traceability
- **CDASH v1.1 cumulative model:** Builds on all prior releases; backward compatible means CDASHIG v2.1 forms can map to both SDTMIG v3.2 AND v3.4 without loss
- **CDASHIG v2.1 to SDTMIG v3.4 mapping:** CDASH variable names match SDTM (e.g., AETERM → AETERM, AEDECOD → AEDECOD). This traceability holds across SDTMIG versions.
- **Direct CRF → SDTM → ADaM pipeline:**
  ```
  CDASHIG v2.1 (collection)
       ↓
  SDTMIG v3.4 (tabulation)
       ↓
  ADaMIG v1.3 (analysis)
  ```
- **OpenClinica Form Library:** Provides ready-to-use CDASH v1.1 templates; backward compatible with our SDTMIG v3.4 target
- **RECIST 1.1:** Aligns with protocol oncology requirements; supported in CDISC Disease Response Supplement (2023)

### Reference Source
OpenClinica CDASH Form Library: https://docs.openclinica.com/oc4/building-forms-and-studies/cdash-crf-library/

---

## 4. CRF Structure & Visit Schedule

### Visit Schedule (LOCKED)

```
SCREENING                  TREATMENT                              FOLLOW-UP
(Days -28 to 0)        (Day 1 to ~EOT)                     (Post-treatment to ~Day 999)

├── Screening Visit     ├── Cycle 1, Day 1 (Baseline)      ├── Off-Treatment FU-01
│   (Week -4)          │   (Wk 1)                          │   (Month 3)
│                       ├── Cycle 1, Day 8                 ├── Off-Treatment FU-02
│                       │   (Wk 2)                          │   (Month 6)
│                       ├── Cycle 1, Day 15                ├── Off-Treatment FU-03
│                       │   (Wk 3)                          │   (Month 12)
│                       ├── Cycle 1, Day 22 (EOC1)         └── Long-term Survival FU
│                       │   (Wk 4)                              (q12w by phone)
│                       ├── Cycle 2, Day 1
│                       │   (Wk 5)
│                       ├── Cycle 2, Day 22 (EOC2)
│                       │   (Wk 8)
│                       ├── ... [Cycles 3-35]
│                       ├── Imaging assessment q6w (Wk 6, 12, 18, 24...)
│                       ├── Imaging assessment q12w after Wk 24
│                       └── End-of-Treatment Visit
│                           (30 days post last dose)
```

### Visit Types & Assessment Windows

| Visit Type | Timing | Duration | Key Assessments |
|-----------|--------|----------|-----------------|
| Screening | Day -28 to Day 0 | 28 days | IE/EE, demographics, baseline labs, vitals, medical history, eligibility confirmation |
| Baseline (C1D1) | Day 1 | — | Dosing, baseline labs, vitals, PD-L1 status, prior therapy, disposition |
| On-Treatment | Every 3 weeks (Q3W) | ±3 days | Dosing, compliance, AEs, labs, vitals, concomitant meds |
| Imaging Visit | Q6W for 18W, then Q12W | ±7 days | Tumour assessment (CT/MRI), RECIST response |
| End-of-Cycle | Every 3 weeks (Q3W) | ±3 days | Cumulative AE review, dose modifications, compliance |
| End-of-Treatment | ~30 days post last dose | ±3 days | Final safety labs, final vitals, disposition (completion/discontinuation reason) |
| Off-Treatment FU | Months 3, 6, 12 | Window varies | Safety follow-up, survival status |
| Long-Term Survival FU | Every 12 weeks | Phone contact | Vital status, disease status (if off-trial assessments available) |

---

## 5. CDASH Forms Selection

### Core Foundational Forms (ADAPTED FROM OPENCLINICA LIBRARY)

| Domain | Form Name | Use in Study | Visit Schedule |
|--------|-----------|--------------|-----------------|
| **DM** | Demographics | Baseline subject identification | Screening/Baseline |
| **DS** | Disposition | Study status (completion, discontinuation, reason) | Baseline + EOT + FU |
| **IE** | Inclusion/Exclusion Criteria | Eligibility verification | Screening |
| **EC** | Exposure as Collected | Drug dosing, dose modifications, compliance | Every on-treatment visit |
| **DA** | Drug Accountability | Drug received, dispensed, returned | Baseline + EOT |
| **AE** | Adverse Events | AE reporting, MedDRA coding, CTCAE grading | Every visit during treatment + FU |
| **CM** | Concomitant Medications | Background medications, WHO Drug coding | Baseline + ongoing |
| **MH** | Medical History | Prior medical conditions, prior therapy | Baseline |
| **SU** | Substance Use (Tobacco) | Smoking status | Baseline |
| **VS** | Vital Signs (Horizontal format) | BP, HR, temperature, respiration | Every visit |
| **LB** | Laboratory Test Results (Local) | **Clinical labs** (chemistry, hematology, urinalysis) + **Baseline biomarkers** (PD-L1 TPS, mutations, TMB) | Baseline (biomarkers), Weeks 1-3 of each cycle (clinical), EOT |
| **PE** | Physical Examination | General PE findings, ECOG status | Baseline + EOT |
| **DD** | Death Details | Cause of death, circumstances (if applicable) | Post-mortem |

### Custom/Oncology-Specific Forms (TO BE DESIGNED)

| Domain | Form Name | Purpose | Visit Schedule |
|--------|-----------|---------|-----------------|
| **TU** | Tumour Identification | Baseline lesion identification, location, measurement method | Baseline imaging visit |
| **TR** | Tumour Results | Lesion measurements (longest diameter for each target lesion) | Every imaging visit (Q6W then Q12W) |
| **RS** | Disease Response | Overall response assessment (CR/PR/SD/PD) per RECIST 1.1 | Every imaging visit (Q6W then Q12W) |

### Not Required (Out of Scope)
- ECG (EG) — not specified in protocol
- Pharmacokinetics (PC) — deferred to separate PK substudy
- Microbiology/Microscopy (MB, MI) — not applicable to NSCLC
- Crohn's therapeutic area forms — not applicable

---

## 6. CRF Design Specifications (LOCKED)

### Format
- **Primary:** Excel spreadsheet (.xlsx) with question-by-question layout
- **Secondary:** PDF mock-up for visual review
- **Rationale:** Spreadsheet allows easy variable mapping to SDTM; PDF for stakeholder approval

### Content per Form
Each form SHALL include:

| Element | Description |
|---------|-------------|
| **Form Header** | Study name, protocol number, form name, visit/cycle, subject ID |
| **Questions** | CDASH variable names, field labels, data types (text, date, numeric, dropdown) |
| **Codelists** | Dropdown values per CDISC CT 2024-03 (or synonyms where appropriate) |
| **Instructions** | Field-level help text (e.g., "Enter body weight in kg") |
| **Validation Rules** | Range checks, required fields, conditional logic (if applicable) |
| **Visit Windows** | ±X days from scheduled visit |
| **Query Notes** | Space for data clarification queries (DM to sites) |

### Biomarker Testing (LB Domain) — Protocol Alignment

**Per protocol Section 4.2 (Eligibility)**, all patients require baseline molecular testing:
- **PD-L1 TPS:** ≥50% by 22C3 pharmDx IHC assay (central lab)
- **EGFR mutations:** Absence of sensitising mutations (exon 19 deletions, exon 21 L858R, other activating mutations)
- **ALK rearrangement:** Absence of ALK fusions
- **Other mutations (testing required):** ROS1, KRAS G12C, MET exon 14 skipping, RET rearrangements, BRAF V600E, NTRK fusions
- **TMB (optional):** If available from genomic panel

**CRF Implementation:**
Biomarker results collected on **LB (Laboratory Test Results) form**, treating molecular findings as laboratory data:

```
FORM: Laboratory Test Results — Baseline Biomarkers (LB)
Visit: Baseline (Screening or Day 1, before randomisation)
Assessment Window: ±7 days from randomisation

Biomarker Fields (LB domain):
├── LBTESTCD = PD-L1_TPS
│   ├── LBTEST = "PD-L1 Tumour Proportion Score"
│   ├── LBORRES = [0-100] (numeric percentage)
│   ├── LBSTRESC = [≥50%, <50%] (categorical for eligibility)
│   ├── LBSTNRHI = 100
│   └── Notes: 22C3 pharmDx assay, central lab result
│
├── LBTESTCD = EGFR_MUT
│   ├── LBTEST = "EGFR Mutation Status"
│   ├── LBORRES = [Wild-type, L858R, Exon 19 deletion, Other activating, Unknown]
│   └── Notes: Sensitising mutations are exclusion criteria
│
├── LBTESTCD = ALK_REARR
│   ├── LBTEST = "ALK Gene Rearrangement"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: ALK positive = exclusion criterion
│
├── LBTESTCD = ROS1_REARR
│   ├── LBTEST = "ROS1 Gene Rearrangement"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; not formal exclusion, but documented for post-progression therapy
│
├── LBTESTCD = KRAS_G12C
│   ├── LBTEST = "KRAS G12C Mutation"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; documented for subgroup analysis
│
├── LBTESTCD = MET_EX14
│   ├── LBTEST = "MET Exon 14 Skipping"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; not formal exclusion
│
├── LBTESTCD = RET_REARR
│   ├── LBTEST = "RET Gene Rearrangement"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; not formal exclusion
│
├── LBTESTCD = BRAF_V600E
│   ├── LBTEST = "BRAF V600E Mutation"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; not formal exclusion
│
├── LBTESTCD = NTRK_FUSE
│   ├── LBTEST = "NTRK Gene Fusion"
│   ├── LBORRES = [Positive, Negative, Not tested, Unknown]
│   └── Notes: Required; not formal exclusion
│
└── LBTESTCD = TMB
    ├── LBTEST = "Tumour Mutational Burden (per Mb)"
    ├── LBORRES = [numeric value, e.g., 12.5]
    ├── LBSTRESC = [High (≥10), Low (<10), Unknown]
    └── Notes: Optional if genomic panel used; exploratory analysis
```

**Rationale for LB domain:**
- CDISC standard: molecular biomarkers = laboratory findings, not demographics
- Enables direct SDTM traceability (LB → ADLB for biomarker subgroup analyses)
- Clinical labs (chemistry, hematology) also on LB; no domain proliferation
- Aligns with CDISC Oncology Examples Document (2024)

---

### Example Form Structure (Adverse Events)
```
FORM: Adverse Events (AE)
Visit: [On-Treatment, every visit]
Assessment Window: ±3 days from cycle day

Fields:
├── AESTDTC (date of AE onset) — Date field, required
├── AETERM (AE term) — Text field, max 200 chars
├── AEDECOD (MedDRA preferred term) — Lookup codelist (MedDRA v27.0)
├── AESOC (System Organ Class) — Auto-derive from MedDRA
├── AESEV (Severity) — Dropdown [Mild, Moderate, Severe]
├── AETOXGR (CTCAE Grade) — Dropdown [Grade 1, 2, 3, 4, 5]
├── AEREL (Relationship to study drug) — Dropdown [Unrelated, Unlikely, Possible, Probable, Definite]
├── AESER (Serious AE) — Dropdown [Yes, No]
├── AEACN (Action taken) — Dropdown [None, Dose reduced, Dose increased, Dose interrupted, Drug discontinued, Drug withdrawn]
└── AEOUT (Outcome) — Dropdown [Recovered, Recovering, Not recovered, Fatal, Unknown]
```

### Data Types (Standardised)
| Type | Format | Example |
|------|--------|---------|
| Date | YYYY-MM-DD | 2026-05-15 |
| Datetime | YYYY-MM-DD HH:MM | 2026-05-15 14:30 |
| Numeric | Integer or decimal | 180 (weight), 98.6 (temp) |
| Text | Free text | "Patient reported dizziness on Day 3" |
| Codelist | Dropdown from CDISC CT | "Preferred Term" from MedDRA |

---

## 7. Decision Points (LOCKED)

| Decision # | Topic | Decision | Rationale |
|-----------|-------|----------|-----------|
| D-01 | MedDRA Version | Use MedDRA v27.0 or simplified synthetic? | Real-world realism requires valid MedDRA. v27.0 available; use preferred terms (LLT optional for POC). |
| D-02 | Lab Data | Realistic distributions vs simple ranges? | Realistic distributions needed for statistical validity. Use normal ranges per lab; add realistic outliers. |
| D-03 | Missing Data | MCAR (random) vs MNAR (dependent)? | Use MCAR for POC (simpler). If needed for advanced analysis, can add MNAR patterns post-launch. |
| D-04 | Event Rates | Conservative (KEYNOTE-024 match) vs optimistic? | Conservative (match observed data). Torivumab HR=0.65 vs chemo; this is realistic. |
| D-05 | eCRF Vendor Format | OpenClinica, Medidata Rave, or generic? | Use generic Excel (platform-agnostic). Can import to any eCRF later. |

**All decisions above are LOCKED and documented in ROADMAP.md**

---

## 8. CRF Deliverables (PHASE 2)

### Primary Deliverables

| Item | Format | Location | Owner |
|------|--------|----------|-------|
| **CRF Specifications** | Excel workbook (.xlsx) with all forms | `crf/SIMULATED-TORIVUMAB-2026_CRF.xlsx` | Nova (scaffold) → LG (review/validate) |
| **CRF Visual Preview** | PDF mockup of key forms | `crf/CRF_Preview.pdf` | Nova |
| **Field Definitions** | CSV mapping (Form → Question → CDASH variable → Data type → Codelist) | `crf/field_definitions.csv` | Nova |
| **Visit Schedule** | CSV with visit type, timing, assessment window, required forms | `crf/visit_schedule.csv` | Nova |
| **Codelist Reference** | CSV linking forms to CDISC CT 2024-03 codelists | `crf/codelist_reference.csv` | Nova |
| **CRF Annotations** | Separate document mapping CRF fields → SDTM variables (post-approval) | `crf/CRF_Annotations.md` | Nova (Phase 4) |

### Secondary Deliverables
- CRF completion guidelines (instructions for sites)
- Query management template (for data clarifications)
- CRF SAP reference (for biostat team)

---

## 9. Success Criteria (PHASE 2 GATE REVIEW)

Upon completion of Phase 2 (aCRF design), the CRF SHALL:

- [ ] Include all 13 foundational CDASH forms (or justified exceptions)
- [ ] Include 3 custom oncology forms (TU, TR, RS) for RECIST 1.1 assessment
- [ ] Use CDISC CT 2024-03 codelists or documented synonyms
- [ ] Define visit windows ±X days for each assessment
- [ ] Map to all variables needed for 19 SDTM domains
- [ ] Include validation rules (required fields, range checks, conditional logic)
- [ ] Be completable within realistic clinic visit timeframe (~30-45 min per visit)
- [ ] Reference protocol section/objective for each form
- [ ] Include MedDRA v27.0 and CTCAE v5.0 coding guidance
- [ ] Be approvable by LG at Phase Gate 1

---

## 10. Timeline Estimate (PHASE 2)

| Task | Days | Notes |
|------|------|-------|
| Review CDASH templates | 1 | Read OpenClinica forms |
| Adapt foundational forms (13) | 3 | DM, DS, IE, EC, DA, AE, CM, MH, SU, VS, LB, PE, DD |
| Design custom oncology forms (3) | 2 | TU, TR, RS per RECIST 1.1 |
| Create Excel workbook | 1 | Combine all forms + metadata |
| Create field definitions + visit schedule | 1 | CSV exports for data mgmt |
| PDF mockup + validation | 1 | Visual review |
| **Total Phase 2** | **~5 days** | Ready for Gate 1 review |

---

## 11. Dependencies & Assumptions

### Assumptions
- LG has access to OpenClinica CDASH library (confirmed — shared link provided)
- MedDRA v27.0 available (standard in pharma; simplified coding acceptable for POC)
- CTCAE v5.0 available (public domain via NCI)
- Visit schedule stable (locked in protocol synopsis v1.1)
- No additional forms needed beyond those listed (can add post-Gate 1 if needed)

### Dependencies
- Protocol synopsis v1.1 (✅ LOCKED)
- CDASH templates (✅ PROVIDED via OpenClinica)
- CDISC CT 2024-03 (✅ AVAILABLE publicly)
- MedDRA v27.0 (⏳ Assume available; if not, use simplified synthetic coding)

---

## 12. Reference Documents

| Document | Link | Purpose |
|----------|------|---------|
| Protocol Synopsis v1.1 | `protocol/synopsis.md` | Study design, objectives, populations |
| ROADMAP.md | `ROADMAP.md` | Overall pipeline phases & timeline |
| OpenClinica CDASH Library | https://docs.openclinica.com/oc4/building-forms-and-studies/cdash-crf-library/ | Form templates |
| CDASHIG v2.1 | https://www.cdisc.org/standards/foundational/cdash/cdashig-v2-1 | CDASH spec (behind login) |
| CDISC Oncology Disease Response Supplement | https://www.cdisc.org/standards/specialized/cdash-oncology | RECIST 1.1 guidance |
| CTCAE v5.0 | https://ctep.cancer.gov/protocolDevelopment/electronic_applications/ctc.htm | Adverse event grading (NCI) |
| MedDRA v27.0 | https://www.meddra.org/ | Medical dictionary for regulatory activities |

---

## Document Approval

| Role | Name | Date | Status |
|------|------|------|--------|
| Prepared by | Nova | 2026-03-30 | ✅ |
| Reviewed by | Lovemore Gakava | TBD | ⏳ Pending |
| Approved by | Lovemore Gakava | TBD | ⏳ Gate 1 |

---

*Last updated: 2026-03-30 19:23 UTC*  
*LOCKED — Ready for CRF design execution (Phase 2)*
