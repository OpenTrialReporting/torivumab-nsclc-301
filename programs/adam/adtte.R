# =============================================================================
# Program    : adtte.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADTTE — Time-to-Event Analysis Dataset
# Spec       : programming-specs/ADTTE-spec.md
# Depends on : datasets/adam/adsl.parquet, datasets/adam/adrs.parquet,
#              datasets/sdtm/ds.parquet, datasets/sdtm/dd.parquet
# Output     : datasets/adam/adtte.parquet
# Run via    : programs/adam/00_run_adam.R (last, after adrs.R)
# Reference  : FDA 2018 censoring guidance; SAP section 4
# Parameters : OS, PFS, DOR, TTR
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
adrs <- as.data.frame(read_parquet(file.path(ADAM_DIR, "adrs.parquet")))
ds   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ds.parquet")))
dd   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dd.parquet")))
rs   <- as.data.frame(read_parquet(file.path(SDTM_DIR, "rs.parquet")))

# 2. Subject-level frame
subj <- adsl |>
  mutate(
    DTHDT    = as.Date(DTHDT),
    TRTSDT   = as.Date(TRTSDT),
    TRTEDT   = as.Date(TRTEDT),
    LSTALVDT = as.Date(LSTALVDT),
    CENSOR_OS = pmax(TRTEDT, LSTALVDT, na.rm = TRUE)
  )

# Reader-stratified PD-date derivation (AL-04/AL-07 closure 2026-05-17)
# Primary PFS uses BICR (SAP §13.5 estimand E2); PFSINV uses Investigator.
pd_dates_by_eval <- function(eval_label) {
  rs |>
    filter(RSEVAL == eval_label, RSSTRESC == "PD", !is.na(RSDTC)) |>
    group_by(STUDYID, USUBJID) |>
    summarise(PDDT = min(as.Date(RSDTC), na.rm = TRUE), .groups = "drop")
}
last_assess_by_eval <- function(eval_label) {
  rs |>
    filter(RSEVAL == eval_label, !is.na(RSDTC)) |>
    group_by(STUDYID, USUBJID) |>
    summarise(LAST_OVR_DT = max(as.Date(RSDTC), na.rm = TRUE), .groups = "drop")
}

pd_bicr <- pd_dates_by_eval("INDEPENDENT ASSESSOR")
pd_inv  <- pd_dates_by_eval("INVESTIGATOR")
last_bicr <- last_assess_by_eval("INDEPENDENT ASSESSOR")
last_inv  <- last_assess_by_eval("INVESTIGATOR")

# Subject-level join (PFS uses BICR PD dates → PDDT)
pd_dates    <- pd_bicr                                       # alias for PFS primary
last_assess <- last_bicr

first_resp <- adrs |>
  filter(PARAMCD == "CBOR", AVALC %in% c("CR", "PR"), !is.na(ADT)) |>
  select(STUDYID, USUBJID, RSPDT = ADT) |>
  mutate(RSPDT = as.Date(RSPDT))

subj <- subj |>
  left_join(pd_dates,    by = c("STUDYID", "USUBJID")) |>
  left_join(last_assess, by = c("STUDYID", "USUBJID")) |>
  left_join(first_resp,  by = c("STUDYID", "USUBJID"))

# Separate subject-level frame for PFSINV (Investigator PD dates)
subj_inv <- adsl |>
  mutate(
    DTHDT    = as.Date(DTHDT),
    TRTSDT   = as.Date(TRTSDT),
    TRTEDT   = as.Date(TRTEDT),
    LSTALVDT = as.Date(LSTALVDT),
    CENSOR_OS = pmax(TRTEDT, LSTALVDT, na.rm = TRUE)
  ) |>
  left_join(pd_inv,    by = c("STUDYID", "USUBJID")) |>
  left_join(last_inv,  by = c("STUDYID", "USUBJID"))

# 3. Overall Survival (OS)
adtte_os <- subj |>
  mutate(
    PARAMCD  = "OS",
    PARAM    = "Overall Survival",
    CNSR     = if_else(DTHFL == "Y", 0L, 1L),
    ADT      = if_else(DTHFL == "Y", DTHDT, CENSOR_OS),
    EVNTDESC = if_else(DTHFL == "Y", "DEATH", "CENSORED - LAST KNOWN ALIVE"),
    SRCDOM   = if_else(DTHFL == "Y", "DD", "ADSL")
  )

# 3b. Overall Survival — While-on-Treatment (OSWOT) sensitivity estimand E1b
#
# Censoring rule per SAP §13.4: censor at min(start of subsequent anti-cancer
# therapy, TRTEDT + 30 days). AL-02 closed 2026-05-17 — subsequent therapy is
# now captured via ADCM.SUBSQTFL='Y', so we pull the earliest subsequent-
# therapy start date per subject and include it in the censoring pmin.
#
# Event = death occurring on or within 30 days of last study treatment
#         (AND before any subsequent therapy starts).
# Censored = at min(TRTEDT + 30, subsequent therapy start, LSTALVDT).
adcm_path <- file.path(ADAM_DIR, "adcm.parquet")
if (file.exists(adcm_path)) {
  adcm     <- as.data.frame(read_parquet(adcm_path))
  subseq_dt <- adcm |>
    filter(SUBSQTFL == "Y", !is.na(ASTDT)) |>
    group_by(USUBJID) |>
    summarise(SUBSQTDT = min(as.Date(ASTDT), na.rm = TRUE), .groups = "drop")
} else {
  subseq_dt <- data.frame(USUBJID = character(0), SUBSQTDT = as.Date(character(0)))
}

adtte_oswot <- subj |>
  left_join(subseq_dt, by = "USUBJID") |>
  mutate(
    OSWOT_CUT     = TRTEDT + 30,
    # Take pmin of the three censoring candidates (TRTEDT+30, subseq tx, last alive)
    OSWOT_CENSOR  = pmin(OSWOT_CUT, SUBSQTDT, LSTALVDT, na.rm = TRUE),
    # Event only if death precedes BOTH TRTEDT+30 AND subseq tx start
    death_in_window = DTHFL == "Y" & !is.na(DTHDT) &
                       DTHDT <= OSWOT_CUT &
                       (is.na(SUBSQTDT) | DTHDT <= SUBSQTDT),
    OSWOT_EVENT   = death_in_window,
    PARAMCD       = "OSWOT",
    PARAM         = "Overall Survival - While-on-Treatment Sensitivity",
    CNSR          = if_else(OSWOT_EVENT, 0L, 1L),
    ADT           = if_else(OSWOT_EVENT, DTHDT, OSWOT_CENSOR),
    EVNTDESC      = case_when(
      OSWOT_EVENT                                ~ "DEATH ON/WITHIN 30D OF LAST DOSE",
      !is.na(SUBSQTDT) & OSWOT_CENSOR == SUBSQTDT ~ "CENSORED - SUBSEQUENT ANTI-CANCER THERAPY",
      !is.na(LSTALVDT) & LSTALVDT < OSWOT_CUT    ~ "CENSORED - LOST BEFORE TRTEDT+30D",
      TRUE                                       ~ "CENSORED - ALIVE AT TRTEDT+30D"
    ),
    SRCDOM        = if_else(OSWOT_EVENT, "DD", "ADSL")
  ) |>
  select(-OSWOT_CUT, -OSWOT_CENSOR, -OSWOT_EVENT, -death_in_window, -SUBSQTDT)

# 4. Progression-Free Survival (PFS) — BICR (primary) per SAP §13.5 / E2
adtte_pfs <- subj |>
  mutate(
    PFS_EVENT_DT = pmin(PDDT, DTHDT, na.rm = TRUE),
    PFS_EVENT    = !is.na(PFS_EVENT_DT),
    PARAMCD      = "PFS",
    PARAM        = "Progression-Free Survival (BICR)",
    CNSR         = if_else(PFS_EVENT, 0L, 1L),
    ADT          = if_else(PFS_EVENT,
                           PFS_EVENT_DT,
                           coalesce(LAST_OVR_DT, CENSOR_OS)),
    EVNTDESC     = case_when(
      !is.na(PDDT) & (is.na(DTHDT) | PDDT <= DTHDT) ~ "PROGRESSIVE DISEASE",
      !is.na(DTHDT)                                  ~ "DEATH",
      TRUE                                           ~ "CENSORED - LAST TUMOUR ASSESSMENT"
    ),
    SRCDOM = case_when(
      EVNTDESC == "PROGRESSIVE DISEASE" ~ "ADRS",
      EVNTDESC == "DEATH"               ~ "DD",
      TRUE                              ~ "ADRS"
    )
  ) |>
  select(-PFS_EVENT_DT, -PFS_EVENT)

# 4b. PFS by Investigator — sensitivity per SAP §13.5 / E2a (AL-04/07 closure)
adtte_pfsinv <- subj_inv |>
  mutate(
    PFS_EVENT_DT = pmin(PDDT, DTHDT, na.rm = TRUE),
    PFS_EVENT    = !is.na(PFS_EVENT_DT),
    PARAMCD      = "PFSINV",
    PARAM        = "Progression-Free Survival (Investigator)",
    CNSR         = if_else(PFS_EVENT, 0L, 1L),
    ADT          = if_else(PFS_EVENT,
                           PFS_EVENT_DT,
                           coalesce(LAST_OVR_DT, CENSOR_OS)),
    EVNTDESC     = case_when(
      !is.na(PDDT) & (is.na(DTHDT) | PDDT <= DTHDT) ~ "PROGRESSIVE DISEASE",
      !is.na(DTHDT)                                  ~ "DEATH",
      TRUE                                           ~ "CENSORED - LAST TUMOUR ASSESSMENT"
    ),
    SRCDOM = case_when(
      EVNTDESC == "PROGRESSIVE DISEASE" ~ "RS-INV",
      EVNTDESC == "DEATH"               ~ "DD",
      TRUE                              ~ "RS-INV"
    )
  ) |>
  select(-PFS_EVENT_DT, -PFS_EVENT)

# 5. Duration of Response (DOR) — confirmed responders only
adtte_dor <- subj |>
  filter(!is.na(RSPDT)) |>
  mutate(
    DOR_EVENT_DT = pmin(
      if_else(!is.na(PDDT)  & PDDT  > RSPDT, PDDT,  as.Date(NA)),
      if_else(!is.na(DTHDT) & DTHDT > RSPDT, DTHDT, as.Date(NA)),
      na.rm = TRUE
    ),
    DOR_EVENT = !is.na(DOR_EVENT_DT),
    PARAMCD   = "DOR",
    PARAM     = "Duration of Response",
    CNSR      = if_else(DOR_EVENT, 0L, 1L),
    ADT       = if_else(DOR_EVENT,
                        DOR_EVENT_DT,
                        coalesce(LAST_OVR_DT, CENSOR_OS)),
    EVNTDESC  = case_when(
      !is.na(PDDT) & PDDT > RSPDT &
        (is.na(DTHDT) | PDDT <= DTHDT) ~ "PROGRESSIVE DISEASE",
      !is.na(DTHDT) & DTHDT > RSPDT    ~ "DEATH",
      TRUE                              ~ "CENSORED"
    ),
    SRCDOM = case_when(
      EVNTDESC == "PROGRESSIVE DISEASE" ~ "ADRS",
      EVNTDESC == "DEATH"               ~ "DD",
      TRUE                              ~ "ADRS"
    )
  ) |>
  select(-DOR_EVENT_DT, -DOR_EVENT)

# 6. Time to Response (TTR) — ITT population
adtte_ttr <- subj |>
  mutate(
    TTR_EVENT = !is.na(RSPDT),
    PARAMCD   = "TTR",
    PARAM     = "Time to Response",
    CNSR      = if_else(TTR_EVENT, 0L, 1L),
    ADT       = if_else(TTR_EVENT,
                        RSPDT,
                        coalesce(LAST_OVR_DT, CENSOR_OS)),
    EVNTDESC  = if_else(TTR_EVENT, "CONFIRMED RESPONSE", "CENSORED - NO RESPONSE"),
    SRCDOM    = "ADRS"
  ) |>
  select(-TTR_EVENT)

# 7. AVAL: days from start to event/censor
add_aval <- function(dat, start_var) {
  dat |> mutate(
    STARTDT  = as.Date(.data[[start_var]]),   # time-to-event origin (P21 AD0245)
    AVAL     = as.numeric(as.Date(ADT) - STARTDT),
    AVALU    = "DAYS"
  )
}

adtte_os    <- add_aval(adtte_os,    "TRTSDT")
adtte_oswot <- add_aval(adtte_oswot, "TRTSDT")
adtte_pfs    <- add_aval(adtte_pfs,    "TRTSDT")
adtte_pfsinv <- add_aval(adtte_pfsinv, "TRTSDT")
adtte_dor   <- add_aval(adtte_dor,   "RSPDT")
adtte_ttr   <- add_aval(adtte_ttr,   "TRTSDT")

# 8. Stack, flag, select
adtte <- bind_rows(adtte_os, adtte_oswot, adtte_pfs, adtte_pfsinv,
                     adtte_dor, adtte_ttr) |>
  # ANL01FL (SAP §12.2): records in this dataset's analysis population.
  # Time-to-event endpoints are analysed on the ITT population.
  mutate(ANL01FL = if_else(ITTFL == "Y", "Y", NA_character_)) |>
  select(
    STUDYID, USUBJID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    PARAM, PARAMCD,
    STARTDT, ADT, AVAL, AVALU, CNSR,
    EVNTDESC, SRCDOM,
    ANL01FL
  ) |>
  arrange(USUBJID, PARAMCD)

# 9. Write output
write_parquet(adtte, file.path(ADAM_DIR, "adtte.parquet"))
message("ADTTE written: ", nrow(adtte), " records across ",
        n_distinct(adtte$PARAMCD), " parameters")
for (pc in sort(unique(adtte$PARAMCD))) {
  sub      <- adtte[adtte$PARAMCD == pc, ]
  n_evt    <- sum(sub$CNSR == 0, na.rm = TRUE)
  med_days <- median(sub$AVAL, na.rm = TRUE)
  message(sprintf("  %-5s  n=%d  events=%d (%.0f%%)  median=%.0f days",
                  pc, nrow(sub), n_evt,
                  100 * n_evt / nrow(sub), med_days))
}
