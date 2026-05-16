# torivumab guidelines loaded
# =============================================================================
# t_dm_01_demographics.R
# T-DM-01 — Demographic and Baseline Characteristics
# Population: ITT
# Source: ADSL
# Estimand reference: descriptive (no SAP estimand ID)
# =============================================================================

adsl <- load_adam("adsl") |>
  filter(ITTFL == "Y")

# Region derivation from COUNTRY
adsl <- adsl |>
  mutate(REGION = case_when(
    COUNTRY %in% c("UNITED STATES", "CANADA")                           ~ "North America",
    COUNTRY %in% c("GERMANY", "FRANCE", "UNITED KINGDOM", "SPAIN",
                    "ITALY", "NETHERLANDS", "POLAND")                   ~ "Europe",
    COUNTRY %in% c("JAPAN", "SOUTH KOREA", "AUSTRALIA")                 ~ "Asia-Pacific",
    COUNTRY == "BRAZIL"                                                 ~ "South America",
    TRUE                                                                ~ "Other"
  ))

counts <- adsl_arm_counts(adsl, "ITTFL")

# Build one summary helper per category
summarise_cont <- function(d, var) {
  v <- d[[var]]
  c(
    n            = sum(!is.na(v)),
    mean         = mean(v, na.rm = TRUE),
    sd           = sd(v,   na.rm = TRUE),
    median       = median(v, na.rm = TRUE),
    min          = min(v,    na.rm = TRUE),
    max          = max(v,    na.rm = TRUE)
  )
}
arm_split <- function(var_fn) {
  list(
    trt = var_fn(adsl |> filter(TRT01P == "Torivumab + Chemotherapy")),
    pbo = var_fn(adsl |> filter(TRT01P == "Placebo + Chemotherapy")),
    tot = var_fn(adsl)
  )
}

# Age block
age_stats <- arm_split(function(d) summarise_cont(d, "AGE"))
age_lt65  <- arm_split(function(d) sum(d$AGEGR1 == "<65"))
age_ge65  <- arm_split(function(d) sum(d$AGEGR1 == ">=65"))

# Category-level helper: returns named list of n by arm for the given category levels
cat_arm <- function(var, lvl) {
  list(
    trt = sum(adsl[[var]][adsl$TRT01P == "Torivumab + Chemotherapy"] == lvl, na.rm = TRUE),
    pbo = sum(adsl[[var]][adsl$TRT01P == "Placebo + Chemotherapy"]    == lvl, na.rm = TRUE),
    tot = sum(adsl[[var]] == lvl, na.rm = TRUE)
  )
}

# Build the row labels + value vectors
rows <- list()
add_row <- function(label, vt, vp, vto) {
  rows[[length(rows) + 1]] <<- data.frame(
    Label = label, TRT = vt, PBO = vp, TOT = vto,
    stringsAsFactors = FALSE, check.names = FALSE
  )
}

# Section: Age
add_row("Age (years)", "", "", "")
add_row("  n",            as.character(age_stats$trt["n"]),
                          as.character(age_stats$pbo["n"]),
                          as.character(age_stats$tot["n"]))
add_row("  Mean (SD)",    fmt_mean_sd(age_stats$trt["mean"], age_stats$trt["sd"]),
                          fmt_mean_sd(age_stats$pbo["mean"], age_stats$pbo["sd"]),
                          fmt_mean_sd(age_stats$tot["mean"], age_stats$tot["sd"]))
add_row("  Median (Min, Max)",
        fmt_med_range(age_stats$trt["median"], age_stats$trt["min"], age_stats$trt["max"]),
        fmt_med_range(age_stats$pbo["median"], age_stats$pbo["min"], age_stats$pbo["max"]),
        fmt_med_range(age_stats$tot["median"], age_stats$tot["min"], age_stats$tot["max"]))
add_row("  < 65, n (%)",  fmt_n_pct(age_lt65$trt, counts$n_trt),
                          fmt_n_pct(age_lt65$pbo, counts$n_pbo),
                          fmt_n_pct(age_lt65$tot, counts$n_tot))
add_row("  ≥ 65, n (%)",  fmt_n_pct(age_ge65$trt, counts$n_trt),
                          fmt_n_pct(age_ge65$pbo, counts$n_pbo),
                          fmt_n_pct(age_ge65$tot, counts$n_tot))

# Section: Sex
add_row("Sex", "", "", "")
for (lvl in c("FEMALE", "MALE")) {
  vals <- cat_arm("SEX", lvl)
  add_row(paste0("  ", tools::toTitleCase(tolower(lvl)), ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Section: Race
add_row("Race", "", "", "")
race_levels <- c("WHITE", "ASIAN", "BLACK OR AFRICAN AMERICAN",
                  "AMERICAN INDIAN OR ALASKA NATIVE", "OTHER", "UNKNOWN")
for (lvl in race_levels) {
  vals <- cat_arm("RACE", lvl)
  add_row(paste0("  ", tools::toTitleCase(tolower(lvl)), ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Section: Region
add_row("Region", "", "", "")
for (lvl in c("North America", "Europe", "Asia-Pacific", "South America")) {
  vals <- cat_arm("REGION", lvl)
  add_row(paste0("  ", lvl, ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Section: Histology
add_row("Histology", "", "", "")
for (lvl in c("Non-squamous", "Squamous")) {
  vals <- cat_arm("HISTCAT", lvl)
  add_row(paste0("  ", lvl, ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Section: ECOG
add_row("ECOG performance status at baseline", "", "", "")
for (lvl in c(0, 1, 2)) {
  vals <- cat_arm("ECOG", lvl)
  add_row(paste0("  ", lvl, ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Section: PD-L1
add_row("PD-L1 TPS category", "", "", "")
for (lvl in c("High >=50%", "Medium 1-49%", "Low <1%")) {
  vals <- cat_arm("PDL1CAT", lvl)
  add_row(paste0("  ", lvl, ", n (%)"),
          fmt_n_pct(vals$trt, counts$n_trt),
          fmt_n_pct(vals$pbo, counts$n_pbo),
          fmt_n_pct(vals$tot, counts$n_tot))
}

# Stack all rows into the final data frame
tbl <- do.call(rbind, rows)
section_rows <- which(tbl$Label %in%
  c("Age (years)", "Sex", "Race", "Region", "Histology",
    "ECOG performance status at baseline", "PD-L1 TPS category"))
indent_rows  <- setdiff(seq_len(nrow(tbl)), section_rows)

# Set column names with N
names(tbl) <- c(
  "Characteristic",
  arm_label("Torivumab + Chemotherapy", counts$n_trt),
  arm_label("Placebo + Chemotherapy",   counts$n_pbo),
  arm_label("Total",                    counts$n_tot)
)

# Build the flextable
ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.0)
ft <- ft |> indent_ft(indent_rows, levels = 1) |> bold_section_ft(section_rows)

# Write all three formats
write_table_all_formats(
  ft,
  id = "T-DM-01",
  title      = "Demographic and Baseline Characteristics",
  population = pop_label(counts$n_tot, "ITTFL"),
  notes      = c(
    "Percentages based on the number of subjects in each arm with non-missing data.",
    "Region derived from COUNTRY (NA: US/Canada; EU: 7 European countries; APAC: Japan/Korea/Australia; SA: Brazil).",
    "PD-L1 TPS category from ADSL.PDL1CAT.",
    "Source: datasets/adam/adsl.parquet"
  )
)
message(sprintf("T-DM-01 written (%d rows, %d arms)", nrow(tbl), ncol(tbl) - 1))
