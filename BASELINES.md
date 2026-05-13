# BASELINES.md

Last updated: 2026-05-13 (Phase 10 completion)

## Build
- `swift build --build-tests`: 14.69s (MacBook Pro M4, 24 GB; Phase 10)
- `Scripts/strict-concurrency-check.sh`: clean

## Tests
- Test source files: 188 Swift files under `Tests/DiagramKitTests`
- `swift test` excluding corpus snapshots: ~30s
- `swift test --filter CorpusSnapshotTests`: ~5 min; use chunked execution for recording
- `swift test --filter CorpusMultiFormatSnapshotTests`: ~0.15s (422 test cases per test)

## Corpus
- `test-diagrams.json`: 426 entries (408 Mermaid + 18 multi-format: D2, DOT, Structurizr, PlantUML)
- Version: 2.0.0
- Multi-format entries carry `sources`, `expectedImporters`, and (where needed) `skipSnapshots`
- Structurizr and PlantUML snapshots skipped due to non-deterministic rendering
- Chunked execution via `SNAPSHOT_DIAGRAM_IDS` avoids signal-10 in parameterized suite

## Snapshot Baselines
- SVG: 609 (Mermaid + multi-format)
- Image: 435 (Mermaid + multi-format)
- ASCII: 174 (Mermaid-only)
- Total tracked corpus baselines: 1045 files

## Gate Status
- `swift build --build-tests`: pass (2026-05-13)
- `Scripts/check-file-sizes.sh`: pass (2026-05-13, pre-existing warnings only)
- `Scripts/check-sendable-annotations.sh`: pass (2026-05-13)
- `Scripts/strict-concurrency-check.sh`: pass (2026-05-13)
- `Scripts/linux-check.sh`: skipped (2026-05-13; Docker/Podman not running)
