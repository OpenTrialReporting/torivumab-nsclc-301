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

# 2. Subject-level frame
subj <- adsl |>
  mutate(
    DTHDT    = as.Date(DTHDT),
    TRTSDT   = as.Date(TRTSDT),
    TRTEDT   = as.Date(TRTEDT),
    LSTALVDT = as.Date(LSTALVDT),
    CENSOR_OS = pmax(TRTEDT, LSTALVDT, na.rm = TRUE)
  )

pd_dates <- adrs |>
  filter(PARAMCD == "OVR", AVALC == "PD", !is.na(ADT)) |>
  group_by(STUDYID, USUBJID) |>
  summarise(PDDT = min(as.Date(ADT), na.rm = TRUE), .groups = "drop")

last_assess <- adrs |>
  filter(PARAMCD == "OVR", !is.na(ADT)) |>
  group_by(STUDYID, USUBJID) |>
  summarise(LAST_OVR_DT = max(as.Date(ADT), na.rm = TRUE), .groups = "drop")

first_resp <- adrs |>
  filter(PARAMCD == "CBOR", AVALC %in% c("CR", "PR"), !is.na(ADT)) |>
  select(STUDYID, USUBJID, RSPDT = ADT) |>
  mutate(RSPDT = as.Date(RSPDT))

subj <- subj |>
  left_join(pd_dates,    by = c("STUDYID", "USUBJID")) |>
  left_join(last_assess, by = c("STUDYID", "USUBJID")) |>
  left_join(first_resp,  by = c("STUDYID", "USUBJID"))

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

# 4. Progression-Free Survival (PFS)
adtte_pfs <- subj |>
  mutate(
    PFS_EVENT_DT = pmin(PDDT, DTHDT, na.rm = TRUE),
    PFS_EVENT    = !is.na(PFS_EVENT_DT),
    PARAMCD      = "PFS",
    PARAM        = "Progression-Free Survival",
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
    START_DT = .data[[start_var]],
    AVAL     = as.numeric(as.Date(ADT) - as.Date(START_DT)),
    AVALU    = "DAYS"
  )
}

adtte_os  <- add_aval(adtte_os,  "TRTSDT")
adtte_pfs <- add_aval(adtte_pfs, "TRTSDT")
adtte_dor <- add_aval(adtte_dor, "RSPDT")
adtte_ttr <- add_aval(adtte_ttr, "TRTSDT")

# 8. Stack, flag, select
adtte <- bind_rows(adtte_os, adtte_pfs, adtte_dor, adtte_ttr) |>
  mutate(ANL01FL = "Y") |>
  select(
    STUDYID, USUBJID,
    SAFFL, ITTFL, TRT01P, TRT01A, TRT01PN, TRT01AN,
    TRTSDT, TRTEDT,
    PARAM, PARAMCD,
    ADT, AVAL, AVALU, CNSR,
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
