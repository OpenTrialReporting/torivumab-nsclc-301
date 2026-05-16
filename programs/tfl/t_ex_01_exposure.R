# torivumab guidelines loaded
# =============================================================================
# t_ex_01_exposure.R
# T-EX-01 — Study Drug Exposure
# Population: Safety
# Source: ADSL (TRTDURD) + SDTM.EX (cycle/dose counts)
# Estimand: descriptive (safety §5.5)
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
ex   <- as.data.frame(read_parquet("datasets/sdtm/ex.parquet"))

# Safety arm counts
counts <- list(
  n_trt = sum(adsl$TRT01A == "Torivumab + Chemotherapy"),
  n_pbo = sum(adsl$TRT01A == "Placebo + Chemotherapy"),
  n_tot = nrow(adsl)
)

# Treatment duration (days)
dur_stats <- function(d) {
  v <- d$TRTDURD
  list(
    n      = sum(!is.na(v)),
    mean   = mean(v, na.rm = TRUE),
    sd     = sd(v,   na.rm = TRUE),
    median = median(v, na.rm = TRUE),
    min    = min(v,    na.rm = TRUE),
    max    = max(v,    na.rm = TRUE)
  )
}
d_trt <- dur_stats(adsl |> filter(TRT01A == "Torivumab + Chemotherapy"))
d_pbo <- dur_stats(adsl |> filter(TRT01A == "Placebo + Chemotherapy"))
d_tot <- dur_stats(adsl)

# Cycles per subject (count of TORIVUMAB / PLACEBO administrations per USUBJID)
ex_study <- ex |>
  filter(EXTRT %in% c("TORIVUMAB", "PLACEBO")) |>
  left_join(adsl |> select(USUBJID, TRT01A), by = "USUBJID") |>
  filter(!is.na(TRT01A))

cycles_per_subj <- ex_study |>
  group_by(USUBJID, TRT01A) |>
  summarise(n_cyc = n(), .groups = "drop")

cyc_stats <- function(d) {
  v <- d$n_cyc
  list(
    n      = nrow(d),
    mean   = mean(v),
    sd     = sd(v),
    median = median(v),
    min    = min(v),
    max    = max(v)
  )
}
c_trt <- cyc_stats(cycles_per_subj |> filter(TRT01A == "Torivumab + Chemotherapy"))
c_pbo <- cyc_stats(cycles_per_subj |> filter(TRT01A == "Placebo + Chemotherapy"))
c_tot <- cyc_stats(cycles_per_subj)

# Cumulative dose of study drug (TORIVUMAB only, in mg)
tor_dose <- ex_study |>
  filter(EXTRT == "TORIVUMAB") |>
  group_by(USUBJID, TRT01A) |>
  summarise(cum_dose = sum(as.numeric(EXDOSE), na.rm = TRUE), .groups = "drop") |>
  left_join(adsl |> select(USUBJID, TRT01A), by = c("USUBJID","TRT01A"))

dose_stats <- function(d) {
  v <- d$cum_dose
  if (length(v) == 0) return(list(n=0L, mean=NA, sd=NA, median=NA, min=NA, max=NA))
  list(
    n      = length(v),
    mean   = mean(v),
    sd     = sd(v),
    median = median(v),
    min    = min(v),
    max    = max(v)
  )
}
dose_trt <- dose_stats(tor_dose |> filter(TRT01A == "Torivumab + Chemotherapy"))

rows <- list()
add_row <- function(label, vt, vp, vto) {
  rows[[length(rows) + 1]] <<- data.frame(
    Label = label, TRT = vt, PBO = vp, TOT = vto,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# Section: Treatment duration
add_row("Treatment duration (days)", "", "", "")
add_row("  n",                   as.character(d_trt$n),  as.character(d_pbo$n),  as.character(d_tot$n))
add_row("  Mean (SD)",            fmt_mean_sd(d_trt$mean,   d_trt$sd),
                                  fmt_mean_sd(d_pbo$mean,   d_pbo$sd),
                                  fmt_mean_sd(d_tot$mean,   d_tot$sd))
add_row("  Median (Min, Max)",    fmt_med_range(d_trt$median, d_trt$min, d_trt$max, 0),
                                  fmt_med_range(d_pbo$median, d_pbo$min, d_pbo$max, 0),
                                  fmt_med_range(d_tot$median, d_tot$min, d_tot$max, 0))

# Section: Cycles received (study drug administrations)
add_row("Number of study drug cycles received", "", "", "")
add_row("  n",                   as.character(c_trt$n),  as.character(c_pbo$n),  as.character(c_tot$n))
add_row("  Mean (SD)",            fmt_mean_sd(c_trt$mean,   c_trt$sd),
                                  fmt_mean_sd(c_pbo$mean,   c_pbo$sd),
                                  fmt_mean_sd(c_tot$mean,   c_tot$sd))
add_row("  Median (Min, Max)",    fmt_med_range(c_trt$median, c_trt$min, c_trt$max, 0),
                                  fmt_med_range(c_pbo$median, c_pbo$min, c_pbo$max, 0),
                                  fmt_med_range(c_tot$median, c_tot$min, c_tot$max, 0))

# Section: Cumulative dose (Torivumab only)
add_row("Cumulative torivumab dose (mg)", "", "", "")
add_row("  n",                    as.character(dose_trt$n),  "—", as.character(dose_trt$n))
add_row("  Mean (SD)",            fmt_mean_sd(dose_trt$mean,  dose_trt$sd, digits = 0),
                                  "—",
                                  fmt_mean_sd(dose_trt$mean,  dose_trt$sd, digits = 0))
add_row("  Median (Min, Max)",    fmt_med_range(dose_trt$median, dose_trt$min, dose_trt$max, 0),
                                  "—",
                                  fmt_med_range(dose_trt$median, dose_trt$min, dose_trt$max, 0))

tbl <- do.call(rbind, rows)
section_rows <- which(tbl$Label %in% c("Treatment duration (days)",
                                         "Number of study drug cycles received",
                                         "Cumulative torivumab dose (mg)"))
indent_rows <- setdiff(seq_len(nrow(tbl)), section_rows)

names(tbl) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.0)
ft <- ft |> indent_ft(indent_rows, levels = 1) |> bold_section_ft(section_rows)

write_table_all_formats(
  ft,
  id         = "T-EX-01",
  title      = "Study Drug Exposure",
  population = pop_label(counts$n_tot, "SAFFL"),
  notes      = c(
    "Treatment duration = ADSL.TRTDURD = TRTEDT − TRTSDT + 1 days.",
    "Cycle count = number of TORIVUMAB or PLACEBO administrations in SDTM.EX (one row per Q3W dose).",
    "Cumulative torivumab dose: sum of EX.EXDOSE (mg) over all torivumab administrations per subject.",
    "Cumulative dose not applicable to placebo arm.",
    "Source: datasets/adam/adsl.parquet, datasets/sdtm/ex.parquet"
  )
)
message(sprintf("T-EX-01 written: TRT med duration %.0fd / %.1f cycles | PBO med %.0fd / %.1f cycles",
                d_trt$median, c_trt$median, d_pbo$median, c_pbo$median))
