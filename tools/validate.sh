#!/usr/bin/env bash
# Headless import + parse-error scan + GUT unit tests.
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo ">> Headless import"
# First pass builds initial import cache / global class cache if missing
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
# Second pass validates import without first-pass cache generation noise
"$GODOT" --headless --path . --import 2>&1 | tee "$LOG"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG"; then
  echo "FAIL: script errors during import" >&2
  exit 1
fi

if [ -f addons/gut/gut_cmdln.gd ]; then
  echo ">> GUT tests"
  "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit
else
  echo ">> GUT not installed yet; skipping tests"
fi
echo ">> OK"
