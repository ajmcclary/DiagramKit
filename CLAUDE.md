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
- [BASELINES.md](BASELINES.md) - current build, test, snapshot, and gate
  metrics.
- [CONTRIBUTING.md](CONTRIBUTING.md) - PR workflow, file-size policy, and
  green/yellow/red `@unchecked Sendable` policy.
- [ATTRIBUTION.md](ATTRIBUTION.md) - upstream Mermaid lineage and licenses.
- [AGENTS.md](AGENTS.md) - terse companion instructions for non-Claude agents.
- [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md) -
  the typed-factory decision tree for parser/exporter diagnostics, enforced by
  `Scripts/check-diagnostic-discipline.sh`.
- [docs/archive/](docs/archive/) - historical record: completed roadmap
  ([PHASES.md](docs/archive/PHASES.md), [PHASE-0.md](docs/archive/PHASE-0.md) …
  [PHASE-10.md](docs/archive/PHASE-10.md)), execution plans
  ([PLAN.md](docs/archive/PLAN.md), [PLAN-followup.md](docs/archive/PLAN-followup.md)),
  shipped-cycle release notes
  ([RELEASE_NOTES-review-remediation.md](docs/archive/RELEASE_NOTES-review-remediation.md)),
  and the review-remediation closing-commit map
  ([BASELINES-history.md](docs/archive/BASELINES-history.md)).

## Commands

```bash
swift build                                         # library + playground
swift build --build-tests                           # also compile tests
swift test --filter <NameOrPattern>                 # one suite/test
swift test --filter CorpusSnapshotTests             # corpus snapshots (~5 min; see caveats)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot
swift run DiagramKitSample                          # SwiftUI sample app

# Rebaseline snapshots after a renderer change (chunked to avoid signal-10):
Scripts/rebaseline-snapshots.sh                     # all SVG + image
Scripts/rebaseline-snapshots.sh --target svg        # SVG only
Scripts/rebaseline-snapshots.sh --target image --chunk 10  # smaller chunks

# Record/refresh snapshot baselines:
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns swift test --filter CorpusSnapshotTests/imageSnapshot

# After editing Package.swift:
swift package resolve
```

There is no separate lint/format command. Verification is `swift test` plus the
discipline gates below.

## Target Layout

The package ships 14 layered SwiftPM library products. Imports flow only
downward; importers/exporters and the `DiagramKitMermaid` slice sit
beside `DiagramKitModel` so they can be consumed without the umbrella.

```text
DiagramKitCommon           (Linux + Apple)  - SVG primitives, theme, text metrics, IssueReporting, StableID, DiagramDiagnostic, BlockRenderConstants, DiagramWorkerConfig
   ^
DiagramKitModel            (Linux + Apple)  - parsers, layouts, SVG/ASCII renderers, payloads
   ^                                           UIKit/AppKit/CoreText files compile to empty on Linux
   +-----------+-----------+-----------+-----------+-----------+
DiagramKitRenderingCG  DiagramKitImport  DiagramKitExport  DiagramKitTestSupport  format slices:
   (Apple-only)        (Linux + Apple)   (Linux + Apple)   (Linux + Apple)        DiagramKitMermaid / D2 / Graphviz / Structurizr / PlantUML
   ^
DiagramKitViews            (Apple-only)     - DiagramView, DiagramNativeView, DiagramLayer
   ^                                           DiagramKitInteractive (Apple-only) — DiagramEditor + mutations
DiagramKit                 (umbrella)       - public API + re-exports (DiagramKitMermaid, Views, RenderingCG, Interactive)
```

`DiagramKit` re-exports the lower targets through `ReExports.swift`. The
package-wide `platforms:` floor is macOS 26.3 + iOS 26.3 (raised to match
CodeEditorPlugin, the sample app's code editor); Apple-only targets like
`DiagramKitRenderingCG`, `DiagramKitViews`, and `DiagramKitInteractive` are
gated at the source level with `#if canImport(UIKit) || canImport(AppKit)` /
`#if canImport(CoreGraphics)` and compile to empty on Linux.

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
- `AsciiRenderOutput` (`text: String`, `diagnostics: [DiagramDiagnostic]`) is
  the return type of `DiagramEngine.renderASCII(...)` and
  `DiagramPipeline.renderASCII(...)`. The String-returning
  `String.renderDiagramASCII(...)` instance method forwards `.text` for
  backward compatibility.
- `PreparedDiagram.diagnostics` aggregates parse-time
  `DiagramImportResult.diagnostics` and layout-time
  `PositionedGraph.diagnostics`, in that order.
- `DiagramEngine.parseImportResult(source:registry:)` is the
  diagnostic-aware async entry; `DiagramEngine.parse(_:)` and
  `String.parseDiagram()` keep their single-return shape for callers that
  don't need diagnostics.
- `MermaidImporter` populates `DiagramImportResult.diagnostics` for
  diagnostic-emitting families (currently C4 \$boundary mismatch and
  Kanban duplicate-node warnings; other Mermaid families surface only
  layout-tier diagnostics via `PositionedGraph`).
- The Mermaid-prefixed public alias cohort (`MermaidParser`,
  `MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`,
  `MermaidStructuralError`, `renderMermaidSVG`, etc.) was sunset in
  Session 12. The free-function SVG entry points (`renderDiagramSVG`,
  `renderDiagramSVGAsync`) and `DiagramPipeline.renderSVG(_:options:)`
  / `_renderDiagramSVG` SPI deprecated in Session 7 (`381fd81`) went
  away in the same change. Use `DiagramEngine.renderSVG(source:…)`,
  `DiagramPipeline.renderSVG(source:…)`, or the canonical `String`
  instance methods (`parseDiagram()`, `renderDiagramImage(…)`,
  `renderDiagramSVG(…)`, `renderDiagramASCII(…)`).

## Critical Invariants

- **Never introduce a thread pool in production parse/layout/render code.**
  Every public engine/pipeline entry point must dispatch work to a fresh
  8 MB-stack `Thread` via `DiagramEngine._runOnWorker` /
  `DiagramWorkerThread.run`. This was tried and reverted in `ff2622b`; the
  cooperative pool's roughly 512 KB stack cannot handle deeply nested subgraph
  layouts. Scope: this invariant applies to `Sources/DiagramKit*/` production
  code on the parse/layout/render path. Test suites
  (`MermaidPipelineConcurrencyTests` exercises the engine under
  `withThrowingTaskGroup` to validate determinism) and the
  `DiagramKitSample` sample app (`Task.detached`, `async let` for UI
  loading) are explicitly out of scope. Narrow `DispatchQueue` caches
  serializing a single regex/formatter cache inside a parser
  (e.g. `_dateFormatterCacheQueue`, `_reqRegexCacheQueue`) are not
  pools and are allowed.
- **Register bundled fonts first.** `DiagramFontRegistry.registerBundledFontsIfNeeded()`
  must run at the start of every pipeline method. Skipping it breaks snapshot
  determinism across OS versions.
- **Parser dispatch order matters.** `Sources/DiagramKit/DiagramDescriptor.swift`
  uses a cascading `firstLine.hasPrefix(...)` chain (matchers prefer
  `startsWithToken` over raw `hasPrefix` for non-trivial prefixes).
  Narrower prefixes must precede broader prefixes; the fallback handles
  `flowchart`, `graph`, `stateDiagram-v2`, and `state`.
- **Two independent renderers exist.** CG/image renderers live under
  `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift`; SVG renderers
  live under `Sources/DiagramKitModel/src_<type>_renderer.swift`. They share no
  geometry/text-measurement logic. Snapshot tests are the guardrail.
- **Use `bmColorEquals()` for color comparisons.** Do not compare colors through
  `hexString` round-trips; AppKit normalizes `NSColor` through `.deviceRGB`.
- **`DiagramKitModel` free functions are SPI-equivalent.** `layoutC4Diagram`,
  `renderQuadrantSvg`, `parseIshikawaDiagram`, etc. are implementation hooks for
  the umbrella module, format slices, and tests — not the supported public API.
  Callers that use them directly must handle worker-thread dispatch, font
  registration, and issue-reporting context themselves. The supported public
  surface is `DiagramEngine.*` / `DiagramImageRenderer.*`. See
  [ARCHITECTURE.md](ARCHITECTURE.md#model-layer-free-functions-are-spi-equivalent).

## Pipeline

```text
Source string
  -> DiagramLoader.parseImportResult (registry probe → MermaidImporter / D2 / DOT / …)
  -> DiagramImportResult { document, diagnostics }      # parse-tier diagnostics
  -> GraphLayout(...).layout
  -> PositionedGraph { …, diagnostics }                  # + layout-tier diagnostics
  -> DiagramRenderer.render (CG) | renderSVG | renderASCII
                              |                      \
                              v                       \-> AsciiRenderOutput { text, diagnostics }
                       PreparedDiagram { diagnostics = import + layout }
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
  HTML-entity tables, multiline utilities, styles, and
  `RecoveryMarker/` (shared `RecoveryMarkerScanner<Kind>` + `DeclarationIndex`
  scaffolding for the comment-encoded recovery-marker pattern used by D2,
  DOT, PlantUML, and Structurizr importers/exporters).
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
  `DiagramPreparerWiring.swift`, `DiagramDescriptor.swift` (parser
  dispatch), `DiagramRegistry+<Type>.swift` (per-family descriptor
  registration, 28 files), `Layout.swift`, `src_ascii_index.swift`,
  `MermaidImporter.swift`, `SVGRenderRegistry.swift`,
  `AsciiRenderRegistry.swift`, `AsciiDocumentRenderRegistry.swift`,
  `AsciiRenderOutput.swift`, `SVGIDGenerator.swift`, and
  `ReExports.swift`.
- `Sources/DiagramKitImport/` - importer protocol and registry boundary
  (`DiagramSourceImporter`, `ImporterRegistry`, `DiagramLoader`,
  `DiagramImportResult`). `DiagramDiagnostic` lives in `DiagramKitCommon`
  (see Phase 4).
- `Sources/DiagramKitExport/` - exporter protocol, registry, and loader
  (`DiagramExporter`, `ExporterRegistry`, `DiagramExportLoader`,
  `DiagramExportResult`, `DiagramExportError`). Depends only on
  `DiagramKitCommon` and `DiagramKitModel`.
- `Sources/DiagramKitMermaid/` - Mermaid source exporter
  (`MermaidExporter` + per-family `MermaidExport/*.swift`). Moved out of
  the umbrella in Phase 4 so consumers can construct it without
  importing `DiagramKit`.
- `Sources/DiagramKitD2/` - D2 importer + exporter (`D2Importer`,
  `D2Parser`, `D2Mapper`, `D2Exporter`).
- `Sources/DiagramKitGraphviz/` - Graphviz DOT importer + exporter
  (`GraphvizImporter`, `DOTParser`, `DOTMapper`, `DOTExporter`).
  `DOTExporter` covers the flowchart family; other families surface a
  `.unsupported` diagnostic on `DiagramExportResult` rather than throwing.
- `Sources/DiagramKitStructurizr/` - Structurizr DSL importer + exporter.
- `Sources/DiagramKitPlantUML/` - PlantUML sequence importer + exporter
  (`PlantUMLImporter`, `PlantUMLExporter`, `PlantUMLSequenceExporter`).
- `Sources/DiagramKitInteractive/` - Apple-only `DiagramEditor` plus
  mutation/undo support.
- `Sources/DiagramKitTestSupport/` - Linux-portable test helpers.
- `Sources/DiagramKitSample/` - SwiftUI sample app (executable target
  `DiagramKitSample`) and the current `test-diagrams.json` corpus source.
  App chrome consumes the external DesignKit package (`DesignKitTokens`/
  `DesignKitThemes`); app-private design-system components live in
  `Sources/DiagramKitSample/DesignSystem/`. The code editor in `EditorPane`
  is CodeEditorPlugin's `CodeEditor` (URL dependency tracking `main` until
  that repo tags a release; diagram-DSL languages
  mermaid/d2/dot/structurizr/plantuml live there). The old NativeCodeEditor/LineNumberRuler/EditorMinimap/
  DiagramSyntaxHighlighter were removed in the 2026-07-13 migration. Diagram/canvas theming
  (`DiagramTheme`, `Theme+ZedTrek.swift`) is independent of DesignKit;
  canvas-follows-chrome syncs by theme display name (contract-tested).
- `Tests/DiagramKitTests/` - XCTest and swift-testing suites plus corpus
  snapshots.
- `Tests/DiagramKitLinuxTests/` - Linux-portable swift-testing suite that
  pins the `DiagramError.unsupportedOnPlatform` contract mechanism + the
  zero-unsupported-families lockdown, and validates the three formerly
  CoreText-bound families (ishikawa / treeView / eventModeling) parse +
  renderSVG + renderASCII successfully on Linux. Built and run under
  `Dockerfile.linux-check`.

## Testing And Snapshots

- Current test source count: 299 Swift files (297 under `Tests/DiagramKitTests`, 2 under `Tests/DiagramKitLinuxTests`). The 15-file XCUI accessibility bundle was removed alongside the 2026-05-18 sample-app relocation; the Xcode-side accessibility audit is no longer gated.
- The corpus is `Sources/DiagramKitSample/Resources/test-diagrams.json` with
  430 entries (401 Mermaid-only + 29 multi-format: D2, DOT, Structurizr, PlantUML).
- Corpus baselines under `Tests/DiagramKitTests/__Snapshots__/` track
  443 SVG, 443 image, and 430 ASCII snapshots (1316 total; stored on
  disk as 443 PNG + 873 `.txt` — `swift-snapshot-testing` writes SVG
  and ASCII to `.txt`).
- Image snapshots use `precision: 0.99, perceptualPrecision: 0.98` to tolerate
  CoreText rasterization drift across CPU architectures.
- Multi-format snapshot tests use format-suffixed names (`entry-id-format`) to
  avoid collisions between formats sharing the same `diagram.id`.
- The full parameterized `CorpusSnapshotTests` run has a known
  `swift-testing` / `swift-snapshot-testing` signal-10 caveat. Use chunked
  execution with `SNAPSHOT_DIAGRAM_IDS` when recording.

**Round-trip discipline.** Beyond snapshot equality, every importer/exporter
pair the library ships is gated on `parse → export → parse → assert structurally
equal` via the `DiagramKitTestSupport.RoundTripHarness`. Same-format (14 cells)
and cross-format (8 unordered pairs / 16 ordered directions) cover every
intersecting family. Allowed losses are typed and closed — `RoundTripLoss`
admits no `case other(_)`, and every observed loss must have a paired
`.warning`/`.unsupported` diagnostic on the export step that produced it.
Fixtures live under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
Run with `swift test --filter "RoundTrip"`.

**Diagnostic discipline.** Emission sites use the typed
`DiagramDiagnostic.lossyTransform(.<category>, ...)` /
`.featureDropped(.<category>, ...)` / `.informational(.<category>, ...)`
factories; raw `DiagramDiagnostic(severity:message:)` is deprecated.
Decision tree, category table, silent-drop policy, and throw boundary
live in [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md).
Enforced by `Scripts/check-diagnostic-discipline.sh`. The harness pairs
`RoundTripLoss` to diagnostics by typed `DiagnosticCategory` equality —
no keyword matching.

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

`DiagramEngine.renderSVG`, `renderASCII`, and `parseImportResult` (plus
`String.renderDiagramSVG` / `renderDiagramASCII`) are available on Linux.

All 28 diagram families are Linux-supported as of Stage 2.5.
`DiagramDescriptor.linuxSupport: Bool` is the per-family flag and
`DiagramEngine.linuxSupport(for:)` is the public introspection API —
both currently return `true` / `(true, nil)` for every family in the
default registry. The `DiagramError.unsupportedOnPlatform` case remains
as the protocol contract for third-party importers that declare
unsupported families in custom registries.

On Linux, text measurement for `ishikawa`, `treeView`, and
`eventModeling` falls back to `TextMetrics.shared.estimateTextWidth`'s
char-count estimation (0.55× / 0.6× fontSize per character). Output is
geometrically valid (no NaN, positive widths/heights) but not
pixel-equivalent to Apple's CoreText measurement. No Linux-specific
snapshot baselines are recorded.

## Forward Roadmap

Feature-complete: Phases 0–10 plus the follow-on Phases 1–11 (DOT
exporter, full PlantUML family coverage, ASCII renderers for all 28
families) have all landed. Importers and exporters ship for Mermaid,
D2, Graphviz DOT, Structurizr, and PlantUML (sequence + class +
state/activity + mindmap + gantt + C4). The corpus carries 430
entries across 28 diagram families. The active backlog is currently empty;
the completed roadmap lives in [docs/archive/PHASES.md](docs/archive/PHASES.md),
and [BASELINES.md](BASELINES.md) has the closing-commit map.
