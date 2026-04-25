# =============================================================================
# Program    : ds.R
# Domain     : DS — Disposition
# SDTM IG ref: Section 6.2
# Reads from : raw/demographics.csv, raw/disposition.csv
# Writes to  : datasets/sdtm/ds.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
dem  <- read.csv(file.path(RAW_DIR, "demographics.csv"),  stringsAsFactors = FALSE)
disp <- read.csv(file.path(RAW_DIR, "disposition.csv"),   stringsAsFactors = FALSE)

# Derive USUBJID in both
make_usubjid <- function(df) {
  df |> mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-")
  )
}

dem  <- make_usubjid(dem)
disp <- make_usubjid(disp)

# CDISC decode mapping for DISC_REASON
disc_decode_map <- c(
  "ADVERSE EVENT"              = "ADVERSE EVENT",
  "AE"                         = "ADVERSE EVENT",
  "WITHDRAWAL BY SUBJECT"      = "WITHDRAWAL BY SUBJECT",
  "WITHDREW CONSENT"           = "WITHDRAWAL BY SUBJECT",
  "PHYSICIAN DECISION"         = "PHYSICIAN DECISION",
  "LOST TO FOLLOW-UP"          = "LOST TO FOLLOW-UP",
  "DEATH"                      = "DEATH",
  "PROGRESSIVE DISEASE"        = "PROGRESSIVE DISEASE",
  "PROTOCOL DEVIATION"         = "PROTOCOL DEVIATION",
  "PROTOCOL VIOLATION"         = "PROTOCOL DEVIATION",
  "OTHER"                      = "OTHER"
)

map_disc_decode <- function(reason) {
  r_up <- str_to_upper(str_trim(reason))
  decoded <- disc_decode_map[r_up]
  ifelse(is.na(decoded), str_to_upper(str_trim(reason)), decoded)
}

# Record 1: Informed Consent (from demographics)
rec1 <- dem |>
  transmute(
    USUBJID,
    DSTERM   = "INFORMED CONSENT OBTAINED",
    DSDECOD  = "INFORMED CONSENT OBTAINED",
    DSCAT    = "PROTOCOL MILESTONE",
    DSSCAT   = NA_character_,
    DSSTDTC  = as.character(INFORM_CONSENT_DATE)
  )

# Record 2: Randomised (from demographics — only non-screen-failures)
rec2 <- dem |>
  filter(!as.character(SCREEN_FAIL) %in% c("Y", "1", "TRUE")) |>
  transmute(
    USUBJID,
    DSTERM   = "RANDOMIZED",
    DSDECOD  = "RANDOMIZED",
    DSCAT    = "PROTOCOL MILESTONE",
    DSSCAT   = NA_character_,
    DSSTDTC  = as.character(RAND_DATE)
  )

# Record 3: Disposition event from disposition.csv
rec3 <- disp |>
  mutate(
    completed = str_to_upper(str_trim(COMPLETION_STATUS)) %in%
      c("COMPLETED", "COMPLETE", "Y", "YES"),
    DSTERM   = ifelse(completed,
                      "COMPLETED",
                      str_to_upper(str_trim(DISC_REASON))),
    DSDECOD  = ifelse(completed,
                      "COMPLETED",
                      map_disc_decode(DISC_REASON)),
    DSCAT    = "DISPOSITION EVENT",
    DSSCAT   = ifelse(completed, NA_character_, "STUDY DISCONTINUATION"),
    DSSTDTC  = ifelse(completed,
                      as.character(STUDY_COMPLETION_DATE),
                      as.character(DISC_DATE))
  ) |>
  transmute(USUBJID, DSTERM, DSDECOD, DSCAT, DSSCAT, DSSTDTC)

# Combine and sequence
sdtm_ds <- bind_rows(rec1, rec2, rec3) |>
  arrange(USUBJID, DSSTDTC) |>
  group_by(USUBJID) |>
  mutate(DSSEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID = STUDYID,
    DOMAIN  = "DS",
    USUBJID,
    DSSEQ,
    DSTERM,
    DSDECOD,
    DSCAT,
    DSSCAT,
    DSSTDTC
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ds, file.path(OUT_DIR, "ds.parquet"))
message("DS written: ", nrow(sdtm_ds), " records")
