#!/usr/bin/env bash

set -euo pipefail

# Strict-concurrency gate for DiagramKit's first-party targets.
#
# The package pins `swiftLanguageModes: [.v6]`, so Swift 6 language mode —
# with its complete strict-concurrency checking — is already the per-target
# default. The former second compile with `-swift-version 6
# -strict-concurrency=complete` therefore re-checked the same code and cost a
# full rebuild on every run for no signal; it is gone.
#
# What this gate now enforces:
#   1. The manifest still pins `.v6`. Dropping that pin would silently
#      downgrade every target to Swift 5 mode and vacate the gate, so it is
#      checked explicitly.
#   2. The ordinary `swift build` emits no diagnostics originating from
#      first-party `Sources/DiagramKit*` code. (Incremental builds re-emit
#      diagnostics only for recompiled files; rule 1 is the durable
#      enforcement, this is the belt-and-braces sweep.)
#
# Do not pass global `-warnings-as-errors`: SwiftPM forwards it to dependencies,
# and Swift 6.3 rejects dependencies that intentionally use `-suppress-warnings`.
# Errors from third-party transitive dependencies are tolerated — those are
# out of our control and tracked separately.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! grep -qF 'swiftLanguageModes: [.v6]' Package.swift; then
  echo 'Package.swift no longer pins swiftLanguageModes: [.v6] — Swift 6 strict concurrency would no longer be the per-target default.' >&2
  exit 1
fi

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

printf '==> swift build (Swift 6 mode via swiftLanguageModes: [.v6])\n'

set +e
swift build >"$LOG" 2>&1
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
