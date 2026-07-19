###############################################################################
# 07_labs.R
# Generates raw/labs.csv
# Panel: HGB, NEUT, PLAT, WBC, ALT, AST, CREAT, BILI, ALB, NA, K
# Visits: Screening, C1D1, C1D15, C2D1, C3D1, C4D1, C5D1, C6D1,
#         maintenance visits, EOT
# ~3% missing values
# Depends on: demographics, rand_dates, is_trt, pfs_days_sim
###############################################################################

message("  Simulating labs...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

# ── reference ranges and simulation parameters ─────────────────────────────
lab_specs <- list(
  HGB  = list(name = "Haemoglobin",             unit = "g/dL",
               lo = 11.5, hi = 17.5,  mu = 12.8, sd = 1.8),
  NEUT = list(name = "Neutrophils",              unit = "10^9/L",
               lo = 1.8,  hi = 7.5,   mu = 4.0,  sd = 1.5),
  PLAT = list(name = "Platelets",                unit = "10^9/L",
               lo = 150,  hi = 400,   mu = 240,   sd = 60),
  WBC  = list(name = "White blood cells",        unit = "10^9/L",
               lo = 4.0,  hi = 11.0,  mu = 7.0,  sd = 2.0),
  ALT  = list(name = "Alanine aminotransferase", unit = "U/L",
               lo = 7,    hi = 56,    mu = 28,    sd = 15),
  AST  = list(name = "Aspartate aminotransferase", unit = "U/L",
               lo = 10,   hi = 40,    mu = 25,    sd = 10),
  CREAT= list(name = "Creatinine",               unit = "umol/L",
               lo = 60,   hi = 110,   mu = 80,    sd = 18),
  BILI = list(name = "Bilirubin total",          unit = "umol/L",
               lo = 3,    hi = 21,    mu = 10,    sd = 5),
  ALB  = list(name = "Albumin",                  unit = "g/L",
               lo = 35,   hi = 52,    mu = 40,    sd = 5),
  SODIUM = list(name = "Sodium",                 unit = "mmol/L",
               lo = 136,  hi = 145,   mu = 140,   sd = 3),  # code was "NA" (Na symbol) -> parsed as missing; use CDISC SODIUM
  K    = list(name = "Potassium",                unit = "mmol/L",
               lo = 3.5,  hi = 5.1,   mu = 4.1,   sd = 0.4)
)

test_codes <- names(lab_specs)
# Fix NA. back to NA for the file
tc_for_file <- test_codes
tc_for_file[tc_for_file == "NA."] <- "NA"

# ── visit schedule ──────────────────────────────────────────────────────────
visit_schedule <- function(rand_dt, pfs_d, last_obs_dt) {
  # Core visits
  visits <- list(
    list(name = "SCREENING", offset_days = -sample(7:28, 1)),
    list(name = "C1D1",  offset_days = 0),
    list(name = "C1D15", offset_days = 14 + sample(-1:1, 1)),
    list(name = "C2D1",  offset_days = 21 + sample(-1:2, 1)),
    list(name = "C3D1",  offset_days = 42 + sample(-1:2, 1)),
    list(name = "C4D1",  offset_days = 63 + sample(-1:2, 1)),
    list(name = "C5D1",  offset_days = 84 + sample(-1:2, 1)),
    list(name = "C6D1",  offset_days = 105 + sample(-1:2, 1))
  )

  # Maintenance visits (every 21 days after C6D1)
  maint_start <- 105 + 21
  maint_cycle <- 1
  repeat {
    off <- maint_start + (maint_cycle - 1) * 21 + sample(-1:2, 1)
    dt  <- rand_dt + off
    if (dt > last_obs_dt || dt > DATA_CUTOFF) break
    visits[[length(visits) + 1]] <- list(
      name         = paste0("MAINT_C", maint_cycle, "D1"),
      offset_days  = off
    )
    maint_cycle <- maint_cycle + 1
    if (maint_cycle > 30) break
  }

  # EOT
  eot_offset <- pfs_d + sample(1:7, 1)
  eot_dt     <- rand_dt + eot_offset
  if (eot_dt <= last_obs_dt && eot_dt <= DATA_CUTOFF) {
    visits[[length(visits) + 1]] <- list(name = "EOT", offset_days = eot_offset)
  }

  # Filter to those before last_obs_dt / cutoff
  Filter(function(v) {
    dt <- rand_dt + v$offset_days
    dt <= min(last_obs_dt, DATA_CUTOFF)
  }, visits)
}

# ── perturbation with chemotherapy effect ─────────────────────────────────
# Cycles cause transient drops in NEUT, HGB, PLAT; possible ALT/AST rises
cycle_effect <- function(test_code, cycle_n) {
  # Returns a multiplier applied to the random draw
  if (cycle_n == 0) return(1.0)   # screening
  if (test_code %in% c("NEUT", "WBC", "PLAT", "HGB")) {
    # Nadir around cycle 2-4, recovery thereafter
    nadir_factor <- 1 - 0.25 * exp(-0.5 * (cycle_n - 2.5)^2)
    return(max(0.4, nadir_factor))
  }
  if (test_code %in% c("ALT", "AST")) {
    # Slight rise with each cycle, more in irAE subjects (handled externally)
    return(1 + 0.06 * cycle_n)
  }
  if (test_code == "CREAT") return(1 + 0.03 * cycle_n)
  return(1.0)
}

labs_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id  <- dm$SUBJECT_ID[i]
  rand_dt  <- rand_dates[i]
  pfs_d    <- pfs_days_sim[i]

  last_obs_dt <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  visits <- visit_schedule(rand_dt, pfs_d, last_obs_dt)

  rows <- list()
  cycle_n_counter <- 0

  for (v in visits) {
    visit_nm <- v$name
    visit_dt <- rand_dt + v$offset_days
    if (grepl("^C[0-9]+D1$", visit_nm) || grepl("^MAINT", visit_nm)) {
      cycle_n_counter <- cycle_n_counter + 1
    }
    cn <- if (visit_nm == "SCREENING") 0 else cycle_n_counter

    for (tc_idx in seq_along(test_codes)) {
      tc   <- test_codes[tc_idx]
      tc_f <- tc_for_file[tc_idx]
      spec <- lab_specs[[tc]]

      # ~3% missing
      if (runif(1) < 0.03) next

      eff <- cycle_effect(tc, cn)
      raw_val <- rnorm(1, mean = spec$mu * eff, sd = spec$sd)

      # Realistic bounds: very rarely go negative
      raw_val <- max(spec$lo * 0.30, raw_val)

      result_val <- round(raw_val, if (spec$mu < 20) 1 else 0)

      abn <- if (result_val < spec$lo) "L" else if (result_val > spec$hi) "H" else "N"

      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID   = subj_id,
        VISIT_NAME   = visit_nm,
        VISIT_DATE   = format(visit_dt, "%Y-%m-%d"),
        TEST_CODE    = tc_f,
        TEST_NAME    = spec$name,
        RESULT_VALUE = result_val,
        RESULT_UNIT  = spec$unit,
        LOWER_NORMAL = spec$lo,
        UPPER_NORMAL = spec$hi,
        ABNORMAL_FLAG = abn,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    labs_list[[i]] <- do.call(rbind, rows)
  }
}

labs <- do.call(rbind, Filter(Negate(is.null), labs_list))
row.names(labs) <- NULL

# ---------------------------------------------------------------------------
# Unscheduled visits (CDISC-realistic collection scenario): an abnormal
# on-treatment safety-lab result prompts an off-schedule recheck ~1 week later.
# Captured as VISIT_NAME = "UNSCHEDULED" with the real (off-schedule) date, as an
# EDC would record it. Generated in a dedicated RNG stream and appended, so the
# scheduled data — and every downstream raw program — is byte-for-byte unchanged.
# ---------------------------------------------------------------------------
.rng_state <- if (exists(".Random.seed", envir = .GlobalEnv)) get(".Random.seed", envir = .GlobalEnv) else NULL
set.seed(20260707)
recheck_tests <- c("ALT", "AST", "NEUT", "PLAT", "HGB", "BILI", "CREAT")
# per-subject collected lab dates: rechecks must be genuinely off-schedule
# (not on a collected visit date) and within participation (<= last lab date).
subj_dates <- lapply(split(as.Date(labs$VISIT_DATE), labs$SUBJECT_ID), unique)
cand <- labs[labs$ABNORMAL_FLAG %in% c("H", "L") &
             labs$TEST_CODE %in% recheck_tests &
             labs$VISIT_NAME != "SCREENING", ]
cand <- cand[runif(nrow(cand)) < 0.10, ]          # ~10% of abnormal safety labs rechecked
uns_rows <- list()
for (j in seq_len(nrow(cand))) {
  r     <- cand[j, ]
  sd    <- subj_dates[[r$SUBJECT_ID]]
  rdate <- as.Date(r$VISIT_DATE) + sample(5:10, 1)  # recheck 5-10 days after the abnormal
  if (rdate %in% sd || rdate > max(sd)) next        # skip collisions / after last visit
  spec  <- lab_specs[[r$TEST_CODE]]
  mid   <- (spec$lo + spec$hi) / 2                   # value recovers toward the normal midpoint
  newv  <- as.numeric(r$RESULT_VALUE) +
           (mid - as.numeric(r$RESULT_VALUE)) * runif(1, 0.3, 0.7) + rnorm(1, 0, spec$sd * 0.3)
  newv  <- round(max(spec$lo * 0.30, newv), if (spec$mu < 20) 1 else 0)
  abn   <- if (newv < spec$lo) "L" else if (newv > spec$hi) "H" else "N"
  uns_rows[[length(uns_rows) + 1]] <- data.frame(
    SUBJECT_ID = r$SUBJECT_ID, VISIT_NAME = "UNSCHEDULED",
    VISIT_DATE = format(rdate, "%Y-%m-%d"),
    TEST_CODE = r$TEST_CODE, TEST_NAME = r$TEST_NAME, RESULT_VALUE = newv,
    RESULT_UNIT = r$RESULT_UNIT, LOWER_NORMAL = r$LOWER_NORMAL,
    UPPER_NORMAL = r$UPPER_NORMAL, ABNORMAL_FLAG = abn, stringsAsFactors = FALSE)
}
if (length(uns_rows)) {
  labs <- rbind(labs, do.call(rbind, uns_rows))
  labs <- labs[order(labs$SUBJECT_ID, as.Date(labs$VISIT_DATE)), ]
  row.names(labs) <- NULL
}
if (!is.null(.rng_state)) assign(".Random.seed", .rng_state, envir = .GlobalEnv)
message("  Unscheduled recheck rows added: ", length(uns_rows))

assign("labs", labs, envir = .GlobalEnv)

write.csv(labs,
          file      = file.path(RAW_DIR, "labs.csv"),
          row.names = FALSE,
          na        = "")

message("  labs.csv written: ", nrow(labs), " rows")
message("    Abnormal flags: L=", sum(labs$ABNORMAL_FLAG == "L"),
        " H=", sum(labs$ABNORMAL_FLAG == "H"),
        " N=", sum(labs$ABNORMAL_FLAG == "N"))
