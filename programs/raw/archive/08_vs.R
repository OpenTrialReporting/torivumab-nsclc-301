# =============================================================================
# torivumab guidelines loaded
# 08_vs.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: VS (Vital Signs)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(308)
# =============================================================================
#
# Outputs:
#   sdtm/vs.parquet              — SDTM VS domain (Parquet)
#   data-raw/raw_data/vs_raw.csv — Raw vital signs records
#
# Tests: HEIGHT (SCR only), WEIGHT, SYSBP, DIABP, TEMP, PULSE, RESP, ECOG
# Visits: SCR, C1D1, C1D8, C1D15, C1D22, C2D22, C3D22, …, EOT, FU01–FU03
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
})

set.seed(308)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    OBS_OS_DATE = as.Date(OBS_OS_DATE),
    PROG_DATE   = as.Date(PROG_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"
n_subj  <- nrow(backbone)

# ── Visit schedule (study day from C1D1; 999 = EOT placeholder) ───────────────
visit_schedule <- data.frame(
  VISIT    = c("SCR","C1D1","C1D8","C1D15","C1D22","C2D22","C3D22","C4D22",
               "C5D22","C6D22","C7D22","C8D22","C9D22","C10D22","EOT",
               "FU01","FU02","FU03"),
  VDAY     = c( -14L,  1L,   8L,   15L,   22L,   43L,   85L,  106L,
                127L, 148L,  169L,  190L,  211L,  232L,  999L,
               1090L, 1180L, 1365L),
  VISITNUM = 1:18,
  stringsAsFactors = FALSE
)

# ECOG only at selected visits
ecog_visits <- c("SCR","C1D1","C1D22","C2D22","C3D22","C4D22","C5D22",
                 "C6D22","C7D22","C8D22","C9D22","C10D22","EOT","FU01","FU02","FU03")

# ── Per-subject baseline parameters (vectorised) ──────────────────────────────
is_male   <- backbone$SEX == "M"
h_mean    <- ifelse(is_male, 173.0, 161.0)
w_mean    <- ifelse(is_male,  78.0,  65.0)

subj_ht   <- round(rnorm(n_subj, h_mean, 8.0), 1)
subj_wt0  <- round(rnorm(n_subj, w_mean, 12.0), 1)
subj_sbp  <- round(rnorm(n_subj, 128.0, 14.0))
subj_dbp  <- round(rnorm(n_subj, 80.0, 9.0))

# ── Cross-join subjects × visits, then filter ─────────────────────────────────
sv <- merge(
  data.frame(subj_idx = seq_len(n_subj)),
  visit_schedule,
  by = NULL   # cross join
)
sv$USUBJID    <- backbone$USUBJID[sv$subj_idx]
sv$C1D1       <- backbone$C1D1_DATE[sv$subj_idx]
sv$EOT_DAY    <- as.integer(backbone$EOT_DATE[sv$subj_idx] - backbone$C1D1_DATE[sv$subj_idx]) + 1L
sv$OBS_END    <- pmin(backbone$OBS_OS_DATE[sv$subj_idx], backbone$DATA_CUTOFF[sv$subj_idx])
sv$PROG_DATE  <- backbone$PROG_DATE[sv$subj_idx]
sv$WT0        <- subj_wt0[sv$subj_idx]
sv$HT         <- subj_ht[sv$subj_idx]
sv$SBP0       <- subj_sbp[sv$subj_idx]
sv$DBP0       <- subj_dbp[sv$subj_idx]

# Resolve EOT day
sv$VDAY_ACT <- ifelse(sv$VISIT == "EOT", sv$EOT_DAY, sv$VDAY)

# Calendar date
sv$VDATE <- sv$C1D1 + sv$VDAY_ACT - 1L

# Apply ±3 day window jitter (not SCR or C1D1)
n_rows      <- nrow(sv)
jitter      <- sample(-3L:3L, n_rows, replace = TRUE)
sv$VDATE    <- as.Date(ifelse(sv$VISIT %in% c("SCR","C1D1"),
                              as.integer(sv$VDATE),
                              as.integer(sv$VDATE) + jitter),
                       origin = "1970-01-01")

# Drop rows past last contact
sv <- sv[sv$VDATE <= sv$OBS_END, ]

# ── Generate measurements per row ─────────────────────────────────────────────
n_v <- nrow(sv)

days_on       <- pmax(as.integer(sv$VDATE - sv$C1D1), 0L)
days_post_prog <- pmax(as.integer(sv$VDATE - sv$PROG_DATE), 0L)
wt_decline    <- 0.02 * days_post_prog / 30.0
wt_val        <- pmax(round(sv$WT0 * (1 - wt_decline) + rnorm(n_v, 0, 1.2), 1), 35.0)

# ECOG
p_ecog2 <- pmin(0.05 + days_post_prog * 0.001, 0.35)
ecog_val <- integer(n_v)
for (i in seq_len(n_v)) {
  if (!sv$VISIT[i] %in% ecog_visits) next
  ecog_val[i] <- sample(0L:2L, 1L, prob = c(
    max(0.45 - p_ecog2[i]/2, 0.05),
    max(0.45 - p_ecog2[i]/2, 0.05),
    p_ecog2[i]
  ))
}

# Temp: 1% febrile
temp_base <- round(rnorm(n_v, 36.7, 0.35), 1)
is_febrile <- runif(n_v) < 0.01
temp_val   <- ifelse(is_febrile, round(runif(n_v, 38.0, 39.5), 1), temp_base)

# Build all tests via rbind (faster than nested list-append)
make_vs_rows <- function(testcd, test, orresu, val, visitdf) {
  data.frame(
    STUDYID  = STUDYID,
    DOMAIN   = "VS",
    USUBJID  = visitdf$USUBJID,
    VSTESTCD = testcd,
    VSTEST   = test,
    VSORRES  = as.character(val),
    VSORRESU = orresu,
    VSSTRESC = as.character(val),
    VSSTRESN = as.numeric(val),
    VSSTRESU = orresu,
    VSDTC    = format(visitdf$VDATE, "%Y-%m-%d"),
    VSDY     = as.integer(visitdf$VDATE - visitdf$C1D1) + 1L,
    VISIT    = visitdf$VISIT,
    VISITNUM = visitdf$VISITNUM,
    stringsAsFactors = FALSE
  )
}

scr_rows  <- sv[sv$VISIT == "SCR", ]
ecog_rows <- sv[sv$VISIT %in% ecog_visits, ]

VS_parts <- list(
  # HEIGHT — screening only
  make_vs_rows("HEIGHT", "Height", "cm",
               scr_rows$HT, scr_rows),
  # WEIGHT — all visits
  make_vs_rows("WEIGHT", "Weight", "kg",
               wt_val, sv),
  # SYSBP
  make_vs_rows("SYSBP", "Systolic Blood Pressure", "mmHg",
               round(sv$SBP0 + rnorm(n_v, 0, 4.0)), sv),
  # DIABP
  make_vs_rows("DIABP", "Diastolic Blood Pressure", "mmHg",
               round(sv$DBP0 + rnorm(n_v, 0, 3.0)), sv),
  # TEMP
  make_vs_rows("TEMP", "Temperature", "C",
               temp_val, sv),
  # PULSE
  make_vs_rows("PULSE", "Pulse Rate", "beats/min",
               round(rnorm(n_v, 76.0, 10.0)), sv),
  # RESP
  make_vs_rows("RESP", "Respiratory Rate", "breaths/min",
               round(rnorm(n_v, 17.0, 2.0)), sv),
  # ECOG — selected visits only
  make_vs_rows("ECOG", "ECOG Performance Status", "",
               ecog_val[sv$VISIT %in% ecog_visits], ecog_rows)
)

VS <- do.call(rbind, VS_parts) %>%
  arrange(USUBJID, VSDTC, VSTESTCD) %>%
  group_by(USUBJID) %>%
  mutate(VSSEQ = row_number()) %>%
  ungroup() %>%
  mutate(EPOCH = ifelse(VSDY < 1L, "SCREENING",
                        ifelse(VSDY > as.integer(
                          backbone$EOT_DATE[match(USUBJID, backbone$USUBJID)] -
                          backbone$C1D1_DATE[match(USUBJID, backbone$USUBJID)]) + 31L,
                          "FOLLOW-UP", "TREATMENT")))

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(VS, "sdtm/vs.parquet")
write.csv(VS, "data-raw/raw_data/vs_raw.csv", row.names = FALSE, na = "")

cat("\n=== VS Domain Validation ===\n")
cat(sprintf("  Total VS records        : %d\n", nrow(VS)))
cat(sprintf("  Subjects with VS data   : %d / %d\n",
            n_distinct(VS$USUBJID), n_subj))
cat(sprintf("  VS tests generated      : %s\n",
            paste(sort(unique(VS$VSTESTCD)), collapse = ", ")))
cat(sprintf("  Mean weight (kg)        : %.1f\n",
            mean(VS$VSSTRESN[VS$VSTESTCD == "WEIGHT"], na.rm = TRUE)))
cat(sprintf("  Mean SBP (mmHg)         : %.1f\n",
            mean(VS$VSSTRESN[VS$VSTESTCD == "SYSBP"], na.rm = TRUE)))
cat("\n  Outputs written: sdtm/vs.parquet, data-raw/raw_data/vs_raw.csv\n")
cat("=== VS generation complete ===\n")
