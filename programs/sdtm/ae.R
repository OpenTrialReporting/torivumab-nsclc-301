# =============================================================================
# Program    : ae.R
# Domain     : AE — Adverse Events
# SDTM IG ref: Section 6.1
# Reads from : raw/adverse_events.csv, raw/codelists/meddra_oncology_subset.csv
# Writes to  : datasets/sdtm/ae.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw    <- read.csv(file.path(RAW_DIR, "adverse_events.csv"), stringsAsFactors = FALSE)
meddra <- read.csv(file.path(RAW_DIR, "codelists", "meddra_oncology_subset.csv"),
                   stringsAsFactors = FALSE)

# Derive USUBJID
raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-")
  )

# MedDRA coding: exact match on LLT_NAME (case-insensitive), then fuzzy
meddra_lookup <- meddra |>
  mutate(LLT_NAME_UPPER = str_to_upper(str_trim(LLT_NAME)))

code_ae <- function(verbatim_terms, meddra_lkp) {
  terms_upper <- str_to_upper(str_trim(verbatim_terms))

  # Exact match
  idx_exact <- match(terms_upper, meddra_lkp$LLT_NAME_UPPER)

  # Fuzzy match for unmatched
  unmatched <- which(is.na(idx_exact))
  if (length(unmatched) > 0) {
    for (i in unmatched) {
      fuzz <- agrep(terms_upper[i], meddra_lkp$LLT_NAME_UPPER,
                    ignore.case = TRUE, max.distance = 0.2, value = FALSE)
      if (length(fuzz) > 0) {
        idx_exact[i] <- fuzz[1]
      }
    }
  }

  data.frame(
    AEDECOD  = ifelse(is.na(idx_exact), terms_upper,        meddra_lkp$PT_NAME[idx_exact]),
    AEBODSYS = ifelse(is.na(idx_exact), NA_character_,      meddra_lkp$SOC_NAME[idx_exact]),
    AEHLT    = ifelse(is.na(idx_exact), NA_character_,      meddra_lkp$HLT_NAME[idx_exact]),
    AELLT    = ifelse(is.na(idx_exact), verbatim_terms,     meddra_lkp$LLT_NAME[idx_exact]),
    IRAEFL   = ifelse(is.na(idx_exact), "N",               ifelse(meddra_lkp$IRAEFL[idx_exact] == "Y", "Y", "N")),
    stringsAsFactors = FALSE
  )
}

coded <- code_ae(raw$AE_VERBATIM_TERM, meddra_lookup)

# Severity, seriousness, and SAE sub-criteria mappings
map_sev <- function(x) {
  x_up <- str_to_upper(str_trim(x))
  case_when(
    x_up %in% c("MILD", "1", "GRADE 1")   ~ "MILD",
    x_up %in% c("MODERATE", "2", "GRADE 2") ~ "MODERATE",
    x_up %in% c("SEVERE", "3", "GRADE 3")  ~ "SEVERE",
    x_up %in% c("LIFE-THREATENING", "4", "GRADE 4") ~ "LIFE-THREATENING",
    x_up %in% c("FATAL", "5", "GRADE 5")   ~ "FATAL",
    TRUE ~ x_up
  )
}

map_yn <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("Y", "YES", "TRUE", "1") ~ "Y",
    x_up %in% c("N", "NO", "FALSE", "0") ~ "N",
    TRUE ~ NA_character_
  )
}

map_rel <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("Y", "YES", "TRUE", "RELATED", "POSSIBLY RELATED",
                 "PROBABLY RELATED", "DEFINITELY RELATED") ~ "Y",
    x_up %in% c("N", "NO", "FALSE", "NOT RELATED", "UNRELATED") ~ "N",
    TRUE ~ NA_character_
  )
}

map_out <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    str_detect(x_up, "RECOVER")  ~ "RECOVERED/RESOLVED",
    str_detect(x_up, "RESOLV")   ~ "RECOVERED/RESOLVED",
    str_detect(x_up, "ONGOING")  ~ "NOT RECOVERED/NOT RESOLVED",
    str_detect(x_up, "SEQUELA")  ~ "RECOVERED/RESOLVED WITH SEQUELAE",
    str_detect(x_up, "FATAL|DEATH") ~ "FATAL",
    TRUE ~ x_up
  )
}

map_acn <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    str_detect(x_up, "DOSE REDUC")   ~ "DOSE REDUCED",
    str_detect(x_up, "DOSE INTERR")  ~ "DRUG INTERRUPTED",
    str_detect(x_up, "DISC")         ~ "DRUG WITHDRAWN",
    str_detect(x_up, "NONE|NOT")     ~ "NONE",
    TRUE ~ x_up
  )
}

raw_coded <- bind_cols(raw, coded)

sdtm_ae <- raw_coded |>
  mutate(
    AETERM  = str_trim(AE_VERBATIM_TERM),
    AESTDTC = as.character(AE_START_DATE),
    AEENDTC = as.character(AE_END_DATE),
    AESEV   = map_sev(SEVERITY),
    AESER   = map_yn(SERIOUS),
    AEREL   = map_rel(RELATED_TO_STUDY_DRUG),
    AEACN   = map_acn(ACTION_TAKEN),
    AEOUT   = map_out(OUTCOME),
    AECAT   = case_when(
      IRAEFL == "Y"                            ~ "IMMUNE-RELATED",
      !is.na(AECAT) & str_trim(AECAT) != ""   ~ str_to_upper(str_trim(AECAT)),
      TRUE                                     ~ NA_character_
    ),
    # SAE sub-criteria from SERIOUS field and OUTCOME
    AESDTH   = ifelse(str_to_upper(str_trim(as.character(OUTCOME))) %in%
                        c("FATAL", "DEATH"), "Y", "N"),
    AESHOSP  = NA_character_,   # not in raw; retain NA
    AESLIFE  = NA_character_,
    AESDISAB = NA_character_,
    AESMIE   = NA_character_,
    AESCONG  = NA_character_,
    AEDISCOD = ifelse(
      str_to_upper(str_trim(as.character(LEADING_TO_DISCONTINUATION))) %in%
        c("Y", "YES", "TRUE", "1"), "Y", "N"
    )
  ) |>
  arrange(USUBJID, AESTDTC) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  mutate(
    # CTCAE grade (AETOXGR) derived from AESEV — NCI CTCAE v5.0 mapping
    AETOXGR = case_when(
      AESEV == "MILD"             ~ "1",
      AESEV == "MODERATE"         ~ "2",
      AESEV == "SEVERE"           ~ "3",
      AESEV == "LIFE-THREATENING" ~ "4",
      AESEV == "FATAL"            ~ "5",
      TRUE                        ~ NA_character_
    ),
    # AESOC: Primary System Organ Class (same hierarchy as AEBODSYS in this coding)
    AESOC = AEBODSYS
  ) |>
  transmute