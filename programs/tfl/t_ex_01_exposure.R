# torivumab guidelines loaded
# =============================================================================
# t_ex_01_exposure.R
# T-EX-01 — Study Drug Exposure
# Population: Safety
# Source: ADEX (PARAMCD ∈ {DOSEAMT, CUMDOSE, RDI}) + ADSL.TRTDURD
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adex <- load_adam("adex") |> filter(SAFFL == "Y")

counts <- list(
  n_trt = sum(adsl$TRT01A == "Torivumab + Chemotherapy"),
  n_pbo = sum(adsl$TRT01A == "Placebo + Chemotherapy"),
  n_tot = nrow(adsl)
)

# Treatment duration (days) from ADSL
dur_stats <- function(d) {
  v <- d$TRTDURD
  list(n=sum(!is.na(v)), mean=mean(v, na.rm=TRUE), sd=sd(v, na.rm=TRUE),
       median=median(v, na.rm=TRUE), min=min(v, na.rm=TRUE), max=max(v, na.rm=TRUE))
}
d_trt <- dur_stats(adsl |> filter(TRT01A == "Torivumab + Chemotherapy"))
d_pbo <- dur_stats(adsl |> filter(TRT01A == "Placebo + Chemotherapy"))
d_tot <- dur_stats(adsl)

# Cycles received from ADEX DOSEAMT (study-drug administrations only)
dose_admin <- adex |> filter(PARAMCD == "DOSEAMT",
                             AEXTRT %in% c("TORIVUMAB", "PLACEBO"))
cycles_per_subj <- dose_admin |>
  group_by(USUBJID, TRT01A) |>
  summarise(n_cyc = n(), .groups = "drop")

cyc_stats <- function(d) {
  v <- d$n_cyc
  if (length(v) == 0) return(list(n=0L, mean=NA, sd=NA, median=NA, min=NA, max=NA))
  list(n=length(v), mean=mean(v), sd=sd(v),
       median=median(v), min=min(v), max=max(v))
}
c_trt <- cyc_stats(cycles_per_subj |> filter(TRT01A == "Torivumab + Chemotherapy"))
c_pbo <- cyc_stats(cycles_per_subj |> filter(TRT01A == "Placebo + Chemotherapy"))
c_tot <- cyc_stats(cycles_per_subj)

# Cumulative torivumab dose from ADEX CUMDOSE
tor_dose <- adex |>
  filter(PARAMCD == "CUMDOSE", AEXTRT == "TORIVUMAB",
         TRT01A == "Torivumab + Chemotherapy")
dose_stats <- function(d) {
  v <- d$AVAL
  if (length(v) == 0) return(list(n=0L, mean=NA, sd=NA, median=NA, min=NA, max=NA))
  list(n=length(v), mean=mean(v), sd=sd(v),
       median=median(v), min=min(v), max=max(v))
}
dose_trt <- dose_stats(tor_dose)

# Relative Dose Intensity (RDI) from ADEX RDI parameter — torivumab
rdi_trt_df <- adex |>
  filter(PARAMCD == "RDI", AEXTRT == "TORIVUMAB",
         TRT01A == "Torivumab + Chemotherapy")
rdi_pbo_df <- adex |>
  filter(PARAMCD == "RDI", AEXTRT == "PLACEBO",
         TRT01A == "Placebo + Chemotherapy")
rdi_summ <- function(d) {
  v <- d$AVAL
  if (length(v) == 0) return(list(n=0L, mean=NA, sd=NA, median=NA, min=NA, max=NA))
  list(n=length(v), mean=mean(v, na.rm=TRUE), sd=sd(v, na.rm=TRUE),
       median=median(v, na.rm=TRUE), min=min(v, na.rm=TRUE), max=max(v, na.rm=TRUE))
}
rdi_trt <- rdi_summ(rdi_trt_df)
rdi_pbo <- rdi_summ(rdi_pbo_df)

rows <- list()
add_row <- function(label, vt, vp, vto) {
  rows[[length(rows) + 1]] <<- data.frame(
    Label = label, TRT = vt, PBO = vp, TOT = vto,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# Section: Treatment duration
add_row("Treatment duration (days)", "", "", "")
add_row("  n",                       as.character(d_trt$n), as.character(d_pbo$n), as.character(d_tot$n))
add_row("  Mean (SD)",                fmt_mean_sd(d_trt$mean, d_trt$sd),
                                       fmt_mean_sd(d_pbo$mean, d_pbo$sd),
                                       fmt_mean_sd(d_tot$mean, d_tot$sd))
add_row("  Median (Min, Max)",        fmt_med_range(d_trt$median, d_trt$min, d_trt$max, 0),
                                       fmt_med_range(d_pbo$median, d_pbo$min, d_pbo$max, 0),
                                       fmt_med_range(d_tot$median, d_tot$min, d_tot$max, 0))

# Section: Cycles
add_row("Number of study drug cycles received", "", "", "")
add_row("  n",                        as.character(c_trt$n), as.character(c_pbo$n), as.character(c_tot$n))
add_row("  Mean (SD)",                 fmt_mean_sd(c_trt$mean, c_trt$sd),
                                        fmt_mean_sd(c_pbo$mean, c_pbo$sd),
                                        fmt_mean_sd(c_tot$mean, c_tot$sd))
add_row("  Median (Min, Max)",         fmt_med_range(c_trt$median, c_trt$min, c_trt$max, 0),
                                        fmt_med_range(c_pbo$median, c_pbo$min, c_pbo$max, 0),
                                        fmt_med_range(c_tot$median, c_tot$min, c_tot$max, 0))

# Section: Cumulative torivumab dose
add_row("Cumulative torivumab dose (mg)", "", "", "")
add_row("  n",                         as.character(dose_trt$n), "—", as.character(dose_trt$n))
add_row("  Mean (SD)",                  fmt_mean_sd(dose_trt$mean, dose_trt$sd, 0), "—",
                                         fmt_mean_sd(dose_trt$mean, dose_trt$sd, 0))
add_row("  Median (Min, Max)",          fmt_med_range(dose_trt$median, dose_trt$min, dose_trt$max, 0), "—",
                                         fmt_med_range(dose_trt$median, dose_trt$min, dose_trt$max, 0))

# Section: Relative Dose Intensity
add_row("Relative dose intensity (%) — study drug", "", "", "")
add_row("  Mean (SD)",                  fmt_mean_sd(rdi_trt$mean, rdi_trt$sd, 1),
                                         fmt_mean_sd(rdi_pbo$mean, rdi_pbo$sd, 1),
                                         "—")
add_row("  Median (Min, Max)",          fmt_med_range(rdi_trt$median, rdi_trt$min, rdi_trt$max, 1),
                                         fmt_med_range(rdi_pbo$median, rdi_pbo$min, rdi_pbo$max, 1),
                                         "—")

tbl <- do.call(rbind, rows)
section_rows <- which(tbl$Label %in% c(
  "Treatment duration (days)",
  "Number of study drug cycles received",
  "Cumulative torivumab dose (mg)",
  "Relative dose intensity (%) — study drug"))
indent_rows <- setdiff(seq_len(nrow(tbl)), section_rows)

names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", counts$n_trt),
                arm_label("Placebo + Chemotherapy",   counts$n_pbo),
                arm_label("Total",                    counts$n_tot))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.4)
ft <- ft |> indent_ft(indent_rows, levels = 1) |> bold_section_ft(section_rows)

write_table_all_formats(
  ft, id = "T-EX-01",
  title = "Study Drug Exposure",
  population = pop_label(counts$n_tot, "SAFFL"),
  notes = c(
    "Treatment duration = ADSL.TRTDURD (TRTEDT − TRTSDT + 1 days).",
    "Cycle count = number of TORIVUMAB or PLACEBO records in ADEX PARAMCD='DOSEAMT'.",
    "Cumulative torivumab dose = ADEX PARAMCD='CUMDOSE', AEXTRT='TORIVUMAB' (mg).",
    "Relative dose intensity (RDI) = ADEX PARAMCD='RDI' = 100 × actual cumulative / planned cumulative dose. Planned per cycle: torivumab/placebo 200 mg; chemo per-subject mean used as planned (synthetic-data simplification).",
    "Source: datasets/adam/adex.parquet + datasets/adam/adsl.parquet."
  )
)
message(sprintf("T-EX-01 written: TRT med dur %.0fd / %.1f cycles / %.0f mg cum / %.0f%% RDI",
                d_trt$median, c_trt$median, dose_trt$median, rdi_trt$median))
