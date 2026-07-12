#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if (( $# > 0 )); then
  roots=("$@")
else
  roots=(
    "$repo_root/Sources/DiagramKitSample/Views"
    "$repo_root/Sources/DiagramKitSample/Models/Workspace"
  )
fi

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
violations="$temporary/violations"
: > "$violations"

is_allowed() {
  local file="$1"
  local rule="$2"
  case "$file:$rule" in
    */Sources/DiagramKitSampleDesignSystem/Generated/*) return 0 ;;
    */NativeCodeEditor.swift:literal-color|*/NativeCodeEditor.swift:system-font) return 0 ;;
    */LineNumberRuler.swift:literal-color|*/LineNumberRuler.swift:system-font) return 0 ;;
  esac
  return 1
}

scan_rule() {
  local rule="$1"
  local pattern="$2"
  local matches="$temporary/$rule"
  : > "$matches"
  rg --pcre2 -nH --glob '*.swift' "$pattern" "${roots[@]}" > "$matches" 2>/dev/null || true
  while IFS=: read -r file line _; do
    [[ -n "$file" && -n "$line" ]] || continue
    if ! is_allowed "$file" "$rule"; then
      printf '%s:%s: %s\n' "$file" "$line" "$rule" >> "$violations"
    fi
  done < "$matches"
}

scan_rule literal-color 'Color\((?:red:|white:|\.sRGB)|Color\.(?:red|blue|green|orange|yellow|purple|pink|gray|black|white|accentColor)\b'
scan_rule system-font '(?:Font\.system|\.font\(\.system)\(size:'
scan_rule numeric-radius 'cornerRadius:\s*[0-9]'
scan_rule direct-icon 'Image\(systemName:'
scan_rule shadow '\.shadow\('
scan_rule material '\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial)\b'
scan_rule literal-animation '\.animation\([^\n]*(?:duration:|\.spring|\.ease)'
scan_rule scale-effect '\.scaleEffect\((?!1(?:\.0)?\b)'
scan_rule gesture-switch '\.onTapGesture[^\n]*(?:\.toggle\(\)|toggle\(\))'
scan_rule undersized-target '\b(?:button|control|view)\.frame\([^\n]*(?:width|height):\s*(?:[0-2]?[0-9]|3[0-9])\b'
scan_rule plain-button '\.buttonStyle\(\.plain\)'

if [[ -s "$violations" ]]; then
  sort -u "$violations"
  exit 1
fi

printf 'Sample design-system adherence: no violations.\n'
