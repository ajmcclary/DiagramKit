# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native Swift port of [mermaid-js](https://mermaid.js.org/) covering ~28 diagram types (flowchart, state, sequence, class, ER, Gantt, gitGraph, mindmap, C4, ZenUML, Wardley, Treemap, etc.). Two output paths exist — Core Graphics (for `renderImage(...)`) and SVG (for `renderSVG(...)`) — plus an ASCII renderer.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile the test target
swift test                                          # full test suite (~140 files, ~5–10 min)
swift test --filter <NameOrPattern>                 # one suite/test, e.g. SequenceSvgTests, CorpusSnapshotTests/svgSnapshot
swift package resolve                               # after editing Package.swift dependencies

# Snapshot-test workflow (CorpusSnapshotTests covers all 396 corpus diagrams)
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests   # record/refresh baselines
swift test --filter CorpusSnapshotTests                                # verify against committed baselines
```

`swift run MermaidPlayground` launches the SwiftUI sample app (macOS / iOS).

## Architecture

### Three-stage pipeline

```
Source string → MermaidParser.parse → MermaidGraph
              → GraphLayout(config:).layout → PositionedGraph
              → DiagramRenderer.render (CG) | renderSVG | renderASCII
```

- **`MermaidRenderer`** ([Sources/BeautifulMermaidSwift/BeautifulMermaid.swift](Sources/BeautifulMermaidSwift/BeautifulMermaid.swift)) is the public façade — `async throws` static methods. Every entry point dispatches its work onto a fresh 8 MB-stack `Thread` via `_runOnWorker`. **Do not reintroduce a thread pool**; it was attempted in `ff2622b` and intentionally reverted (see the doc-comment on `_runOnWorker` and `FOLLOWUPS.md`). Layout exceeds the cooperative pool's ~512 KB stack budget on nested-subgraph diagrams.
- **`MermaidPipeline`** ([Sources/BeautifulMermaidSwift/MermaidPipeline.swift](Sources/BeautifulMermaidSwift/MermaidPipeline.swift)) is a stateless enum (NOT an actor) holding the synchronous, nonisolated implementations. Each public method calls `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` first — critical for snapshot determinism.
- **`MermaidImageRenderer`** ([Sources/BeautifulMermaidSwift/ImageRenderer.swift](Sources/BeautifulMermaidSwift/ImageRenderer.swift)) wraps the CG path and produces `BMImage` / PNG / JPEG. Routes through `MermaidRenderer._runOnWorker`, **not** a separate worker (the duplication was removed).

### Type-safe payloads

`MermaidGraph.payload: DiagramPayload` and `PositionedGraph.content: PositionedContent` are enums with one case per diagram type — never `Any` / dictionaries. Always pattern-match:

```swift
switch graph.typedPayload {
case .flowchart(let model): ...
case .sequenceDiagram(let seq): ...
}
```

`Layout.swift` performs the parse-payload → layout dispatch via these enums and uses `_reportMermaidIssue(...)` for "shouldn't happen" mismatches (logged in tests, swallowed in prod via [IssueReporting](https://github.com/pointfreeco/xctest-dynamic-overlay)).

### Two parallel render paths (drift hazard)

Every diagram type has **two independent renderers** that share no geometry/text-measurement logic:

- **CG path:** `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+<Type>.swift` — extends `DiagramRenderer`, drives `CGContext`, used by `renderImage(...)`.
- **SVG path:** `Sources/BeautifulMermaidSwift/Mermaid/src_<type>_renderer.swift` (or `_svg.swift`) — used by `renderSVG(...)`.

These will drift over time. Snapshot tests catch divergence. Consolidation onto a single canonical path is a tracked follow-up — see [FOLLOWUPS.md](FOLLOWUPS.md).

### Parser dispatch

[Sources/BeautifulMermaidSwift/Parser.swift](Sources/BeautifulMermaidSwift/Parser.swift) uses a cascading `firstLine.hasPrefix(...)` chain (e.g. `"sequencediagram"`, `"classdiagram"`, `"radar-beta"`). **Order matters** — narrower prefixes must come before broader ones. The fallback at the end handles `flowchart`, `graph`, `stateDiagram-v2`, and the older `state` keyword. Per-diagram-type parsers live in `Sources/BeautifulMermaidSwift/Mermaid/src_<type>_parser.swift`. The largest preprocessing file, `SourcePreprocessing.swift` (~2.6K LOC), handles frontmatter / multiline joining / comment stripping for all diagrams.

### Cross-platform shim

[Sources/BeautifulMermaidSwift/CrossPlatform.swift](Sources/BeautifulMermaidSwift/CrossPlatform.swift) defines `BMColor`, `BMFont`, `BMImage`, `BMBezierPath`, `BMView` typealiases via `#if canImport(UIKit) / canImport(AppKit)`. AppKit `NSBezierPath` doesn't expose `cgPath`, so a custom `bm_cgPath` converter walks element-by-element including `.cubicCurveTo` / `.quadraticCurveTo`. **Do not** assume `BMColor` round-trips through `hexString` — use `bmColorEquals()` for comparisons (it normalizes through `.deviceRGB` on AppKit).

### Bundled fonts (snapshot determinism)

`Sources/BeautifulMermaidSwift/Resources/Fonts/` ships Noto Sans (4 weights) + Noto Sans Mono (Regular + Bold) under SIL OFL. They are registered process-wide on first use via `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` and looked up by family name (`"Noto Sans"`, `"Noto Sans Mono"`) in:

- `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily` (the canonical knobs)
- `DiagramRenderer._monoFont/_italicSystemFont/_italicMonoFont` (route through `config.*`)
- Five private per-extension helpers in `Treemap`, `Venn`, `Ishikawa`, `EventModeling`
- `MindmapTheme.fontFamily` (default `"Noto Sans"`)

System fonts drift across macOS/iOS major versions; bundled fonts make snapshot images byte-stable. **Don't hardcode `"Menlo"` / `"Trebuchet MS"` etc. in a renderer** — route through `config.*`. Mermaid-specific font fallbacks (e.g. Trebuchet MS for EventModeling) belong in the helper's fallback chain, not at the call site.

### Test corpus & snapshots

- The corpus is [Examples/MermaidPlayground/Resources/test-diagrams.json](Examples/MermaidPlayground/Resources/test-diagrams.json) — 396 diagrams across 28 GAPS.md families. `PlaygroundExampleCatalogTests` validates that every category has at least one entry and that picker order matches GAPS.md.
- `CorpusSnapshotTests.swift` (swift-testing, parameterized over `loadDiagrams()`) renders every entry through SVG / image / ASCII paths. Baselines live in `Tests/BeautifulMermaidSwiftTests/__Snapshots__/CorpusSnapshotTests/`. Currently ~393 SVG, ~172 ASCII, ~161 image baselines — the gap on image vs SVG is the rendering-bug punch list.
- Most other tests use `XCTestCase` (~140 files). Migration to swift-testing is incremental, not blocking.

## Pinned dependencies

- **`swift-snapshot-testing` is pinned to a fork** at `ajmcclary/swift-snapshot-testing` branch `fix-swift-6.3-attachable` (commit `67ce8c1`), carrying [pointfreeco/swift-snapshot-testing#1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090). The upstream 1.18+ versions don't compile against Swift 6.3's `Attachable` cross-import-overlay layout. Switch back to upstream once #1090 ships in a tagged release — see "Upstream dependencies to watch" in [FOLLOWUPS.md](FOLLOWUPS.md).
- `swift-custom-dump` and `xctest-dynamic-overlay` (for `IssueReporting`) are upstream pointfreeco releases.

## What lives where

- `Sources/BeautifulMermaidSwift/` — library
  - `BeautifulMermaid.swift`, `MermaidPipeline.swift`, `ImageRenderer.swift` — public API
  - `Parser.swift`, `Layout.swift`, `Types.swift` — top-level dispatchers and public types
  - `CrossPlatform.swift`, `FontRegistry.swift`, `IssueReportingSupport.swift` — platform shims
  - `Render/` — new CG renderer + per-type extensions
  - `Mermaid/` — JS-ported per-diagram-type parsers / layouts / SVG / ASCII (~150 files)
  - `Resources/` — bundled fonts + `VERSION` file (read by `MermaidRenderer.version`)
- `Examples/MermaidPlayground/` — SwiftUI sample app, also the source of the test corpus JSON
- `Tests/BeautifulMermaidSwiftTests/` — XCTest + swift-testing test files; `__Snapshots__/` baselines (excluded from SwiftPM resource processing)

## Conventions

- **`async throws` is the public default.** `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`); `renderSVG` / `renderASCII` are intentionally NOT main-actor.
- **Public types implement `Sendable`** — `DiagramType`, `DiagramPayload`, `MermaidGraph`, `PositionedContent`, `PositionedGraph`, `LayoutConfig`, `EdgeStyle` are all explicitly `Sendable`. `swiftLanguageModes: [.v6]` is enforced.
- **Errors flow through `_withMermaidIssueReporting(operation:)`.** Use it at every public boundary so test-time observers see uncategorized failures without obstructing flow.
- **Underscore-prefixed top-level names are SPI** (e.g. `_PositionedNodePayload`, `_renderMermaidSVG`). Public typealiases drop the underscore: `PositionedNode = _PositionedNodePayload`. Don't reference the `_`-prefixed names from outside the module.
- The Mermaid frontmatter parser at `SourcePreprocessing.swift:_parseFrontMatterAndStripped` is the single entry for YAML-like frontmatter; per-diagram-type parsers receive a typed `frontmatter` argument and pull config off it.

See [FOLLOWUPS.md](FOLLOWUPS.md) for explicitly deferred work (CG/SVG audit, RenderConfig magic-number sweep, SourcePreprocessing split, etc.).
