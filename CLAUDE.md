# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native Swift port of [mermaid-js](https://mermaid.js.org/) covering ~28 diagram types (flowchart, state, sequence, class, ER, Gantt, gitGraph, mindmap, C4, ZenUML, Wardley, Treemap, etc.). Two output paths exist — Core Graphics (for `renderImage(...)`) and SVG (for `renderSVG(...)`) — plus an ASCII renderer.

## Documentation map

The repo carries a layered doc set; each file has a defined role. This file (`CLAUDE.md`) holds the invariants Claude must respect and the conventions Claude should follow. When scopes overlap (e.g. the worker-thread invariant) **this file is the source of truth for "do not break this"; ARCHITECTURE.md is the source of truth for "here is how it works in detail."**

- [README.md](README.md) — public surface, install snippet, quick-start examples for image / SVG / ASCII / SwiftUI.
- [ARCHITECTURE.md](ARCHITECTURE.md) — long-form layer diagram, three-stage pipeline, dual CG/SVG drift hazard, layer-import rules.
- [BASELINES.md](BASELINES.md) — captured 2026-05-10: clean-build time (53.4s), test counts (144 files), snapshot counts (914 baselines = 396 SVG / 346 image / 172 ASCII), file-size landscape, gate status, refresh commands.
- [CONTRIBUTING.md](CONTRIBUTING.md) — file-size thresholds, the green/yellow/red `@unchecked Sendable` policy with banner example, "add a new diagram type" 9-step checklist, PR checklist.
- [ATTRIBUTION.md](ATTRIBUTION.md) — upstream `mermaid-js` lineage (MIT, Knut Sveidqvist & contributors), bundled fonts (SIL OFL), Swift libraries.
- [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) — bundled assets with copyright + license-text references.
- [ANALYSIS.md](ANALYSIS.md) — six-stage import plan and current status.
- [AGENTS.md](AGENTS.md) — terse companion to this file for non-Claude AI agents.

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile the test target
swift test                                          # full test suite (144 files, ~5–10 min — see BASELINES.md for caveats)
swift test --filter <NameOrPattern>                 # one suite/test, e.g. SequenceSvgTests, CorpusSnapshotTests/svgSnapshot
swift package resolve                               # after editing Package.swift dependencies

# Snapshot-test workflow (CorpusSnapshotTests covers all 396 corpus diagrams)
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests   # record/refresh baselines
swift test --filter CorpusSnapshotTests                                # verify against committed baselines
```

`swift run MermaidPlayground` launches the SwiftUI sample app (macOS / iOS).

## Architecture

### Target layout

The package ships six SwiftPM targets in a strict dependency layer ([Package.swift](Package.swift)):

```
DiagramKitCommon           (Linux + Apple)  — SVG primitives, theme, text metrics, IssueReporting, StableID
   ↑
DiagramKitModel            (Linux + Apple)  — parsers, layouts, SVG/ASCII renderers, frontmatter binding, payloads
   ↑                                          UIKit/AppKit/CoreText files compile to empty on Linux
   ├──────────────────┐
DiagramKitRenderingCG     DiagramKitTestSupport
   (Apple-only)            (Linux + Apple)
   ↑
DiagramKitViews            (Apple-only — `MermaidView`, `MermaidLayer`, `MermaidDiagram`, `MermaidDiagramView`)
   ↑
DiagramKit                 (umbrella; public API; `ReExports.swift` re-exports the sub-targets)
   — Apple-only edges to RenderingCG/Views are gated via `condition: .when(platforms: [Apple])`
```

The `DiagramKit` umbrella owns the public API surface (`MermaidRenderer`, `MermaidImageRenderer`, `MermaidPipeline`, `Parser.swift`, `Layout.swift`). On Linux the umbrella's `parse` / `layout` work; everything CG-bound throws or is `#if`-gated out.

The view types live in `Sources/DiagramKitViews/`. Views call `MermaidPreparation.prepare(...)` (in `DiagramKitRenderingCG`) directly; the umbrella's `_MermaidPreparerBootstrap` registers the synchronous `MermaidPipeline.prepare` closure and wires `MermaidViewPreparerEnvironment` the first time any public `MermaidRenderer.*` API is called. Hosts that bypass the umbrella public API (e.g. instantiate `MermaidView` directly) should call `MermaidRenderer.bootstrap()` once at startup.

### Three-stage pipeline

```
Source string → MermaidParser.parse → MermaidGraph
              → GraphLayout(config:).layout → PositionedGraph
              → DiagramRenderer.render (CG) | renderSVG | renderASCII
```

- **`MermaidRenderer`** ([Sources/DiagramKit/MermaidRenderer.swift](Sources/DiagramKit/MermaidRenderer.swift)) is the public façade — `async throws` static methods. Every entry point dispatches its work onto a fresh 8 MB-stack `Thread` via `_runOnWorker`. **Do not reintroduce a thread pool**; it was attempted in `ff2622b` and intentionally reverted (see the doc-comment on `_runOnWorker`). Layout exceeds the cooperative pool's ~512 KB stack budget on nested-subgraph diagrams.
- **`MermaidPipeline`** ([Sources/DiagramKit/MermaidPipeline.swift](Sources/DiagramKit/MermaidPipeline.swift)) is a stateless enum (NOT an actor) holding the synchronous, nonisolated implementations. Each public method calls `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` first — critical for snapshot determinism.
- **`MermaidImageRenderer`** ([Sources/DiagramKit/ImageRenderer.swift](Sources/DiagramKit/ImageRenderer.swift)) wraps the CG path and produces `BMImage` / PNG / JPEG. Routes through `MermaidRenderer._runOnWorker`, **not** a separate worker (the duplication was removed).

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

- **CG path:** `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift` — extends `DiagramRenderer`, drives `CGContext`, used by `renderImage(...)`.
- **SVG path:** `Sources/DiagramKitModel/src_<type>_renderer.swift` (or `_svg.swift`) — used by `renderSVG(...)`.

These will drift over time. Snapshot tests catch divergence. Consolidation onto a single canonical path is a long-standing follow-up.

### Parser dispatch

[Sources/DiagramKit/Parser.swift](Sources/DiagramKit/Parser.swift) uses a cascading `firstLine.hasPrefix(...)` chain (e.g. `"sequencediagram"`, `"classdiagram"`, `"radar-beta"`). **Order matters** — narrower prefixes must come before broader ones. The fallback at the end handles `flowchart`, `graph`, `stateDiagram-v2`, and the older `state` keyword. Per-diagram-type parsers live in `Sources/DiagramKitModel/src_<type>_parser.swift`. Source preprocessing (frontmatter, multiline joining, comment stripping, init directive) is split across [SourcePreprocessing.swift](Sources/DiagramKitModel/SourcePreprocessing.swift), [MermaidSourceNormalizer.swift](Sources/DiagramKitModel/MermaidSourceNormalizer.swift), [FrontmatterDocumentParser.swift](Sources/DiagramKitModel/FrontmatterDocumentParser.swift), and [InitDirectiveParser.swift](Sources/DiagramKitModel/InitDirectiveParser.swift). `_parseFrontMatterAndStripped` in `SourcePreprocessing.swift` is still the single entry point that per-diagram parsers call.

### Cross-platform shim

[Sources/DiagramKitModel/CrossPlatform.swift](Sources/DiagramKitModel/CrossPlatform.swift) defines `BMColor`, `BMFont`, `BMImage`, `BMBezierPath`, `BMView` typealiases via `#if canImport(UIKit) / canImport(AppKit)`. AppKit `NSBezierPath` doesn't expose `cgPath`, so a custom `bm_cgPath` converter walks element-by-element including `.cubicCurveTo` / `.quadraticCurveTo`. **Do not** assume `BMColor` round-trips through `hexString` — use `bmColorEquals()` for comparisons (it normalizes through `.deviceRGB` on AppKit).

### Bundled fonts (snapshot determinism)

`Sources/DiagramKitRenderingCG/Resources/Fonts/` ships Noto Sans (4 weights) + Noto Sans Mono (Regular + Bold) under SIL OFL. They are registered process-wide on first use via `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` and looked up by family name (`"Noto Sans"`, `"Noto Sans Mono"`) in:

- `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily` (the canonical knobs)
- `DiagramRenderer._monoFont/_italicSystemFont/_italicMonoFont` (route through `config.*`)
- Five private per-extension helpers in `Treemap`, `Venn`, `Ishikawa`, `EventModeling`
- `MindmapTheme.fontFamily` (default `"Noto Sans"`)

System fonts drift across macOS/iOS major versions; bundled fonts make snapshot images byte-stable. **Don't hardcode `"Menlo"` / `"Trebuchet MS"` etc. in a renderer** — route through `config.*`. Mermaid-specific font fallbacks (e.g. Trebuchet MS for EventModeling) belong in the helper's fallback chain, not at the call site.

### Test corpus & snapshots

- The corpus is [Examples/MermaidPlayground/Resources/test-diagrams.json](Examples/MermaidPlayground/Resources/test-diagrams.json) — 396 diagrams across 28 diagram families. `PlaygroundExampleCatalogTests` validates that every category has at least one entry and that picker order matches the canonical family list in `Examples/MermaidPlayground/Models/SampleDiagrams.swift`.
- [CorpusSnapshotTests.swift](Tests/DiagramKitTests/CorpusSnapshotTests.swift) (swift-testing, parameterized over `loadDiagrams()`) renders every entry through SVG / image / ASCII paths. Baselines live in `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/`. Currently ~396 SVG, ~346 image, ~172 ASCII baselines — the remaining image gap is the rendering-bug punch list.
- Most other tests use `XCTestCase` (~144 files). Migration to swift-testing is incremental, not blocking.
- See [BASELINES.md](BASELINES.md) for current build-time / test / snapshot counts and refresh commands. The full-corpus parameterized run hits a known signal-10 hang on `main` (a `swift-testing` × `swift-snapshot-testing` interaction over 396 entries) — verify in chunks (`--filter "CorpusSnapshotTests/svgSnapshot.*<family>-"`) until the harness issue is fixed. The snapshots themselves are green.

## Pinned dependencies

- **`swift-snapshot-testing` is pinned to a fork** at `ajmcclary/swift-snapshot-testing` branch `fix-swift-6.3-attachable`, carrying [pointfreeco/swift-snapshot-testing#1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090). The upstream 1.18+ versions don't compile against Swift 6.3's `Attachable` cross-import-overlay layout. Switch back to upstream once #1090 ships in a tagged release.
- `swift-custom-dump` and `xctest-dynamic-overlay` (for `IssueReporting`) are upstream pointfreeco releases.
- `swift-crypto` is depended on **only on Linux** (`condition: .when(platforms: [.linux])`) so `DiagramKitCommon`'s `StableID.derive(...)` has a CryptoKit-equivalent API. Apple platforms use the system `CryptoKit` directly.

## What lives where

- `Sources/DiagramKitCommon/` — Linux-portable foundations: `SVG`, `IssueReportingSupport`, `StableID` (CryptoKit / swift-crypto), text metrics, theme, font-awesome / HTML-entity tables, multiline utils, styles.
- `Sources/DiagramKitModel/` (~197 files) — JS-ported per-diagram-type **parsers / layouts / SVG / ASCII renderers** (`src_<type>_parser.swift`, `src_<type>_layout.swift`, `src_<type>_renderer.swift`, `src_ascii_*.swift`). Also `Types.swift`, `RenderConfig.swift`, `RenderOptions.swift`, `RenderTokens.swift`, `PositionedPayloads.swift`, `CrossPlatform.swift` (`BMColor` / `BMFont` / `BMImage` typealiases), `FrontmatterBinding+<Type>.swift` (one per diagram), and the source-preprocessing quartet. UIKit/AppKit/CoreText-specific files are gated to compile to empty on Linux.
- `Sources/DiagramKitRenderingCG/` — Apple-only CG renderer. `DiagramRenderer+<Type>.swift` per diagram type plus `DiagramRenderer.swift`, `EdgeRenderer`, `LabelRenderer`, `ShapeRenderer`, `ArrowRenderer`, `CGPathRenderer`, `PreparedDiagram`, `FontRegistry` (`BeautifulMermaidFontRegistry`), `Version` (reads `Resources/VERSION`). `Resources/` ships bundled fonts (`Fonts/Noto Sans*`) + `VERSION`.
- `Sources/DiagramKitViews/` — Apple-only SwiftUI/UIKit views (`MermaidView`, `MermaidLayer`, `MermaidDiagram`, `MermaidDiagramView`).
- `Sources/DiagramKitTestSupport/` — Linux-portable test helpers (no CG/CT/UI deps).
- `Sources/DiagramKit/` — public API umbrella: `MermaidRenderer.swift`, `MermaidPipeline.swift`, `ImageRenderer.swift`, `Parser.swift`, `Layout.swift`, `MermaidPreparerWiring.swift`, `DiagramDescriptor.swift`, `src_index.swift`, `src_ascii_index.swift`, plus `ReExports.swift` (re-exports `DiagramKitViews` / `DiagramKitRenderingCG` / `DiagramKitModel` / `DiagramKitCommon`).
- `Examples/MermaidPlayground/` — SwiftUI sample app and the source of `Resources/test-diagrams.json` (test corpus).
- `Tests/DiagramKitTests/` — XCTest + swift-testing test files (~144); `__Snapshots__/CorpusSnapshotTests/` baselines (excluded from SwiftPM resource processing).
- `Scripts/linux-check.sh` + `Dockerfile.linux-check` — Linux portability harness.

## Conventions

- **`async throws` is the public default.** `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`); `renderSVG` / `renderASCII` are intentionally NOT main-actor.
- **Public types implement `Sendable`** — `DiagramType`, `DiagramPayload`, `MermaidGraph`, `PositionedContent`, `PositionedGraph`, `LayoutConfig`, `EdgeStyle` are all explicitly `Sendable`. `swiftLanguageModes: [.v6]` is enforced.
- **Errors flow through `_withMermaidIssueReporting(operation:)`.** Use it at every public boundary so test-time observers see uncategorized failures without obstructing flow.
- **Underscore-prefixed top-level names are SPI** (e.g. `_PositionedNodePayload`, `_renderMermaidSVG`). Public typealiases drop the underscore: `PositionedNode = _PositionedNodePayload`. Don't reference the `_`-prefixed names from outside the module.
- The Mermaid frontmatter parser at `SourcePreprocessing.swift:_parseFrontMatterAndStripped` is the single entry for YAML-like frontmatter; per-diagram-type parsers receive a typed `frontmatter` argument and pull config off it via the `FrontmatterBinding+<Type>.swift` adapters.
- **Module imports follow the layer order.** Files inside `DiagramKitModel` cannot `import DiagramKitRenderingCG`; files inside `DiagramKitRenderingCG` import `DiagramKitModel` + `DiagramKitCommon`; the umbrella `DiagramKit` re-exports the layer below it. When in doubt about where a new file belongs: if it touches CoreGraphics, it goes in RenderingCG; if it touches UIKit/AppKit only via the `BMColor`/`BMFont` shims, it can go in Model under a `#if canImport(UIKit)||canImport(AppKit)` gate; if it has no platform deps at all, prefer `DiagramKitCommon`.

## Linux portability state (Stage 2)

DiagramKit compiles on `swift:6.3.1-noble` for the targets in the table below. Functional Linux layout/rendering for layouts that depend on text measurement (`CTLineGetBoundsWithOptions`) is **deferred** — those dispatch arms throw `MermaidStructuralError.payloadMismatch` on Linux. A portable text-measurement shim is the Stage 2.5 follow-up.

| Target | Linux | Notes |
|---|---|---|
| `DiagramKitCommon` | full | No CG/CT/UI dependencies. |
| `DiagramKitModel` | partial | UIKit/AppKit/CoreText files compile to empty on Linux. SVG/ASCII paths that don't measure text work; layouts requiring CTLine bounds (ishikawa, treeView, eventModeling) are unreachable. |
| `DiagramKitTestSupport` | full | No CG/CT/UI dependencies. |
| `DiagramKit` (umbrella) | partial | `parse(_:)` and `layout(_:config:)` portable. `renderImage`, `renderSVG`, `renderASCII`, `render(in: CGContext)` are Apple-only. View types now live in `DiagramKitViews`. |
| `DiagramKitRenderingCG` | none | Apple-only via `condition: .when(platforms: [Apple])` + `#if canImport(CoreGraphics)`. |
| `DiagramKitViews` | none | Apple-only. |
| `DiagramKitTests` | none | Test target depends on RenderingCG; left Apple-only for Stage 2. |
| `MermaidPlayground` | none | SwiftUI executable. |

**Verifying the Linux build:**

```bash
./Scripts/linux-check.sh
```

Builds the Linux-portable target matrix in a `swift:6.3.1-noble` container (Docker or Podman) and prints PASS/FAIL per target. Requires the daemon running locally (e.g. `open -a Docker`).

**The platform-condition pattern:**
- `Package.swift` edges that traverse RenderingCG/Views are guarded by `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])`.
- Source-level: `#if canImport(CoreGraphics)` for CG, `#if canImport(CoreText)` for text measurement, `#if canImport(UIKit) || canImport(AppKit)` for native UI types and `BMColor`/`BMFont`/`BMImage`.
- `BMColor`/`BMFont`/`BMImage`/`BMView`/`BMBezierPath` typealiases in `CrossPlatform.swift` are intentionally undefined on Linux. Any callsite using them must itself be gated.

**Known deferrals:**
- A portable text-measurement shim so `ishikawa` / `treeView` / `eventModeling` layouts can run on Linux (Stage 2.5).
- CG/SVG renderer drift — they share no geometry/measurement code; long-term plan is a single canonical path. Snapshot tests are the only guardrail in the meantime.
- `RenderConfig.swift` carries a number of magic constants that should be lifted into theme tokens.
- Removing the `?? MermaidViewPreparer(prepare: MermaidPreparation.prepare(...))` fallback in `MermaidLayer` / `MermaidDiagram` — once the umbrella's bootstrap is guaranteed by other means.

## Discipline gates (Stage 3)

`Package.swift` applies `strictConcurrencySettings` (the `StrictConcurrency` upcoming feature) uniformly to every target via the top-level `let strictConcurrencySettings: [SwiftSetting]` constant. `InferSendableFromCaptures` is intentionally **not** included — it is already on by default in Swift 6 mode, and re-enabling it via `.enableUpcomingFeature` emits a per-file warning. The doc-comment on the constant explains the rationale.

Four governance scripts live under `Scripts/` and are orchestrated by `Scripts/bootstrap-smoke-check.sh` (the local "is Stage 3 healthy?" gate). Run them individually during development; run the orchestrator before merging:

| Script | What it checks | Allowlist |
|---|---|---|
| `check-file-sizes.sh` | Every `.swift` in `Sources/` and `Tests/` against 500-line warn / 1000-line error thresholds. | `Scripts/check-file-sizes-allowlist.txt` (one path per line, `#` comments OK). The 11 JS-ported parser/layout/renderer files in `DiagramKitModel` are grandfathered. |
| `check-sendable-annotations.sh` | Every `@unchecked Sendable` is either in the allowlist or has a "Concurrency Contract" banner in the first 50 lines of the file or within 10 lines of the annotation. | `.sendable-allowlist.txt` at repo root. Format: `file:line:category:sunset` — `red` (must resolve), `yellow` with `YYYY-MM-DD` sunset (resolve by date). Stage 3 grandfathered all 14 existing sites as yellow with sunset `2027-06-30`. |
| `strict-concurrency-check.sh` | `swift build` under `-strict-concurrency=complete -warnings-as-errors`, filtered to first-party diagnostics matching `Sources/DiagramKit[^/]*/`. Third-party diagnostics are tolerated. | None — fix or yellow-allowlist via the sendable script. |
| `bootstrap-smoke-check.sh` | Orchestrator: `swift package dump-package`, `swift test`, the three gates above, `linux-check.sh`, and `xcodebuild` for iOS / visionOS / tvOS via the `DiagramKit-Package` auto-scheme. | n/a |

**Adding new `@unchecked Sendable`:** prefer green — write a Concurrency Contract banner explaining the invariant (single-pass / construction-then-freeze / queue-confinement / etc.) within 10 lines of the annotation. Only fall back to yellow with a sunset if the banner can't honestly be written.

**Bootstrap markers (`<Target>Bootstrap.phase: Int`)** are intentionally not introduced in this package. They are relevant once DiagramKit is promoted into the monorepo and a second consumer is identified (Stage 6 in `ANALYSIS.md`); add them then.

**Known caveats for `bootstrap-smoke-check.sh`:**
- `swift test` full-run hangs partway through with `unexpected signal code 10` — pre-existing on `main` per the `CorpusSnapshotTests` issue. Verify snapshots in chunks (`--filter "CorpusSnapshotTests/svgSnapshot.*<family>-"`) until the harness issue is resolved.
- `linux-check.sh` requires Docker or Podman running locally.
- `xcodebuild` runs require the relevant platform runtimes installed in Xcode; missing runtimes are skipped (not failed) per the script's "Please download…" detection.
