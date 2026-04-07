# =============================================================================
# torivumab guidelines loaded
# 09_lb.R — SIMULATED-TORIVUMAB-2026 | Phase 3: Data Generation
# Domain: LB (Laboratory Test Results)
# Standard: SDTMIG v3.4 | CDISC CT 2024-03 | LOINC
# Seed: set.seed(309)
# =============================================================================
#
# Outputs:
#   sdtm/lb.parquet              — SDTM LB domain (Parquet)
#   data-raw/raw_data/lb_raw.csv — Raw lab records
#
# Panels: Haematology, Chemistry, Thyroid, Urinalysis (dipstick), Biomarkers
# Biomarkers (SCR only): PD-L1 TPS (≥50%), EGFR/ALK (all negative),
#   ROS1, KRAS G12C, MET ex14, RET, BRAF V600E, NTRK, TMB (optional ~62%)
#
# Dependencies: data-raw/raw_data/subject_backbone.csv (from 01_dm.R)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(arrow)
})

set.seed(309)

backbone <- read.csv("data-raw/raw_data/subject_backbone.csv",
                     stringsAsFactors = FALSE) %>%
  mutate(
    C1D1_DATE   = as.Date(C1D1_DATE),
    EOT_DATE    = as.Date(EOT_DATE),
    OBS_OS_DATE = as.Date(OBS_OS_DATE),
    DATA_CUTOFF = as.Date(DATA_CUTOFF)
  )

STUDYID <- "TORIVUMAB-NSCLC-301"
n_subj  <- nrow(backbone)

# ── Lab test catalogue ─────────────────────────────────────────────────────────
lab_tests <- data.frame(
  LBTESTCD = c("WBC","HGB","PLT","NEUT","LYMPH","MONO",
               "ALT","AST","ALKPH","BILI","CREAT","BUN","NA","K","GLUC","ALB",
               "TSH","T4FREE",
               "USPECGR","UPH"),
  LBTEST   = c("Leukocytes","Hemoglobin","Platelets","Neutrophils","Lymphocytes","Monocytes",
               "Alanine Aminotransferase","Aspartate Aminotransferase","Alkaline Phosphatase",
               "Bilirubin","Creatinine","Blood Urea Nitrogen","Sodium","Potassium","Glucose","Albumin",
               "Thyroid Stimulating Hormone","Free Thyroxine",
               "Urine Specific Gravity","Urine pH"),
  LBCAT    = c(rep("HEMATOLOGY",6), rep("CHEMISTRY",10), rep("ENDOCRINE",2), rep("URINALYSIS",2)),
  LBORRESU = c("10^9/L","g/dL","10^9/L","10^9/L","10^9/L","10^9/L",
               "U/L","U/L","U/L","umol/L","umol/L","mmol/L","mmol/L","mmol/L","mmol/L","g/L",
               "mIU/L","pmol/L",
               "",""),
  norm_lo  = c(3.5,12.0,150,1.8,1.0,0.2, 7,10,44,5,60,2.5,136,3.5,3.9,35, 0.5,12, 1.005,4.5),
  norm_hi  = c(10.5,16.0,400,7.5,4.0,1.0,40,40,147,21,110,6.7,145,5.0,6.1,52, 4.5,22, 1.030,8.5),
  mu       = c(7.0,13.5,230,4.5,2.1,0.5, 22,24,80,11,82,4.5,140,4.1,5.2,42, 2.0,16, 1.015,6.0),
  sigma    = c(1.8,1.5,60,1.3,0.6,0.15, 9,9,22,4,16,1.0,2.5,0.4,0.8,4, 0.8,2, 0.005,1.0),
  panel    = c(rep("HAEM",6), rep("CHEM",10), rep("THYR",2), rep("URINE",2)),
  round_dp = c(2,1,0,2,2,2, 0,0,0,0,0,1,0,1,1,0, 2,1, 3,1),
  stringsAsFactors = FALSE
)

# Visit schedule for routine labs (study day from C1D1)
routine_visits <- data.frame(
  VISIT    = c("SCR","C1D1","C1D22","C2D22","C3D22","C4D22","C5D22",
               "C6D22","C7D22","C8D22","C9D22","C10D22","EOT","FU01"),
  VDAY     = c(-14L,1L,22L,43L,85L,106L,127L,148L,169L,190L,211L,232L,999L,1090L),
  VISITNUM = 1:14,
  stringsAsFactors = FALSE
)
thyroid_visits <- c("SCR","C1D22","C3D22","C5D22","C7D22","C9D22","EOT")
urine_visits   <- c("SCR","C1D1","EOT")

# ── Cross-join subjects × visits ──────────────────────────────────────────────
sv <- merge(data.frame(subj_idx = seq_len(n_subj)), routine_visits, by = NULL)
sv$USUBJID  <- backbone$USUBJID[sv$subj_idx]
sv$ARMCD    <- backbone$ARMCD[sv$subj_idx]
sv$C1D1     <- backbone$C1D1_DATE[sv$subj_idx]
sv$EOT_DAY  <- as.integer(backbone$EOT_DATE[sv$subj_idx] -
                            backbone$C1D1_DATE[sv$subj_idx]) + 1L
sv$OBS_END  <- pmin(backbone$OBS_OS_DATE[sv$subj_idx],
                     backbone$DATA_CUTOFF[sv$subj_idx])

sv$VDAY_ACT <- ifelse(sv$VISIT == "EOT", sv$EOT_DAY, sv$VDAY)
sv$VDATE    <- sv$C1D1 + sv$VDAY_ACT - 1L

# Window jitter ±2 days (non-anchored visits)
n_sv <- nrow(sv)
jit  <- sample(-2L:2L, n_sv, replace = TRUE)
sv$VDATE <- as.Date(ifelse(sv$VISIT %in% c("SCR","C1D1"),
                            as.integer(sv$VDATE),
                            as.integer(sv$VDATE) + jit),
                    origin = "1970-01-01")
sv <- sv[sv$VDATE <= sv$OBS_END, ]

# ── Generate continuous lab panels per visit row ───────────────────────────────
days_on_all <- pmax(as.integer(sv$VDATE - sv$C1D1), 0L)

lb_parts <- vector("list", nrow(lab_tests))

for (j in seq_len(nrow(lab_tests))) {
  t   <- lab_tests[j, ]
  pnl <- t$panel

  # Filter visits for this panel
  vis_mask <- switch(pnl,
    HAEM  = rep(TRUE, nrow(sv)),
    CHEM  = rep(TRUE, nrow(sv)),
    THYR  = sv$VISIT %in% thyroid_visits,
    URINE = sv$VISIT %in% urine_visits
  )
  sv_sub <- sv[vis_mask, ]
  if (nrow(sv_sub) == 0L) next

  n_r     <- nrow(sv_sub)
  days_on <- days_on_all[vis_mask]

  val <- rnorm(n_r, t$mu, t$sigma)

  # irAE patterns
  if (t$LBTESTCD %in% c("ALT","AST")) {
    # Liver enzyme spikes: TOR arm, increasing risk over time
    spike_p <- 0.003 * (days_on / 30)
    spikes  <- sv_sub$ARMCD == "TOR" & runif(n_r) < spike_p
    val[spikes] <- val[spikes] * runif(sum(spikes), 3.0, 8.0)
  }
  if (t$LBTESTCD == "TSH") {
    tsh_spike <- sv_sub$ARMCD == "TOR" & days_on > 60L & runif(n_r) < 0.012
    val[tsh_spike] <- val[tsh_spike] * runif(sum(tsh_spike), 2.0, 6.0)
  }

  val <- pmax(val, 0.001)
  val <- round(val, t$round_dp)

  lbnrind <- ifelse(val < t$norm_lo, "L", ifelse(val > t$norm_hi, "H", "N"))

  lb_parts[[j]] <- data.frame(
    STUDYID  = STUDYID,
    DOMAIN   = "LB",
    USUBJID  = sv_sub$USUBJID,
    LBTESTCD = t$LBTESTCD,
    LBTEST   = t$LBTEST,
    LBCAT    = t$LBCAT,
    LBORRES  = as.character(val),
    LBORRESU = t$LBORRESU,
    LBSTRESC = as.character(val),
    LBSTRESN = val,
    LBSTRESU = t$LBORRESU,
    LBNRLO   = t$norm_lo,
    LBNRHI   = t$norm_hi,
    LBNRIND  = lbnrind,
    LBDTC    = format(sv_sub$VDATE, "%Y-%m-%d"),
    LBDY     = as.integer(sv_sub$VDATE - sv_sub$C1D1) + 1L,
    VISIT    = sv_sub$VISIT,
    VISITNUM = sv_sub$VISITNUM,
    EPOCH    = ifelse(as.integer(sv_sub$VDATE - sv_sub$C1D1) < 0L, "SCREENING", "TREATMENT"),
    stringsAsFactors = FALSE
  )
}

LB_routine <- do.call(rbind, lb_parts[!sapply(lb_parts, is.null)])

# ── Biomarkers (screening only, per subject) ──────────────────────────────────
scr_dates <- backbone$C1D1_DATE - 14L
bm_spec <- data.frame(
  LBTESTCD = c("PDL1TPS","EGFRMUT","ALKREARR","ROS1REARR","KRASG12C",
               "METEX14","RETREARR","BRAFV600E","NTRK"),
  LBTEST   = c("PD-L1 TPS (22C3)","EGFR Mutation Status","ALK Rearrangement",
               "ROS1 Rearrangement","KRAS G12C Mutation","MET Exon 14 Skipping",
               "RET Rearrangement","BRAF V600E Mutation","NTRK Fusion"),
  p_pos    = c(1.00, 0.00, 0.00, 0.02, 0.13, 0.03, 0.02, 0.02, 0.01),
  stringsAsFactors = FALSE
)

bm_rows <- lapply(seq_len(nrow(bm_spec)), function(j) {
  bm      <- bm_spec[j, ]
  pos     <- runif(n_subj) < bm$p_pos
  lborres <- if (bm$LBTESTCD == "PDL1TPS") {
    as.character(round(runif(n_subj, 50, 99)))
  } else {
    ifelse(pos, "POSITIVE", "NEGATIVE")
  }
  data.frame(
    STUDYID  = STUDYID, DOMAIN = "LB",
    USUBJID  = backbone$USUBJID,
    LBTESTCD = bm$LBTESTCD, LBTEST = bm$LBTEST, LBCAT = "BIOMARKER",
    LBORRES  = lborres,
    LBORRESU = ifelse(bm$LBTESTCD == "PDL1TPS", "%", ""),
    LBSTRESC = lborres,
    LBSTRESN = ifelse(bm$LBTESTCD == "PDL1TPS", as.numeric(lborres), NA_real_),
    LBSTRESU = ifelse(bm$LBTESTCD == "PDL1TPS", "%", ""),
    LBNRLO = NA_real_, LBNRHI = NA_real_, LBNRIND = "",
    LBDTC    = format(scr_dates, "%Y-%m-%d"),
    LBDY     = as.integer(scr_dates - backbone$C1D1_DATE) + 1L,
    VISIT = "SCR", VISITNUM = 0L, EPOCH = "SCREENING",
    stringsAsFactors = FALSE
  )
})

# TMB (optional ~62%)
tmb_mask <- runif(n_subj) < 0.62
tmb_val  <- round(runif(n_subj, 1, 35))
bm_tmb <- data.frame(
  STUDYID  = STUDYID, DOMAIN = "LB",
  USUBJID  = backbone$USUBJID[tmb_mask],
  LBTESTCD = "TMB", LBTEST = "Tumour Mutational Burden", LBCAT = "BIOMARKER",
  LBORRES  = as.character(tmb_val[tmb_mask]),
  LBORRESU = "mut/Mb",
  LBSTRESC = as.character(tmb_val[tmb_mask]),
  LBSTRESN = tmb_val[tmb_mask],
  LBSTRESU = "mut/Mb",
  LBNRLO = NA_real_, LBNRHI = NA_real_, LBNRIND = "",
  LBDTC    = format(scr_dates[tmb_mask], "%Y-%m-%d"),
  LBDY     = as.integer(scr_dates[tmb_mask] - backbone$C1D1_DATE[tmb_mask]) + 1L,
  VISIT = "SCR", VISITNUM = 0L, EPOCH = "SCREENING",
  stringsAsFactors = FALSE
)

LB_bm <- do.call(rbind, c(bm_rows, list(bm_tmb)))

LB <- rbind(LB_routine, LB_bm) %>%
  arrange(USUBJID, LBDTC, LBTESTCD) %>%
  group_by(USUBJID) %>%
  mutate(LBSEQ = row_number()) %>%
  ungroup()

dir.create("sdtm",              showWarnings = FALSE, recursive = TRUE)
dir.create("data-raw/raw_data", showWarnings = FALSE, recursive = TRUE)

write_parquet(LB, "sdtm/lb.parquet")
write.csv(LB, "data-raw/raw_data/lb_raw.csv", row.names = FALSE, na = "")

cat("\n=== LB Domain Validation ===\n")
cat(sprintf("  Total LB records        : %d\n", nrow(LB)))
cat(sprintf("  Subjects with LB data   : %d / %d\n",
            n_distinct(LB$USUBJID), n_subj))
cat(sprintf("  Biomarker records       : %d\n",
            sum(LB$LBCAT == "BIOMARKER")))
cat(sprintf("  PD-L1 TPS (n)           : %d; median = %.0f%%\n",
            sum(LB$LBTESTCD == "PDL1TPS"),
            median(LB$LBSTRESN[LB$LBTESTCD == "PDL1TPS"], na.rm = TRUE)))
cat(sprintf("  Elevated ALT (>ULN)     : %d (%.1f%% of ALT results)\n",
            sum(LB$LBTESTCD == "ALT" & LB$LBNRIND == "H", na.rm = TRUE),
            100 * mean(LB$LBTESTCD == "ALT" & !is.na(LB$LBNRIND) & LB$LBNRIND == "H")))
cat("\n  Outputs written: sdtm/lb.parquet, data-raw/raw_data/lb_raw.csv\n")
cat("=== LB generation complete ===\n")
