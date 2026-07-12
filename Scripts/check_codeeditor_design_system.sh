#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$repo_root/Scripts/gen_codeeditor_design_system.py" \
  --contract "$repo_root/Scripts/codeeditor-design-system-contract.json" \
  --themes "$repo_root/Scripts/zed-trek.json" \
  --output-root "$repo_root" \
  --check
