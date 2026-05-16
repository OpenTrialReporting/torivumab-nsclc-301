# torivumab guidelines loaded
# =============================================================================
# t_eff_06_dcr.R
# T-EFF-06 — Disease Control Rate (DCR = CR + PR + SD with SD≥8 weeks)
# Population: Response Evaluable
# Source: ADRS PARAMCD='CBOR' + 'OVR' for SD duration + ADSL
# Estimand: E5
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adrs <- load_adam("adrs")

re_subj <- adrs |> filter(PARAMCD == "OVR") |> distinct(USUBJID) |> pull(USUBJID)
adsl_re <- adsl |> filter(USUBJID %in% re_subj)

# CBOR
cbor <- adrs |> filter(PARAMCD == "CBOR") |>
  select(USUBJID, CBOR = AVALC)

# SD duration: first SD date → next non-SD date or last OVR date
sd_first <- adrs |> filter(PARAMCD == "OVR", AVALC == "SD") |>
  group_by(USUBJID) |>
  summarise(first_sd = min(as.Date(ADT)), .groups = "drop")

last_assess <- adrs |> filter(PARAMCD == "OVR") |>
  group_by(USUBJID) |>
  summarise(last_ovr = max(as.Date(ADT)), .groups = "drop")

dat <- adsl_re |>
  left_join(cbor, by = "USUBJID") |>
  left_join(sd_first, by = "USUBJID") |>
  left_join(last_assess, by = "USUBJID") |>
  mutate(
    sd_duration_days = ifelse(!is.na(first_sd) & !is.na(last_ovr),
                                as.integer(last_ovr - first_sd), NA),
    # DCR: CR/PR responders, OR SD with duration >= 8 weeks (56 days)
    is_dc = (CBOR %in% c("CR","PR")) |
            (CBOR == "SD" & !is.na(sd_duration_days) & sd_duration_days >= 56),
    is_trt = TRT01P == "Torivumab + Chemotherapy"
  )

n_re_trt <- sum(dat$is_trt)
n_re_pbo <- sum(!dat$is_trt)
dc_trt   <- sum(dat$is_dc & dat$is_trt, na.rm = TRUE)
dc_pbo   <- sum(dat$is_dc & !dat$is_trt, na.rm = TRUE)

ci_trt <- binom.test(dc_trt, n_re_trt)$conf.int * 100
ci_pbo <- binom.test(dc_pbo, n_re_pbo)$conf.int * 100

p_trt <- dc_trt / n_re_trt
p_pbo <- dc_pbo / n_re_pbo
rd    <- 100 * (p_trt - p_pbo)
se_rd <- sqrt(p_trt*(1-p_trt)/n_re_trt + p_pbo*(1-p_pbo)/n_re_pbo) * 100
rd_lo <- rd - 1.96 * se_rd
rd_hi <- rd + 1.96 * se_rd

# CMH
tab <- table(arm = factor(dat$is_trt, levels = c(FALSE, TRUE),
                          labels = c("PBO","TRT")),
             dc  = factor(dat$is_dc, levels = c(TRUE, FALSE)),
             strat = paste(dat$HISTCAT, dat$REGION))
keep <- apply(tab, 3, function(m) min(rowSums(m)) > 0)
mh <- tryCatch(mantelhaen.test(tab[,,keep], exact = FALSE),
                error = function(e) NULL)
cmh_p <- if (!is.null(mh)) mh$p.value else NA_real_

rows <- data.frame(
  Label = c(
    "Subjects in Response Evaluable population, N",
    "Disease Control Rate (CR + PR + SD ≥8 weeks), n (%)",
    "  95% CI (Clopper-Pearson)",
    "Risk difference TRT − PBO, % (95% CI Wald)",
    "p-value (Cochran-Mantel-Haenszel, stratified)"
  ),
  TRT = c(
    sprintf("%d", n_re_trt),
    fmt_n_pct(dc_trt, n_re_trt),
    sprintf("(%.1f, %.1f)", ci_trt[1], ci_trt[2]),
    sprintf("%.1f (%.1f, %.1f)", rd, rd_lo, rd_hi),
    fmt_p(cmh_p)
  ),
  PBO = c(
    sprintf("%d", n_re_pbo),
    fmt_n_pct(dc_pbo, n_re_pbo),
    sprintf("(%.1f, %.1f)", ci_pbo[1], ci_pbo[2]),
    "", ""
  ),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", n_re_trt),
                 arm_label("Placebo + Chemotherapy",   n_re_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)
ft <- ft |> indent_ft(3, levels = 1)
ft <- bold(ft, i = c(2, 4, 5), part = "body")

write_table_all_formats(
  ft, id = "T-EFF-06",
  title = "Disease Control Rate",
  population = sprintf("Response Evaluable Population (N=%d)", nrow(dat)),
  notes = c(
    "DCR = subjects with confirmed CBOR of CR, PR, or SD (duration ≥8 weeks from randomisation).",
    "SD duration computed as days between first SD assessment and last OVR record.",
    "Per-arm 95% CI by Clopper-Pearson; stratified CMH p-value (histology × region).",
    "Source: datasets/adam/adrs.parquet, adsl.parquet."
  )
)

message(sprintf("T-EFF-06 written: DCR TRT %.1f%% vs PBO %.1f%%, RD=%.1f, p=%s",
                100*p_trt, 100*p_pbo, rd, fmt_p(cmh_p)))
