# torivumab guidelines loaded
# =============================================================================
# t_ae_03_g3_plus.R
# T-AE-03 — Grade ≥ 3 Treatment-Emergent AEs by SOC and PT
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y", AETOXGRN >= 3)

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")

bld <- build_ae_soc_pt_ft(adae, n_trt, n_pbo, min_pct = 0)

write_table_all_formats(
  bld$ft, id = "T-AE-03",
  title = "Grade ≥ 3 Treatment-Emergent Adverse Events by SOC and PT",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Includes all PTs with at least one Grade ≥ 3 TEAE in either arm (no incidence cutoff).",
    "Grade per CTCAE v5.0 (ADAE.AETOXGRN ≥ 3 = Grade 3 / 4 / 5).",
    "Source: datasets/adam/adae.parquet WHERE TRTEMFL='Y' AND AETOXGRN >= 3."
  )
)
message(sprintf("T-AE-03 written: %d PTs / %d SOCs", bld$n_pts, bld$n_socs))
