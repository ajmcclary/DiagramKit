#!/usr/bin/env bash

# Discipline gate: fail when stale "will be introduced" / "will become"
# transition markers reappear in Sources/. The remediation plan (PHASES.md,
# CODE_QUALITY_AUDIT.md finding P4) sweeps these on every phase close; this
# guard keeps them swept.
#
# Patterns INTENTIONALLY allowed (not matched here):
#   - `Phase 8: Interactivity Primitives — Slice 8X`   — file-history tag.
#   - `Phase 1: Branch positions`                       — in-function algorithm step.
#   - `Phase X of the A5 RenderConfig split`            — deliberate migration seam.
#   - `Phase 0 backward-compat deprecated alias`        — file-history tag.
#   - `Phase N (audit AX)`                              — historical reference to a closed phase.
#
# Patterns this guard flags:
#   1. `will be introduced` — future-tense premise that landed already.
#   2. `will become` — future-tense rename premise that landed already.
#   3. `after Phase 6D` — outdated specific reference (the bucket the audit P4 used).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Use rg with explicit failure if any match is found. `--quiet` is fine here
# because we re-run without it to show context when the gate fails.
PATTERNS=(
  'will be introduced'
  'will become'
  'after Phase 6D'
)

status=0
for pattern in "${PATTERNS[@]}"; do
  if rg --quiet --fixed-strings "$pattern" Sources 2>/dev/null; then
    printf '\n❌ Stale phase comment matched: %s\n' "$pattern"
    rg -n --fixed-strings "$pattern" Sources || true
    status=1
  fi
done

if [[ "$status" -eq 0 ]]; then
  printf '✓ No stale phase-transition comments in Sources.\n'
fi

exit "$status"
