# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## What This Is

DiagramKit is a native Swift port of [mermaid-js](https://mermaid.js.org/)
covering roughly 28 diagram families. It parses source into a typed
`DiagramDocument`, lays that into a `PositionedGraph`, and renders through Core
Graphics images, SVG, and ASCII.

## Documentation Map

This file is the source of truth for invariants and conventions. When scopes
overlap, preserve the constraints here and use the other docs for detail.

- [README.md](README.md) - public install and quick-start examples.
- [ARCHITECTURE.md](ARCHITECTURE.md) - layer diagram, pipeline details, drift
  hazards, and import rules.
- [PHASES.md](PHASES.md) - active multi-format roadmap from the current state.
- [PHASE-0.md](PHASE-0.md) - completed rename plan/history.
- [ANALYSIS.md](ANALYSIS.md) - long-form rationale and format analysis.
- [BASELINES.md](BASELINES.md) - current build, test, snapshot, and gate
  metrics.
- [CONTRIBUTING.md](CONTRIBUTING.md) - PR workflow, file-size policy, and
  green/yellow/red `@unchecked Sendable` policy.
- [ATTRIBUTION.md](ATTRIBUTION.md) - upstream Mermaid lineage and licenses.
- [AGENTS.md](AGENTS.md) - terse companion instructions for non-Claude agents.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile tests
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

There is no separate lint/format command. Verification is `swift test` plus the
discipline gates below.

## Target Layout

The package has six layered SwiftPM targets. Imports flow only downward.

```text
DiagramKitCommon           (Linux + Apple)  - SVG primitives, theme, text metrics, IssueReporting, StableID
   ^
DiagramKitModel            (Linux + Apple)  - parsers, layouts, SVG/ASCII renderers, payloads
   ^                                           UIKit/AppKit/CoreText files compile to empty on Linux
   +------------------+
DiagramKitRenderingCG     DiagramKitTestSupport
   (Apple-only)            (Linux + Apple)
   ^
DiagramKitViews            (Apple-only)     - DiagramView, DiagramNativeView, DiagramLayer, DiagramViewModel
   ^
DiagramKit                 (umbrella)       - public API + re-exports
```

`DiagramKit` re-exports the lower targets through `ReExports.swift`. Apple-only
edges to RenderingCG and Views are guarded in `Package.swift` with
`condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])`.

## Public Surface

- `DiagramEngine` is the public async facade.
- `DiagramPipeline` holds synchronous, nonisolated implementations.
- `DiagramImageRenderer` renders `BMImage` / PNG / JPEG.
- `DiagramDocument` is the canonical parsed model.
- `DiagramView`, `DiagramNativeView`, `DiagramLayer`, and `DiagramViewModel`
  live in `DiagramKitViews`.
- `String` helpers use format-neutral names:
  `parseDiagram()`, `renderDiagramImage(...)`, `renderDiagramSVG(...)`, and
  `renderDiagramASCII(...)`.
- Mermaid-prefixed public aliases carry `@available(*, deprecated, renamed:message:)`
  annotations and will be removed in the next major version. Internal/SPI
  aliases were removed in Phase 10.

## Critical Invariants

- **Never introduce a thread pool.** Every public entry point must dispatch work
  to a fresh 8 MB-stack `Thread` via `DiagramEngine._runOnWorker` /
  `DiagramWorkerThread.run`. This was tried and reverted in `ff2622b`; the
  cooperative pool's roughly 512 KB stack cannot handle deeply nested subgraph
  layouts.
- **Register bundled fonts first.** `DiagramFontRegistry.registerBundledFontsIfNeeded()`
  must run at the start of every pipeline method. Skipping it breaks snapshot
  determinism across OS versions.
- **Parser dispatch order matters.** `Parser.swift` still uses a cascading
  `firstLine.hasPrefix(...)` chain. Narrower prefixes must precede broader
  prefixes; the fallback handles `flowchart`, `graph`, `stateDiagram-v2`, and
  `state`.
- **Two independent renderers exist.** CG/image renderers live under
  `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift`; SVG renderers
  live under `Sources/DiagramKitModel/src_<type>_renderer.swift`. They share no
  geometry/text-measurement logic. Snapshot tests are the guardrail.
- **Use `bmColorEquals()` for color comparisons.** Do not compare colors through
  `hexString` round-trips; AppKit normalizes `NSColor` through `.deviceRGB`.

## Pipeline

```text
Source string
  -> MermaidParser.parse
  -> DiagramDocument
  -> GraphLayout(...).layout
  -> PositionedGraph
  -> DiagramRenderer.render (CG) | renderSVG | renderASCII
```

`DiagramEngine` is defined in `Sources/DiagramKit/DiagramEngine.swift`.
`DiagramPipeline` is defined in `Sources/DiagramKit/DiagramPipeline.swift`.

The view layer uses `DiagramViewPreparer` in `DiagramKitRenderingCG`. The umbrella
registers the canonical prepare closure through `_DiagramPreparerBootstrap`.
Hosts that instantiate views before any `DiagramEngine` call should invoke
`DiagramEngine.bootstrap()` once at startup.

## Type Safety

`DiagramDocument.payload` / `typedPayload` and `PositionedGraph.content` are
enums with one case per diagram family. Do not cast payloads to `Any`; always
pattern-match the typed enum.

Errors and issue reporting flow through the format-neutral helpers in
`DiagramKitCommon`, such as `_withDiagramIssueReporting(operation:)` and
`_reportDiagramIssue(...)`.

Underscore-prefixed top-level symbols are SPI (`_PositionedNodePayload`,
`_renderDiagramSVG`, etc.). Use public typealiases such as `PositionedNode`
outside the defining module.

## What Lives Where

- `Sources/DiagramKitCommon/` - Linux-portable foundations: `SVG`,
  `IssueReportingSupport`, `StableID`, text metrics, themes, Font Awesome /
  HTML-entity tables, multiline utilities, and styles.
- `Sources/DiagramKitModel/` - JS-ported parsers, layouts, SVG renderers, ASCII
  renderers, payload models, render options/tokens, cross-platform shims,
  frontmatter binding, source preprocessing, `DiagramColorParser`, and
  `DiagramSourceNormalizer`.
- `Sources/DiagramKitRenderingCG/` - Apple-only CG renderer, `PreparedDiagram`,
  `DiagramWorkerThread`, `DiagramPreparation`, `DiagramBitmapRenderer`,
  `DiagramViewPreparer`, `DiagramFontRegistry`, bundled fonts, and version
  resources.
- `Sources/DiagramKitViews/` - Apple-only SwiftUI/UIKit/AppKit wrappers:
  `DiagramView.swift`, `DiagramNativeView.swift`, `DiagramLayer.swift`,
  `DiagramViewModel.swift`.
- `Sources/DiagramKit/` - umbrella public API: `DiagramEngine.swift`,
  `DiagramPipeline.swift`, `DiagramImageRenderer.swift`,
  `DiagramPreparerWiring.swift`, `Parser.swift`, `Layout.swift`,
  `DiagramDescriptor.swift`, `src_index.swift`, `src_ascii_index.swift`,
  `ReExports.swift`, `MermaidImporter.swift`, and `SVGRenderRegistry.swift`.
- `Sources/DiagramKitImport/` - importer protocol and registry boundary.
- `Sources/DiagramKitD2/` - D2 importer (`D2Importer`, `D2Parser`, `D2Mapper`).
- `Sources/DiagramKitGraphviz/` - Graphviz DOT importer (`GraphvizImporter`, `DOTParser`, `DOTMapper`).
- `Sources/DiagramKitStructurizr/` - Structurizr DSL importer.
- `Sources/DiagramKitExporter/` - multi-format exporter protocol (`MermaidExporter`, `D2Exporter`, `StructurizrExporter`, `PlantUMLExporter`).
- `Sources/DiagramKitTestSupport/` - Linux-portable test helpers.
- `Examples/MermaidPlayground/` - SwiftUI sample app and the current
  `test-diagrams.json` corpus source.
- `Tests/DiagramKitTests/` - XCTest and swift-testing suites plus corpus
  snapshots.

## Testing And Snapshots

- Current test source count: 188 Swift files under `Tests/DiagramKitTests`.
- The corpus is `Examples/MermaidPlayground/Resources/test-diagrams.json` with
  422 entries (396 Mermaid-only + 26 multi-format: D2, DOT, Structurizr, PlantUML).
- Corpus baselines under `Tests/DiagramKitTests/__Snapshots__/` track
  435 SVG, 435 image, and 174 ASCII files (1044 total; 609 text snapshots
  including SVG + ASCII).
- Image snapshots use `precision: 0.99, perceptualPrecision: 0.98` to tolerate
  CoreText rasterization drift across CPU architectures.
- Multi-format snapshot tests use format-suffixed names (`entry-id-format`) to
  avoid collisions between formats sharing the same `diagram.id`.
- The full parameterized `CorpusSnapshotTests` run has a known
  `swift-testing` / `swift-snapshot-testing` signal-10 caveat. Use chunked
  execution with `SNAPSHOT_DIAGRAM_IDS` when recording.

## Discipline Gates

`Scripts/bootstrap-smoke-check.sh` is the local merge gate. It chains
`swift package dump-package`, `swift test`, the governance scripts below,
`linux-check.sh`, and a multiplatform `xcodebuild` sweep.

- `Scripts/check-file-sizes.sh` - 500-line warning / 1000-line error for Swift
  files. Allowlist: `Scripts/check-file-sizes-allowlist.txt`.
- `Scripts/check-sendable-annotations.sh` - every `@unchecked Sendable` must be
  allowlisted or carry a "Concurrency Contract" banner near the annotation.
- `Scripts/strict-concurrency-check.sh` - first-party strict concurrency build
  under Swift 6.
- `Scripts/linux-check.sh` - Docker/Podman build of the Linux-portable target
  matrix on `swift:6.3.1-noble`.

If Docker/Podman is not running locally, record `linux-check.sh` as skipped due
to environment. Do not treat that as a source failure.

`Package.swift` applies `strictConcurrencySettings` using the `StrictConcurrency`
upcoming feature. `InferSendableFromCaptures` is intentionally omitted because it
is already default in Swift 6 mode and emits "already enabled" warnings when
re-enabled.

## Linux Portability

Linux parse/layout support is partial. `DiagramKitCommon`,
`DiagramKitModel`, and `DiagramKitTestSupport` are Linux-portable. CG, native UI,
and CoreText-bound layout/rendering remain Apple-only or gated out.

`BMColor`, `BMFont`, `BMImage`, `BMView`, and `BMBezierPath` are intentionally
undefined on Linux. Any callsite using them must be platform-gated.

The portable text-measurement shim for `ishikawa`, `treeView`, and
`eventModeling` remains a deferred follow-up.

## Forward Roadmap

Phases 0–10 are complete. The multi-format importer boundary is in place with
importers for Mermaid, D2, Graphviz DOT, Structurizr, and PlantUML (sequence).
The corpus carries ~422 entries across 28 diagram families. Remaining work:

1. Complete remaining PlantUML importer slices (Phases 6B–6E in PHASES.md).
2. Add exporter coverage for remaining diagram families.
3. Follow [PHASES.md](PHASES.md) for the active roadmap.
