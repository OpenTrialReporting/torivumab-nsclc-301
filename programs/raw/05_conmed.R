###############################################################################
# 05_conmed.R
# Generates raw/conmed.csv
# Realistic verbatim drug names from atc_conmed.csv
# Depends on: demographics, rand_dates
###############################################################################

message("  Simulating concomitant medications...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

# ── load ATC conmed codelist ───────────────────────────────────────────────
atc_path <- file.path(RAW_DIR, "codelists", "atc_conmed.csv")
atc      <- read.csv(atc_path, stringsAsFactors = FALSE)

# ── helper: pick verbatim name (use _1 or _2 randomly with small typos) ───
pick_verbatim <- function(row) {
  base <- sample(c(row$DRUG_NAME_VERBATIM_1, row$DRUG_NAME_VERBATIM_2), 1)
  # Occasionally alter capitalisation
  mods <- c(
    function(x) x,
    function(x) tolower(x),
    function(x) tools::toTitleCase(x),
    function(x) toupper(x)
  )
  sample(mods, 1)[[1]](base)
}

# ── common supportive care drugs used in NSCLC chemo patients ─────────────
# These will appear in most patients
always_classes  <- c("ANTIEMETIC", "STEROID", "ANTACID", "VITAMIN_B12",
                     "FOLATE", "ANALGESIC", "ANTICOAGULANT")
# Conditionally based on AE / medical history
cond_classes    <- c("ANTIHYPERTENSIVE", "ANTIDIABETIC", "ANTIBIOTIC",
                     "IMMUNOSUPPRESSANT", "THYROID_HORMONE",
                     "PROTON_PUMP_INHIBITOR", "STATIN", "ANTIDEPRESSANT")

conmed_list <- vector("list", n)

for (i in seq_len(n)) {
  subj_id  <- dm$SUBJECT_ID[i]
  rand_dt  <- rand_dates[i]

  # Last date of follow-up
  last_obs <- if (!is.na(disposition$LAST_CONTACT_DATE[i]))
    as.Date(disposition$LAST_CONTACT_DATE[i]) else DATA_CUTOFF

  rows <- list()

  # ── always-present supportive care ──────────────────────────────────────
  # Antiemetics (ondansetron / granisetron)
  anti_pool <- atc[atc$INDICATION_CLASS == "ANTIEMETIC", , drop = FALSE]
  if (nrow(anti_pool) > 0) {
    row_pick <- anti_pool[sample(nrow(anti_pool), min(2, nrow(anti_pool))), ]
    for (r in seq_len(nrow(row_pick))) {
      start_d <- rand_dt - sample(0:7, 1)
      end_d   <- rand_dt + sample(120:300, 1)
      end_d   <- min(end_d, last_obs)
      ongoing <- end_d >= DATA_CUTOFF - 14
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        DRUG_NAME_VERBATIM  = pick_verbatim(row_pick[r, ]),
        START_DATE          = format(start_d, "%Y-%m-%d"),
        END_DATE            = if (ongoing) "" else format(end_d, "%Y-%m-%d"),
        INDICATION          = row_pick[r, "INDICATION"],
        ONGOING             = if (ongoing) "Y" else "N",
        stringsAsFactors    = FALSE
      )
    }
  }

  # Vitamins (B12, folic acid) — pemetrexed pre-medication (all patients)
  vit_pool <- atc[atc$INDICATION_CLASS %in% c("VITAMIN_B12", "FOLATE"), , drop = FALSE]
  if (nrow(vit_pool) > 0) {
    for (r in seq_len(min(nrow(vit_pool), 2))) {
      start_d <- rand_dt - sample(7:14, 1)   # started before first pemetrexed
      end_d   <- rand_dt + sample(180:400, 1)
      end_d   <- min(end_d, last_obs)
      ongoing <- end_d >= DATA_CUTOFF - 14
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        DRUG_NAME_VERBATIM  = pick_verbatim(vit_pool[r, ]),
        START_DATE          = format(start_d, "%Y-%m-%d"),
        END_DATE            = if (ongoing) "" else format(end_d, "%Y-%m-%d"),
        INDICATION          = vit_pool[r, "INDICATION"],
        ONGOING             = if (ongoing) "Y" else "N",
        stringsAsFactors    = FALSE
      )
    }
  }

  # ── conditional meds (random subset based on subject profile) ─────────
  n_cond <- sample(1:5, 1)
  cond_pool <- atc[atc$INDICATION_CLASS %in% cond_classes, , drop = FALSE]
  if (nrow(cond_pool) > 0 && n_cond > 0) {
    sel_rows <- cond_pool[sample(nrow(cond_pool), min(n_cond, nrow(cond_pool))), ]
    for (r in seq_len(nrow(sel_rows))) {
      start_d <- rand_dt - sample(0:365, 1)   # pre-existing or started on study
      end_d   <- rand_dt + sample(90:600, 1)
      end_d   <- min(end_d, last_obs)
      ongoing <- runif(1) < 0.40
      if (ongoing) end_d_str <- "" else end_d_str <- format(end_d, "%Y-%m-%d")
      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID          = subj_id,
        DRUG_NAME_VERBATIM  = pick_verbatim(sel_rows[r, ]),
        START_DATE          = format(start_d, "%Y-%m-%d"),
        END_DATE            = end_d_str,
        INDICATION          = sel_rows[r, "INDICATION"],
        ONGOING             = if (ongoing) "Y" else "N",
        stringsAsFactors    = FALSE
      )
    }
  }

  # ── steroids (common supportive / irAE management) ─────────────────────
  steroid_pool <- atc[atc$INDICATION_CLASS == "STEROID", , drop = FALSE]
  if (nrow(steroid_pool) > 0 && runif(1) < 0.60) {
    r_s    <- steroid_pool[sample(nrow(steroid_pool), 1), ]
    start_d <- rand_dt + sample(14:90, 1)
    dur_d   <- sample(14:60, 1)
    end_d   <- start_d + dur_d
    end_d   <- min(end_d, last_obs)
    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID         = subj_id,
      DRUG_NAME_VERBATIM = pick_verbatim(r_s),
      START_DATE         = format(start_d, "%Y-%m-%d"),
      END_DATE           = format(end_d, "%Y-%m-%d"),
      INDICATION         = r_s$INDICATION,
      ONGOING            = "N",
      stringsAsFactors   = FALSE
    )
  }

  if (length(rows) > 0) {
    conmed_list[[i]] <- do.call(rbind, rows)
  }
}

conmed <- do.call(rbind, Filter(Negate(is.null), conmed_list))
row.names(conmed) <- NULL

assign("conmed", conmed, envir = .GlobalEnv)

write.csv(conmed,
          file      = file.path(RAW_DIR, "conmed.csv"),
          row.names = FALSE,
          na        = "")

message("  conmed.csv written: ", nrow(conmed), " rows")
