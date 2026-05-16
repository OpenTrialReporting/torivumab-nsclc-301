# torivumab guidelines loaded
# =============================================================================
# t_ae_06_aesi.R
# T-AE-06 — Adverse Events of Special Interest (AESI) by Category
# =============================================================================
# AL-08 closure (2026-05-17): sponsor AESI list is now driven by a versioned
# MedDRA PT codelist at raw/codelists/aesi_meddra_pts.csv (Protocol §7.4).
# Each PT carries an AESICAT (sponsor category) and a grade rule
# (always-AESI vs grade>=3 only). Rows here are grouped by AESICAT instead
# of by SOC, matching the SAP §13.4 supportive-safety estimand E4.

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y")

aesi_pts <- read.csv("raw/codelists/aesi_meddra_pts.csv",
                     stringsAsFactors = FALSE) |>
  mutate(
    MEDDRA_PT_U = toupper(trimws(MEDDRA_PT)),
    GRADE_RULE  = ifelse(grepl("Grade>=3 only", COMMENT, fixed = TRUE), "G3+",
                  ifelse(grepl("Grade>=2",       COMMENT, fixed = TRUE), "G2+",
                                                                          "ANY"))
  )

# Map ADAE PTs -> AESI categories
adae$AEDECOD_U <- toupper(trimws(adae$AEDECOD))
adae_aesi <- adae |>
  inner_join(
    aesi_pts |> select(MEDDRA_PT_U, AESICAT, AESI_GROUP, GRADE_RULE),
    by = c("AEDECOD_U" = "MEDDRA_PT_U"),
    relationship = "many-to-many"
  ) |>
  # Apply grade rule (AESEV: MILD/MODERATE/SEVERE/LIFE-THREATENING/FATAL ↔ G1..G5)
  mutate(
    GRADE_NUM = case_when(
      toupper(AESEV) %in% c("MILD",              "GRADE 1") ~ 1L,
      toupper(AESEV) %in% c("MODERATE",          "GRADE 2") ~ 2L,
      toupper(AESEV) %in% c("SEVERE",            "GRADE 3") ~ 3L,
      toupper(AESEV) %in% c("LIFE THREATENING",
                           "LIFE-THREATENING",  "GRADE 4") ~ 4L,
      toupper(AESEV) %in% c("FATAL",             "GRADE 5") ~ 5L,
      TRUE                                                  ~ NA_integer_
    )
  ) |>
  filter(
    GRADE_RULE == "ANY" |
      (GRADE_RULE == "G2+" & GRADE_NUM >= 2) |
      (GRADE_RULE == "G3+" & GRADE_NUM >= 3)
  )

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

# Subject-level counts per AESICAT
cat_counts <- adae_aesi |>
  distinct(AESICAT, USUBJID, TRT01A) |>
  group_by(AESICAT) |>
  summarise(
    n_trt_cat = sum(TRT01A == "Torivumab + Chemotherapy"),
    n_pbo_cat = sum(TRT01A == "Placebo + Chemotherapy"),
    .groups = "drop"
  ) |>
  arrange(desc(n_trt_cat + n_pbo_cat))

# Any-AESI overall row
any_aesi <- adae_aesi |> distinct(USUBJID, TRT01A)
row_any <- data.frame(
  Label = "Any AESI",
  TRT   = fmt_n_pct(sum(any_aesi$TRT01A == "Torivumab + Chemotherapy"), n_trt),
  PBO   = fmt_n_pct(sum(any_aesi$TRT01A == "Placebo + Chemotherapy"),   n_pbo),
  stringsAsFactors = FALSE, check.names = FALSE
)

rows_cat <- cat_counts |>
  transmute(
    Label = paste0("  ", tools::toTitleCase(tolower(AESICAT))),
    TRT   = fmt_n_pct(n_trt_cat, n_trt),
    PBO   = fmt_n_pct(n_pbo_cat, n_pbo)
  )

tbl <- rbind(row_any, as.data.frame(rows_cat))
names(tbl) <- c(" ",
                arm_label("Torivumab + Chemotherapy", n_trt),
                arm_label("Placebo + Chemotherapy",   n_pbo))

ft <- flextable(tbl) |> tfl_theme_ft(col1_w = 3.8)
ft <- bold(ft, i = 1, part = "body")

write_table_all_formats(
  ft, id = "T-AE-06",
  title = "Adverse Events of Special Interest (AESI) by Category",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "AESI = pre-specified events of regulatory interest for the PD-1 inhibitor class (Protocol §7.4).",
    sprintf("Categories driven by sponsor AESI MedDRA codelist (raw/codelists/aesi_meddra_pts.csv; %d PTs across %d categories).",
            nrow(aesi_pts), length(unique(aesi_pts$AESICAT))),
    "Grade rule per PT: most PTs are AESI at any grade; selected lab/symptom PTs require Grade>=3 (e.g. ALT/AST, AKI, rash, diarrhoea, pruritus); IRR requires Grade>=2.",
    "A subject is counted once per category regardless of multiple occurrences.",
    "Source: datasets/adam/adae.parquet WHERE TRTEMFL='Y' INNER JOIN raw/codelists/aesi_meddra_pts.csv."
  )
)
message(sprintf("T-AE-06 written: %d AESI categories, %d AEs flagged",
                nrow(cat_counts), nrow(adae_aesi)))
