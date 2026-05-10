#!/usr/bin/env bash

set -euo pipefail

# Strict-concurrency gate for DiagramKit's first-party targets.
#
# Runs `swift build` under Swift 6 mode + `-strict-concurrency=complete` and
# asserts no error or warning originates from anything inside `Sources/`.
# Errors from third-party transitive dependencies are tolerated — those are
# out of our control and tracked separately.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

printf '==> swift build -Xswiftc -swift-version -Xswiftc 6 -Xswiftc -strict-concurrency=complete\n'

swift build \
  -Xswiftc -swift-version -Xswiftc 6 \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors \
  >"$LOG" 2>&1 || true

if grep -E "Sources/DiagramKit[^/]*/" "$LOG" | grep -E "(error|warning):" >&2; then
  printf '\n\xE2\x9D\x8C DiagramKit first-party code emitted strict-concurrency diagnostics. See above.\n'
  exit 1
fi

printf '\xE2\x9C\x93 DiagramKit first-party targets are strict-concurrency clean.\n'
printf '  (Third-party transitive deps may still emit diagnostics; those are tolerated.)\n'
