# DiagramKit (mermaid-swift)

DiagramKit is a native Swift port of [mermaid-js](https://mermaid.js.org/) covering ~28 diagram families (flowchart, state, sequence, class, ER, Gantt, gitGraph, mindmap, C4, ZenUML, Wardley, Treemap, Sankey, XY chart, Quadrant, Radar, Block, Timeline, EventModeling, Architecture, Ishikawa, Kanban, Packet, Pie, Requirement, TreeView, Venn, ZenUML). It exposes three render backends — Core Graphics images, SVG, and ASCII — plus a SwiftUI/UIKit/AppKit view wrapper.

> **Status:** active and feature-complete. Phases 0–10 of the multi-format port + the follow-on Phases 1–11 (DOT exporter, full PlantUML family coverage, ASCII renderers for all 28 diagram families) all landed. 13 SwiftPM library products. 1044 snapshot baselines. Closing-commit map for every Critical review finding and follow-on feature item lives in [BASELINES.md](BASELINES.md); the archived plans are at [docs/archive/PLAN.md](docs/archive/PLAN.md) and [docs/archive/PLAN-followup.md](docs/archive/PLAN-followup.md).

## Features

- ~28 mermaid diagram types parsed and laid out natively in Swift.
- Three render backends from a single layout: CoreGraphics (`renderImage`), SVG (`renderSVG`), ASCII (`renderASCII`).
- Snapshot-deterministic rendering via bundled Noto Sans / Noto Sans Mono fonts (system-font drift across macOS major versions is neutralised).
- Frontmatter / init-directive parsing matches upstream Mermaid: YAML frontmatter, `%%{init: …}%%` directives, theme tokens, and per-diagram-type config bindings.
- `DiagramView` (SwiftUI) + `DiagramNativeView` (UIKit/AppKit) for drop-in display on Apple platforms.
- Linux-portable parse + layout (CG/CT-bound layouts excepted); see [ARCHITECTURE.md](ARCHITECTURE.md) for the per-target portability matrix.
- Strict Swift 6 concurrency: `swiftLanguageModes: [.v6]` plus the `StrictConcurrency` upcoming feature applied per target.

## Requirements

| Component | Minimum |
|---|---|
| Swift tools | 6.3 |
| macOS | 14 (Sonoma) |
| iOS | 17 |
| macCatalyst | 17 |
| visionOS | 1 |
| Linux | `swift:6.3.1-noble` (parse + layout subset; no rendering) |

## Install

Add DiagramKit as a SwiftPM dependency:

```swift
.package(path: "../mermaid-swift")          // in-tree
// or
.package(url: "https://github.com/<owner>/mermaid-swift", branch: "main")
```

Then depend on the umbrella product:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "DiagramKit", package: "mermaid-swift")
    ]
)
```

## Package topology

```
DiagramKitCommon           (Linux + Apple)  — SVG primitives, theme, text metrics, IssueReporting, StableID
   ↑
DiagramKitModel            (Linux + Apple)  — parsers, layouts, SVG/ASCII renderers, frontmatter binding, payloads
   ↑                                           UIKit/AppKit/CoreText files compile to empty on Linux
   ├──────────────────┐
DiagramKitRenderingCG     DiagramKitTestSupport
   (Apple-only)            (Linux + Apple)
   ↑
DiagramKitViews            (Apple-only — SwiftUI/UIKit/AppKit view wrappers)
   ↑
DiagramKit                 (umbrella; public API)
   — Apple-only edges to RenderingCG/Views are gated via `condition: .when(platforms: [Apple])`
```

For module-level architecture, layer-import rules, and the rendering pipeline, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Quick start

### Render to a `BMImage` (UIImage / NSImage)

```swift
import DiagramKit

let source = """
flowchart LR
    A[Start] --> B{Decision}
    B -->|yes| C[Done]
    B -->|no| A
"""

let image = try await DiagramImageRenderer.render(
    source,
    scale: 2.0
)
```

### Render to SVG

```swift
let svg: String = try await DiagramEngine.renderSVG(source)
```

### Render to ASCII

```swift
let ascii: String = try await DiagramEngine.renderASCII(source)
print(ascii)
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
let positioned = try await DiagramEngine.layout(source, config: .default)
// positioned is the laid-out scene graph; render with renderSVG / renderASCII
// (renderImage requires CoreGraphics → Apple-only).
```

## Diagram-type coverage

DiagramKit parses and renders the families below. The corpus at [Examples/DiagramPlayground/Resources/test-diagrams.json](Examples/DiagramPlayground/Resources/test-diagrams.json) ships **422** sample diagrams across **28** families (396 Mermaid-only + 26 multi-format with D2, DOT, Structurizr, and PlantUML sources), used as the snapshot-test fixture set.

`flowchart` · `stateDiagram-v2` · `sequenceDiagram` · `classDiagram` · `erDiagram` · `gantt` · `gitGraph` · `mindmap` · `journey` · `pie` · `quadrantChart` · `radar-beta` · `xychart-beta` · `timeline` · `sankey-beta` · `block-beta` · `kanban` · `requirementDiagram` · `c4Context` (and C4 variants) · `architecture-beta` · `packet-beta` · `treemap-beta` · `treeView-beta` · `ishikawa-beta` · `eventModeling-beta` · `wardley-beta` · `venn-beta` · `zenuml`

For the per-diagram-type parser/layout/renderer file map, see the "What lives where" section of [CLAUDE.md](CLAUDE.md).

## Linux portability

| Target | Linux | Notes |
|---|---|---|
| `DiagramKitCommon` | full | No CG/CT/UI dependencies. |
| `DiagramKitModel` | partial | UIKit/AppKit/CoreText files compile to empty on Linux. SVG/ASCII paths that don't measure text work; layouts requiring `CTLineGetBoundsWithOptions` (`ishikawa`, `treeView`, `eventModeling`) are unreachable until Stage 2.5 ships a portable measurement shim. |
| `DiagramKitTestSupport` | full | No CG/CT/UI dependencies. |
| `DiagramKit` (umbrella) | partial | `parse(_:)` and `layout(_:config:)` portable. `renderImage`, `renderSVG`, `renderASCII`, and `render(in: CGContext)` are Apple-only. |
| `DiagramKitRenderingCG` | none | Apple-only via `condition: .when(platforms: [Apple])` + `#if canImport(CoreGraphics)`. |
| `DiagramKitViews` | none | Apple-only. |

Verify Linux build: `./Scripts/linux-check.sh` (requires Docker or Podman; builds the Linux-portable matrix in `swift:6.3.1-noble`).

## Quality and verification

```bash
swift build                           # ~50s clean, ~4s incremental
swift test                            # full suite (188 test files; see BASELINES.md for caveats)
swift test --filter <NameOrPattern>   # narrow run, e.g. SequenceSvgTests, CorpusSnapshotTests/svgSnapshot
./Scripts/bootstrap-smoke-check.sh    # local "is this branch healthy?" gate
```

The four governance scripts under `Scripts/` are described in [CONTRIBUTING.md](CONTRIBUTING.md) and the "Discipline gates" section of [CLAUDE.md](CLAUDE.md).

## Snapshot tests

Snapshot baselines live under `Tests/DiagramKitTests/__Snapshots__/`. The corpus harness covers all 422 sample diagrams across SVG and image paths, 174 Mermaid-only ASCII baselines, and 13 additional non-Mermaid multi-format baselines via `CorpusMultiFormatSnapshotTests`.

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests   # record/refresh Mermaid-only
swift test --filter CorpusSnapshotTests                                # verify Mermaid-only
swift test --filter CorpusMultiFormatSnapshotTests                     # verify multi-format
SNAPSHOT_DIAGRAM_IDS=id1,id2,... SNAPSHOT_TESTING_RECORD=true \
  swift test --filter CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot
```

> **Known caveat:** the full `CorpusSnapshotTests` parameterized suite can encounter signal-10 on `main` — a `swift-testing` × `swift-snapshot-testing` interaction. Use chunked execution with `SNAPSHOT_DIAGRAM_IDS` when recording:
> ```bash
> SNAPSHOT_DIAGRAM_IDS=id1,id2,... SNAPSHOT_TESTING_RECORD=true \
>   swift test --filter CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot
> ```

## Examples

`Examples/DiagramPlayground/` is a SwiftUI sample app that exercises every diagram family and renderer:

```bash
swift run DiagramPlayground
```

> The playground's Xcode-project surface and the location of `Resources/test-diagrams.json` (currently inside the app, not in `DiagramKitTestSupport`) is a deliberate trade-off so the corpus stays editable from the SwiftUI app. See [ANALYSIS.md](ANALYSIS.md) for the original rationale.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — layered target map, three-stage pipeline, the worker-thread invariant, dual CG/SVG render-path drift hazard.
- [BASELINES.md](BASELINES.md) — clean-build time, test count, snapshot count, file-size landscape.
- [CONTRIBUTING.md](CONTRIBUTING.md) — file-size thresholds, the four governance scripts, PR workflow.
- [ATTRIBUTION.md](ATTRIBUTION.md) — upstream `mermaid-js` lineage, bundled fonts, library dependencies.
- [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) — bundled assets with copyright + license text references.
- [CLAUDE.md](CLAUDE.md) — invariants, conventions, layer-import rules, where new files belong.
- [PHASES.md](PHASES.md) — active multi-format roadmap from the current state.
- [ANALYSIS.md](ANALYSIS.md) — long-form format analysis and rationale.

## Migration from Mermaid-prefixed names

Phase 10 (completed 2026-05-13) standardized all public entry points on Diagram-prefixed names. Mermaid-prefixed compatibility aliases remain available with compiler fix-its through the next major version.

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
| `parseMermaid()` on String | `parseDiagram()` |
| `renderMermaidImage(...)` on String | `renderDiagramImage(...)` |
| `renderMermaidSVG(...)` (String / free function) | `renderDiagramSVG(...)` |
| `renderMermaidASCII(...)` on String | `renderDiagramASCII(...)` |
| `renderImageAsync(...)` on DiagramEngine | `renderImage(...)` |
| `renderSVGAsync(...)` on DiagramEngine | `renderSVG(...)` |

Internal and SPI aliases (Tier 2) were removed entirely in Phase 10. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the full deprecation policy.

## License

DiagramKit's own source is released under the same terms as the rest of the `mermaid-swift` repository (see the repository LICENSE if present). Bundled assets are licensed separately as documented in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md). Upstream `mermaid-js` is MIT — see [ATTRIBUTION.md](ATTRIBUTION.md) for the lineage and license citation.
