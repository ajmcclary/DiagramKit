#!/usr/bin/env bash

# Local merge gate: runs every governance script and platform build, aggregates
# failures, and exits non-zero only if at least one gate failed. The shell does
# NOT `set -e` because we explicitly want every gate to run so the operator sees
# the complete failure surface in a single invocation.
#
# Environment skips:
#   SKIP_LINUX_CHECK=1   — skip the Docker/Podman Linux build (still reported).
#   Missing Xcode platform runtimes — skipped by `run_build` with a notice.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

status=0

run_gate() {
  local name="$1"
  shift
  printf '\n==> %s\n' "$name"
  if ! "$@"; then
    printf '\n❌ Gate failed: %s\n' "$name"
    status=1
    return 1
  fi
  return 0
}

run_build() {
  local platform="$1"
  local destination="$2"
  local output

  printf '\n==> Building for %s\n' "$platform"

  if ! output=$(xcodebuild -scheme DiagramKit-Package -destination "$destination" build 2>&1); then
    printf '%s\n' "$output"

    if grep -q "Please download and install the platform from Xcode > Settings > Components" <<<"$output"; then
      printf '\n%s\n' "Skipping $platform build because the platform runtime is not installed in Xcode."
      return
    else
      printf '\n%s\n' "Bootstrap smoke check failed while building $platform."
    fi

    status=1
    return
  fi

  printf '%s\n' "$output"
}

run_gate "swift package dump-package" swift package dump-package
# Corpus parameterized snapshot suites are run separately below so a known
# swift-testing + swift-snapshot-testing signal-10 in the parameterized harness
# does not abort the whole gate (see CLAUDE.md "Testing And Snapshots").
run_gate "swift test (non-corpus)" \
  swift test \
  --skip "CorpusSnapshotTests" \
  --skip "CorpusMultiFormatSnapshotTests"
run_gate "swift test (round-trip)" \
  swift test --filter "RoundTrip"
run_gate "swift test (corpus SVG)" \
  swift test --filter "CorpusSnapshotTests/svgSnapshot"
run_gate "swift test (corpus ASCII)" \
  swift test --filter "CorpusSnapshotTests/asciiSnapshot"
run_gate "swift test (corpus image)" \
  swift test --filter "CorpusSnapshotTests/imageSnapshot"
run_gate "swift test (corpus multi-format SVG)" \
  swift test --filter "CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot"
run_gate "swift test (corpus multi-format image)" \
  swift test --filter "CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot"
run_gate "check-file-sizes.sh" "$ROOT/Scripts/check-file-sizes.sh"
run_gate "strict-concurrency-check.sh" "$ROOT/Scripts/strict-concurrency-check.sh"
run_gate "check-sendable-annotations.sh" "$ROOT/Scripts/check-sendable-annotations.sh"
run_gate "check-stale-phase-comments.sh" "$ROOT/Scripts/check-stale-phase-comments.sh"
run_gate "linux-check.sh" "$ROOT/Scripts/linux-check.sh"

run_build "iOS" 'generic/platform=iOS'
run_build "visionOS" 'generic/platform=visionOS'
run_build "tvOS" 'generic/platform=tvOS'

if [[ "$status" -eq 0 ]]; then
  printf '\n✓ All gates passed.\n'
else
  printf '\n❌ One or more gates failed. See output above.\n'
fi

exit "$status"
