# =============================================================================
# Program    : tu.R
# Domain     : TU — Tumor Identification
# SDTM IG ref: Section 9.1 (Oncology)
# Reads from : raw/tumor_measurements.csv
# Writes to  : datasets/sdtm/tu.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "tumor_measurements.csv"), stringsAsFactors = FALSE)

# VISITNUM mapping
visit_map <- c(
  "SCREENING" = 0L, "SCR" = 0L,
  "C1D1" = 1L, "C1D15" = 2L, "C2D1" = 3L, "C3D1" = 4L,
  "C4D1" = 5L, "C5D1" = 6L, "C6D1" = 7L, "C7D1" = 8L, "C8D1" = 9L,
  "EOT" = 99L, "END OF TREATMENT" = 99L,
  "FU1" = 100L, "FU2" = 101L,
  "FOLLOW-UP 1" = 100L, "FOLLOW-UP 2" = 101L
)

get_visitnum <- function(visit_name) {
  v_up <- str_to_upper(str_trim(visit_name))
  mapped <- visit_map[v_up]
  ifelse(is.na(mapped), NA_integer_, as.integer(mapped))
}

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    TUTESTCD = "TUMIDENT",
    TUTEST   = "Tumor Identification",
    TUORRES  = paste(str_trim(LESION_TYPE), str_trim(ANATOMICAL_LOCATION), sep = " - "),
    TULOC    = str_to_upper(str_trim(ANATOMICAL_LOCATION)),
    # TUMETHOD: default CT SCAN; can be derived from raw if available
    TUMETHOD = "CT SCAN",
    TUDTC    = as.character(ASSESSMENT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME),
    # TUGRPID: based on LESION_TYPE
    TUGRPID  = case_when(
      str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT") ~ "TARGET",
      str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
      TRUE ~ str_to_upper(str_trim(LESION_TYPE))
    ),
    TULINKID = as.character(LESION_ID)
  ) |>
  arrange(USUBJID, TUDTC, TULINKID) |>
  group_by(USUBJID) |>
  mutate(TUSEQ = row_number()) |>
  ungroup()

sdtm_tu <- raw |>
  transmute(
    STUDYID,
    DOMAIN   = "TU",
    USUBJID,
    TUSEQ,
    TUTESTCD,
    TUTEST,
    TUORRES,
    TULOC,
    TUMETHOD,
    TUDTC,
    VISITNUM,
    VISIT,
    TUGRPID,
    TULINKID
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_tu, file.path(OUT_DIR, "tu.parquet"))
message("TU written: ", nrow(sdtm_tu), " records")
