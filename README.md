# DiagramKit

**DiagramKit** is a native Swift diagramming toolkit that parses, lays out, and renders diagrams across five source formats — Mermaid, D2, Graphviz DOT, Structurizr, and PlantUML — from a single engine. It covers 28 diagram families, ships three independent render backends (Core Graphics images, SVG, and ASCII), and exposes SwiftUI, UIKit, and AppKit view wrappers for drop-in display on Apple platforms. A Linux-portable parse-and-layout core keeps non-rendering workflows cross-platform.

> **Status:** feature-complete. 14 SwiftPM library products. 1,298 snapshot baselines (437 image + 437 SVG + 424 ASCII) across 424 corpus entries. The closing-commit map for every Critical review finding and follow-on feature is in [docs/archive/BASELINES-history.md](docs/archive/BASELINES-history.md); archived plans live at [docs/archive/PLAN.md](docs/archive/PLAN.md) and [docs/archive/PLAN-followup.md](docs/archive/PLAN-followup.md).

---

## Features

### Multi-format engine

Five source formats with automatic detection — DiagramKit probes the input and dispatches to the correct importer:

| Format | Import | Export | Rendering | Interactive editing |
|---|---|---|---|---|
| **Mermaid** (flowchart, sequence, class, ER, Gantt, mindmap, C4, … — 28 families) | ✓ | ✓ | CG · SVG · ASCII | ✓ (flowchart, sequence, Gantt) |
| **D2** | ✓ | ✓ | CG · SVG · ASCII | — |
| **Graphviz DOT** | ✓ | ✓ | CG · SVG · ASCII | — |
| **Structurizr** | ✓ | ✓ | CG · SVG | — |
| **PlantUML** (sequence, class, state/activity, mindmap, Gantt, C4) | ✓ | ✓ | CG · SVG | — |

Import dispatch is automatic: `DiagramEngine.renderSVG(source)` probes the source string and routes to the right parser. An explicit `sourceFormat:` parameter is available when you know the format ahead of time.

### 28 diagram families

`flowchart` · `stateDiagram` · `sequenceDiagram` · `classDiagram` · `erDiagram` · `gantt` · `gitGraph` · `mindmap` · `journey` · `pie` · `quadrantChart` · `radar` · `xyChart` · `timeline` · `sankey` · `block` · `kanban` · `requirement` · `c4` (Context, Container, Component, Dynamic, Deployment) · `architecture` · `packet` · `treemap` · `treeView` · `ishikawa` · `eventModeling` · `wardley` · `venn` · `zenuml`

All families have CG, SVG, and ASCII renderers. Parsers handle YAML frontmatter, `%%{init: …}%%` directives, and theme tokens per the upstream Mermaid specification.

### Three render backends

A single layout pass feeds three independent render paths:

| Backend | Method | Output | Platforms |
|---|---|---|---|
| **Core Graphics** | `renderImage(source:)` | `BMImage` (UIImage / NSImage), PNG, JPEG at configurable scale | Apple only |
| **SVG** | `renderSVG(source:)` | Standards-compliant SVG string with configurable ID policies | Apple + Linux (partial) |
| **ASCII** | `renderASCII(source:)` | Plain-text diagram suitable for terminals, log output, or inline documentation | Apple + Linux (partial) |

The CG and SVG renderers are independent implementations — they share no geometry or measurement code. Snapshot tests (437 image + 437 SVG baselines) guard against drift between the two paths.

### Apple-platform views

Drop-in display components for SwiftUI, UIKit, and AppKit:

- **`DiagramView`** — SwiftUI `View` with automatic async rendering, configurable theme, and frame constraints.
- **`DiagramNativeView`** — UIKit `UIView` / AppKit `NSView` subclass for imperative UI code.
- **`DiagramLayer`** — `CALayer` subclass for compositing diagrams into custom view hierarchies.
- **`DiagramViewModel`** — Observable-object wrapper that manages parse/layout/render lifecycle with loading and error states.

### Interactive diagram editor

`DiagramKitInteractive` provides a mutation-based editing surface for supported families (flowchart, sequence, Gantt):

- **`DiagramEditor`** — undo/redo stack, source round-trip synchronization, family-specific mutation types.
- **`DiagramMutation`** — typed mutation protocol with add/remove/reorder/edit operations.
- **`FlowchartSubgraphMutation`** — subgraph-aware editing for flowchart diagrams.

### Import and export

Round-trip between formats using the importer and exporter registries:

- **`DiagramKitImport`** — `ImporterRegistry` discovers the right importer by probing the source string or via explicit `DiagramFormatID`.
- **`DiagramKitExport`** — `ExporterRegistry` exports any supported diagram type to the target format. Round-trip harness tests verify structural fidelity and diagnostic pairing.

### Snapshot-deterministic rendering

Bundled Noto Sans / Noto Sans Mono fonts neutralize system-font drift across macOS and iOS major versions. Every render path routes font lookup through `RenderConfig.defaultFontFamily` / `defaultProportionalFontFamily`. The result: a `flowchart LR` diagram rendered on macOS 26 produces the same pixels as on macOS 27 — and the same SVG glyph positions — without the host system's installed fonts.

### Linux portability

The parse and layout stages have no Core Graphics, Core Text, UIKit, or AppKit dependencies. On Linux (`swift:6.3.1-noble`), you can parse Mermaid, D2, DOT, Structurizr, and PlantUML sources and render them to SVG or ASCII for diagram families that don't require text measurement (≈25 of 28 families). CoreText-dependent layouts (`ishikawa`, `treeView`, `eventModeling`) are gated behind `#if canImport(CoreText)` and compile to empty stubs.

### Strict Swift 6 concurrency

The entire package compiles under `swiftLanguageModes: [.v6]` with the `StrictConcurrency` upcoming feature applied per target. Public entry points use `async throws`; `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`).

---

## Requirements

| Component | Minimum |
|---|---|
| Swift tools | 6.3 |
| macOS | 26 |
| iOS | 26 |
| Linux | `swift:6.3.1-noble` (parse + layout + SVG/ASCII rendering; no CG image output) |

---

## Installation

Add DiagramKit as a SwiftPM dependency:

```swift
.package(url: "https://github.com/<owner>/mermaid-swift", branch: "main")
```

Then depend on the umbrella product (which re-exports everything you'll typically need):

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "DiagramKit", package: "mermaid-swift")
    ]
)
```

### Granular products

For smaller dependency footprints, depend on individual products:

| Product | What it provides |
|---|---|
| `DiagramKit` | Umbrella — `DiagramEngine`, `DiagramImageRenderer`, `DiagramPipeline`, all re-exports |
| `DiagramKitCommon` | No-UI primitives: `SVG`, theme tokens, `StableID`, `DiagramFormatID`, diagnostics |
| `DiagramKitModel` | Parsers, layouts, SVG/ASCII renderers, `DiagramDocument`, `PositionedGraph`, `DiagramType` |
| `DiagramKitImport` | `DiagramLoader`, `ImporterRegistry`, multi-format import dispatch |
| `DiagramKitExport` | `DiagramExporter`, `ExporterRegistry`, `DiagramExportResult` |
| `DiagramKitMermaid` | Mermaid-specific parser, exporter, and family descriptors |
| `DiagramKitD2` | D2-specific importer and exporter |
| `DiagramKitGraphviz` | Graphviz DOT importer and exporter |
| `DiagramKitStructurizr` | Structurizr DSL importer and exporter |
| `DiagramKitPlantUML` | PlantUML importer and exporter (sequence, class, state/activity, mindmap, Gantt, C4) |
| `DiagramKitRenderingCG` | Core Graphics renderer + bundled fonts (Apple only) |
| `DiagramKitViews` | `DiagramView`, `DiagramNativeView`, `DiagramLayer`, `DiagramViewModel` (Apple only) |
| `DiagramKitInteractive` | `DiagramEditor`, `DiagramMutation`, undo/redo (Apple only) |
| `DiagramKitTestSupport` | Test harnesses, round-trip utilities, corpus fixtures |

---

## Quick start

### Render a diagram to an image (UIImage / NSImage)

```swift
import DiagramKit

let source = """
flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C[Done]
    B -->|no| A
"""

let image = try await DiagramEngine.renderImage(
    source: source,
    scale: 2.0
)
```

Or use the stateful `DiagramImageRenderer` for repeated renders with a shared configuration:

```swift
let renderer = DiagramImageRenderer(theme: .default, config: LayoutConfig())
renderer.scale = 3.0

let image1 = try await renderer.renderImage(from: flowchartSource)
let image2 = try await renderer.renderImage(from: sequenceSource)
```

### Render to SVG

```swift
let svg = try await DiagramEngine.renderSVG(source: source)
```

### Render to ASCII (terminal-friendly)

```swift
let output = try await DiagramEngine.renderASCII(source: source)
print(output.text)          // the ASCII art
print(output.diagnostics)   // any parse/layout warnings
```

### Display in SwiftUI

```swift
import SwiftUI
import DiagramKit

struct ContentView: View {
    let source: String

    var body: some View {
        DiagramView(source: source)
            .frame(minWidth: 320, minHeight: 200)
    }
}
```

### Parse without rendering (Linux-portable)

```swift
let document = try await DiagramEngine.parse(source)
// document is a DiagramDocument — examine .type, .payload, .content
```

### Parse with diagnostics

```swift
let result = try await DiagramEngine.parseImportResult(source: source)
print(result.document)      // the parsed model
print(result.diagnostics)   // parse-tier warnings (C4 $boundary mismatch, Kanban duplicates, …)
```

### Lay out (parse + position)

```swift
let positioned = try await DiagramEngine.layout(source, config: .default)
// positioned is the laid-out scene graph; feed it to renderSVG / renderASCII
```

### Force a specific source format

```swift
let svg = try await DiagramEngine.renderSVG(
    source: d2Source,
    sourceFormat: .d2
)
```

### Check Linux support for a diagram family

```swift
let (supported, reason) = DiagramEngine.linuxSupport(for: .ishikawa)
// (false, "ishikawa layout requires CoreText text measurement")
```

### Export a diagram to another format

```swift
let document = try await DiagramEngine.parse(mermaidSource)
let exporter = ExporterRegistry.default.exporter(named: .graphviz)!
let exported = try exporter.export(document)
print(exported.source)  // Graphviz DOT source
```

### Use the interactive editor

```swift
import DiagramKitInteractive

let editor = DiagramEditor(source: flowchartSource, type: .flowchart)
try editor.apply(.addNode(id: "D", label: "Review"))
try editor.apply(.addEdge(from: "C", to: "D"))
print(editor.source)  // updated Mermaid source with the new node and edge
```

---

## Package topology

```
DiagramKitCommon           (Linux + Apple)  — SVG primitives, theme, text metrics, StableID, DiagramFormatID, diagnostics
   ^
DiagramKitModel            (Linux + Apple)  — parsers, layouts, SVG/ASCII renderers, frontmatter binding, payloads
   ^                                           UIKit/AppKit/CoreText files compile to empty on Linux
   +-----------+-----------+-----------+-----------+-----------+
DiagramKitRenderingCG  DiagramKitImport  DiagramKitExport  DiagramKitTestSupport  format slices:
   (Apple-only)        (Linux + Apple)   (Linux + Apple)   (Linux + Apple)        DiagramKitMermaid / D2 / Graphviz / Structurizr / PlantUML
   ^
DiagramKitViews            (Apple-only)  — DiagramView, DiagramNativeView, DiagramLayer
   ^
DiagramKitInteractive      (Apple-only)  — DiagramEditor, mutations, undo/redo
   ^
DiagramKit                 (umbrella)    — DiagramEngine, DiagramImageRenderer, DiagramPipeline, public API + re-exports
```

Apple-only edges to `DiagramKitRenderingCG`, `DiagramKitViews`, and `DiagramKitInteractive` are guarded in `Package.swift` with `condition: .when(platforms: [Apple])`.

For the full architectural breakdown — the three-stage pipeline, the worker-thread invariant, the dual CG/SVG render-path drift hazard, and the layer-import rules — see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Corpus and snapshot testing

The test corpus at `Sources/DiagramKitSample/Resources/test-diagrams.json` contains **424 entries** (397 Mermaid-only + 27 multi-format with D2, DOT, Structurizr, and PlantUML sources). Snapshot baselines live under `Tests/DiagramKitTests/__Snapshots__/`:

| Kind | Count | Description |
|---|---|---|
| SVG | 437 | 424 Mermaid + 13 multi-format |
| Image (PNG) | 437 | 424 Mermaid + 13 multi-format |
| ASCII | 424 | One per corpus entry |
| **Total** | **1,298** | (`swift-snapshot-testing` writes SVG and ASCII as `.txt`) |

```bash
# Verify all snapshot baselines
swift test --filter CorpusSnapshotTests          # Mermaid-only (~5 min)
swift test --filter CorpusMultiFormatSnapshotTests  # Multi-format

# Re-record after an intentional rendering change
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests

# Chunked execution (avoids a known signal-10 interaction in the parameterized suite)
SNAPSHOT_DIAGRAM_IDS=block-1-simple,flowchart-1 SNAPSHOT_TESTING_RECORD=true \
  swift test --filter CorpusSnapshotTests/imageSnapshot
```

Image snapshots use `precision: 0.99, perceptualPrecision: 0.98`.

---

## Quality and verification

```bash
swift build                           # library + sample app
swift build --build-tests             # compile test suite
swift test                            # full suite (298 test files under Tests/DiagramKitTests)
swift test --filter <NameOrPattern>   # narrow run
./Scripts/bootstrap-smoke-check.sh    # local merge gate (build, test, governance scripts, Linux check)
```

The four governance scripts enforce invariants locally and in CI:

| Script | Enforces |
|---|---|
| `Scripts/check-file-sizes.sh` | 500-line warn / 1000-line error per `.swift` file |
| `Scripts/check-sendable-annotations.sh` | Every `@unchecked Sendable` must carry a Concurrency Contract banner or be allowlisted |
| `Scripts/strict-concurrency-check.sh` | First-party strict-concurrency build passes clean |
| `Scripts/linux-check.sh` | Docker/Podman build of the Linux-portable matrix on `swift:6.3.1-noble` |

---

## Migration from Mermaid-prefixed names

All public entry points use Diagram-prefixed names. Mermaid-prefixed compatibility aliases remain available with compiler fix-its through the next major version.

| Deprecated alias | Canonical name |
|---|---|
| `MermaidRenderer` | `DiagramEngine` |
| `MermaidPipeline` | `DiagramPipeline` |
| `MermaidImageRenderer` | `DiagramImageRenderer` |
| `MermaidGraph` | `DiagramDocument` |
| `BeautifulMermaidError` | `DiagramError` |
| `MermaidStructuralError` | `DiagramStructuralError` |
| `MermaidView` | `DiagramNativeView` |
| `MermaidDiagramView` | `DiagramView` |
| `MermaidLayer` | `DiagramLayer` |
| `MermaidDiagram` | `DiagramViewModel` |
| `parseMermaid()` | `parseDiagram()` |
| `renderMermaidImage(...)` | `renderDiagramImage(...)` |
| `renderMermaidSVG(...)` | `renderDiagramSVG(...)` |
| `renderMermaidASCII(...)` | `renderDiagramASCII(...)` |

---

## Documentation

| Document | Purpose |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layered target map, three-stage pipeline, worker-thread invariant, dual CG/SVG render-path drift hazard, layer-import rules |
| [BASELINES.md](BASELINES.md) | Build times, test counts, snapshot counts, file-size landscape, gate status, open deferrals |
| [CONTRIBUTING.md](CONTRIBUTING.md) | PR workflow, file-size policy, green/yellow/red `@unchecked Sendable` policy, adding a new diagram type, snapshot-test workflow |
| [ATTRIBUTION.md](ATTRIBUTION.md) | Upstream `mermaid-js` lineage, bundled fonts, library dependencies |
| [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) | Bundled assets with copyright + license text references |
| [CLAUDE.md](CLAUDE.md) | Invariants, conventions, where new files belong, commands |
| [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md) | Typed-factory decision tree for parser/exporter diagnostics |
| [docs/archive/](docs/archive/) | Historical record: completed phases, execution plans, release notes, closing-commit map |

---

## Running the sample app

```bash
swift run DiagramKitSample
```

The SwiftUI sample app in `Sources/DiagramKitSample/` exercises every diagram family and renderer, and serves as the live-editing front-end for the test corpus.

---

## License

DiagramKit's own source is released under the same terms as the rest of the `mermaid-swift` repository. Bundled assets are licensed separately as documented in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). Upstream `mermaid-js` is MIT — see [ATTRIBUTION.md](ATTRIBUTION.md) for lineage and license citation.
