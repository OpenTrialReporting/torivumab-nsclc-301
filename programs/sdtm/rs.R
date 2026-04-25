# =============================================================================
# Program    : rs.R
# Domain     : RS — Disease Response
# SDTM IG ref: Section 9.3 (Oncology)
# Reads from : raw/overall_response.csv
# Writes to  : datasets/sdtm/rs.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "overall_response.csv"), stringsAsFactors = FALSE)

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

# RSSTRESN mapping: CR=1, PR=2, SD=3, PD=4, NE=5
resp_num_map <- c(
  "CR" = 1L, "COMPLETE RESPONSE" = 1L, "COMPLETE REMISSION" = 1L,
  "PR" = 2L, "PARTIAL RESPONSE" = 2L,
  "SD" = 3L, "STABLE DISEASE" = 3L,
  "PD" = 4L, "PROGRESSIVE DISEASE" = 4L,
  "NE" = 5L, "NOT EVALUABLE" = 5L, "NED" = 5L
)

map_rsstresn <- function(resp) {
  r_up <- str_to_upper(str_trim(resp))
  mapped <- resp_num_map[r_up]
  ifelse(is.na(mapped), NA_integer_, as.integer(mapped))
}

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    RSTESTCD = "OVRLRESP",
    RSTEST   = "Overall Response",
    RSCAT    = "OVERALL RESPONSE",
    RSEVAL   = "INVESTIGATOR",
    RSORRES  = str_to_upper(str_trim(INVESTIGATOR_RESPONSE)),
    RSSTRESC = str_to_upper(str_trim(INVESTIGATOR_RESPONSE)),
    RSSTRESN = map_rsstresn(INVESTIGATOR_RESPONSE),
    RSDTC    = as.character(ASSESSMENT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME)
  ) |>
  arrange(USUBJID, RSDTC) |>
  group_by(USUBJID) |>
  mutate(RSSEQ = row_number()) |>
  ungroup()

sdtm_rs <- raw |>
  transmute(
    STUDYID,
    DOMAIN   = "RS",
    USUBJID,
    RSSEQ,
    RSTESTCD,
    RSTEST,
    RSCAT,
    RSEVAL,
    RSORRES,
    RSSTRESC,
    RSSTRESN,
    RSDTC,
    VISITNUM,
    VISIT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_rs, file.path(OUT_DIR, "rs.parquet"))
message("RS written: ", nrow(sdtm_rs), " records")
