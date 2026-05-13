# AGENTS.md

Native Swift mermaid-js port moving toward a multi-format DiagramKit. For
invariants and conventions, read `CLAUDE.md` first. For architecture details,
read [ARCHITECTURE.md](ARCHITECTURE.md). For the active roadmap, read
[PHASES.md](PHASES.md). For Phase 0 rename history, read
[PHASE-0.md](PHASE-0.md). For current metrics, read
[BASELINES.md](BASELINES.md).

The package has six layered targets:

`DiagramKitCommon` (Linux+Apple) -> `DiagramKitModel` (Linux+Apple) ->
`DiagramKitRenderingCG` (Apple-only) / `DiagramKitTestSupport` (Linux+Apple) /
`DiagramKitViews` (Apple-only) -> `DiagramKit` (umbrella public API and
re-exports).

Imports flow strictly along that direction.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # corpus snapshots (~5 min; see caveats)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot
swift run MermaidPlayground                         # SwiftUI sample app

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
  If Docker/Podman is not running locally, record it as skipped due to
  environment; do not treat that as a source failure.

## Critical Constraints

- **Never introduce a thread pool.** Public entry points use a fresh 8 MB-stack
  worker thread via `DiagramEngine._runOnWorker` / `DiagramWorkerThread.run`.
  This was tried and reverted in `ff2622b`.
- **`DiagramFontRegistry.registerBundledFontsIfNeeded()` must be called first**
  in every pipeline method. Skipping it breaks snapshot determinism.
- **Parser dispatch order matters.** `Parser.swift` uses cascading
  `firstLine.hasPrefix(...)`; narrower prefixes must come before broader ones.
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

Phase 0 is complete: format-neutral public names are primary, deprecated
Mermaid aliases remain, and corpus baselines are current. The next work is the
importer boundary:

1. Add `DiagramSourceImporter`, `DiagramImportResult`, `DiagramDiagnostic`,
   `ImporterRegistry`, and `DiagramLoader`.
2. Extract the current Mermaid source routing behind `MermaidImporter`.
3. Keep `DiagramDocument -> PositionedGraph -> render` source-format neutral.
4. Make the corpus multi-format before adding d2/DOT/Structurizr/PlantUML.

Do not start a new format parser before that boundary exists.

## Testing

- Test sources: 188 Swift files under `Tests/DiagramKitTests`.
- Corpus: `Examples/MermaidPlayground/Resources/test-diagrams.json`
  (396 Mermaid entries).
- Snapshot baselines:
  - SVG: 396
  - Image: 396
  - ASCII: 174
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

