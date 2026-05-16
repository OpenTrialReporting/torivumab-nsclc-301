###############################################################################
# 14_drug_accountability.R
# Generates raw/drug_accountability.csv
# CDASH DA form — pharmacist dispensation log per cycle visit
#
# Model:
#   - Study drug (TORIVUMAB / PLACEBO): 100 mg vials. Pharmacist dispenses
#     ceil(dose_mg / 100) vials per administration; returned vials = dispensed
#     - used; rare losses simulated at ~2% probability (vial dropped / breakage).
#   - Companion chemo (CARBOPLATIN, PEMETREXED): compounded at site, dispensed
#     and used in mg with no return possible.
#   - Compliance % per administration (used / dispensed * 100, capped 0-100).
#   - Accountability assessment occurs on the same visit as the dose.
#
# Depends on: raw/exposure.csv (read at run time — not globals — so the script
#             can run standalone or via the orchestrator after 03_exposure.R).
###############################################################################

message("  Simulating drug accountability...")

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
})

set.seed(20260314)  # local seed for DA-specific stochastic noise

# Resolve raw dir whether run standalone (from project root) or via orchestrator
if (!exists("RAW_DIR", inherits = TRUE)) RAW_DIR <- "raw"

exposure_path <- file.path(RAW_DIR, "exposure.csv")
if (!file.exists(exposure_path)) {
  stop("Cannot find raw/exposure.csv. Run programs/raw/03_exposure.R first.")
}

ex <- read.csv(exposure_path, stringsAsFactors = FALSE)

# Vial size lookup (mg per vial). NA → compounded (no vial concept).
vial_size_mg <- c(
  "TORIVUMAB"   = 100,
  "PLACEBO"     = 100,
  "CARBOPLATIN" = NA_real_,
  "PEMETREXED"  = NA_real_
)

ex <- ex |>
  mutate(
    DRUG    = str_to_upper(str_trim(DRUG_NAME)),
    DOSE_MG = as.numeric(DOSE_MG),
    VISIT_NAME = paste0("C", CYCLE_NUMBER, "D", DAY_IN_CYCLE),
    VIAL_SZ = vial_size_mg[DRUG]
  )

# Per-administration accountability records
da_rows <- ex |>
  rowwise() |>
  mutate(
    is_vialed = !is.na(VIAL_SZ) && VIAL_SZ > 0,
    vials_needed = if (is_vialed) ceiling(DOSE_MG / VIAL_SZ) else NA_real_,
    # Pharmacist always dispenses whole vials for IV; for compounded, dispensed = used
    AMT_DISPENSED = if (is_vialed) vials_needed else DOSE_MG,
    # Rare loss simulation for vialed drug (~2% lose 1 vial)
    lost_vial = if (is_vialed && runif(1) < 0.02) 1 else 0,
    # Used = dose / vial_size (fractional, but only whole vials drawn so use vials_needed - waste)
    AMT_USED = if (is_vialed) vials_needed - lost_vial else DOSE_MG,
    AMT_RETURNED = if (is_vialed) pmax(AMT_DISPENSED - AMT_USED - lost_vial, 0) else 0,
    AMT_LOST = lost_vial,
    AMT_UNIT = if (is_vialed) "VIAL" else str_to_upper(str_trim(DOSE_UNIT)),
    COMPLIANCE_PCT = round(
      ifelse(AMT_DISPENSED > 0,
             pmin(100, (AMT_USED / AMT_DISPENSED) * 100),
             NA_real_),
      1
    ),
    DISPENSED_BY = paste0("PH-", substr(SUBJECT_ID, 1, 7))
  ) |>
  ungroup() |>
  transmute(
    SUBJECT_ID,
    VISIT_NAME,
    VISIT_DATE        = START_DATE,
    DRUG_NAME         = DRUG,
    DOSE_FORM         = ifelse(is_vialed, "VIAL", "COMPOUNDED"),
    AMT_DISPENSED,
    AMT_USED,
    AMT_RETURNED,
    AMT_LOST,
    AMT_UNIT,
    COMPLIANCE_PCT,
    ACCOUNTABILITY_DATE = START_DATE,
    DISPENSED_BY
  ) |>
  arrange(SUBJECT_ID, VISIT_DATE, DRUG_NAME)

# Make available to the orchestrator session, but the source of truth is the CSV
if (exists(".GlobalEnv", inherits = TRUE)) {
  assign("drug_accountability", da_rows, envir = .GlobalEnv)
}

out_path <- file.path(RAW_DIR, "drug_accountability.csv")
write.csv(da_rows, file = out_path, row.names = FALSE, na = "")

message("  drug_accountability.csv written: ", nrow(da_rows), " rows (",
        n_distinct(da_rows$SUBJECT_ID), " subjects, ",
        sum(da_rows$AMT_LOST), " lost vials simulated)")
