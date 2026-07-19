# =============================================================================
# Program    : te.R
# Domain     : TE — Trial Elements
# SDTM IG ref: Section 7.2 (Trial Design)
# Reads from : (study-level constants; no subject data)
# Writes to  : datasets/sdtm/te.parquet
# Notes      : One record per planned trial element. ETCD <= 8 chars. Presence
#              of TE clears P21 SD1113 (Missing TE dataset).
# =============================================================================

library(dplyr)
library(arrow)

OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

elements <- tibble::tribble(
  ~ETCD,   ~ELEMENT,     ~TESTRL,                                 ~TEENRL,                                              ~TEDUR,
  "SCRN",  "Screening",  "Informed consent",                      "Randomization",                                      "P28D",
  "TRT",   "Treatment",  "First dose of study treatment",         "Last dose of study treatment or discontinuation",    NA,
  "FU",    "Follow-up",  "Discontinuation of study treatment",    "Death or end of study participation",                NA
)

sdtm_te <- elements |>
  transmute(
    STUDYID  = STUDYID,
    DOMAIN   = "TE",
    ETCD,
    ELEMENT,
    TESTRL,
    TEENRL,
    TEDUR
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_te, file.path(OUT_DIR, "te.parquet"))
message("TE written: ", nrow(sdtm_te), " element records")
