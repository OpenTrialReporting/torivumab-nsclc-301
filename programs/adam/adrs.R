# =============================================================================
# Program    : adrs.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADRS — Oncology Response Analysis Dataset
# Spec       : programming-specs/ADRS-spec.md
# Depends on : datasets/adam/adsl.parquet, datasets/adam/adtr.parquet,
#              datasets/sdtm/rs.parquet
# Output     : datasets/adam/adrs.parquet
# Reference  : RECIST 1.1 (Eisenhauer et al., 2009)
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
adtr <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adtr.parquet")))
rs   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "rs.parquet")))

# 2. ADSL merge variables
adsl_vars <- adsl |>
  select(STUDYID, USUBJID, TRTSDT, TRTEDT,
         SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN)

# 3. Overall response (OVR) — per-visit investigator assessments
# Filter to INVESTIGATOR reader (AL-04 fix 2026-05-17: SDTM.RS now also
# carries BICR records; ADRS keeps Investigator-based OVR/BOR/CBOR/ORR to
# preserve established response semantics. BICR is consumed in ADTTE
# directly for PFS only — a future SAP amendment can flip these to BICR.)
ovr <- rs |>
  filter(RSEVAL == "INVESTIGATOR") |>
  filter(!is.na(RSSTRESC), RSSTRESC %in% c("CR", "PR", "SD", "PD", "NE")) |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID")) |>
  mutate(
    ADT     = as.Date(RSDTC),
    ADY     = study_day(ADT, TRTSDT),
    PARAMCD = "OVR",
    PARAM   = "Overall Response by Investigator (RECIST 1.1)",
    AVALC   = RSSTRESC,
    # AVAL = ordinal rank derived from the response code (RS.RSSTRESN dropped —
    # a categorical response has no numeric SDTM result; P21 SD1448)
    AVAL    = dplyr::recode(RSSTRESC, "CR" = 1, "PR" = 2, "SD" = 3,
                            "PD" = 4, "NE" = 5, .default = NA_real_),
    RSPFL   = NA_character_
  )

# 4. Best Overall Response (BOR)
#    SD counts only if >= 8 weeks (ADY >= 57, 1-indexed) from TRTSDT
bor_raw <- ovr |>
  mutate(sd_eligible = AVALC == "SD" & ADY >= 57) |>
  group_by(STUDYID, USUBJID) |>
  summarise(
    best_nonsd  = if (any(AVALC != "SD", na.rm = TRUE))
                    min(AVAL[AVALC != "SD"], na.rm = TRUE)
                  else NA_real_,
    has_elig_sd = any(sd_eligible, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    BOR_AVAL = case_when(
      !is.na(best_nonsd) & best_nonsd <= 3                   ~ best_nonsd,
      has_elig_sd & (is.na(best_nonsd) | best_nonsd > 3)     ~ 3,
      !is.na(best_nonsd)                                      ~ best_nonsd,
      TRUE                                                    ~ 5
    ),
    BOR_AVALC = case_when(
      BOR_AVAL == 1 ~ "CR", BOR_AVAL == 2 ~ "PR",
      BOR_AVAL == 3 ~ "SD", BOR_AVAL == 4 ~ "PD",
      TRUE          ~ "NE"
    )
  )

bor_dates <- ovr |>
  group_by(STUDYID, USUBJID) |>
  slice_min(AVAL, n = 1, with_ties = FALSE) |>
  select(STUDYID, USUBJID, ADT_BOR = ADT)

adrs_bor <- adsl_vars |>
  left_join(bor_raw,   by = c("STUDYID", "USUBJID")) |>
  left_join(bor_dates, by = c("STUDYID", "USUBJID")) |>
  mutate(
    PARAMCD  = "BOR",
    PARAM    = "Best Overall Response (RECIST 1.1)",
    ADT      = ADT_BOR,
    ADY      = study_day(ADT, TRTSDT),
    AVAL     = BOR_AVAL,
    AVALC    = BOR_AVALC,
    RSPFL    = if_else(BOR_AVALC %in% c("CR", "PR"), "Y", "N"),
    VISIT    = NA_character_,
    VISITNUM = NA_integer_
  ) |>
  select(-BOR_AVAL, -BOR_AVALC, -has_elig_sd, -best_nonsd, -ADT_BOR)

# 5. Confirmed Best Overall Response (CBOR)
#    CR/PR: confirming response of equal or better >= 28 days later
#    SD: same 8-week rule; PD: no confirmation needed
confirm_check <- ovr |>
  group_by(STUDYID, USUBJID) |>
  arrange(ADT) |>
  mutate(
    confirmed = mapply(function(aval_i, adt_i) {
      later <- AVALC[ADT >= adt_i + 28 & AVAL <= aval_i]
      length(later) > 0
    }, AVAL, ADT)
  ) |>
  ungroup()

cbor_raw <- confirm_check |>
  filter(
    (AVALC %in% c("CR", "PR") & confirmed) |
    (AVALC == "SD" & ADY >= 57) |
    AVALC == "PD"
  ) |>
  group_by(STUDYID, USUBJID) |>
  slice_min(AVAL, n = 1, with_ties = FALSE) |>
  select(STUDYID, USUBJID, CBOR_AVAL = AVAL, CBOR_AVALC = AVALC, ADT_CBOR = ADT)

adrs_cbor <- adsl_vars |>
  left_join(cbor_raw, by = c("STUDYID", "USUBJID")) |>
  mutate(
    PARAMCD  = "CBOR",
    PARAM    = "Confirmed Best Overall Response (RECIST 1.1)",
    ADT      = ADT_CBOR,
    ADY      = study_day(ADT, TRTSDT),
    AVAL     = if_else(!is.na(CBOR_AVAL), CBOR_AVAL, 5),
    AVALC    = if_else(!is.na(CBOR_AVALC), CBOR_AVALC, "NE"),
    RSPFL    = if_else(!is.na(CBOR_AVALC) & CBOR_AVALC %in% c("CR", "PR"), "Y", "N"),
    VISIT    = NA_character_,
    VISITNUM = NA_integer_
  ) |>
  select(-CBOR_AVAL, -CBOR_AVALC, -ADT_CBOR)

# 6. Stack all ADRS records
#    AVISIT = analysis visit (per-visit OVR records only; BOR/CBOR are
#    subject-level -> AVISIT NA). VISITNUM is dropped: SDTM.RS did not collect
#    it (100% NA), so it aids no traceability; AVISITN carries the ordering.
adrs <- bind_rows(ovr, adrs_bor, adrs_cbor)
# Analysis-visit windowing (SAP §12.2, TUMOUR stream): per-visit response records
# map to their nearest RECIST assessment by ADY; subject-level BOR/CBOR have no
# collected visit and keep AVISIT/AVISITN = NA.
.win <- derive_avisit_windowed(adrs$ADY, adrs$VISIT,
                               rep(NA_integer_, nrow(adrs)), "TUMOUR")
adrs$AVISIT  <- .win$AVISIT
adrs$AVISITN <- .win$AVISITN
adrs$ATPTREF <- .win$ATPTREF
# Shared ANL01FL rule (SAP §12.2), the same logic as ADLB/ADVS/ADTR: one analysis
# record per subject x parameter x analysis visit for the by-visit OVR records,
# and one per subject x parameter for the subject-level BOR/CBOR records.
adrs$ANL01FL <- flag_anl01(adrs, "PARAMCD")
adrs <- adrs |>
  select(
    STUDYID, USUBJID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    PARAM, PARAMCD,
    ADT, ADY,
    AVAL, AVALC,
    RSPFL, ANL01FL,
    VISIT, AVISIT, AVISITN
  ) |>
  arrange(USUBJID, PARAMCD, ADT)

# 7. Write output
write_parquet(adrs, file.path(ADAM_DIR, "adrs.parquet"))
message("ADRS written: ", nrow(adrs), " records")
message("  OVR:  ", sum(adrs$PARAMCD == "OVR",  na.rm = TRUE))
message("  BOR:  ", sum(adrs$PARAMCD == "BOR",  na.rm = TRUE))
message("  CBOR: ", sum(adrs$PARAMCD == "CBOR", na.rm = TRUE))
n_resp <- sum(adrs$PARAMCD == "CBOR" & adrs$RSPFL == "Y" & adrs$ITTFL == "Y",
              na.rm = TRUE)
n_itt  <- sum(adrs$PARAMCD == "CBOR" & adrs$ITTFL == "Y", na.rm = TRUE)
message(sprintf("  ORR (CBOR, ITT): %d / %d (%.1f%%)", n_resp, n_itt,
                100 * n_resp / max(n_itt, 1)))
message("  BOR distribution:")
print(table(adrs$AVALC[adrs$PARAMCD == "BOR"], useNA = "ifany"))
