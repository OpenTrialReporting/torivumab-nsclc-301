###############################################################################
# 15_protocol_deviations.R
# Generates raw/protocol_deviations.csv
# CDASH DV form — protocol deviations log
#
# Model (per VALIDATION-PLAN.md proposal):
#   - ~5-8% of subjects have at least one MAJOR deviation (target ~30)
#   - ~30-40% of subjects have at least one MINOR deviation (target ~150)
#   - A subject may have multiple deviations of either severity
#
# Major categories (probability conditional on having a major dev):
#   ELIGIBILITY VIOLATION          15%   randomised despite IE failure
#   PROHIBITED CONCOMITANT MED     30%   received excluded medication on study
#   MISSED TUMOUR ASSESSMENTS      30%   >=2 consecutive missed scans
#   DOSE MODIFICATION VIOLATION    15%   dose modified outside protocol rules
#   OTHER MAJOR                    10%
#
# Minor categories (conditional on having a minor dev):
#   VISIT WINDOW VIOLATION         65%   assessment outside protocol window
#   MISSED LAB / VITALS            15%
#   LATE ASSESSMENT                10%
#   PROCEDURAL                     10%
#
# Dates: random within the subject's on-study window (RAND_DATE to last contact).
# Depends on: demographics (global), disposition (global)
###############################################################################

message("  Simulating protocol deviations...")

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

set.seed(20260315)  # local seed (master 20260301 set by orchestrator)

dm   <- demographics
disp <- disposition
n    <- nrow(dm)

# Subject-level deviation incidence
has_major <- runif(n) < 0.07     # ~7% target
has_minor <- runif(n) < 0.35     # ~35% target

# Number of deviations per subject (Poisson-ish — most have 1, some have 2+)
n_major_per_subj <- ifelse(has_major, pmax(1L, rpois(n, 1.2)), 0L)
n_minor_per_subj <- ifelse(has_minor, pmax(1L, rpois(n, 1.5)), 0L)

# Category sampling helpers
sample_major_cat <- function(n_evt) {
  if (n_evt == 0) return(character(0))
  sample(
    c("ELIGIBILITY VIOLATION",
      "PROHIBITED CONCOMITANT MEDICATION",
      "MISSED TUMOUR ASSESSMENTS",
      "DOSE MODIFICATION VIOLATION",
      "OTHER MAJOR DEVIATION"),
    size    = n_evt,
    replace = TRUE,
    prob    = c(0.15, 0.30, 0.30, 0.15, 0.10)
  )
}
sample_minor_cat <- function(n_evt) {
  if (n_evt == 0) return(character(0))
  sample(
    c("VISIT WINDOW VIOLATION",
      "MISSED LAB / VITALS",
      "LATE ASSESSMENT",
      "PROCEDURAL DEVIATION"),
    size    = n_evt,
    replace = TRUE,
    prob    = c(0.65, 0.15, 0.10, 0.10)
  )
}

# Map category → human-readable verbatim term
verbatim_lookup <- list(
  "ELIGIBILITY VIOLATION" = c(
    "Subject enrolled despite failing inclusion criterion 4 (ECOG PS)",
    "Subject enrolled with prior CNS-directed therapy (excluded)",
    "Baseline PD-L1 TPS < 50% — eligibility criterion violated",
    "Subject had clinically significant abnormal lab at screening — not excluded"
  ),
  "PROHIBITED CONCOMITANT MEDICATION" = c(
    "Subject received systemic corticosteroid > 10 mg/d prednisone equivalent",
    "Subject received live attenuated vaccine during treatment period",
    "Subject received another investigational drug concurrently",
    "Subject received immunosuppressive therapy during treatment"
  ),
  "MISSED TUMOUR ASSESSMENTS" = c(
    "Two consecutive scheduled tumour assessments missed",
    "Three consecutive scheduled tumour assessments missed",
    "Scan window exceeded by >2 weeks for ≥2 cycles"
  ),
  "DOSE MODIFICATION VIOLATION" = c(
    "Dose reduction below protocol-permitted minimum",
    "Treatment continued through Grade 3 AE without dose modification per protocol",
    "Dose held longer than protocol-permitted 6 weeks"
  ),
  "OTHER MAJOR DEVIATION" = c(
    "Informed consent form not signed prior to randomisation",
    "Wrong study drug dispensed at site (corrected next cycle)",
    "Randomisation stratum mis-assigned"
  ),
  "VISIT WINDOW VIOLATION" = c(
    "Visit outside ±3 day window",
    "Visit outside ±5 day window",
    "Cycle administered >7 days late"
  ),
  "MISSED LAB / VITALS" = c(
    "Haematology missed at scheduled visit",
    "Vital signs not recorded at scheduled visit",
    "Chemistry panel incomplete"
  ),
  "LATE ASSESSMENT" = c(
    "Tumour assessment performed >7 days late",
    "Safety assessment delayed",
    "ECOG performance status assessment missed"
  ),
  "PROCEDURAL DEVIATION" = c(
    "ePRO not completed at scheduled visit",
    "Pharmacist did not document drug accountability per SOP",
    "Sample not stored at correct temperature (excursion <2 hr)"
  )
)
verbatim_for <- function(category) {
  pool <- verbatim_lookup[[category]]
  if (is.null(pool)) return(category)
  sample(pool, 1)
}

# Map category → DVDECOD (standardised term)
decode_for <- function(category) {
  switch(category,
    "ELIGIBILITY VIOLATION"               = "ENROLLMENT/ELIGIBILITY CRITERIA NOT MET",
    "PROHIBITED CONCOMITANT MEDICATION"   = "PROHIBITED CONCOMITANT MEDICATION",
    "MISSED TUMOUR ASSESSMENTS"           = "MISSED REQUIRED EFFICACY ASSESSMENT",
    "DOSE MODIFICATION VIOLATION"         = "DOSE MODIFICATION ERROR",
    "OTHER MAJOR DEVIATION"               = "OTHER",
    "VISIT WINDOW VIOLATION"              = "ASSESSMENT OUTSIDE PROTOCOL WINDOW",
    "MISSED LAB / VITALS"                 = "MISSED ROUTINE ASSESSMENT",
    "LATE ASSESSMENT"                     = "LATE ASSESSMENT",
    "PROCEDURAL DEVIATION"                = "OTHER",
    category
  )
}

# Build rows
rows <- list()
for (i in seq_len(n)) {
  subj_id   <- dm$SUBJECT_ID[i]
  rand_dt   <- as.Date(dm$RAND_DATE[i])
  last_dt   <- as.Date(disp$LAST_CONTACT_DATE[i])
  if (is.na(last_dt)) last_dt <- rand_dt + 30

  if (n_major_per_subj[i] > 0) {
    cats <- sample_major_cat(n_major_per_subj[i])
    for (c in cats) {
      dv_dt <- rand_dt + sample(0:max(1, as.integer(last_dt - rand_dt)), 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID    = subj_id,
        DV_TERM       = verbatim_for(c),
        DV_DECODE     = decode_for(c),
        DV_CATEGORY   = c,
        DV_SEVERITY   = "MAJOR",
        DV_DATE       = format(dv_dt, "%Y-%m-%d"),
        DV_EPOCH      = if (dv_dt < rand_dt) "SCREENING"
                          else if (dv_dt <= as.Date(disp$DISC_DATE[i]) | is.na(disp$DISC_DATE[i])) "TREATMENT"
                          else "FOLLOW-UP",
        stringsAsFactors = FALSE
      )
    }
  }
  if (n_minor_per_subj[i] > 0) {
    cats <- sample_minor_cat(n_minor_per_subj[i])
    for (c in cats) {
      dv_dt <- rand_dt + sample(0:max(1, as.integer(last_dt - rand_dt)), 1)
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID    = subj_id,
        DV_TERM       = verbatim_for(c),
        DV_DECODE     = decode_for(c),
        DV_CATEGORY   = c,
        DV_SEVERITY   = "MINOR",
        DV_DATE       = format(dv_dt, "%Y-%m-%d"),
        DV_EPOCH      = if (dv_dt < rand_dt) "SCREENING"
                          else if (dv_dt <= as.Date(disp$DISC_DATE[i]) | is.na(disp$DISC_DATE[i])) "TREATMENT"
                          else "FOLLOW-UP",
        stringsAsFactors = FALSE
      )
    }
  }
}

deviations <- do.call(rbind, rows)
deviations <- deviations |> arrange(SUBJECT_ID, DV_DATE)

assign("protocol_deviations", deviations, envir = .GlobalEnv)

write.csv(
  deviations,
  file      = file.path(RAW_DIR, "protocol_deviations.csv"),
  row.names = FALSE,
  na        = ""
)

n_major <- sum(deviations$DV_SEVERITY == "MAJOR")
n_minor <- sum(deviations$DV_SEVERITY == "MINOR")
n_subj_major <- n_distinct(deviations$SUBJECT_ID[deviations$DV_SEVERITY == "MAJOR"])
n_subj_minor <- n_distinct(deviations$SUBJECT_ID[deviations$DV_SEVERITY == "MINOR"])
message(sprintf("  protocol_deviations.csv written: %d records (%d MAJOR / %d MINOR)",
                nrow(deviations), n_major, n_minor))
message(sprintf("    Subjects affected: %d MAJOR / %d MINOR",
                n_subj_major, n_subj_minor))
