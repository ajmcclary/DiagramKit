#!/usr/bin/env bash
# Regression gate for linux-check.sh's environment-skip contract.
#
# An installed but unusable container runtime (for example Docker Desktop not
# running) is an environment skip, not a source failure, and linux-check.sh
# must not attempt a build in that state.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

MOCK_DOCKER="$TMPDIR/docker"
{
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf '%s\n' 'if [[ "${1:-}" == "info" ]]; then'
    printf '%s\n' '    exit 1'
    printf '%s\n' 'fi'
    printf '%s\n' 'echo "unexpected docker invocation: $*" >&2'
    printf '%s\n' 'exit 42'
} > "$MOCK_DOCKER"
chmod +x "$MOCK_DOCKER"
cp "$MOCK_DOCKER" "$TMPDIR/podman"

OUTPUT="$(PATH="$TMPDIR:$PATH" "$ROOT/Scripts/linux-check.sh" 2>&1)"

if ! grep -q "recording environment skip" <<<"$OUTPUT"; then
    echo "$OUTPUT" >&2
    echo "Expected linux-check.sh to record an environment skip." >&2
    exit 1
fi
