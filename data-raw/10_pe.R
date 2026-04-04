# =============================================================================
# torivumab guidelines loaded
# 10_pe.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: PE (Physical Examination)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03
# Seed: set.seed(310)
# =============================================================================
#
# Outputs:
#   sdtm/pe.parquet              — SDTM PE domain (Parquet)
#   data-raw/raw_data/pe_raw.csv — Raw PE records
#
# PE strategy:
#   - Collected at Screening, C1D1, EOT
#   - Body systems assessed: General Appearance, HEENT, Respiratory,
#     Cardiovascular, Abdominal, Neurological, Skin, Lymph Nodes, Extremities
#   - PEORRES: "NORMAL" / "ABNORMAL" / "NOT DONE"
#   - Abnormal findings coded to MedDRA (simplified for synthetic data)
#   - Most subjects normal at screening (inclusion criterion: adequate performance)
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# Run after: 01_dm.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(310)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE = as.Date(C1D1_DATE),
    EOT_DATE  = as.Date(EOT_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"

pe_body_systems <- tribble(
  ~PETESTCD, ~PETEST,                  ~PECAT,          ~p_abnormal_scr, ~p_abnormal_eot,
  "GENAPP",  "General Appearance",     "OVERALL",        0.05,             0.12,
  "HEAD",    "Head, Eyes, Ears, Nose, Throat", "HEAD",  0.04,             0.06,
  "RESP",    "Respiratory",            "RESPIRATORY",    0.12,             0.20,
  "CARDIO",  "Cardiovascular",         "CARDIOVASCULAR", 0.08,             0.12,
  "ABDOMEN", "Abdomen",               "ABDOMINAL",       0.06,             0.10,
  "NEURO",   "Neurological",           "NEUROLOGICAL",   0.04,             0.08,
  "SKIN",    "Skin",                  "DERMATOLOGICAL",  0.05,             0.15,  # skin irAEs
  "LYMPH",   "Lymph Nodes",            "LYMPHATIC",      0.08,             0.10,
  "EXTREM",  "Extremities",            "MUSCULOSKELETAL", 0.04,            0.08
)

abnormal_findings <- c(
  "GENAPP"  = "Reduced performance status",
  "HEAD"    = "Mild oropharyngeal erythema",
  "RESP"    = "Reduced breath sounds at right base",
  "CARDIO"  = "Irregular heart rhythm",
  "ABDOMEN" = "Mild hepatomegaly",
  "NEURO"   = "Mild peripheral sensory loss",
  "SKIN"    = "Maculopapular rash",
  "LYMPH"   = "Cervical lymphadenopathy",
  "EXTREM"  = "Lower limb oedema"
)

pe_visits <- list(
  list(name = "SCR",  day = -14L, epoch = "SCREENING"),
  list(name = "C1D1", day =   1L, epoch = "TREATMENT"),
  list(name = "EOT",  day = 999L, epoch = "TREATMENT")   # 999 = derived per subject
)

generate_pe <- function(subj) {
  c1d1    <- subj$C1D1_DATE
  eot_day <- as.integer(subj$EOT_DATE - c1d1) + 1L
  obs_end <- min(subj$OBS_OS_DATE, subj$DATA_CUTOFF)

  pe_recs <- list()
  seq_n   <- 0L

  for (vis in pe_visits) {
    vday  <- if (vis$name == "EOT") eot_day else vis$day
    vdate <- c1d1 + vday - 1L
    if (vdate > obs_end) next

    is_eot <- vis$name == "EOT"

    for (j in seq_len(nrow(pe_body_systems))) {
      sys <- pe_body_systems[j, ]

      p_abn <- if (is_eot) sys$p_abnormal_eot[[1]] else sys$p_abnormal_scr[[1]]
      is_abn <- runif(1L) < p_abn

      peorres  <- ifelse(is_abn, "ABNORMAL", "NORMAL")
      peclsig  <- ifelse(is_abn,
                         sample(c("YES", "NO"), 1L, prob = c(0.4, 0.6)),
                         "NO")
      pedesc   <- if (is_abn) abnormal_findings[sys$PETESTCD[[1]]] else ""

      seq_n <- seq_n + 1L
      pe_recs[[seq_n]] <- tibble(
        STUDYID  = STUDYID,
        DOMAIN   = "PE",
        USUBJID  = subj$USUBJID,
        PESEQ    = seq_n,
        PETESTCD = sys$PETESTCD[[1]],
        PETEST   = sys$PETEST[[1]],
        PECAT    = sys$PECAT[[1]],
        PEORRES  = peorres,
        PEDESC   = pedesc,
        PECLSIG  = peclsig,
        PEDTC    = format(vdate, "%Y-%m-%d"),
        PEDY     = as.integer(vdate - c1d1) + 1L,
        VISIT    = vis$name,
        EPOCH    = vis$epoch
      )
    }
  }

  if (length(pe_recs) == 0L) return(NULL)
  bind_rows(pe_recs) %>% mutate(PESEQ = row_number())
}

PE <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_pe)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(PE, "sdtm/pe.parquet")
write.csv(PE, "data-raw/raw_data/pe_raw.csv", row.names = FALSE, na = "")

cat("\n=== PE Domain Validation ===\n")
cat(sprintf("  Total PE records        : %d\n", nrow(PE)))
cat(sprintf("  Subjects with PE data   : %d / %d\n",
            n_distinct(PE$USUBJID), nrow(backbone)))
cat(sprintf("  Abnormal findings       : %d (%.1f%%)\n",
            sum(PE$PEORRES == "ABNORMAL"),
            100 * mean(PE$PEORRES == "ABNORMAL")))
cat("\n  Outputs written: sdtm/pe.parquet, data-raw/raw_data/pe_raw.csv\n")
cat("=== PE generation complete ===\n")
