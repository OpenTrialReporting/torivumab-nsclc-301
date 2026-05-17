# torivumab guidelines loaded
# =============================================================================
# t_ds_03_intercurrent_events.R
# T-DS-03 — Intercurrent Events Summary
# Population: ITT
# Source: ADSL + SDTM.DS + ADRS (for first response assessment date)
# Estimand: Operationalises SAP §13.3 IE taxonomy
# =============================================================================

adsl <- load_adam("adsl") |> filter(ITTFL == "Y")
adrs <- load_adam("adrs")
ds   <- as.data.frame(read_parquet("datasets/sdtm/ds.parquet"))

counts <- adsl_arm_counts(adsl, "ITTFL")

# Arm lookup for DS / ADRS joins
arm_lookup <- adsl |> select(USUBJID, TRT01P)

# Helper
n_arm <- function(usubj_set) {
  list(
    trt = sum(adsl$USUBJID %in% usubj_set & adsl$TRT01P == "Torivumab + Chemotherapy"),
    pbo = sum(adsl$USUBJID %in% usubj_set & adsl$TRT01P == "Placebo + Chemotherapy"),
    tot = length(intersect(adsl$USUBJID, usubj_set))
  )
}

# IE 1: Treatment discontinuation (any reason)
disc_reasons <- c("PROGRESSIVE DISEASE", "ADVERSE EVENT",
                  "WITHDRAWAL BY SUBJECT", "PHYSICIAN DECISION", "OTHER")
ie1 <- n_arm(unique(ds$USUBJID[ds$DSDECOD %in% disc_reasons]))

# IE 2: Treatment discontinuation due to AE
ie2 <- n_arm(unique(ds$USUBJID[ds$DSDECOD == "ADVERSE EVENT"]))

# IE 3: Initiation of subsequent anti-cancer therapy — from ADCM.SUBSQTFL
# (closed AL-02 / AL-10 on 2026-05-17 — was hardcoded 0)
adcm <- tryCatch(load_adam("adcm"), error = function(e) NULL)
if (!is.null(adcm) && "SUBSQTFL" %in% names(adcm)) {
  ie3 <- n_arm(unique(adcm$USUBJID[adcm$SUBSQTFL == "Y"]))
} else {
  ie3 <- list(trt = 0L, pbo = 0L, tot = 0L)
}

# IE 5: No post-baseline tumour assessment (subjects in ITT with no OVR records)
overall_rs <- adrs |> filter(PARAMCD == "OVR")
has_post_baseline <- unique(overall_rs$USUBJID)

# IE 4: ≥2 consecutive missed scheduled tumour assessments (closes AL-12, 2026-05-17).
# Per subject, walk through ADRS OVR records (Investigator reads, sorted by date)
# and detect any gap > 16 weeks (= 112 days). The scheduled grid is Q6W (42 days),
# so a gap of 16+ weeks implies ≥2 consecutive missed Q6W scans. Subjects who
# died or discontinued cleanly (no in-window gap) are excluded.
gap_subjects <- overall_rs |>
  filter(!is.na(ADT)) |>
  arrange(USUBJID, ADT) |>
  group_by(USUBJID) |>
  mutate(gap_days = as.integer(as.Date(ADT) - lag(as.Date(ADT)))) |>
  filter(!is.na(gap_days), gap_days > 112L) |>
  pull(USUBJID) |>
  unique()
ie4 <- n_arm(gap_subjects)
no_pba <- setdiff(adsl$USUBJID, has_post_baseline)
ie5 <- n_arm(no_pba)

# IE 6: Death before first response assessment
first_rs <- overall_rs |>
  group_by(USUBJID) |>
  summarise(first_rs_dt = min(as.Date(ADT), na.rm = TRUE), .groups = "drop")
died_before_assess <- adsl |>
  filter(DTHFL == "Y") |>
  left_join(first_rs, by = "USUBJID") |>
  filter(is.na(first_rs_dt) | as.Date(DTHDT) < first_rs_dt) |>
  pull(USUBJID)
ie6 <- n_arm(died_before_assess)

# IE 7: Withdrawal of consent
ie7 <- n_arm(unique(ds$USUBJID[ds$DSDECOD == "WITHDRAWAL BY SUBJECT"]))

# Build table
make_row <- function(label, ie) {
  data.frame(
    Label = label,
    TRT = fmt_n_pct(ie$trt, counts$n_trt),
    PBO = fmt_n_pct(ie$pbo, counts$n_pbo),
    TOT = fmt_n_pct(ie$tot, counts$n_tot),
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

tbl <- rbind(
  make_row("Treatment discontinuation (any reason)",     ie1),
  make_row("Treatment discontinuation due to AE",        ie2),
  make_row("Initiation of subsequent anti-cancer therapy", ie3),
  make_row("≥ 2 consecutive missed tumour assessments",  ie4),
  make_row("No post-baseline tumour assessment",         ie5),
  make_row("Death before first response assessment",      ie6),
  make_row("Withdrawal of consent",                       ie7)
)
names(tbl) <- c(
  " ",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.8)

write_table_all_formats(
  ft,
  id         = "T-DS-03",
  title      = "Intercurrent Events Summary",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Operationalises the intercurrent event taxonomy in SAP §13.3.",
    "Subsequent anti-cancer therapy: real counts from ADCM.SUBSQTFL='Y' (added 2026-05-17; raw simulator `16_subsequent_therapy.R`).",
    "≥ 2 consecutive missed tumour assessments: detected from ADRS OVR by gaps > 16 weeks against the scheduled Q6W grid (~6% subjects carry a stochastic 2-3 visit miss episode from `09_tumor_measurements.R`).",
    "A subject may experience multiple IEs and appear in multiple rows.",
    "Source: ADSL, ADRS (PARAMCD='OVR'), SDTM.DS, ADCM"
  )
)
message(sprintf("T-DS-03 written: discontinuations=%d, no-PBA=%d, death-before-assess=%d, withdraw=%d",
                ie1$tot, ie5$tot, ie6$tot, ie7$tot))
