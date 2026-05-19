# Architecture

DiagramKit is structured as a layered Swift package: a small portable foundation, a substantial parsing/layout core, two Apple-only rendering targets, an umbrella that re-exports the public API, and a thin test-support target. This document describes the layers, the rendering pipeline, the invariants worth defending, and the known drift hazards.

## High-level design goals

- **Pure-data parse and layout.** The parse step yields a typed `DiagramDocument` (one enum case per diagram family); the layout step yields a typed `PositionedGraph`. Neither stage touches CoreGraphics, CoreText, UIKit, or AppKit. This is what makes the engine Linux-portable.
- **Three render backends from one layout.** A single `PositionedGraph` is consumed by the CG image path (`renderImage`), the SVG path (`renderSVG`), and the ASCII path (`renderASCII`). They share no geometry/measurement code today — see "Drift hazard" below.
- **Snapshot-deterministic rendering.** Bundled fonts neutralise system-font drift across macOS / iOS major versions. Every render path routes font lookup through `RenderConfig.*` so per-call overrides work.
- **Strict layer boundaries.** Source-level imports follow the dependency layer; cross-layer imports either compile clean on every platform or sit behind a `#if canImport(...)` gate.

## Layered target map

```
                           ┌─────────────────────┐
                           │   DiagramKitCommon  │  full Linux + Apple
                           │  (no CG/CT/UI deps) │
                           └──────────┬──────────┘
                                      │
                           ┌──────────▼──────────┐
                           │   DiagramKitModel   │  Linux + Apple (partial)
                           │  parsers · layouts  │  CT-bound files compile to empty on Linux
                           │  SVG · ASCII · types│
                           └────┬─────────┬──────┘
                                │         │
              ┌─────────────────▼┐       ┌▼──────────────────────┐
              │ DiagramKitRenderingCG │  │ DiagramKitTestSupport │  full Linux + Apple
              │      (Apple-only)     │  │  (no CG/CT/UI deps)   │
              └─────────┬─────────────┘  └───────────────────────┘
                        │
              ┌─────────▼──────────┐
              │  DiagramKitViews   │  Apple-only views
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────────────────────┐
              │            DiagramKit              │  umbrella: public API + re-exports
              │  Apple-only edges to RenderingCG/  │
              │  Views via condition:.when(Apple)  │
              └─────────────────────────────────────┘
```

The package-wide `platforms:` floor in [Package.swift](Package.swift) is macOS 26 + iOS 26 (Catalyst, tvOS, and visionOS were dropped on 2026-05-18). Apple-only targets like `DiagramKitRenderingCG`, `DiagramKitViews`, and `DiagramKitInteractive` are gated at the source level via `#if canImport(CoreGraphics)`, `#if canImport(CoreText)`, and `#if canImport(UIKit) || canImport(AppKit)`.

| Target | What lives there | Linux | Apple |
|---|---|---|---|
| `DiagramKitCommon` | `SVG` primitives, `IssueReportingSupport`, `StableID` (CryptoKit / swift-crypto), text metrics, theme tokens, font-awesome / HTML-entity tables, multiline utilities, styles. | full | full |
| `DiagramKitModel` | ~255 files: per-diagram-type `src_<type>_parser.swift`, `src_<type>_layout.swift`, `src_<type>_renderer.swift`, ASCII converters (`src_ascii_*.swift`), source-preprocessing quartet, `Types.swift`, `RenderConfig.swift`, `RenderOptions.swift`, `RenderTokens.swift`, `PositionedPayloads.swift`, `CrossPlatform.swift` (`BMColor`/`BMFont`/`BMImage` shims), and 28 `FrontmatterBinding+<Type>.swift` adapters. | partial | full |
| `DiagramKitRenderingCG` | Apple-only CG renderer: `DiagramRenderer+<Type>.swift` per diagram family, plus `EdgeRenderer`, `LabelRenderer`, `ShapeRenderer`, `ArrowRenderer`, `CGPathRenderer`, `PreparedDiagram`, `FontRegistry` (`DiagramFontRegistry`), `Version`. Bundled fonts under `Resources/Fonts/`. | none | full |
| `DiagramKitTestSupport` | Linux-portable test helpers (no CG/CT/UI deps). | full | full |
| `DiagramKitViews` | Apple-only SwiftUI/UIKit/AppKit wrappers: `DiagramNativeView`, `DiagramView`, `DiagramLayer`, `DiagramViewModel`. | none | full |
| `DiagramKit` | Umbrella: `DiagramEngine`, `DiagramImageRenderer`, `DiagramPipeline`, `DiagramDescriptor.swift` (parser dispatch), `DiagramRegistry+<Type>.swift` (28 family descriptors), `Layout.swift`, `src_ascii_index.swift`. | partial | full |

## Three-stage pipeline

```
Source string
    │
    ▼
┌────────────────────┐
│  DiagramLoader     │   Parse: source → DiagramDocument (typed payload enum)
│   .parseDocument   │   Lives in: DiagramKitImport + DiagramKit umbrella
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  GraphLayout       │   Layout: DiagramDocument → PositionedGraph
│   .layout(...)     │   Pure-data; no CG/CT on the portable path
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  Render backends   │   PositionedGraph → BMImage | String (SVG) | String (ASCII)
│  • CG  → renderImage      (Apple-only)
│  • SVG → renderSVG        (Apple + Linux for non-text-measuring layouts)
│  • ASCII → renderASCII    (Apple + Linux for non-text-measuring layouts)
└────────────────────┘
```

### Parser dispatch

Multi-format import dispatch goes through `DiagramLoader` + `ImporterRegistry` (Structurizr, PlantUML, Graphviz, D2, Mermaid — in probe order). Mermaid-family dispatch within `MermaidImporter` then routes through `DiagramRegistry.detect(header)` to the per-family descriptor in `Sources/DiagramKit/DiagramRegistry+<Family>.swift`. See `Sources/DiagramKit/DiagramPipeline.swift` for the default registry.

Source preprocessing (frontmatter, multiline-string joining, comment stripping, `%%{init: …}%%` directive) is split across:

- `Sources/DiagramKitModel/SourcePreprocessing.swift` — entry point `_parseFrontMatterAndStripped(...)`
- `Sources/DiagramKitModel/DiagramSourceNormalizer.swift`
- `Sources/DiagramKitModel/FrontmatterDocumentParser.swift`
- `Sources/DiagramKitModel/InitDirectiveParser.swift`

Per-diagram-type parsers receive a typed `frontmatter` argument and pull config off it via the `FrontmatterBinding+<Type>.swift` adapters (one per family).

### Type-safe payloads

`DiagramDocument.payload: DiagramPayload` and `PositionedGraph.content: PositionedContent` are enums with one case per diagram type — never `Any` or untyped dictionaries. `Layout.swift` performs the parse-payload → layout dispatch via these enums and uses `_reportDiagramIssue(...)` for "shouldn't happen" mismatches (logged in tests via `IssueReporting`, swallowed in production).

### Diagnostics

`DiagramImportResult.diagnostics` carries parse-tier warnings (currently emitted by the Mermaid C4 `$boundary` mismatch path and the Kanban duplicate-node check, plus every non-Mermaid importer). `PositionedGraph.diagnostics` carries layout-tier warnings (subgraph recursion truncations in `src_layout.swift`, Ishikawa recursion-depth overflow, gitgraph `parallelCommits` missing-position fallback). `PreparedDiagram.diagnostics` aggregates the two in `[parse, layout]` order. The ASCII path bypasses `PreparedDiagram` and returns `AsciiRenderOutput { text, diagnostics }`, where `diagnostics = renderRegistryDiagnostics` (parse-tier signals reach the ASCII path through the family parsers invoked inside the registry closure). Fatal conditions still `throw`; the diagnostic array carries only `.warning` and `.info` severities.

Round-trip discipline (`DiagramKitTestSupport.RoundTripHarness`) cross-references this diagnostic surface: an exporter that introduces a structural loss without emitting a paired `.warning` or `.unsupported` diagnostic fails the round-trip gate. See `docs/superpowers/specs/2026-05-15-roundtrip-exporter-tests-design.md`.

Emission sites use the typed `DiagramDiagnostic.lossyTransform(.<category>, ...)` / `.featureDropped(.<category>, ...)` / `.informational(.<category>, ...)` factories; raw `DiagramDiagnostic(severity:message:)` is deprecated. The harness pairs `RoundTripLoss` to diagnostics by typed `DiagnosticCategory` equality. See [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md) for the per-severity contract and category catalog, enforced by `Scripts/check-diagnostic-discipline.sh`.

## The worker-thread invariant

`DiagramEngine` ([Sources/DiagramKit/DiagramEngine.swift](Sources/DiagramKit/DiagramEngine.swift)) is the public façade. Every `async throws` entry point dispatches its work onto a fresh **8 MB-stack `Thread`** via `_runOnWorker`.

**Do not reintroduce a thread pool in production parse/layout/render code.** It was attempted in commit `ff2622b` and intentionally reverted (see the doc-comment on `_runOnWorker`). Layout exceeds the cooperative pool's ~512 KB stack budget on nested-subgraph diagrams; running on a dedicated worker thread with an 8 MB stack is the only thing that keeps deeply nested mindmaps and flowcharts from crashing on stack overflow.

Scope. This invariant covers `Sources/DiagramKit*/` parse/layout/render code. It does **not** cover:

- **Tests** — `Tests/DiagramKitTests/MermaidPipelineConcurrencyTests.swift` deliberately drives `DiagramEngine` from `withThrowingTaskGroup` to validate determinism under concurrent callers.
- **The `DiagramKitSample` sample app** — UI work uses `Task.detached`, `async let`, and `DispatchQueue.main.async` for syntax highlighting, history persistence, and file loading.
- **Narrow per-parser caches** — `_dateFormatterCacheQueue` (`src_gantt_parser.swift`) and `_reqRegexCacheQueue` (`src_requirement_parser.swift`) are single-element `DispatchQueue` serializers around `DateFormatter` / `NSRegularExpression` reuse, not pools.

Grep audits that surface `TaskGroup` / `Task.detached` / `DispatchQueue` should consult this scope before flagging hits as policy violations.

Implementation details:
- `DiagramPipeline` ([Sources/DiagramKit/DiagramPipeline.swift](Sources/DiagramKit/DiagramPipeline.swift)) is a stateless `enum` (NOT an actor) holding the synchronous, nonisolated implementations. Each public method calls `DiagramFontRegistry.registerBundledFontsIfNeeded()` first — critical for snapshot determinism.
- `DiagramImageRenderer` ([Sources/DiagramKit/DiagramImageRenderer.swift](Sources/DiagramKit/DiagramImageRenderer.swift)) routes through `DiagramEngine._runOnWorker` rather than a separate worker (the duplication was removed).

### Model-layer free functions are SPI-equivalent

`DiagramKitModel` exposes ~30 public free functions (`parseIshikawaDiagram`, `layoutC4Diagram`, `layoutTreemapDiagram`, `layoutMindmap`, `renderQuadrantSvg`, `renderC4Svg`, `renderClassSvg`, `renderErSvg`, `renderKanbanSvg`, …). They exist for the umbrella `DiagramKit` module, the format-slice exporters, the test target, and other lower-level consumers — not as the supported public surface.

These helpers are **synchronous, not worker-thread mediated, and do not perform their own font registration or issue-reporting setup**. They are SPI-equivalent: the underscore prefix used elsewhere (`_renderDiagramSVG`, `_PositionedNodePayload`) is not applied here only because too many existing call sites import them by their bare names.

**The supported public API is `DiagramEngine.*` and `DiagramImageRenderer.*`.** Anything else is an implementation hook. Callers that reach into `DiagramKitModel` free functions directly are themselves responsible for:

- **Thread / stack management** — call from a worker with an 8 MB stack (see [`_runOnWorker`](Sources/DiagramKit/DiagramEngine.swift)) when laying out diagrams with deep recursion (mindmap, nested subgraphs); the cooperative thread pool's ~512 KB budget is not enough.
- **Font registration** — call `DiagramFontRegistry.registerBundledFontsIfNeeded()` before any Apple-side layout / render path; without it bundled-font snapshot determinism breaks and CoreText falls back to system fonts that drift across OS versions. (Font construction is locked at the resolver since [REVIEW.md C1](REVIEW.md), so concurrent calls won't stall on the font-provider XPC even without registration — but registration is still required for snapshot stability.)
- **Issue reporting context** — wrap with `_withDiagramIssueReporting(operation:)` if you want emitted diagnostics to flow through the central issue-reporting boundary.

When in doubt: go through `DiagramEngine`. The model-layer free functions are for cases where the caller has explicit reasons to skip the engine (e.g., test fixtures that pin behavior of one layout function without paying for the full pipeline).

## Rendering backends — drift hazard

Every diagram type has **two independent renderers** that share no geometry or text-measurement logic:

- **CG path:** `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift` — extends `DiagramRenderer`, drives a `CGContext`, used by `renderImage(...)`.
- **SVG path:** `Sources/DiagramKitModel/src_<type>_renderer.swift` (or `_svg.swift`) — used by `renderSVG(...)`.

These will drift over time. **Snapshot tests catch divergence** — every diagram family has SVG, image, and ASCII baselines under `Tests/DiagramKitTests/__Snapshots__/`. Consolidation onto a single canonical render path is a long-standing follow-up; the dual paths exist because the JS port preserved upstream Mermaid's `Renderer.draw(svg)` and the CG path was added native-side.

When changing geometry, label measurement, or arrow routing for a diagram family, **change both renderers in the same commit and re-record both snapshot baselines**. A drift in either direction is silent until the corpus run flags it.

## Structurizr recovery comments — drift hazard

The Structurizr exporter encodes element-scoped tags and flattened nested-boundary parentage in `# diagramkit:tag=<tag>` and `# diagramkit:boundary-parent=<label>` line-comment markers placed adjacent to the element/group they augment. A pre-lexer scan (`scanStructurizrPreLexer` in `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift`) harvests those markers before `StructurizrLexer.preprocess(_:)` strips `#` line comments at `StructurizrLexer.swift:84-93`. **Do not strip `# diagramkit:` recovery comments upstream of the importer.** A generic comment-cleanup step that removes them silently re-introduces a structural round-trip loss that the harness cannot pair to a diagnostic. The shrunken `structurizrC4` round-trip allow-list (no `.boundaryFlatten`) acts as the regression bar.

## Cross-platform shim

`Sources/DiagramKitModel/CrossPlatform.swift` defines `BMColor`, `BMFont`, `BMImage`, `BMBezierPath`, `BMView` typealiases via `#if canImport(UIKit)` / `#if canImport(AppKit)`. AppKit's `NSBezierPath` doesn't expose `cgPath`, so a custom `bm_cgPath` converter walks element-by-element including `.cubicCurveTo` / `.quadraticCurveTo`.

**Do not** assume `BMColor` round-trips through `hexString` — use `bmColorEquals()` for comparisons (it normalises through `.deviceRGB` on AppKit).

On Linux, `BMColor` / `BMFont` / `BMImage` / `BMView` / `BMBezierPath` are intentionally undefined. Any callsite using them must itself be gated.

## Bundled fonts (snapshot determinism)

`Sources/DiagramKitRenderingCG/Resources/Fonts/` ships:

- Noto Sans — Regular, Bold, Italic, BoldItalic
- Noto Sans Mono — Regular, Bold

Both under SIL OFL. They are registered process-wide on first use via `DiagramFontRegistry.registerBundledFontsIfNeeded()` and looked up by family name (`"Noto Sans"`, `"Noto Sans Mono"`) in:

- `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily` (the canonical knobs)
- `DiagramRenderer._monoFont` / `_italicSystemFont` / `_italicMonoFont` (route through `config.*`)
- Five private per-extension helpers in `Treemap`, `Venn`, `Ishikawa`, `EventModeling`
- `MindmapTheme.fontFamily` (default `"Noto Sans"`)

System fonts drift across macOS/iOS major versions; bundled fonts make snapshot images byte-stable. **Don't hardcode `"Menlo"` / `"Trebuchet MS"` etc. in a renderer** — route through `config.*`. Mermaid-specific font fallbacks (e.g. Trebuchet MS for EventModeling) belong in the helper's fallback chain, not at the call site.

## Layer-import rules

A file's home target is determined by its dependencies:

- Touches `CoreGraphics` → `DiagramKitRenderingCG`.
- Touches `UIKit`/`AppKit` only via the `BMColor`/`BMFont`/`BMImage` shims → `DiagramKitModel` under a `#if canImport(UIKit)||canImport(AppKit)` gate.
- No platform deps at all → `DiagramKitCommon`.

Files in `DiagramKitModel` cannot `import DiagramKitRenderingCG`. Files in `DiagramKitRenderingCG` import `DiagramKitModel` + `DiagramKitCommon`. The umbrella `DiagramKit` re-exports the layer below it.

## Concurrency model

- `swiftLanguageModes: [.v6]` is enforced package-wide.
- `strictConcurrencySettings` (the `StrictConcurrency` upcoming feature) is applied per target via the constant in [Package.swift](Package.swift). `InferSendableFromCaptures` is intentionally omitted — it's already default in Swift 6 mode and emits a per-file warning when re-enabled.
- Public types implement `Sendable` explicitly: `DiagramType`, `DiagramPayload`, `DiagramDocument`, `PositionedContent`, `PositionedGraph`, `LayoutConfig`, `EdgeStyle`.
- `async throws` is the public default. `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`); `renderSVG` / `renderASCII` are intentionally **not** main-actor.
- Errors flow through `_withDiagramIssueReporting(operation:)` at every public boundary so test-time observers see uncategorised failures without obstructing flow.
- Underscore-prefixed top-level names are SPI (e.g. `_PositionedNodePayload`, `_renderDiagramSVG`). Public typealiases drop the underscore: `PositionedNode = _PositionedNodePayload`.

## Discipline gates

`Scripts/bootstrap-smoke-check.sh` orchestrates:

1. `swift package dump-package` — manifest sanity.
2. `swift test` — full suite (see [BASELINES.md](BASELINES.md) for caveats around the corpus signal-10 hang).
3. `Scripts/check-file-sizes.sh` — 500-line warn / 1000-line error, allowlist at `Scripts/check-file-sizes-allowlist.txt`.
4. `Scripts/strict-concurrency-check.sh` — `swift build` under `-strict-concurrency=complete -warnings-as-errors`, filtered to `Sources/DiagramKit*/`.
5. `Scripts/check-sendable-annotations.sh` — every `@unchecked Sendable` must be in `.sendable-allowlist.txt` (yellow + sunset) or carry a "Concurrency Contract" banner.
6. `Scripts/linux-check.sh` — Docker/Podman build of the Linux-portable matrix on `swift:6.3.1-noble`.
7. `xcodebuild` for iOS / visionOS / tvOS via the `DiagramKit-Package` auto-scheme.

The four governance scripts originated as ports from the sibling `MusicToolkit` package. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Known deferrals

- **Stage 2.5** — portable text-measurement shim (replacement for `CTLineGetBoundsWithOptions` on Linux) so `ishikawa` / `treeView` / `eventModeling` layouts can run without an Apple runtime.
- **CG/SVG renderer drift** — long-term plan is a single canonical render path; snapshot tests are the only guardrail in the meantime.
- **`RenderConfig.swift` magic constants** — should be lifted into theme tokens.
- **View interactivity** — `DiagramKitViews` is split out, but selection, hit-testing, and editor-oriented state remain future work.
- **`<Module>Bootstrap.phase: Int` markers** — deferred to a future monorepo-promotion stage.

## Suggested reading map

For new contributors, in order:

1. [README.md](README.md) — public surface, install, quick-start.
2. This file — layered target map and the worker-thread invariant.
3. [CLAUDE.md](CLAUDE.md) — invariants, conventions, "where new files belong" decision tree.
4. [CONTRIBUTING.md](CONTRIBUTING.md) — the governance gates and PR workflow.
5. [BASELINES.md](BASELINES.md) — current metrics and known caveats.
6. [docs/archive/PHASES.md](docs/archive/PHASES.md) — completed multi-format roadmap, useful for understanding why the package is shaped the way it is.
