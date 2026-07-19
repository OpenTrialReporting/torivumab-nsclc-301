# =============================================================================
# Program    : ts.R
# Domain     : TS — Trial Summary
# SDTM IG ref: Section 7.4 (Trial Design)
# Reads from : (study-level constants; no subject data)
# Writes to  : datasets/sdtm/ts.parquet
# Notes      : One record per trial-summary parameter. Coded TSVAL values are
#              verified against CDISC CT 2026-03-27 (Trial Phase / Trial Type /
#              Trial Blinding Schema / No Yes). Presence of TS clears P21 SD1115
#              (Missing TS dataset — Reject).
# =============================================================================

library(dplyr)
library(arrow)

OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

# One row per parameter: TSPARMCD, TSPARM (label), TSVAL (value)
params <- tibble::tribble(
  ~TSPARMCD,  ~TSPARM,                                   ~TSVAL,
  "TITLE",    "Trial Title",                             "A Phase III, Randomized, Double-Blind Study of Torivumab Plus Chemotherapy Versus Placebo Plus Chemotherapy in Previously Untreated Advanced Non-Small Cell Lung Cancer",
  "TPHASE",   "Trial Phase Classification",              "PHASE III TRIAL",
  "TTYPE",    "Trial Type",                              "EFFICACY",
  "TBLIND",   "Trial Blinding Schema",                   "DOUBLE BLIND",
  "RANDOM",   "Trial is Randomized",                     "Y",
  "ADDON",    "Added on to Existing Treatments",         "Y",
  "TCNTRL",   "Control Type",                            "PLACEBO",
  "TINDTP",   "Trial Indication Type",                   "TREATMENT",
  "INDIC",    "Trial Disease/Condition Indication",      "Non-Small Cell Lung Cancer",
  "TDIGRP",   "Diagnosis Group",                         "Advanced or metastatic non-small cell lung cancer",
  "OBJPRIM",  "Trial Primary Objective",                 "To compare overall survival between torivumab plus chemotherapy and placebo plus chemotherapy",
  "OBJSEC",   "Trial Secondary Objective",               "To compare progression-free survival, objective response rate, and safety",
  "TRT",      "Investigational Therapy or Treatment",    "TORIVUMAB",
  "COMPTRT",  "Comparative Treatment Name",              "PLACEBO",
  "NARMS",    "Planned Number of Arms",                  "2",
  "PLANSUB",  "Planned Number of Subjects",              "450",
  "AGEMIN",   "Planned Minimum Age of Subjects",         "P18Y",
  "AGEMAX",   "Planned Maximum Age of Subjects",         NA,
  "LENGTH",   "Trial Length",                            "P36M",
  "SPONSOR",  "Clinical Study Sponsor",                  "Simulated Sponsor (synthetic data)",
  "REGID",    "Registry Identifier",                     "NCT-SIMULATED-301"
)

sdtm_ts <- params |>
  filter(!is.na(TSVAL) & TSVAL != "") |>
  group_by(TSPARMCD) |>
  mutate(TSSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID  = STUDYID,
    DOMAIN   = "TS",
    TSSEQ,
    TSPARMCD,
    TSPARM,
    TSVAL
  ) |>
  arrange(TSPARMCD, TSSEQ)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ts, file.path(OUT_DIR, "ts.parquet"))
message("TS written: ", nrow(sdtm_ts), " parameter records")
