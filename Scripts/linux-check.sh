#!/usr/bin/env bash
# Builds the Linux-portable DiagramKit targets via swift:6.3.1-noble.
# Mirrors MusicToolkit/Scripts/... pattern.
#
# Picks podman if available, else docker. Build context is the package root.

set -euo pipefail

if command -v podman >/dev/null 2>&1; then
    runtime=podman
elif command -v docker >/dev/null 2>&1; then
    runtime=docker
else
    echo "error: neither podman nor docker found in PATH" >&2
    exit 2
fi

"$runtime" build -f Dockerfile.linux-check -t diagramkit-linux-check .
"$runtime" run --rm diagramkit-linux-check
