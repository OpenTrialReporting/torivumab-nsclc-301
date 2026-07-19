#!/usr/bin/env bash
# =============================================================================
# run_p21.sh — Pinnacle 21 Community CLI validation for this project.
#
# Wraps the bundled Community CLI (p21-client) so validation can be run
# head-less (e.g. by Claude Code) instead of the desktop app. Validates the
# XPT export against define.xml and drops a timestamped report in
# qc/p21-reports/.
#
# Usage (run from anywhere in the repo):
#   qc/run_p21.sh [sdtm|adam|both] [--build]
#
#   sdtm   validate SDTM   (default)
#   adam   validate ADaM   (needs SDTM present too)
#   both   run SDTM then ADaM
#   --build   regenerate xpt/ + define/define.xml first (build_xpt.R + build_define.R)
#
# Config (set in qc/.env — git-ignored; copy qc/.env.example. Env vars win):
#   P21_HOME     dir holding p21-client-*.jar + configs/  (Community "Documents" dir)
#   P21_JAVA     path to the bundled Java 8 java.exe
#   P21_ENGINE   engine/config version        (default 2508.1)
#   P21_CT       CDISC SDTM CT version        (default 2026-03-27)
#   P21_API_KEY  optional Pinnacle 21 Enterprise API key  (credential — .env only)
#
# Prereqs: Java 8 (bundled with Community). MedDRA/SNOMED dictionaries are not
# installed, so those dictionary checks are skipped (structural MedDRA rules
# such as SD1449 still fire) — matching how the desktop reports were produced.
# =============================================================================
set -euo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Local machine config / credentials live in qc/.env (git-ignored — copy
# qc/.env.example and fill in). Anything already set in the environment wins.
if [[ -f "$PROJ/qc/.env" ]]; then
  set -a; . "$PROJ/qc/.env"; set +a
fi

# Defaults resolve machine paths via $HOME so nothing user-specific is committed.
_home="${HOME:-$USERPROFILE}"
_default_p21_home="$_home/OneDrive/Documents/Pinnacle 21 Community"
[[ -d "$_default_p21_home" ]] || _default_p21_home="$_home/Documents/Pinnacle 21 Community"

P21_HOME="${P21_HOME:-$_default_p21_home}"
P21_JAVA="${P21_JAVA:-}"          # required — set in qc/.env (bundled Community Java 8)
P21_ENGINE="${P21_ENGINE:-2508.1}"
P21_CT="${P21_CT:-2026-03-27}"
P21_API_KEY="${P21_API_KEY:-}"   # optional Enterprise API key (kept out of git)

if [[ -z "$P21_JAVA" || ! -x "$P21_JAVA" ]]; then
  echo "ERROR: P21_JAVA is unset or not executable. Set it in qc/.env (see" >&2
  echo "       qc/.env.example) to the bundled Community Java 8 java.exe." >&2
  exit 1
fi

MODE="sdtm"
BUILD=0
for arg in "$@"; do
  case "$arg" in
    sdtm|adam|both) MODE="$arg" ;;
    --build)        BUILD=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ---- locate jar (copy into P21_HOME if only the in-app copy exists) ----------
# The bundled layout is <app>/components/{java64/bin/java.exe, lib/p21-client-*.jar};
# derive the lib dir from P21_JAVA rather than hard-coding an install path.
JAR="$(ls "$P21_HOME"/p21-client-*.jar 2>/dev/null | sort | tail -1 || true)"
if [[ -z "$JAR" ]]; then
  applib="$(cd "$(dirname "$P21_JAVA")/../../lib" 2>/dev/null && pwd || true)"
  APPJAR="$(ls "$applib"/p21-client-*.jar 2>/dev/null | sort | tail -1 || true)"
  [[ -z "$APPJAR" ]] && { echo "ERROR: p21-client jar not found in $P21_HOME or the app lib dir. Set P21_HOME/P21_JAVA in qc/.env." >&2; exit 1; }
  cp "$APPJAR" "$P21_HOME/" && JAR="$P21_HOME/$(basename "$APPJAR")"
  echo "Copied CLI jar to $P21_HOME"
fi

# ---- optional rebuild of XPT + define ----------------------------------------
if [[ "$BUILD" -eq 1 ]]; then
  echo "== Rebuilding XPT + define.xml =="
  ( cd "$PROJ" && Rscript programs/export/build_xpt.R >/dev/null && Rscript programs/define/build_define.R >/dev/null )
fi

SDTM_XPT="$PROJ/xpt/sdtm"
ADAM_XPT="$PROJ/xpt/adam"
# Each run points at a standard-scoped define so datasets absent from that run's
# source folder are not reported missing (SD0061). The SDTM run uses the
# SDTM-only define; the ADaM run loads SDTM + ADaM together and uses the combined
# define. Fall back to the combined define if the split file is absent.
DEFINE="$PROJ/define/define.xml"
SDTM_DEFINE="$PROJ/define/sdtm/define.xml"; [[ -f "$SDTM_DEFINE" ]] || SDTM_DEFINE="$DEFINE"
ADAM_DEFINE="$DEFINE"
[[ -d "$SDTM_XPT" ]] || { echo "ERROR: $SDTM_XPT missing — run with --build first." >&2; exit 1; }

STAMP="$(date +%Y%m%dT%H%M%S)"
OUTDIR="$PROJ/qc/p21-reports"
mkdir -p "$OUTDIR"

# git-bash → Windows path (the CLI is a Windows JVM and wants C:\ paths)
w() { cygpath -w "$1"; }

# -----------------------------------------------------------------------------
# SD1005 workaround for ADaM validation.
# SD1005 ("Invalid STUDYID": a STUDYID value must match one in the DM domain) is
# an SDTM cross-domain lookup. When the SDTM datasets are loaded as supporting
# data inside an ADaM run, this lookup misfires and flags every non-DM SDTM
# record (~540K) even though the STUDYID is a valid constant and the standalone
# SDTM run passes the rule cleanly. We temporarily deactivate SD1005 in the SDTM
# sub-config for the ADaM run only, and restore it immediately (a trap guarantees
# restore even on error/interrupt). The rule stays fully active for the SDTM run.
_SD1005_CFG=""; _SD1005_BAK=""
restore_sd1005() {
  if [[ -n "$_SD1005_BAK" && -f "$_SD1005_BAK" ]]; then
    mv -f "$_SD1005_BAK" "$_SD1005_CFG" 2>/dev/null || true
  fi
  _SD1005_BAK=""; _SD1005_CFG=""
}
trap restore_sd1005 EXIT INT TERM

patch_sd1005() {   # deactivate SD1005 in the SDTM sub-config (for the ADaM run)
  _SD1005_CFG="$P21_HOME/configs/$P21_ENGINE/SDTM-IG 3.4 (FDA).xml"
  [[ -f "$_SD1005_CFG" ]] || { _SD1005_CFG=""; return 0; }
  _SD1005_BAK="$(mktemp)"; cp "$_SD1005_CFG" "$_SD1005_BAK"
  sed -i 's#RuleID="SD1005" Active="Yes"#RuleID="SD1005" Active="No"#g' "$_SD1005_CFG"
}

run_one() {
  local std="$1" ver="$2" config_xml="$3" report="$4"; shift 4
  local config_path="$P21_HOME/configs/$P21_ENGINE/$config_xml"
  echo ""
  echo "== Pinnacle 21 CLI: $std $ver (engine $P21_ENGINE, CT $P21_CT) =="
  [[ -f "$config_path" ]] || { echo "ERROR: rule config not found: $config_path" >&2; return 1; }
  local extra=()
  [[ -n "$P21_API_KEY" ]] && extra+=(--api.key="$P21_API_KEY")
  # ADaM validates the linked SDTM data too — suppress the spurious SD1005 there.
  [[ "$std" == "adam" ]] && patch_sd1005
  local log; log="$(mktemp)"
  ( cd "$P21_HOME" && "$P21_JAVA" -jar "$(basename "$JAR")" \
      --engine.version="$P21_ENGINE" \
      --config="$(w "$config_path")" \
      --standard="$std" \
      --standard.version="$ver" \
      --cdisc.ct.sdtm.version="$P21_CT" \
      --source.define="$(w "$DEFINE")" \
      --report="$(w "$report")" \
      --report.cutoff=1000000 \
      ${extra[@]+"${extra[@]}"} \
      "$@" 2>&1 ) > "$log" || true
  restore_sd1005   # restore the SDTM config immediately after the run
  grep -viE "SLF4J|logback|Reflections|^[0-9]{2}:[0-9]{2}:[0-9]{2}" "$log" | grep -iE "error|warn|complete|finish|summary|rule" | head -20 || true

  if grep -qiE "expired|CLI\.3\.17|IqException|Expiration date check" "$log"; then
    cat >&2 <<'MSG'

*** Pinnacle 21 Community licence/qualification has EXPIRED ***
The CLI reached the engine but the installation-qualification check failed.
This is a P21 licensing gate, not a data problem. To refresh it:
  1. Launch the desktop app once while online:
       "C:\Program Files (x86)\Pinnacle 21 Community\Pinnacle 21 Community.exe"
     (it renews the qualification token in app.data), then re-run this script.
  2. If the desktop app also reports expiry, download the latest Community
     release from pinnacle21.com and re-run.
MSG
    rm -f "$log"; return 3
  fi
  rm -f "$log"

  if [[ -f "$report" ]]; then
    echo "Report: $report"
    command -v Rscript >/dev/null 2>&1 && Rscript "$PROJ/qc/p21_summary.R" "$report" 2>/dev/null || true
  else
    echo "WARNING: report not produced — check CLI output above." >&2
    return 1
  fi
}

case "$MODE" in
  sdtm|both)
    DEFINE="$SDTM_DEFINE"
    run_one sdtm 3.4 "SDTM-IG 3.4 (FDA).xml" "$OUTDIR/pinnacle21-cli-${STAMP}-sdtm.xlsx" \
      --source.sdtm="$(w "$SDTM_XPT")"
    ;;
esac
case "$MODE" in
  adam|both)
    [[ -d "$ADAM_XPT" ]] || { echo "ERROR: $ADAM_XPT missing — run with --build." >&2; exit 1; }
    DEFINE="$ADAM_DEFINE"
    run_one adam 1.3 "ADaM-IG 1.3 (FDA).xml" "$OUTDIR/pinnacle21-cli-${STAMP}-adam.xlsx" \
      --cdisc.ct.adam.version="$P21_CT" \
      --source.sdtm="$(w "$SDTM_XPT")" \
      --source.adam="$(w "$ADAM_XPT")"
    ;;
esac

echo ""
echo "Done. Reports in $OUTDIR/"
