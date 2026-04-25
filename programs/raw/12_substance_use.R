###############################################################################
# 12_substance_use.R
# Generates raw/substance_use.csv
# Tobacco, Alcohol, Recreational drugs
# Depends on: demographics
###############################################################################

message("  Simulating substance use...")

library(dplyr)

dm <- demographics
n  <- nrow(dm)

su_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id <- dm$SUBJECT_ID[i]
  smoking  <- dm$SMOKING_STATUS[i]

  rows <- list()

  # ── Tobacco ───────────────────────────────────────────────────────────
  tobacco_status <- switch(smoking,
    "Current" = "Current user",
    "Former"  = "Former user",
    "Never"   = "Never used"
  )

  pack_years <- if (smoking == "Current") {
    round(runif(1, 10, 80), 1)
  } else if (smoking == "Former") {
    round(runif(1, 5, 60), 1)
  } else {
    NA
  }

  freq_tobacco <- switch(smoking,
    "Current" = sample(c("Daily", "Occasionally"), 1, prob = c(0.85, 0.15)),
    "Former"  = "Former - daily",
    "Never"   = "Never"
  )

  rows[[1]] <- data.frame(
    SUBJECT_ID   = subj_id,
    SUBSTANCE    = "Tobacco",
    USE_STATUS   = tobacco_status,
    PACK_YEARS   = if (is.na(pack_years)) "" else as.character(pack_years),
    FREQUENCY    = freq_tobacco,
    stringsAsFactors = FALSE
  )

  # ── Alcohol ───────────────────────────────────────────────────────────
  alc_status <- sample(c("Current user", "Former user", "Never used"),
                       1, prob = c(0.55, 0.20, 0.25))
  freq_alc <- switch(alc_status,
    "Current user" = sample(c("Daily", "Weekly", "Occasionally"),
                            1, prob = c(0.20, 0.45, 0.35)),
    "Former user"  = "Former",
    "Never used"   = "Never"
  )

  rows[[2]] <- data.frame(
    SUBJECT_ID   = subj_id,
    SUBSTANCE    = "Alcohol",
    USE_STATUS   = alc_status,
    PACK_YEARS   = "",
    FREQUENCY    = freq_alc,
    stringsAsFactors = FALSE
  )

  # ── Recreational drugs (not all subjects asked / not all disclose) ────
  if (runif(1) < 0.70) {  # 70% have entry
    rec_status <- sample(c("Never used", "Former user", "Current user"),
                         1, prob = c(0.80, 0.15, 0.05))
    freq_rec <- switch(rec_status,
      "Current user" = "Occasionally",
      "Former user"  = "Former",
      "Never used"   = "Never"
    )
    rows[[3]] <- data.frame(
      SUBJECT_ID   = subj_id,
      SUBSTANCE    = "Recreational drugs",
      USE_STATUS   = rec_status,
      PACK_YEARS   = "",
      FREQUENCY    = freq_rec,
      stringsAsFactors = FALSE
    )
  }

  su_list[[i]] <- do.call(rbind, rows)
}

substance_use <- do.call(rbind, Filter(Negate(is.null), su_list))
row.names(substance_use) <- NULL

assign("substance_use", substance_use, envir = .GlobalEnv)

write.csv(substance_use,
          file      = file.path(RAW_DIR, "substance_use.csv"),
          row.names = FALSE,
          na        = "")

message("  substance_use.csv written: ", nrow(substance_use), " rows")
message("    Tobacco: ",
        paste(names(table(substance_use$USE_STATUS[substance_use$SUBSTANCE == "Tobacco"])),
              table(substance_use$USE_STATUS[substance_use$SUBSTANCE == "Tobacco"]),
              sep = "=", collapse = ", "))
