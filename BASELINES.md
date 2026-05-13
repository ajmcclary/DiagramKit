# BASELINES.md

Last updated: 2026-05-13

## Build
- `swift build --build-tests`: 22.23s (MacBook Pro M4, 24 GB; observed during Phase 0 remediation)
- `Scripts/strict-concurrency-check.sh`: clean in the Phase 0 gate run

## Tests
- Test source files: 188 Swift files under `Tests/DiagramKitTests`
- `swift test` excluding corpus snapshots: ~30s
- `swift test --filter CorpusSnapshotTests`: ~5 min; use chunked execution for recording

## Snapshot Baselines
- SVG: ~439 entries (Mermaid-only) + multi-format suffixed
- Image: ~439 entries (Mermaid-only) + multi-format suffixed
- ASCII: 174 entries (Mermaid-only)
- Multi-format baselines: D2, DOT, Structurizr, PlantUML (format-suffixed, e.g. `*-d2.txt`, `*-graphviz.txt`)
- Total tracked corpus baselines: ~1000+ files

## Corpus
- `test-diagrams.json`: 439 entries (396 original Mermaid + ~43 multi-format: D2, DOT, Structurizr, PlantUML)
- Version: 2.1.0 (Phase 10 corpus expansion)

## Gate Status
- `swift build --build-tests`: pass (2026-05-12, Phase 5 remediation)
- `Scripts/check-file-sizes.sh`: pass (2026-05-12, pre-existing warnings only)
- `Scripts/check-sendable-annotations.sh`: pass (2026-05-12)
- `Scripts/strict-concurrency-check.sh`: pass (2026-05-13)
- `Scripts/linux-check.sh`: skipped (2026-05-13; Docker/Podman not running)
