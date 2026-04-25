# =============================================================================
# Program    : vs.R
# Domain     : VS — Vital Signs
# SDTM IG ref: Section 7.2
# Reads from : raw/vital_signs.csv
# Writes to  : datasets/sdtm/vs.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)
library(tidyr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "vital_signs.csv"), stringsAsFactors = FALSE)

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

# Vital signs parameter metadata
vs_meta <- tribble(
  ~col_name,        ~VSTESTCD, ~VSTEST,                  ~VSORRESU, ~VSSTRESU,
  "SYSTOLIC_BP",    "SYSBP",   "Systolic Blood Pressure", "mmHg",    "mmHg",
  "DIASTOLIC_BP",   "DIABP",   "Diastolic Blood Pressure","mmHg",    "mmHg",
  "HEART_RATE",     "HR",      "Heart Rate",              "beats/min","beats/min",
  "WEIGHT_KG",      "WEIGHT",  "Weight",                  "kg",       "kg",
  "HEIGHT_CM",      "HEIGHT",  "Height",                  "cm",       "cm",
  "TEMPERATURE_C",  "TEMP",    "Temperature",             "C",        "C",
  "RESP_RATE",      "RESP",    "Respiratory Rate",        "breaths/min","breaths/min"
)

# Add USUBJID and VISITNUM
raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME),
    VSDTC    = as.character(VISIT_DATE)
  )

# Pivot longer: one row per parameter
vs_long <- raw |>
  pivot_longer(
    cols      = all_of(vs_meta$col_name),
    names_to  = "col_name",
    values_to = "raw_value"
  ) |>
  filter(!is.na(raw_value) & as.character(raw_value) != "") |>
  left_join(vs_meta, by = "col_name") |>
  mutate(
    VSORRES  = as.character(raw_value),
    VSSTRESN = suppressWarnings(as.numeric(raw_value)),
    VSSTRESC = as.character(raw_value)
  )

sdtm_vs <- vs_long |>
  arrange(USUBJID, VSDTC, VSTESTCD) |>
  group_by(USUBJID) |>
  mutate(VSSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN   = "VS",
    USUBJID,
    VSSEQ,
    VSTESTCD,
    VSTEST,
    VSORRES,
    VSORRESU,
    VSSTRESC,
    VSSTRESN,
    VSSTRESU,
    VSDTC,
    VISITNUM,
    VISIT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_vs, file.path(OUT_DIR, "vs.parquet"))
message("VS written: ", nrow(sdtm_vs), " records")
