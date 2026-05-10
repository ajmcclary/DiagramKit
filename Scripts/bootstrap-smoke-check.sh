#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

status=0

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

swift package dump-package
swift test
"$ROOT/Scripts/check-file-sizes.sh"
"$ROOT/Scripts/strict-concurrency-check.sh"
"$ROOT/Scripts/check-sendable-annotations.sh" || status=1
"$ROOT/Scripts/linux-check.sh"
run_build "iOS" 'generic/platform=iOS'
run_build "visionOS" 'generic/platform=visionOS'
run_build "tvOS" 'generic/platform=tvOS'

exit "$status"
