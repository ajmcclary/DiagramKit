#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WARN_LIMIT=500
ERROR_LIMIT=1000
ALLOWLIST_FILE="$ROOT/Scripts/check-file-sizes-allowlist.txt"
STATUS=0

ALLOWED=()
if [[ -f "$ALLOWLIST_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    ALLOWED+=("$line")
  done < "$ALLOWLIST_FILE"
fi

is_allowed() {
  local file="$1"
  for allowed in "${ALLOWED[@]}"; do
    [[ "$file" == "$allowed" ]] && return 0
  done
  return 1
}

# Parse per file so any whitespace inside a path survives (a plain
# `wc -l | sort -rn | read lines file` pipeline mangles paths containing
# whitespace runs, tabs, or newlines).
while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file" | tr -d '[:space:]')
  if is_allowed "$file"; then
    continue
  fi

  if [[ "$lines" -gt "$ERROR_LIMIT" ]]; then
    printf 'ERROR: %s is %d lines (limit: %d)\n' "$file" "$lines" "$ERROR_LIMIT"
    STATUS=1
  elif [[ "$lines" -gt "$WARN_LIMIT" ]]; then
    printf 'WARNING: %s is %d lines (limit: %d)\n' "$file" "$lines" "$WARN_LIMIT"
  fi
done < <(find Sources Tests -name "*.swift" -print0 | LC_ALL=C sort -z)

exit "$STATUS"
