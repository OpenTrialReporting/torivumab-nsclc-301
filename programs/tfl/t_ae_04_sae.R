# torivumab guidelines loaded
# =============================================================================
# t_ae_04_sae.R
# T-AE-04 — Serious Adverse Events by SOC and PT
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y", AESER == "Y")

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")
bld <- build_ae_soc_pt_ft(adae, n_trt, n_pbo, min_pct = 0)

write_table_all_formats(
  bld$ft, id = "T-AE-04",
  title = "Serious Adverse Events by SOC and PT",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Serious = ADAE.AESER='Y' (sub-criteria: death, hospitalisation, life-threatening, disability, congenital anomaly, other medically important).",
    "All SAE PTs included (no incidence cutoff).",
    "Source: datasets/adam/adae.parquet WHERE TRTEMFL='Y' AND AESER='Y'."
  )
)
message(sprintf("T-AE-04 written: %d PTs / %d SOCs", bld$n_pts, bld$n_socs))
