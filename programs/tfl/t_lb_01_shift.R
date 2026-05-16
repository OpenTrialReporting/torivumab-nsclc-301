# torivumab guidelines loaded
# =============================================================================
# t_lb_01_shift.R
# T-LB-01 — Laboratory Abnormalities Shift Table (Baseline → Worst Post-Baseline)
# Population: Safety
# Source: ADLB
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adlb <- load_adam("adlb") |> filter(SAFFL == "Y", !is.na(NRIND))

# Baseline NRIND per subject per parameter
baseline <- adlb |> filter(ABLFL == "Y") |>
  select(USUBJID, PARAMCD, PARAM, base_nrind = NRIND)

# Worst post-baseline (worst = HIGH or LOW; if any abnormal across visits, use that)
nrind_order <- c("LOW" = 1, "HIGH" = 1, "NORMAL" = 0)
post_bl <- adlb |>
  filter(is.na(ABLFL) | ABLFL != "Y") |>
  mutate(score = nrind_order[NRIND]) |>
  group_by(USUBJID, PARAMCD) |>
  summarise(
    worst_score = max(score, na.rm = TRUE),
    worst_nrind = first(NRIND[score == max(score, na.rm = TRUE)]),
    .groups = "drop"
  ) |>
  mutate(worst_nrind = ifelse(worst_score == 0, "NORMAL", worst_nrind))

shifts <- baseline |>
  inner_join(post_bl, by = c("USUBJID","PARAMCD")) |>
  left_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID")

# Build wide shift counts per parameter × arm
PARAMS_DISPLAY <- shifts |> distinct(PARAMCD, PARAM) |> arrange(PARAMCD)

categories <- c("NORMAL → NORMAL", "NORMAL → ABNORMAL",
                "ABNORMAL → NORMAL", "ABNORMAL → ABNORMAL")

classify <- function(bn, wn) {
  bn_a <- bn != "NORMAL"
  wn_a <- wn != "NORMAL"
  case_when(
    !bn_a & !wn_a ~ "NORMAL → NORMAL",
    !bn_a &  wn_a ~ "NORMAL → ABNORMAL",
     bn_a & !wn_a ~ "ABNORMAL → NORMAL",
     bn_a &  wn_a ~ "ABNORMAL → ABNORMAL"
  )
}

shifts <- shifts |>
  mutate(category = classify(base_nrind, worst_nrind))

# Per-arm denominators per parameter = subjects with baseline + post-baseline
denoms <- shifts |>
  group_by(PARAMCD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop")

count_shift <- function(pcode, cat, arm_full) {
  sum(shifts$PARAMCD == pcode & shifts$category == cat &
        shifts$TRT01A == arm_full)
}
denom_of <- function(pcode, arm_full) {
  d <- denoms$n[denoms$PARAMCD == pcode & denoms$TRT01A == arm_full]
  if (length(d) == 0) 0L else d
}

rows <- list(); section_rows <- integer(0); indent_rows <- integer(0); rid <- 0L
add <- function(label, t, t_d, p, p_d, sec = FALSE) {
  rid <<- rid + 1L
  rows[[rid]] <<- data.frame(
    Label = label,
    TRT = fmt_n_pct(t, t_d),
    PBO = fmt_n_pct(p, p_d),
    stringsAsFactors = FALSE, check.names = FALSE)
  if (sec) section_rows <<- c(section_rows, rid)
  else     indent_rows  <<- c(indent_rows,  rid)
}

n_trt_all <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo_all <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

for (i in seq_len(nrow(PARAMS_DISPLAY))) {
  pc <- PARAMS_DISPLAY$PARAMCD[i]
  pl <- PARAMS_DISPLAY$PARAM[i]
  trt_d <- denom_of(pc, "Torivumab + Chemotherapy")
  pbo_d <- denom_of(pc, "Placebo + Chemotherapy")
  add(sprintf("%s (n with baseline + post-baseline)", pl),
      trt_d, n_trt_all, pbo_d, n_pbo_all, sec = TRUE)
  for (cat in categories) {
    add(paste0("  ", cat),
        count_shift(pc, cat, "Torivumab + Chemotherapy"), trt_d,
        count_shift(pc, cat, "Placebo + Chemotherapy"),   pbo_d)
  }
}

tbl <- do.call(rbind, rows)
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt_all),
                arm_label("Placebo + Chemotherapy",   n_pbo_all))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.8)
ft <- ft |> bold_section_ft(section_rows) |> indent_ft(indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-LB-01",
  title = "Laboratory Abnormalities — Baseline → Worst Post-Baseline Shift",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Shift = baseline reference-range indicator → worst post-baseline indicator per subject per parameter.",
    "NORMAL = within reference range; ABNORMAL = HIGH or LOW.",
    "Section header rows show the per-arm denominator (subjects with both baseline and post-baseline values for that parameter); cell percentages use that denominator.",
    "Source: datasets/adam/adlb.parquet (NRIND, ABLFL)."
  )
)
message(sprintf("T-LB-01 written: %d parameters", nrow(PARAMS_DISPLAY)))
