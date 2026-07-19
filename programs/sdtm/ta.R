# =============================================================================
# Program    : ta.R
# Domain     : TA — Trial Arms
# SDTM IG ref: Section 7.1 (Trial Design)
# Reads from : (study-level constants; no subject data)
# Writes to  : datasets/sdtm/ta.parquet
# Notes      : One record per arm per element transition. ARMCD must match
#              DM.ARMCD (TORICHEMO / PBOCHEMO). EPOCH values verified against
#              CDISC CT 2026-03-27. Presence of TA clears P21 SD1112.
# =============================================================================

library(dplyr)
library(arrow)

OUT_DIR <- "datasets/sdtm"
STUDYID <- "CTX-NSCLC-301"

# Element sequence shared by both arms (Screen -> Treatment -> Follow-up)
elems <- tibble::tribble(
  ~TAETORD, ~ETCD,  ~ELEMENT,     ~EPOCH,
  1L,       "SCRN", "Screening",  "SCREENING",
  2L,       "TRT",  "Treatment",  "TREATMENT",
  3L,       "FU",   "Follow-up",  "FOLLOW-UP"
)

arms <- tibble::tribble(
  ~ARMCD,       ~ARM,
  "TORICHEMO",  "Torivumab + Chemotherapy",
  "PBOCHEMO",   "Placebo + Chemotherapy"
)

sdtm_ta <- tidyr::crossing(arms, elems) |>
  mutate(
    STUDYID  = STUDYID,
    DOMAIN   = "TA",
    # Branch at randomization (end of screening element)
    TABRANCH = ifelse(ETCD == "SCRN", paste0("Randomized to ", ARM), NA_character_),
    TATRANS  = NA_character_
  ) |>
  transmute(
    STUDYID, DOMAIN, ARMCD, ARM, TAETORD, ETCD, ELEMENT, TABRANCH, TATRANS, EPOCH
  ) |>
  arrange(ARMCD, TAETORD)

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(sdtm_ta, file.path(OUT_DIR, "ta.parquet"))
message("TA written: ", nrow(sdtm_ta), " arm-element records")
