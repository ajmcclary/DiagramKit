# Architecture

DiagramKit is structured as a layered Swift package: a small portable foundation, a substantial parsing/layout core, two Apple-only rendering targets, an umbrella that re-exports the public API, and a thin test-support target. This document describes the layers, the rendering pipeline, the invariants worth defending, and the known drift hazards.

## High-level design goals

- **Pure-data parse and layout.** The parse step yields a typed `MermaidGraph` (one enum case per diagram family); the layout step yields a typed `PositionedGraph`. Neither stage touches CoreGraphics, CoreText, UIKit, or AppKit. This is what makes the engine Linux-portable.
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
              │  DiagramKitViews   │  Apple-only (placeholder stub)
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────────────────────┐
              │            DiagramKit              │  umbrella: public API + Views/
              │  Apple-only edges to RenderingCG/  │
              │  Views via condition:.when(Apple)  │
              └─────────────────────────────────────┘
```

Apple-platform-only edges in [Package.swift](Package.swift) are guarded with `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])`. Source-level platform gates use `#if canImport(CoreGraphics)`, `#if canImport(CoreText)`, and `#if canImport(UIKit) || canImport(AppKit)`.

| Target | What lives there | Linux | Apple |
|---|---|---|---|
| `DiagramKitCommon` | `SVG` primitives, `IssueReportingSupport`, `StableID` (CryptoKit / swift-crypto), text metrics, theme tokens, font-awesome / HTML-entity tables, multiline utilities, styles. | full | full |
| `DiagramKitModel` | ~197 files: per-diagram-type `src_<type>_parser.swift`, `src_<type>_layout.swift`, `src_<type>_renderer.swift`, ASCII converters (`src_ascii_*.swift`), source-preprocessing quartet, `Types.swift`, `RenderConfig.swift`, `RenderOptions.swift`, `RenderTokens.swift`, `PositionedPayloads.swift`, `CrossPlatform.swift` (`BMColor`/`BMFont`/`BMImage` shims), and 28 `FrontmatterBinding+<Type>.swift` adapters. | partial | full |
| `DiagramKitRenderingCG` | Apple-only CG renderer: `DiagramRenderer+<Type>.swift` per diagram family, plus `EdgeRenderer`, `LabelRenderer`, `ShapeRenderer`, `ArrowRenderer`, `CGPathRenderer`, `PreparedDiagram`, `FontRegistry` (`BeautifulMermaidFontRegistry`), `Version`. Bundled fonts under `Resources/Fonts/`. | none | full |
| `DiagramKitTestSupport` | Linux-portable test helpers (no CG/CT/UI deps). | full | full |
| `DiagramKitViews` | Placeholder stub today. The actual SwiftUI/UIKit views (`MermaidView`, `MermaidDiagramView`, `MermaidLayer`, `MermaidDiagram`) currently live in `Sources/DiagramKit/Views/` because they depend on `MermaidPipeline`. A future refactor may extract them via a closure-based Preparer protocol. | none | full |
| `DiagramKit` | Umbrella: `MermaidRenderer`, `MermaidImageRenderer`, `MermaidPipeline`, `Parser.swift`, `Layout.swift`, `DiagramDescriptor.swift`, `src_index.swift`, `src_ascii_index.swift`, plus `Views/`. | partial | full |

## Three-stage pipeline

```
Source string
    │
    ▼
┌────────────────────┐
│  MermaidParser     │   Parse: source → MermaidGraph (typed payload enum)
│   .parse(_:)       │   Lives in: DiagramKit umbrella + DiagramKitModel
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  GraphLayout       │   Layout: MermaidGraph → PositionedGraph
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

`Sources/DiagramKit/Parser.swift` uses a cascading `firstLine.hasPrefix(...)` chain (e.g. `"sequencediagram"`, `"classdiagram"`, `"radar-beta"`). Order matters — narrower prefixes must come before broader ones. The tail handles `flowchart`, `graph`, `stateDiagram-v2`, and the older `state` keyword.

Source preprocessing (frontmatter, multiline-string joining, comment stripping, `%%{init: …}%%` directive) is split across:

- `Sources/DiagramKitModel/SourcePreprocessing.swift` — entry point `_parseFrontMatterAndStripped(...)`
- `Sources/DiagramKitModel/MermaidSourceNormalizer.swift`
- `Sources/DiagramKitModel/FrontmatterDocumentParser.swift`
- `Sources/DiagramKitModel/InitDirectiveParser.swift`

Per-diagram-type parsers receive a typed `frontmatter` argument and pull config off it via the `FrontmatterBinding+<Type>.swift` adapters (one per family).

### Type-safe payloads

`MermaidGraph.payload: DiagramPayload` and `PositionedGraph.content: PositionedContent` are enums with one case per diagram type — never `Any` or untyped dictionaries. `Layout.swift` performs the parse-payload → layout dispatch via these enums and uses `_reportMermaidIssue(...)` for "shouldn't happen" mismatches (logged in tests via `IssueReporting`, swallowed in production).

## The worker-thread invariant

`MermaidRenderer` ([Sources/DiagramKit/MermaidRenderer.swift](Sources/DiagramKit/MermaidRenderer.swift)) is the public façade. Every `async throws` entry point dispatches its work onto a fresh **8 MB-stack `Thread`** via `_runOnWorker`.

**Do not reintroduce a thread pool.** It was attempted in commit `ff2622b` and intentionally reverted (see the doc-comment on `_runOnWorker`). Layout exceeds the cooperative pool's ~512 KB stack budget on nested-subgraph diagrams; running on a dedicated worker thread with an 8 MB stack is the only thing that keeps deeply nested mindmaps and flowcharts from crashing on stack overflow.

Implementation details:
- `MermaidPipeline` ([Sources/DiagramKit/MermaidPipeline.swift](Sources/DiagramKit/MermaidPipeline.swift)) is a stateless `enum` (NOT an actor) holding the synchronous, nonisolated implementations. Each public method calls `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` first — critical for snapshot determinism.
- `MermaidImageRenderer` ([Sources/DiagramKit/ImageRenderer.swift](Sources/DiagramKit/ImageRenderer.swift)) routes through `MermaidRenderer._runOnWorker` rather than a separate worker (the duplication was removed).

## Rendering backends — drift hazard

Every diagram type has **two independent renderers** that share no geometry or text-measurement logic:

- **CG path:** `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift` — extends `DiagramRenderer`, drives a `CGContext`, used by `renderImage(...)`.
- **SVG path:** `Sources/DiagramKitModel/src_<type>_renderer.swift` (or `_svg.swift`) — used by `renderSVG(...)`.

These will drift over time. **Snapshot tests catch divergence** — every diagram family has SVG, image, and ASCII baselines under `Tests/DiagramKitTests/__Snapshots__/`. Consolidation onto a single canonical render path is a long-standing follow-up; the dual paths exist because the JS port preserved upstream Mermaid's `Renderer.draw(svg)` and the CG path was added native-side.

When changing geometry, label measurement, or arrow routing for a diagram family, **change both renderers in the same commit and re-record both snapshot baselines**. A drift in either direction is silent until the corpus run flags it.

## Cross-platform shim

`Sources/DiagramKitModel/CrossPlatform.swift` defines `BMColor`, `BMFont`, `BMImage`, `BMBezierPath`, `BMView` typealiases via `#if canImport(UIKit)` / `#if canImport(AppKit)`. AppKit's `NSBezierPath` doesn't expose `cgPath`, so a custom `bm_cgPath` converter walks element-by-element including `.cubicCurveTo` / `.quadraticCurveTo`.

**Do not** assume `BMColor` round-trips through `hexString` — use `bmColorEquals()` for comparisons (it normalises through `.deviceRGB` on AppKit).

On Linux, `BMColor` / `BMFont` / `BMImage` / `BMView` / `BMBezierPath` are intentionally undefined. Any callsite using them must itself be gated.

## Bundled fonts (snapshot determinism)

`Sources/DiagramKitRenderingCG/Resources/Fonts/` ships:

- Noto Sans — Regular, Bold, Italic, BoldItalic
- Noto Sans Mono — Regular, Bold

Both under SIL OFL. They are registered process-wide on first use via `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()` and looked up by family name (`"Noto Sans"`, `"Noto Sans Mono"`) in:

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
- `strictConcurrencySettings` (`StrictConcurrency` + `InferSendableFromCaptures` upcoming features) is applied per target via the constant in [Package.swift](Package.swift).
- Public types implement `Sendable` explicitly: `DiagramType`, `DiagramPayload`, `MermaidGraph`, `PositionedContent`, `PositionedGraph`, `LayoutConfig`, `EdgeStyle`.
- `async throws` is the public default. `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`); `renderSVG` / `renderASCII` are intentionally **not** main-actor.
- Errors flow through `_withMermaidIssueReporting(operation:)` at every public boundary so test-time observers see uncategorised failures without obstructing flow.
- Underscore-prefixed top-level names are SPI (e.g. `_PositionedNodePayload`, `_renderMermaidSVG`). Public typealiases drop the underscore: `PositionedNode = _PositionedNodePayload`.

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
- **`DiagramKitViews` extraction** — currently a placeholder stub; the real views still live in the umbrella because they depend on `MermaidPipeline`.
- **`<Module>Bootstrap.phase: Int` markers** — deferred to Stage 6 monorepo promotion (per [ANALYSIS.md](ANALYSIS.md)).

## Suggested reading map

For new contributors, in order:

1. [README.md](README.md) — public surface, install, quick-start.
2. This file — layered target map and the worker-thread invariant.
3. [CLAUDE.md](CLAUDE.md) — invariants, conventions, "where new files belong" decision tree.
4. [CONTRIBUTING.md](CONTRIBUTING.md) — the governance gates and PR workflow.
5. [BASELINES.md](BASELINES.md) — current metrics and known caveats.
6. [ANALYSIS.md](ANALYSIS.md) — six-stage import plan and current status.
