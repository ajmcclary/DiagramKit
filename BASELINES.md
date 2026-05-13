# BASELINES.md

Last updated: 2026-05-13 (Phase 8 — review remediation release verification)

## Build
- `swift build --build-tests`: ~22–27s on a MacBook Pro M4 (24 GB) after
  the Phase 4 target split. Steady-state incremental builds are still
  sub-2s. `Scripts/strict-concurrency-check.sh`: clean.

## Tests
- Test source files: 191 Swift files under `Tests/DiagramKitTests`
  (added in remediation: `DiagramPipelineReviewRegressionTests`,
  `DiagramViewReviewRegressionTests`, `FlowchartStateERReviewRegressionTests`).
- `swift test` excluding corpus snapshots: ~30s
- `swift test --filter CorpusSnapshotTests`: ~5 min; use chunked execution
  for recording. The known signal-10 hang on a full corpus run is
  unchanged from `main`.
- `swift test --filter CorpusMultiFormatSnapshotTests`: ~0.15s
  (422 test cases per test)

## Corpus
- `test-diagrams.json`: 422 entries (396 Mermaid-only + 26 multi-format:
  D2, DOT, Structurizr, PlantUML).
- Version: 2.1.0
- Multi-format entries carry `sources`, `expectedImporters`, and (where
  needed) `skipSnapshots`.
- Non-Mermaid Structurizr and PlantUML snapshots are skipped due to
  non-deterministic rendering.
- Chunked execution via `SNAPSHOT_DIAGRAM_IDS` avoids the signal-10 hang
  in the parameterized suite.

## Snapshot Baselines
- SVG: 435 (422 corpus entries + 13 non-Mermaid multi-format)
- Image: 435 (422 corpus entries + 13 non-Mermaid multi-format)
- ASCII: 174 (Mermaid-only)
- Text snapshots: 609 (SVG + ASCII)
- Total tracked corpus baselines: 1044 files

**Re-recorded during remediation:**
- 7 Gantt SVG baselines (`gantt-1` … `gantt-7`) — Phase 1.3 pinned the
  today-marker via `DIAGRAMKIT_GANTT_TODAY=2024-06-15`.
- 2 Block SVG baselines (`block-5-edges`, `block-7-architecture`) —
  Phase 6D fixed the D2-probe mis-routing.
- 2 Block image baselines (`block-5-edges`, `block-7-architecture`) —
  Phase 8 caught the corresponding image drift that exceeded the
  precision threshold.

## Gate Status
- `swift build --build-tests`: pass (2026-05-13)
- `Scripts/check-file-sizes.sh`: pass — pre-existing warnings only
  (10 files between 500–600 lines; `check-file-sizes-allowlist.txt`
  unchanged).
- `Scripts/check-sendable-annotations.sh`: pass — 12 yellow allowlist
  entries remaining (down from 14: `DiagramTheme` and
  `ArchitectureIconRegistry` went green in Phase 6A).
- `Scripts/strict-concurrency-check.sh`: pass
- `Scripts/linux-check.sh`: skipped (Docker/Podman not running in this
  workspace). CI honors `SKIP_LINUX_CHECK=1`.
- `Scripts/bootstrap-smoke-check.sh`: aggregating gates pass; Xcode
  platform builds are skipped in the headless workspace and recorded as
  environment skips by `run_build`.

## Review-remediation map (REVIEW.md Critical → closing commit)

| # | Critical finding | Phase | Commit |
| --- | --- | --- | --- |
| 1 | `DiagramPipeline.renderSVG` round-trips theme through `hexString` | 1 | `75d3244` |
| 2 | Block CG vs SVG `.round` shape mismatch | 1 | `75d3244` |
| 3 | `DiagramLayer.preparationTask` stale main-actor publish | 3 | `07aac8c` |
| 4 | `DiagramLayer.commonInit()` is `nonisolated` | 3 | `07aac8c` — documented constraint blocked on `@preconcurrency QuartzCore` |
| 5 | `DiagramView.bindPreparationUpdates` clobbers `onPrepareComplete` | 3 | `07aac8c` |
| 6 | `StructurizrExporter` alias sanitization | 2 | `81342f6` |
| 7 | `StructurizrExporter` emits tags/group the parser drops | 2 | `81342f6` |
| 8 | `PlantUMLSequenceExport.escape` newline normalization | 2 | `81342f6` |
| 9 | `DiagramKitExport → DiagramKitImport` dependency | 4 | `3b98dd6` |
| 10 | `MermaidExporter` inside the umbrella | 4 | `3b98dd6` |
| 11 | Gantt today-marker non-determinism | 1 | `75d3244` |
| 12 | `bootstrap-smoke-check.sh` + `linux-check.sh` policy | 5 | `cb1f082` |

Important-and-Minor backlog is closed across Phases 6A–6F + 7
(commits `7ae5c1c`, `c60574a`, `d35e849`, `d7d68dd`, `bcb7bae`,
`07cc87a`, `a20e94e`).

## Deferred follow-ups

- **EventModeling tests:** `EventModelingTests.swift` is a single
  monolithic XCTest file. Splitting per-concern (parser / layout /
  renderer / corpus fixture) is a separate scoped phase. Documented at
  the suite-level so it remains discoverable.
- **DOT exporter:** `DOTExporter` does not exist yet.
  `DiagramExportLoader.export(to: .graphviz, …)` returns a `.unsupported`
  diagnostic (Phase 6D), and PHASES.md flags the work.
- **PlantUML family slices:** importer + exporter coverage for class,
  state/activity, mindmap+gantt, and C4 import remains open.

## ASCII renderer coverage

Only 5 of the 28 diagram families ship ASCII renderers today
(`flowchart`, `sequence`, `class`, `er`, `state`); the remaining
23 families throw `DiagramError.notYetImplemented("… ASCII rendering")`
at render time and are deliberately excluded from `CorpusSnapshotTests/
asciiSnapshot` baselines. Promoting ASCII coverage to all 28 families
is a separate, scoped phase — see REVIEW.md "Important / Renderers".

## Merge-gate caveats

- `Scripts/bootstrap-smoke-check.sh` no longer fails fast: every
  governance script and platform build runs, failures aggregate, and the
  script exits non-zero only if at least one gate reported failure. The
  complete failure surface is visible in a single local invocation.
- `Scripts/linux-check.sh` is environment-aware: if neither `docker` nor
  `podman` is on `PATH`, or if `SKIP_LINUX_CHECK=1` is set, it exits 0
  with a notice. Real container failures still exit non-zero.
- `swift test` still hits the documented signal-10 hang on a full corpus
  run; chunked execution via `SNAPSHOT_DIAGRAM_IDS` remains the
  recommended workflow for recording or verifying snapshots.

## Continuous integration

`.github/workflows/ci.yml` runs every PR on a macOS runner: package
dump, build, test, the three governance scripts, and `linux-check.sh`
with `SKIP_LINUX_CHECK=1` (the macOS runner image does not ship a
container runtime). The local merge gate adds the Xcode platform sweep
and a real `linux-check.sh` against the maintainer's installed runtime.
