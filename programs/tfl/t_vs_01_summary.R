# torivumab guidelines loaded
# =============================================================================
# t_vs_01_summary.R
# T-VS-01 — Vital Signs Summary (Mean change from baseline at key visits)
# Population: Safety
# Source: ADVS
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
advs <- load_adam("advs") |> filter(SAFFL == "Y", !is.na(CHG))

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Key visits to summarise (handful)
KEY_VISITS <- c("C1D1", "C4D1", "EOT")

PARAMS_DISPLAY <- advs |>
  distinct(PARAMCD, PARAM) |>
  arrange(PARAMCD) |>
  filter(!PARAMCD %in% c("HEIGHT"))  # height doesn't change meaningfully

summarise_chg <- function(d) {
  v <- d$CHG
  if (length(v) == 0 || all(is.na(v)))
    return(list(n=0L, mean=NA, sd=NA))
  list(n = sum(!is.na(v)),
       mean = mean(v, na.rm = TRUE),
       sd   = sd(v, na.rm = TRUE))
}

rows <- list(); section_rows <- integer(0); indent_rows <- integer(0); rid <- 0L
add <- function(label, vt, vp, sec = FALSE) {
  rid <<- rid + 1L
  rows[[rid]] <<- data.frame(
    Label = label, TRT = vt, PBO = vp,
    stringsAsFactors = FALSE, check.names = FALSE)
  if (sec) section_rows <<- c(section_rows, rid)
  else     indent_rows  <<- c(indent_rows,  rid)
}

for (i in seq_len(nrow(PARAMS_DISPLAY))) {
  pc <- PARAMS_DISPLAY$PARAMCD[i]
  pl <- PARAMS_DISPLAY$PARAM[i]
  add(pl, "", "", sec = TRUE)
  for (vis in KEY_VISITS) {
    s_t <- summarise_chg(advs |> filter(PARAMCD == pc, AVISIT == vis, ANL01FL == "Y",
                                          TRT01A == "Torivumab + Chemotherapy"))
    s_p <- summarise_chg(advs |> filter(PARAMCD == pc, AVISIT == vis, ANL01FL == "Y",
                                          TRT01A == "Placebo + Chemotherapy"))
    add(sprintf("  Change at %s — Mean (SD)", vis),
        sprintf("%s (n=%d)", fmt_mean_sd(s_t$mean, s_t$sd, 1), s_t$n),
        sprintf("%s (n=%d)", fmt_mean_sd(s_p$mean, s_p$sd, 1), s_p$n))
  }
}

tbl <- do.call(rbind, rows)
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt),
                arm_label("Placebo + Chemotherapy",   n_pbo))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.6)
if (length(section_rows) > 0) ft <- bold_section_ft(ft, section_rows)
if (length(indent_rows)  > 0) ft <- indent_ft(ft, indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-VS-01",
  title = "Vital Signs — Mean Change from Baseline at Key Visits",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Change from baseline (ADVS.CHG) at C1D1, C4D1, End of Treatment (EOT).",
    "Per-subject baseline = ADVS.BASE (last value with ABLFL='Y').",
    "Source: datasets/adam/advs.parquet."
  )
)
message(sprintf("T-VS-01 written: %d parameters × %d visits",
                nrow(PARAMS_DISPLAY), length(KEY_VISITS)))
