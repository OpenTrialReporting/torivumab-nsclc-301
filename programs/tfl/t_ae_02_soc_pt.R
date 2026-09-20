# torivumab guidelines loaded
# =============================================================================
# t_ae_02_soc_pt.R
# T-AE-02 — TEAEs by SOC and Preferred Term (≥5% in any arm)
# Population: Safety
# Source: ADAE
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y")

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Subject-level incidence per SOC × PT × ARM (distinct subjects)
inc <- adae |>
  filter(!is.na(AEBODSYS), !is.na(AEDECOD)) |>
  group_by(AEBODSYS, AEDECOD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(
    names_from = TRT01A, values_from = n,
    values_fill = 0
  ) |>
  rename(TRT = `Torivumab + Chemotherapy`,
         PBO = `Placebo + Chemotherapy`) |>
  mutate(
    pct_trt = 100 * TRT / n_trt,
    pct_pbo = 100 * PBO / n_pbo,
    max_pct = pmax(pct_trt, pct_pbo)
  ) |>
  filter(max_pct >= 5) |>
  arrange(AEBODSYS, desc(max_pct))

# SOC-level totals (any PT, distinct subjects in this SOC)
soc_inc <- adae |>
  group_by(AEBODSYS, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0) |>
  rename(TRT = `Torivumab + Chemotherapy`,
         PBO = `Placebo + Chemotherapy`)

# Build table: per SOC: header row + PT rows
rows <- list()
section_rows <- integer(0)
indent_rows  <- integer(0)
row_id <- 0L
add <- function(label, trt_n, pbo_n, is_section = FALSE) {
  row_id <<- row_id + 1L
  rows[[row_id]] <<- data.frame(
    Label = label,
    TRT = fmt_n_pct(trt_n, n_trt),
    PBO = fmt_n_pct(pbo_n, n_pbo),
    stringsAsFactors = FALSE, check.names = FALSE)
  if (is_section) section_rows <<- c(section_rows, row_id)
  else            indent_rows  <<- c(indent_rows,  row_id)
}

# Overall "Any TEAE" row heading the SOC/PT hierarchy (shell annotation).
# Distinct subjects with >= 1 TEAE, independent of the >= 5% PT filter.
add("Any treatment-emergent AE",
    n_distinct(adae$USUBJID[adae$TRT01A == "Torivumab + Chemotherapy"]),
    n_distinct(adae$USUBJID[adae$TRT01A == "Placebo + Chemotherapy"]),
    is_section = TRUE)

for (soc in sort(unique(inc$AEBODSYS))) {
  soc_t <- soc_inc$TRT[soc_inc$AEBODSYS == soc]
  soc_p <- soc_inc$PBO[soc_inc$AEBODSYS == soc]
  add(soc, soc_t, soc_p, is_section = TRUE)
  pts <- inc |> filter(AEBODSYS == soc)
  for (i in seq_len(nrow(pts))) {
    add(paste0("  ", pts$AEDECOD[i]), pts$TRT[i], pts$PBO[i])
  }
}

tbl <- do.call(rbind, rows)
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt),
                arm_label("Placebo + Chemotherapy",   n_pbo))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 4.0)
ft <- ft |> bold_section_ft(section_rows) |> indent_ft(indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-AE-02",
  title = "Treatment-Emergent AEs by SOC and Preferred Term (≥ 5% in any arm)",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Includes Preferred Terms with incidence ≥ 5% in either arm.",
    "SOC subtotals = distinct subjects with at least one PT in that SOC.",
    "\u0027Any treatment-emergent AE\u0027 counts distinct subjects with >= 1 TEAE and is not restricted by the >= 5% Preferred Term filter.",
    "Within SOC, PTs sorted by maximum incidence across arms (descending).",
    "Source: datasets/adam/adae.parquet WHERE SAFFL='Y' AND TRTEMFL='Y'; datasets/adam/adsl.parquet WHERE SAFFL='Y' (denominators)."
  )
)
message(sprintf("T-AE-02 written: %d PTs across %d SOCs",
                length(indent_rows), length(section_rows) - 1L))
