# =============================================================================
# Program    : pe.R
# Domain     : PE — Physical Examination
# SDTM IG ref: Section 7.3
# Reads from : raw/physical_exam.csv
# Writes to  : datasets/sdtm/pe.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw <- read.csv(file.path(RAW_DIR, "physical_exam.csv"), stringsAsFactors = FALSE)

# VISITNUM mapping
visit_map <- c(
  "SCREENING" = 0L, "SCR" = 0L,
  "C1D1" = 1L, "C1D15" = 2L, "C2D1" = 3L, "C3D1" = 4L,
  "C4D1" = 5L, "C5D1" = 6L, "C6D1" = 7L, "C7D1" = 8L, "C8D1" = 9L,
  "EOT" = 900L, "END OF TREATMENT" = 900L,
  "FU1" = 901L, "FU2" = 902L,
  "FOLLOW-UP 1" = 901L, "FOLLOW-UP 2" = 902L
)

get_visitnum <- function(visit_name) {
  v <- str_to_upper(str_trim(visit_name))
  n <- as.integer(visit_map[v])
  # Unique, complete VISITNUM for visits absent from visit_map (P21 SD0051):
  n[is.na(n) & v == "BASELINE"] <- 0L
  m <- is.na(n) & grepl("^MAINT_C[0-9]+D1$", v)      # maintenance cycles -> 9 + cycle
  n[m] <- 9L + as.integer(sub("D1$", "", sub("^MAINT_C", "", v[m])))
  w <- is.na(n) & grepl("ASSESS_WK[0-9]+$", v)       # tumour assessments -> week number
  n[w] <- as.integer(sub("^.*WK", "", v[w]))
  as.integer(n)
}

# Derive PETESTCD from BODY_SYSTEM (max 8 chars, uppercase, no spaces)
derive_testcd <- function(body_sys) {
  s <- str_to_upper(str_replace_all(str_trim(body_sys), "[^A-Z0-9]", ""))
  str_sub(s, 1, 8)
}

raw <- raw |>
  mutate(
    USUBJID  = paste(STUDYID, SUBJECT_ID,
                     sep = "-"),
    PETESTCD = derive_testcd(BODY_SYSTEM),
    PETEST   = str_to_upper(str_trim(BODY_SYSTEM)),
    PEORRES  = paste(str_trim(FINDING),
                     ifelse(is.na(FINDING_DETAIL) | str_trim(FINDING_DETAIL) == "",
                            "", paste0(" - ", str_trim(FINDING_DETAIL))),
                     sep = ""),
    # PENORM: "Y" if finding indicates normal
    PENORM   = case_when(
      str_to_upper(str_trim(FINDING)) %in%
        c("NORMAL", "WITHIN NORMAL LIMITS", "WNL", "NO ABNORMALITY DETECTED",
          "NAD", "UNREMARKABLE") ~ "Y",
      TRUE ~ NA_character_
    ),
    # PESTRESC: standardized result (P21 SD0057) — normal/abnormal in std format.
    PESTRESC = ifelse(PENORM == "Y" & !is.na(PENORM), "NORMAL", "ABNORMAL"),
    # PECLSIG: clinically significant flag
    PECLSIG  = case_when(
      str_detect(str_to_upper(str_trim(FINDING)), "CLINICALLY SIGNIFICANT") ~ "Y",
      PENORM == "Y" ~ "N",
      TRUE ~ NA_character_
    ),
    PEDTC    = as.character(VISIT_DATE),
    VISIT    = str_to_upper(str_trim(VISIT_NAME)),
    VISITNUM = get_visitnum(VISIT_NAME)
  ) |>
  arrange(USUBJID, PEDTC, PETESTCD) |>
  group_by(USUBJID) |>
  mutate(PESEQ = row_number()) |>
  ungroup()

sdtm_pe <- raw |>
  # PENORM (not in PE model — SD0058) dropped; normal/abnormal is carried in
  # PEORRES. PECLSIG (clinically significant) retained as a permissible qualifier.
  transmute(
    STUDYID,
    DOMAIN   = "PE",
    USUBJID,
    PESEQ,
    PETESTCD,
    PETEST,
    PEORRES,
    PESTRESC,
    PECLSIG,
    PEDTC,
    VISITNUM,
    VISIT
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_pe, file.path(OUT_DIR, "pe.parquet"))
message("PE written: ", nrow(sdtm_pe), " records")
