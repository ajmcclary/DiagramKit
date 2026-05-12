# BASELINES.md

Last updated: 2026-05-12

## Build
- `swift build --build-tests`: 22.23s (MacBook Pro M4, 24 GB; observed during Phase 0 remediation)
- `Scripts/strict-concurrency-check.sh`: clean in the Phase 0 gate run

## Tests
- Test source files: 169 Swift files under `Tests/DiagramKitTests`
- `swift test --filter Structurizr`: 96 tests in 10 suites (Phase 5 remediation)
- `swift test` excluding corpus snapshots: ~30s in the Phase 0 run notes
- `swift test --filter CorpusSnapshotTests`: ~5 min; see README for the current parameterized harness caveat

## Snapshot Baselines
- SVG: 396 entries
- Image: 396 entries
- ASCII: 174 entries
- Total tracked corpus baselines: 966 files

## Gate Status
- `swift build --build-tests`: pass (2026-05-12, Phase 5 remediation)
- `Scripts/check-file-sizes.sh`: pass (2026-05-12, pre-existing warnings only)
- `Scripts/check-sendable-annotations.sh`: pass (2026-05-12)
- `Scripts/strict-concurrency-check.sh`: pass (2026-05-12)
- `Scripts/linux-check.sh`: skipped in this local pass because Docker/Podman was not running
