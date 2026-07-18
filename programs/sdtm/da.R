# torivumab guidelines loaded
# =============================================================================
# Program    : da.R
# Domain     : DA — Drug Accountability
# SDTM IG ref: Section 6.5
# Reads from : raw/drug_accountability.csv  (CDASH DA form)
# Writes to  : datasets/sdtm/da.parquet
# Notes      : 1:1 raw → SDTM mapping. Each raw dispensation event yields
#              one DA record per accountability test (DISPAMT, USEDAMT, and
#              — when applicable — RETAMT / LOSTAMT for vialed product).
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)
library(tidyr)

RAW_DIR <- "raw"
OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

raw_path <- file.path(RAW_DIR, "drug_accountability.csv")
if (!file.exists(raw_path)) {
  stop(
    "Cannot find raw/drug_accountability.csv. ",
    "Run programs/raw/14_drug_accountability.R first."
  )
}

raw <- read.csv(raw_path, stringsAsFactors = FALSE)

study_id_const <- STUDYID  # avoid shadowing inside dplyr verbs below

raw <- raw |>
  mutate(
    STUDYID = study_id_const,
    USUBJID = paste(study_id_const, SUBJECT_ID, sep = "-"),
    EXTRT   = str_to_upper(str_trim(DRUG_NAME))
  )

# Long-form DA: pivot accountability quantities into one record per test
da_long <- raw |>
  mutate(
    has_return = DOSE_FORM == "VIAL",
    has_loss   = DOSE_FORM == "VIAL"
  ) |>
  select(
    STUDYID, USUBJID, EXTRT, VISIT_NAME, VISIT_DATE,
    AMT_UNIT, has_return, has_loss,
    DISPAMT = AMT_DISPENSED,
    USEDAMT = AMT_USED,
    RETAMT  = AMT_RETURNED,
    LOSTAMT = AMT_LOST
  ) |>
  pivot_longer(
    cols      = c(DISPAMT, RETAMT, LOSTAMT),   # USEDAMT dropped — not a CDISC DA test (P21 CT2002/CT2003)
    names_to  = "DATESTCD",
    values_to = "value"
  ) |>
  # Drop RETAMT / LOSTAMT for non-vialed (compounded) drugs
  filter(
    !(DATESTCD %in% c("RETAMT", "LOSTAMT") & !has_return),
    !is.na(value)
  ) |>
  mutate(
    DOMAIN   = "DA",
    DATEST   = case_when(                     # exact CDISC DATEST decodes (P21 CT2002/CT2003)
      DATESTCD == "DISPAMT" ~ "Dispensed Amount",
      DATESTCD == "RETAMT"  ~ "Returned Amount",
      DATESTCD == "LOSTAMT" ~ "Lost Amount",
      TRUE                  ~ DATESTCD
    ),
    DACAT    = "DRUG ACCOUNTABILITY",
    DAORRES  = format(round(value, 2), nsmall = 0, trim = TRUE),
    DAORRESU = dplyr::recode(AMT_UNIT, "MG" = "mg", "MG/M2" = "mg/m2"),  # CDISC UNIT (CT2002)
    DASTRESC = format(round(value, 2), nsmall = 0, trim = TRUE),
    DASTRESN = as.numeric(value),
    DASTRESU = dplyr::recode(AMT_UNIT, "MG" = "mg", "MG/M2" = "mg/m2"),  # CDISC UNIT (CT2002)
    DASTDTC  = as.character(VISIT_DATE),
    VISIT    = VISIT_NAME
  ) |>
  arrange(USUBJID, DASTDTC, EXTRT, DATESTCD) |>
  group_by(USUBJID) |>
  mutate(DASEQ = row_number()) |>
  ungroup() |>
  transmute(
    STUDYID,
    DOMAIN,
    USUBJID,
    DASEQ,
    DATESTCD,
    DATEST,
    DACAT,
    DAORRES,
    DAORRESU,
    DASTRESC,
    DASTRESN,
    DASTRESU,
    DASTDTC,
    VISIT,
    EXTRT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(da_long, file.path(OUT_DIR, "da.parquet"))
message("DA written: ", nrow(da_long), " records (",
        n_distinct(da_long$USUBJID), " subjects)")
