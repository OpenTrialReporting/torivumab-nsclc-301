# =============================================================================
# Program    : 00_run_sdtm.R
# Purpose    : Master controller — sources all SDTM domain mapping programs
#              in the order required by CDISC SDTM IG dependencies.
# Study      : CTX-NSCLC-301 (Torivumab NSCLC Phase 3)
# Run from   : Project root (torivumab-nsclc-301/)
# Usage      : Rscript programs/sdtm/00_run_sdtm.R
#              OR source("programs/sdtm/00_run_sdtm.R") from R console
# =============================================================================

# Verify working directory is project root
if (!file.exists("raw")) {
  stop(
    "Working directory must be the project root (containing raw/).\n",
    "Current directory: ", getwd()
  )
}

# Ensure output directory exists
dir.create("datasets/sdtm", showWarnings = FALSE, recursive = TRUE)

# ---- Domain execution order ----
# DM first (subject-level anchor for USUBJID)
# DS next (uses demographics for consent/randomisation records)
# EX, then interventions/events, then oncology-specific, then SUPPQUAL

sdtm_programs <- c(
  "dm",       # DM  — Demographics
  "ds",       # DS  — Disposition
  "ex",       # EX  — Exposure
  "ae",       # AE  — Adverse Events
  "cm",       # CM  — Concomitant Medications
  "lb",       # LB  — Laboratory Results
  "vs",       # VS  — Vital Signs
  "mh",       # MH  — Medical History
  "pe",       # PE  — Physical Examination
  "tu",       # TU  — Tumor Identification
  "tr",       # TR  — Tumor Results
  "rs",       # RS  — Disease Response
  "dd",       # DD  — Death Details
  "su",       # SU  — Substance Use
  "suppdm"    # SUPPDM — Supplemental Qualifiers for DM
)

# ---- Run each program ----
run_domain <- function(domain) {
  prog_path <- file.path("programs", "sdtm", paste0(domain, ".R"))
  message("\n", strrep("=", 70))
  message("Running: ", prog_path)
  message(strrep("=", 70))

  # withCallingHandlers catches+muffles warnings while letting execution continue;
  # tryCatch catches errors and halts cleanly.
  withCallingHandlers(
    tryCatch(
      {
        source(prog_path, local = new.env(parent = globalenv()))
        message("SUCCESS: ", toupper(domain))
      },
      error = function(e) {
        message("ERROR in ", toupper(domain), ": ", conditionMessage(e))
        stop("Execution halted due to error in ", toupper(domain),
             ". Fix and re-run.")
      }
    ),
    warning = function(w) {
      message("WARNING in ", toupper(domain), ": ", conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
}

start_time <- proc.time()

for (dom in sdtm_programs) {
  run_domain(dom)
}

# ---- Step 2: Attach SDTMIG v3.4 variable labels ----
message("\n", strrep("=", 70))
message("Running: programs/sdtm/16_label_domains.R")
message(strrep("=", 70))
source("programs/sdtm/16_label_domains.R")

elapsed <- proc.time() - start_time

message("\n", strrep("=", 70))
message("All SDTM domains completed and labelled.")
message(sprintf("Total elapsed time: %.1f seconds", elapsed["elapsed"]))
message(strrep("=", 70))

# ---- Summary: list output parquet f