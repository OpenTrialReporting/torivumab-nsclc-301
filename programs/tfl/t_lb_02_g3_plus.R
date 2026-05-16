# torivumab guidelines loaded
# =============================================================================
# t_lb_02_g3_plus.R
# T-LB-02 — Laboratory CTCAE Grade ≥ 3 Worst Post-Baseline
# Population: Safety
# Source: ADLB
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adlb <- load_adam("adlb") |> filter(SAFFL == "Y", !is.na(ATOXGRN))

# Worst post-baseline ATOXGR per subject per parameter
worst <- adlb |>
  filter(is.na(ABLFL) | ABLFL != "Y") |>
  group_by(USUBJID, PARAMCD, PARAM) |>
  summarise(worst_g = max(ATOXGRN, na.rm = TRUE), .groups = "drop") |>
  left_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID")

# Denominator: subjects with at least one post-baseline ATOXGR per parameter per arm
denoms <- worst |>
  group_by(PARAMCD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop")

PARAMS_DISPLAY <- worst |> distinct(PARAMCD, PARAM) |> arrange(PARAMCD)

n_trt_all <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo_all <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

denom_of <- function(pc, arm_full) {
  d <- denoms$n[denoms$PARAMCD == pc & denoms$TRT01A == arm_full]
  if (length(d) == 0) 0L else d
}

count_grade <- function(pc, ge, arm_full) {
  sum(worst$PARAMCD == pc & worst$worst_g >= ge & worst$TRT01A == arm_full,
      na.rm = TRUE)
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

for (i in seq_len(nrow(PARAMS_DISPLAY))) {
  pc <- PARAMS_DISPLAY$PARAMCD[i]
  pl <- PARAMS_DISPLAY$PARAM[i]
  trt_d <- denom_of(pc, "Torivumab + Chemotherapy")
  pbo_d <- denom_of(pc, "Placebo + Chemotherapy")
  add(sprintf("%s (n with post-baseline grade)", pl),
      trt_d, n_trt_all, pbo_d, n_pbo_all, sec = TRUE)
  add("  Grade ≥ 3",
      count_grade(pc, 3, "Torivumab + Chemotherapy"), trt_d,
      count_grade(pc, 3, "Placebo + Chemotherapy"),   pbo_d)
  add("  Grade 4",
      count_grade(pc, 4, "Torivumab + Chemotherapy"), trt_d,
      count_grade(pc, 4, "Placebo + Chemotherapy"),   pbo_d)
}

tbl <- do.call(rbind, rows)
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt_all),
                arm_label("Placebo + Chemotherapy",   n_pbo_all))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.8)
ft <- ft |> bold_section_ft(section_rows) |> indent_ft(indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-LB-02",
  title = "Laboratory CTCAE Grade ≥ 3 Worst Post-Baseline",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Worst post-baseline CTCAE grade per subject per parameter.",
    "Grade per CTCAE v5.0 (ADLB.ATOXGRN).",
    "Section header rows show the per-arm denominator (subjects with at least one gradeable post-baseline value for that parameter).",
    "Source: datasets/adam/adlb.parquet (ATOXGRN)."
  )
)
message(sprintf("T-LB-02 written: %d parameters", nrow(PARAMS_DISPLAY)))
