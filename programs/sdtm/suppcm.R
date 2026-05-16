# torivumab guidelines loaded
# =============================================================================
# Program    : suppcm.R
# Dataset    : SUPPCM — Supplemental Qualifiers for CM
# SDTM IG ref: Section 8.4
# Reads from : datasets/sdtm/cm.parquet
# Writes to  : datasets/sdtm/suppcm.parquet
# Notes      : SUPPCM carries:
#                CMATC    — WHO ATC classification code (sponsor-defined SUPP)
#                CMIRAEFL — Prescribed for immune-related AE management (Y/N)
#              CMATC is currently denormalised inside parent CM (back-compat
#              with existing ADaM joins); SUPPCM is the SDTM-compliant home
#              for both qualifiers. See SDTM-PROVENANCE §9 Open Items.
# =============================================================================

library(dplyr)
library(arrow)
library(stringr)
library(tidyr)

SDTM_DIR <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

cm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "cm.parquet")))

# Corticosteroid ATC prefix H02AB covers prednisolone, methylprednisolone,
# dexamethasone, hydrocortisone — first-line agents for irAE management.
cortico_atc_prefix <- "H02AB"

supp_records <- cm |>
  mutate(
    CMATC_clean   = ifelse(is.na(CMATC) | str_trim(CMATC) == "", NA_character_, CMATC),
    is_steroid    = !is.na(CMATC_clean) & str_starts(CMATC_clean, cortico_atc_prefix),
    indc_irae     = !is.na(CMINDC) &
                      str_detect(str_to_upper(CMINDC),
                                 "IMMUNE|IRAE|COLITIS|PNEUMONITIS|HEPATITIS|THYROIDITIS"),
    CMIRAEFL      = ifelse(is_steroid & indc_irae, "Y", "N")
  )

supp_atc <- supp_records |>
  filter(!is.na(CMATC_clean)) |>
  transmute(
    STUDYID  = STUDYID,
    RDOMAIN  = "CM",
    USUBJID,
    IDVAR    = "CMSEQ",
    IDVARVAL = as.character(CMSEQ),
    QNAM     = "CMATC",
    QLABEL   = "WHO ATC Classification Code",
    QVAL     = CMATC_clean,
    QORIG    = "ASSIGNED",
    QEVAL    = ""
  )

supp_irae <- supp_records |>
  transmute(
    STUDYID  = STUDYID,
    RDOMAIN  = "CM",
    USUBJID,
    IDVAR    = "CMSEQ",
    IDVARVAL = as.character(CMSEQ),
    QNAM     = "CMIRAEFL",
    QLABEL   = "Prescribed for irAE Management",
    QVAL     = CMIRAEFL,
    QORIG    = "DERIVED",
    QEVAL    = ""
  )

sdtm_suppcm <- bind_rows(supp_atc, supp_irae) |>
  arrange(USUBJID, as.integer(IDVARVAL), QNAM)

dir.create(SDTM_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_suppcm, file.path(SDTM_DIR, "suppcm.parquet"))
message("SUPPCM written: ", nrow(sdtm_suppcm), " records (",
        n_distinct(sdtm_suppcm$USUBJID), " subjects, ",
        n_distinct(sdtm_suppcm$QNAM), " QNAMs)")
