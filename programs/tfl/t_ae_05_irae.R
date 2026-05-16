# torivumab guidelines loaded
# =============================================================================
# t_ae_05_irae.R
# T-AE-05 — Immune-Related Adverse Events by Category (SOC) and PT
# =============================================================================

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y", IRAEFL == "Y")

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")
bld <- build_ae_soc_pt_ft(adae, n_trt, n_pbo, min_pct = 0)

write_table_all_formats(
  bld$ft, id = "T-AE-05",
  title = "Immune-Related Adverse Events by Category",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "Immune-related = ADAE.IRAEFL='Y' (derived from SDTM.AE.AECAT='IMMUNE-RELATED').",
    "Category here corresponds to SOC; refinement to dedicated irAE categories (e.g. pneumonitis / colitis / hepatitis / thyroiditis) would require a sponsor-defined IRAECAT codelist that is not yet derived in ADAE.",
    "Source: datasets/adam/adae.parquet WHERE TRTEMFL='Y' AND IRAEFL='Y'."
  )
)
message(sprintf("T-AE-05 written: %d PTs / %d SOCs", bld$n_pts, bld$n_socs))
