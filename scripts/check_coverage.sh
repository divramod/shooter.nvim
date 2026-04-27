#!/usr/bin/env bash
# Run the Plenary test suite under luacov, then assert the global Total
# meets the configured threshold. Exits non-zero (rc=1) on coverage shortfall,
# rc=2 on test failures.
#
# Threshold defaults to 80; override via $COVERAGE_THRESHOLD or --threshold N.
# Plan-0001-feats-refactor canonical gate; called from CI in .github/workflows/.
set -euo pipefail

THRESHOLD="${COVERAGE_THRESHOLD:-80}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --threshold=*) THRESHOLD="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"

rm -f luacov.stats.out luacov.report.out

LOG=/tmp/check_coverage_test.log
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" \
  -c "qa!" 2>&1 | tee "$LOG" >/dev/null

if grep -E 'Tests Failed|Errors *: *[1-9]' "$LOG" >/dev/null; then
  echo "FAIL: test suite has failures or errors (see $LOG)" >&2
  awk -F'\t' '/Failed/ {gsub(/[^0-9]/, "", $2); f+=$2} /Errors/ {gsub(/[^0-9]/, "", $2); e+=$2} END {print "  failed="f" errors="e}' "$LOG" >&2
  exit 2
fi

if [[ ! -f luacov.report.out ]]; then
  echo "FAIL: luacov.report.out missing — coverage tooling didn't run" >&2
  exit 2
fi

# luacov reports localized percentages on macOS (e.g. "87,07%"); normalize to
# "." before parsing.
COVERAGE=$(awk '/^Total/ {pct=$NF; gsub("%","",pct); gsub(",", ".", pct); print pct; exit}' luacov.report.out)
if [[ -z "$COVERAGE" ]]; then
  echo "FAIL: could not parse Total line from luacov.report.out" >&2
  exit 2
fi

# Compare via awk (bash floats are unreliable).
if awk -v c="$COVERAGE" -v t="$THRESHOLD" 'BEGIN { exit !(c+0 >= t+0) }'; then
  printf 'PASS: coverage %s%% >= %s%% threshold\n' "$COVERAGE" "$THRESHOLD"
  exit 0
else
  printf 'FAIL: coverage %s%% < %s%% threshold\n' "$COVERAGE" "$THRESHOLD" >&2
  exit 1
fi
