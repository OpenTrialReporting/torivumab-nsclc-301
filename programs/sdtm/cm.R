# =============================================================================
# Program    : cm.R
# Domain     : CM — Concomitant Medications
# SDTM IG ref: Section 6.2
# Reads from : raw/conmed.csv, raw/codelists/atc_conmed.csv
# Writes to  : datasets/sdtm/cm.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "conmed.csv"),             stringsAsFactors = FALSE)
atc <- read.csv(file.path(RAW_DIR, "codelists", "atc_conmed.csv"), stringsAsFactors = FALSE)

# Derive USUBJID
raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-")
  )

# ATC lookup: match DRUG_NAME_VERBATIM to DRUG_NAME_VERBATIM_1 or _2 (case-insensitive)
atc_lookup <- atc |>
  mutate(
    V1_UPPER = str_to_upper(str_trim(DRUG_NAME_VERBATIM_1)),
    V2_UPPER = str_to_upper(str_trim(DRUG_NAME_VERBATIM_2))
  )

match_atc <- function(verbatim_vec) {
  v_up <- str_to_upper(str_trim(verbatim_vec))
  n    <- length(v_up)

  CMDECOD  <- character(n)
  CMATC    <- character(n)
  CMINDC   <- character(n)

  for (i in seq_len(n)) {
    # Exact match on V1 or V2
    idx <- which(atc_lookup$V1_UPPER == v_up[i] | atc_lookup$V2_UPPER == v_up[i])
    if (length(idx) == 0) {
      # Fuzzy fallback across both columns
      idx1 <- agrep(v_up[i], atc_lookup$V1_UPPER, ignore.case = TRUE,
                    max.distance = 0.2, value = FALSE)
      idx2 <- agrep(v_up[i], atc_lookup$V2_UPPER, ignore.case = TRUE,
                    max.distance = 0.2, value = FALSE)
      idx  <- unique(c(idx1, idx2))
    }
    if (length(idx) > 0) {
      CMDECOD[i]  <- atc_lookup$DRUG_NAME[idx[1]]
      CMATC[i]   <- atc_lookup$ATC_CODE[idx[1]]
      CMINDC[i]  <- atc_lookup$INDICATION[idx[1]]
    } else {
      CMDECOD[i]  <- str_to_upper(str_trim(verbatim_vec[i]))
      CMATC[i]   <- NA_character_
      CMINDC[i]  <- NA_character_
    }
  }

  data.frame(CMDECOD, CMATC, CMINDC, stringsAsFactors = FALSE)
}

atc_coded <- match_atc(raw$DRUG_NAME_VERBATIM)

raw_coded <- bind_cols(raw, atc_coded)

sdtm_cm <- raw_coded |>
  mutate(
    CMTRT    = str_trim(DRUG_NAME_VERBATIM),
    CMSTDTC  = as.character(START_DATE),
    CMENDTC  = as.character(END_DATE),
    CMENRTPT = case_when(
      str_to_upper(str_trim(as.character(ONGOING))) %in% c("Y", "YES", "TRUE", "1") ~ "ONGOING",
      is.na(END_DATE) | str_trim(as.character(END_DATE)) == "" ~ "ONGOING",
      TRUE ~ "BEFORE"
    ),
    # Use raw INDICATION if ATC lookup didn't supply one
    CMINDC   = ifelse(is.na(CMINDC) | CMINDC == "",
                      str_to_upper(str_trim(INDICATION)),
                      CMINDC),
    CMROUTE  = "ORAL",
    CMCAT    = "CONCOMITANT MEDICATION"
  ) |>
  arrange(USUBJID, CMSTDTC, CMTRT) |>
  group_by(USUBJID) |>
  mutate(CMSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN   = "CM",
    USUBJID,
    CMSEQ,
    CMTRT,
    CMDECOD,
    CMATC,
    CMINDC,
    CMROUTE,
    CMSTDTC,
    CMENDTC,
    CMENRTPT,
    CMCAT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_cm, file.path(OUT_DIR, "cm.parquet"))
message("CM written: ", nrow(sdtm_cm), " records")
