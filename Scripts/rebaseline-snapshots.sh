#!/usr/bin/env bash
# Scripts/rebaseline-snapshots.sh
#
# Re-records CorpusSnapshotTests baselines in chunks small enough to
# avoid the documented swift-testing × swift-snapshot-testing signal-10
# hang at full-corpus parameterized scale.
#
# Usage:
#   Scripts/rebaseline-snapshots.sh [--target svg|image|both] [--chunk N] [--dry-run]
#
# Defaults: --target both, --chunk 20.
# Idempotent: re-running picks up .rebaseline-logs/missing-<target>.txt
# and re-records only those IDs.
#
# Spec: docs/superpowers/specs/2026-05-14-svg-palette-audit-rebaseline-design.md

set -euo pipefail

TARGET="both"
CHUNK=20
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --chunk)  CHUNK="$2";  shift 2 ;;
        --dry-run) DRY_RUN=1;  shift ;;
        -h|--help)
            sed -n '1,/^set -euo/p' "$0" | sed -n 's/^# \{0,1\}//p'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

case "$TARGET" in
    svg|image|both) ;;
    *) echo "--target must be svg|image|both" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

mkdir -p .rebaseline-logs

JSON="Sources/DiagramKitSample/Resources/test-diagrams.json"
if [ ! -f "$JSON" ]; then
    echo "Corpus file missing: $JSON" >&2
    exit 1
fi

# Extract IDs (jq preferred, sed fallback).
if command -v jq >/dev/null 2>&1; then
    mapfile -t ALL_IDS < <(jq -r '.diagrams[].id' "$JSON")
else
    mapfile -t ALL_IDS < <(grep -oE '"id"\s*:\s*"[^"]+"' "$JSON" \
        | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
fi
echo "Found ${#ALL_IDS[@]} corpus entries."

record_target() {
    local name="$1"        # svg | image | svg-mf | image-mf
    local filter="$2"      # CorpusSnapshotTests/svgSnapshot, etc.

    local missing_file=".rebaseline-logs/missing-${name}.txt"
    local ids=()
    if [ -s "$missing_file" ]; then
        echo "[$name] resuming from $missing_file"
        mapfile -t ids < "$missing_file"
    else
        ids=( "${ALL_IDS[@]}" )
    fi
    rm -f "$missing_file"

    local total=${#ids[@]}
    local chunks=$(( (total + CHUNK - 1) / CHUNK ))
    local failed_chunks=()

    local idx=0
    for ((i=0; i<total; i+=CHUNK)); do
        idx=$((idx+1))
        local slice=( "${ids[@]:i:CHUNK}" )
        local csv
        csv=$(IFS=,; echo "${slice[*]}")
        local log=".rebaseline-logs/${name}-chunk-${idx}.log"
        echo "[$name $idx/$chunks] recording ${#slice[@]} entries → $log"

        if [ "$DRY_RUN" = "1" ]; then
            echo "  DRY: SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=$csv swift test --filter $filter"
            continue
        fi

        if ! SNAPSHOT_TESTING_RECORD=all \
             SNAPSHOT_DIAGRAM_IDS="$csv" \
             swift test --filter "$filter" > "$log" 2>&1; then
            echo "  CHUNK $idx FAILED (see $log)"
            failed_chunks+=( "$idx" )
            printf '%s\n' "${slice[@]}" >> "$missing_file"
        fi
    done

    if [ "${#failed_chunks[@]}" -gt 0 ]; then
        echo "[$name] failed chunks: ${failed_chunks[*]} — re-run to retry missing IDs"
    else
        echo "[$name] all ${total} entries recorded ✓"
    fi
}

case "$TARGET" in
    svg)
        record_target svg    "CorpusSnapshotTests/svgSnapshot"
        record_target svg-mf "CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot" || true
        ;;
    image)
        record_target image    "CorpusSnapshotTests/imageSnapshot"
        record_target image-mf "CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot" || true
        ;;
    both)
        record_target svg      "CorpusSnapshotTests/svgSnapshot"
        record_target svg-mf   "CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot" || true
        record_target image    "CorpusSnapshotTests/imageSnapshot"
        record_target image-mf "CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot" || true
        ;;
esac
