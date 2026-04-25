###############################################################################
# 13_physical_exam.R
# Generates raw/physical_exam.csv
# Systems: General, HEENT, Chest, Abdomen, Extremities, Neurological
# Visits: Screening, C1D1, C3D1, C5D1, EOT (and some maintenance)
# Depends on: demographics, rand_dates, pfs_days_sim
###############################################################################

message("  Simulating physical examinations...")

library(dplyr)

dm <- demographics
n  <- nrow(dm)

body_systems <- c("General", "HEENT", "Chest", "Abdomen", "Extremities", "Neurological")

# ── abnormal finding details by system ────────────────────────────────────
abnormal_details <- list(
  General      = c("Performance status declined", "Cachexia noted",
                   "Weight loss >5% since last visit", "Pallor",
                   "Generalised fatigue", "Mild oedema"),
  HEENT        = c("Conjunctival pallor", "Cervical lymphadenopathy",
                   "Mucositis grade 1", "Dry mucous membranes",
                   "Supraclavicular lymph node palpable"),
  Chest        = c("Decreased breath sounds at right base",
                   "Crackles bilateral", "Dullness to percussion left base",
                   "Wheeze noted", "Pleural rub",
                   "Reduced chest expansion"),
  Abdomen      = c("Hepatomegaly - mild", "Mild abdominal tenderness",
                   "Splenomegaly not palpable", "Ascites - trace",
                   "Right upper quadrant discomfort"),
  Extremities  = c("Peripheral oedema grade 1", "Peripheral neuropathy - tingling feet",
                   "Calf tenderness", "Cool peripheries",
                   "Muscle wasting - bilateral lower limbs"),
  Neurological = c("Peripheral neuropathy - sensory", "Mild confusion",
                   "Decreased reflexes bilateral lower limbs",
                   "Cognitive slowing", "Headache reported")
)

# ── visit schedule for PE ─────────────────────────────────────────────────
pe_visit_offsets <- function(rand_dt, pfs_d, last_obs_dt) {
  base_offsets <- c(
    SCREENING = -sample(7:28, 1),
    C1D1      = 0,
    C3D1      = 42 + sample(-1:2, 1),
    C5D1      = 84 + sample(-1:2, 1),
    C6D1      = 105 + sample(-1:2, 1)
  )

  # Maintenance every ~6 weeks — guard against short-PFS subjects
  maint_start <- 105 + 42
  maint_end   <- pfs_d + 30
  if (maint_end >= maint_start) {
    maint_off <- seq(maint_start, maint_end, by = 42)
    maint_nms <- paste0("MAINT_ASSESS_WK", round(maint_off / 7))
    extra_off  <- setNames(maint_off, maint_nms)
    all_off    <- c(base_offsets, extra_off)
  } else {
    all_off <- base_offsets
  }

  # EOT
  eot_off <- pfs_d + sample(1:7, 1)
  all_off  <- c(all_off, EOT = eot_off)

  # Filter
  all_off[rand_dt + all_off <= min(last_obs_dt, DATA_CUTOFF)]
}

pe_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id <- dm$SUBJECT_ID[i]
  rand_dt <- rand_dates[i]
  pfs_d   <- pfs_days_sim[i]
  ecog    <- dm$ECOG_BASELINE[i]

  last_obs_dt <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  offsets  <- pe_visit_offsets(rand_dt, pfs_d, last_obs_dt)
  rows     <- list()

  for (j in seq_along(offsets)) {
    visit_nm <- names(offsets)[j]
    visit_dt <- rand_dt + offsets[j]
    visit_n  <- as.integer(offsets[j] / 42)   # rough assessment number

    for (sys in body_systems) {
      # Probability of abnormality increases with visits (disease progression proxy)
      base_abn_p <- 0.08 + ecog * 0.05 + visit_n * 0.015
      base_abn_p <- min(base_abn_p, 0.45)

      is_abn  <- runif(1) < base_abn_p
      finding <- if (is_abn) "Abnormal" else "Normal"
      detail  <- if (is_abn) sample(abnormal_details[[sys]], 1) else ""

      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID     = subj_id,
        VISIT_NAME     = visit_nm,
        VISIT_DATE     = format(visit_dt, "%Y-%m-%d"),
        BODY_SYSTEM    = sys,
        FINDING        = finding,
        FINDING_DETAIL = detail,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    pe_list[[i]] <- do.call(rbind, rows)
  }
}

physical_exam <- do.call(rbind, Filter(Negate(is.null), pe_list))
row.names(physical_exam) <- NULL

assign("physical_exam", physical_exam, envir = .GlobalEnv)

write.csv(physical_exam,
          file      = file.path(RAW_DIR, "physical_exam.csv"),
          row.names = FALSE,
          na        = "")

message