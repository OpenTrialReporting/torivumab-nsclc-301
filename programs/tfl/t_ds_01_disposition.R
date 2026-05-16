# torivumab guidelines loaded
# =============================================================================
# t_ds_01_disposition.R
# T-DS-01 — Subject Disposition
# Population: All randomised (ITT)
# Source: ADSL + SDTM.DS
# Estimand: descriptive
# =============================================================================

adsl <- load_adam("adsl")
ds   <- as.data.frame(read_parquet("datasets/sdtm/ds.parquet"))

itt <- adsl |> filter(ITTFL == "Y")
counts <- adsl_arm_counts(itt, "ITTFL")

# Map ARM for joining DS records to arm
arm_lookup <- adsl |> select(USUBJID, TRT01P)
ds_arm     <- ds |> left_join(arm_lookup, by = "USUBJID")

# Helper: count subjects with at least one DSDECOD matching predicate, per arm
n_by_arm <- function(filter_expr) {
  flt <- ds_arm |> filter(!!enquo(filter_expr))
  list(
    trt = n_distinct(flt$USUBJID[flt$TRT01P == "Torivumab + Chemotherapy"]),
    pbo = n_distinct(flt$USUBJID[flt$TRT01P == "Placebo + Chemotherapy"]),
    tot = n_distinct(flt$USUBJID)
  )
}

# Discontinuation reasons (DS records other than the RANDOMIZED/IC anchors)
disc_reasons <- c("PROGRESSIVE DISEASE", "ADVERSE EVENT",
                  "WITHDRAWAL BY SUBJECT", "PHYSICIAN DECISION", "OTHER")

# Build counts
n_rand   <- list(trt = counts$n_trt, pbo = counts$n_pbo, tot = counts$n_tot)
n_treat  <- list(
  trt = sum(itt$SAFFL == "Y" & itt$TRT01P == "Torivumab + Chemotherapy"),
  pbo = sum(itt$SAFFL == "Y" & itt$TRT01P == "Placebo + Chemotherapy"),
  tot = sum(itt$SAFFL == "Y")
)
n_pp <- list(
  trt = sum(itt$PPROTFL == "Y" & itt$TRT01P == "Torivumab + Chemotherapy"),
  pbo = sum(itt$PPROTFL == "Y" & itt$TRT01P == "Placebo + Chemotherapy"),
  tot = sum(itt$PPROTFL == "Y")
)
n_compl  <- n_by_arm(DSDECOD == "COMPLETED")
n_disc_total <- n_by_arm(DSDECOD %in% disc_reasons)
n_disc_pd    <- n_by_arm(DSDECOD == "PROGRESSIVE DISEASE")
n_disc_ae    <- n_by_arm(DSDECOD == "ADVERSE EVENT")
n_disc_with  <- n_by_arm(DSDECOD == "WITHDRAWAL BY SUBJECT")
n_disc_phy   <- n_by_arm(DSDECOD == "PHYSICIAN DECISION")
n_disc_oth   <- n_by_arm(DSDECOD == "OTHER")
n_death  <- list(
  trt = sum(itt$DTHFL == "Y" & itt$TRT01P == "Torivumab + Chemotherapy"),
  pbo = sum(itt$DTHFL == "Y" & itt$TRT01P == "Placebo + Chemotherapy"),
  tot = sum(itt$DTHFL == "Y")
)

rows <- list()
add_row <- function(label, vals_or_n) {
  if (is.list(vals_or_n)) {
    rows[[length(rows) + 1]] <<- data.frame(
      Label = label,
      TRT = fmt_n_pct(vals_or_n$trt, counts$n_trt),
      PBO = fmt_n_pct(vals_or_n$pbo, counts$n_pbo),
      TOT = fmt_n_pct(vals_or_n$tot, counts$n_tot),
      stringsAsFactors = FALSE, check.names = FALSE
    )
  } else {
    rows[[length(rows) + 1]] <<- data.frame(
      Label = label,
      TRT = "", PBO = "", TOT = "",
      stringsAsFactors = FALSE, check.names = FALSE
    )
  }
}

add_row("Subjects randomised (ITT)", n_rand)
add_row("Subjects treated (Safety population)", n_treat)
add_row("Per-Protocol population", n_pp)
add_row("Treatment status", NULL)
add_row("  Completed treatment per protocol", n_compl)
add_row("  Discontinued treatment", n_disc_total)
add_row("    Progressive disease", n_disc_pd)
add_row("    Adverse event", n_disc_ae)
add_row("    Withdrawal by subject", n_disc_with)
add_row("    Physician decision", n_disc_phy)
add_row("    Other", n_disc_oth)
add_row("Vital status", NULL)
add_row("  Died on study", n_death)

tbl <- do.call(rbind, rows)
section_rows <- which(tbl$Label %in% c("Treatment status", "Vital status"))
indent1_rows <- which(tbl$Label %in% c("  Completed treatment per protocol",
                                         "  Discontinued treatment",
                                         "  Died on study"))
indent2_rows <- which(grepl("^    ", tbl$Label))

names(tbl) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.2)
ft <- ft |> bold_section_ft(section_rows)
ft <- ft |> indent_ft(indent1_rows, levels = 1)
ft <- ft |> indent_ft(indent2_rows, levels = 2)

write_table_all_formats(
  ft,
  id         = "T-DS-01",
  title      = "Subject Disposition",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Percentages based on ITT N per arm.",
    "Discontinuation reasons from SDTM.DS (DSDECOD).",
    "A subject may appear in only one discontinuation category (first reason).",
    "Source: datasets/adam/adsl.parquet, datasets/sdtm/ds.parquet"
  )
)
message(sprintf("T-DS-01 written: %d completed, %d discontinued, %d deaths",
                n_compl$tot, n_disc_total$tot, n_death$tot))
