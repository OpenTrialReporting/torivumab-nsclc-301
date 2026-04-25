###############################################################################
# 03_exposure.R
# Generates raw/exposure.csv
# Drugs: TORIVUMAB or PLACEBO (200 mg flat IV Q3W) +
#        CARBOPLATIN (AUC5 mg/m2) + PEMETREXED (500 mg/m2)
# Induction: up to 6 cycles Q21D
# Maintenance: PEMETREXED only every 21 days until PD/toxicity
# Depends on: demographics, disposition, pfs_days_sim, rand_dates, is_trt
###############################################################################

message("  Simulating exposure...")

library(lubridate)
library(dplyr)

dm   <- demographics
disp <- disposition
n    <- nrow(dm)

# Body surface area (Mosteller) — needed for dose calculation
bsa <- round(sqrt((dm$HEIGHT_CM * dm$WEIGHT_KG) / 3600), 2)

# ── per-subject cycle generation ───────────────────────────────────────────
exposure_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id   <- dm$SUBJECT_ID[i]
  rand_dt   <- rand_dates[i]
  trt_arm   <- dm$TREATMENT_ARM[i]
  pfs_d     <- pfs_days_sim[i]
  bsa_i     <- bsa[i]

  # Determine last acceptable treatment date
  if (disp$COMPLETION_STATUS[i] == "Discontinued" &&
      !is.na(disp$DISC_DATE[i]) &&
      disp$DISC_REASON[i] %in% c("Progressive Disease", "Adverse Event")) {
    last_tx_date <- as.Date(disp$DISC_DATE[i]) - sample(1:7, 1)
  } else {
    last_tx_date <- min(rand_dt + pfs_d, DATA_CUTOFF - 1)
  }

  # Max cycles before last_tx_date
  max_possible_cycles <- floor(as.integer(last_tx_date - rand_dt) / 21) + 1
  max_possible_cycles <- max(1, min(max_possible_cycles, 60))  # cap safety

  # Induction: cycles 1-6 (or until last_tx_date)
  induction_cycles <- min(6, max_possible_cycles)
  # Maintenance: additional Q21D cycles with pemetrexed only
  maintenance_cycles <- max(0, max_possible_cycles - 6)
  maintenance_cycles <- min(maintenance_cycles, 30)  # realistic cap

  rows <- list()

  for (cyc in seq_len(induction_cycles)) {
    cycle_start <- rand_dt + (cyc - 1) * 21 + sample(-1:2, 1)
    if (cycle_start > last_tx_date) break

    # Dose modification flag: small probability, higher in later cycles
    dm_flag <- ifelse(runif(1) < 0.05 + cyc * 0.008, "Y", "N")
    dm_reason <- ifelse(dm_flag == "Y",
                        sample(c("Toxicity", "Dose limiting toxicity",
                                 "Renal impairment", "Neutropenia"), 1),
                        "")

    dose_factor <- ifelse(dm_flag == "Y", sample(c(0.75, 0.80), 1), 1.0)

    # Study drug (TORIVUMAB or PLACEBO) — flat 200 mg
    study_drug <- ifelse(grepl("Torivumab", trt_arm), "TORIVUMAB", "PLACEBO")
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID      = subj_id,
      DRUG_NAME       = study_drug,
      DOSE_MG         = round(200 * dose_factor),
      DOSE_UNIT       = "mg",
      ROUTE           = "INTRAVENOUS",
      START_DATE      = format(cycle_start, "%Y-%m-%d"),
      END_DATE        = format(cycle_start, "%Y-%m-%d"),
      CYCLE_NUMBER    = cyc,
      DAY_IN_CYCLE    = 1,
      DOSE_MODIFIED   = dm_flag,
      DOSE_MOD_REASON = dm_reason,
      stringsAsFactors = FALSE
    )

    # CARBOPLATIN AUC5 (mg; approximate: AUC * (GFR + 25), GFR~80 mL/min)
    gfr_approx <- round(rnorm(1, 80, 10))
    carbo_dose  <- round(5 * (gfr_approx + 25) * dose_factor)
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID      = subj_id,
      DRUG_NAME       = "CARBOPLATIN",
      DOSE_MG         = carbo_dose,
      DOSE_UNIT       = "mg",
      ROUTE           = "INTRAVENOUS",
      START_DATE      = format(cycle_start, "%Y-%m-%d"),
      END_DATE        = format(cycle_start, "%Y-%m-%d"),
      CYCLE_NUMBER    = cyc,
      DAY_IN_CYCLE    = 1,
      DOSE_MODIFIED   = dm_flag,
      DOSE_MOD_REASON = dm_reason,
      stringsAsFactors = FALSE
    )

    # PEMETREXED 500 mg/m2
    pem_dose <- round(500 * bsa_i * dose_factor)
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID      = subj_id,
      DRUG_NAME       = "PEMETREXED",
      DOSE_MG         = pem_dose,
      DOSE_UNIT       = "mg/m2",
      ROUTE           = "INTRAVENOUS",
      START_DATE      = format(cycle_start, "%Y-%m-%d"),
      END_DATE        = format(cycle_start, "%Y-%m-%d"),
      CYCLE_NUMBER    = cyc,
      DAY_IN_CYCLE    = 1,
      DOSE_MODIFIED   = dm_flag,
      DOSE_MOD_REASON = dm_reason,
      stringsAsFactors = FALSE
    )
  }

  # Maintenance pemetrexed
  if (maintenance_cycles > 0) {
    for (m in seq_len(maintenance_cycles)) {
      cyc_total   <- 6 + m
      maint_start <- rand_dt + (cyc_total - 1) * 21 + sample(-1:2, 1)
      if (maint_start > last_tx_date) break

      dm_flag   <- ifelse(runif(1) < 0.08, "Y", "N")
      dm_reason <- ifelse(dm_flag == "Y",
                          sample(c("Toxicity", "Renal impairment"), 1), "")
      dose_factor <- ifelse(dm_flag == "Y", 0.75, 1.0)
      pem_dose <- round(500 * bsa_i * dose_factor)

      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID      = subj_id,
        DRUG_NAME       = "PEMETREXED",
        DOSE_MG         = pem_dose,
        DOSE_UNIT       = "mg/m2",
        ROUTE           = "INTRAVENOUS",
        START_DATE      = format(maint_start, "%Y-%m-%d"),
        END_DATE        = format(maint_start, "%Y-%m-%d"),
        CYCLE_NUMBER    = cyc_total,
        DAY_IN_CYCLE    = 1,
        DOSE_MODIFIED   = dm_flag,
        DOSE_MOD_REASON = dm_reason,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    exposure_list[[i]] <- do.call(rbind, rows)
  }
}

exposure <- do.call(rbind, Filter(Negate(is.null), exposure_list))
row.names(exposure) <- NULL

assign("exposure", exposure, envir = .GlobalEnv)

write.csv(exposure,
          file      = file.path(RAW_DIR, "exposure.csv"),
          row.names = FALSE,
          na        = "")

message("  exposure.csv written: ", nrow(exposure), " rows")
