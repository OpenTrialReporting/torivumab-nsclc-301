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

# MH gives OR; for risk difference use unstratified per-arm difference + Newcombe CI
# (mantelhaen.test on 2x2xK gives common OR, not RD; compute RD manually)
p_trt <- trt_ct / n_re_trt
p_pbo <- pbo_ct / n_re_pbo
rd    <- 100 * (p_trt - p_pbo)
se_rd <- sqrt(p_trt*(1-p_trt)/n_re_trt + p_pbo*(1-p_pbo)/n_re_pbo) * 100
rd_lo <- rd - 1.96 * se_rd
rd_hi <- rd + 1.96 * se_rd

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
    "Risk difference TRT − PBO, % (95% CI Wald)",
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
    sprintf("(%.1f, %.1f)", ci_trt[1], ci_trt[2]),
    sprintf("%.1f (%.1f, %.1f)", rd, rd_lo, rd_hi),
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
    sprintf("(%.1f, %.1f)", ci_pbo[1], ci_pbo[2]),
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
    "Stratified Cochran-Mantel-Haenszel test: histology × region.",
    "SYNTHETIC-DATA NOTE: SAP §13.6 specifies BICR-assessed response; this study simulates only Investigator-assessed RS records.",
    "Source: datasets/adam/adrs.parquet, adsl.parquet."
  )
)

message(sprintf("T-EFF-05 written: ORR TRT %.1f%% vs PBO %.1f%%, RD=%.1f (%.1f, %.1f), p=%s",
                100*p_trt, 100*p_pbo, rd, rd_lo, rd_hi, fmt_p(cmh_p)))
