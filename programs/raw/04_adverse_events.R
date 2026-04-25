###############################################################################
# 04_adverse_events.R
# Generates raw/adverse_events.csv
# Realistic verbatim AE terms with variation in capitalisation/descriptors
# irAEs only in TORIVUMAB arm; chemo AEs in both arms
# Depends on: demographics, rand_dates, is_trt, pfs_days_sim, died_before_cutoff
###############################################################################

message("  Simulating adverse events...")

library(dplyr)
library(lubridate)

dm <- demographics
n  <- nrow(dm)

# ── load MedDRA codelist ───────────────────────────────────────────────────
meddra_path <- file.path(RAW_DIR, "codelists", "meddra_oncology_subset.csv")
meddra      <- read.csv(meddra_path, stringsAsFactors = FALSE)
irae_llt    <- meddra[meddra$IRAEFL == "Y", "LLT_NAME"]
chemo_llt   <- meddra[meddra$IRAEFL == "N", "LLT_NAME"]

# ── verbatim term variation helper ────────────────────────────────────────
make_verbatim <- function(term) {
  mods <- c(
    function(t) t,
    function(t) tolower(t),
    function(t) tools::toTitleCase(tolower(t)),
    function(t) paste(t, "- grade 2"),
    function(t) paste("mild", tolower(t)),
    function(t) paste("moderate", tolower(t)),
    function(t) paste("severe", tolower(t)),
    function(t) paste("intermittent", tolower(t)),
    function(t) paste(tolower(t), "(ongoing)"),
    function(t) paste(t, "NOS"),
    function(t) gsub("([A-Z])", " \\1", t) |> trimws(),
    function(t) paste(tolower(t), "- worsening"),
    function(t) paste("grade 3", tolower(t))
  )
  mod <- sample(mods, 1)[[1]]
  mod(term)
}

# ── severity / seriousness mappings ───────────────────────────────────────
severity_opts <- c("Mild", "Moderate", "Severe", "Life-threatening")

# ── AE generation ─────────────────────────────────────────────────────────
ae_list <- vector("list", n)

# irAE profiles by arm
irae_terms_pool <- c(
  "Pneumonitis", "Immune-mediated pneumonitis",
  "Hypothyroidism", "Underactive thyroid",
  "Colitis", "Immune-mediated colitis", "Enterocolitis",
  "Hepatitis", "Immune-mediated hepatitis",
  "Rash", "Skin rash", "Maculopapular rash",
  "Pruritus", "Itching",
  "ALT increased", "AST increased",
  "Adrenal insufficiency", "Hyperthyroidism"
)

# Chemo AE pool
chemo_terms_pool <- c(
  "Nausea", "Feeling nauseous", "Nausea NOS",
  "Vomiting", "Fatigue", "Asthenia",
  "Neutropenia", "Neutrophil count decreased",
  "Thrombocytopenia", "Platelet count decreased",
  "Anaemia", "Haemoglobin decreased",
  "Alopecia", "Hair loss",
  "Constipation", "Diarrhoea",
  "Peripheral neuropathy", "Mucositis oral",
  "Decreased appetite", "Dyspnoea"
)

for (i in seq_len(n)) {
  subj_id  <- dm$SUBJECT_ID[i]
  rand_dt  <- rand_dates[i]
  trt      <- is_trt[i]
  pfs_d    <- pfs_days_sim[i]
  died     <- died_before_cutoff[i]

  # Last observation date for AE window
  last_obs <- if (died) death_date_potential[i] else min(rand_dt + pfs_d + 60, DATA_CUTOFF)

  rows <- list()

  # ── chemotherapy-backbone AEs (both arms) ─────────────────────────────
  n_chemo_ae <- sample(3:9, 1)
  for (j in seq_len(n_chemo_ae)) {
    ae_term  <- sample(chemo_terms_pool, 1)
    ae_start <- rand_dt + sample(1:as.integer(pmax(1, last_obs - rand_dt - 5)), 1)
    if (ae_start >= last_obs) ae_start <- rand_dt + sample(1:14, 1)

    # Duration
    dur <- sample(5:45, 1)
    ae_end_raw <- ae_start + dur

    # ~5% missing end dates (ongoing)
    missing_end <- runif(1) < 0.05
    ae_end <- if (missing_end || ae_end_raw >= last_obs) NA else ae_end_raw

    # Grade 3+ probability
    g3p_prob <- if (trt) G3P_PROB_TRT else G3P_PROB_PBO
    is_g3p   <- runif(1) < g3p_prob * 0.6  # chemo portion

    sev <- if (is_g3p) {
      sample(c("Severe", "Life-threatening"), 1, prob = c(0.80, 0.20))
    } else {
      sample(c("Mild", "Moderate"), 1, prob = c(0.50, 0.50))
    }

    serious <- ifelse(sev %in% c("Severe", "Life-threatening") && runif(1) < 0.45, "Yes", "No")

    rel_opts  <- c("Yes", "No", "Possibly", "Probably", "Unlikely")
    rel_probs <- c(0.10, 0.30, 0.25, 0.20, 0.15)
    related   <- sample(rel_opts, 1, prob = rel_probs)

    action_opts  <- c("None", "Dose reduced", "Drug interrupted", "Drug withdrawn")
    action_probs <- if (sev == "Mild") c(0.70, 0.10, 0.15, 0.05) else c(0.20, 0.25, 0.35, 0.20)
    action <- sample(action_opts, 1, prob = action_probs)

    outcome_opts  <- c("Resolved", "Resolving", "Not resolved", "Resolved with sequelae", "Unknown")
    outcome_probs <- c(0.65, 0.15, 0.10, 0.05, 0.05)
    outcome <- if (!is.na(ae_end)) sample(outcome_opts, 1, prob = outcome_probs) else "Not resolved"

    leading_disc <- ifelse(action == "Drug withdrawn" && runif(1) < 0.4, "Y", "N")

    rows[[length(rows) + 1]] <- data.frame(
      SUBJECT_ID               = subj_id,
      AE_VERBATIM_TERM         = make_verbatim(ae_term),
      AE_START_DATE            = format(ae_start, "%Y-%m-%d"),
      AE_END_DATE              = if (is.na(ae_end)) "" else format(ae_end, "%Y-%m-%d"),
      SEVERITY                 = sev,
      SERIOUS                  = serious,
      RELATED_TO_STUDY_DRUG    = related,
      ACTION_TAKEN             = action,
      OUTCOME                  = outcome,
      AECAT                    = "",
      LEADING_TO_DISCONTINUATION = leading_disc,
      stringsAsFactors         = FALSE
    )
  }

  # ── irAEs (TORIVUMAB arm only, some subjects) ─────────────────────────
  irae_prob <- if (trt) IRAE_PROB_TRT else IRAE_PROB_PBO
  has_irae  <- runif(1) < irae_prob

  if (has_irae) {
    n_irae <- sample(1:3, 1, prob = c(0.60, 0.28, 0.12))
    for (k in seq_len(n_irae)) {
      irae_term  <- sample(irae_terms_pool, 1)
      # irAEs tend to appear early-mid treatment
      irae_start <- rand_dt + sample(21:pmax(22, min(120, as.integer(last_obs - rand_dt - 5))), 1)
      if (irae_start >= last_obs) irae_start <- rand_dt + sample(14:28, 1)

      dur_irae <- sample(14:90, 1)
      irae_end_raw <- irae_start + dur_irae
      missing_end_i <- runif(1) < 0.08
      irae_end <- if (missing_end_i || irae_end_raw >= last_obs) NA else irae_end_raw

      # irAEs can be serious
      is_g3p_irae <- runif(1) < 0.35
      sev_i <- if (is_g3p_irae) {
        sample(c("Severe", "Life-threatening"), 1, prob = c(0.78, 0.22))
      } else {
        sample(c("Mild", "Moderate"), 1, prob = c(0.40, 0.60))
      }

      serious_i <- ifelse(sev_i %in% c("Severe", "Life-threatening") && runif(1) < 0.55, "Yes", "No")

      rel_i <- sample(c("Probably", "Possibly", "Yes"), 1, prob = c(0.50, 0.30, 0.20))

      action_i_opts  <- c("None", "Dose reduced", "Drug interrupted", "Drug withdrawn")
      action_i_probs <- if (sev_i == "Mild") c(0.40, 0.20, 0.30, 0.10) else c(0.05, 0.15, 0.45, 0.35)
      action_i <- sample(action_i_opts, 1, prob = action_i_probs)

      outcome_i <- if (!is.na(irae_end)) {
        sample(c("Resolved", "Resolving", "Not resolved", "Resolved with sequelae"),
               1, prob = c(0.60, 0.20, 0.12, 0.08))
      } else "Not resolved"

      leading_i <- ifelse(action_i == "Drug withdrawn" && runif(1) < 0.5, "Y", "N")

      rows[[length(rows) + 1]] <- data.frame(
        SUBJECT_ID               = subj_id,
        AE_VERBATIM_TERM         = make_verbatim(irae_term),
        AE_START_DATE            = format(irae_start, "%Y-%m-%d"),
        AE_END_DATE              = if (is.na(irae_end)) "" else format(irae_end, "%Y-%m-%d"),
        SEVERITY                 = sev_i,
        SERIOUS                  = serious_i,
        RELATED_TO_STUDY_DRUG    = rel_i,
        ACTION_TAKEN             = action_i,
        OUTCOME                  = outcome_i,
        AECAT                    = "IMMUNE-RELATED",
        LEADING_TO_DISCONTINUATION = leading_i,
        stringsAsFactors         = FALSE
      )
    }
  }

  if (length(rows) > 0) {
    ae_list[[i]] <- do.call(rbind, rows)
  }
}

adverse_events <- do.call(rbind, Filter(Negate(is.null), ae_list))
row.names(adverse_events) <- NULL

assign("adverse_events", adverse_events, envir = .GlobalEnv)

write.csv(adverse_events,
          file      = file.path(RAW_DIR, "adverse_events.csv"),
          row.names = FALSE,
          na        = "")

message("  adverse_events.csv written: ", nrow(adverse_events), " rows")
message("    irAE rows: ", sum(adverse_events$AECAT == "IMMUNE-RELATED"))
