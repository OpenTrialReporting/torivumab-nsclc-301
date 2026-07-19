###############################################################################
# 16_subsequent_therapy.R
# Appends subsequent anti-cancer therapy records to raw/conmed.csv.
# Closes accepted limitation AL-02: post-trial / on-progression therapy was
# not previously simulated, breaking the T-EFF-12 OSWOT censoring rule.
#
# Model:
#   - Eligible: subjects who had PFS event PRECEDING death (i.e., progressors)
#     AND who survived ≥21 days after PD.
#   - ~40% of eligible subjects initiate subsequent therapy.
#   - Start date: PD date + 14-45 days (gap for re-evaluation).
#   - Realistic NSCLC 2L choices weighted by previous treatment arm:
#       Torivumab arm → DOCETAXEL (60%) | RAMUCIRUMAB+DOCETAXEL (25%) |
#                       single-agent chemo (15%)
#       Placebo arm   → PEMBROLIZUMAB (60%) | NIVOLUMAB (25%) |
#                       DOCETAXEL (15%)
#   - End date: continues until death or last contact (typical second-line
#     duration 4-9 months).
# Depends on: demographics, disposition, pfs_days_sim, died_before_cutoff
###############################################################################

message("  Simulating subsequent anti-cancer therapy...")

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
})

set.seed(20260316)  # local seed (AL-02 fix)

dm   <- demographics
disp <- disposition
n    <- nrow(dm)

is_trt_arm <- dm$TREATMENT_ARM == "Torivumab + Chemotherapy"

# A subject is a "progressor candidate" if their PFS event preceded death
# (so PD happened, not just death-without-PD). The simulation generates
# pfs_days_sim ≤ os_days_sim, so a subject is a progressor when
# pfs_days_sim < os_days_sim by at least a few days.
os_days <- get("os_days_sim", envir = .GlobalEnv)
pfs_days <- get("pfs_days_sim", envir = .GlobalEnv)
gap_days <- os_days - pfs_days
progressor <- gap_days >= 21    # PD with at least 3 weeks of post-PD time

# 40% of eligible progressors initiate subsequent therapy
get_subseq <- function(arm_is_trt) {
  if (arm_is_trt) {
    sample(c("DOCETAXEL", "RAMUCIRUMAB + DOCETAXEL", "GEMCITABINE"),
           1, prob = c(0.60, 0.25, 0.15))
  } else {
    sample(c("PEMBROLIZUMAB", "NIVOLUMAB", "DOCETAXEL"),
           1, prob = c(0.60, 0.25, 0.15))
  }
}

subseq_rows <- list()
for (i in seq_len(n)) {
  if (!progressor[i]) next
  if (runif(1) >= 0.40) next   # 40% of progressors initiate

  rand_dt <- as.Date(dm$RAND_DATE[i])
  pd_dt   <- rand_dt + pfs_days[i]

  # Subsequent therapy is only captured when progression and its re-evaluation
  # gap fall within the subject's follow-up (on/before last contact). Subjects
  # whose latent PD lies beyond last contact were censored first, so no record
  # is collected — otherwise the start date would post-date end of participation
  # (P21 SD1202). Last contact <= RFPENDTC, so a start before it is always in-window.
  last_dt <- as.Date(disp$LAST_CONTACT_DATE[i])
  if (is.na(last_dt)) last_dt <- pd_dt + 180
  start_d <- pd_dt + sample(14:45, 1)

  # Duration: 4-9 months, capped at last contact
  dur_d   <- sample(120:270, 1)
  end_d   <- min(start_d + dur_d, last_dt)
  ongoing <- end_d >= last_dt - 5    # still ongoing if reaches last contact

  drug    <- get_subseq(is_trt_arm[i])

  # Only capture the therapy if it starts within follow-up (on/before last
  # contact). The skip is placed AFTER all sampling so the RNG stream — and hence
  # every other subject's record — is unchanged; only out-of-window rows drop.
  if (start_d >= last_dt) next

  subseq_rows[[length(subseq_rows) + 1]] <- data.frame(
    SUBJECT_ID          = dm$SUBJECT_ID[i],
    DRUG_NAME_VERBATIM  = drug,
    START_DATE          = format(start_d, "%Y-%m-%d"),
    END_DATE            = if (ongoing) "" else format(end_d, "%Y-%m-%d"),
    INDICATION          = "Subsequent anti-cancer therapy",
    ONGOING             = if (ongoing) "Y" else "N",
    stringsAsFactors    = FALSE
  )
}

if (length(subseq_rows) == 0) {
  message("  No subsequent therapy records generated (unlikely).")
  return(invisible(NULL))
}

subseq <- do.call(rbind, subseq_rows)

# Append to the existing conmed.csv
conmed_path <- file.path(RAW_DIR, "conmed.csv")
existing <- read.csv(conmed_path, stringsAsFactors = FALSE)
combined <- bind_rows(existing, subseq) |>
  arrange(SUBJECT_ID, START_DATE)

write.csv(combined,
          file      = conmed_path,
          row.names = FALSE,
          na        = "")

assign("conmed", combined, envir = .GlobalEnv)

message(sprintf("  %d subsequent-therapy rows appended to conmed.csv (%d eligible progressors)",
                nrow(subseq), sum(progressor)))
message("  Drug distribution:")
print(table(subseq$DRUG_NAME_VERBATIM))
