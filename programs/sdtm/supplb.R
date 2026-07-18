# torivumab guidelines loaded
# =============================================================================
# Program    : supplb.R
# Dataset    : SUPPLB — Supplemental Qualifiers for LB
# SDTM IG ref: Section 8.4
# Reads from : datasets/sdtm/lb.parquet
# Writes to  : datasets/sdtm/supplb.parquet
# Notes      : SUPPLB carries:
#                BIOMRKFL — Biomarker test indicator (Y for PD-L1, EGFR, ALK,
#                           ROS1, KRAS G12C, MET ex14, RET, BRAF V600E, NTRK,
#                           TMB; N otherwise)
#                CENTLBFL — Central lab indicator (Y for biomarkers and
#                           protocol-defined central tests; N otherwise)
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)
library(tidyr)

SDTM_DIR <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

lb <- as.data.frame(read_parquet(file.path(SDTM_DIR, "lb.parquet")))

biomarker_codes <- c(
  "PDL1", "PDL1TPS", "PD_L1_TPS",
  "EGFR", "EGFRMUT", "EGFR_MUT",
  "ALK", "ALKREARR", "ALK_REARR",
  "ROS1", "ROS1REARR", "ROS1_REARR",
  "KRAS", "KRASG12C", "KRAS_G12C",
  "METEX14", "MET_EX14",
  "RET", "RETREARR", "RET_REARR",
  "BRAF", "BRAFV600E", "BRAF_V600E",
  "NTRK", "NTRKFUSE", "NTRK_FUSE",
  "TMB"
)

lb_flagged <- lb |>
  mutate(
    LBTESTCD_UP = str_to_upper(str_trim(LBTESTCD)),
    BIOMRKFL    = ifelse(LBTESTCD_UP %in% biomarker_codes, "Y", "N"),
    CENTLBFL   = ifelse(BIOMRKFL == "Y", "Y", "N")
  )

supp_long <- lb_flagged |>
  pivot_longer(
    cols      = c(BIOMRKFL, CENTLBFL),
    names_to  = "QNAM",
    values_to = "QVAL"
  ) |>
  transmute(
    STUDYID  = STUDYID,
    RDOMAIN  = "LB",
    USUBJID,
    IDVAR    = "LBSEQ",
    IDVARVAL = as.character(LBSEQ),
    QNAM,
    QLABEL   = case_when(
      QNAM == "BIOMRKFL"  ~ "Biomarker Test Indicator",
      QNAM == "CENTLBFL" ~ "Central Lab Indicator"
    ),
    QVAL,
    QORIG    = "DERIVED",
    QEVAL    = ""
  ) |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(supp_long, file.path(SDTM_DIR, "supplb.parquet"))
message("SUPPLB written: ", nrow(supp_long), " records (",
        n_distinct(supp_long$USUBJID), " subjects, ",
        n_distinct(supp_long$QNAM), " QNAMs)")
