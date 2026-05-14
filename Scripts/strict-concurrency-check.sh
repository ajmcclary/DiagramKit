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

set +e
swift build \
  -Xswiftc -swift-version -Xswiftc 6 \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors \
  >"$LOG" 2>&1
BUILD_EXIT=$?
set -e

if grep -E "Sources/DiagramKit[^/]*/" "$LOG" | grep -E "(error|warning):" >&2; then
  printf '\n\xE2\x9D\x8C DiagramKit first-party code emitted strict-concurrency diagnostics. See above.\n'
  exit 1
fi

# A non-zero build exit is tolerated only if it's caused by third-party
# diagnostics that don't reference first-party `Sources/DiagramKit*` paths.
# Look for the success marker; if `swift build` failed without producing
# it, we cannot truthfully claim "first-party clean."
if [ "$BUILD_EXIT" -ne 0 ] && ! grep -q "Build complete!" "$LOG"; then
  printf '\n\xE2\x9D\x8C swift build failed (exit %d) without producing "Build complete!" — cannot validate first-party clean.\n' "$BUILD_EXIT"
  tail -n 40 "$LOG" >&2 || true
  exit 1
fi

printf '\xE2\x9C\x93 DiagramKit first-party targets are strict-concurrency clean.\n'
printf '  (Third-party transitive deps may still emit diagnostics; those are tolerated.)\n'
