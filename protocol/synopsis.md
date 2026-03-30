# ⚠️ FICTIONAL EDUCATIONAL PROTOCOL — NOT FOR REGULATORY USE

---

**THIS IS A COMPLETELY FICTIONAL PROTOCOL CREATED FOR EDUCATIONAL PURPOSES ONLY.**

**DO NOT submit to any regulatory authority, do NOT register on ClinicalTrials.gov, do NOT use for clinical investigation.**

**All identifiers (protocol number, IND, EudraCT, NCT) are fictional and non-functional. Celindra Therapeutics, torivumab, and all trial details are fictional.**

**This document is for learning clinical trial design, CDISC standards, and pharmaverse stack development only.**

---

# CLINICAL TRIAL PROTOCOL SYNOPSIS

---

## TITLE PAGE

**Full Study Title:**
A Randomised, Double-Blind, Placebo-Controlled, Phase 3 Study of Torivumab (Anti-PD-L1 Monoclonal Antibody) versus Placebo as First-Line Treatment in Patients with Advanced or Metastatic Non-Small Cell Lung Cancer with PD-L1 Tumour Proportion Score ≥50% and No EGFR or ALK Genomic Tumour Aberrations

**Short Title:**
TORIVA-LUNG 301

**Protocol Number:** SIMULATED-TORIVUMAB-2026 *(FICTIONAL EDUCATIONAL PROTOCOL — Do NOT use for any regulatory submission)*

**Protocol Version:** 1.0

**Protocol Date:** 22 March 2026

**Sponsor:**
Celindra Therapeutics
1 Innovation Drive, Suite 400
Cambridge, MA 02139, USA
Tel: +1 (617) 555-0100

**Investigational Medicinal Product:** Torivumab 200 mg/10 mL concentrate for solution for infusion

**IND/CTA Number:** IND-SIM-2026-99999 *(FICTIONAL — Educational simulation only. Do NOT use for any regulatory submission.)*

**EudraCT Number:** 9999-999999-99 *(FICTIONAL — Educational simulation only. Do NOT use for any regulatory submission.)*

**ClinicalTrials.gov Identifier:** NCT99999999 *(FICTIONAL — Educational simulation only. Do NOT use for registration.)*

**Therapeutic Area:** Oncology — Non-Small Cell Lung Cancer (NSCLC)

**Phase:** 3

**Regulatory Sponsor Contact:**
Dr. Elena Vasquez, MD
Vice President, Regulatory Affairs
Celindra Therapeutics
1 Innovation Drive, Suite 400, Cambridge, MA 02139, USA
Tel: +1 (617) 555-0110 | Email: e.vasquez@celindra-tx.com *(fictional)*

**Medical Monitor:**
Dr. James Okafor, MD, PhD
Senior Medical Director, Oncology
Celindra Therapeutics
Tel: +1 (617) 555-0120 | Email: j.okafor@celindra-tx.com *(fictional)*

**Biostatistics:**
Dr. Sarah Mitchell, PhD
Head of Biostatistics, Oncology
Celindra Therapeutics *(fictional)*

**Data Management:**
Dr. Wei Zhang, MSc
Director, Clinical Data Management
Celindra Therapeutics | EDC Platform: Medidata Rave *(fictional)*

---

> ⚠️ **CRITICAL LEGAL NOTICE — FICTIONAL EDUCATIONAL DOCUMENT**
> 
> This protocol is a **COMPLETELY FICTIONAL** educational simulation created for learning and training purposes only. 
>
> **DO NOT use for:**
> - Any regulatory submission (FDA, EMA, PMDA, or any national authority)
> - Any clinical trial registration (ClinicalTrials.gov, EudraCT, etc.)
> - Any actual clinical investigation
> - Patient care or medical decision-making
>
> **All identifiers are fictional and non-functional:**
> - Protocol number: SIMULATED-TORIVUMAB-2026 (NOT a real protocol)
> - IND number: IND-SIM-2026-99999 (NOT a real IND)
> - EudraCT: 9999-999999-99 (NOT a real EudraCT)
> - NCT: NCT99999999 (NOT a real trial identifier)
>
> **Fictional elements:**
> - Celindra Therapeutics (fictional sponsor)
> - Torivumab (fictional drug compound)
> - All investigators, contacts, and trial data (fictional)
>
> **Purpose:** Educational reference for protocol structure, CDISC standards, and pharmaverse stack development.
>
> **Liability:** This document carries no legal standing. Any use for actual regulatory or clinical purposes is prohibited and may result in legal liability. See file header disclaimer.

---

## SYNOPSIS TABLE

| Parameter | Details |
|---|---|
| **Study Title** | [FICTIONAL] TORIVA-LUNG: Torivumab vs Placebo, First-Line Advanced NSCLC, PD-L1 TPS ≥50% |
| **Protocol Number** | SIMULATED-TORIVUMAB-2026 |
| **Phase** | 3 |
| **Sponsor** | Celindra Therapeutics |
| **Indication** | Advanced or metastatic NSCLC (Stage IIIB/IIIC/IV), PD-L1 TPS ≥50%, no EGFR/ALK mutation |
| **Study Design** | Randomised, double-blind, placebo-controlled, multinational |
| **Investigational Product** | Torivumab 200 mg IV Q3W (anti-PD-L1 monoclonal antibody) |
| **Comparator** | Matching placebo IV Q3W |
| **Randomisation Ratio** | 2:1 (torivumab : placebo) |
| **Stratification Factors** | Histology (squamous vs non-squamous); Geographic region (North America / Europe / Asia-Pacific) |
| **Target Sample Size** | 450 subjects (300 torivumab; 150 placebo) |
| **Primary Endpoint** | Overall Survival (OS) |
| **Key Secondary Endpoints** | Progression-Free Survival (PFS), ORR, DoR, DCR, Safety |
| **Exploratory Endpoints** | Patient-reported outcomes (PROs), PD-L1/TMB biomarker subgroups |
| **Response Assessment Criteria** | RECIST Version 1.1 |
| **Treatment Duration** | Up to 35 cycles (~2 years) or until disease progression / unacceptable toxicity |
| **OS Statistical Assumptions** | HR = 0.65; Control median OS = 14.0 months; Experimental median OS = 21.5 months |
| **PFS Statistical Assumptions** | HR = 0.55; Control median PFS = 6.0 months; Experimental median PFS = 11.0 months |
| **Power / Alpha** | 80% power; two-sided α = 0.05 |
| **Events Required (OS)** | ~320 deaths |
| **Accrual Period** | 18 months |
| **Minimum Follow-Up** | 24 months |
| **Analysis Populations** | ITT (primary), Safety, Per-Protocol |
| **Regulatory Framework** | ICH E6(R2), ICH E8(R1), ICH E9, ICH E9(R1), ICH E17, CTCAE v5.0 |
| **CDISC Standards** | SDTMIG v3.4, ADaMIG v1.3 |

---

## 1. BACKGROUND AND RATIONALE

### 1.1 Disease Burden — Non-Small Cell Lung Cancer

Lung cancer represents the leading cause of cancer-related mortality worldwide, accounting for approximately 1.8 million deaths annually (Global Cancer Observatory, 2022). Non-small cell lung cancer (NSCLC) comprises approximately 85% of all lung cancer diagnoses, with the majority of patients presenting with advanced or metastatic disease at the time of initial diagnosis. The five-year overall survival rate for patients with Stage IV NSCLC treated with conventional platinum-based doublet chemotherapy has historically remained below 10–15%, representing a significant unmet medical need.

*(Epidemiological figures sourced from Global Cancer Observatory (GLOBOCAN) 2022 estimates. Final protocol to reference most current GLOBOCAN/SEER data available at time of submission.)*

### 1.2 PD-L1 Biology and Tumour Immune Evasion

Programmed Death-Ligand 1 (PD-L1), encoded by the CD274 gene, is a transmembrane protein expressed on tumour cells and tumour-infiltrating immune cells. Engagement of PD-L1 with its cognate receptor, Programmed Death-1 (PD-1) expressed on cytotoxic T lymphocytes, results in suppression of T-cell activation, proliferation, and cytokine release — a mechanism co-opted by tumour cells to evade host immune surveillance.

In NSCLC, PD-L1 overexpression, defined as Tumour Proportion Score (TPS) ≥50%, has been identified as a predictive biomarker for response to PD-1/PD-L1 axis blockade. Approximately 25–30% of patients with advanced NSCLC exhibit PD-L1 TPS ≥50% on validated immunohistochemistry (IHC) assays. This subpopulation has demonstrated substantial clinical benefit from immune checkpoint inhibitor (ICI) therapy in landmark trials, with durable responses and improved survival compared to platinum doublet chemotherapy.

### 1.3 Torivumab — Investigational Agent

Torivumab is a humanised immunoglobulin G1 (IgG1) monoclonal antibody developed by Celindra Therapeutics that binds with high affinity and selectivity to PD-L1, blocking the PD-L1/PD-1 and PD-L1/CD80 (B7-1) inhibitory interactions. By disrupting these co-inhibitory signals, torivumab is intended to restore functional anti-tumour T-cell immunity within the tumour microenvironment.

**Phase 1/2 Clinical Experience** *(Synthetic — educational simulation only)*

Torivumab was evaluated in a first-in-human Phase 1 dose-escalation study (CTX-001; N=42) in patients with advanced solid tumours refractory to standard therapy. Doses of 1, 3, 10, and 20 mg/kg Q3W were evaluated. No dose-limiting toxicities were observed at doses up to 20 mg/kg Q3W. The recommended Phase 2 dose (RP2D) was established at 200 mg flat dose Q3W based on pharmacokinetic modelling demonstrating target receptor occupancy >95% across the dose range with a flat-dose regimen.

In a subsequent Phase 2 expansion cohort (CTX-002; N=98) in patients with advanced NSCLC and PD-L1 TPS ≥50%, torivumab 200 mg Q3W demonstrated an objective response rate (ORR) of 44.9%, median progression-free survival of 10.3 months, and an acceptable safety profile consistent with the PD-L1 inhibitor class. These data supported advancement to Phase 3 evaluation.

*Full PK/PD characterisation and Phase 1/2 clinical study reports are available in the Investigator's Brochure. This narrative is synthetic and generated for educational simulation purposes; torivumab is a fictional compound.*

### 1.4 Unmet Medical Need and Rationale for CTX-NSCLC-301

Despite advances with approved PD-1/PD-L1 inhibitors, clinical challenges persist:

- A proportion of patients with PD-L1 TPS ≥50% do not derive durable benefit from existing approved agents.
- Immune-related adverse events (irAEs) remain a clinically significant management burden.
- The comparative profile of torivumab — binding kinetics, Fc engineering, and irAE risk — may offer a differentiated benefit-risk profile.

In preclinical studies, torivumab demonstrated high-affinity binding to human PD-L1 (KD ~0.3 nM) with potent restoration of T-cell proliferation and cytokine production in co-culture assays. Fc-engineering with an IgG1 LALAPG mutation abolishes Fc receptor binding, reducing the risk of antibody-dependent cellular cytotoxicity (ADCC) against PD-L1-expressing immune cells — a differentiation feature relative to some approved PD-L1 inhibitors. The dose of 200 mg flat dose Q3W is supported by Phase 1 PK/PD modelling (CTX-001) demonstrating sustained receptor occupancy above the efficacious threshold throughout the dosing interval. *(Synthetic — educational simulation only)*

The Phase 3 study CTX-NSCLC-301 is therefore designed to evaluate the efficacy and safety of torivumab 200 mg IV Q3W versus placebo as first-line monotherapy in patients with advanced/metastatic NSCLC and PD-L1 TPS ≥50%, providing data sufficient to support global regulatory registration.

---

## 2. STUDY OBJECTIVES

### 2.1 Primary Objective

- To evaluate the effect of torivumab 200 mg Q3W versus placebo on **Overall Survival (OS)** in patients with previously untreated advanced or metastatic NSCLC with PD-L1 TPS ≥50% and no EGFR or ALK genomic tumour aberrations.

### 2.2 Secondary Objectives

1. To compare **Progression-Free Survival (PFS)** between the torivumab and placebo arms as assessed by blinded independent central review (BICR) per RECIST 1.1.
2. To compare the **Objective Response Rate (ORR)** (complete response [CR] + partial response [PR]) between treatment arms per RECIST 1.1 by BICR.
3. To evaluate the **Duration of Response (DoR)** in responders in each treatment arm.
4. To compare the **Disease Control Rate (DCR)** (CR + PR + stable disease [SD]) between treatment arms.
5. To characterise the **safety and tolerability** of torivumab relative to placebo, including the incidence, severity, and management of adverse events (AEs), serious adverse events (SAEs), immune-related adverse events (irAEs), and adverse events of special interest (AESIs).

### 2.3 Exploratory Objectives

1. To evaluate **Patient-Reported Outcomes (PROs)**, including health-related quality of life (HRQoL), symptoms, and functioning, using the EORTC QLQ-C30 and QLQ-LC13 questionnaires and the EQ-5D-5L.
2. To explore the relationship between **PD-L1 TPS** (as a continuous variable), **Tumour Mutational Burden (TMB)**, and efficacy outcomes (OS, PFS, ORR).
3. To characterise **pharmacokinetic (PK) parameters** of torivumab [NOTE: PK sampling schedule and analysis plan to be defined in a separate PK substudy protocol or appended PK section].
4. To assess the development of **anti-drug antibodies (ADA)** to torivumab.
5. To explore efficacy by histological subtype (squamous vs non-squamous) and geographic region.

---

## 3. STUDY DESIGN

### 3.1 Overview

CTX-NSCLC-301 is a **randomised, double-blind, placebo-controlled, multinational Phase 3** clinical trial. Eligible patients are randomised in a **2:1 ratio** to receive either torivumab 200 mg intravenously every 3 weeks (Q3W) or matching placebo IV Q3W.

### 3.2 Design Schematic

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                    CTX-NSCLC-301 — TORIVA-LUNG 301 Study Design                             │
│         Phase 3, Randomised, Double-Blind, Placebo-Controlled, Multinational                │
└─────────────────────────────────────────────────────────────────────────────────────────────┘

   SCREENING                  TREATMENT PERIOD                        FOLLOW-UP
  (Up to 28 days)         (Up to 35 cycles / ~2 years)
                                                                   ┌──────────────────────┐
 ┌──────────────┐         ┌───────────────────────────┐            │  POST-TREATMENT       │
 │  ELIGIBILITY │         │  ARM A (n≈300)             │───────────►│  FOLLOW-UP            │
 │  ASSESSMENT  │    ┌───►│  TORIVUMAB 200 mg IV Q3W   │            │  • Tumour assessments │
 │              │    │    │  Day 1 of each 21-day cycle│            │    until progression  │
 │  • PD-L1 TPS │    │    └───────────────────────────┘            │  • Survival follow-up │
 │    ≥50% (IHC)│    │                                              │    every 12 weeks     │
 │  • NSCLC     │ 2:1│     Stratified Randomisation                 │    (telephone)        │
 │    Stage     │ Rand    ┌─────────────────────────┐               │  • Until death or     │
 │    IIIB-IV   │ (IWRS)  │ Factor 1: Histology      │               │    study close-out    │
 │  • No EGFR/  │    │    │  • Squamous              │               └──────────────────────┘
 │    ALK mut.  │    │    │  • Non-squamous          │
 │  • ECOG PS   │    │    │ Factor 2: Region          │
 │    0 or 1    │    │    │  • North America          │
 │  • Adequate  │    │    │  • Europe                 │               ┌──────────────────────┐
 │    organ fn. │    │    │  • Asia-Pacific           │               │  LONG-TERM           │
 └──────┬───────┘    │    └─────────────────────────┘               │  SURVIVAL FOLLOW-UP  │
        │            │                                               │                      │
        │  Informed  │    ┌───────────────────────────┐             │  Every 12 weeks      │
        │  Consent   └───►│  ARM B (n≈150)             │───────────►│  until death or      │
        │                 │  PLACEBO IV Q3W            │             │  study close-out     │
        ▼                 │  Day 1 of each 21-day cycle│             └──────────────────────┘
  ┌───────────┐           └───────────────────────────┘
  │ ENROLMENT │
  │  N = 450  │           Treatment continues until:
  └───────────┘           • Disease progression (RECIST 1.1, BICR)
                          • Unacceptable toxicity
                          • Withdrawal of consent
                          • Completion of 35 cycles (~2 years)
                          • Death

────────────────────────────────────────────────────────────────────────────────────────────
  Timeline:   |── 18 months accrual ──|──────── 24 months minimum follow-up ────────|
              |─────────────── ~42 months total study duration ───────────────────────|
────────────────────────────────────────────────────────────────────────────────────────────

  Primary Endpoint:    Overall Survival (OS)
  Key Secondary:       PFS (BICR, RECIST 1.1) · ORR · DoR · DCR · Safety
  Exploratory:         PROs (EORTC QLQ-C30/LC13, EQ-5D-5L) · PD-L1/TMB biomarkers · PK
```

Stratification at randomisation:
- **Factor 1:** Tumour histology — squamous vs non-squamous
- **Factor 2:** Geographic region — North America / Europe / Asia-Pacific

### 3.3 Randomisation

Randomisation will be performed centrally using an interactive web response system (IWRS). The IWRS will assign treatment group and kit number. Randomisation will be stratified by the two factors listed in Section 3.2. The randomisation list will be generated by the Sponsor's independent biostatistics group using a permuted block design with randomly varying block sizes.

Block sizes will remain blinded to site staff throughout the study. Exact block sizes will be documented in the randomisation specification held by the independent statistician and not disclosed in the protocol body.

### 3.4 Blinding

The study is double-blind. Torivumab and placebo infusions will be identical in appearance, volume, and infusion duration. Blinding will be maintained at the site, patient, and Sponsor levels throughout the study. All response assessments will be performed by a **Blinded Independent Central Review (BICR)** committee.

Unblinding provisions:
- Emergency unblinding for a specific patient is permitted at the Investigator's discretion for urgent medical management. An emergency unblinding procedure will be available 24 hours/day, 7 days/week via IWRS.
- Any unblinding must be documented and the Sponsor notified within 24 hours.

### 3.5 Treatment Arms

| Arm | Treatment | Dose | Route | Schedule | Duration |
|---|---|---|---|---|---|
| A (Active) | Torivumab | 200 mg | IV infusion over 30 min | Q3W (Day 1 of each 21-day cycle) | Up to 35 cycles (~2 years) |
| B (Control) | Placebo | Matching volume | IV infusion over 30 min | Q3W (Day 1 of each 21-day cycle) | Up to 35 cycles (~2 years) |

Treatment continues until disease progression per RECIST 1.1, unacceptable toxicity, withdrawal of consent, or completion of 35 cycles, whichever occurs first.

### 3.6 Post-Treatment Follow-Up

Patients who discontinue treatment for reasons other than disease progression or death will continue tumour assessments per the imaging schedule until progression, initiation of new anti-cancer therapy, withdrawal of consent, or death.

All patients will be followed for survival (Overall Survival follow-up) by telephone contact every 12 weeks following the end-of-treatment visit, until death, withdrawal of consent, or study close-out.

---

## 4. STUDY POPULATION

### 4.1 Inclusion Criteria

A patient is eligible for enrolment if ALL of the following criteria are met:

1. **Age:** ≥18 years of age at the time of informed consent.

2. **Histologically or cytologically confirmed** diagnosis of NSCLC (adenocarcinoma, squamous cell carcinoma, or other NSCLC histology). Mixed small cell/NSCLC histology is excluded.

3. **Stage:** Stage IIIB (not amenable to curative-intent chemoradiation), Stage IIIC, or Stage IV disease per AJCC 8th Edition staging.

4. **Line of therapy:** No prior systemic anti-cancer therapy for advanced/metastatic disease. Prior adjuvant or neoadjuvant chemotherapy or chemoradiation completed ≥6 months before diagnosis of metastatic disease is permitted. Prior adjuvant ICI therapy is not permitted. *(Cross-referenced: KEYNOTE-024 NCT02142738; KEYNOTE-042 NCT02220894)*

5. **PD-L1 expression:** PD-L1 TPS ≥50% as determined by the 22C3 pharmDx IHC assay (Dako/Agilent) at a certified central laboratory. Central laboratory result governs eligibility in all cases of discordance with local laboratory results. A newly obtained formalin-fixed tumour tissue biopsy from a site not previously irradiated is required; archival tissue is acceptable only if obtained after the diagnosis of metastatic disease. *(Cross-referenced: KEYNOTE-024 NCT02142738)*

6. **Molecular testing:** Absence of sensitising EGFR mutations (including exon 19 deletions and exon 21 L858R substitutions and other known activating mutations) and ALK gene rearrangements, as determined by a validated assay. Testing for ROS1, KRAS G12C, MET exon 14 skipping, RET rearrangements, BRAF V600E, and NTRK fusions must also be performed for all patients to characterise the population and guide post-progression therapy. These alterations are not formal exclusion criteria but must be documented at baseline in the eCRF. *(Cross-referenced: KEYNOTE-024 NCT02142738; contemporary NSCLC trial standard)*

7. **Measurable disease:** At least one measurable lesion per RECIST 1.1 criteria (≥10 mm in longest diameter by CT scan, or ≥15 mm in short axis for lymph nodes).

8. **ECOG Performance Status:** 0 or 1 at screening.

9. **Life expectancy:** ≥12 weeks as assessed by the Investigator.

10. **Adequate organ function** at screening (all within 10 days before first dose):
    - Haematological: ANC ≥1.5 × 10⁹/L; Platelets ≥100 × 10⁹/L; Haemoglobin ≥90 g/L (without transfusion within 7 days)
    - Hepatic: Total bilirubin ≤1.5 × ULN (≤3 × ULN for patients with documented Gilbert's syndrome); AST and ALT ≤2.5 × ULN (≤5 × ULN if liver metastases present)
    - Renal: Serum creatinine ≤1.5 × ULN or eGFR ≥50 mL/min/1.73m² (CKD-EPI or MDRD formula)
    - Coagulation: INR or PT ≤1.5 × ULN and aPTT ≤1.5 × ULN (unless patient is receiving therapeutic anticoagulation)

11. **Female patients of childbearing potential (FOCBP):** Must have a negative serum pregnancy test within 72 hours before the first dose of study drug. FOCBP and male patients with female partners of childbearing potential must agree to use two adequate barrier methods of contraception, or a barrier method plus a hormonal method, from screening through ≥120 days after the last dose of study drug, conforming to ICH M3(R2) and applicable regional regulatory requirements. *(Cross-referenced: KEYNOTE-024 NCT02142738; KEYNOTE-042 NCT02220894)*

12. **Informed consent:** Patient must have signed and dated written informed consent in accordance with ICH E6(R2) GCP guidelines and local regulatory requirements before any study-specific procedures.

13. **Archival or fresh tumour tissue:** Available archival tumour tissue (formalin-fixed paraffin-embedded [FFPE] biopsy obtained ≤3 years before screening, or fresh biopsy obtained during screening), in sufficient quantity and quality for central PD-L1 testing and exploratory biomarker analyses.

### 4.2 Exclusion Criteria

A patient is **not eligible** for enrolment if ANY of the following criteria apply:

1. **Prior checkpoint inhibitor therapy:** Prior treatment with any anti-PD-1, anti-PD-L1, anti-PD-L2, anti-CD137, or anti-CTLA-4 antibody, or any other antibody or drug specifically targeting T-cell co-stimulation or checkpoint pathways.

2. **Actionable oncogenic drivers:** Known sensitising EGFR mutation or ALK rearrangement. Additionally, any other actionable oncogenic driver alteration (ROS1, RET, BRAF V600E, MET exon 14, NTRK, KRAS G12C) for which an approved targeted therapy is available in the enrolling jurisdiction, if the patient would be eligible for that targeted therapy. Jurisdiction-specific approved targeted therapy landscapes will be documented in a country-specific protocol appendix.

3. **Active autoimmune disease:** Any active autoimmune disease or syndrome that required systemic immunosuppressive treatment within the last 2 years, or that may recur upon cessation of immunosuppressive treatment. Exceptions: patients with vitiligo, type 1 diabetes mellitus (stable on insulin), hypothyroidism (stable on hormone replacement), or psoriasis not requiring systemic treatment are permitted.

4. **Active systemic corticosteroid use:** Systemic corticosteroid therapy at a dose equivalent to >10 mg prednisone daily or any other immunosuppressive medication within 7 days prior to the first dose of study treatment. Inhaled, topical, and physiologic replacement doses are permitted.

5. **Brain metastases:** Untreated symptomatic brain metastases or leptomeningeal disease. Patients with treated brain metastases are eligible if clinically stable (no progression on imaging for ≥4 weeks post-treatment), off systemic corticosteroids (or on stable dose ≤10 mg prednisone equivalent/day) for ≥2 weeks before first dose, and neurologically stable. *(Cross-referenced: KEYNOTE-024 NCT02142738 — untreated CNS metastases excluded; treated and stable brain metastases permitted, consistent with current ICI trial standard)*

6. **Prior malignancy:** Active or history of another primary malignancy within 3 years prior to study enrolment, except for adequately treated basal cell or squamous cell skin cancer, in situ cervical cancer, or other cancers from which the patient has been disease-free for ≥3 years and is not receiving treatment.

7. **Active infections:** Uncontrolled, serious active infection requiring systemic therapy. Active tuberculosis (TB) or known history of TB. Known history of HIV is an exclusion criterion. Known active Hepatitis B or C is an exclusion criterion. *(Cross-referenced: KEYNOTE-024 NCT02142738; KEYNOTE-042 NCT02220894 — both exclude known HIV history and active HBV/HCV)*

8. **Interstitial lung disease (ILD):** History of (non-infectious) pneumonitis that required steroids, or current pneumonitis, or known history of interstitial lung disease.

9. **Prior thoracic radiation:** Prior thoracic radiation therapy >30 Gy within 6 months prior to first dose of study drug. *(Cross-referenced: KEYNOTE-024 NCT02142738; KEYNOTE-042 NCT02220894 — both use >30 Gy within 6 months as threshold)*

10. **Significant cardiovascular disease:** Myocardial infarction, unstable angina, significant cardiac arrhythmia, stroke, or transient ischaemic attack within 6 months prior to first dose; NYHA Class III or IV congestive heart failure; QTcF >480 ms on screening ECG.

11. **Major surgery:** Major surgical procedure (defined as any procedure requiring general anaesthesia) within 28 days prior to the first dose of study treatment, or inadequate recovery from a prior surgical procedure. Minor procedures (e.g., port placement, biopsy under local anaesthesia) are permitted.

12. **Live vaccine:** Administration of a live attenuated vaccine within 30 days prior to the first dose of study drug or anticipation that such a live attenuated vaccine will be required during the study or within 90 days after the last dose.

13. **Pregnancy or breastfeeding:** Female patients who are pregnant or breastfeeding.

14. **Known hypersensitivity:** Known hypersensitivity to torivumab, placebo components, or any excipients of the formulation.

15. **Concurrent participation:** Current enrolment in another investigational study, or receipt of any investigational agent within 4 weeks (or 5 half-lives, whichever is longer) prior to first dose.

---

## 5. TREATMENT

### 5.1 Investigational Medicinal Products

| Product | Description | Presentation | Storage |
|---|---|---|---|
| Torivumab | Anti-PD-L1 humanised IgG1 mAb | 200 mg/10 mL (20 mg/mL) concentrate for IV infusion | 2°C–8°C, protected from light |
| Placebo | Matching placebo | Matching volume, identical appearance | 2°C–8°C, protected from light |

Torivumab is supplied as a sterile, preservative-free, concentrated solution of 200 mg/10 mL (20 mg/mL) in a single-dose vial. Excipients: L-histidine, L-histidine hydrochloride monohydrate, sucrose, polysorbate 80, water for injection. Prior to administration, each vial must be diluted in 0.9% sodium chloride to a final concentration of 2–10 mg/mL and administered as an intravenous infusion over 30 minutes (±10 minutes). Full pharmaceutical specifications, storage conditions, and infusion compatibility data are provided in the Investigator's Brochure (IB) and the IMP Pharmacy Manual. *(Fictional — for simulation purposes)*

### 5.2 Dosing and Administration

- **Torivumab:** 200 mg administered as an intravenous infusion over 30 minutes, on Day 1 of each 21-day cycle.
- **Placebo:** Matching placebo administered as an intravenous infusion over 30 minutes, on Day 1 of each 21-day cycle.
- Maximum treatment duration: 35 cycles (~2 years).
- Pre-medication (e.g., antihistamines, corticosteroids) is not required as routine pre-medication but may be administered at the Investigator's discretion for the management of infusion reactions.

Pre-medication is not mandated at study start, consistent with the PD-L1 inhibitor class profile. If infusion-related reactions (IRRs) are observed at a rate exceeding 5% Grade ≥2 in the first 50 treated patients, the Safety Monitoring Committee (SMC) will review and may recommend a protocol amendment to mandate pre-medication. This trigger is pre-specified in the SMC charter.

### 5.3 Dose Modifications

Unlike cytotoxic chemotherapy, torivumab (an immune checkpoint inhibitor) **does not permit dose reductions**. Management of toxicity is achieved through treatment delays or permanent discontinuation based on the type and severity of adverse events.

#### 5.3.1 Treatment Delays

| AE Grade (CTCAE v5.0) | Action |
|---|---|
| Grade 2 (select irAEs) | Hold torivumab; initiate supportive care; resume when resolved to Grade ≤1 |
| Grade 3 (non-life-threatening) | Hold torivumab; initiate corticosteroids as appropriate; resume if recovered to Grade ≤1 within 12 weeks |
| Grade 4 (any) | Permanently discontinue torivumab (see Section 5.3.2) |

A maximum treatment delay of **12 weeks** is permitted. If the toxicity does not resolve to Grade ≤1 within 12 weeks, torivumab must be permanently discontinued.

#### 5.3.2 Permanent Discontinuation Criteria

Torivumab must be permanently discontinued in the event of any of the following:
- Grade 3 or 4 immune-related pneumonitis
- Grade 4 immune-related hepatitis (or Grade 3 hepatitis not responding to high-dose corticosteroids)
- Grade 3 or 4 colitis or diarrhoea not responsive to treatment
- Grade ≥3 infusion reactions (subsequent rechallenge may be considered for Grade 3 at Investigator's discretion following consultation with Sponsor Medical Monitor)
- Any Grade 4 irAE
- Requirement for >40 mg prednisone equivalent/day for >12 weeks
- Inability to reduce corticosteroid dose to ≤10 mg prednisone equivalent/day within 12 weeks
- Recurrence of Grade 3 irAE after treatment resumption
- Any other toxicity that, in the Investigator's clinical judgment, contraindicates further treatment

[NOTE: Specific irAE management algorithms by organ system are detailed in Section 9.3. The dose modification table above is a summary; the irAE management guidance in Section 9.3 takes precedence.]

### 5.4 Concomitant Medications

#### 5.4.1 Permitted

- Supportive care medications (antiemetics, analgesics, growth factors per ASCO/ESMO guidelines)
- Therapeutic anticoagulation (enoxaparin, warfarin, DOACs) for documented thromboembolic events
- Bisphosphonates or RANK-L inhibitors for bone metastases
- Corticosteroids for irAE management per protocol irAE guidelines
- Hormone replacement therapy (stable dose)
- Inhaled corticosteroids for asthma/COPD

#### 5.4.2 Prohibited

- Any other concurrent anti-cancer therapy (chemotherapy, targeted therapy, immunotherapy, antibody-drug conjugates, radiotherapy [except palliative single-fraction radiation])
- Live attenuated vaccines
- Systemic immunosuppressive agents (except as directed for irAE management)
- Strong CYP inhibitors or inducers are not expected to affect torivumab exposure, as monoclonal antibodies are not metabolised via CYP450 pathways. A formal drug interaction assessment is provided in the Investigator's Brochure. No dose adjustments are required for concomitant CYP-active medications.

---

## 6. EFFICACY ASSESSMENTS

### 6.1 Tumour Assessment Schedule

Tumour imaging assessments will be performed by computed tomography (CT) with contrast (or MRI if CT is contraindicated) of the chest, abdomen, and pelvis (and brain if clinically indicated or if brain metastases present at baseline).

| Timepoint | Assessment |
|---|---|
| Screening (within 28 days before Cycle 1 Day 1) | Baseline imaging |
| Cycle 3 Day 1 (Week 6, ±7 days) | First on-treatment assessment |
| Cycle 5 Day 1 (Week 12, ±7 days) | Second on-treatment assessment |
| Every 6 weeks (±7 days) for the first 12 months | Imaging Q6W |
| Every 12 weeks (±7 days) from Month 12 onwards | Imaging Q12W |
| End of Treatment (EOT) | Imaging at EOT (unless performed within 6 weeks) |
| Disease Progression | Confirmed at subsequent scan ≥4 weeks later when possible |

The assessment frequency (Q6W for first year, Q12W thereafter) is aligned with PFS event capture requirements and standard ICI trial practice, consistent with KEYNOTE-024 and contemporary first-line NSCLC trials. The BICR vendor will be contracted to support this imaging schedule; imaging protocol specifications will be provided in a separate BICR charter.

### 6.2 Response Evaluation — RECIST Version 1.1

All tumour response assessments will be performed by a **Blinded Independent Central Review (BICR)** committee according to RECIST Version 1.1 criteria. Investigator assessments will be performed in parallel and will serve as supportive data for PFS (and may trigger local clinical decisions including discontinuation for progression).

**Response categories (RECIST 1.1):**

| Category | Abbreviation | Definition |
|---|---|---|
| Complete Response | CR | Disappearance of all target lesions; any pathological lymph nodes must have reduction in short axis to <10 mm |
| Partial Response | PR | ≥30% decrease in the sum of diameters of target lesions from baseline |
| Stable Disease | SD | Neither sufficient shrinkage for PR nor sufficient increase for PD |
| Progressive Disease | PD | ≥20% increase in sum of diameters of target lesions from nadir AND absolute increase ≥5 mm; or appearance of new lesions |

**Confirmation of response:** CR and PR must be confirmed by a repeat assessment ≥4 weeks later.

**Endpoint definitions:**

- **OS:** Time from randomisation to death from any cause. Patients not known to have died at data cut-off will be censored at the date last known alive.
- **PFS:** Time from randomisation to the first documented disease progression per RECIST 1.1 (BICR) or death from any cause, whichever occurs first. Patients without progression or death will be censored at the last adequate tumour assessment.
- **ORR:** Proportion of patients with best overall response of CR or PR.
- **DoR:** Time from first documented CR or PR to first documented disease progression or death from any cause in responding patients.
- **DCR:** Proportion of patients with best overall response of CR, PR, or SD (maintained ≥8 weeks).

The DCR SD requirement of ≥8 weeks is consistent with RECIST 1.1 guidance and standard practice in first-line NSCLC immunotherapy trials to avoid counting transient or pseudo-progression as disease control. This threshold is pre-specified and will be documented in the SAP.

---

## 7. SAFETY ASSESSMENTS

### 7.1 Adverse Event Monitoring

All adverse events (AEs) will be monitored from the time of informed consent until 90 days after the last dose of study drug (or until initiation of new anti-cancer therapy, whichever occurs first). AEs will be graded using the **National Cancer Institute Common Terminology Criteria for Adverse Events (CTCAE) Version 5.0** and coded using MedDRA (latest version at study initiation).

**AE definitions:**
- **Adverse Event (AE):** Any untoward medical occurrence in a study participant administered an IMP, whether or not considered related to study drug.
- **Serious Adverse Event (SAE):** Any AE that results in death, is life-threatening, requires hospitalisation or prolongation of existing hospitalisation, results in persistent or significant disability/incapacity, is a congenital anomaly/birth defect, or is medically significant.
- **Adverse Event of Special Interest (AESI):** Immune-related AEs (irAEs) and infusion-related reactions (IRRs), as defined in Section 7.3.

### 7.2 Safety Assessment Schedule

| Assessment | Screening | Cycle 1 Day 1 | Day 1 Each Subsequent Cycle | EOT | 30-day Safety | 90-day Safety |
|---|---|---|---|---|---|---|
| Physical examination | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| ECOG PS | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| Vital signs | ✓ | Pre/post-infusion | Pre/post-infusion | ✓ | ✓ | — |
| 12-lead ECG | ✓ | — | C3, C5, then Q6 cycles | ✓ | — | — |
| Haematology | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Chemistry (LFTs, creatinine) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Thyroid function (TSH, fT4) | ✓ | — | C3, C5, then Q12 weeks | ✓ | ✓ | — |
| Cortisol (AM) | ✓ | — | If clinically indicated | — | — | — |
| Urinalysis | ✓ | — | C3, C5, then Q6 cycles | ✓ | — | — |
| Pregnancy test (serum) | ✓ (FOCBP) | — | Q6 weeks (FOCBP) | ✓ | — | — |
| AE/SAE assessment | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Concomitant medications | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

[NOTE: Full Schedule of Assessments (SoA) to be presented as a formal table in the final protocol body. The above is a synopsis-level summary. FOCBP = Female of Childbearing Potential.]

### 7.3 Immune-Related Adverse Events (irAE) Management

Torivumab, as a PD-L1 inhibitor, carries a recognised risk of immune-related adverse events resulting from non-specific activation of the immune system. The following management algorithms are based on current clinical guidelines (ASCO, ESMO, SITC) and will be operationalised in a separate **irAE Management Guideline** document provided to all study sites.

The irAE management guidance below reflects current standard of care for PD-1/PD-L1 inhibitors, based on ASCO, ESMO, and SITC published guidelines. As torivumab is an investigational agent, class-level guidance is applied. Any unique or unexpected safety signals observed during early enrolment will be reviewed by the SMC and may trigger a protocol amendment.

#### 7.3.1 Immune-Related Pneumonitis

Pneumonitis is a potentially life-threatening irAE with class incidence of approximately 3–5% (all grades) and 1–2% (Grade ≥3) for PD-L1 inhibitors in NSCLC.

| Grade (CTCAE v5.0) | Definition | Management |
|---|---|---|
| Grade 1 | Asymptomatic; radiographic findings only | Hold torivumab; close monitoring; repeat imaging in 3–4 weeks; pulmonology consultation |
| Grade 2 | Symptomatic; limiting instrumental ADL | Hold torivumab; prednisone 1 mg/kg/day (or equivalent); taper over ≥4–6 weeks; resume if resolved to Grade ≤1 |
| Grade 3 | Severe symptoms; limiting self-care ADL; hospitalisation | Permanently discontinue torivumab; IV methylprednisolone 1–2 mg/kg/day; if no improvement in 48h: add infliximab or MMF; pulmonology/ID consult |
| Grade 4 | Life-threatening | Permanently discontinue torivumab; IV methylprednisolone 2 mg/kg/day; ICU-level care; consider IVIG, infliximab |

#### 7.3.2 Immune-Related Colitis/Diarrhoea

Immune-related colitis incidence: ~1–3% all grades for PD-L1 inhibitors.

| Grade | Definition | Management |
|---|---|---|
| Grade 1 | <4 stools/day increase over baseline | Continue torivumab; supportive care (hydration, loperamide); close monitoring |
| Grade 2 | 4–6 stools/day increase; limiting instrumental ADL | Hold torivumab; prednisone 1 mg/kg/day; taper over ≥4–6 weeks; GI consultation; stool cultures to exclude infectious aetiology |
| Grade 3 | ≥7 stools/day; hospitalisation; limiting self-care ADL | Permanently discontinue torivumab; IV methylprednisolone 1–2 mg/kg/day; if no improvement in 72h: infliximab 5 mg/kg (if no perforation, sepsis); colonoscopy |
| Grade 4 | Life-threatening consequences | Permanently discontinue; IV high-dose steroids; infliximab or vedolizumab; surgical consultation |

#### 7.3.3 Immune-Related Hepatitis

Immune-related hepatitis incidence: ~2–10% (all grades); ~1–2% Grade ≥3.

| Grade | AST/ALT Elevation | Management |
|---|---|---|
| Grade 1 | >ULN–3× ULN | Continue torivumab; increase LFT monitoring to weekly; investigate alternative causes |
| Grade 2 | >3–5× ULN | Hold torivumab; prednisone 0.5–1 mg/kg/day; weekly LFT monitoring; GI/hepatology consult |
| Grade 3 | >5–20× ULN | Permanently discontinue torivumab; IV methylprednisolone 1–2 mg/kg/day; hepatology consult; liver biopsy may be required |
| Grade 4 | >20× ULN | Permanently discontinue; IV high-dose steroids; hepatology consult; assess for transplant need |

#### 7.3.4 Immune-Related Endocrinopathies

**Thyroid disorders** (hypothyroidism/hyperthyroidism/thyroiditis): Most common irAE class with anti-PD-L1 agents; incidence up to 10–15% for thyroid abnormalities of any grade.

- **Hypothyroidism:** Initiate levothyroxine replacement per endocrinology guidance; torivumab may be continued in most cases (hold for Grade 3–4 symptomatic hypothyroidism).
- **Hyperthyroidism/thyroiditis:** Beta-blockers for symptomatic relief; propylthiouracil or methimazole if indicated; hold torivumab for Grade ≥2; endocrinology consultation.

**Adrenal insufficiency/adrenal crisis:** Incidence ~1–2%. Presentations may be insidious. Screening cortisol at baseline. If adrenal insufficiency confirmed:
- Hold torivumab; stress-dose hydrocortisone for crisis.
- Long-term corticosteroid replacement; permanent discontinuation of torivumab for Grade ≥3.
- Endocrinology consultation mandatory.

**Hypophysitis:** Incidence <1% for anti-PD-L1 agents (higher with anti-CTLA-4). MRI pituitary if clinically suspected. Hormone replacement as needed; torivumab may be resumed if ≤Grade 2 after hormone replacement initiated.

**Type 1 Diabetes Mellitus (new onset or acute exacerbation):** Check glucose and HbA1c; endocrinology consultation; insulin therapy; hold torivumab for Grade ≥3 hyperglycaemia.

#### 7.3.5 Infusion-Related Reactions (IRRs)

IRR incidence: approximately 1–5% for anti-PD-L1 antibodies.

| Grade | Symptoms | Management |
|---|---|---|
| Grade 1 | Mild (flushing, rash, fever <38°C, chills) | Slow infusion rate by 50%; antihistamine; monitor closely; complete infusion if resolves |
| Grade 2 | Moderate (urticaria, dyspnoea, hypotension responsive to fluids) | Stop infusion; supportive care (antihistamine, IV fluids, paracetamol); resume at 50% rate when resolved; consider pre-medication for subsequent cycles |
| Grade 3 | Severe (bronchospasm, hypotension requiring vasopressors, angioedema, anaphylaxis) | Permanently discontinue torivumab; epinephrine, IV fluids, bronchodilators as appropriate; medical emergency management |
| Grade 4 | Life-threatening | Permanently discontinue; emergency medical management; epinephrine, resuscitation |

**Pre-medication:** Not mandated routinely. Pre-medication with antihistamine (±paracetamol) should be considered for all subsequent cycles following a Grade 1–2 IRR.

### 7.4 Adverse Events of Special Interest (AESIs)

The following AESIs will be prospectively tracked with enhanced monitoring and reported to the Sponsor within 24 hours of Investigator awareness:

- Immune-related pneumonitis (any grade)
- Immune-related hepatitis (Grade ≥2)
- Immune-related colitis (Grade ≥2)
- Immune-related endocrinopathies (Grade ≥2)
- Immune-related nephritis
- Immune-related myocarditis (irrespective of grade — potentially life-threatening; immediate cardiology assessment required)
- Immune-related neurological toxicities (encephalitis, meningitis, Guillain-Barré syndrome)
- Immune-related dermatological toxicities (Stevens-Johnson Syndrome, Toxic Epidermal Necrolysis)
- Infusion-related reactions (Grade ≥2)

Immune-related myocarditis is rare (<1%) but carries high mortality with PD-1/PD-L1 inhibitors. The SMC charter pre-specifies an enhanced review trigger: any confirmed or suspected Grade ≥2 immune-related myocarditis will trigger an expedited unblinded SMC review within 5 business days of notification. A stopping rule will be applied if the incidence of Grade ≥3 myocarditis exceeds 1% in the torivumab arm at any interim review.

### 7.5 Safety Monitoring Committee

An independent **Safety Monitoring Committee (SMC)**, also referred to as a Data Safety Monitoring Board (DSMB), will be constituted prior to study initiation. The SMC will conduct periodic unblinded safety reviews at predetermined intervals (at minimum every 6 months, or triggered by specific safety signals). The SMC charter will define:
- Stopping rules (safety)
- SAE signal thresholds
- Communication procedures with the Sponsor and regulatory authorities

---

## 8. STATISTICAL CONSIDERATIONS

### 8.1 Sample Size Justification

**Primary endpoint:** Overall Survival (OS)

**Statistical assumptions:**

| Parameter | Value | Source/Basis |
|---|---|---|
| Hazard Ratio (HR) for OS | 0.65 | Benchmarked to KEYNOTE-024 (pembrolizumab vs chemotherapy; first-line NSCLC PD-L1 TPS ≥50%) |
| Control arm median OS | 14.0 months | Aligned with contemporary first-line NSCLC placebo/chemotherapy historical data |
| Experimental arm median OS | 21.5 months | Derived: HR = 0.65 → median OS experimental = 14.0 / 0.65 ≈ 21.5 months |
| Accrual period | 18 months | Operational assumption based on global site network |
| Minimum follow-up | 24 months | Post-accrual follow-up to accumulate required events |
| Total study duration | ~42 months | 18 months accrual + 24 months minimum follow-up |
| Dropout rate | ~10% | Standard assumption; accounts for withdrawal of consent and loss to follow-up |
| Two-sided alpha (α) | 0.05 | — |
| Power (1−β) | 80% | — |
| Randomisation ratio | 2:1 | Torivumab : Placebo |

**Events required calculation:**

Using the log-rank test under an exponential survival assumption:

Number of events (d) required:

```
d = (Z_α/2 + Z_β)² / [p₁ × p₂ × (log HR)²]

where:
  Z_α/2 = 1.960 (two-sided α = 0.05)
  Z_β   = 0.842 (power = 80%)
  p₁    = 2/3 (proportion in torivumab arm)
  p₂    = 1/3 (proportion in placebo arm)
  HR    = 0.65
  log HR = ln(0.65) = −0.4308

d = (1.960 + 0.842)² / [4/9 × (−0.4308)²]
  = (2.802)² / [0.4444 × 0.1856]
  = 7.851 / 0.08248
  ≈ 95.2 ... per equal allocation formula

Adjusted for 2:1 allocation:
  d = 4 × (1.960 + 0.842)² / (log HR)²
    = 4 × 7.851 / 0.18560
    = 31.404 / 0.18560
    ≈ 315 events
```

Rounding up and applying a modest correction for dropout (×10% inflation):
**Required OS events: ~320 deaths**

The formula applied is the standard Schoenfeld (1981) formula for log-rank test sample size. The result of ~320 events is internally consistent with the stated assumptions. The calculation will be independently verified using validated statistical software (nQuery Advisor or equivalent) and the exact software output documented in the Statistical Analysis Plan (SAP).

**Sample size calculation:**

Given the accrual (18 months) and follow-up (24 months) timeline, and using actuarial methods to project event accumulation under exponential survival with the stated hazard rates:

Expected event probability per arm at analysis:
- Placebo arm: Exponential with median 14.0 months → λ_ctrl = ln(2)/14.0 = 0.0495/month
- Torivumab arm: Exponential with median 21.5 months → λ_exp = ln(2)/21.5 = 0.0322/month

Proportion of patients expected to have died by data cut-off (approximately 42 months from study start, averaging ~33 months from randomisation):
- Placebo: ~78% (P(event) = 1 − e^(−0.0495 × 33) ≈ 0.80)
- Torivumab: ~65% (P(event) = 1 − e^(−0.0322 × 33) ≈ 0.65)

Overall event probability (weighted 2:1): (0.65 × 2 + 0.80 × 1) / 3 ≈ 0.70

Required sample size = Events required / Overall event probability = 320 / 0.70 ≈ 457 patients

Inflated for 10% dropout: 457 / 0.90 ≈ 508 patients

The planned enrolment target of 450 subjects is fixed. This study is **event-driven**: enrolment will be capped at 450 subjects (300 torivumab : 150 placebo), and the study timeline will flex as required to accumulate the 320 OS events needed to trigger the primary analysis. If event accumulation is slower than projected, the follow-up period will be extended accordingly. The DSMB will confirm event-driven analysis triggers at each interim review. This approach is consistent with standard Phase 3 oncology trial design and aligned with the KEYNOTE-024 precedent.

**Final planned sample size: 450 subjects (300 torivumab : 150 placebo)**

### 8.2 Analysis Populations

| Population | Definition |
|---|---|
| **Intent-to-Treat (ITT)** | All randomised patients, analysed according to randomised treatment assignment regardless of actual treatment received. **Primary analysis population for OS and PFS.** |
| **Safety Population** | All patients who received at least one dose (or partial dose) of study drug, analysed according to actual treatment received. |
| **Per-Protocol (PP)** | All ITT patients without major protocol deviations that could have affected the primary efficacy assessment. Definition of major deviations to be pre-specified in the SAP. **Supportive analysis for OS.** |
| **Response Evaluable Population** | All patients in the ITT population who have at least one post-baseline tumour assessment or who experienced clinical progression prior to the first post-baseline assessment. Used for ORR analyses. |

### 8.3 Primary Analysis — Overall Survival

OS will be compared between treatment arms using a **stratified log-rank test**, stratified by the randomisation stratification factors (histology and geographic region). The primary analysis will be conducted when approximately **320 deaths** have occurred in the ITT population.

A **stratified Cox proportional hazards model** will be used to estimate the OS Hazard Ratio (HR) and its 95% confidence interval, with the same stratification factors as covariates.

Kaplan-Meier estimates of median OS and survival probability at predefined timepoints (12, 18, 24 months) will be presented with 95% confidence intervals (Greenwood formula).

### 8.4 Secondary Analyses

- **PFS:** Stratified log-rank test; stratified Cox PH model; Kaplan-Meier estimates. BICR as primary PFS assessment; Investigator assessment as sensitivity analysis.
- **ORR:** Comparison between arms using Cochran-Mantel-Haenszel (CMH) test stratified by histology and region; 95% CI using Clopper-Pearson method.
- **DoR and DCR:** Descriptive statistics; Kaplan-Meier for DoR; CMH for DCR.
- **Safety:** Descriptive summaries of AE incidence by preferred term, system organ class, and CTCAE grade.

### 8.5 Multiplicity Control

To control the familywise type I error rate across the primary and key secondary endpoints, a **graphical testing procedure (Maurer-Bretz closed testing framework)** will be applied in the following hierarchical sequence:

1. Overall Survival (OS) — α = 0.05 (two-sided)
2. Progression-Free Survival (PFS) — full α propagated from OS if significant
3. Objective Response Rate (ORR) — full α propagated from PFS if significant
4. Duration of Response (DoR) — tested sequentially thereafter

The exact multiplicity procedure — including alpha propagation rules, weights, and transition matrix — will be fully pre-specified in the SAP prior to database lock. The graphical testing procedure will be validated by the study statistician and reviewed by the independent statistician before the SAP is finalised.

### 8.6 Interim Analyses

**Interim Analysis 1 (IA1) — Futility and Safety Review:**
- Timing: When approximately 50% of required OS events (~160 deaths) have occurred.
- Purpose: Futility assessment only (not superiority). The study will be recommended for continuation unless the conditional power for OS falls below 10%.
- No alpha penalty applied at IA1.

**Interim Analysis 2 (IA2) — Efficacy Interim:**
- Timing: When approximately 75% of required OS events (~240 deaths) have occurred.
- Purpose: Potential early stopping for efficacy.
- Alpha spent using **O'Brien-Fleming spending function** (Lan-DeMets implementation).
- Approximate boundary at IA2: p < 0.00100 (two-sided; exact value to be determined by spending function in SAP).

**Final Analysis:**
- Timing: When approximately 320 OS deaths have occurred.
- Remaining alpha spent at final analysis: two-sided p < 0.0464 (approximate, based on O'Brien-Fleming allocation).

Exact alpha spending boundaries will be computed by the independent statistician using the O'Brien-Fleming spending function and presented in both the SAP and SMC charter prior to the first interim analysis. All interim analyses will be conducted by an independent unblinded statistician; results will be communicated to the SMC only, maintaining sponsor and investigator blinding.

---

## 9. ETHICAL CONSIDERATIONS

### 9.1 Regulatory and Good Clinical Practice Compliance

This study will be conducted in accordance with:
- **ICH E6(R2):** Good Clinical Practice (GCP)
- **ICH E8(R1):** General Considerations for Clinical Trials
- **ICH E9:** Statistical Principles for Clinical Trials
- **ICH E9(R1):** Addendum on Estimands and Sensitivity Analysis in Clinical Trials
- **ICH E17:** General Principles for Planning and Design of Multi-Regional Clinical Trials
- **Declaration of Helsinki** (2013 revision)
- All applicable national and local regulatory requirements

### 9.2 Institutional Review Board / Independent Ethics Committee (IRB/IEC)

Prior to initiation at any study site, the final protocol, protocol synopsis, patient information sheet/informed consent form (PIS/ICF), and all other relevant documents must be reviewed and approved by the relevant IRB/IEC. No patient may be enrolled prior to receipt of written IRB/IEC approval.

Any protocol amendments that require IRB/IEC review must be submitted and approved before implementation at the affected sites (unless the amendment is required to eliminate an immediate hazard to participants).

### 9.3 Informed Consent

Informed consent must be obtained from all participants prior to any study-specific procedures, in accordance with ICH E6(R2). The ICF must:
- Be written in plain language accessible to the study population.
- Describe the nature of the study, procedures, risks, and benefits.
- Explain the voluntary nature of participation and the right to withdraw at any time without penalty.
- Include specific consent for optional biomarker sampling (if applicable).
- Comply with all applicable local language and literacy requirements.

The process of obtaining and documenting informed consent must be described in the site's Standard Operating Procedures (SOPs) and documented in the source records and CRF.

For countries where a legally authorised representative may provide consent on behalf of a patient who lacks capacity, site-specific local consent procedures will be documented in a country-specific consent addendum and approved by the relevant local IRB/IEC prior to site activation.

### 9.4 Data Privacy and Confidentiality

All patient data will be handled in accordance with applicable data privacy legislation (e.g., GDPR in the European Union, HIPAA in the United States, and equivalent local regulations). Patient data will be pseudonymised. The master identification code list will be maintained securely at the study site and access restricted to authorised personnel.

### 9.5 Risk-Benefit Assessment

Based on the established clinical activity of PD-L1 checkpoint inhibitors in first-line NSCLC with PD-L1 TPS ≥50%, and the known manageable irAE profile of this drug class, the anticipated benefit of torivumab in improving OS and PFS in this population is considered to outweigh the known risks. All patients will receive comprehensive safety monitoring and irAE management support as described in this protocol.

The risk-benefit assessment is based on Phase 1/2 data (CTX-001, CTX-002) demonstrating an ORR of 44.9% and manageable safety profile in the target population, benchmarked against the established PD-L1 inhibitor class. The benefit of durable anti-tumour responses in a poor-prognosis population is considered to outweigh the identified risks of irAEs, which are manageable with established algorithms. *(Synthetic — educational simulation only)*

---

## 10. KEY INFORMATION FOR CRF DESIGN

The following Case Report Forms (CRFs) / electronic Data Collection Modules are required for this study. These should be developed in accordance with CDISC CDASH standards (v2.1 or later) and mapped to SDTMIG v3.4 domains at the point of specification.

| CRF Module | Key Variables | SDTM Domain |
|---|---|---|
| Demography | Age, sex, race, ethnicity, date of birth, country | DM |
| Informed Consent | Date of consent, version | DS |
| Eligibility Checklist | Inclusion/exclusion criteria confirmation (Y/N per item) | SC, DS |
| Medical History | Prior conditions, onset/resolution dates, ongoing flag | MH |
| Prior Anti-Cancer Therapy | Prior regimens, dates, reason for discontinuation | CM, TU |
| Concomitant Medications | Drug name, dose, route, indication, start/stop dates | CM |
| Randomisation | Randomisation date, treatment arm, IWRS confirmation | DS, SUPPDM |
| Study Drug Administration | Date, dose administered, infusion start/stop time, volume | EX |
| Dose Modifications | Reason for delay/discontinuation, action taken | DS, SUPPEX |
| Tumour Assessment (RECIST 1.1) | Lesion measurements by timepoint, target/non-target, new lesion | TU, TR, RS |
| Overall Response | Best overall response, dates | RS |
| Adverse Events | MedDRA term, start/stop date, severity (CTCAE grade), relationship, action | AE, SUPPAE |
| Serious Adverse Events | SAE flag, seriousness criteria, outcome, narrative | AE, SUPPAE |
| irAE Module | irAE type, grade, management (steroids, biologics, dose), resolution | AE, SUPPAE |
| Laboratory Results | Haematology, chemistry, thyroid, urinalysis — value, unit, reference range | LB |
| Vital Signs | BP, HR, temperature, weight, height | VS |
| ECG | QTcF, PR, QRS, RhythmH findings | EG |
| ECOG Performance Status | Score, date | FA |
| Pregnancy | Pregnancy status, outcome if applicable | PR |
| Survival Follow-Up | Date of last contact, vital status, cause of death | DS, SUPPDS |
| Patient-Reported Outcomes | EORTC QLQ-C30, QLQ-LC13, EQ-5D-5L — item-level responses | QS |
| Biomarker / Tissue Collection | Sample type, collection date, result (PD-L1 TPS, TMB) | MB, BS |
| Pharmacokinetics (optional) | PK sample time, collection date, analyte concentration | PC |

CRF design will be reviewed by a CDISC-certified data manager prior to EDC build. A CDASH-annotated CRF (aCRF) will be prepared alongside the CRF and submitted as part of the regulatory submission package. An Edit Check Specification (ECS) document will be developed to enforce data quality at point of entry in Medidata Rave.

---

## 11. KEY INFORMATION FOR STATISTICAL ANALYSIS PLAN

The following statistical methods and analysis components are required in the Statistical Analysis Plan (SAP) for CTX-NSCLC-301. The SAP must be finalised and locked **prior to database lock and unblinding**.

| Analysis Area | Methods Required |
|---|---|
| **Primary OS analysis** | Stratified log-rank test; stratified Cox PH model (HR + 95% CI); Kaplan-Meier curves with 95% CI bands; log-log transformation for CI; Greenwood formula |
| **PFS analysis** | Same as OS; BICR primary; Investigator assessment sensitivity; competing risks analysis (death without progression as competing event) |
| **ORR / DCR** | CMH test stratified by histology and region; Clopper-Pearson 95% CI; Wilson score CI as sensitivity |
| **DoR** | Kaplan-Meier; median with 95% CI; analysis restricted to responders (ORR population) |
| **Multiplicity control** | Graphical testing procedure (Maurer-Bretz); pre-specified in SAP with full transition matrix and alpha allocations |
| **Interim analyses** | O'Brien-Fleming spending function (Lan-DeMets); exact alpha boundaries at each IA; conditional power calculations |
| **Subgroup analyses** | Forest plot of OS HR for pre-specified subgroups: histology, region, sex, age (<65/≥65), ECOG PS (0/1), baseline PD-L1 TPS (50–74% vs ≥75%), TMB-high/low; treatment × subgroup interaction tests (exploratory) |
| **Estimands framework** | Define estimands per ICH E9(R1): target population, variable, population-level summary, intercurrent event handling strategy (e.g., treatment policy, hypothetical, composite) — for OS, PFS, ORR separately |
| **Sensitivity analyses for OS** | Landmark analysis at 12 and 24 months; weighted log-rank test; restricted mean survival time (RMST) |
| **Sensitivity analyses for PFS** | BICR-confirmed PFS (requiring radiological confirmation of progression); PFS by Investigator; PFS using PD-L1 central vs local testing |
| **Missing data handling** | For OS: minimal (death is the event; censoring rules pre-specified per Kaplan-Meier censoring conventions); for ORR: patients without post-baseline assessment counted as non-responders; for PROs: mixed models for repeated measures (MMRM) for continuous outcomes; multiple imputation as sensitivity |
| **Safety analyses** | Descriptive tables: AEs by PT, SOC, grade; TEAE/TRAE tables; irAE-specific tables; exposure-adjusted incidence rates; time to onset and resolution for irAEs |
| **PRO analyses** | MMRM for QLQ-C30 global health status; time to deterioration (TTD) using log-rank; minimally important difference (MID) thresholds per EORTC guidelines |
| **Biomarker/PK** | Exploratory; described in a separate Biomarker Analysis Plan (BAP) and PK analysis plan |
| **ADaM datasets required** | ADSL (subject-level), ADTTE (OS, PFS, DoR, TTD), ADRS (response/RECIST), ADAE (AEs/irAEs), ADLB (labs), ADVS (vitals), ADQS (PROs), ADPC (PK), ADEX (exposure) |
| **CDISC standards** | SDTMIG v3.4 (submission datasets); ADaMIG v1.3 (analysis datasets); define.xml v2.1; controlled terminology current at dataset lock |

A formal Define-XML v2.1 document and accompanying Reviewer's Guide will be prepared as part of the submission package. SDTM and ADaM domain mapping will be overseen by a CDISC-trained programming lead and validated using Pinnacle 21 Enterprise prior to submission.

---

## APPENDIX A — ABBREVIATIONS

| Abbreviation | Definition |
|---|---|
| ADaM | Analysis Data Model |
| AE | Adverse Event |
| AESI | Adverse Event of Special Interest |
| ALK | Anaplastic Lymphoma Kinase |
| ANC | Absolute Neutrophil Count |
| AST/ALT | Aspartate/Alanine Aminotransferase |
| BICR | Blinded Independent Central Review |
| BSA | Body Surface Area |
| CDx | Companion Diagnostic |
| CMH | Cochran-Mantel-Haenszel |
| CR | Complete Response |
| CRF | Case Report Form |
| CT | Computed Tomography |
| CTCAE | Common Terminology Criteria for Adverse Events |
| DCR | Disease Control Rate |
| DM | Demography (SDTM domain) |
| DoR | Duration of Response |
| DSMB | Data Safety

 Monitoring Board |
| eGFR | Estimated Glomerular Filtration Rate |
| ECOG PS | Eastern Cooperative Oncology Group Performance Status |
| EDC | Electronic Data Capture |
| EGFR | Epidermal Growth Factor Receptor |
| EOT | End of Treatment |
| EORTC | European Organisation for Research and Treatment of Cancer |
| EQ-5D-5L | EuroQol 5-Dimension 5-Level Questionnaire |
| FOCBP | Female of Childbearing Potential |
| GCP | Good Clinical Practice |
| HRQoL | Health-Related Quality of Life |
| HR | Hazard Ratio |
| ICF | Informed Consent Form |
| ICH | International Council for Harmonisation |
| ICI | Immune Checkpoint Inhibitor |
| IEC | Independent Ethics Committee |
| IHC | Immunohistochemistry |
| IMP | Investigational Medicinal Product |
| irAE | Immune-Related Adverse Event |
| IRB | Institutional Review Board |
| IRR | Infusion-Related Reaction |
| ITT | Intent-to-Treat |
| IWRS | Interactive Web Response System |
| LFT | Liver Function Test |
| LTFU | Long-Term Follow-Up |
| mAb | Monoclonal Antibody |
| MedDRA | Medical Dictionary for Regulatory Activities |
| MID | Minimally Important Difference |
| MMRM | Mixed Models for Repeated Measures |
| MRI | Magnetic Resonance Imaging |
| NSCLC | Non-Small Cell Lung Cancer |
| ORR | Objective Response Rate |
| OS | Overall Survival |
| PD | Progressive Disease |
| PD-1 | Programmed Death-1 |
| PD-L1 | Programmed Death-Ligand 1 |
| PFS | Progression-Free Survival |
| PIS | Patient Information Sheet |
| PK | Pharmacokinetics |
| PP | Per-Protocol |
| PR | Partial Response |
| PRO | Patient-Reported Outcome |
| RECIST | Response Evaluation Criteria in Solid Tumours |
| RMST | Restricted Mean Survival Time |
| SAE | Serious Adverse Event |
| SAP | Statistical Analysis Plan |
| SD | Stable Disease |
| SDTM | Study Data Tabulation Model |
| SMC | Safety Monitoring Committee |
| SoA | Schedule of Assessments |
| SOC | System Organ Class |
| TMB | Tumour Mutational Burden |
| TPS | Tumour Proportion Score |
| TTD | Time to Deterioration |
| ULN | Upper Limit of Normal |

---

## APPENDIX B — KEY REFERENCES

The following references are cited in this synopsis. Full citation details will be provided in the final protocol document in Vancouver format.

1. **KEYNOTE-024:** Reck M, et al. Pembrolizumab versus Chemotherapy for PD-L1–Positive Non–Small-Cell Lung Cancer. *N Engl J Med.* 2016;375:1823–1833.
2. **KEYNOTE-024 5-year update:** Reck M, et al. Five-Year Outcomes with Pembrolizumab versus Chemotherapy for Metastatic Non–Small-Cell Lung Cancer with PD-L1 Tumour Proportion Score ≥50%. *J Clin Oncol.* 2021;39:2339–2349.
3. **RECIST 1.1:** Eisenhauer EA, et al. New response evaluation criteria in solid tumours: Revised RECIST guideline (version 1.1). *Eur J Cancer.* 2009;45:228–247.
4. **CTCAE v5.0:** National Cancer Institute. Common Terminology Criteria for Adverse Events, Version 5.0. 2017.
5. **ICH E6(R2):** Good Clinical Practice: Integrated Addendum. 2016.
6. **ICH E9(R1):** Addendum on Estimands and Sensitivity Analysis in Clinical Trials. 2019.
7. **irAE Guidelines:** Brahmer JR, et al. Management of Immune-Related Adverse Events in Patients Treated With Immune Checkpoint Inhibitor Therapy. *J Clin Oncol.* 2018;36:1714–1768.
8. **SITC irAE Guidelines:** Puzanov I, et al. Managing toxicities associated with immune checkpoint inhibitors: consensus recommendations from the Society for Immunotherapy of Cancer (SITC) Toxicity Management Working Group. *J Immunother Cancer.* 2017;5:95.
9. **EORTC QLQ-C30:** Aaronson NK, et al. The European Organization for Research and Treatment of Cancer QLQ-C30: A Quality-of-Life Instrument for Use in International Clinical Trials in Oncology. *J Natl Cancer Inst.* 1993;85:365–376.
10. **Global Cancer Observatory 2022:** Sung H, et al. Global Cancer Statistics 2020. *CA Cancer J Clin.* 2021;71:209–249.

---

## DOCUMENT HISTORY

| Version | Date | Description of Changes |
|---|---|---|
| 1.1 | 30 March 2026 | ⚠️ CRITICAL: Updated all regulatory identifiers to obviously fictional formats. Added legal notices to prevent accidental regulatory/clinical use. |
| 1.0 | 22 March 2026 | Initial version — protocol synopsis for SIMULATED-TORIVUMAB-2026 |

---

> **SYNTHETIC DOCUMENT DISCLAIMER**
> This protocol synopsis is a synthetic educational document created for simulation and training purposes. Torivumab is a fictional investigational product; no real clinical, pharmacokinetic, or safety data exist for this compound. All efficacy assumptions are benchmarked to published clinical literature (KEYNOTE-024). This document must not be used for any actual regulatory submission, clinical investigation, or patient care.
>
> **Prepared by:** Nova (AI Assistant) on behalf of Lovemore Gakava, Celindra Therapeutics Study Team
> **For review by:** Lovemore Gakava
