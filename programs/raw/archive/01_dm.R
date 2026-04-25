# =============================================================================
# torivumab guidelines loaded
# 01_dm.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: DM (Demographics)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(301)
# =============================================================================
#
# Outputs:
#   sdtm/dm.parquet                       — SDTM DM domain (Parquet)
#   data-raw/raw_data/dm_raw.csv          — Raw demographics (pre-SDTM)
#   data-raw/raw_data/subject_backbone.csv — Subject-level dates/outcomes
#                                            consumed by all downstream scripts
#
# Dependencies: None (backbone script — run first)
# Run after: (none)
# Run before: 02_ex.R, 03_ds.R, and all subsequent domain scripts
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(301)

# ── Study constants ────────────────────────────────────────────────────────────
STUDYID       <- "TORIVUMAB-NSCLC-301"
N_TOTAL       <- 450L
N_ACTIVE      <- 300L
N_PLACEBO     <- 150L
ENROLL_START  <- as.Date("2022-01-15")   # first subject enrolled (C1D1)
ENROLL_END    <- as.Date("2023-07-15")   # last subject enrolled (~18 months)
DATA_CUTOFF   <- as.Date("2025-01-31")   # analysis data cut (~38 months post-first)
MAX_CYCLES    <- 35L                      # 35 × 21 = 735 days max treatment
MAX_TREAT_DAYS <- MAX_CYCLES * 21L

# Survival assumptions benchmarked against KEYNOTE-024 (Reck et al., NEJM 2016)
MEDIAN_OS_TOR  <- 21.5   # months; derived from HR 0.65 vs control 14.0 m
MEDIAN_OS_PBO  <- 14.0   # months
MEDIAN_PFS_TOR <- 11.0   # months; derived from HR 0.55 vs control 6.0 m
MEDIAN_PFS_PBO <-  6.0   # months
DROPOUT_RATE   <-  0.10  # 10% administrative dropout (MCAR)

# Helper: months → days
m2d <- function(m) m * 30.4375

# Exponential rate from median
exp_rate <- function(median_months) log(2) / m2d(median_months)


# ── Site configuration ─────────────────────────────────────────────────────────
# 60 sites: 18 North America, 24 Europe, 18 Asia-Pacific
# One fixed country per site; proportional to real multinational NSCLC trial sites

site_na <- tibble(
  SITEID = sprintf("%03d", 101:118),
  region = "NORTH AMERICA",
  COUNTRY = c(
    rep("USA", 12),   # 12 US sites
    rep("CAN",  6)    #  6 Canadian sites
  )
)

site_eu <- tibble(
  SITEID = sprintf("%03d", 201:224),
  region = "EUROPE",
  COUNTRY = c(
    rep("DEU", 5), rep("GBR", 5), rep("FRA", 4),
    rep("NLD", 3), rep("ESP", 3), rep("ITA", 2),
    rep("BEL", 1), rep("SWE", 1)
  )
)

site_apac <- tibble(
  SITEID = sprintf("%03d", 301:318),
  region = "ASIA-PACIFIC",
  COUNTRY = c(
    rep("JPN", 6),   # 6 Japan sites
    rep("KOR", 4),   # 4 Korea
    rep("AUS", 3),   # 3 Australia
    rep("CHN", 3),   # 3 China
    rep("TWN", 2)    # 2 Taiwan
  )
)

site_info <- bind_rows(site_na, site_eu, site_apac)


# ── Stratification grid ────────────────────────────────────────────────────────
# Strata: Histology (Squamous/Non-squamous) × Region (NA/EU/APAC)
# Proportions: SQ ~30%, NSQ ~70%; NA ~30%, EU ~40%, APAC ~30%
# Treatment: 2:1 (active:placebo) within each stratum

strat_props <- expand.grid(
  histology = c("SQUAMOUS", "NON-SQUAMOUS"),
  region    = c("NORTH AMERICA", "EUROPE", "ASIA-PACIFIC"),
  stringsAsFactors = FALSE
) %>%
  mutate(
    hist_p = ifelse(histology == "SQUAMOUS", 0.30, 0.70),
    reg_p  = case_when(
      region == "NORTH AMERICA" ~ 0.30,
      region == "EUROPE"        ~ 0.40,
      region == "ASIA-PACIFIC"  ~ 0.30
    ),
    prop    = hist_p * reg_p,
    n_total = round(prop * N_TOTAL),
    n_active = round(n_total * (N_ACTIVE / N_TOTAL)),
    n_pbo    = n_total - n_active
  )

# Correct rounding: force exact totals in stratum 1 (SQUAMOUS, NA)
strat_props$n_total[1]  <- strat_props$n_total[1]  + (N_TOTAL  - sum(strat_props$n_total))
strat_props$n_active[1] <- strat_props$n_active[1] + (N_ACTIVE - sum(strat_props$n_active))
strat_props$n_pbo[1]    <- strat_props$n_total[1]  - strat_props$n_active[1]

stopifnot(sum(strat_props$n_total) == N_TOTAL)
stopifnot(sum(strat_props$n_active) == N_ACTIVE)
stopifnot(sum(strat_props$n_pbo) == N_PLACEBO)


# ── Generate subject list with block randomisation ─────────────────────────────
subjects <- map_dfr(seq_len(nrow(strat_props)), function(i) {
  sg <- strat_props[i, ]
  n  <- sg$n_total

  # Sites matching this region
  region_sites <- site_info %>%
    filter(region == sg$region) %>%
    pull(SITEID)

  # Assign subjects to sites (approximately equal load per site)
  site_assign <- sample(region_sites, n, replace = TRUE)

  # Exact 2:1 treatment allocation within stratum (shuffled, not truncated blocks)
  # strat_props already guarantees exact n_active / n_pbo counts
  trt <- sample(c(rep("TOR", sg$n_active), rep("PBO", sg$n_pbo)))

  tibble(
    histology = sg$histology,
    region    = sg$region,
    SITEID    = site_assign,
    ARMCD     = trt
  )
})

# Assign sequential subject numbers within each site
subjects <- subjects %>%
  arrange(SITEID) %>%
  group_by(SITEID) %>%
  mutate(
    SUBJID  = paste0(SITEID, "-", sprintf("%03d", row_number()))
  ) %>%
  ungroup() %>%
  mutate(
    USUBJID  = paste0(STUDYID, "-", SUBJID),
    ARM      = ifelse(ARMCD == "TOR", "TORIVUMAB 200 MG Q3W", "PLACEBO"),
    ACTARMCD = ARMCD,
    ACTARM   = ARM,
    STUDYID  = STUDYID,
    DOMAIN   = "DM"
  ) %>%
  left_join(site_info %>% select(SITEID, COUNTRY), by = "SITEID")

n <- nrow(subjects)
stopifnot(n == N_TOTAL)
stopifnot(sum(subjects$ARMCD == "TOR") == N_ACTIVE)
stopifnot(sum(subjects$ARMCD == "PBO") == N_PLACEBO)


# ── Demographics ───────────────────────────────────────────────────────────────

# Age (NSCLC, first-line): median ~64, SD ~9, range 40–82
# KEYNOTE-024: median 65 (range 33–90); squamous slightly older
age_mean <- ifelse(subjects$histology == "SQUAMOUS", 65.0, 63.5)
AGE <- as.integer(
  pmin(pmax(round(rnorm(n, mean = age_mean, sd = 8.5)), 40L), 82L)
)

# Sex: ~58% male overall; slightly higher in squamous (historically)
p_male <- ifelse(subjects$histology == "SQUAMOUS", 0.64, 0.55)
SEX <- ifelse(runif(n) < p_male, "M", "F")

# Race: region-stratified distributions
# CDISC CT values: WHITE | BLACK OR AFRICAN AMERICAN | ASIAN |
#   AMERICAN INDIAN OR ALASKA NATIVE | NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER | OTHER
RACE <- character(n)
for (i in seq_len(n)) {
  rgn <- subjects$region[i]
  if (rgn == "NORTH AMERICA") {
    RACE[i] <- sample(
      c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN",
        "AMERICAN INDIAN OR ALASKA NATIVE", "OTHER"),
      1L, prob = c(0.62, 0.13, 0.07, 0.02, 0.16)
    )
  } else if (rgn == "EUROPE") {
    RACE[i] <- sample(
      c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN", "OTHER"),
      1L, prob = c(0.84, 0.05, 0.06, 0.05)
    )
  } else {
    # Asia-Pacific
    RACE[i] <- sample(
      c("ASIAN", "WHITE", "OTHER"),
      1L, prob = c(0.93, 0.04, 0.03)
    )
  }
}

# Ethnicity: Hispanic/Latino primarily in North America
p_hisp <- ifelse(subjects$region == "NORTH AMERICA", 0.11, 0.02)
ETHNIC <- ifelse(
  runif(n) < p_hisp,
  "HISPANIC OR LATINO",
  "NOT HISPANIC OR LATINO"
)


# ── Study dates ────────────────────────────────────────────────────────────────

# Enrolment (C1D1): uniform over 18-month accrual window
# Sort by enrolment date to give realistic site activation pattern
enroll_day_offsets <- sort(
  sample(0L:as.integer(ENROLL_END - ENROLL_START), n, replace = FALSE)
)
C1D1_date <- ENROLL_START + enroll_day_offsets

# Informed consent: 7–28 days before C1D1 (screening window)
ic_offset  <- sample(7L:28L, n, replace = TRUE)
RFICDTC_date <- C1D1_date - ic_offset

# Date of demographics collection: same day as informed consent or 1–3 days later
dm_date_offset <- sample(0L:3L, n, replace = TRUE)
DMDTC_date <- RFICDTC_date + dm_date_offset

# Date of birth: derived from age and C1D1
# Random day-within-year offset so BRTHDTC is not always Jan 15
bday_offset  <- sample(0L:364L, n, replace = TRUE)
BRTHDTC_date <- C1D1_date - round(AGE * 365.25) - bday_offset


# ── Survival outcomes ─────────────────────────────────────────────────────────
# OS time from exponential; PFS time used to determine last treatment date

# OS: exponential with arm-specific rate
os_days_raw <- ifelse(
  subjects$ARMCD == "TOR",
  rexp(n, rate = exp_rate(MEDIAN_OS_TOR)),
  rexp(n, rate = exp_rate(MEDIAN_OS_PBO))
)
os_days_raw <- pmax(round(os_days_raw), 1L)

# PFS: exponential with arm-specific rate
pfs_days_raw <- ifelse(
  subjects$ARMCD == "TOR",
  rexp(n, rate = exp_rate(MEDIAN_PFS_TOR)),
  rexp(n, rate = exp_rate(MEDIAN_PFS_PBO))
)
pfs_days_raw <- pmax(round(pfs_days_raw), 1L)

# PFS must be ≤ OS (progression before death; otherwise PFS censored at OS)
pfs_days_raw <- pmin(pfs_days_raw, os_days_raw)

# Administrative dropout (MCAR): exponential with 10% rate over 36 months
dropout_lambda  <- -log(1 - DROPOUT_RATE) / m2d(36)
dropout_days    <- pmax(round(rexp(n, rate = dropout_lambda)), 1L)

# Calendar dates of events
death_date    <- C1D1_date + os_days_raw
prog_date     <- C1D1_date + pfs_days_raw
dropout_date  <- C1D1_date + dropout_days

# Observed OS: min(death, dropout, cutoff)
obs_os_days   <- pmin(os_days_raw, dropout_days,
                      as.integer(DATA_CUTOFF - C1D1_date))
obs_os_date   <- C1D1_date + obs_os_days

# Death indicator: died on-study (not dropped out first, within cutoff)
CNSR_OS   <- as.integer(!(os_days_raw <= dropout_days &
                            death_date <= DATA_CUTOFF))  # 0=event, 1=censored
DTHFL_val <- ifelse(CNSR_OS == 0L, "Y", "")
DTHDTC_val <- ifelse(CNSR_OS == 0L, format(death_date, "%Y-%m-%d"), "")

# Last treatment date: min(PFS, max cycles, dropout, cutoff) from C1D1
last_treat_days <- pmin(
  pfs_days_raw,
  MAX_TREAT_DAYS,
  dropout_days,
  as.integer(DATA_CUTOFF - C1D1_date)
)
# Snap to Q3W cycle boundary (nearest multiple of 21 ≥ 1)
n_cycles_completed  <- pmax(floor(last_treat_days / 21L), 0L)
last_dose_days      <- n_cycles_completed * 21L
# At minimum, subject received at least 1 dose (Day 1)
last_dose_days      <- pmax(last_dose_days, 0L)
last_dose_date      <- C1D1_date + last_dose_days

# EOT date: 30 days post last dose
eot_date <- last_dose_date + 30L

# RFSTDTC / RFXSTDTC = C1D1 (first dose for all enrolled subjects)
RFSTDTC_val  <- format(C1D1_date,      "%Y-%m-%d")
RFXSTDTC_val <- format(C1D1_date,      "%Y-%m-%d")

# RFXENDTC = last dose date
RFXENDTC_val <- format(last_dose_date, "%Y-%m-%d")

# RFENDTC = last date on study (last contact: death or obs_os_date)
RFENDTC_val  <- format(obs_os_date,    "%Y-%m-%d")

# RFPENDTC = last date status known (= RFENDTC for all)
RFPENDTC_val <- format(obs_os_date,    "%Y-%m-%d")


# ── Assemble SDTM DM dataset ───────────────────────────────────────────────────
DM <- subjects %>%
  mutate(
    BRTHDTC  = format(BRTHDTC_date,  "%Y-%m-%d"),
    AGE      = AGE,
    AGEU     = "YEARS",
    SEX      = SEX,
    RACE     = RACE,
    ETHNIC   = ETHNIC,
    DMDTC    = format(DMDTC_date,    "%Y-%m-%d"),
    RFICDTC  = format(RFICDTC_date,  "%Y-%m-%d"),
    RFSTDTC  = RFSTDTC_val,
    RFXSTDTC = RFXSTDTC_val,
    RFXENDTC = RFXENDTC_val,
    RFENDTC  = RFENDTC_val,
    RFPENDTC = RFPENDTC_val,
    DTHFL    = DTHFL_val,
    DTHDTC   = DTHDTC_val
  ) %>%
  # SDTM variable order (SDTMIG v3.4 DM domain)
  select(
    STUDYID, DOMAIN, USUBJID, SUBJID, RFSTDTC, RFENDTC,
    RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC,
    DTHDTC, DTHFL,
    SITEID, BRTHDTC, AGE, AGEU, SEX, RACE, ETHNIC,
    ARMCD, ARM, ACTARMCD, ACTARM,
    COUNTRY, DMDTC
  )


# ── Supplementary DM (SUPPDM) ─────────────────────────────────────────────────
# Stratification variables not in core DM domain go to SUPPDM
SUPPDM <- subjects %>%
  mutate(
    # Histology stratum
    HIST_QNAM   = "HISTSCAT",
    HIST_QLABEL = "Histology Stratum",
    HIST_QVAL   = histology,
    HIST_QORIG  = "ASSIGNED",
    HIST_QEVAL  = "",

    # Region stratum
    REG_QNAM    = "REGION1",
    REG_QLABEL  = "Geographic Region",
    REG_QVAL    = region,
    REG_QORIG   = "ASSIGNED",
    REG_QEVAL   = ""
  ) %>%
  select(STUDYID, RDOMAIN = DOMAIN, USUBJID, SUBJID,
         HIST_QNAM, HIST_QLABEL, HIST_QVAL, HIST_QORIG, HIST_QEVAL,
         REG_QNAM,  REG_QLABEL,  REG_QVAL,  REG_QORIG,  REG_QEVAL)

# Pivot SUPPDM to long format (SDTM SUPP-- structure)
SUPPDM_long <- bind_rows(
  SUPPDM %>% transmute(
    STUDYID, RDOMAIN, USUBJID, IDVAR = "SUBJID", IDVARVAL = SUBJID,
    QNAM = HIST_QNAM, QLABEL = HIST_QLABEL, QVAL = HIST_QVAL,
    QORIG = HIST_QORIG, QEVAL = HIST_QEVAL
  ),
  SUPPDM %>% transmute(
    STUDYID, RDOMAIN, USUBJID, IDVAR = "SUBJID", IDVARVAL = SUBJID,
    QNAM = REG_QNAM, QLABEL = REG_QLABEL, QVAL = REG_QVAL,
    QORIG = REG_QORIG, QEVAL = REG_QEVAL
  )
) %>%
  arrange(USUBJID, QNAM)


# ── Subject backbone (downstream use) ─────────────────────────────────────────
# This CSV is the shared reference for all downstream scripts.
# Every domain script joins to this by USUBJID.
subject_backbone <- subjects %>%
  mutate(
    C1D1_DATE       = as.character(C1D1_date),
    RFICDTC_DATE    = as.character(RFICDTC_date),
    LAST_DOSE_DATE  = as.character(last_dose_date),
    EOT_DATE        = as.character(eot_date),
    OBS_OS_DATE     = as.character(obs_os_date),
    DEATH_DATE      = as.character(ifelse(CNSR_OS == 0L, as.character(death_date), NA_character_)),
    PROG_DATE       = as.character(prog_date),
    DROPOUT_DATE    = as.character(dropout_date),
    DATA_CUTOFF     = as.character(DATA_CUTOFF),
    OS_DAYS_RAW     = os_days_raw,
    PFS_DAYS_RAW    = pfs_days_raw,
    OBS_OS_DAYS     = obs_os_days,
    LAST_DOSE_DAYS  = last_dose_days,
    N_CYCLES        = n_cycles_completed,
    CNSR_OS         = CNSR_OS,    # 0 = death event, 1 = censored
    CNSR_PFS        = as.integer(!(pfs_days_raw == os_days_raw | prog_date <= DATA_CUTOFF)),
    DTHFL           = DTHFL_val,
    AGE             = AGE,
    SEX             = SEX,
    RACE            = RACE,
    ETHNIC          = ETHNIC
  ) %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID, ARMCD, ARM,
    histology, region, COUNTRY,
    C1D1_DATE, RFICDTC_DATE, LAST_DOSE_DATE, EOT_DATE,
    OBS_OS_DATE, DEATH_DATE, PROG_DATE, DROPOUT_DATE, DATA_CUTOFF,
    OS_DAYS_RAW, PFS_DAYS_RAW, OBS_OS_DAYS, LAST_DOSE_DAYS,
    N_CYCLES, CNSR_OS, CNSR_PFS, DTHFL,
    AGE, SEX, RACE, ETHNIC
  )


# ── Write outputs ──────────────────────────────────────────────────────────────
dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

# SDTM DM domain → Parquet
write_parquet(DM, "sdtm/dm.parquet")

# SDTM SUPPDM → Parquet
write_parquet(SUPPDM_long, "sdtm/suppdm.parquet")

# Raw demographics → CSV (for traceability / inspection)
write.csv(DM, "data-raw/raw_data/dm_raw.csv", row.names = FALSE, na = "")

# Subject backbone → CSV (consumed by all downstream scripts)
write.csv(subject_backbone, "data-raw/raw_data/subject_backbone.csv",
          row.names = FALSE, na = "")


# ── Validation checks ──────────────────────────────────────────────────────────
cat("\n=== DM Domain Validation ===\n")
cat(sprintf("  Total subjects      : %d (expected %d)\n", nrow(DM), N_TOTAL))
cat(sprintf("  Active (TOR)        : %d (expected %d)\n",
            sum(DM$ARMCD == "TOR"), N_ACTIVE))
cat(sprintf("  Placebo (PBO)       : %d (expected %d)\n",
            sum(DM$ARMCD == "PBO"), N_PLACEBO))
cat(sprintf("  Deaths on-study     : %d (%.1f%%)\n",
            sum(DM$DTHFL == "Y", na.rm = TRUE),
            100 * sum(DM$DTHFL == "Y", na.rm = TRUE) / N_TOTAL))
cat(sprintf("  Median age          : %.1f years\n",
            median(DM$AGE)))
cat(sprintf("  Sex (M/F)           : %d / %d\n",
            sum(DM$SEX == "M"), sum(DM$SEX == "F")))
cat(sprintf("  USUBJID unique      : %s\n",
            ifelse(n_distinct(DM$USUBJID) == nrow(DM), "PASS", "FAIL")))
cat(sprintf("  No missing RFSTDTC  : %s\n",
            ifelse(all(nchar(DM$RFSTDTC) == 10L), "PASS", "FAIL")))
cat(sprintf("  RFENDTC >= RFSTDTC  : %s\n",
            ifelse(all(DM$RFENDTC >= DM$RFSTDTC, na.rm = TRUE), "PASS", "FAIL")))
cat(sprintf("  Backbone rows       : %d\n", nrow(subject_backbone)))
cat("\n  Arm × Histology breakdown:\n")
print(as.data.frame(table(subject_backbone$ARMCD, subject_backbone$histology)))
cat("\n  Arm × Region breakdown:\n")
print(as.data.frame(table(subject_backbone$ARMCD, subject_backbone$region)))
cat(sprintf("\n  Outputs written:\n"))
cat("    sdtm/dm.parquet\n")
cat("    sdtm/suppdm.parquet\n")
cat("    data-raw/raw_data/dm_raw.csv\n")
cat("    data-raw/raw_data/subject_backbone.csv\n")
cat("\n=== DM generation complete ===\n")
