# torivumab guidelines loaded
# =============================================================================
# t_eff_13_orr_itt.R
# T-EFF-13 — Objective Response Rate, ITT Denominator (Sensitivity)
# Source: ADRS PARAMCD='CBOR' + ADSL ITT
# Estimand: E3a (SAP §13.6 sensitivity)
# Population: ITT (all 450) — denominator change vs T-EFF-05
# IE handling: composite (subjects without post-baseline assessment counted as non-responders)
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adrs <- load_adam("adrs")
counts <- adsl_arm_counts(adsl, "ITTFL")

cbor <- adrs |> filter(PARAMCD == "CBOR") |>
  select(USUBJID, CBOR = AVALC)

# LEFT JOIN: ITT subjects without a CBOR record get NA, treated as non-responder
dat <- adsl |> left_join(cbor, by = "USUBJID") |>
  mutate(
    is_resp = !is.na(CBOR) & CBOR %in% c("CR","PR"),
    is_trt  = TRT01P == "Torivumab + Chemotherapy"
  )

n_trt    <- counts$n_trt
n_pbo    <- counts$n_pbo
trt_ct   <- sum(dat$is_resp & dat$is_trt)
pbo_ct   <- sum(dat$is_resp & !dat$is_trt)
no_pba   <- sum(is.na(dat$CBOR))

ci_trt <- binom.test(trt_ct, n_trt)$conf.int * 100
ci_pbo <- binom.test(pbo_ct, n_pbo)$conf.int * 100

p_trt <- trt_ct / n_trt
p_pbo <- pbo_ct / n_pbo
rd    <- 100 * (p_trt - p_pbo)
se    <- sqrt(p_trt*(1-p_trt)/n_trt + p_pbo*(1-p_pbo)/n_pbo) * 100
rd_lo <- rd - 1.96 * se
rd_hi <- rd + 1.96 * se

tab <- table(arm = factor(dat$is_trt, levels = c(FALSE, TRUE), labels = c("PBO","TRT")),
             resp = factor(dat$is_resp, levels = c(TRUE, FALSE)),
             strat = paste(dat$HISTCAT, dat$REGION))
keep <- apply(tab, 3, function(m) min(rowSums(m)) > 0)
mh   <- tryCatch(mantelhaen.test(tab[,,keep], exact = FALSE),
                  error = function(e) NULL)
cmh_p <- if (!is.null(mh)) mh$p.value else NA_real_

rows <- data.frame(
  Label = c(
    "Subjects in ITT population, N",
    "Responders (confirmed CR/PR), n (%)",
    "Non-responders (incl. no post-baseline assessment), n (%)",
    "  Of which: no post-baseline assessment (composite IE), n",
    "Risk difference TRT − PBO, % (95% CI Wald)",
    "p-value (Cochran-Mantel-Haenszel, stratified)",
    "95% CI per arm (Clopper-Pearson)"
  ),
  TRT = c(
    sprintf("%d", n_trt),
    fmt_n_pct(trt_ct, n_trt),
    fmt_n_pct(n_trt - trt_ct, n_trt),
    sprintf("%d", sum(is.na(dat$CBOR) & dat$is_trt)),
    sprintf("%.1f (%.1f, %.1f)", rd, rd_lo, rd_hi),
    fmt_p(cmh_p),
    sprintf("(%.1f, %.1f)", ci_trt[1], ci_trt[2])
  ),
  PBO = c(
    sprintf("%d", n_pbo),
    fmt_n_pct(pbo_ct, n_pbo),
    fmt_n_pct(n_pbo - pbo_ct, n_pbo),
    sprintf("%d", sum(is.na(dat$CBOR) & !dat$is_trt)),
    "", "",
    sprintf("(%.1f, %.1f)", ci_pbo[1], ci_pbo[2])
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", n_trt),
                 arm_label("Placebo + Chemotherapy",   n_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.8)
ft <- ft |> indent_ft(4, levels = 1)
ft <- bold(ft, i = c(2, 5, 6), part = "body")

write_table_all_formats(
  ft, id = "T-EFF-13",
  title = "Objective Response Rate — ITT Denominator (Sensitivity)",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Estimand E3a (SAP §13.6) — uses full ITT as denominator (removes implicit selection in Response Evaluable).",
    "Composite IE strategy retained: subjects without any post-baseline tumour assessment are counted as non-responders.",
    sprintf("In this dataset, %d subjects have no post-baseline assessment.", no_pba),
    "Per-arm 95% CI by Clopper-Pearson; stratified CMH test (histology × region).",
    "Source: datasets/adam/adsl.parquet (ITT) + adrs.parquet (CBOR)."
  )
)
message(sprintf("T-EFF-13 written: ITT ORR TRT %.1f%% vs PBO %.1f%%, RD=%.1f, p=%s",
                100*p_trt, 100*p_pbo, rd, fmt_p(cmh_p)))
