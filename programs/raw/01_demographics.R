###############################################################################
# 01_demographics.R
# Generates raw/demographics.csv
# 450 subjects, 1:1 randomisation across 15 sites
###############################################################################

message("  Simulating demographics...")

# ── site assignments (~30/site) ────────────────────────────────────────────
site_ids <- paste0("SITE", sprintf("%03d", 1:N_SITES))
subject_site <- rep(site_ids, times = ceiling(N_SUBJECTS / N_SITES))[1:N_SUBJECTS]
subject_site <- sample(subject_site)  # shuffle

# ── subject IDs ───────────────────────────────────────────────────────────
subject_ids <- paste0(subject_site, "-", sprintf("%04d", seq_len(N_SUBJECTS)))

# ── treatment arm — strictly alternating then shuffled within site ─────────
arm_raw <- rep(ARMS, times = N_SUBJECTS / 2)
# Within each site, randomise order
arm_assigned <- character(N_SUBJECTS)
for (site in site_ids) {
  idx <- which(subject_site == site)
  n_s <- length(idx)
  arm_block <- rep(ARMS, times = ceiling(n_s / 2))[1:n_s]
  arm_assigned[idx] <- sample(arm_block)
}

# ── enrolment / consent / rand dates ──────────────────────────────────────
rand_dates <- sample(
  seq(ENROL_START, ENROL_END, by = "day"),
  size = N_SUBJECTS,
  replace = TRUE
)
rand_dates <- sort(rand_dates)  # roughly chronological

inform_consent_dates <- rand_dates - sample(7:21, N_SUBJECTS, replace = TRUE)

# ── demographics ───────────────────────────────────────────────────────────
age_at_rand <- sample(45:82, N_SUBJECTS, replace = TRUE)
birthdates   <- rand_dates - lubridate::years(age_at_rand) -
                sample(0:364, N_SUBJECTS, replace = TRUE)

sex_vals <- sample(c("Male", "Female"), N_SUBJECTS,
                   replace = TRUE, prob = c(0.58, 0.42))

race_opts <- c("White", "Asian", "Black or African American",
               "American Indian or Alaska Native", "Other", "Unknown")
race_probs <- c(0.52, 0.28, 0.10, 0.02, 0.05, 0.03)
race_vals  <- sample(race_opts, N_SUBJECTS, replace = TRUE, prob = race_probs)

ethnic_opts  <- c("Not Hispanic or Latino", "Hispanic or Latino",
                  "Not reported", "Unknown")
ethnic_probs <- c(0.80, 0.10, 0.06, 0.04)
ethnic_vals  <- sample(ethnic_opts, N_SUBJECTS, replace = TRUE, prob = ethnic_probs)

country_map <- c(
  SITE001 = "United States", SITE002 = "United States", SITE003 = "Canada",
  SITE004 = "Germany",       SITE005 = "France",        SITE006 = "United Kingdom",
  SITE007 = "Japan",         SITE008 = "South Korea",   SITE009 = "Australia",
  SITE010 = "Spain",         SITE011 = "Italy",         SITE012 = "Brazil",
  SITE013 = "United States", SITE014 = "Netherlands",   SITE015 = "Poland"
)
country_vals <- country_map[subject_site]

# ── ECOG ──────────────────────────────────────────────────────────────────
ecog_vals <- sample(0:2, N_SUBJECTS, replace = TRUE, prob = c(0.25, 0.55, 0.20))

# ── PDL1 ──────────────────────────────────────────────────────────────────
# Realistic distribution: bimodal — many low, some high
pdl1_score <- round(c(
  rbeta(round(N_SUBJECTS * 0.45), 1, 8) * 100,   # low scores 0-20
  rbeta(round(N_SUBJECTS * 0.30), 3, 5) * 100,   # medium 1-49
  rbeta(round(N_SUBJECTS * 0.25), 6, 3) * 100    # high >=50
)[sample(N_SUBJECTS)], 1)
pdl1_score <- pmax(0, pmin(100, pdl1_score))

pdl1_group <- case_when(
  pdl1_score < 1   ~ "Low <1%",
  pdl1_score < 50  ~ "Medium 1-49%",
  TRUE             ~ "High >=50%"
)

# ── histology ─────────────────────────────────────────────────────────────
histology_vals <- sample(c("Non-squamous", "Squamous"), N_SUBJECTS,
                         replace = TRUE, prob = c(0.68, 0.32))

# ── smoking ───────────────────────────────────────────────────────────────
smoking_vals <- sample(c("Former", "Current", "Never"), N_SUBJECTS,
                       replace = TRUE, prob = c(0.55, 0.30, 0.15))

# ── anthropometrics ───────────────────────────────────────────────────────
height_cm <- round(rnorm(N_SUBJECTS,
                         mean = ifelse(sex_vals == "Male", 174, 162),
                         sd   = 8), 1)
weight_kg <- round(rnorm(N_SUBJECTS,
                         mean = ifelse(sex_vals == "Male", 80, 68),
                         sd   = 14), 1)
weight_kg <- pmax(40, weight_kg)
height_cm <- pmax(145, pmin(200, height_cm))

# ── assemble ──────────────────────────────────────────────────────────────
demographics <- data.frame(
  SUBJECT_ID          = subject_ids,
  SITE_ID             = subject_site,
  BIRTHDATE           = format(birthdates, "%Y-%m-%d"),
  SEX                 = sex_vals,
  RACE                = race_vals,
  ETHNIC              = ethnic_vals,
  COUNTRY             = unname(country_vals),
  INFORM_CONSENT_DATE = format(inform_consent_dates, "%Y-%m-%d"),
  RAND_DATE           = format(rand_dates, "%Y-%m-%d"),
  TREATMENT_ARM       = arm_assigned,
  ECOG_BASELINE       = ecog_vals,
  PDL1_SCORE          = pdl1_score,
  PDL1_GROUP          = pdl1_group,
  HISTOLOGY           = histology_vals,
  SMOKING_STATUS      = smoking_vals,
  WEIGHT_KG           = weight_kg,
  HEIGHT_CM           = height_cm,
  SCREEN_FAIL         = "N",
  stringsAsFactors    = FALSE
)

# ── expose to global environment for downstream scripts ───────────────────
assign("demographics", demographics, envir = .GlobalEnv)

# ── write ─────────────────────────────────────────────────────────────────
write.csv(demographics,
          file      = file.path(RAW_DIR, "demographics.csv"),
          row.names = FALSE,
          na        = "")

message("  demographics.csv written: ", nrow(demographics), " rows")
