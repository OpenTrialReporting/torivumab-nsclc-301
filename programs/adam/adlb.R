# =============================================================================
# Program    : adlb.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADLB — Laboratory Test Results BDS
# Spec       : programming-specs/ADLB-spec.md
# Depends on : datasets/adam/adsl.parquet, datasets/sdtm/lb.parquet
# Output     : datasets/adam/adlb.parquet
# =============================================================================

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr)
  library(lubridate)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
dir.create(ADAM_DIR, showWarnings = FALSE, recursive = TRUE)

# 1. Read inputs
adsl <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adsl.parquet")))
lb   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "lb.parquet")))

# 2. Merge ADSL onto LB
adsl_vars <- adsl |>
  select(STUDYID, USUBJID, SUBJID, SITEID,
         TRTSDT, TRTEDT, SAFFL, ITTFL,
         TRT01P, TRT01A, TRT01PN, TRT01AN)

adlb <- lb |>
  left_join(adsl_vars, by = c("STUDYID", "USUBJID"))

# 3. Analysis date and study day
adlb <- adlb |>
  mutate(
    ADT = as.Date(LBDTC),
    ADY = as.integer(ADT - TRTSDT) + 1L
  )

# 4. Analysis variables
adlb <- adlb |>
  mutate(
    PARAMCD = LBTESTCD,
    PARAM   = LBTEST,
    AVAL    = as.numeric(LBSTRESN),
    AVALC   = as.character(LBORRES),
    AVALU   = LBSTRESU,
    ANRLO   = as.numeric(LBSTNRLO),
    ANRHI   = as.numeric(LBSTNRHI),
    NRIND   = LBNRIND
  )

# 5. Baseline flag (ABLFL) — last non-missing AVAL on or before TRTSDT
adlb <- adlb |>
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      new_var = ABLFL,
      by_vars = exprs(STUDYID, USUBJID, PARAMCD),
      order   = exprs(ADT, LBSEQ),
      mode    = "last"
    ),
    filter = !is.na(AVAL) & ADT <= TRTSDT
  )

# 6. Baseline value, change, percent change
adlb <- adlb |>
  derive_var_base(
    by_vars    = exprs(STUDYID, USUBJID, PARAMCD),
    source_var = AVAL,
    new_var    = BASE
  ) |>
  derive_var_chg() |>
  derive_var_pchg()

# 7. Analysis flags
adlb <- adlb |>
  mutate(
    ANL01FL = if_else(!is.na(AVAL) & ADT > TRTSDT & SAFFL == "Y",
                      "Y", NA_character_),
    DTYPE   = NA_character_
  )

# 8. CTCAE toxicity grading — NCI CTCAE v5.0
adlb <- adlb |>
  mutate(
    ATOXGR = case_when(
      PARAMCD %in% c("ALT", "AST") & !is.na(AVAL) & !is.na(ANRHI) ~ case_when(
        AVAL <= ANRHI        ~ "0",
        AVAL <= 3  * ANRHI   ~ "1",
        AVAL <= 5  * ANRHI   ~ "2",
        AVAL <= 20 * ANRHI   ~ "3",
        TRUE                 ~ "4"
      ),
      PARAMCD == "BILI" & !is.na(AVAL) & !is.na(ANRHI) ~ case_when(
        AVAL <= ANRHI        ~ "0",
        AVAL <= 1.5 * ANRHI  ~ "1",
        AVAL <= 3   * ANRHI  ~ "2",
        AVAL <= 10  * ANRHI  ~ "3",
        TRUE                 ~ "4"
      ),
      PARAMCD == "HGB" & !is.na(AVAL) & !is.na(ANRLO) ~ case_when(
        AVAL >= ANRLO  ~ "0",
        AVAL >= 100    ~ "1",
        AVAL >= 80     ~ "2",
        AVAL >= 65     ~ "3",
        TRUE           ~ "4"
      ),
      PARAMCD == "NEUT" & !is.na(AVAL) & !is.na(ANRLO) ~ case_when(
        AVAL >= ANRLO  ~ "0",
        AVAL >= 1.5    ~ "1",
        AVAL >= 1.0    ~ "2",
        AVAL >= 0.5    ~ "3",
        TRUE           ~ "4"
      ),
      PARAMCD == "CREAT" & !is.na(AVAL) & !is.na(ANRHI) ~ case_when(
        AVAL <= ANRHI        ~ "0",
        AVAL <= 1.5 * ANRHI  ~ "1",
        AVAL <= 3   * ANRHI  ~ "2",
        AVAL <= 6   * ANRHI  ~ "3",
        TRUE                 ~ "4"
      ),
      TRUE ~ NA_character_
    ),
    ATOXGRN = suppressWarnings(as.integer(ATOXGR))
  )

# 9. Select final variables
adlb <- adlb |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    LBSEQ, PARAM, PARAMCD, LBCAT,
    LBDTC, ADT, ADY,
    AVAL, AVALC, AVALU, ANRLO, ANRHI, NRIND,
    ABLFL, BASE, CHG, PCHG,
    ATOXGR, ATOXGRN,
    ANL01FL, DTYPE,
    VISIT, VISITNUM
  ) |>
  arrange(USUBJID, PARAMCD, ADT, LBSEQ)

# 10. Write output
write_parquet(adlb, file.path(ADAM_DIR, "adlb.parquet"))
message("ADLB written: ", nrow(adlb), " records")
message("  Parameters: ", paste(sort(unique(adlb$PARAMCD)), collapse = ", "))
message("  Subjects:   ", n_distinct(adlb$USUBJID))
