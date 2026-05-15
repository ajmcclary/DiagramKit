#!/usr/bin/env bash
#
# check-diagnostic-discipline.sh
#
# Enforces docs/diagnostic-severity-discipline.md. Three rules:
#   1. Raw `DiagramDiagnostic(severity:` outside Sources/DiagramKitCommon/ is
#      forbidden; use .lossyTransform / .featureDropped / .informational.
#   2. Every `// SILENT-DROP(` marker must be followed within 3 lines by a
#      `Pinned by: <TestName>` line, and that test must exist under Tests/.
#   3. Exporters MUST NOT throw DiagramError.malformedSource; emit a
#      .featureDropped diagnostic instead.
#
# Allowlist: .diagnostic-discipline-allowlist.txt at repo root.
# Format: file:line  (one entry per line; comments with # OK)
#
# Override root for self-test: set DIAGRAMKIT_DISCIPLINE_ROOT to operate
# against a sandbox tree instead of the real repo.

set -uo pipefail

if [[ -n "${DIAGRAMKIT_DISCIPLINE_ROOT:-}" ]]; then
  ROOT="$DIAGRAMKIT_DISCIPLINE_ROOT"
else
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
cd "$ROOT"

ALLOWLIST="$ROOT/.diagnostic-discipline-allowlist.txt"
VIOLATIONS=0

# Load allowlist into an associative array.
declare -A ALLOW
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
    ALLOW["$entry"]=1
  done < "$ALLOWLIST"
fi

# Rule 1 — raw DiagramDiagnostic(severity:) outside Common is forbidden.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  loc=$(echo "$hit" | cut -d: -f1-2)
  if [[ -z "${ALLOW["$loc"]:-}" ]]; then
    echo "  $loc: raw DiagramDiagnostic(severity:) — use .lossyTransform/.featureDropped/.informational" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(grep -RIn 'DiagramDiagnostic(severity:' Sources --include='*.swift' \
           --exclude-dir=DiagramKitCommon 2>/dev/null || true)

# Rule 2 — // SILENT-DROP( markers must carry a Pinned by: line within 6 lines
# (multiline reason comments are common; cap chosen so a stale marker still rots)
# and the referenced test must exist under Tests/.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  file=$(echo "$hit" | cut -d: -f1)
  line=$(echo "$hit" | cut -d: -f2)
  end=$((line + 6))
  ctx=$(sed -n "${line},${end}p" "$file" 2>/dev/null || true)
  test_ref=$(echo "$ctx" | grep -oE 'Pinned by:[[:space:]]+\S+' | head -1 | awk '{print $3}')
  if [[ -z "$test_ref" ]]; then
    echo "  $file:$line: SILENT-DROP marker missing 'Pinned by: <Test>' line within 6 lines" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi
  # Strip leading qualifier (e.g., "Suite.testName" → "testName").
  short="${test_ref##*.}"
  if ! grep -RIlq "func $short\b" Tests/ 2>/dev/null; then
    echo "  $file:$line: SILENT-DROP references missing test '$test_ref'" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(grep -RIn '// SILENT-DROP(' Sources --include='*.swift' 2>/dev/null || true)

# Rule 3 — exporters MUST NOT throw DiagramError.malformedSource.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  echo "  $hit: exporter throws malformedSource — emit a .featureDropped diagnostic instead" >&2
  VIOLATIONS=$((VIOLATIONS + 1))
done < <(grep -RIn 'throw DiagramError\.malformedSource' \
           Sources --include='*Exporter*.swift' 2>/dev/null || true)

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "diagnostic-discipline: $VIOLATIONS violation(s)" >&2
  exit 1
fi
echo "diagnostic-discipline: ✓ clean"
exit 0
