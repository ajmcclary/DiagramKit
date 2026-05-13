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

## Merge-gate caveats

- `Scripts/bootstrap-smoke-check.sh` no longer fails fast: every governance
  script and platform build runs, failures aggregate, and the script exits
  non-zero only if at least one gate reported failure. This means you see
  the complete failure surface in a single local invocation.
- `Scripts/linux-check.sh` is environment-aware: if neither `docker` nor
  `podman` is on `PATH`, or if `SKIP_LINUX_CHECK=1` is set, it exits 0
  with a notice. Real container failures still exit non-zero.
- `swift test` still hits the documented signal-10 hang on a full corpus
  run; chunked execution via `SNAPSHOT_DIAGRAM_IDS` remains the
  recommended workflow for recording or verifying snapshots.

## Continuous integration

`.github/workflows/ci.yml` runs every PR on a macOS runner: package dump,
build, test, the three governance scripts, and `linux-check.sh` with
`SKIP_LINUX_CHECK=1` (the macOS runner image does not ship a container
runtime). The local merge gate adds the Xcode platform sweep and a real
`linux-check.sh` against the maintainer's installed runtime.
