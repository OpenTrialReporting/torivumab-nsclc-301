###############################################################################
# 08_vital_signs.R
# Generates raw/vital_signs.csv
# Visits mirror the lab visit schedule (subset)
# Depends on: demographics, rand_dates, pfs_days_sim
###############################################################################

message("  Simulating vital signs...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

vs_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id  <- dm$SUBJECT_ID[i]
  rand_dt  <- rand_dates[i]
  pfs_d    <- pfs_days_sim[i]
  sex      <- dm$SEX[i]
  wt_base  <- dm$WEIGHT_KG[i]
  ht_base  <- dm$HEIGHT_CM[i]

  last_obs_dt <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  # ── visit offsets (a subset of the lab schedule) ─────────────────────
  offsets <- c(
    SCREENING = -sample(7:28, 1),
    C1D1      = 0,
    C1D15     = 14 + sample(-1:1, 1),
    C2D1      = 21 + sample(-1:2, 1),
    C3D1      = 42 + sample(-1:2, 1),
    C4D1      = 63 + sample(-1:2, 1),
    C5D1      = 84 + sample(-1:2, 1),
    C6D1      = 105 + sample(-1:2, 1)
  )

  # Add maintenance visits (every 21 days) — guard against short-PFS subjects
  maint_start <- 105 + 21
  maint_end   <- pfs_d + 30
  if (maint_end >= maint_start) {
    maint_offsets <- seq(maint_start, maint_end, by = 21)
    maint_names   <- paste0("MAINT_C", seq_along(maint_offsets), "D1")
    extra_off     <- setNames(maint_offsets, maint_names)
    offsets       <- c(offsets, extra_off)
  }

  # EOT
  eot_off <- pfs_d + sample(1:7, 1)
  offsets  <- c(offsets, EOT = eot_off)

  # Filter to window
  offsets <- offsets[rand_dt + offsets <= min(last_obs_dt, DATA_CUTOFF)]

  rows <- list()
  for (j in seq_along(offsets)) {
    visit_nm <- names(offsets)[j]
    visit_dt <- rand_dt + offsets[j]
    visit_n  <- as.integer(offsets[j] / 21)  # rough cycle

    # Weight tends to decrease with disease progression / chemo
    wt_drift   <- wt_base - visit_n * rnorm(1, 0.15, 0.10)
    wt_drift   <- max(wt_base * 0.70, wt_drift)

    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID   = subj_id,
      VISIT_NAME   = visit_nm,
      VISIT_DATE   = format(visit_dt, "%Y-%m-%d"),
      SYSTOLIC_BP  = round(rnorm(1,
                                 mean = ifelse(sex == "Male", 128, 122),
                                 sd   = 14)),
      DIASTOLIC_BP = round(rnorm(1,
                                 mean = ifelse(sex == "Male", 80, 76),
                                 sd   = 9)),
      HEART_RATE   = round(rnorm(1, mean = 75, sd = 12)),
      WEIGHT_KG    = round(wt_drift, 1),
      HEIGHT_CM    = ht_base,   # constant (measured at screening only in practice, kept here)
      TEMPERATURE_C = round(rnorm(1, mean = 36.7, sd = 0.4), 1),
      RESP_RATE    = round(rnorm(1, mean = 16, sd = 2)),
      stringsAsFactors = FALSE
    )
  }

  if (length(rows) > 0) {
    vs_list[[i]] <- do.call(rbind, rows)
  }
}

vital_signs <- do.call(rbind, Filter(Negate(is.null), vs_list))
row.names(vital_signs) <- NULL

# ---------------------------------------------------------------------------
# Unscheduled visits (CDISC-realistic): an abnormal on-treatment vital sign
# (hypertension SBP>=160 / DBP>=100, or tachycardia HR>=110) prompts an
# off-schedule recheck ~1 week later, captured as VISIT_NAME="UNSCHEDULED".
# Generated in a dedicated RNG stream and constrained to be genuinely
# off-schedule and within participation, so scheduled data and every downstream
# raw program stay byte-identical.
# ---------------------------------------------------------------------------
.rng_state <- if (exists(".Random.seed", envir = .GlobalEnv)) get(".Random.seed", envir = .GlobalEnv) else NULL
set.seed(20260708)
subj_dates <- lapply(split(as.Date(vital_signs$VISIT_DATE), vital_signs$SUBJECT_ID), unique)
abn  <- vital_signs$SYSTOLIC_BP >= 160 | vital_signs$DIASTOLIC_BP >= 100 |
        vital_signs$HEART_RATE >= 110
cand <- vital_signs[abn & toupper(vital_signs$VISIT_NAME) != "SCREENING", ]
cand <- cand[runif(nrow(cand)) < 0.08, ]          # ~8% of abnormal vitals rechecked
recover <- function(v, mid) round(v + (mid - v) * runif(1, 0.3, 0.7) + rnorm(1, 0, 4))
uns_rows <- list()
for (j in seq_len(nrow(cand))) {
  r     <- cand[j, ]
  sd    <- subj_dates[[r$SUBJECT_ID]]
  rdate <- as.Date(r$VISIT_DATE) + sample(5:10, 1)
  if (rdate %in% sd || rdate > max(sd)) next        # off-schedule + within participation
  uns_rows[[length(uns_rows) + 1]] <- data.frame(
    SUBJECT_ID = r$SUBJECT_ID, VISIT_NAME = "UNSCHEDULED",
    VISIT_DATE = format(rdate, "%Y-%m-%d"),
    SYSTOLIC_BP  = recover(r$SYSTOLIC_BP, 122),
    DIASTOLIC_BP = recover(r$DIASTOLIC_BP, 78),
    HEART_RATE   = recover(r$HEART_RATE, 75),
    WEIGHT_KG    = r$WEIGHT_KG, HEIGHT_CM = r$HEIGHT_CM,
    TEMPERATURE_C = round(rnorm(1, 36.7, 0.4), 1),
    RESP_RATE    = round(rnorm(1, 16, 2)), stringsAsFactors = FALSE)
}
if (length(uns_rows)) {
  vital_signs <- rbind(vital_signs, do.call(rbind, uns_rows))
  vital_signs <- vital_signs[order(vital_signs$SUBJECT_ID, as.Date(vital_signs$VISIT_DATE)), ]
  row.names(vital_signs) <- NULL
}
if (!is.null(.rng_state)) assign(".Random.seed", .rng_state, envir = .GlobalEnv)
message("  Unscheduled vital rechecks added: ", length(uns_rows))

# Clip physiological bounds
vital_signs$SYSTOLIC_BP  <- pmax(80,  pmin(200, vital_signs$SYSTOLIC_BP))
vital_signs$DIASTOLIC_BP <- pmax(50,  pmin(120, vital_signs$DIASTOLIC_BP))
vital_signs$HEART_RATE   <- pmax(40,  pmin(140, vital_signs$HEART_RATE))
vital_signs$TEMPERATURE_C <- pmax(35.5, pmin(40, vital_signs$TEMPERATURE_C))
vital_signs$RESP_RATE    <- pmax(10,  pmin(30,  vital_signs$RESP_RATE))

assign("vital_signs", vital_signs, envir = .GlobalEnv)

write.csv(vital_signs,
          file      = file.path(RAW_DIR, "vital_signs.csv"),
          row.names = FALSE,
          na        = "")

message("  vital_signs.csv written: ", nrow(vital_signs), " rows")
