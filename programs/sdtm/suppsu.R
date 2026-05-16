# torivumab guidelines loaded
# =============================================================================
# Program    : suppsu.R
# Dataset    : SUPPSU — Supplemental Qualifiers for SU
# SDTMIG ref : Section 8.4
# Reads from : datasets/sdtm/su.parquet
# Writes to  : datasets/sdtm/suppsu.parquet
# Notes      : SUPPSU carries the standardised smoking-status decode
#              (SMKSTAT) for downstream baseline-table use. Derived from
#              SU records where SUTRT='TOBACCO'.
#              (2026-05-17) Replaces the legacy STUDYID='TORIVUMAB-NSCLC-301'
#              artifact with current STUDYID='CTX-NSCLC-301'. Closes AL-01.
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)

SDTM_DIR <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

su <- as.data.frame(read_parquet(file.path(SDTM_DIR, "su.parquet")))

# One row per subject — pick the TOBACCO record and decode SUSCAT
tobacco <- su |>
  filter(str_to_upper(str_trim(SUTRT)) == "TOBACCO") |>
  mutate(
    SMKSTAT = case_when(
      str_to_upper(str_trim(SUSCAT)) %in% c("CURRENT USER", "CURRENT") ~ "CURRENT SMOKER",
      str_to_upper(str_trim(SUSCAT)) %in% c("FORMER USER", "FORMER")  ~ "EX-SMOKER",
      str_to_upper(str_trim(SUSCAT)) %in% c("NEVER USED", "NEVER")    ~ "NEVER SMOKED",
      TRUE                                                              ~ NA_character_
    )
  )

sdtm_suppsu <- tobacco |>
  filter(!is.na(SMKSTAT)) |>
  arrange(USUBJID) |>
  transmute(
    STUDYID  = STUDYID,
    RDOMAIN  = "SU",
    USUBJID,
    IDVAR    = "SUSEQ",
    IDVARVAL = as.character(SUSEQ),
    QNAM     = "SMKSTAT",
    QLABEL   = "Smoking Status",
    QVAL     = SMKSTAT,
    QORIG    = "CRF",
    QEVAL    = ""
  )

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_suppsu, file.path(SDTM_DIR, "suppsu.parquet"))
message("SUPPSU written: ", nrow(sdtm_suppsu), " records (",
        n_distinct(sdtm_suppsu$USUBJID), " subjects)")
message("  SMKSTAT distribution: ",
        paste(names(table(sdtm_suppsu$QVAL)), unname(table(sdtm_suppsu$QVAL)),
              sep="=", collapse=", "))
