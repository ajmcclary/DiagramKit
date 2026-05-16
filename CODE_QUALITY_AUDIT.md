# Code Quality Audit

## Executive Summary

DiagramKit has a generally strong architectural foundation. The package is split into clear layered targets, the public `DiagramEngine` API centralizes worker-thread execution, and format import/export is organized around registries rather than hard-coded call sites. The most important abstractions already exist: `DiagramDescriptor`, `ImporterRegistry`, `ExporterRegistry`, `SVGDocumentBuilder`, `ShapeSpecRegistry`, render constants, and frontmatter binding runners.

The primary structural risk is that several of those abstractions are only partially adopted. Older ported modules still contain large, multi-responsibility implementations, especially flowchart/state layout, ASCII rendering, SVG rendering, and frontmatter compatibility. This creates avoidable cognitive load because maintainers must understand both the newer abstraction model and older family-specific paths that duplicate it.

The highest-value refactoring work is not a broad rewrite. It is targeted consolidation:

1. Split the large layout and ASCII drawing modules along existing responsibilities.
2. Make SVG and ASCII render registries match the typed descriptor pattern already used by parsing and layout.
3. Move portable shape geometry out of Apple-gated model code so SVG and CG renderers can share it.
4. Standardize frontmatter binding, SVG escaping, accessibility generation, and exporter diagnostics.

Overall structural health: **moderate to good**, with strong boundaries at the package level and meaningful technical debt concentrated in a small number of large modules and duplicated renderer paths.

## Scope and Method

This audit reviewed source structure, package boundaries, helper and utility modules, registry patterns, renderer implementations, parser/layout abstractions, frontmatter handling, and duplication hotspots under `Sources`. Tests and snapshots were considered as guardrails, but the focus was structural maintainability rather than behavioral correctness.

Quantitative observations:

- Source Swift files under `Sources`: 445.
- Source Swift lines of code: approximately 104,641.
- Swift test files under `Tests`: 299.
- Test Swift lines of code: approximately 51,854.
- Source files over 500 lines: 59.
- Source files over 1,000 lines: 11.
- Repeated normalized 8-line code clusters found in a sampling pass: 932, many benign, but several high-signal clusters are discussed below.

## Abstraction Analysis

### A1. ASCII rendering bypasses the newer parse/layout abstraction

**Evidence**

- `Sources/DiagramKit/DiagramPipeline.swift:282` defines `renderASCII(source:theme:sourceFormat:)`.
- `Sources/DiagramKit/DiagramPipeline.swift:288` creates `let registry = defaultRegistry` internally, while SVG rendering accepts an injectable registry at `Sources/DiagramKit/DiagramPipeline.swift:209`.
- `Sources/DiagramKit/DiagramPipeline.swift:305` converts non-Mermaid documents back to Mermaid source with `DiagramExportLoader.export`.
- `Sources/DiagramKit/DiagramPipeline.swift:319` passes source to `original_src_ascii_index().renderMermaidToAscii`.
- `Sources/DiagramKit/src_ascii_index.swift:386` dispatches ASCII rendering by source syntax and only uses `AsciiRenderRegistry` after re-detecting Mermaid diagram type.
- `Sources/DiagramKit/AsciiRenderRegistry.swift:7` explicitly states that ASCII renderers still consume preprocessed Mermaid source.

**Impact**

ASCII rendering has a different abstraction model from parsing, layout, and SVG rendering. It re-parses source after import/export normalization, which increases drift risk and makes non-Mermaid formats depend on Mermaid exporter fidelity. It also prevents callers and tests from injecting a custom importer registry, unlike the SVG path.

**Recommendation**

Introduce a document-aware ASCII render path that mirrors SVG rendering. Keep the source-based registry as a compatibility layer while gradually moving families to typed payload or positioned graph renderers.

Illustrative shape:

```swift
public struct AsciiRenderContext: Sendable {
  public var theme: DiagramTheme
  public var config: RenderConfig
}

public struct TypedAsciiRenderDescriptor<Payload>: Sendable {
  public let diagramType: DiagramType
  public let render: @Sendable (Payload, AsciiRenderContext) throws -> AsciiRenderOutput
}

extension DiagramPipeline {
  public static func renderASCII(
    source: String,
    theme: DiagramTheme = .default,
    sourceFormat: DiagramFormatID? = nil,
    registry: ImporterRegistry = defaultRegistry
  ) throws -> AsciiRenderOutput {
    try runPipeline {
      let document = try DiagramLoader.parse(source, as: sourceFormat, registry: registry)
      return try AsciiDocumentRenderRegistry.defaultRegistry.render(document, theme: theme)
    }
  }
}
```

This would align ASCII with the existing SVG path at `Sources/DiagramKit/DiagramPipeline.swift:205` and reduce the need for Mermaid round-trips.

### A2. Flowchart/state layout is an overburdened module

**Evidence**

- `Sources/DiagramKitModel/src_layout.swift` is 1,519 lines.
- `Sources/DiagramKitModel/src_layout.swift:40` starts `_buildElkGraph`, which builds the ELK graph, assigns ports, splits edges, and handles nested subgraphs.
- `Sources/DiagramKitModel/src_layout.swift:357` starts `_collectEdgeSegments`, a separate edge extraction concern.
- `Sources/DiagramKitModel/src_layout.swift:461` starts `_orthogonalizeEdgePoints`, a path normalization concern.
- `Sources/DiagramKitModel/src_layout.swift:511` starts `_alignLayerNodes`, a layout post-processing concern.
- `Sources/DiagramKitModel/src_layout.swift:627` starts `_bundleEdgePaths`, another edge post-processing concern.
- `Sources/DiagramKitModel/src_layout.swift:943` starts `_extractPositionedGraph`, which converts ELK output into public positioned graph data.
- `Sources/DiagramKitModel/src_layout.swift:1211` starts `_layoutGraphSyncWithConfig`, while `Sources/DiagramKitModel/src_layout.swift:1441` starts `_layoutGraphSyncFromLayoutEngine`; both orchestrate layout with overlapping fallback behavior.

**Impact**

This file is effectively a layout subsystem in one file. Local changes to edge construction, ELK conversion, fallback behavior, or positioned graph extraction require understanding unrelated responsibilities. The file size allowlist confirms the size is known, but the current structure still slows maintenance and increases regression risk.

**Recommendation**

Extract along existing internal seams without changing behavior:

- `ElkGraphFactory`: `_buildElkGraph`, `_makeEdge`, subgraph node construction.
- `ElkLayoutRunner`: ELK invocation, fallback layout, worker-safe execution boundaries.
- `PositionedGraphExtractor`: `_extractPositionedGraph` and node/edge conversion helpers.
- `FlowEdgePostProcessor`: `_collectEdgeSegments`, `_orthogonalizeEdgePoints`, `_bundleEdgePaths`.

Illustrative extraction:

```swift
struct ElkGraphFactory {
  func makeGraph(
    from graph: GraphModel,
    direction: LayoutDirection,
    diagnostics: _LayoutDiagnostics?
  ) -> ElkGraph {
    // Existing _buildElkGraph body, minus layout execution.
  }

  private func makeEdge(
    index: Int,
    edge: MermaidEdge,
    sourceID: String,
    targetID: String
  ) -> ElkGraphEdge {
    // Shared edge construction currently repeated in src_layout.swift.
  }
}
```

The first extraction should be mechanical and should preserve snapshot output exactly.

### A3. Portable shape geometry exists but is gated away from portable SVG usage

**Status:** Open. The Apple gate on `ShapeSpec` / `SVGPathSerializer` /
`RenderConfig` is over-conservative — the comments cite `BMColor` / `BMFont`
but the geometry surfaces don't actually depend on those types. The real
blocker is that `ShapeSpec` uses `CGFloat` / `CGRect` / `CGSize` /
`CGPoint` extensively, and this codebase treats CoreGraphics as Apple-only
(`DiagramGeometry.swift` gates `CGPoint` / `CGRect` bridging behind
`#if canImport(CoreGraphics)`). Ungating ShapeSpec for Linux would require
porting its public surface to `Double` / `DiagramPoint` / `DiagramRect`
across ~70 specs, the `SVGPathSerializer`, every decoration callback, and
every callsite — a multi-day refactor in its own right.

D2 was tackled in the same commit because most of A3's downstream payoff
(SVG-vs-CG unification) doesn't actually need Linux portability; it just
needs both renderers to route through `ShapeSpecRegistry` on Apple, which
is now true.

**Evidence**

- `Sources/DiagramKitModel/ShapeSpec.swift:1` is gated by `#if canImport(UIKit) || canImport(AppKit)`. **(open — Linux port deferred)**
- `Sources/DiagramKitModel/ShapeSpec.swift:10` describes `ShapeSpec` as the single source of truth for layout, CoreGraphics, and SVG rendering.
- `Sources/DiagramKitModel/SVGPathSerializer.swift:1` is also platform-gated, even though SVG path serialization is not inherently Apple-only. **(open — Linux port deferred)**
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:18` uses `ShapeSpecRegistry` for CG shape drawing.
- `Sources/DiagramKitModel/src_block_renderer.swift:186` manually switches over block node shapes for SVG. **(resolved — now routes through `ShapeSpecRegistry` + `SVGPathSerializer`)**
- `Sources/DiagramKitModel/src_block_renderer.swift:404` maps block node shapes to names separately from the CG path. **(resolved — `BlockShapeMapper` is the shared mapper)**
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:150` contains a separate `_cgBlockShapeName` mapping. **(resolved — delegates to `BlockShapeMapper`)**

**Impact**

The intended shape abstraction cannot serve Linux-portable SVG renderers because it is behind Apple platform gates. As a result, block SVG and CG renderers duplicate shape naming and geometry. This directly undermines the stated role of `ShapeSpec` and increases renderer drift.

**Recommendation**

Move platform-neutral shape definitions and SVG path serialization to a Linux-portable target, preferably `DiagramKitCommon` or an ungated part of `DiagramKitModel`. Keep only native `CGPath`, `UIColor`, and `NSColor` adapters behind Apple gates.

Illustrative split:

```swift
public struct PortableShapeSpec: Sendable {
  public var semanticName: String
  public var path: @Sendable (CGRect) -> ShapePath
  public var textInsets: EdgeInsets
}

public enum PortableShapeRegistry {
  public static func spec(named name: String) -> PortableShapeSpec {
    // Existing defaults from ShapeSpecRegistry+Defaults.swift.
  }
}

public enum SVGPathSerializer {
  public static func pathData(for path: ShapePath) -> String {
    // Existing portable serializer without UIKit/AppKit gating.
  }
}
```

Then both `DiagramRenderer+Block.swift` and `src_block_renderer.swift` can use the same shape registry.

### A4. `DiagramFrontmatter` is a compatibility god object

**Evidence**

- `Sources/DiagramKitModel/DiagramFrontmatter.swift:23` defines `DiagramFrontmatter`.
- `Sources/DiagramKitModel/DiagramFrontmatter.swift:28` starts an initializer with dozens of optional per-family config and theme parameters.
- `Sources/DiagramKitModel/DiagramFrontmatter.swift:167` defines `PerDiagramFrontmatter.Storage` with one stored property per family config/theme pair.
- `Sources/DiagramKitModel/DiagramFrontmatter.swift:276` starts proxy accessors for every family.
- `Sources/DiagramKitModel/DiagramFrontmatter.swift:451` starts flat-field compatibility shims that mirror many of the storage fields.

**Impact**

Every new diagram family or frontmatter shape requires edits across initializer parameters, storage, accessors, and compatibility shims. This concentrates unrelated ownership in a single file and makes additions noisy. The broad `@unchecked Sendable` storage also becomes harder to audit as fields are added.

**Recommendation**

Keep public compatibility shims, but move the canonical model toward typed sections and generated or table-driven accessors. At minimum, split family sections into smaller files and make the large initializer delegate to a typed storage builder.

Illustrative direction:

```swift
public struct DiagramFamilyFrontmatter<Config: Sendable, Theme: Sendable>: Sendable {
  public var config: Config?
  public var theme: Theme?
}

public struct PerDiagramFrontmatter: Sendable {
  public var block = DiagramFamilyFrontmatter<BlockDiagramConfig, ThemeVariables>()
  public var sequence = DiagramFamilyFrontmatter<SequenceDiagramConfig, ThemeVariables>()
  public var flowchart = DiagramFamilyFrontmatter<FlowchartDiagramConfig, FlowchartThemeVariables>()
}
```

Flat properties such as `blockConfig` can remain deprecated forwarding accessors while new code uses structured sections.

### A5. Frontmatter binding helpers are under-utilized

**Status:** Resolved. `ConfigThemeBinding.apply` now accepts an optional
`themeFallbackPrefixes` array so a binding can route theme keys through a
family-specific prefix first (e.g. `themeVariables.radar.`) and fall back
to a flat prefix (`themeVariables.`). Radar, EventModeling, and Pie now
delegate through the shared runner — they no longer reimplement the
`hasConfig`/`hasTheme` state machine. Gantt delegates through
`SingleSectionBinding` and keeps only its top-level `displayMode` quirk
as a small special-case branch inside its `apply` method (the
"only `compact` actually changes the rendered output" rule is too narrow
to belong in the generic runner).

**Evidence**

- `Sources/DiagramKitModel/FrontmatterBinding.swift:41` defines the common `FrontmatterBinding` protocol.
- `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift:21` defines `SingleSectionBinding`.
- `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift:55` defines `ConfigThemeBinding` (now also `themeFallbackPrefixes`).
- `Sources/DiagramKitModel/FrontmatterBinding+Packet.swift:13` uses `ConfigThemeBinding`.
- `Sources/DiagramKitModel/FrontmatterBinding+Radar.swift:3` manually implements a config/theme binding. **(resolved — delegates to `ConfigThemeBinding` with fallback prefixes)**
- `Sources/DiagramKitModel/FrontmatterBinding+EventModeling.swift:3` manually implements a config/theme binding. **(resolved — delegates to `ConfigThemeBinding`)**
- `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:5` manually implements a config/theme binding with fallback prefixes. **(resolved — delegates to `ConfigThemeBinding` with fallback prefixes)**
- `Sources/DiagramKitModel/FrontmatterBinding+Gantt.swift:4` manually implements a single config binding because it has top-level aliases. **(resolved — delegates to `SingleSectionBinding` with the `displayMode` alias handled before delegation)**

**Impact**

The project has a good abstraction for frontmatter binding, but family files use it inconsistently. Manual implementations make it harder to tell which behavior is intentional and which is historical. Fallback prefixes and top-level aliases are the main reasons helper adoption is incomplete.

**Recommendation**

Extend the binding runners to support fallback prefixes and top-level aliases, then migrate manual family bindings to the shared helpers.

Illustrative helper:

```swift
struct ConfigThemeBinding<Config: Decodable & Sendable, Theme: Decodable & Sendable> {
  var configPrefixes: [String]
  var themePrefixes: [String]
  var topLevelConfigAliases: [String: WritableKeyPath<Config, String?>] = [:]
}
```

This keeps special cases explicit while avoiding full manual binders per family.

### A6. `original_src_ascii_draw` is a large procedural drawing object

**Evidence**

- `Sources/DiagramKitModel/src_ascii_draw.swift` is 1,108 lines.
- `Sources/DiagramKitModel/src_ascii_draw.swift:37` starts `drawNode`.
- `Sources/DiagramKitModel/src_ascii_draw.swift:177` starts `drawLine`.
- `Sources/DiagramKitModel/src_ascii_draw.swift:523` starts `drawArrow`.
- `Sources/DiagramKitModel/src_ascii_draw.swift:608`, `Sources/DiagramKitModel/src_ascii_draw.swift:688`, `Sources/DiagramKitModel/src_ascii_draw.swift:747`, and `Sources/DiagramKitModel/src_ascii_draw.swift:780` handle bundled edge variants.
- `Sources/DiagramKitModel/src_ascii_draw.swift:871` starts `drawSubgraphBox`.
- `Sources/DiagramKitModel/src_ascii_draw.swift:928`, `Sources/DiagramKitModel/src_ascii_draw.swift:948`, and `Sources/DiagramKitModel/src_ascii_draw.swift:967` fill role overlays.
- `Sources/DiagramKitModel/src_ascii_draw.swift:1001` starts `drawGraph`.

**Impact**

The class combines node drawing, edge routing, arrowheads, bundles, subgraphs, role overlays, and whole-graph orchestration. This makes simple ASCII improvements expensive because unrelated drawing rules live in the same procedural object.

**Recommendation**

Split by drawing responsibility while sharing the same canvas type:

```swift
struct AsciiNodeDrawer {
  func drawNode(_ node: PositionedNode, into canvas: inout AsciiCanvas)
}

struct AsciiEdgeDrawer {
  func drawEdge(_ edge: PositionedEdge, into canvas: inout AsciiCanvas)
}

struct AsciiGraphDrawer {
  var nodes: AsciiNodeDrawer
  var edges: AsciiEdgeDrawer
  var subgraphs: AsciiSubgraphDrawer
}
```

The split should be internal first. Public API behavior should remain snapshot-driven.

### A7. SVG render registration does not reuse the typed descriptor pattern

**Status:** Resolved. `SVGRenderDescriptor.typed<Payload>` is now the
canonical factory and consumes a typed payload accessor on
`PositionedGraph`. The 26 entries that used to repeat the
`guard case let .X(...) else { throw payloadMismatch(.X) }` block
(everything except `flowchart` / `stateDiagram`, which pass the whole
`PositionedGraph` through `renderSvg`) now resolve to one-line entries.
Sequence/Class/ER additionally use struct-reconstructing accessors so the
factory shape stays uniform.

**Evidence**

- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:13` defines a `_typed` descriptor factory that removes parse/layout boilerplate.
- `Sources/DiagramKit/SVGRenderRegistry.swift:33` manually builds a dictionary of render closures for each diagram type. **(resolved — entries now go through `.typed(type, accessor) { … }`)**
- `Sources/DiagramKit/SVGRenderRegistry.swift:44`, `Sources/DiagramKit/SVGRenderRegistry.swift:61`, `Sources/DiagramKit/SVGRenderRegistry.swift:78`, and many following closures all repeat the same pattern. **(resolved — boilerplate eliminated)**

**Impact**

Adding or modifying a diagram family requires editing one large registry with repetitive type checks. The implementation pattern is conceptually the same as `DiagramRegistry._typed`, but SVG does not get the same reduction in boilerplate.

**Recommendation**

Add a typed SVG render descriptor factory:

```swift
extension SVGRenderDescriptor {
  static func typed<Content>(
    _ type: DiagramType,
    render: @escaping @Sendable (PositionedDiagram<Content>, RenderConfig) throws -> String
  ) -> SVGRenderDescriptor {
    SVGRenderDescriptor(type) { positioned, config in
      guard case let .typed(content as Content) = positioned.graph.content else {
        throw DiagramError.renderingFailed("Expected \(Content.self) for \(type)")
      }
      return try render(positioned.mapContent { content }, config)
    }
  }
}
```

The exact shape should follow existing `PositionedGraph` APIs, but the goal is to move the repetitive payload verification out of the central registry.

## Pattern Consistency Review

### P1. SVG and ASCII public pipeline signatures are inconsistent

**Status:** Partially resolved. Source-based `renderASCII` now accepts
`registry: ImporterRegistry = defaultRegistry` on both `DiagramPipeline` and
`DiagramEngine`, matching `renderSVG`. The positioned-graph asymmetry remains
open and is tracked alongside audit A1 (structured document-aware ASCII path).

**Evidence**

- `Sources/DiagramKit/DiagramPipeline.swift:205` exposes `renderSVG(..., registry: ImporterRegistry = defaultRegistry)`.
- `Sources/DiagramKit/DiagramPipeline.swift:282` exposes `renderASCII(..., sourceFormat: DiagramFormatID? = nil)` without a registry parameter. **(resolved — registry now injected)**
- `Sources/DiagramKit/DiagramPipeline.swift:244` exposes `renderSVG(positioned:config:)`, but there is no equivalent positioned ASCII renderer. **(open — requires A1 structured path)**

**Impact**

Developers must remember that registry injection and positioned rendering work for SVG but not ASCII. This increases API surprise and makes non-Mermaid ASCII rendering depend on source conversion rather than the structured model.

**Recommendation**

Make ASCII API capabilities converge with SVG. Start by adding `registry:` to source-based ASCII rendering, then add a structured render path once `AsciiDocumentRenderRegistry` exists.

```swift
public static func renderASCII(
  source: String,
  theme: DiagramTheme = .default,
  sourceFormat: DiagramFormatID? = nil,
  registry: ImporterRegistry = defaultRegistry
) throws -> AsciiRenderOutput
```

### P2. Some source comments describe old phase limitations rather than current behavior

**Status:** PlantUML headers refreshed. PlantUMLImporter and PlantUMLExporter
now describe current capability (Sequence/Class/State/Mindmap/Gantt/C4) and
the dispatch order is documented without phase-tag references. The
`MermaidExporter.swift:8` line referenced in the original audit was already
accurate (REVIEW.md cross-references, not roadmap archive references) so
no change there. The stale Mermaid `7A-P1/7A-P2/Phase 10` diagnostic text
was already removed under D4.

**Evidence**

- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift:43` says C4, Gantt, Mindmap, State, Activity, and ER coverage is deferred. **(resolved)**
- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift:53` now dispatches C4.
- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift:59` now dispatches Gantt.
- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift:63` now dispatches Mindmap.
- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift:67` now dispatches State/Activity.
- `Sources/DiagramKitPlantUML/PlantUMLExporter.swift:9` says the exporter supports Sequence and Class diagrams only. **(resolved)**
- `Sources/DiagramKitPlantUML/PlantUMLExporter.swift:16` includes State, Mindmap, Gantt, and C4 diagram types.
- `Sources/DiagramKitExport/MermaidExporter.swift:8` still describes a Phase 10 sub-slice even though the roadmap is archived as complete. **(not stale — comment references REVIEW.md, not archived roadmap)**

**Impact**

Stale comments create false constraints. A maintainer may avoid using or extending existing PlantUML coverage because the file header claims it is not implemented.

**Recommendation**

Replace phase-history comments with durable capability comments. Keep historical phase information in archived docs, not in active source headers.

Example:

```swift
/// Imports supported PlantUML families into DiagramDocument.
///
/// Detection is intentionally ordered from narrow families to broad families
/// so C4 and Gantt markers are considered before generic sequence syntax.
```

### P3. SVG builder usage is inconsistent across renderers

**Status:** Resolved. All five hand-written `<title>` / `<desc>` sites now go
through `SVGDocumentBuilder.accessibility()`. Gantt and block additionally
forward `accTitle` / `accDescr` into the builder constructor; class lost the
ad-hoc 2-space indent on the accessibility lines (3 corpus snapshots
rebaselined accordingly).

**Evidence**

- `Sources/DiagramKitModel/SVGUtilities.swift:8` says `SVGDocumentBuilder` replaces hand-written wrappers and accessibility markup.
- `Sources/DiagramKitModel/SVGUtilities.swift:130` provides `accessibility()`.
- `Sources/DiagramKitModel/src_sequence_renderer.swift:43` appends `svgBuilder.accessibility()`.
- `Sources/DiagramKitModel/src_gantt_renderer.swift:89` manually writes `<title>` and `<desc>`. **(resolved)**
- `Sources/DiagramKitModel/src_er_renderer.swift:44` manually writes `<title>` and `<desc>`. **(resolved)**
- `Sources/DiagramKitModel/src_class_renderer.swift:45` manually writes `<title>` and `<desc>`. **(resolved)**
- `Sources/DiagramKitModel/src_block_renderer.swift:37` manually writes `<title>` and `<desc>`. **(resolved)**
- `Sources/DiagramKitModel/src_renderer.swift:84` manually writes `<title>` and `<desc>`. **(resolved)**

**Impact**

Renderer files mix two conventions for the same SVG document boilerplate. That makes accessibility behavior harder to change globally and increases the chance of inconsistent escaping or markup ordering.

**Recommendation**

Standardize every SVG renderer on the builder:

```swift
let builder = SVGDocumentBuilder(...)
var parts: [String] = []
parts.append(builder.open())
parts.append(builder.accessibility())
parts.append(builder.style())
```

If a renderer needs custom title or description text, pass it through `SVGDocumentBuilder` rather than writing raw tags locally.

### P4. XML and SVG escaping helpers are duplicated around the codebase

**Status:** SVG-renderer half resolved. Every per-family pass-through wrapper
in `Sources/DiagramKitModel/` (16 wrappers across 16 files) now resolves to
`SVG.escapeText` / `SVG.escapeAttribute` directly: `_escapeXml`,
`_escapePieXml`, `_escapeQuadrantXml`, `_escapeRadarXml`, `_sankeyEscapeXml`,
`_tescapeXml`, `_gitGraphEscapeXml`, `escapeXml`, and `_escapeAttr` are all
deleted. The remaining open items are the cross-format exporters' local
`escapeString` helpers (D2, Structurizr, DOT, PlantUML, Mermaid) and the
`String.escapedXML` extension defined in `src_block_renderer.swift` and
shared with the packet renderer.

**Evidence**

- `Sources/DiagramKitCommon/SVG.swift:17` defines `SVG.escapeText`.
- `Sources/DiagramKitCommon/SVG.swift:28` defines `SVG.escapeAttribute`.
- `Sources/DiagramKitCommon/src_multiline_utils.swift:45` keeps deprecated `escapeXml`.
- `Sources/DiagramKitModel/src_sequence_renderer.swift:534` defines `escapeXML`. **(resolved)**
- `Sources/DiagramKitModel/src_gantt_renderer.swift:201` defines `ganttEscapeXML`. **(resolved)**
- `Sources/DiagramKitModel/src_architecture_renderer.swift:318` defines `architectureEscapeXML`. **(resolved)**
- `Sources/DiagramKitModel/src_renderer.swift:1010` defines `_flowchartEscapeXML`. **(resolved as `_escapeAttr`)**
- `Sources/DiagramKitModel/src_class_renderer.swift:500` defines `classEscapeXML`. **(resolved as `_escapeAttr`)**
- `Sources/DiagramKitModel/src_er_renderer.swift:534` defines `erEscapeXML`. **(resolved as `_escapeAttr`)**
- `Sources/DiagramKitD2/D2Exporter.swift:68` defines a local `escapeString`. **(open — exporter scope)**
- `Sources/DiagramKitStructurizr/StructurizrExporter.swift:200` defines a local `escapeString`. **(open — exporter scope)**

**Impact**

Most of these wrappers are simple pass-throughs, but their presence makes escaping policy look family-specific. The local exporter helpers also make it harder to audit whether text and attribute contexts are handled correctly.

**Recommendation**

Use `SVG.escapeText` and `SVG.escapeAttribute` directly in SVG renderers. For non-SVG exporters, introduce format-specific shared helpers only when the escaping rules differ.

```swift
let title = SVG.escapeText(diagramTitle)
let id = SVG.escapeAttribute(nodeID)
```

Deprecation shims can remain for compatibility, but new renderer code should use the common namespace directly.

### P5. Dual renderer drift is acknowledged but not structurally reduced

**Evidence**

- `AGENTS.md` documents that CG/image renderers live in `DiagramKitRenderingCG` while SVG renderers live in `DiagramKitModel`, and that they drift.
- `Sources/DiagramKitCommon/BlockRenderConstants.swift:3` provides shared block constants.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:31` implements CG block node drawing.
- `Sources/DiagramKitModel/src_block_renderer.swift:186` implements separate SVG block node drawing.
- `Sources/DiagramKitCommon/SequenceRenderConstants.swift:3` provides shared sequence constants.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Sequence.swift:273` implements CG sequence arrowheads.
- `Sources/DiagramKitModel/src_sequence_renderer.swift:122` implements separate SVG marker definitions.
- `Sources/DiagramKitModel/src_sequence_types.swift:394` centralizes sequence arrow style classification, which is a good partial abstraction.

**Impact**

Shared constants reduce some drift, but shape geometry, marker behavior, arrowheads, and name mappings still live in renderer-specific code. Snapshot tests catch differences after the fact, but they do not reduce the effort required to make synchronized changes.

**Recommendation**

Extract renderer-neutral geometry and semantic classification first, leaving paint operations renderer-specific:

```swift
struct ArrowheadGeometry: Sendable {
  var points: [CGPoint]
  var fill: Bool
  var stroke: Bool
}

protocol DiagramArrowheadRenderer {
  associatedtype Output
  func render(_ geometry: ArrowheadGeometry, style: StrokeStyle) -> Output
}
```

Start with block shapes and sequence arrowheads because both already have shared constants and visible duplicated mappings.

### P6. Apple platform import boilerplate is repeated in CG renderer extensions

**Status:** Resolved as far as the boilerplate variants are concerned. All 17
renderer files that needed a UIKit/AppKit gate now use the canonical form

```swift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```

The redundant `targetEnvironment(macCatalyst)` branches (macCatalyst always
satisfies `canImport(UIKit)`) and the Flow-only AppKit-first ordering are
gone. A shared typealias shim was not introduced because Swift file-level
imports still require each renderer to opt in to the framework it uses,
so a shim would not reduce the per-file import line by itself.

**Evidence**

- `Sources/DiagramKitRenderingCG/DiagramRenderer+Kanban.swift:1` contains repeated `#if canImport(UIKit)` / `#elseif canImport(AppKit)` import boilerplate. **(resolved — canonical form)**
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Radar.swift:1` contains the same boilerplate. **(resolved)**
- A duplicate-cluster pass found the same platform import block repeated across more than 20 `DiagramRenderer+*.swift` files. **(resolved — 17 files normalized in one pass)**

**Impact**

The cost is low, but the repeated boilerplate adds visual noise and makes renderer files look more platform-dependent than they often are.

**Recommendation**

Centralize platform type aliases and common imports in one RenderingCG shim file when possible. Individual renderer extensions should import only what they directly need.

```swift
#if canImport(UIKit)
import UIKit
public typealias DiagramNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias DiagramNativeColor = NSColor
#endif
```

## Duplication and Reuse Audit

### D1. ELK edge and subgraph construction are repeated inside `src_layout.swift`

**Status:** Partially resolved. The edge, label, and deepest-subgraph helpers
were extracted to file-private top-level functions (`_makeElkEdge`,
`_makeEdgeLabels`, `_deepestSubgraphID`) and the three graph builders
(`_buildElkGraph`, `_buildElkGraphNoCrossEdges`, `_buildFlatElkGraph`) now share
them. `buildSubgraphNode` remains duplicated because the port-aware and
no-cross-edges variants have structurally different bodies (port allocation
versus none); deferring that split until the larger A2 file split lands.
`src_layout.swift` dropped from 1,519 to 1,441 lines as a result.

**Evidence**

- `Sources/DiagramKitModel/src_layout.swift:43` defines an inner `_makeEdge`. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:1301` repeats an inner `_makeEdge` with the same core purpose. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:143` builds edge labels. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:181` builds another edge label path. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:1409` repeats label construction. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:95` defines `_deepestSubgraph`. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:1293` repeats deepest-subgraph logic. **(resolved)**
- `Sources/DiagramKitModel/src_layout.swift:206` builds subgraph nodes. **(open — port-aware variant)**
- `Sources/DiagramKitModel/src_layout.swift:1348` repeats subgraph-node construction. **(open — no-cross-edges variant)**

**Impact**

The same graph-construction rules exist in multiple places. Any correction to edge IDs, labels, subgraph containment, or port handling can be applied incompletely.

**Recommendation**

Extract reusable functions before splitting the file. This is a lower-risk first step than moving entire subsystems:

```swift
private struct ElkEdgeBuilder {
  func makeEdge(
    id: String,
    model: MermaidEdge,
    sourceID: String,
    targetID: String,
    label: String?
  ) -> ElkGraphEdge {
    ElkGraphEdge(
      id: id,
      sources: [sourceID],
      targets: [targetID],
      labels: label.map { [ElkLabel(text: $0)] } ?? []
    )
  }
}
```

After this consolidation, snapshot tests can verify that the extraction was behavior-preserving.

### D2. Block shape rendering is duplicated between SVG and CG

**Status:** Resolved. Both renderers now agree on shape selection via the
shared `BlockShapeMapper.shapeSpecName(for:)` and consume the same
`ShapeSpecRegistry` entries for geometry. Snapshot impact: 12 block SVG
corpus snapshots rebaselined to the unified output (which differs from the
old SVG markup for cylinder cap geometry, `rect_left_inv_arrow` shape, and
`.round` corner radius — these now match CG instead of having SVG-only
behavior). CG output is unchanged because `_cgBlockShapeName` already
returned the canonical aliases. The block-arrow geometry (`renderBlockArrowSvg`)
is still custom because the arrow shape has no `ShapeSpec` analog yet; it
stays as the residual D2 follow-up.

**Evidence**

- `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:31` draws block nodes in CG.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:150` maps block node shapes for CG. **(resolved — delegates to `BlockShapeMapper`)**
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:185` maps block arrow heads for CG.
- `Sources/DiagramKitModel/src_block_renderer.swift:186` draws block nodes in SVG. **(resolved — routes through `ShapeSpecRegistry` + `SVGPathSerializer`)**
- `Sources/DiagramKitModel/src_block_renderer.swift:318` calculates block arrow geometry for SVG. **(open — block-arrow has no `ShapeSpec` analog)**
- `Sources/DiagramKitModel/src_block_renderer.swift:404` maps block node shapes for SVG. **(resolved — `BlockShapeMapper` is the single source)**
- `Sources/DiagramKitCommon/BlockRenderConstants.swift:3` already provides shared constants, but not shared geometry. **(resolved — geometry now also shared via `ShapeSpec`)**

**Impact**

The renderers are forced to evolve in parallel. Shape support, arrowhead changes, and geometry fixes must be made twice.

**Recommendation**

Move shape and arrowhead semantics into portable shared helpers:

```swift
enum BlockShapeMapper {
  static func shapeName(for node: BlockNode) -> String {
    // Single mapping used by SVG and CG renderers.
  }
}

enum BlockArrowGeometry {
  static func arrowHead(for edge: PositionedBlockEdge) -> ArrowheadGeometry {
    // Renderer-neutral points and fill/stroke semantics.
  }
}
```

The CG renderer should convert shared geometry to `CGPath`; the SVG renderer should convert the same geometry to path data or marker elements.

### D3. ASCII shape files duplicate dimension scaffolding

**Evidence**

- `Sources/DiagramKitModel/src_ascii_shapes_rectangle.swift:8` calculates box dimensions.
- `Sources/DiagramKitModel/src_ascii_shapes_special.swift:4` calculates base box dimensions.
- `Sources/DiagramKitModel/src_ascii_shapes_index.swift:4` calculates basic box dimensions.
- `Sources/DiagramKitModel/src_ascii_shapes_stadium.swift:11` calculates stadium dimensions with very similar width and height constraints.

**Impact**

Shape-specific rendering should differ in border glyphs and contours, not in repeated minimum-size and label-centering rules. The current repetition makes text fitting behavior harder to keep consistent across shapes.

**Recommendation**

Introduce a shared dimension helper:

```swift
struct AsciiShapeMetrics: Sendable {
  var width: Int
  var height: Int
  var labelRow: Int
  var labelColumn: Int
}

func makeBoxMetrics(
  label: String,
  horizontalPadding: Int = 2,
  verticalPadding: Int = 1,
  minWidth: Int = 5,
  minHeight: Int = 3
) -> AsciiShapeMetrics {
  let width = max(minWidth, label.count + horizontalPadding * 2)
  let height = max(minHeight, 1 + verticalPadding * 2)
  return AsciiShapeMetrics(width: width, height: height, labelRow: height / 2, labelColumn: horizontalPadding)
}
```

Shape renderers can then focus on the border algorithm.

### D4. Unsupported exporter diagnostics are repeated

**Status:** Resolved. `DiagramExportResult.unsupportedDiagram(formatName:type:)`
is the single source of wording: `"<formatName> export for '<type>' is not
supported"`. All five exporters (D2, DOT/Graphviz, Structurizr, PlantUML,
Mermaid) now delegate to it. PlantUML and Mermaid lost their "is not yet
implemented" and "(7A-P1/7A-P2/Phase 10)" wording in the process. The
loader's distinct "No exporter registered for format" path stays untouched
because it is conceptually different.

**Evidence**

- `Sources/DiagramKitExport/DiagramExportLoader.swift:24` emits a diagnostic for unsupported export formats. **(distinct concern — left as-is)**
- `Sources/DiagramKitD2/D2Exporter.swift:22` emits an unsupported diagram diagnostic. **(resolved)**
- `Sources/DiagramKitGraphviz/DOTExporter.swift:19` emits an unsupported diagram diagnostic. **(resolved — was `DiagramKitDOT` in original audit; actual target is `DiagramKitGraphviz`)**
- `Sources/DiagramKitStructurizr/StructurizrExporter.swift:17` emits an unsupported diagram diagnostic. **(resolved)**
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift:28` emits an unsupported diagram diagnostic. **(resolved)**
- `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift:30` emits an unsupported diagram diagnostic. **(resolved — was `DiagramKitExport` in original audit; actual target is `DiagramKitMermaid`)**

**Impact**

Diagnostic wording and severity can drift by exporter. New exporters are likely to copy one of the existing blocks, spreading the pattern further.

**Recommendation**

Add a shared constructor in `DiagramKitExport`:

```swift
extension DiagramExportResult {
  static func unsupported(
    format: DiagramFormatID,
    document: DiagramDocument,
    reason: String? = nil
  ) -> DiagramExportResult {
    .failure(
      DiagramDiagnostic(
        severity: .error,
        message: reason ?? "\(format.rawValue) export does not support \(document.type)",
        range: nil
      )
    )
  }
}
```

Exporters can then return the same structured diagnostic without repeating message construction.

### D5. String escaping and quoting helpers are repeated across exporters

**Evidence**

- `Sources/DiagramKitD2/D2Exporter.swift:68` defines `escapeString`.
- `Sources/DiagramKitStructurizr/StructurizrExporter.swift:200` defines `escapeString`.
- `Sources/DiagramKitDOT/DOTFlowchartExport.swift:18` defines DOT-specific escaping.
- `Sources/DiagramKitPlantUML/PlantUMLSequenceExporter.swift:175` and nearby lines define PlantUML escaping helpers.
- `Sources/DiagramKitExport/MermaidExportHelpers.swift:11` defines Mermaid string escaping helpers.

**Impact**

Some repetition is appropriate because D2, DOT, Structurizr, PlantUML, and Mermaid have different escaping rules. The current structure, however, makes it difficult to tell which helpers differ by format and which are repeated accidentally.

**Recommendation**

Keep format-specific escaping, but place it behind clearly named reusable helpers in each exporter module. Avoid local nested escape functions in individual exporter files.

```swift
enum DOTEscaper {
  static func quoted(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
  }
}
```

This preserves format-specific behavior while making escaping policy auditable.

### D6. Public API worker wrappers repeat similar boilerplate

**Evidence**

- `Sources/DiagramKit/DiagramEngine.swift:52` wraps `parse`.
- `Sources/DiagramKit/DiagramEngine.swift:62` wraps `layout`.
- `Sources/DiagramKit/DiagramEngine.swift:75` wraps `renderSVG`.
- `Sources/DiagramKit/DiagramEngine.swift:151` wraps `renderASCII`.
- `Sources/DiagramKit/DiagramEngine.swift:217` implements `_runOnWorker`.
- `Sources/DiagramKit/DiagramPipeline.swift:27` separately centralizes font registration and error reporting in `runPipeline`.

**Impact**

The repeated wrapper pattern is acceptable because these are public API entry points with different signatures. The risk is that future methods could miss `DiagramFontRegistry.registerBundledFontsIfNeeded()` or worker execution requirements.

**Recommendation**

Do not over-abstract the public API signatures. Instead, add a small internal helper that makes the required pattern harder to bypass:

```swift
private static func runEngineOperation<T: Sendable>(
  _ operation: @escaping @Sendable () throws -> T
) async throws -> T {
  try await _runOnWorker {
    try DiagramPipeline.runPipeline(operation)
  }
}
```

Public methods stay readable, but the font and worker invariants are enforced in one place.

### D7. Acceptable repetition that should not be refactored aggressively

The following repetition appears intentional or low-value to abstract:

- Snapshot baselines under `Tests`, because duplication is the point of regression fixtures.
- Per-family descriptor registration files when they are short and declarative.
- Large data tables such as icon maps and corpus fixtures.
- Format-specific escaping where grammar rules genuinely differ.
- Platform gates where a file directly uses native Apple UI or image types.
- Parser code that intentionally mirrors upstream Mermaid behavior for easier port comparison.

Refactoring these areas would likely reduce readability or increase indirection without meaningful maintainability gains.

## Prioritized Refactoring Roadmap

### Priority 1: Split `src_layout.swift` along existing responsibilities

**Impact:** Very high maintainability and scalability gain.

**Status:** Step 1 (D1 helper extraction) landed. `_makeElkEdge`,
`_makeEdgeLabels`, and `_deepestSubgraphID` now back all three graph builders.
Remaining work: split ELK graph construction, layout execution, positioned
extraction, and edge post-processing into separate internal files, and unify
the two `buildSubgraphNode` variants. Run the full layout and snapshot suites
after each mechanical move.

### Priority 2: Create a structured ASCII rendering path

**Impact:** Very high developer productivity gain for new formats.

Add registry injection to `renderASCII`, then introduce document-aware ASCII rendering. Keep the source-based path as a compatibility fallback while migrating families one by one.

### Priority 3: Make shape geometry portable and shared by SVG and CG

**Impact:** High maintainability gain and reduced renderer drift.

**Status:** SVG-CG unification half landed. The block SVG renderer now
routes through `ShapeSpecRegistry` + `SVGPathSerializer`, and
`BlockShapeMapper` is the single source of truth for `BlockNodeType` →
shape-alias mapping. Linux portability for `ShapeSpec` (the audit's "A3"
half) stays open: it requires porting the public surface from `CGFloat` /
`CGRect` to `Double` / `DiagramRect` across the registry and every
decoration callback. Expanding the shared registry to additional
shape-heavy families is the next incremental step.

### Priority 4: Standardize SVG document construction and escaping

**Impact:** Medium-high consistency gain with low implementation risk.

**Status:** Both halves landed for the SVG renderers. Accessibility now
goes through `SVGDocumentBuilder.accessibility()` (P3), and every
per-family `_escapeXml` / `_escapeAttr` pass-through shim has been deleted
in favor of direct `SVG.escapeText` / `SVG.escapeAttribute` calls (P4).
Cross-format exporter helpers (D2/Structurizr/DOT/PlantUML/Mermaid
`escapeString`) and the `String.escapedXML` extension shared by the block
and packet renderers remain as follow-ups.

### Priority 5: Consolidate frontmatter binding patterns

**Impact:** Medium-high scalability gain for future families.

**Status:** Landed. `ConfigThemeBinding.apply` gained an optional
`themeFallbackPrefixes` parameter. Radar, EventModeling, Pie, and Gantt
binders now delegate to the shared runners. Adding a new
config-and-theme family is a single closure pair plus a prefix list.

### Priority 6: Reduce exporter diagnostic duplication

**Impact:** Medium productivity gain.

**Status:** Landed. `DiagramExportResult.unsupportedDiagram(formatName:type:)`
in `DiagramKitExport` is the single canonical constructor; D2, DOT,
Structurizr, PlantUML, and Mermaid exporters all use it. The loader's
"no exporter registered" path stays separate (different concern).

### Priority 7: Split `original_src_ascii_draw`

**Impact:** Medium maintainability gain.

Extract node, edge, bundle, subgraph, and role overlay drawers. This should follow the structured ASCII rendering work so the split supports the target architecture rather than preserving source-based assumptions.

### Priority 8: Refresh stale source comments

**Impact:** Medium cognitive-load reduction with very low risk.

**Status:** Resolved for the PlantUML importer + exporter headers (the only
genuinely stale comments the audit identified). Both files now describe
current capabilities without phase-tag references. The MermaidExporter
comment flagged in the original P2 evidence was not actually stale.

### Priority 9: Centralize CG platform boilerplate

**Impact:** Low but useful readability improvement.

**Status:** Landed in the form that actually shrinks the boilerplate:
the three variant `#if` blocks (macCatalyst-prefixed, combined-OR, and
AppKit-first) were collapsed to the canonical
`#if canImport(UIKit) ... #elseif canImport(AppKit)` shape across all 17
renderer files. A typealias shim would not reduce per-file framework
imports further; existing `BMColor` / `BMImage` in `DiagramKitCommon`
already serve that role.

## Closing Assessment

DiagramKit is not structurally weak; it is structurally uneven. The package-level layering and registry-based architecture are solid, and the most useful abstractions already exist. The maintainability opportunity is to finish the migration toward those abstractions, especially in layout, rendering, ASCII output, and frontmatter. A focused refactoring sequence can reduce the largest modules, remove duplicated renderer logic, and make future diagram-family work more predictable without destabilizing the public API.
