# =============================================================================
# Program    : tr.R
# Domain     : TR — Tumor Results
# SDTM IG ref: Section 9.2 (Oncology)
# Reads from : raw/tumor_measurements.csv
# Writes to  : datasets/sdtm/tr.parquet
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
    TRDTC    = as.character(ASSESSMENT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME),
    TRGRPID  = case_when(
      str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT") ~ "TARGET",
      str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
      TRUE ~ str_to_upper(str_trim(LESION_TYPE))
    ),
    TRLINKID = as.character(LESION_ID),
    new_lesion_flag = str_to_upper(str_trim(as.character(NEW_LESION))) %in%
      c("Y", "YES", "TRUE", "1")
  )

# --- Record set 1: Target lesion longest diameter (LDIAM) ---
tr_target <- raw |>
  filter(TRGRPID == "TARGET" & !is.na(LONGEST_DIAMETER_MM)) |>
  mutate(
    TRTESTCD = "LDIAM",
    TRTEST   = "Longest Diameter",
    TRORRES  = as.character(LONGEST_DIAMETER_MM),
    TRSTRESC = as.character(LONGEST_DIAMETER_MM),
    TRSTRESN = as.numeric(LONGEST_DIAMETER_MM),
    TRSTRESU = "mm"
  )

# --- Record set 2: Non-target lesion overall response (OVRLRESP) ---
tr_nontarget <- raw |>
  filter(TRGRPID == "NON-TARGET" & !is.na(RESPONSE_CATEGORY) &
           str_trim(as.character(RESPONSE_CATEGORY)) != "") |>
  mutate(
    TRTESTCD = "OVRLRESP",
    TRTEST   = "Overall Response",
    TRORRES  = str_to_upper(str_trim(RESPONSE_CATEGORY)),
    TRSTRESC = str_to_upper(str_trim(RESPONSE_CATEGORY)),
    TRSTRESN = NA_real_,
    TRSTRESU = NA_character_
  )

# --- Record set 3: New lesion flag (NEWLSN) ---
tr_newlesion <- raw |>
  filter(new_lesion_flag) |>
  mutate(
    TRTESTCD = "NEWLSN",
    TRTEST   = "New Lesion",
    TRORRES  = "Y",
    TRSTRESC = "Y",
    TRSTRESN = NA_real_,
    TRSTRESU = NA_character_
  )

# Combine
tr_all <- bind_rows(tr_target, tr_nontarget, tr_newlesion)

sdtm_tr <- tr_all |>
  arrange(USUBJID, TRDTC, TRLINKID, TRTESTCD) |>
  group_by(USUBJID) |>
  mutate(TRSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN   = "TR",
    USUBJID,
    TRSEQ,
    TRTESTCD,
    TRTEST,
    TRORRES,
    TRSTRESC,
    TRSTRESN,
    TRSTRESU,
    TRDTC,
    VISITNUM,
    VISIT,
    TRGRPID,
    TRLINKID
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_tr, file.path(OUT_DIR, "tr.parquet"))
message("TR written: ", nrow(sdtm_tr), " records")
