# torivumab guidelines loaded
# =============================================================================
# t_ae_06_aesi.R
# T-AE-06 — Adverse Events of Special Interest (AESI) by Category
# =============================================================================
# The synthetic AE coding does not carry a dedicated AESI flag. Per SAP §4.6,
# the AESI list (Protocol §7.4) was deferred. As a stand-in we surface
# AEs in the standard irAE categories (which dominate the AESI list for
# PD-1 inhibitor trials): pneumonitis, colitis, hepatitis, thyroiditis,
# adrenal insufficiency, type-1 diabetes, nephritis, dermatitis.

adsl <- load_adam("adsl") |> filter(SAFFL == "Y")
adae <- load_adam("adae") |> filter(SAFFL == "Y", TRTEMFL == "Y")

AESI_REGEX <- "PNEUMONITIS|COLITIS|HEPATITIS|THYROIDITIS|ADRENAL INSUFFICIENCY|TYPE 1 DIABETES|NEPHRITIS|DERMATITIS|MYOCARDITIS|HYPOPHYSITIS"

adae <- adae |> filter(grepl(AESI_REGEX, toupper(AEDECOD)))

n_trt <- sum(adsl$TRT01A == "Torivumab + Chemotherapy")
n_pbo <- sum(adsl$TRT01A == "Placebo + Chemotherapy")
bld <- build_ae_soc_pt_ft(adae, n_trt, n_pbo, min_pct = 0)

write_table_all_formats(
  bld$ft, id = "T-AE-06",
  title = "Adverse Events of Special Interest (AESI) by Category",
  population = pop_label(nrow(adsl), "SAFFL"),
  notes = c(
    "AESI = pre-specified events of regulatory interest for PD-1 inhibitor class.",
    "Categories captured by pattern match on AEDECOD against: PNEUMONITIS, COLITIS, HEPATITIS, THYROIDITIS, ADRENAL INSUFFICIENCY, TYPE 1 DIABETES, NEPHRITIS, DERMATITIS, MYOCARDITIS, HYPOPHYSITIS.",
    "DATA-LIMITATION NOTE: SAP §4.6 deferred the formal AESI MedDRA PT list pending Protocol §7.4 finalisation; the regex stand-in here is therefore an approximation. Real implementations should use a sponsor-defined AESI codelist.",
    "Source: datasets/adam/adae.parquet WHERE TRTEMFL='Y' AND AEDECOD matches AESI regex."
  )
)
message(sprintf("T-AE-06 written: %d PTs / %d SOCs", bld$n_pts, bld$n_socs))
