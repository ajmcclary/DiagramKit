# BASELINES.md

Last updated: 2026-05-12

## Build
- `swift build --build-tests`: 22.23s (MacBook Pro M4, 24 GB; observed during Phase 0 remediation)
- `Scripts/strict-concurrency-check.sh`: clean in the Phase 0 gate run

## Tests
- Test source files: 150 Swift files under `Tests/DiagramKitTests`
- `swift test` excluding corpus snapshots: ~30s in the Phase 0 run notes
- `swift test --filter CorpusSnapshotTests`: ~5 min; see README for the current parameterized harness caveat

## Snapshot Baselines
- SVG: 396 entries
- Image: 396 entries
- ASCII: 174 entries
- Total tracked corpus baselines: 966 files

## Gate Status
- `swift build --build-tests`: pass (2026-05-12)
- `Scripts/check-file-sizes.sh`: pass in the Phase 0 gate run
- `Scripts/check-sendable-annotations.sh`: pass in the Phase 0 gate run
- `Scripts/strict-concurrency-check.sh`: pass in the Phase 0 gate run
- `Scripts/linux-check.sh`: skipped in this local pass because Docker/Podman was not running
