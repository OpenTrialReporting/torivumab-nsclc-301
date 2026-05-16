# torivumab guidelines loaded
# =============================================================================
# t_mh_01_summary.R
# T-MH-01 — Medical History by Category and Term (≥5%)
# Population: Safety
# Source: ADMH
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
admh <- load_adam("admh") |> filter(SAFFL == "Y")

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Per-subject incidence per MHCAT × MHDECOD × arm
inc <- admh |>
  filter(!is.na(MHCAT), !is.na(MHDECOD)) |>
  group_by(MHCAT, MHDECOD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)
trt_col <- "Torivumab + Chemotherapy"; pbo_col <- "Placebo + Chemotherapy"
if (!trt_col %in% names(inc)) inc[[trt_col]] <- 0L
if (!pbo_col %in% names(inc)) inc[[pbo_col]] <- 0L
inc <- inc |> rename(TRT = !!trt_col, PBO = !!pbo_col) |>
  mutate(pct_trt = 100 * TRT / n_trt,
          pct_pbo = 100 * PBO / n_pbo,
          max_pct = pmax(pct_trt, pct_pbo)) |>
  filter(max_pct >= 5) |>
  arrange(MHCAT, desc(max_pct))

cat_inc <- admh |>
  group_by(MHCAT, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)
if (!trt_col %in% names(cat_inc)) cat_inc[[trt_col]] <- 0L
if (!pbo_col %in% names(cat_inc)) cat_inc[[pbo_col]] <- 0L
cat_inc <- cat_inc |> rename(TRT = !!trt_col, PBO = !!pbo_col)

rows <- list(); section_rows <- integer(0); indent_rows <- integer(0); rid <- 0L
add <- function(label, t, p, sec = FALSE) {
  rid <<- rid + 1L
  rows[[rid]] <<- data.frame(
    Label = label,
    TRT = fmt_n_pct(t, n_trt),
    PBO = fmt_n_pct(p, n_pbo),
    stringsAsFactors = FALSE, check.names = FALSE)
  if (sec) section_rows <<- c(section_rows, rid)
  else     indent_rows  <<- c(indent_rows,  rid)
}

for (cat_lvl in sort(unique(inc$MHCAT))) {
  ct <- cat_inc$TRT[cat_inc$MHCAT == cat_lvl]
  cp <- cat_inc$PBO[cat_inc$MHCAT == cat_lvl]
  add(cat_lvl, ct, cp, sec = TRUE)
  pts <- inc |> filter(MHCAT == cat_lvl)
  for (i in seq_len(nrow(pts))) {
    add(paste0("  ", pts$MHDECOD[i]), pts$TRT[i], pts$PBO[i])
  }
}
if (length(rows) == 0) {
  rows[[1]] <- data.frame(Label = "(no medical history items meeting criteria)",
                           TRT = "0 (0.0)", PBO = "0 (0.0)",
                           stringsAsFactors = FALSE, check.names = FALSE)
}

tbl <- do.call(rbind, rows)
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt),
                arm_label("Placebo + Chemotherapy",   n_pbo))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 4.2)
if (length(section_rows) > 0) ft <- bold_section_ft(ft, section_rows)
if (length(indent_rows)  > 0) ft <- indent_ft(ft, indent_rows, levels = 1)

write_table_all_formats(
  ft, id = "T-MH-01",
  title = "Medical History by Category and Term (≥ 5% in any arm)",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Includes medical history terms with incidence ≥ 5% in either arm.",
    "Category from ADMH.MHCAT ('PRIMARY DIAGNOSIS' = the NSCLC diagnosis; 'MEDICAL HISTORY' = all other conditions).",
    "Term coding is simplified (title-case of verbatim) for the synthetic dataset; real studies should use MedDRA-coded MHDECOD.",
    "Source: datasets/adam/admh.parquet."
  )
)
message(sprintf("T-MH-01 written: %d terms across %d categories",
                length(indent_rows), length(section_rows)))
