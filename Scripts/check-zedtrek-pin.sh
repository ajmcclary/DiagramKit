#!/usr/bin/env bash
#
# check-zedtrek-pin.sh
#
# Pins the generated Zed Trek canvas hexes: Sources/DiagramKitModel/
# Theme+ZedTrek.swift must be exactly what Scripts/gen_zedtrek.py derives
# from Scripts/zed-trek.json. Nothing else ties the checked-in hexes to the
# design source, so hand-edits (or a zed-trek.json refresh) drift silently.
# This is a thin wrapper so the bootstrap gate table stays uniform; the
# comparison itself lives in gen_zedtrek.py --check.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "check-zedtrek-pin.sh: requires python3" >&2
  exit 2
fi

exec python3 "$ROOT/Scripts/gen_zedtrek.py" --check
