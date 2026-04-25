###############################################################################
# 10_overall_response.R
# Generates raw/overall_response.csv
# Investigator-assessed response per RECIST 1.1 at each tumor assessment visit
# Derives response from tumor_measurements (target lesion sum and new lesions)
# Depends on: tumor_measurements, demographics, rand_dates
###############################################################################

message("  Simulating overall response assessments...")

library(dplyr)
library(lubridate)

tm <- tumor_measurements
dm <- demographics

# ── compute target lesion sum-of-diameters per subject per visit ───────────
target_sums <- tm %>%
  filter(LESION_TYPE == "Target", LESION_ID != "NEW_1") %>%
  group_by(SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME) %>%
  summarise(
    SUM_LD      = sum(as.numeric(LONGEST_DIAMETER_MM), na.rm = TRUE),
    N_TARGETS   = n(),
    .groups = "drop"
  )

baseline_sums <- target_sums %>%
  filter(VISIT_NAME == "BASELINE") %>%
  select(SUBJECT_ID, BASELINE_SUM = SUM_LD)

non_target_status <- tm %>%
  filter(LESION_TYPE == "Non-target") %>%
  group_by(SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME) %>%
  summarise(
    NT_PD = any(RESPONSE_CATEGORY == "Unequivocal PD"),
    .groups = "drop"
  )

new_lesion_flag <- tm %>%
  filter(NEW_LESION == "Y") %>%
  group_by(SUBJECT_ID, ASSESSMENT_DATE, VISIT_NAME) %>%
  summarise(HAS_NEW = TRUE, .groups = "drop")

# On-study visits only
on_study <- target_sums %>%
  filter(VISIT_NAME != "BASELINE") %>%
  left_join(baseline_sums, by = "SUBJECT_ID") %>%
  left_join(non_target_status, by = c("SUBJECT_ID", "ASSESSMENT_DATE", "VISIT_NAME")) %>%
  left_join(new_lesion_flag,   by = c("SUBJECT_ID", "ASSESSMENT_DATE", "VISIT_NAME")) %>%
  mutate(
    NT_PD   = ifelse(is.na(NT_PD),   FALSE, NT_PD),
    HAS_NEW = ifelse(is.na(HAS_NEW), FALSE, HAS_NEW),
    PCT_CHG = ifelse(!is.na(BASELINE_SUM) & BASELINE_SUM > 0,
                     (SUM_LD - BASELINE_SUM) / BASELINE_SUM * 100, NA)
  )

# ── RECIST 1.1 investigator response assignment ────────────────────────────
assign_response <- function(sum_ld, pct_chg, nt_pd, has_new, baseline_sum) {
  if (is.na(pct_chg)) return("NE")

  # PD criteria
  if (has_new)                                   return("PD")
  if (nt_pd)                                     return("PD")
  if (pct_chg >= 20 && sum_ld > baseline_sum * 0.80) return("PD")

  # CR (all targets 0, all NT absent/CR, no new)
  if (sum_ld == 0 && !nt_pd && !has_new)         return("CR")

  # PR
  if (pct_chg <= -30)                            return("PR")

  # SD
  if (pct_chg > -30 && pct_chg < 20)            return("SD")

  return("NE")
}

on_study <- on_study %>%
  rowwise() %>%
  mutate(
    INVESTIGATOR_RESPONSE = assign_response(
      SUM_LD, PCT_CHG, NT_PD, HAS_NEW,
      ifelse(is.na(BASELINE_SUM), 0, BASELINE_SUM)
    )
  ) %>%
  ungroup()

# ── add small investigator variability (realistic read inconsistency) ──────
# ~5% of assessments may differ by one category (SD<->PR or SD<->PD)
shift_response <- function(resp) {
  if (runif(1) > 0.05) return(resp)
  if (resp == "SD")   return(sample(c("PR", "PD"), 1, prob = c(0.6, 0.4)))
  if (resp == "PR")   return(sample(c("SD", "PR"), 1, prob = c(0.3, 0.7)))
  if (resp == "PD")   return(sample(c("SD", "PD"), 1, prob = c(0.25, 0.75)))
  return(resp)
}

on_study$INVESTIGATOR_RESPONSE <- sapply(on_study$INVESTIGATOR_RESPONSE, shift_response)

overall_response <- on_study %>%
  transmute(
    SUBJECT_ID          = SUBJECT_ID,
    ASSESSMENT_DATE     = ASSESSMENT_DATE,
    VISIT_NAME          = VISIT_NAME,
    INVESTIGATOR_RESPONSE = INVESTIGATOR_RESPONSE,
    ASSESSMENT_TYPE     = "Investigator"
  ) %>%
  arrange(SUBJECT_ID, ASSESSMENT_DATE)

assign("overall_response", overall_response, envir = .GlobalEnv)

write.csv(overall_response,
          file      = file.path(RAW_DIR, "overall_response.csv"),
          row.names = FALSE,
          na        = "")

message("  overall_response.csv written: ", nrow(overall_response), " rows")
resp_counts <- table(overall_response$INVESTIGATOR_RESPONSE)
message("    Response distribution: ", paste(names(resp_counts), resp_counts, sep = "=", collapse = ", "))
