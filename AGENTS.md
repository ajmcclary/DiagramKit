# AGENTS.md

Native Swift mermaid-js port that now ships a multi-format DiagramKit
(Mermaid + D2 + Graphviz DOT + Structurizr + PlantUML). For invariants
and conventions, read `CLAUDE.md` first. For architecture details, read
[ARCHITECTURE.md](ARCHITECTURE.md). For current metrics, read
[BASELINES.md](BASELINES.md). For historical context (completed phases,
plans, and the shipped review-remediation cycle), see
[docs/archive/](docs/archive/).

The package ships **14 layered SwiftPM library products**. Imports flow
strictly downward:

```text
DiagramKitCommon           (Linux + Apple)
   ^
DiagramKitModel            (Linux + Apple, partial)
   ^
   +-----------+-----------+-----------+-----------+-----------+
DiagramKitRenderingCG  DiagramKitImport  DiagramKitExport  DiagramKitTestSupport  format slices:
   (Apple-only)        (Linux + Apple)   (Linux + Apple)   (Linux + Apple)        DiagramKitMermaid / D2 / Graphviz / Structurizr / PlantUML
   ^
DiagramKitViews            (Apple-only)
   ^                       DiagramKitInteractive (Apple-only)
DiagramKit                 (umbrella public API + re-exports)
```

Apple-only edges to `DiagramKitRenderingCG`, `DiagramKitViews`, and
`DiagramKitInteractive` are guarded in `Package.swift` with
`condition: .when(platforms: [Apple])`.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # corpus snapshots (~5 min; see caveats)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot
swift run DiagramKitSample                          # SwiftUI sample app

# Record/refresh snapshot baselines:
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot

# After editing Package.swift:
swift package resolve
```

There is no separate lint/format/typecheck step. Use `swift test` plus the gates
below.

## Verification Gates

`Scripts/bootstrap-smoke-check.sh` is the full local merge gate. It chains
`swift package dump-package`, `swift test`, the governance gates, Linux check,
and a multiplatform `xcodebuild` sweep.

- `Scripts/check-file-sizes.sh` - 500 warn / 1000 error per `.swift` file.
- `Scripts/check-sendable-annotations.sh` - every `@unchecked Sendable` must be
  allowlisted or carry a "Concurrency Contract" banner.
- `Scripts/strict-concurrency-check.sh` - first-party strict-concurrency build.
- `Scripts/linux-check.sh` - Docker/Podman build of the Linux-portable matrix.
  If Docker/Podman is missing or not running locally, record it as skipped due
  to environment; do not treat that as a source failure.

## Critical Constraints

- **Never introduce a thread pool.** Public entry points use a fresh 8 MB-stack
  worker thread via `DiagramEngine._runOnWorker` / `DiagramWorkerThread.run`.
  This was tried and reverted in `ff2622b`.
- **`DiagramFontRegistry.registerBundledFontsIfNeeded()` must be called first**
  in every pipeline method. Skipping it breaks snapshot determinism.
- **Parser dispatch order matters.** `Sources/DiagramKit/DiagramDescriptor.swift`
  uses cascading `firstLine.hasPrefix(...)`; narrower prefixes must come
  before broader ones.
- **Two independent renderers exist.** CG/image renderers live in
  `DiagramKitRenderingCG`; SVG renderers live in `DiagramKitModel`. They drift;
  snapshots are the guardrail.
- **Use `bmColorEquals()` for color comparisons**, not `hexString` round-trips.

## Conventions

- Public API: `async throws` static methods on `DiagramEngine` or
  `DiagramImageRenderer`.
- Deprecated Mermaid-prefixed names remain for compatibility. Use
  Diagram-prefixed names in new code.
- `@MainActor` only on methods that produce/consume `BMImage`, `CGContext`, or
  native UI types. `renderSVG` and `renderASCII` are intentionally not
  main-actor.
- Underscore-prefixed top-level names (`_PositionedNodePayload`,
  `_renderDiagramSVG`) are SPI. Use public typealiases such as `PositionedNode`
  outside the module.
- Font family: route through `RenderConfig.defaultFontFamily` /
  `defaultProportionalFontFamily`. Never hardcode `"Menlo"`, `"Trebuchet MS"`,
  etc. in a renderer.
- Type-safe payloads: pattern-match `graph.typedPayload` / `graph.content`;
  never cast to `Any`.

## Current Roadmap

Feature-complete. Phases 0–10 plus the follow-on Phases 1–11 (DOT
exporter, full PlantUML family coverage, ASCII renderers for all 28
families) have landed. Format-neutral public names are primary;
Mermaid-prefixed aliases carry deprecation annotations (Tier 1) or
have been removed (Tier 2). Importers and exporters cover Mermaid,
D2, Graphviz DOT, Structurizr, and PlantUML (sequence + class +
state/activity + mindmap + gantt + C4). The active backlog is currently
empty; the completed roadmap lives in [docs/archive/PHASES.md](docs/archive/PHASES.md).

## Testing

- Test sources: 299 Swift files under `Tests/DiagramKitTests`
  (301 total incl. `Tests/DiagramKitLinuxTests`). The XCUI bundle was
  removed alongside the 2026-05-18 sample-app relocation.
- Corpus: `Sources/DiagramKitSample/Resources/test-diagrams.json`
  (424 entries: 397 Mermaid-only + 27 multi-format with D2, DOT, Structurizr, PlantUML sources).
- Snapshot baselines:
  - SVG: 437 (424 Mermaid corpus + 13 non-Mermaid multi-format)
  - Image: 437 (424 Mermaid corpus + 13 non-Mermaid multi-format)
  - ASCII: 424 (one per corpus entry — Phases 7–11 closed the renderer-coverage gap)
- Total tracked: 1,298 files (437 PNG + 861 `.txt`;
  `swift-snapshot-testing` writes SVG and ASCII as `.txt`).
- `CorpusMultiFormatSnapshotTests` renders every `(entry, format)` pair with
  format-suffixed snapshot names (`entry-id-format`), honoring `skipSnapshots`.
  Chunked execution with `SNAPSHOT_DIAGRAM_IDS` avoids the known signal-10
  parameterized-suite issue.
- Image snapshots use `precision: 0.99, perceptualPrecision: 0.98`.
- Pure renames should not re-record snapshots. Re-record only for intentional
  rendering or fixture changes.

## Dependencies

- `swift-custom-dump` and `xctest-dynamic-overlay` (IssueReporting) are upstream
  pointfreeco releases.
- `swift-snapshot-testing` is pinned to
  `ajmcclary/swift-snapshot-testing`, branch `fix-swift-6.3-attachable`, while
  pointfreeco PR #1090 awaits an upstream tagged release.
- `swiftLanguageModes: [.v6]` is enforced; public types are `Sendable`.
