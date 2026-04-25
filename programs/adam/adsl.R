# =============================================================================
# Program    : adsl.R
# Study      : SIMULATED-TORIVUMAB-2026 (CTX-NSCLC-301)
# Dataset    : ADSL — Subject-Level Analysis Dataset
# Spec       : programming-specs/ADSL-spec.md
# Depends on : datasets/sdtm/dm.parquet, ds.parquet, ex.parquet,
#              suppdm.parquet, dd.parquet
# Output     : datasets/adam/adsl.parquet
# Run via    : programs/adam/00_run_adam.R
# =============================================================================

suppressPackageStartupMessages({
  library(admiral)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(arrow)
})

SDTM_DIR <- file.path("datasets", "sdtm")
ADAM_DIR <- file.path("datasets", "adam")
dir.create(ADAM_DIR, showWarnings = FALSE, recursive = TRUE)

# 1. Read SDTM inputs
dm     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dm.parquet")))
ds     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ds.parquet")))
ex     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "ex.parquet")))
suppdm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "suppdm.parquet")))
dd     <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dd.parquet")))

# 2. SUPPDM — pivot to wide
suppdm_wide <- suppdm |>
  filter(QNAM %in% c("ECOGBSL", "PDL1SCR", "PDL1GRP", "HISTSCAT")) |>
  pivot_wider(
    id_cols     = c(STUDYID, USUBJID),
    names_from  = QNAM,
    values_from = QVAL
  )

# 3. Treatment dates from EX
ex_doses <- ex |>
  filter(!is.na(EXDOSE) & as.numeric(EXDOSE) > 0) |>
  mutate(EXSTDT = as.Date(EXSTDTC), EXENDT = as.Date(EXENDTC))

trts <- ex_doses |>
  group_by(STUDYID, USUBJID) |>
  summarise(TRTSDT = min(EXSTDT, na.rm = TRUE),
            TRTEDT = max(EXENDT, na.rm = TRUE), .groups = "drop")

# 4. Death date from DD
dd_death <- dd |>
  filter(!is.na(DDDTC) & nchar(trimws(DDDTC)) >= 10) |>
  mutate(DTHDT = as.Date(DDDTC)) |>
  group_by(STUDYID, USUBJID) |>
  summarise(DTHDT = min(DTHDT, na.rm = TRUE), .groups = "drop")

# 5. Last alive date from DS
ds_last <- ds |>
  filter(DSCAT == "DISPOSITION EVENT", !is.na(DSSTDTC)) |>
  mutate(DS_DT = as.Date(DSSTDTC)) |>
  group_by(STUDYID, USUBJID) |>
  summarise(LSTALVDT = max(DS_DT, na.rm = TRUE), .groups = "drop")

# 6. Build ADSL
adsl <- dm |>
  left_join(suppdm_wide, by = c("STUDYID", "USUBJID")) |>
  left_join(trts,        by = c("STUDYID", "USUBJID")) |>
  left_join(dd_death,    by = c("STUDYID", "USUBJID")) |>
  left_join(ds_last,     by = c("STUDYID", "USUBJID")) |>
  mutate(
    RANDDT  = as.Date(RFSTDTC),
    ICDT    = as.Date(RFICDTC),
    TRTDURD = as.integer(TRTEDT - TRTSDT) + 1L,
    AGEGR1  = case_when(
      AGE < 65  ~ "<65",
      AGE >= 65 ~ ">=65",
      TRUE      ~ NA_character_
    ),
    TRT01P  = ARM,
    TRT01A  = ACTARM,
    TRT01PN = case_when(
      ARM == "Torivumab + Chemotherapy" ~ 1L,
      ARM == "Placebo + Chemotherapy"   ~ 2L,
      TRUE                              ~ NA_integer_
    ),
    TRT01AN = TRT01PN,
    ITTFL   = if_else(is.na(ARMNRS) | ARMNRS != "SCREEN FAILURE", "Y", "N"),
    SAFFL   = if_else(!is.na(TRTSDT), "Y", "N"),
    PPROTFL = if_else(!is.na(TRTSDT), "Y", "N"),
    DTHFL   = if_else(!is.na(DTHDT), "Y", "N"),
    ECOG    = as.integer(ECOGBSL),
    PDL1CAT = PDL1GRP,
    PDL1SCR = as.numeric(PDL1SCR),
    HISTCAT = HISTSCAT
  )

# 7. Select final variables
adsl <- adsl |>
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    AGE, AGEGR1, AGEU, SEX, RACE, ETHNIC, COUNTRY,
    ARM, ACTARM, TRT01P, TRT01A, TRT01PN, TRT01AN,
    ICDT, RANDDT, TRTSDT, TRTEDT, TRTDURD,
    ITTFL, SAFFL, PPROTFL,
    DTHFL, DTHDT, LSTALVDT,
    ECOG, PDL1CAT, PDL1SCR, HISTCAT
  ) |>
  arrange(USUBJID)

# 8. Write output
write_parquet(adsl, file.path(ADAM_DIR, "adsl.parquet"))
message("ADSL written: ", nrow(adsl), " subjects")
message("  ITTFL=Y: ", sum(adsl$ITTFL == "Y", na.rm = TRUE))
message("  SAFFL=Y: ", sum(adsl$SAFFL == "Y", na.rm = TRUE))
message("  DTHFL=Y: ", sum(adsl$DTHFL == "Y", na.rm = TRUE))
message("  TRT01P table:")
print(table(adsl$TRT01P, useNA = "ifany"))
