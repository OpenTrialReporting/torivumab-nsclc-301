# =============================================================================
# Program    : adtr.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADTR — Tumor Results BDS
# Spec       : programming-specs/ADTR-spec.md
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/tr.parquet,
#              datasets/sdtm/tu.parquet
# Output     : datasets/adam/adtr.parquet
# =============================================================================

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr)
  library(lubridate)
  library(arrow)
})

source(file.path("programs", "adam", "_visit_utils.R"))

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
dir.create(ADAM_DIR, showWarnings = FALSE, recursive = TRUE)

# 1. Read inputs
adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
tr   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "tr.parquet")))
tu   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "tu.parquet")))

# 2. Merge ADSL onto TR
adsl_vars <- adsl |>
  select(STUDYID, USUBJID, TRTSDT, TRTEDT,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN)

tr_merged <- tr |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(ADT = as.Date(TRDTC))

# 3. Target lesion diameter records (LDIAM)
tr_ldiam <- tr_merged |>
  filter(TRTESTCD == "LDIAM", TRGRPID == "TARGET", !is.na(TRSTRESN))

# 4. Sum of Longest Diameters (SLD) per subject / visit / date — PARAMCD = "SDIAM"
adtr_sdiam <- tr_ldiam |>
  group_by(STUDYID, USUBJID, VISIT, VISITNUM, ADT, TRTSDT, TRTEDT,
           SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN) |>
  summarise(
    AVAL  = sum(TRSTRESN, na.rm = TRUE),
    N_TGT = n(),
    .groups = "drop"
  ) |>
  mutate(
    PARAMCD = "SDIAM",
    PARAM   = "Sum of Longest Diameters (mm)",
    AVALU   = "mm"
  )

# 5. Individual lesion diameter records — PARAMCD = "LDIAM"
adtr_ldiam <- tr_ldiam |>
  mutate(
    PARAMCD = "LDIAM",
    PARAM   = "Longest Diameter (mm)",
    AVALU   = "mm",
    AVAL    = TRSTRESN,
    LNKID   = TRLNKID
  ) |>
  select(STUDYID, USUBJID, VISIT, VISITNUM, ADT, TRTSDT, TRTEDT,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
         PARAMCD, PARAM, AVALU, AVAL, LNKID)

# 6. Combine and add study day
adtr <- bind_rows(
  adtr_sdiam |> mutate(LNKID = NA_character_),   # N_TGT preserved from summarise
  adtr_ldiam |> mutate(N_TGT = NA_integer_)
) |>
  mutate(ADY = study_day(ADT, TRTSDT))

# 7. Baseline flag (ABLFL)
#    Baseline = last non-missing, non-zero AVAL on or before TRTSDT
adtr <- adtr |>
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      new_var = ABLFL,
      by_vars = exprs(STUDYID, USUBJID, PARAMCD, LNKID),
      order   = exprs(ADT),
      mode    = "last"
    ),
    # Baseline only on SDIAM (the analysis parameter, one row per subject/visit)
    # — not per-lesion LDIAM, which would give multiple baselines per
    # USUBJID/PARAMCD (P21 AD0154). LDIAM change is not analysed.
    filter = PARAMCD == "SDIAM" & !is.na(AVAL) & AVAL > 0 & ADT <= TRTSDT
  )

# 8. Baseline value (BASE), change (CHG), percent change (PCHG)
adtr <- adtr |>
  derive_var_base(
    by_vars    = exprs(STUDYID, USUBJID, PARAMCD, LNKID),
    source_var = AVAL,
    new_var    = BASE
  ) |>
  derive_var_chg() |>
  derive_var_pchg()

# 9. Nadir SLD (minimum post-baseline SDIAM per subject)
nadir_tbl <- adtr |>
  filter(PARAMCD == "SDIAM", ADT > TRTSDT, !is.na(AVAL)) |>
  group_by(STUDYID, USUBJID) |>
  summarise(NADIR = min(AVAL, na.rm = TRUE), .groups = "drop")

adtr <- adtr |>
  left_join(nadir_tbl, by = c("STUDYID", "USUBJID"))

# 10. Analysis flag
adtr <- adtr |>
  mutate(
    ANL01FL = if_else(
      PARAMCD == "SDIAM" & !is.na(AVAL) & ADT > TRTSDT & SAFFL == "Y",
      "Y", NA_character_
    )
  )

# 11. Select final variables
#    AVISIT = analysis visit (BASELINE / TUMOR_ASSESS_WKn). VISITNUM is dropped:
#    SDTM.TR did not collect it (100% NA); AVISITN carries the numeric ordering.
# Analysis-visit windowing (SAP §12.2, TUMOUR stream): tumour-result records map
# to their nearest RECIST assessment by ADY. BASELINE/TUMOR_ASSESS_WKn reproduce
# their nominal week (no windowing dups); ANL01FL is unchanged.
.win <- derive_avisit_windowed(adtr$ADY, adtr$VISIT,
                               rep(NA_integer_, nrow(adtr)), "TUMOUR")
adtr$AVISIT  <- .win$AVISIT
adtr$AVISITN <- .win$AVISITN
adtr <- adtr |>
  select(
    STUDYID, USUBJID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    PARAM, PARAMCD, AVALU,
    VISIT, AVISIT, AVISITN, ADT, ADY,
    AVAL, BASE, CHG, PCHG, NADIR,
    ABLFL, ANL01FL,
    LNKID, N_TGT
  ) |>
  arrange(USUBJID, PARAMCD, LNKID, AVISITN, ADT)

# 12. Write output
write_parquet(adtr, file.path(ADAM_DIR, "adtr.parquet"))
message("ADTR written: ", nrow(adtr), " records")
message("  SDIAM records: ", sum(adtr$PARAMCD == "SDIAM", na.rm = TRUE))
message("  LDIAM records: ", sum(adtr$PARAMCD == "LDIAM", na.rm = TRUE))
message("  Subjects with baseline SLD: ",
        sum(adtr$PARAMCD == "SDIAM" & !is.na(adtr$ABLFL) & adtr$ABLFL == "Y",
            na.rm = TRUE))
