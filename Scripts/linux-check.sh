#!/usr/bin/env bash
# Builds the Linux-portable DiagramKit targets via swift:6.3.1-noble.
# Mirrors MusicToolkit/Scripts/... pattern.
#
# Picks podman if available, else docker.
#
# Environment skips:
#   SKIP_LINUX_CHECK=1   — exit 0 immediately with a skip notice (CI use).
#   No podman or docker — exit 0 with an environment-skip notice; the
#                         absence of a container runtime is not a source
#                         failure. Actual container build failures still
#                         exit non-zero.

set -euo pipefail

if [[ "${SKIP_LINUX_CHECK:-0}" = "1" ]]; then
    echo "linux-check.sh: SKIP_LINUX_CHECK=1, skipping container build."
    exit 0
fi

if command -v podman >/dev/null 2>&1; then
    runtime=podman
elif command -v docker >/dev/null 2>&1; then
    runtime=docker
else
    echo "linux-check.sh: neither podman nor docker found in PATH; recording environment skip."
    exit 0
fi

if ! "$runtime" info >/dev/null 2>&1; then
    echo "linux-check.sh: $runtime found but not usable; recording environment skip."
    exit 0
fi

"$runtime" build -f Dockerfile.linux-check -t diagramkit-linux-check .
"$runtime" run --rm diagramkit-linux-check
