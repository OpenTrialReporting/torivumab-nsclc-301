# torivumab guidelines loaded
# =============================================================================
# t_vs_02_weight_shift.R
# T-VS-02 — Weight change categories (baseline → worst post-baseline %change)
# Population: Safety
# Source: ADVS PARAMCD='WEIGHT'
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
advs <- load_adam("advs") |>
  filter(SAFFL == "Y", PARAMCD == "WEIGHT", !is.na(PCHG))

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Most-extreme (lowest, indicating loss) PCHG per subject
worst <- advs |>
  filter(is.na(ABLFL) | ABLFL != "Y") |>
  group_by(USUBJID, TRT01A) |>
  summarise(worst_pchg = min(PCHG, na.rm = TRUE), .groups = "drop")

categorise <- function(pchg) {
  case_when(
    pchg <= -20            ~ "Loss ≥ 20%",
    pchg >  -20 & pchg <= -10 ~ "Loss 10% to 20%",
    pchg >  -10 & pchg <  -5  ~ "Loss 5% to 10%",
    pchg >=  -5 & pchg <=  5  ~ "No significant change (±5%)",
    pchg >    5 & pchg <  10  ~ "Gain 5% to 10%",
    pchg >=  10 & pchg <  20  ~ "Gain 10% to 20%",
    pchg >=  20             ~ "Gain ≥ 20%",
    TRUE                     ~ "Unknown"
  )
}
worst <- worst |> mutate(category = categorise(worst_pchg))

denom_trt <- sum(worst$TRT01A == "Torivumab + Chemotherapy")
denom_pbo <- sum(worst$TRT01A == "Placebo + Chemotherapy")

CATEGORIES <- c("Loss ≥ 20%", "Loss 10% to 20%", "Loss 5% to 10%",
                "No significant change (±5%)",
                "Gain 5% to 10%", "Gain 10% to 20%", "Gain ≥ 20%")

rows <- data.frame(
  Label = CATEGORIES,
  TRT   = sapply(CATEGORIES, function(c)
    fmt_n_pct(sum(worst$category == c & worst$TRT01A == "Torivumab + Chemotherapy"),
              denom_trt)),
  PBO   = sapply(CATEGORIES, function(c)
    fmt_n_pct(sum(worst$category == c & worst$TRT01A == "Placebo + Chemotherapy"),
              denom_pbo)),
  stringsAsFactors = FALSE, check.names = FALSE
)
names(rows) <- c("Weight change category (worst on-treatment)",
                 arm_label("Torivumab + Chemotherapy", denom_trt),
                 arm_label("Placebo + Chemotherapy",   denom_pbo))

ft <- flextable(rows) |> tfl_theme_ft(col1_w = 3.6)

write_table_all_formats(
  ft, id = "T-VS-02",
  title = "Weight Change Categories — Worst On-Treatment Percent Change",
  population = sprintf("Safety Population with ≥1 post-baseline weight (N=%d)",
                       nrow(worst)),
  notes = c(
    "Categories applied to per-subject worst (most extreme) post-baseline % change in weight.",
    "Denominators = subjects with at least one post-baseline weight measurement per arm.",
    "Source: datasets/adam/advs.parquet WHERE PARAMCD='WEIGHT'."
  )
)
message(sprintf("T-VS-02 written: %d subjects categorised", nrow(worst)))
