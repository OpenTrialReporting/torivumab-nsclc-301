# torivumab guidelines loaded
# =============================================================================
# t_lb_01_shift.R
# T-LB-01 — Laboratory Abnormalities Shift Table (Baseline → Worst Post-Baseline)
# Population: Safety
# Source: ADLB (BNRIND, ANRIND, ABLFL) — SAP §5.6, #27 D8/D9
#
# Baseline category  : BNRIND on the ABLFL = 'Y' record
# Worst post-baseline: ANRIND of the most extreme post-baseline record. Any
#                      abnormal (LOW / HIGH) record beats NORMAL; when a subject
#                      has both LOW and HIGH post-baseline results, the record
#                      furthest outside the reference range — distance beyond
#                      the nearer bound, scaled by the range width — supplies
#                      the category (ties: earliest ADT).
# Layout             : per parameter, the 3 × 3 baseline × worst cross-tab
#                      (NORMAL / LOW / HIGH) as long-form rows; the parameter
#                      header row carries the per-arm denominator = subjects
#                      with both a baseline and a post-baseline result.
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adlb <- load_adam("adlb") |> filter(SAFFL == "Y")

CATS <- c("NORMAL", "LOW", "HIGH")

# Baseline reference-range category per subject per parameter
baseline <- adlb |>
  filter(ABLFL == "Y", !is.na(BNRIND)) |>
  distinct(USUBJID, PARAMCD, PARAM, base_cat = BNRIND)

# Worst post-baseline category per subject per parameter
post_bl <- adlb |>
  filter(is.na(ABLFL) | ABLFL != "Y", !is.na(ANRIND), !is.na(AVAL)) |>
  mutate(
    width = ANRHI - ANRLO,
    dev   = case_when(
      ANRIND == "HIGH" & !is.na(width) & width > 0 ~ (AVAL - ANRHI) / width,
      ANRIND == "LOW"  & !is.na(width) & width > 0 ~ (ANRLO - AVAL) / width,
      ANRIND %in% c("HIGH", "LOW")                 ~ 1,      # abnormal, width unknown
      TRUE                                         ~ 0       # NORMAL
    )
  ) |>
  arrange(USUBJID, PARAMCD, desc(dev), ADT) |>
  group_by(USUBJID, PARAMCD) |>
  summarise(worst_cat = first(ANRIND), .groups = "drop")

shifts <- baseline |>
  inner_join(post_bl, by = c("USUBJID", "PARAMCD")) |>
  left_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID")

PARAMS_DISPLAY <- shifts |> distinct(PARAMCD, PARAM) |> arrange(PARAMCD)

# Per-arm denominators per parameter = subjects with baseline + post-baseline
denoms <- shifts |>
  group_by(PARAMCD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop")

count_shift <- function(pcode, bcat, wcat, arm_full) {
  sum(shifts$PARAMCD == pcode & shifts$base_cat == bcat &
        shifts$worst_cat == wcat & shifts$TRT01A == arm_full)
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
  for (bc in CATS) for (wc in CATS) {
    add(sprintf("  Baseline %s \u2192 worst %s", bc, wc),
        count_shift(pc, bc, wc, "Torivumab + Chemotherapy"), trt_d,
        count_shift(pc, bc, wc, "Placebo + Chemotherapy"),   pbo_d)
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
  title = "Laboratory Abnormalities \u2014 Baseline \u2192 Worst Post-Baseline Shift",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Shift = baseline reference-range category (BNRIND, ABLFL = 'Y' record) \u2192 worst post-baseline category (ANRIND) per subject per parameter; categories LOW / NORMAL / HIGH against the central-laboratory reference range (SAP \u00a75.6).",
    "Worst post-baseline = the most extreme post-baseline record: any LOW or HIGH result beats NORMAL; where both LOW and HIGH occur, the record furthest outside the reference range (distance beyond the nearer bound, scaled by the range width) supplies the category.",
    "Section header rows show the per-arm denominator (subjects with both a baseline and a post-baseline result for that parameter); cell percentages use that denominator.",
    "Source: datasets/adam/adlb.parquet (BNRIND, ANRIND, ABLFL)."
  )
)
message(sprintf("T-LB-01 written: %d parameters", nrow(PARAMS_DISPLAY)))
