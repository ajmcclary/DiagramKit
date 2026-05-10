#!/usr/bin/env bash
set -euo pipefail

# check-sendable-annotations.sh
#
# Ensures every @unchecked Sendable annotation in Sources/ is either:
#   1. In the allowlist (red → error / yellow → check sunset)
#   2. Green — has a concurrency contract banner (passes silently)
#   3. Unknown — not in allowlist and no contract → error
#
# Contract detection: looks for a banner in the first 50 lines of the file
# OR within 10 lines before the annotation. This handles both file-level
# banners (at the top) and nearby banners.
#
# Allowlist: .sendable-allowlist.txt at repo root.
# Format: file:line:category:sunset  (sunset is YYYY-MM-DD for yellow; ignored for red)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

shopt -s extglob

ALLOWLIST="$ROOT/.sendable-allowlist.txt"
STATUS=0
NOW_EPOCH=$(date +%s)

declare -A ALLOWLIST_CATEGORY
declare -A ALLOWLIST_SUNSET

if [[ -f "$ALLOWLIST" ]]; then
  while IFS=: read -r file line cat sunset || [[ -n "$file" ]]; do
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    file="${file##+( )}"; file="${file%%+( )}"
    line="${line##+( )}"; line="${line%%+( )}"
    cat="${cat##+( )}"; cat="${cat%%+( )}"
    sunset="${sunset##+( )}"; sunset="${sunset%%+( )}"
    key="$file:$line"
    ALLOWLIST_CATEGORY["$key"]="$cat"
    ALLOWLIST_SUNSET["$key"]="$sunset"
  done < "$ALLOWLIST"
fi

has_contract_banner() {
  local file="$1"
  local line="$2"

  sed -n '1,50p' "$file" 2>/dev/null | grep -qiE \
    "Concurrency Contract|@unchecked Sendable.*per the|single-pass|construction-then-freeze|setup-then-share|render-pipeline|queue-confinement|All public APIs are thread-safe" \
    && return 0

  local start=$((line - 10))
  [[ $start -lt 1 ]] && start=1
  sed -n "${start},${line}p" "$file" 2>/dev/null | grep -qiE \
    "Concurrency Contract|@unchecked Sendable.*per the|single-pass|construction-then-freeze|setup-then-share|render-pipeline|queue-confinement|All public APIs are thread-safe" \
    && return 0

  return 1
}

date_to_epoch() {
  local d="$1"
  if date --version >/dev/null 2>&1; then
    date -d "$d" +%s 2>/dev/null || echo 0
  else
    date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || echo 0
  fi
}

ANNOTATIONS=$(grep -rn '@unchecked Sendable' Sources/ 2>/dev/null || true)

if [[ -z "$ANNOTATIONS" ]]; then
  echo "No @unchecked Sendable annotations found in Sources/."
  exit 0
fi

while IFS=: read -r file line rest; do
  [[ "$rest" =~ ^[[:space:]]*// ]] && continue

  TYPE_NAME=$(echo "$rest" | sed -nE \
    's/.*(class|struct|enum|extension)[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*/\2/p')
  [[ -z "$TYPE_NAME" ]] && TYPE_NAME="(unknown)"

  key="$file:$line"
  cat="${ALLOWLIST_CATEGORY["$key"]:-}"
  sunset="${ALLOWLIST_SUNSET["$key"]:-}"

  if [[ -n "$cat" ]]; then
    case "$cat" in
      red)
        echo "ERROR: $file:$line — Red-category @unchecked Sendable on '$TYPE_NAME' must be resolved to Green or Yellow."
        STATUS=1
        ;;
      yellow)
        if [[ -n "$sunset" ]]; then
          SUNSET_EPOCH=$(date_to_epoch "$sunset")
          if [[ "$NOW_EPOCH" -gt "$SUNSET_EPOCH" ]]; then
            echo "ERROR: $file:$line — Yellow-category @unchecked Sendable on '$TYPE_NAME' is past its sunset date ($sunset)."
            STATUS=1
          else
            echo "ALLOWED (yellow, sunset $sunset): $file:$line — $TYPE_NAME"
          fi
        else
          echo "ALLOWED (yellow, no sunset): $file:$line — $TYPE_NAME"
        fi
        ;;
      *)
        echo "ERROR: $file:$line — Unknown allowlist category '$cat' for '$TYPE_NAME'."
        STATUS=1
        ;;
    esac
    continue
  fi

  if has_contract_banner "$file" "$line"; then
    continue
  fi

  echo "ERROR: $file:$line — @unchecked Sendable on '$TYPE_NAME' has no concurrency contract and is not in the allowlist."
  STATUS=1

done <<< "$ANNOTATIONS"

if [[ $STATUS -eq 0 ]]; then
  echo "✓ All @unchecked Sendable annotations are documented or allowlisted."
else
  echo ""
  echo "FAILED: Some @unchecked Sendable annotations need attention."
  echo "  Green: add a concurrency contract banner within 10 lines of the annotation"
  echo "         or in the first 50 lines of the file."
  echo "  Red:   add a banner, then move to the Yellow section with a sunset date."
  echo "  Yellow: resolve the leaky API before the sunset date."
fi

exit $STATUS
