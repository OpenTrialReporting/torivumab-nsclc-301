# =============================================================================
# Program    : lb.R
# Domain     : LB — Laboratory Results
# SDTM IG ref: Section 7.1
# Reads from : raw/labs.csv
# Writes to  : datasets/sdtm/lb.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "labs.csv"), stringsAsFactors = FALSE)

# VISITNUM mapping
visit_map <- c(
  "SCREENING" = 0L, "SCR" = 0L,
  "C1D1" = 1L, "C1D15" = 2L, "C2D1" = 3L, "C3D1" = 4L,
  "C4D1" = 5L, "C5D1" = 6L, "C6D1" = 7L, "C7D1" = 8L,
  "C8D1" = 9L,
  "EOT" = 99L, "END OF TREATMENT" = 99L,
  "FU1" = 100L, "FU2" = 101L,
  "FOLLOW-UP 1" = 100L, "FOLLOW-UP 2" = 101L
)

get_visitnum <- function(visit_name) {
  v_up <- str_to_upper(str_trim(visit_name))
  mapped <- visit_map[v_up]
  ifelse(is.na(mapped), NA_integer_, as.integer(mapped))
}

# Haematology test codes
haem_codes <- c("HGB", "NEUT", "PLAT", "WBC", "LYMPH",
                 "RBC", "HCT", "MCH", "MCHC", "MCV")

raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-"),
    LBTESTCD = str_to_upper(str_trim(TEST_CODE)),
    LBTEST   = str_trim(TEST_NAME),
    LBCAT    = case_when(
      LBTESTCD %in% haem_codes ~ "HAEMATOLOGY",
      TRUE                     ~ "CHEMISTRY"
    ),
    LBORRES  = as.character(RESULT_VALUE),
    LBORRESU = str_trim(RESULT_UNIT),
    # Numeric result
    LBSTRESN = suppressWarnings(as.numeric(RESULT_VALUE)),
    LBSTRESC = as.character(RESULT_VALUE),
    LBSTRESU = str_trim(RESULT_UNIT),   # assume SI; SI conversion would be domain-specific
    LBSTNRLO = suppressWarnings(as.numeric(LOWER_NORMAL)),
    LBSTNRHI = suppressWarnings(as.numeric(UPPER_NORMAL)),
    LBNRIND  = case_when(
      str_to_upper(str_trim(as.character(ABNORMAL_FLAG))) %in% c("H", "HIGH") ~ "HIGH",
      str_to_upper(str_trim(as.character(ABNORMAL_FLAG))) %in% c("L", "LOW")  ~ "LOW",
      str_to_upper(str_trim(as.character(ABNORMAL_FLAG))) %in% c("N", "NORMAL", "") ~ "NORMAL",
      !is.na(LBSTRESN) & !is.na(LBSTNRHI) & LBSTRESN > LBSTNRHI ~ "HIGH",
      !is.na(LBSTRESN) & !is.na(LBSTNRLO) & LBSTRESN < LBSTNRLO ~ "LOW",
      !is.na(LBSTRESN) ~ "NORMAL",
      TRUE ~ NA_character_
    ),
    LBDTC    = as.character(VISIT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME),
    LBBLFL   = ifelse(VISITNUM == 0L | str_to_upper(str_trim(VISIT_NAME)) %in%
                        c("SCREENING", "SCR"), "Y", NA_character_)
  ) |>
  arrange(USUBJID, LBDTC, LBTESTCD) |>
  group_by(USUBJID) |>
  mutate(LBSEQ = row_number()) |>
  ungroup()

sdtm_lb <- raw |>
  transmute(
    STUDYID,
    DOMAIN   = "LB",
    USUBJID,
    LBSEQ,
    LBTESTCD,
    LBTEST,
    LBCAT,
    LBORRES,
    LBORRESU,
    LBSTRESC,
    LBSTRESN,
    LBSTRESU,
    LBSTNRLO,
    LBSTNRHI,
    LBNRIND,
    LBDTC,
    VISITNUM,
    VISIT,
    LBBLFL
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_lb, file.path(OUT_DIR, "lb.parquet"))
message("LB written: ", nrow(sdtm_lb), " records")
