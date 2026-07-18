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
    TRDTC    = as.character(ASSESSMENT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME),
    TRGRPID  = case_when(
      str_to_upper(str_trim(LESION_TYPE)) %in% c("TARGET", "TGT") ~ "TARGET",
      str_to_upper(str_trim(LESION_TYPE)) %in% c("NON-TARGET", "NONTARGET", "NT") ~ "NON-TARGET",
      TRUE ~ str_to_upper(str_trim(LESION_TYPE))
    ),
    TRLNKID = as.character(LESION_ID),
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

# Non-target overall response and new-lesion flags are NOT valid TR (Tumor/
# Lesion Results) test codes — those are response assessments that belong in RS
# (the overall response in RS already reflects them). Only LDIAM lesion
# measurements remain in TR (P21 CT2002 for TRTESTCD/TRTEST).
tr_all <- tr_target

sdtm_tr <- tr_all |>
  arrange(USUBJID, TRDTC, TRLNKID, TRTESTCD) |>
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
    TRLNKID
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_tr, file.path(OUT_DIR, "tr.parquet"))
message("TR written: ", nrow(sdtm_tr), " records")
