# BASELINES.md

Last updated: 2026-05-19

For the closed Critical-finding/commit map, the 2026-05-14 rebaseline
event log, and the post-remediation feature-work table, see
[docs/archive/BASELINES-history.md](docs/archive/BASELINES-history.md).

## Build

- `swift build --build-tests`: ~22–27s on a MacBook Pro M4 (24 GB)
  after the Phase 4 target split. Steady-state incremental builds are
  still sub-2s. `Scripts/strict-concurrency-check.sh`: clean.

## Tests

- Test source files: 298 Swift files under `Tests/DiagramKitTests`
  (300 total: 298 + 2 in `Tests/DiagramKitLinuxTests`). The 15-file XCUI
  bundle that previously lived alongside the sample was removed on
  2026-05-18 when the sample relocated to `Sources/DiagramKitSample/`.
- `swift test` excluding corpus snapshots: ~30s.
- `swift test --filter CorpusSnapshotTests`: ~5 min; use chunked
  execution for recording. The known signal-10 hang on a full corpus
  run is unchanged from `main`.
- `swift test --filter CorpusMultiFormatSnapshotTests`: ~0.15s
  (424 test cases per test).

## Corpus

- `Sources/DiagramKitSample/Resources/test-diagrams.json`:
  **424 entries** (397 Mermaid-only + 27 multi-format: D2, DOT,
  Structurizr, PlantUML).
- Multi-format entries carry `sources`, `expectedImporters`, and
  (where needed) `skipSnapshots`.
- Non-Mermaid Structurizr and PlantUML snapshots are skipped due to
  non-deterministic rendering.
- Chunked execution via `SNAPSHOT_DIAGRAM_IDS` avoids the signal-10
  hang in the parameterized suite.

## Snapshot baselines

`swift-snapshot-testing` stores SVG and ASCII snapshots with a `.txt`
extension; image snapshots are `.png`. The split below is by snapshot
*kind*, not file extension.

- SVG: **437** (424 Mermaid corpus + 13 multi-format).
- Image: **437** (424 Mermaid corpus + 13 multi-format).
- ASCII: **424** (one per corpus entry — Phases 7–11 added renderers
  for the remaining 23 families).
- Total tracked corpus baselines: **1,298** files
  (437 PNG + 861 `.txt`).

## Gate status

- `swift build --build-tests`: pass (2026-05-15).
- `Scripts/check-file-sizes.sh`: pass — warning-only surface, no
  1000-line errors. 55 files over the 500-line warning threshold;
  9 files over the 1000-line hard limit are allowlisted in
  `Scripts/check-file-sizes-allowlist.txt`.
- `Scripts/check-sendable-annotations.sh`: pass — 12 yellow allowlist
  entries remaining (sunset `2027-06-30`).
- `Scripts/strict-concurrency-check.sh`: pass.
- `Scripts/linux-check.sh`: skips as an environment condition when
  Docker/Podman is missing or installed but not usable. CI honors
  `SKIP_LINUX_CHECK=1`.
- `Scripts/bootstrap-smoke-check.sh`: aggregating gates pass; Xcode
  platform builds are skipped in the headless workspace and recorded
  as environment skips by `run_build`.

## Mermaid exporter coverage

- **2026-05-19 — Wave 3 (3 families, closing wave):** Mermaid Export
  column moves from 25/28 to 28/28. New exporters: `block`,
  `architecture`, `wardleyBeta`. `block` reuses Wave 1's
  `emitIndentedTree` (5th caller after mindmap, treemap, treeView,
  ishikawa); `architecture` and `wardleyBeta` emit linearly with no
  helper reuse. 6 new round-trip fixture files under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. Same-format
  round-trip suite grows from 34 to 37 family arms. The
  `MermaidExporter.export(_:)` switch is now **exhaustive at 28/28**;
  the `default: .unsupportedDiagram` fall-through is removed. The
  Swift compiler's exhaustiveness check is the compile-time
  invariant. `CorpusRoundTripTests` passes for every Mermaid corpus
  entry in the now-fully-supported set with no additions to
  `knownFailures`. Spec
  [docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md)
  is closed.
- **2026-05-19 — Wave 2 (9 families):** Mermaid Export column moves
  from 16/28 to 25/28. New exporters: `xyChart`, `quadrantChart`,
  `requirement`, `radar`, `venn`, `ishikawa`, `treeView`, `zenuml`,
  `eventModeling`. `ishikawa` and `treeView` reuse Wave 1's
  `emitIndentedTree`; no new helpers were extracted. 18 new
  round-trip fixture files under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. Same-format
  round-trip suite grows from 25 to 34 family arms. The
  `CorpusRoundTripTests` suite passes for every Mermaid corpus entry
  in the post-Wave-2 supported set with no additions to
  `knownFailures`. The `default: .unsupportedDiagram` arm in
  `MermaidExporter.export(_:)` stays for Wave 3.
- **2026-05-19 — Wave 1 (9 families):** Mermaid Export column in
  [COVERAGE.md](COVERAGE.md) moves from 7/28 to 16/28. New
  exporters: `pie`, `sankey`, `packet`, `journey`, `timeline`,
  `kanban`, `mindmap`, `treemap`, `gitGraph`. Shared scaffolding
  additions: `MermaidExportHelpers.emitSectionedItems` (used by
  journey + timeline) and `MermaidExportHelpers.emitIndentedTree`
  (used by mindmap + treemap). 18 new round-trip fixture files
  under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
  Same-format round-trip suite grows from 16 to 25 family arms.
  New `CorpusRoundTripTests` walks every Mermaid corpus entry in
  the supported set through `parse → export → parse →
  assertStructurallyEqual`; pre-existing exporter divergences in
  non-Wave-1 families (flowchart, state, sequence, class, ER) are
  tracked in `CorpusRoundTripTests.knownFailures` for drain via
  later waves. Wave 2 (`xyChart`, `quadrantChart`, `requirement`,
  `radar`, `venn`, `ishikawa`, `zenuml`, `treeView`,
  `eventModeling`) and Wave 3 (`block`, `architecture`,
  `wardleyBeta`) plans land in
  `docs/superpowers/plans/`.

## Open deferrals

- **EventModeling tests** — `EventModelingTests.swift` remains a
  single monolithic XCTest file. Splitting per-concern (parser /
  layout / renderer / corpus fixture) is a separate scoped phase.
  Documented at the suite level so it stays discoverable.
- **`DiagramLayer.commonInit()` → `@MainActor`** — blocked on
  dropping `@preconcurrency QuartzCore`; documented in source.

## Merge-gate caveats

- `Scripts/bootstrap-smoke-check.sh` no longer fails fast: every
  governance script and platform build runs, failures aggregate, and
  the script exits non-zero only if at least one gate reported
  failure. The complete failure surface is visible in a single local
  invocation.
- `Scripts/linux-check.sh` is environment-aware: if neither `docker`
  nor `podman` is on `PATH`, if the selected runtime is installed but
  not usable, or if `SKIP_LINUX_CHECK=1` is set, it exits 0 with a
  notice. Real container build/run failures still exit non-zero.
- `swift test` still hits the documented signal-10 hang on a full
  corpus run; chunked execution via `SNAPSHOT_DIAGRAM_IDS` remains
  the recommended workflow for recording or verifying snapshots.

## Continuous integration

`.github/workflows/ci.yml` runs every PR on a macOS runner: package
dump, build, test, the three governance scripts, and
`linux-check.sh` with `SKIP_LINUX_CHECK=1` (the macOS runner image
does not ship a container runtime). The local merge gate adds the
Xcode platform sweep and a real `linux-check.sh` against the
maintainer's installed runtime.
