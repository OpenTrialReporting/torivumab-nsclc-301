# torivumab guidelines loaded
# =============================================================================
# t_dv_01_deviations.R
# T-DV-01 — Protocol Deviations Detail (replaces a sparser T-DS-02 view)
# Population: ITT
# Source: ADDV
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y")
addv <- load_adam("addv")
counts <- adsl_arm_counts(adsl, "ITTFL")

n_arm <- function(filter_expr) {
  flt <- addv |> filter(!!enquo(filter_expr))
  list(
    trt = n_distinct(flt$USUBJID[flt$TRT01P == "Torivumab + Chemotherapy"]),
    pbo = n_distinct(flt$USUBJID[flt$TRT01P == "Placebo + Chemotherapy"]),
    tot = n_distinct(flt$USUBJID)
  )
}

n_major  <- n_arm(DVCAT == "MAJOR")
n_minor  <- n_arm(DVCAT == "MINOR")

# Detailed breakdown by DVDECOD (standardised deviation term)
scats <- unique(addv$DVDECOD[!is.na(addv$DVDECOD)])
scat_rows <- lapply(scats, function(s) {
  n <- n_arm(DVDECOD == s)
  data.frame(Label = paste0("  ", s),
             TRT = fmt_n_pct(n$trt, counts$n_trt),
             PBO = fmt_n_pct(n$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE)
})

rows <- rbind(
  data.frame(Label = "Severity",   TRT = "", PBO = "", TOT = "",
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "  Major deviations",
             TRT = fmt_n_pct(n_major$trt, counts$n_trt),
             PBO = fmt_n_pct(n_major$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n_major$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "  Minor deviations",
             TRT = fmt_n_pct(n_minor$trt, counts$n_trt),
             PBO = fmt_n_pct(n_minor$pbo, counts$n_pbo),
             TOT = fmt_n_pct(n_minor$tot, counts$n_tot),
             stringsAsFactors = FALSE, check.names = FALSE),
  data.frame(Label = "Subcategory (major)", TRT = "", PBO = "", TOT = "",
             stringsAsFactors = FALSE, check.names = FALSE)
)
rows <- rbind(rows, do.call(rbind, scat_rows))
names(rows) <- c(" ",
                 arm_label("Torivumab + Chemotherapy", counts$n_trt),
                 arm_label("Placebo + Chemotherapy",   counts$n_pbo),
                 arm_label("Total",                    counts$n_tot))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)
ft <- bold_section_ft(ft, c(1, 4))
ft <- indent_ft(ft, c(2, 3, 5:nrow(rows)), levels = 1)

write_table_all_formats(
  ft, id = "T-DV-01",
  title = "Protocol Deviations — Detail",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes = c(
    "Detailed view of ADDV records with severity and subcategory breakdown.",
    "Synthetic-data note: only one record exists (randomised-never-dosed placebo subject) because the simulator does not generate SDTM.DV.",
    "Source: datasets/adam/addv.parquet."
  )
)
message(sprintf("T-DV-01 written: %d major / %d minor deviations",
                n_major$tot, n_minor$tot))
