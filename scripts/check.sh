#!/usr/bin/env bash
#
# check.sh — quality gate for aon2026 (Astronomy Open Night 2026).
#
#   ./scripts/check.sh          # quick: analyze, l10n completeness, tests, reskin tests
#   ./scripts/check.sh full     # + web / apk / iOS-sim builds
#   ./scripts/check.sh quick    # explicit quick
#
# Blocking gates fail the script (non-zero exit). `dart format` is REPORTED but
# never blocks: the repo carries pre-existing Dart 3.12 tall-style drift
# (~99/187 files), so a blanket format gate would fail on code we deliberately
# do not reformat. See memory: "dart format wholesale drift".
#
# No new dependencies. Uses only the Flutter/Dart toolchain + python3 (for the
# reskin asset-transform tests).

set -uo pipefail

# ── locate repo root (script lives in scripts/) ─────────────────────────────
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT" || { echo "cannot cd to repo root"; exit 2; }

MODE="${1:-quick}"
case "$MODE" in
  quick|full) ;;
  -h|--help)
    grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '1d'; exit 0 ;;
  *) echo "unknown mode: $MODE (use 'quick' or 'full')"; exit 2 ;;
esac

# ── pretty output (degrade gracefully when not a TTY) ───────────────────────
if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; DIM=$'\033[2m'; X=$'\033[0m'
else
  R=; G=; Y=; B=; DIM=; X=
fi

FAILED=()   # names of blocking gates that failed
PASSED=0
SKIPPED=()

hr() { printf '%s\n' "────────────────────────────────────────────────────────"; }
now_ms() { python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0; }

# run_gate "Name" cmd args...   → blocking; records pass/fail, streams a tail on failure
run_gate() {
  local name="$1"; shift
  printf '%s▶ %s%s\n' "$B" "$name" "$X"
  local log start end
  log="$(mktemp)"; start="$(now_ms)"
  if "$@" >"$log" 2>&1; then
    end="$(now_ms)"
    printf '  %s✓ %s%s %s(%sms)%s\n' "$G" "$name" "$X" "$DIM" "$((end-start))" "$X"
    PASSED=$((PASSED+1)); rm -f "$log"; return 0
  else
    end="$(now_ms)"
    printf '  %s✗ %s%s %s(%sms)%s\n' "$R" "$name" "$X" "$DIM" "$((end-start))" "$X"
    printf '%s' "$DIM"; tail -n 25 "$log" | sed 's/^/    /'; printf '%s' "$X"
    FAILED+=("$name"); rm -f "$log"; return 1
  fi
}

echo
printf '%saon2026 check — mode: %s%s\n' "$B" "$MODE" "$X"
printf '%s%s%s\n' "$DIM" "$(flutter --version 2>/dev/null | head -1 || echo 'flutter: NOT FOUND')" "$X"
hr

# ── 0. toolchain present ────────────────────────────────────────────────────
command -v flutter >/dev/null 2>&1 || { echo "${R}flutter not on PATH${X}"; exit 2; }

# ── 1. resolve dependencies ─────────────────────────────────────────────────
run_gate "pub get" flutter pub get

# ── 2. static analysis (must be clean) ──────────────────────────────────────
run_gate "flutter analyze" flutter analyze

# ── 2b. vendored-asset provenance (buildings.json SHA-256 must not drift) ────
provenance_gate() {
  local asset="assets/data/buildings.json"
  local prov="docs/fixtures/buildings_provenance.json"
  [ -f "$asset" ] || return 0  # asset not present yet → feature absent, skip
  # Asset present but provenance record gone = integrity gate silently removed.
  # FAIL rather than skip (map audit P2 — deleting the record bypassed the gate).
  if [ ! -f "$prov" ]; then
    echo "provenance record missing: $prov (present asset $asset has no SHA gate)"; return 1
  fi
  local have want
  have="$(shasum -a 256 "$asset" | awk '{print $1}')"
  want="$(python3 -c "import json,sys;print(json.load(open('$prov'))['sha256'])")"
  if [ "$have" != "$want" ]; then
    echo "buildings.json SHA drift: asset=$have provenance=$want"; return 1
  fi
  return 0
}
run_gate "buildings.json provenance" provenance_gate

# ── 3. l10n: regenerate + assert EN/FA completeness ─────────────────────────
# gen-l10n writes any missing non-template keys to untranslated-messages-file
# instead of failing, so the real gate is: that file must be empty/absent.
UNTRANSLATED=".dart_tool/untranslated_messages.json"
rm -f "$UNTRANSLATED"
l10n_gate() {
  flutter gen-l10n || return 1
  if [ -s "$UNTRANSLATED" ] && [ "$(tr -d '[:space:]{}' < "$UNTRANSLATED")" != "" ]; then
    echo "untranslated keys present (FA incomplete):"; cat "$UNTRANSLATED"; return 1
  fi
  return 0
}
run_gate "l10n complete (EN+FA)" l10n_gate

# ── 4. tests (Dart) ─────────────────────────────────────────────────────────
run_gate "flutter test" flutter test

# ── 5. reskin asset-transform tests (Python) ────────────────────────────────
if command -v python3 >/dev/null 2>&1 && [ -f tools/reskin/test_reskin.py ]; then
  run_gate "reskin transform tests" bash -c 'cd tools/reskin && python3 test_reskin.py'
else
  SKIPPED+=("reskin transform tests (python3 or file missing)")
fi

# ── 6. dart format — INFORMATIONAL ONLY (never blocks) ──────────────────────
printf '%s▶ dart format (informational)%s\n' "$B" "$X"
FMT="$(dart format --output=none --set-exit-if-changed lib test 2>&1)"; FMT_RC=$?
if [ "$FMT_RC" -eq 0 ]; then
  printf '  %s✓ formatted%s\n' "$G" "$X"
else
  CHANGED="$(printf '%s\n' "$FMT" | grep -c '^Changed ')"
  printf '  %s• %s file(s) differ from dart format%s %s(pre-existing 3.12 tall-style drift — not a gate; do not blanket-reformat)%s\n' \
    "$Y" "$CHANGED" "$X" "$DIM" "$X"
fi

# ── 7. build gates (full only) ──────────────────────────────────────────────
if [ "$MODE" = "full" ]; then
  hr
  printf '%sbuild gates%s\n' "$B" "$X"

  run_gate "build web" flutter build web

  if flutter config 2>/dev/null | grep -qiE 'android|sdk' && [ -d android ]; then
    run_gate "build apk (debug)" flutter build apk --debug
  else
    SKIPPED+=("build apk (no Android toolchain)")
  fi

  if [ "$(uname)" = "Darwin" ] && command -v xcodebuild >/dev/null 2>&1 && [ -d ios ]; then
    run_gate "build ios (simulator, debug)" flutter build ios --simulator --debug
  else
    SKIPPED+=("build ios (needs macOS + Xcode)")
  fi
fi

# ── summary ─────────────────────────────────────────────────────────────────
hr
printf '%sSummary%s  passed: %s%d%s  failed: %s%d%s  skipped: %d\n' \
  "$B" "$X" "$G" "$PASSED" "$X" "$R" "${#FAILED[@]}" "$X" "${#SKIPPED[@]}"
for s in "${SKIPPED[@]:-}"; do [ -n "$s" ] && printf '  %s- skipped: %s%s\n' "$DIM" "$s" "$X"; done
if [ "${#FAILED[@]}" -gt 0 ]; then
  for f in "${FAILED[@]}"; do printf '  %s✗ %s%s\n' "$R" "$f" "$X"; done
  printf '%sCHECK FAILED%s\n' "$R$B" "$X"
  exit 1
fi
printf '%sCHECK PASSED%s\n' "$G$B" "$X"
exit 0
