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
    # RSEVAL carries reader type (AL-04/AL-07 fix 2026-05-17 — BICR added)
    RSEVAL   = case_when(
      str_to_upper(str_trim(ASSESSMENT_TYPE)) == "BICR"         ~ "INDEPENDENT ASSESSOR",
      str_to_upper(str_trim(ASSESSMENT_TYPE)) == "INVESTIGATOR" ~ "INVESTIGATOR",
      TRUE                                                       ~ "INVESTIGATOR"
    ),
    RSORRES  = str_to_upper(str_trim(INVESTIGATOR_RESPONSE)),
    RSSTRESC = str_to_upper(str_trim(INVESTIGATOR_RESPONSE)),
    RSSTRESN = map_rsstresn(INVESTIGATOR_RESPONSE),
    RSDTC    = as.character(ASSESSMENT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME)
  ) |>
  arrange(USUBJID, RSDTC, RSEVAL) |>
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
    RSEVAL,    # INVESTIGATOR or INDEPENDENT ASSESSOR (BICR)
    RSORRES,
    RSSTRESC,
    RSDTC,
    VISITNUM,
    VISIT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_rs, file.path(OUT_DIR, "rs.parquet"))
message("RS written: ", nrow(sdtm_rs), " records")
