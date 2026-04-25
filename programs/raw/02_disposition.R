###############################################################################
# 02_disposition.R
# Generates raw/disposition.csv
# Depends on: demographics (global)
###############################################################################

message("  Simulating disposition...")

library(lubridate)

dm <- demographics

n <- nrow(dm)
rand_dates  <- as.Date(dm$RAND_DATE)
is_trt      <- dm$TREATMENT_ARM == "Torivumab + Chemotherapy"

# ── simulate OS and PFS times (months → days) ─────────────────────────────
# These drive discontinuation logic; not stored as columns
lambda_os  <- ifelse(is_trt, LAMBDA_OS_TRT,  LAMBDA_OS_PBO)
lambda_pfs <- ifelse(is_trt, LAMBDA_PFS_TRT, LAMBDA_PFS_PBO)

os_months  <- rexp(n, rate = lambda_os)
pfs_months <- rexp(n, rate = lambda_pfs)
pfs_months <- pmin(pfs_months, os_months)   # PFS cannot exceed OS

os_days    <- round(os_months  * 30.4375)
pfs_days   <- round(pfs_months * 30.4375)

death_date_potential  <- rand_dates + os_days
last_tx_date_potential <- rand_dates + pfs_days

# ── administrative censoring at data cutoff ────────────────────────────────
died_before_cutoff <- death_date_potential <= DATA_CUTOFF

# ── discontinuation reasons ────────────────────────────────────────────────
disc_reasons_pd  <- "Progressive Disease"
disc_reasons_ae  <- "Adverse Event"
disc_reasons_wbs <- "Withdrawal by Subject"
disc_reasons_phd <- "Physician Decision"
disc_reasons_oth <- "Other"

completion_status <- character(n)
disc_date         <- as.Date(rep(NA, n))
disc_reason       <- character(n)
last_contact_date <- as.Date(rep(NA, n))
study_completion  <- as.Date(rep(NA, n))

for (i in seq_len(n)) {
  tx_end <- min(last_tx_date_potential[i], DATA_CUTOFF - 1)

  if (died_before_cutoff[i]) {
    # Subject died on study
    completion_status[i] <- "Discontinued"
    disc_date[i]         <- death_date_potential[i]
    # reason: mostly PD, some AE, some other
    disc_reason[i] <- sample(
      c(disc_reasons_pd, disc_reasons_ae, disc_reasons_oth),
      1, prob = c(0.72, 0.18, 0.10)
    )
    last_contact_date[i] <- death_date_potential[i]
    study_completion[i]  <- death_date_potential[i]
  } else {
    # Subject still alive at cutoff — may have discontinued treatment earlier
    # ~35% discontinued before cutoff for non-death reasons
    early_disc <- runif(1) < 0.35
    if (early_disc) {
      disc_day <- sample(seq(pfs_days[i], os_days[i], length.out = 5), 1)
      disc_day <- max(21, min(disc_day, as.integer(DATA_CUTOFF - rand_dates[i]) - 7))
      disc_d   <- rand_dates[i] + round(disc_day)
      if (disc_d >= DATA_CUTOFF) {
        # Completed (still on study at cut-off)
        completion_status[i] <- "Completed"
        disc_date[i]         <- NA
        disc_reason[i]       <- ""
        last_contact_date[i] <- DATA_CUTOFF - sample(0:14, 1)
        study_completion[i]  <- DATA_CUTOFF
      } else {
        completion_status[i] <- "Discontinued"
        disc_date[i]         <- disc_d
        disc_reason[i] <- sample(
          c(disc_reasons_pd, disc_reasons_ae, disc_reasons_wbs,
            disc_reasons_phd, disc_reasons_oth),
          1, prob = c(0.50, 0.20, 0.14, 0.10, 0.06)
        )
        # Follow-up every 8 weeks after disc until cutoff or death
        last_contact_date[i] <- min(disc_d + sample(56:168, 1), DATA_CUTOFF)
        study_completion[i]  <- last_contact_date[i]
      }
    } else {
      # Completed — on study at cutoff
      completion_status[i] <- "Completed"
      disc_date[i]         <- NA
      disc_reason[i]       <- ""
      last_contact_date[i] <- DATA_CUTOFF - sample(0:14, 1)
      study_completion[i]  <- DATA_CUTOFF
    }
  }
}

disposition <- data.frame(
  SUBJECT_ID           = dm$SUBJECT_ID,
  COMPLETION_STATUS    = completion_status,
  DISC_DATE            = format(disc_date, "%Y-%m-%d"),
  DISC_REASON          = disc_reason,
  LAST_CONTACT_DATE    = format(last_contact_date, "%Y-%m-%d"),
  STUDY_COMPLETION_DATE = format(study_completion, "%Y-%m-%d"),
  stringsAsFactors     = FALSE
)

# Store derived dates for downstream use
assign("disposition",              disposition,              envir = .GlobalEnv)
assign("os_days_sim",              os_days,                  envir = .GlobalEnv)
assign("pfs_days_sim",             pfs_days,                 envir = .GlobalEnv)
assign("death_date_potential",     death_date_potential,     envir = .GlobalEnv)
assign("died_before_cutoff",       died_before_cutoff,       envir = .GlobalEnv)
assign("rand_dates",               rand_dates,               envir = .GlobalEnv)
assign("is_trt",                   is_trt,                   envir = .GlobalEnv)

write.csv(disposition,
          file      = file.path(RAW_DIR, "disposition.csv"),
          row.names = FALSE,
          na        = "")

message("  disposition.csv written: ", nrow(disposition), " rows")
message("    Discontinued: ",
        sum(disposition$COMPLETION_STATUS == "Discontinued"),
        " | Completed: ",
        sum(disposition$COMPLETION_STATUS == "Completed"))
