# BASELINES.md

Last updated: 2026-05-12

## Build
- `swift build --build-tests`: ~16s (MacBook Pro M4, 24 GB)
- `swift build -strict-concurrency=complete -warnings-as-errors`: clean

## Tests
- `swift test`: ~XXX test suites, ~XXX test cases (approx. X minutes)
- `SNAPSHOT_DIAGRAM_IDS=... swift test --filter CorpusSnapshotTests/imageSnapshot`: ~5 min

## Snapshot Baselines
- SVG: 396 entries
- Image: 346 entries (50 gap: layouts producing 0x0 bounds)
- ASCII: 172 entries

## Gate Status
- `Scripts/check-file-sizes.sh`: pass
- `Scripts/check-sendable-annotations.sh`: pass
- `Scripts/strict-concurrency-check.sh`: pass
- `Scripts/linux-check.sh`: pass
