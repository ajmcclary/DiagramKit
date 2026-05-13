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
- `test-diagrams.json`: 422 entries (396 Mermaid-only + 26 multi-format: D2, DOT, Structurizr, PlantUML)
- Version: 2.1.0
- Multi-format entries carry `sources`, `expectedImporters`, and (where needed) `skipSnapshots`
- Non-Mermaid Structurizr and PlantUML snapshots are skipped due to non-deterministic rendering
- Chunked execution via `SNAPSHOT_DIAGRAM_IDS` avoids signal-10 in parameterized suite

## Snapshot Baselines
- SVG: 435 (422 corpus entries + 13 non-Mermaid multi-format)
- Image: 435 (422 corpus entries + 13 non-Mermaid multi-format)
- ASCII: 174 (Mermaid-only)
- Text snapshots: 609 (SVG + ASCII)
- Total tracked corpus baselines: 1044 files

## Gate Status
- `swift build --build-tests`: pass (2026-05-13)
- `Scripts/check-file-sizes.sh`: pass (2026-05-13, pre-existing warnings only)
- `Scripts/check-sendable-annotations.sh`: pass (2026-05-13)
- `Scripts/strict-concurrency-check.sh`: pass (2026-05-13)
- `Scripts/linux-check.sh`: skipped (2026-05-13; Docker/Podman not running)
