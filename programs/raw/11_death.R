###############################################################################
# 11_death.R
# Generates raw/death.csv
# Only subjects who died before data cutoff
# Depends on: demographics, died_before_cutoff, death_date_potential, disposition
###############################################################################

message("  Simulating death records...")

library(dplyr)

dm    <- demographics
n     <- nrow(dm)

cause_detail_map <- list(
  "Disease progression" = c(
    "Progression of NSCLC",
    "Metastatic lung cancer",
    "Respiratory failure due to disease progression",
    "Brain metastases - disease progression",
    "Multi-organ failure secondary to cancer progression",
    "Hepatic failure due to liver metastases"
  ),
  "Adverse event" = c(
    "Sepsis",
    "Pneumonitis - immune-mediated",
    "Respiratory failure",
    "Pulmonary embolism",
    "Cardiac arrest",
    "Gastrointestinal haemorrhage"
  ),
  "Other" = c(
    "Cardiovascular event",
    "Stroke",
    "Road traffic accident",
    "Suicide",
    "Unknown cause",
    "Comorbid illness"
  ),
  "Unknown" = c(
    "Not reported",
    "Unknown",
    "Pending autopsy",
    ""
  )
)

death_list <- list()

for (i in seq_len(n)) {
  if (!died_before_cutoff[i]) next

  subj_id    <- dm$SUBJECT_ID[i]
  death_dt   <- death_date_potential[i]
  disc_reason <- disposition$DISC_REASON[i]

  # Primary cause aligned with discontinuation reason where possible
  if (!is.na(disc_reason) && disc_reason == "Adverse Event") {
    primary_cause <- sample(c("Adverse event", "Disease progression"), 1,
                            prob = c(0.60, 0.40))
  } else {
    primary_cause <- sample(
      c("Disease progression", "Adverse event", "Other", "Unknown"),
      1, prob = c(0.72, 0.14, 0.08, 0.06)
    )
  }

  detail_pool <- cause_detail_map[[primary_cause]]
  cause_detail <- sample(detail_pool, 1)

  death_list[[length(death_list) + 1]] <- data.frame(
    SUBJECT_ID    = subj_id,
    DEATH_DATE    = format(death_dt, "%Y-%m-%d"),
    PRIMARY_CAUSE = primary_cause,
    CAUSE_DETAIL  = cause_detail,
    stringsAsFactors = FALSE
  )
}

death <- do.call(rbind, death_list)
row.names(death) <- NULL

assign("death", death, envir = .GlobalEnv)

write.csv(death,
          file      = file.path(RAW_DIR, "death.csv"),
          row.names = FALSE,
          na        = "")

message("  death.csv written: ", nrow(death), " rows")
message("    Primary causes: ",
        paste(names(table(death$PRIMARY_CAUSE)),
              table(death$PRIMARY_CAUSE), sep = "=", collapse = ", "))
