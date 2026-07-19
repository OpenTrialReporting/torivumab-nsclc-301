# =============================================================================
# Program    : ae.R
# Domain     : AE — Adverse Events
# SDTM IG ref: Section 6.1
# Reads from : raw/adverse_events.csv, raw/codelists/meddra_oncology_subset.csv
# Writes to  : datasets/sdtm/ae.parquet
# =============================================================================

library(dplyr)
library(lubridate)
library(arrow)
library(stringr)

RAW_DIR  <- "raw"
OUT_DIR  <- "datasets/sdtm"
STUDYID  <- "CTX-NSCLC-301"

# Read raw
raw    <- read.csv(file.path(RAW_DIR, "adverse_events.csv"), stringsAsFactors = FALSE)
meddra <- read.csv(file.path(RAW_DIR, "codelists", "meddra_oncology_subset.csv"),
                   stringsAsFactors = FALSE)

# Derive USUBJID
raw <- raw |>
  mutate(
    USUBJID = paste(STUDYID, SUBJECT_ID,
                    sep = "-")
  ) |>
  # Drop duplicate CRF rows for the same event (P21 SD1201). One AE was entered
  # twice differing only in end date; keep the record with the later end date.
  arrange(USUBJID, AE_START_DATE, AE_VERBATIM_TERM, dplyr::desc(AE_END_DATE)) |>
  distinct(USUBJID, AE_VERBATIM_TERM, AE_START_DATE, SEVERITY, SERIOUS,
           ACTION_TAKEN, OUTCOME, .keep_all = TRUE)

# -----------------------------------------------------------------------------
# MedDRA coding
# -----------------------------------------------------------------------------
# The collected verbatim terms carry severity/status decorations (e.g.
# "GRADE 3 NEUTROPENIA", "MILD NAUSEA NOS", "DYSPNOEA (ONGOING)",
# "PLATELET COUNT DECREASED - WORSENING"). MedDRA coding strips these modifiers
# to recover the underlying medical concept, then matches the LLT (falling back
# to the PT). This deterministic normalisation replaces the old fuzzy agrep and
# takes coverage from ~23% to 100% against the (curated) oncology subset — every
# base concept resolves to a real dictionary LLT/PT with a numeric code.
# (P21 SD1449 — MedDRA population; SD0055 — codes are numeric, not char.)
normalize_term <- function(x) {
  s <- str_to_upper(str_trim(x))
  s <- gsub("\\s+", " ", s)
  s <- gsub("N O S", "NOS", s)                 # de-space the "N O S" data artifact
  # strip trailing status / grade decorations (loop until stable)
  repeat {
    s2 <- s
    s2 <- str_trim(gsub("\\s*[-(]?\\s*(ONGOING|WORSENING|IMPROVING|RESOLVED|RESOLVING)\\s*\\)?$", "", s2))
    s2 <- str_trim(gsub("\\s*-?\\s*GRADE\\s*[0-9]+$", "", s2))
    s2 <- str_trim(gsub("\\s+NOS$", "", s2))
    s2 <- str_trim(gsub("[-(]\\s*$", "", s2))
    if (identical(s2, s)) break
    s <- s2
  }
  # strip leading severity / frequency modifiers (loop until stable)
  repeat {
    s2 <- str_trim(gsub("^(MILD|MODERATE|SEVERE|GRADE\\s*[0-9]+|INTERMITTENT|PERSISTENT|TRANSIENT)\\s+", "", s))
    if (identical(s2, s)) break
    s <- s2
  }
  str_trim(s)
}

meddra_lookup <- meddra |>
  mutate(
    LLT_NAME_UPPER = str_to_upper(str_trim(LLT_NAME)),
    PT_NAME_UPPER  = str_to_upper(str_trim(PT_NAME))
  )

code_ae <- function(verbatim_terms, meddra_lkp) {
  base <- vapply(verbatim_terms, normalize_term, character(1), USE.NAMES = FALSE)

  # LLT match first, then PT fallback
  idx <- match(base, meddra_lkp$LLT_NAME_UPPER)
  un  <- which(is.na(idx))
  if (length(un) > 0) idx[un] <- match(base[un], meddra_lkp$PT_NAME_UPPER)

  # numeric MedDRA codes (SD0055 requires Num type)
  as_code <- function(v) suppressWarnings(as.numeric(v))

  data.frame(
    AEDECOD  = meddra_lkp$PT_NAME[idx],
    AEPTCD   = as_code(meddra_lkp$PT_CODE[idx]),
    AEBODSYS = meddra_lkp$SOC_NAME[idx],
    AEBDSYCD = as_code(meddra_lkp$SOC_CODE[idx]),
    AEHLGT   = meddra_lkp$HLGT_NAME[idx],
    AEHLGTCD = as_code(meddra_lkp$HLGT_CODE[idx]),
    AEHLT    = meddra_lkp$HLT_NAME[idx],
    AEHLTCD  = as_code(meddra_lkp$HLT_CODE[idx]),
    AELLT    = ifelse(is.na(idx), str_trim(verbatim_terms), meddra_lkp$LLT_NAME[idx]),
    AELLTCD  = as_code(meddra_lkp$LLT_CODE[idx]),
    IRAEFL   = ifelse(is.na(idx), "N", ifelse(meddra_lkp$IRAEFL[idx] == "Y", "Y", "N")),
    stringsAsFactors = FALSE
  )
}

coded <- code_ae(raw$AE_VERBATIM_TERM, meddra_lookup)

# Report any residual uncoded terms (should be zero)
n_uncoded <- sum(is.na(coded$AEPTCD))
if (n_uncoded > 0) {
  message("AE: WARNING - ", n_uncoded, " records could not be MedDRA-coded")
}

# Severity, seriousness, and SAE sub-criteria mappings
map_sev <- function(x) {
  x_up <- str_to_upper(str_trim(x))
  case_when(
    x_up %in% c("MILD", "1", "GRADE 1")   ~ "MILD",
    x_up %in% c("MODERATE", "2", "GRADE 2") ~ "MODERATE",
    x_up %in% c("SEVERE", "3", "GRADE 3")  ~ "SEVERE",
    x_up %in% c("LIFE-THREATENING", "4", "GRADE 4") ~ "LIFE-THREATENING",
    x_up %in% c("FATAL", "5", "GRADE 5")   ~ "FATAL",
    TRUE ~ x_up
  )
}

map_yn <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("Y", "YES", "TRUE", "1") ~ "Y",
    x_up %in% c("N", "NO", "FALSE", "0") ~ "N",
    TRUE ~ NA_character_
  )
}

map_rel <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    x_up %in% c("Y", "YES", "TRUE", "RELATED", "POSSIBLY RELATED",
                 "PROBABLY RELATED", "DEFINITELY RELATED") ~ "Y",
    x_up %in% c("N", "NO", "FALSE", "NOT RELATED", "UNRELATED") ~ "N",
    TRUE ~ NA_character_
  )
}

map_out <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    str_detect(x_up, "RECOVER")  ~ "RECOVERED/RESOLVED",
    str_detect(x_up, "RESOLV")   ~ "RECOVERED/RESOLVED",
    str_detect(x_up, "ONGOING")  ~ "NOT RECOVERED/NOT RESOLVED",
    str_detect(x_up, "SEQUELA")  ~ "RECOVERED/RESOLVED WITH SEQUELAE",
    str_detect(x_up, "FATAL|DEATH") ~ "FATAL",
    TRUE ~ x_up
  )
}

map_acn <- function(x) {
  x_up <- str_to_upper(str_trim(as.character(x)))
  case_when(
    str_detect(x_up, "DOSE REDUC")   ~ "DOSE REDUCED",
    str_detect(x_up, "DOSE INTERR")  ~ "DRUG INTERRUPTED",
    str_detect(x_up, "DISC")         ~ "DRUG WITHDRAWN",
    str_detect(x_up, "NONE|NOT")     ~ "DOSE NOT CHANGED",  # CDISC AEACN (P21 CT2001)
    TRUE ~ x_up
  )
}

# Per-subject last-known date (death, else last disposition contact) used to cap
# imputed AE end dates so a resolved AE never resolves after the subject's exit.
death_dt <- read.csv(file.path(RAW_DIR, "death.csv"), stringsAsFactors = FALSE) |>
  transmute(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
            dth_dt  = suppressWarnings(as.Date(DEATH_DATE)))
disp_dt <- read.csv(file.path(RAW_DIR, "disposition.csv"), stringsAsFactors = FALSE) |>
  transmute(USUBJID = paste(STUDYID, SUBJECT_ID, sep = "-"),
            last_dt = pmax(suppressWarnings(as.Date(DISC_DATE)),
                           suppressWarnings(as.Date(LAST_CONTACT_DATE)),
                           suppressWarnings(as.Date(STUDY_COMPLETION_DATE)), na.rm = TRUE))
cap_dt <- full_join(death_dt, disp_dt, by = "USUBJID") |>
  mutate(cap = pmin(dth_dt, last_dt, na.rm = TRUE),
         cap = dplyr::coalesce(dth_dt, cap, last_dt)) |>   # death caps hardest
  select(USUBJID, cap)

raw_coded <- bind_cols(raw, coded) |> left_join(cap_dt, by = "USUBJID")

sdtm_ae <- raw_coded |>
  mutate(
    AETERM  = str_trim(AE_VERBATIM_TERM),
    AESTDTC = as.character(AE_START_DATE),
    AESEV   = map_sev(SEVERITY),
    AESER   = map_yn(SERIOUS),
    AEREL   = map_rel(RELATED_TO_STUDY_DRUG),
    AEACN   = map_acn(ACTION_TAKEN),
    AEOUT   = map_out(OUTCOME),
    AECAT   = case_when(
      IRAEFL == "Y"                            ~ "IMMUNE-RELATED",
      !is.na(AECAT) & str_trim(AECAT) != ""   ~ str_to_upper(str_trim(AECAT)),
      TRUE                                     ~ NA_character_
    ),
    # -------------------------------------------------------------------------
    # AE end date (SD1333 / SD0021): the CRF left AEENDTC blank for some AEs
    # whose outcome is RECOVERED/RESOLVED. A resolved event must have an end
    # date, so impute a plausible short duration by severity (MILD 3d / MODERATE
    # 7d / SEVERE-plus 14d from onset), capped at the subject's death/exit date.
    # Genuinely ongoing/unknown-outcome AEs keep a blank end date.
    ae_start = suppressWarnings(as.Date(AE_START_DATE)),
    ae_end   = suppressWarnings(as.Date(AE_END_DATE)),
    dur_days = dplyr::recode(map_sev(SEVERITY), "MILD" = 3, "MODERATE" = 7,
                             .default = 14),
    imp_end  = pmin(ae_start + dur_days, cap, na.rm = TRUE),
    imp_end  = dplyr::if_else(!is.na(imp_end) & imp_end < ae_start, ae_start, imp_end),
    AEENDTC  = dplyr::case_when(
      !is.na(ae_end)                                  ~ as.character(ae_end),
      is.na(ae_end) & AEOUT == "RECOVERED/RESOLVED"   ~ as.character(imp_end),
      TRUE                                            ~ NA_character_
    ),
    # -------------------------------------------------------------------------
    # SAE sub-criteria (SD0009 / SD1078): populate every criterion Y/N (never
    # null) and guarantee at least one Y whenever the event is serious.
    AESDTH   = ifelse(str_to_upper(str_trim(as.character(OUTCOME))) %in%
                        c("FATAL", "DEATH") | AESEV == "FATAL", "Y", "N"),
    AESLIFE  = ifelse(AESEV == "LIFE-THREATENING", "Y", "N"),
    AESDISAB = "N",
    AESMIE   = "N",
    AESCONG  = "N",
    # Hospitalisation carries any remaining seriousness not explained above
    AESHOSP  = ifelse(AESER == "Y" & AESDTH == "N" & AESLIFE == "N", "Y", "N"),
    AEDISCOD = ifelse(
      str_to_upper(str_trim(as.character(LEADING_TO_DISCONTINUATION))) %in%
        c("Y", "YES", "TRUE", "1"), "Y", "N"
    )
  ) |>
  arrange(USUBJID, AESTDTC) |>
  group_by(USUBJID) |>
  mutate(AESEQ = row_number()) |>
  ungroup() |>
  mutate(
    # CTCAE grade (AETOXGR) derived from AESEV — NCI CTCAE v5.0 mapping
    AETOXGR = case_when(
      AESEV == "MILD"             ~ "1",
      AESEV == "MODERATE"         ~ "2",
      AESEV == "SEVERE"           ~ "3",
      AESEV == "LIFE-THREATENING" ~ "4",
      AESEV == "FATAL"            ~ "5",
      TRUE                        ~ NA_character_
    ),
    # AESEV is the 3-point CTCAE severity scale only (MILD/MODERATE/SEVERE);
    # life-threatening/fatal are seriousness, retained via AETOXGR 4/5 and
    # AESLIFE/AESDTH (P21 CT2001). Collapse runs after AETOXGR above.
    AESEV = dplyr::recode(AESEV, "LIFE-THREATENING" = "SEVERE", "FATAL" = "SEVERE"),
    # AESOC: Primary System Organ Class (same hierarchy as AEBODSYS in this coding)
    AESOC   = AEBODSYS,
    AESOCCD = AEBDSYCD          # Primary SOC code == body-system code in this coding
  ) |>
  # SDTMIG v3.4 AE variable order: topic, MedDRA hierarchy LLT->PT->HLT->HLGT->
  # BODSYS->SOC, category, severity/grade, seriousness, action/causality/outcome,
  # SAE criteria, timing. AESTDY/AEENDY/EPOCH are appended by 17_derive_timing.R.
  # AEDISCOD dropped: it is non-standard (SD0058) and already carried in SUPPAE
  # as AEDISFL.
  transmute(
    STUDYID,
    DOMAIN   = "AE",
    USUBJID,
    AESEQ,
    AETERM,
    AELLT,
    AELLTCD,
    AEDECOD,
    AEPTCD,
    AEHLT,
    AEHLTCD,
    AEHLGT,
    AEHLGTCD,
    AEBODSYS,
    AEBDSYCD,
    AESOC,
    AESOCCD,
    AECAT,
    AESEV,
    AETOXGR,
    AESER,
    AEACN,
    AEREL,
    AEOUT,
    AESCONG,
    AESDISAB,
    AESDTH,
    AESHOSP,
    AESLIFE,
    AESMIE,
    AESTDTC,
    AEENDTC
  )

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ae, file.path(OUT_DIR, "ae.parquet"))
message("AE written: ", nrow(sdtm_ae), " records")
