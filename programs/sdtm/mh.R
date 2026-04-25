# =============================================================================
# Program    : mh.R
# Domain     : MH — Medical History
# SDTM IG ref: Section 6.4
# Reads from : raw/medical_history.csv
# Writes to  : datasets/sdtm/mh.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "medical_history.csv"), stringsAsFactors = FALSE)

raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-"),
    MHTERM  = str_trim(CONDITION_VERBATIM),
    # Simplified coding: title-case of verbatim term
    MHDECOD = str_to_title(str_trim(CONDITION_VERBATIM)),
    MHCAT   = case_when(
      str_to_upper(str_trim(as.character(PREEXISTING))) %in%
        c("Y", "YES", "TRUE", "1") &
        str_detect(str_to_upper(str_trim(CONDITION_VERBATIM)),
                   "CANCER|CARCINOMA|TUMOU?R|MALIGNANCY|NSCLC|SCLC|MELANOMA|LYMPHOMA") ~
        "PRIMARY DIAGNOSIS",
      TRUE ~ "MEDICAL HISTORY"
    ),
    MHSTDTC = as.character(ONSET_DATE),
    MHPRESP = "Y",
    MHOCCUR = "Y",
    MHENRTPT = case_when(
      str_to_upper(str_trim(as.character(STATUS))) %in%
        c("ONGOING", "ACTIVE", "CURRENT") ~ "ONGOING",
      str_to_upper(str_trim(as.character(STATUS))) %in%
        c("RESOLVED", "INACTIVE", "PAST", "N") ~ "BEFORE",
      TRUE ~ NA_character_
    )
  ) |>
  arrange(USUBJID, MHSTDTC) |>
  group_by(USUBJID) |>
  mutate(MHSEQ = row_number()) |>
  ungroup()

sdtm_mh <- raw |>
  transmute(
    STUDYID,
    DOMAIN   = "MH",
    USUBJID,
    MHSEQ,
    MHTERM,
    MHDECOD,
    MHCAT,
    MHSTDTC,
    MHENRTPT,
    MHPRESP,
    MHOCCUR
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_mh, file.path(OUT_DIR, "mh.parquet"))
message("MH written: ", nrow(sdtm_mh), " records")
