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
  "EOT" = 900L, "END OF TREATMENT" = 900L,
  "FU1" = 901L, "FU2" = 902L,
  "FOLLOW-UP 1" = 901L, "FOLLOW-UP 2" = 902L
)

get_visitnum <- function(visit_name) {
  v <- str_to_upper(str_trim(visit_name))
  n <- as.integer(visit_map[v])
  # Unique, complete VISITNUM for visits absent from visit_map (P21 SD0051):
  n[is.na(n) & v == "BASELINE"] <- 0L
  m <- is.na(n) & grepl("^MAINT_C[0-9]+D1$", v)      # maintenance cycles -> 9 + cycle
  n[m] <- 9L + as.integer(sub("D1$", "", sub("^MAINT_C", "", v[m])))
  w <- is.na(n) & grepl("ASSESS_WK[0-9]+$", v)       # tumour assessments -> week number
  n[w] <- as.integer(sub("^.*WK", "", v[w]))
  as.integer(n)
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
