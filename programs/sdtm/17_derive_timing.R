# =============================================================================
# Program    : 17_derive_timing.R
# Purpose    : Cross-domain timing derivations applied after all domain programs.
#              For every observation domain this adds:
#                * --DY study-day variables from each --DTC and DM.RFSTDTC
#                  (P21 SD1083 / SD1087 / SD1091 — missing --DY when --DTC present)
#                * EPOCH from the subject's treatment window in DM
#                  (P21 SD1077 EPOCH not found; SD1097 no treatment-emergent info)
#              Runs BEFORE 16_label_domains.R so the new columns get labelled.
# Reads/Writes: datasets/sdtm/*.parquet (in place)
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

SDTM_DIR <- "datasets/sdtm"

# Parse only complete ISO dates; partial (e.g. year-only medical-history) dates
# yield NA, so --DY / EPOCH are left blank rather than erroring.
safe_date <- function(x) {
  x <- as.character(x)
  as.Date(ifelse(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}", x), substr(x, 1, 10), NA))
}

dm <- as.data.frame(read_parquet(file.path(SDTM_DIR, "dm.parquet"))) |>
  transmute(USUBJID,
            rfst = safe_date(RFSTDTC),
            fdos = safe_date(RFXSTDTC),
            ldos = safe_date(RFXENDTC))

# SDTM study day: day 1 = RFSTDTC, no day 0 (negative before reference start).
study_day <- function(date, ref) {
  d <- as.integer(safe_date(date) - ref)
  ifelse(is.na(d), NA_integer_, ifelse(d >= 0L, d + 1L, d))
}

# EPOCH from the treatment window: SCREENING before first dose, TREATMENT while
# on treatment, FOLLOW-UP after last dose. Undosed subjects are all SCREENING.
epoch_of <- function(date, fdos, ldos) {
  d <- safe_date(date)
  dplyr::case_when(
    is.na(d)                    ~ NA_character_,
    is.na(fdos) | d < fdos      ~ "SCREENING",
    is.na(ldos) | d <= ldos     ~ "TREATMENT",  # last-dose day is still TREATMENT
    TRUE                        ~ "FOLLOW-UP"
  )
}

# Per-domain config: named vector of --DTC -> --DY, plus the --DTC used for EPOCH
# (NA where EPOCH does not apply — DM/MH/SU are demographic/historical).
timing_cfg <- list(
  ae = list(dy = c(AESTDTC = "AESTDY", AEENDTC = "AEENDY"), epoch = "AESTDTC"),
  cm = list(dy = c(CMSTDTC = "CMSTDY", CMENDTC = "CMENDY"), epoch = "CMSTDTC"),
  da = list(dy = c(DADTC   = "DADY"),                       epoch = "DADTC"),
  dd = list(dy = c(DDDTC   = "DDDY"),                       epoch = "DDDTC"),
  dm = list(dy = c(DMDTC   = "DMDY"),                       epoch = NA),
  ds = list(dy = c(DSSTDTC = "DSSTDY"),                     epoch = "DSSTDTC"),
  dv = list(dy = c(DVSTDTC = "DVSTDY"),                     epoch = "DVSTDTC"),
  ex = list(dy = c(EXSTDTC = "EXSTDY", EXENDTC = "EXENDY"), epoch = "EXSTDTC"),
  lb = list(dy = c(LBDTC   = "LBDY"),                       epoch = "LBDTC"),
  mh = list(dy = c(MHSTDTC = "MHSTDY"),                     epoch = NA),
  pe = list(dy = c(PEDTC   = "PEDY"),                       epoch = "PEDTC"),
  rs = list(dy = c(RSDTC   = "RSDY"),                       epoch = "RSDTC"),
  se = list(dy = c(SESTDTC = "SESTDY", SEENDTC = "SEENDY"), epoch = NA),
  tr = list(dy = c(TRDTC   = "TRDY"),                       epoch = "TRDTC"),
  tu = list(dy = c(TUDTC   = "TUDY"),                       epoch = "TUDTC"),
  vs = list(dy = c(VSDTC   = "VSDY"),                       epoch = "VSDTC")
)

cat("\n=== Timing derivations (EPOCH + --DY) ===\n")
for (dom in names(timing_cfg)) {
  path <- file.path(SDTM_DIR, paste0(dom, ".parquet"))
  if (!file.exists(path)) next
  df  <- as.data.frame(read_parquet(path))
  cfg <- timing_cfg[[dom]]

  df <- left_join(df, dm, by = "USUBJID")

  # --DY for each present --DTC
  added <- character(0)
  for (i in seq_along(cfg$dy)) {
    dtc <- names(cfg$dy)[i]; dyv <- cfg$dy[[i]]
    if (dtc %in% names(df)) {
      df[[dyv]] <- study_day(df[[dtc]], df$rfst)
      added <- c(added, dyv)
    }
  }
  # EPOCH
  if (!is.na(cfg$epoch) && cfg$epoch %in% names(df)) {
    df$EPOCH <- epoch_of(df[[cfg$epoch]], df$fdos, df$ldos)
    added <- c(added, "EPOCH")
  }

  df <- df |> select(-rfst, -fdos, -ldos)

  # CDISC Timing order: EPOCH precedes the date variables; each --DY follows its
  # --DTC. Place --DY after --DTC, then insert EPOCH just before its source date.
  ord <- setdiff(names(df), "EPOCH")
  for (i in seq_along(cfg$dy)) {
    dtc <- names(cfg$dy)[i]; dyv <- cfg$dy[[i]]
    if (dtc %in% ord && dyv %in% ord) {
      ord <- append(ord[ord != dyv], dyv, after = which(ord == dtc))
    }
  }
  if ("EPOCH" %in% names(df)) {
    if (!is.na(cfg$epoch) && cfg$epoch %in% ord) {
      ord <- append(ord, "EPOCH", after = which(ord == cfg$epoch) - 1)  # before --DTC
    } else {
      ord <- c(ord, "EPOCH")
    }
  }
  df <- df[, ord]

  # Atomic write via temp file + rename (avoids the Windows "user-mapped section"
  # lock from writing back to a just-read parquet path).
  tmp <- paste0(path, ".tmp")
  write_parquet(df, tmp)
  file.rename(tmp, path)
  rm(df); invisible(gc(verbose = FALSE))
  cat(sprintf("  %-4s + %s\n", dom, paste(added, collapse = ", ")))
}
cat("=== Timing derivations complete ===\n")
