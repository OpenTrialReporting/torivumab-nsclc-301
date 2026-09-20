# torivumab guidelines loaded
# =============================================================================
# t_eff_05_orr.R
# T-EFF-05 — Objective Response Rate (ORR, BICR per SAP; investigator-derived here)
# Population: Response Evaluable (subjects with ≥1 post-baseline OVR or clinical PD)
# Source: ADRS PARAMCD='CBOR' + ADSL
# Estimand: E3
# Method: Clopper-Pearson per-arm CI; stratified MH risk difference + CI
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adrs <- load_adam("adrs")

# Response Evaluable: subjects with at least one OVR record
re_subj <- adrs |> filter(PARAMCD == "OVR") |> distinct(USUBJID) |> pull(USUBJID)
adsl_re <- adsl |> filter(USUBJID %in% re_subj)

# Join CBOR onto the RE subset
cbor <- adrs |> filter(PARAMCD == "CBOR") |>
  select(USUBJID, CBOR = AVALC)

dat <- adsl_re |> left_join(cbor, by = "USUBJID") |>
  mutate(
    is_resp = !is.na(CBOR) & CBOR %in% c("CR","PR"),
    is_trt  = TRT01P == "Torivumab + Chemotherapy"
  )

n_re_trt <- sum(dat$is_trt)
n_re_pbo <- sum(!dat$is_trt)

# Per-arm responders + Clopper-Pearson CI
trt_ct <- sum(dat$is_resp & dat$is_trt)
pbo_ct <- sum(dat$is_resp & !dat$is_trt)
ci_trt <- binom.test(trt_ct, n_re_trt, conf.level = 0.95)$conf.int * 100
ci_pbo <- binom.test(pbo_ct, n_re_pbo, conf.level = 0.95)$conf.int * 100

# Stratified MH risk difference (TRT - PBO), 95% CI
tab <- table(arm = factor(dat$is_trt, levels = c(FALSE, TRUE),
                          labels = c("PBO","TRT")),
             resp = factor(dat$is_resp, levels = c(TRUE, FALSE)),
             strat = paste(dat$HISTCAT, dat$REGION))
# Filter strata with both arms
keep <- apply(tab, 3, function(m) min(rowSums(m)) > 0)
if (sum(keep) > 0) {
  mh <- tryCatch(
    mantelhaen.test(tab[,,keep], exact = FALSE, conf.level = 0.95),
    error = function(e) NULL
  )
} else mh <- NULL

# Stratified MH risk difference (#27 D13, signed 2026-09-20).
# mantelhaen.test() on a 2 x 2 x K table returns a common ODDS RATIO, so it
# cannot supply the estimand in SAP §13.6. It is kept above for the CMH p-value
# only; the effect estimate is the Mantel-Haenszel weighted risk difference with
# Greenland-Robins variance, computed per stratum over histology x region.
strata_counts <- dat |>
  mutate(.strat = paste(HISTCAT, REGION)) |>
  group_by(.strat) |>
  summarise(
    x1 = sum(is_resp & is_trt),  n1 = sum(is_trt),
    x0 = sum(is_resp & !is_trt), n0 = sum(!is_trt),
    .groups = "drop"
  )

mh_rd  <- mh_risk_diff(strata_counts$x1, strata_counts$n1,
                       strata_counts$x0, strata_counts$n0)
p_trt  <- trt_ct / n_re_trt   # per-arm proportions, for the completion message
p_pbo  <- pbo_ct / n_re_pbo
rd     <- 100 * mh_rd$rd
rd_lo  <- 100 * mh_rd$lo
rd_hi  <- 100 * mh_rd$hi
se_rd  <- 100 * mh_rd$se

# CMH p-value (test of common OR != 1)
cmh_p <- if (!is.null(mh)) mh$p.value else NA_real_

# BOR breakdown for completeness
bor_n <- function(category, only_trt = NULL) {
  s <- dat |> filter(!is.na(CBOR) & CBOR == category)
  if (!is.null(only_trt)) s <- s |> filter(is_trt == only_trt)
  nrow(s)
}

rows <- data.frame(
  Label = c(
    "Subjects in Response Evaluable population, N",
    "Confirmed Best Overall Response (CBOR)",
    "  Complete Response (CR), n (%)",
    "  Partial Response (PR), n (%)",
    "  Stable Disease (SD), n (%)",
    "  Progressive Disease (PD), n (%)",
    "  Not Evaluable (NE), n (%)",
    "Objective Response Rate (CR + PR), n (%)",
    "  95% CI (Clopper-Pearson)",
    "Risk difference TRT − PBO, % (stratified MH, 95% CI)",
    "p-value (Cochran-Mantel-Haenszel, stratified)"
  ),
  TRT = c(
    sprintf("%d", n_re_trt),
    "",
    fmt_n_pct(bor_n("CR", TRUE), n_re_trt),
    fmt_n_pct(bor_n("PR", TRUE), n_re_trt),
    fmt_n_pct(bor_n("SD", TRUE), n_re_trt),
    fmt_n_pct(bor_n("PD", TRUE), n_re_trt),
    fmt_n_pct(bor_n("NE", TRUE), n_re_trt),
    fmt_n_pct(trt_ct, n_re_trt),
    paste0("(", fmt_fixed(ci_trt[1], 1), ", ", fmt_fixed(ci_trt[2], 1), ")"),
    paste0(fmt_fixed(rd, 1), " (", fmt_fixed(rd_lo, 1), ", ", fmt_fixed(rd_hi, 1), ")"),
    fmt_p(cmh_p)
  ),
  PBO = c(
    sprintf("%d", n_re_pbo),
    "",
    fmt_n_pct(bor_n("CR", FALSE), n_re_pbo),
    fmt_n_pct(bor_n("PR", FALSE), n_re_pbo),
    fmt_n_pct(bor_n("SD", FALSE), n_re_pbo),
    fmt_n_pct(bor_n("PD", FALSE), n_re_pbo),
    fmt_n_pct(bor_n("NE", FALSE), n_re_pbo),
    fmt_n_pct(pbo_ct, n_re_pbo),
    paste0("(", fmt_fixed(ci_pbo[1], 1), ", ", fmt_fixed(ci_pbo[2], 1), ")"),
    "", ""
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", n_re_trt),
                 arm_label("Placebo + Chemotherapy",   n_re_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)
ft <- ft |> bold_section_ft(c(2, 8)) |> indent_ft(c(3:7, 9), levels = 1)
ft <- bold(ft, i = c(8, 10, 11), part = "body")

write_table_all_formats(
  ft, id = "T-EFF-05",
  title = "Objective Response Rate (Investigator-Assessed)",
  population = sprintf("Response Evaluable Population (N=%d)", nrow(dat)),
  notes = c(
    "Response Evaluable = ITT with ≥1 post-baseline tumour assessment.",
    "Confirmed Best Overall Response (CBOR) per RECIST 1.1 — confirmation requires a second CR/PR ≥28 days after the first with no intervening PD.",
    "Per-arm 95% CI for ORR by Clopper-Pearson exact method.",
    "Risk difference is the Mantel-Haenszel weighted difference in proportions across histology × region strata, with Greenland-Robins 95% CI. Strata containing no subjects in one arm carry no information about the difference and are excluded.",
    "Stratified Cochran-Mantel-Haenszel test: histology × region. The CMH procedure tests a common odds ratio; the effect estimate reported above is the risk difference, per SAP §13.6.",
    "SYNTHETIC-DATA NOTE: SAP §13.6 specifies BICR-assessed response; this study simulates only Investigator-assessed RS records.",
    "Source: datasets/adam/adrs.parquet, adsl.parquet."
  )
)

message(sprintf("T-EFF-05 written: ORR TRT %.1f%% vs PBO %.1f%%, RD=%.1f (%.1f, %.1f), p=%s",
                100*p_trt, 100*p_pbo, rd, rd_lo, rd_hi, fmt_p(cmh_p)))
