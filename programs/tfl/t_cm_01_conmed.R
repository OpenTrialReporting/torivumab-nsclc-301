# torivumab guidelines loaded
# =============================================================================
# t_cm_01_conmed.R
# T-CM-01 — Concomitant Medications by ATC class and Preferred Term (≥5%)
# Population: Safety
# Source: ADCM (ONTRTFL='Y')
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adcm <- load_adam("adcm") |> filter(SAFFL == "Y", ONTRTFL == "Y")

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Top-level grouping: ATC code level 1 (first character: e.g. "A", "B", "C"...)
# In our codelist CMINDC carries the human-readable class/indication.
inc <- adcm |>
  filter(!is.na(CMDECOD)) |>
  mutate(ATC_CLASS = ifelse(is.na(CMINDC) | CMINDC == "", "Other / Unclassified",
                              CMINDC)) |>
  group_by(ATC_CLASS, CMDECOD, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)

# Rename arm cols robustly
trt_col <- "Torivumab + Chemotherapy"
pbo_col <- "Placebo + Chemotherapy"
if (!trt_col %in% names(inc)) inc[[trt_col]] <- 0L
if (!pbo_col %in% names(inc)) inc[[pbo_col]] <- 0L
inc <- inc |>
  rename(TRT = !!trt_col, PBO = !!pbo_col) |>
  mutate(pct_trt = 100 * TRT / n_trt,
          pct_pbo = 100 * PBO / n_pbo,
          max_pct = pmax(pct_trt, pct_pbo)) |>
  filter(max_pct >= 5) |>
  arrange(ATC_CLASS, desc(max_pct))

class_inc <- adcm |>
  mutate(ATC_CLASS = ifelse(is.na(CMINDC) | CMINDC == "", "Other / Unclassified",
                              CMINDC)) |>
  group_by(ATC_CLASS, TRT01A) |>
  summarise(n = n_distinct(USUBJID), .groups = "drop") |>
  tidyr::pivot_wider(names_from = TRT01A, values_from = n, values_fill = 0)
if (!trt_col %in% names(class_inc)) class_inc[[trt_col]] <- 0L
if (!pbo_col %in% names(class_inc)) class_inc[[pbo_col]] <- 0L
class_inc <- class_inc |> rename(TRT = !!trt_col, PBO = !!pbo_col)

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

for (cls in sort(unique(inc$ATC_CLASS))) {
  ct <- class_inc$TRT[class_inc$ATC_CLASS == cls]
  cp <- class_inc$PBO[class_inc$ATC_CLASS == cls]
  add(cls, ct, cp, sec = TRUE)
  pts <- inc |> filter(ATC_CLASS == cls)
  for (i in seq_len(nrow(pts))) {
    add(paste0("  ", pts$CMDECOD[i]), pts$TRT[i], pts$PBO[i])
  }
}
if (length(rows) == 0) {
  rows[[1]] <- data.frame(Label = "(no concomitant medications meeting criteria)",
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
  ft, id = "T-CM-01",
  title = "Concomitant Medications by Indication Class and Preferred Term (≥5%)",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Includes preferred terms with on-treatment incidence ≥ 5% in either arm.",
    "Class grouping uses ADCM.CMINDC (curated indication class from the ATC lookup).",
    "On-treatment = ADCM.ONTRTFL='Y' (medication period overlaps TRTSDT..TRTEDT).",
    "Source: datasets/adam/adcm.parquet WHERE ONTRTFL='Y'."
  )
)
message(sprintf("T-CM-01 written: %d PTs across %d classes",
                length(indent_rows), length(section_rows)))
