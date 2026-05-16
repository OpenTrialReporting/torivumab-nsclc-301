# torivumab guidelines loaded
# =============================================================================
# t_ae_07_deaths.R
# T-AE-07 — Deaths (overall + on-study + within 30 days of last dose, by cause)
# Population: Safety
# Sources: ADSL (DTHFL/DTHDT/LSTALVDT/TRTEDT) + SDTM.DD (DDTERM cause)
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
dd   <- as.data.frame(read_parquet("datasets/sdtm/dd.parquet"))

counts <- list(
  n_trt = sum(adsl$TRT01A == "Torivumab + Chemotherapy"),
  n_pbo = sum(adsl$TRT01A == "Placebo + Chemotherapy"),
  n_tot = nrow(adsl)
)

deaths <- adsl |> filter(DTHFL == "Y") |>
  left_join(dd |> select(USUBJID, DDTERM), by = "USUBJID") |>
  mutate(
    days_post_trt = as.integer(as.Date(DTHDT) - as.Date(TRTEDT)),
    on_study      = days_post_trt <= 30,
    is_trt        = TRT01A == "Torivumab + Chemotherapy"
  )

n_subj_arm <- function(filter_expr) {
  flt <- deaths |> filter(!!enquo(filter_expr))
  list(
    trt = sum(flt$is_trt),
    pbo = sum(!flt$is_trt),
    tot = nrow(flt)
  )
}

n_all       <- n_subj_arm(TRUE)
n_on_study  <- n_subj_arm(on_study == TRUE)
n_late      <- n_subj_arm(on_study == FALSE)

# Cause-of-death breakdown (overall)
cause_levels <- sort(unique(deaths$DDTERM))
cause_rows <- lapply(cause_levels, function(cz) {
  n <- n_subj_arm(DDTERM == cz)
  data.frame(
    Label = paste0("  ", cz),
    TRT = fmt_n_pct(n$trt, counts$n_trt),
    PBO = fmt_n_pct(n$pbo, counts$n_pbo),
    TOT = fmt_n_pct(n$tot, counts$n_tot),
    stringsAsFactors = FALSE, check.names = FALSE
  )
})
cause_tbl <- do.call(rbind, cause_rows)

rows <- list(
  data.frame(Label = "All deaths", TRT = fmt_n_pct(n_all$trt, counts$n_trt),
             PBO = fmt_n_pct(n_all$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n_all$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "  Death on study (within 30 days of last dose)",
             TRT = fmt_n_pct(n_on_study$trt, counts$n_trt),
             PBO = fmt_n_pct(n_on_study$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n_on_study$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "  Death > 30 days after last dose",
             TRT = fmt_n_pct(n_late$trt, counts$n_trt),
             PBO = fmt_n_pct(n_late$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n_late$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "Primary cause of death (all deaths)",
             TRT = "", PBO = "", TOT = "",
             stringsAsFactors = FALSE, check.names = FALSE)
)
tbl <- do.call(rbind, c(rows, list(cause_tbl)))
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", counts$n_trt),
                arm_label("Placebo + Chemotherapy",   counts$n_pbo),
                arm_label("Total",                    counts$n_tot))

section_rows <- which(tbl$Label %in% c("All deaths",
                                         "Primary cause of death (all deaths)"))
indent_rows  <- which(grepl("^  ", tbl$Label))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.6)
ft <- ft |> bold_section_ft(section_rows) |> indent_ft(indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-AE-07",
  title = "Deaths",
  population = pop_label(counts$n_tot, "SAFFL"),
  notes = c(
    "All causes of death from SDTM.DD (one record per deceased subject).",
    "On-study = death ≤ 30 days after TRTEDT; late = death > 30 days after TRTEDT.",
    "Source: datasets/adam/adsl.parquet + datasets/sdtm/dd.parquet."
  )
)
message(sprintf("T-AE-07 written: %d deaths (TRT %d / PBO %d)",
                n_all$tot, n_all$trt, n_all$pbo))
