# =============================================================================
# Program    : ts.R
# Domain     : TS — Trial Summary
# SDTM IG ref: Section 7.4 (Trial Design)
# Reads from : raw/demographics.csv, raw/disposition.csv (for study dates/counts)
# Writes to  : datasets/sdtm/ts.parquet
# Notes      : One record per trial-summary parameter (per value for FCNTRY).
#              TSPARM is the exact CDISC decode of TSPARMCD (P21 CT2002/CT2003);
#              coded TSVALs verified against CDISC CT 2026-03-27. Includes the
#              FDA-required parameter set (P21 SD22xx; SD2232 SSTDTC is a Reject).
# =============================================================================

library(dplyr)
library(arrow)

RAW_DIR <- "raw"
OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

dem  <- read.csv(file.path(RAW_DIR, "demographics.csv"), stringsAsFactors = FALSE)
disp <- read.csv(file.path(RAW_DIR, "disposition.csv"),  stringsAsFactors = FALSE)

sstdtc <- as.character(min(suppressWarnings(as.Date(dem$INFORM_CONSENT_DATE)), na.rm = TRUE))
sendtc <- as.character(max(c(suppressWarnings(as.Date(disp$DISC_DATE)),
                             suppressWarnings(as.Date(disp$LAST_CONTACT_DATE)),
                             suppressWarnings(as.Date(disp$STUDY_COMPLETION_DATE))), na.rm = TRUE))
n_sub  <- nrow(dem)

# TSPARMCD -> (TSPARM decode, TSVAL). TSPARM must be the exact CDISC decode.
params <- tibble::tribble(
  ~TSPARMCD,  ~TSPARM,                                    ~TSVAL,
  "TITLE",    "Trial Title",                              "A Phase III, Randomized, Double-Blind Study of Torivumab Plus Chemotherapy Versus Placebo Plus Chemotherapy in Previously Untreated Advanced Non-Small Cell Lung Cancer",
  "STYPE",    "Study Type",                               "INTERVENTIONAL",
  "INTMODEL", "Intervention Model",                       "PARALLEL",
  "INTTYPE",  "Intervention Type",                        "BIOLOGIC",
  "PCLAS",    "Pharmacologic Class",                      "Programmed death receptor-1 blocking antibody",
  "TPHASE",   "Trial Phase Classification",               "PHASE III TRIAL",
  "TTYPE",    "Trial Type",                               "EFFICACY",
  "TBLIND",   "Trial Blinding Schema",                    "DOUBLE BLIND",
  "TCNTRL",   "Control Type",                             "PLACEBO",
  "TINDTP",   "Trial Intent Type",                        "TREATMENT",
  "RANDOM",   "Trial is Randomized",                      "Y",
  "ADDON",    "Added on to Existing Treatments",          "Y",
  "ADAPT",    "Adaptive Design",                          "N",
  "INDIC",    "Trial Disease/Condition Indication",       "Non-Small Cell Lung Cancer",
  "TDIGRP",   "Diagnosis Group",                          "Advanced or metastatic non-small cell lung cancer",
  "THERAREA", "Therapeutic Area",                         "Oncology",
  "OBJPRIM",  "Trial Primary Objective",                  "To compare overall survival between torivumab plus chemotherapy and placebo plus chemotherapy",
  "OBJSEC",   "Trial Secondary Objective",                "To compare progression-free survival, objective response rate, and safety",
  "OUTMSPRI", "Primary Outcome Measure",                  "Overall survival",
  "TRT",      "Investigational Therapy or Treatment",     "TORIVUMAB",
  "COMPTRT",  "Comparative Treatment Name",               "PLACEBO",
  "CURTRT",   "Current Therapy or Treatment",             "PLATINUM-BASED CHEMOTHERAPY",
  "NARMS",    "Planned Number of Arms",                   "2",
  "NCOHORT",  "Number of Groups/Cohorts",                 "1",
  "PLANSUB",  "Planned Number of Subjects",               "450",
  "ACTSUB",   "Actual Number of Subjects",                as.character(n_sub),
  "HLTSUBJI", "Healthy Subject Indicator",                "N",
  "SEXPOP",   "Sex of Participants",                      "BOTH",
  "AGEMIN",   "Planned Minimum Age of Subjects",          "P18Y",
  "AGEMAX",   "Planned Maximum Age of Subjects",          "P99Y",
  "LENGTH",   "Trial Length",                             "P36M",
  "SSTDTC",   "Study Start Date",                         sstdtc,
  "SENDTC",   "Study End Date",                           sendtc,
  "DCUTDTC",  "Data Cutoff Date",                         sendtc,
  "DCUTDESC", "Data Cutoff Description",                  "Primary analysis data cutoff",
  "STOPRULE", "Study Stop Rules",                         "Pre-specified interim and final overall-survival analyses per protocol; no formal stopping rule for harm beyond DSMB review",
  "ONGOSIND", "Ongoing Study Indicator",                  "N",
  "EXTTIND",  "Extension Trial Indicator",                "N",
  "PDSTIND",  "Pediatric Study Indicator",                "N",
  "PDPSTIND", "Pediatric Postmarket Study Indicator",     "N",
  "PIPIND",   "Pediatric Investigation Plan Indicator",   "N",
  "RDIND",    "Rare Disease Indicator",                   "N",
  "SDTMVER",  "SDTM Version",                             "1.7",
  "SDTIGVER", "SDTM IG Version",                          "3.4",
  "SPONSOR",  "Clinical Study Sponsor",                   "Simulated Sponsor (synthetic data)",
  "REGID",    "Registry Identifier",                      "NCT-SIMULATED-301"
)

# FCNTRY — one record per planned country (ISO 3166-1 alpha-3 / GENC)
countries <- sort(unique(toupper(trimws(dem$COUNTRY))))
ctry_map <- c("AUSTRALIA"="AUS","BRAZIL"="BRA","CANADA"="CAN","FRANCE"="FRA",
              "GERMANY"="DEU","ITALY"="ITA","JAPAN"="JPN","NETHERLANDS"="NLD",
              "POLAND"="POL","SOUTH KOREA"="KOR","SPAIN"="ESP",
              "UNITED KINGDOM"="GBR","UNITED STATES"="USA")
fcntry <- tibble::tibble(
  TSPARMCD = "FCNTRY",
  TSPARM   = "Planned Country of Investigational Sites",
  TSVAL    = unname(ctry_map[countries])
) |> filter(!is.na(TSVAL))

sdtm_ts <- bind_rows(params, fcntry) |>
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
  # NB: TSVALCD/TSVCDREF (Expected) are intentionally omitted (P21 SD0057,
  # accepted). Populating them triggers per-parameter content checks
  # (SD2240-SD2266) that require real reference-terminology codes — e.g. a UNII
  # for TRT — which do not exist for the synthetic investigational product.

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ts, file.path(OUT_DIR, "ts.parquet"))
message("TS written: ", nrow(sdtm_ts), " parameter records")
