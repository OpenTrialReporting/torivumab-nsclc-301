# =============================================================================
# torivumab guidelines loaded
# 13_rs.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: RS (Disease Response) — RECIST 1.1 Overall Response
# Standard: SDTMIG v3.4 | CDISC Oncology Disease Response Supplement 2023
# Seed: set.seed(313)
# =============================================================================
#
# Outputs:
#   sdtm/rs.parquet              — SDTM RS domain (Parquet)
#   data-raw/raw_data/rs_raw.csv — Raw response records
#
# RS strategy (RECIST 1.1, BICR — Blinded Independent Central Review):
#   RSTEST = "Overall Response" | RSTESTCD = "OVRLRESP"
#   RSORRES: CR / PR / SD / PD / NE (Not Evaluable)
#   One RS record per imaging visit per subject (BICR assessment)
#   Best Overall Response (BOR) derived as additional RS record:
#     RSTESTCD = "BOR" | RSTEST = "Best Overall Response"
#
# RECIST 1.1 response rules applied:
#   - CR: all target lesions disappeared (sum = 0) AND
#         all non-target lesions absent/normalised
#   - PR: ≥30% decrease in sum of diameters from baseline
#         (no PD criteria met)
#   - PD: ≥20% increase from nadir sum AND ≥5mm absolute increase
#         OR new lesion OR unequivocal progression of non-target
#   - SD: neither PR nor PD criteria
#   - NE: missing/unevaluable data
#   - BOR: best response across all visits (requires confirmation for CR/PR)
#
# Dependencies:
#   - data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
#   - data-raw/raw_data/tr_sum_diam.csv (from 12_tr.R)
# Run after: 12_tr.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(purrr)
})

set.seed(313)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(C1D1_DATE = as.Date(C1D1_DATE))

tr_sum <- read.csv("data-raw/raw_data/tr_sum_diam.csv",
                   stringsAsFactors = FALSE) %>%
  mutate(TRDTC = as.Date(TRDTC))

STUDYID <- "TORIVUMAB-NSCLC-301"

# ── RECIST 1.1 rules ──────────────────────────────────────────────────────────
apply_recist_rules <- function(sum_diam_df) {
  # Input: per-visit sum of diameters with % change
  # Output: per-visit RSORRES
  n       <- nrow(sum_diam_df)
  results <- character(n)
  nadir   <- sum_diam_df$SUM_DIAM[1L]   # initialise nadir as first post-BL sum

  for (i in seq_len(n)) {
    s     <- sum_diam_df$SUM_DIAM[i]
    bl    <- sum_diam_df$BL_SUM_DIAM[i]
    pct_chg <- sum_diam_df$PCT_CHANGE[i]

    # Update nadir
    if (!is.na(s)) nadir <- min(nadir, s, na.rm = TRUE)

    if (is.na(s)) {
      results[i] <- "NE"
      next
    }

    # CR: sum = 0 (all lesions disappeared)
    if (s == 0) {
      results[i] <- "CR"
    }
    # PD: ≥20% increase from nadir + ≥5mm absolute, or response pattern = PD
    else if (!is.na(nadir) && (s - nadir) / max(nadir, 0.001) >= 0.20 &&
             (s - nadir) >= 5.0 && i > 1L) {
      results[i] <- "PD"
    }
    # Force PD when response pattern indicates it and past PFS time
    else if (sum_diam_df$RESPONSE_PATTERN[i] == "PD" && i >= 2L) {
      if (pct_chg > 0 && i > 1L) results[i] <- "PD"
      else results[i] <- "SD"
    }
    # PR: ≥30% decrease from baseline
    else if (pct_chg <= -30.0) {
      results[i] <- "PR"
    }
    # SD: between -30% and +20% (but <5mm absolute increase from nadir)
    else {
      results[i] <- "SD"
    }
  }

  results
}

# ── Best Overall Response determination ───────────────────────────────────────
determine_bor <- function(responses) {
  # BOR priority: CR > PR > SD > PD > NE
  # Per RECIST 1.1: PR/CR requires confirmation at ≥4 weeks
  priority <- c(CR = 1L, PR = 2L, SD = 3L, PD = 4L, NE = 5L)
  best <- "NE"
  for (r in responses) {
    if (r %in% names(priority) && priority[r] < priority[best]) {
      best <- r
    }
  }
  # Simple confirmation: if CR or PR, require ≥2 consecutive confirmatory visits
  # (simplified for synthetic data — apply heuristic)
  if (best %in% c("CR", "PR")) {
    cr_pr_run <- rle(responses[responses != "NE"])$lengths[
      rle(responses[responses != "NE"])$values == best
    ]
    if (length(cr_pr_run) == 0 || max(cr_pr_run) < 2L) {
      best <- "SD"  # unconfirmed CR/PR → downgrade to SD
    }
  }
  best
}

# ── Generate RS records ────────────────────────────────────────────────────────
generate_rs <- function(subj) {
  subj_sum <- tr_sum %>% filter(USUBJID == subj$USUBJID)
  if (nrow(subj_sum) == 0L) return(NULL)

  c1d1 <- subj$C1D1_DATE

  # Apply RECIST rules
  per_visit_response <- apply_recist_rules(subj_sum)

  rs_recs <- list()
  seq_n   <- 0L

  for (i in seq_along(per_visit_response)) {
    seq_n <- seq_n + 1L
    rs_recs[[seq_n]] <- tibble(
      STUDYID  = STUDYID,
      DOMAIN   = "RS",
      USUBJID  = subj$USUBJID,
      RSSEQ    = seq_n,
      RSTESTCD = "OVRLRESP",
      RSTEST   = "Overall Response",
      RSCAT    = "RECIST 1.1",
      RSSCAT   = "BICR",
      RSORRES  = per_visit_response[i],
      RSSTRESC = per_visit_response[i],
      RSDTC    = as.character(subj_sum$TRDTC[i]),
      RSDY     = subj_sum$TRDY[i],
      VISIT    = subj_sum$VISIT[i],
      VISITNUM = i,
      EPOCH    = "TREATMENT"
    )
  }

  # Best Overall Response record
  bor <- determine_bor(per_visit_response)
  # BOR date = date of first occurrence of best response
  bor_date <- subj_sum$TRDTC[which(per_visit_response == bor)[1L]]
  if (is.na(bor_date)) bor_date <- subj_sum$TRDTC[nrow(subj_sum)]

  seq_n <- seq_n + 1L
  rs_recs[[seq_n]] <- tibble(
    STUDYID  = STUDYID,
    DOMAIN   = "RS",
    USUBJID  = subj$USUBJID,
    RSSEQ    = seq_n,
    RSTESTCD = "BOR",
    RSTEST   = "Best Overall Response",
    RSCAT    = "RECIST 1.1",
    RSSCAT   = "BICR",
    RSORRES  = bor,
    RSSTRESC = bor,
    RSDTC    = as.character(bor_date),
    RSDY     = as.integer(bor_date - c1d1) + 1L,
    VISIT    = "",
    VISITNUM = 999.0,
    EPOCH    = "TREATMENT"
  )

  bind_rows(rs_recs) %>% mutate(RSSEQ = row_number())
}

RS <- backbone %>%
  split(seq_len(nrow(.))) %>%
  map_dfr(generate_rs)

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(RS, "sdtm/rs.parquet")
write.csv(RS, "data-raw/raw_data/rs_raw.csv", row.names = FALSE, na = "")


# ── Validation ─────────────────────────────────────────────────────────────────
bor_summary <- RS %>%
  filter(RSTESTCD == "BOR") %>%
  left_join(backbone %>% select(USUBJID, ARMCD), by = "USUBJID") %>%
  count(ARMCD, RSORRES) %>%
  group_by(ARMCD) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()

cat("\n=== RS Domain Validation ===\n")
cat(sprintf("  Total RS records        : %d\n", nrow(RS)))
cat(sprintf("  Subjects with RS data   : %d / %d\n",
            n_distinct(RS$USUBJID), nrow(backbone)))
cat(sprintf("  BOR records             : %d (expected %d)\n",
            sum(RS$RSTESTCD == "BOR"),
            n_distinct(RS$USUBJID)))
cat("\n  Best Overall Response by Arm:\n")
print(bor_summary %>%
        select(ARMCD, RSORRES, n, pct) %>%
        arrange(ARMCD, RSORRES))

# Compute ORR (CR+PR)
orr <- bor_summary %>%
  group_by(ARMCD) %>%
  summarise(orr = round(sum(pct[RSORRES %in% c("CR","PR")]), 1))
cat("\n  ORR (CR+PR):\n")
print(orr)
cat("\n  Outputs written: sdtm/rs.parquet, data-raw/raw_data/rs_raw.csv\n")
cat("=== RS generation complete ===\n")
