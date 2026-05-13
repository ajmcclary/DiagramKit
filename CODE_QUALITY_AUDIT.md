# Code Quality Audit

Date: 2026-05-13

## Executive Summary

DiagramKit has a defensible high-level architecture: SwiftPM targets are layered, the public API is concentrated in `DiagramEngine` and `DiagramPipeline`, parser output and layout output are modeled as typed enums, and importer/exporter registries establish a scalable multi-format direction. The structural health is therefore good at the target-boundary level.

The maintainability risk is concentrated one layer below that boundary. The codebase still carries large TypeScript-port modules, several parallel dispatch surfaces, and repeated per-family glue. The largest issue is not lack of abstraction in general; it is that several useful abstractions already exist but are only partially adopted. In particular, typed ELK models, typed diagram descriptors, frontmatter binding helpers, font resolvers, and canvas utilities are present but bypassed in important paths.

Audit measurements:

- `Sources`: 418 Swift files, 100,653 LOC.
- `DiagramKitModel`: 236 Swift files, 74,559 LOC, about 74% of source LOC.
- 59 source files exceed the repository's 500-line warning threshold; 11 exceed 1,000 lines.
- Exact normalized duplicate scan over `Sources/**/*.swift`: 412 repeated 10-line clusters.
- `Scripts/check-file-sizes.sh` reports warnings only; no file-size hard errors.
- `swift build --target DiagramKitGraphviz` completed successfully, but the Graphviz target declaration still diverges from its imports.

Overall assessment: structurally sound but increasingly brittle. The next maintainability gains should come from consolidating dispatch and adapter layers, not from broad rewrites of individual parsers.

## Abstraction Analysis

### Finding A1: Typed ELK models exist but dictionary-based layout remains dominant

Evidence:

- `Sources/DiagramKitModel/ElkModels.swift:8-11` states that typed ELK models replace the `[String: Any]` dictionaries currently used in `src_layout.swift`.
- `Sources/DiagramKitModel/src_layout.swift:14` still aliases `_ElkNode = [String: Any]`.
- `Sources/DiagramKitModel/src_layout.swift:27-55` builds edge dictionaries by hand.
- `Sources/DiagramKitModel/src_layout.swift:1238-1258` builds dictionaries, calls `layoutEngineSync`, then immediately converts the result back into `ElkGraphNode`.
- `Sources/DiagramKitModel/src_layout.swift:1297-1424` repeats hierarchical ELK graph construction with dictionary literals.
- `Sources/DiagramKitModel/src_elk_instance.swift:4` exposes `public typealias LayoutNode = [String: Any]`.
- Dictionary hotspot count: 41 `[String: Any]`/`_ElkNode` references in `src_layout.swift`, 24 in `src_er_layout.swift`, 22 in `src_elk_instance.swift`, 14 in `src_requirement_layout.swift`, and 13 in `src_class_layout.swift`.

Impact:

The layout boundary is the most failure-prone part of the system because structural errors silently default to zeroes, empty arrays, or missing labels. The type-safe diagram model stops before the ELK adapter, so a typo such as `"target"` versus `"targets"` is invisible to the compiler and often becomes a geometry defect caught only by snapshots.

Recommendation:

Promote `ElkGraphNode`, `ElkGraphEdge`, and `ElkGraphLabel` from output adapters to both input and output adapters. Keep dictionary conversion at exactly one boundary: the call into `layoutEngineSync`.

Illustrative refactor:

```swift
struct ElkGraphBuilder {
    func makeFlowGraph(_ graph: ParsedGraphModel, mode: ElkHierarchyMode) -> ElkGraphNode {
        ElkGraphNode(
            id: "root",
            children: makeChildren(graph),
            edges: makeEdges(graph.edges),
            layoutOptions: ElkLayoutOptions.root(direction: graph.direction, mode: mode)
        )
    }

    private func makeEdge(_ edge: original_src_types.MermaidEdge, index: Int) -> ElkGraphEdge {
        ElkGraphEdge(
            id: "e\(index)",
            sources: [edge.source],
            targets: [edge.target],
            labels: edge.label.map(makeLabel) ?? []
        )
    }
}
```

### Finding A2: `DiagramRegistry._typed` is an unused abstraction

Evidence:

- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:14-24` defines `_typed` specifically to remove repeated payload wrapping and unwrapping.
- `rg -n '_typed' Sources/DiagramKit` finds only the helper definition at `DiagramRegistry+TypedDescriptor.swift:24`.
- `Sources/DiagramKit/DiagramRegistry+Sequence.swift:13-33`, `Sources/DiagramKit/DiagramRegistry+Class.swift:13-32`, and `Sources/DiagramKit/DiagramRegistry+ER.swift:13-31` hand-code the pattern the helper was meant to centralize.
- Repository-wide, `DiagramRegistry+*.swift` contains 27 `guard case let ... = graph.payload` guards and 29 `return DiagramDocument(payload: ...)` wrappers.

Impact:

Adding or changing a diagram family requires editing repetitive closure code. The repeated shape is easy to get subtly wrong: mismatched payload cases, missing frontmatter threading, or inconsistent positioned graph initialization. The unused helper also misleads maintainers because the code says the abstraction exists, while the implementation does not benefit from it.

Recommendation:

Adopt `_typed` for families with one-to-one parse/layout payloads. Keep direct `DiagramDescriptor` construction only for cross-emitting families such as flowchart/state.

Illustrative refactor:

```swift
static let _classDiagram = _typed(
    type: .classDiagram,
    matches: { $0.normalized.hasPrefix("classdiagram") },
    parse: { source, frontmatter in
        try parseClassDiagram(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
    },
    wrap: DiagramPayload.classDiagram,
    unwrap: {
        guard case let .classDiagram(value) = $0 else { return nil }
        return value
    },
    layout: { parsed, _ in try layoutClassDiagramSync(parsed) },
    positioned: { graph, positioned in
        PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .classDiagram(
            classes: positioned.classes,
            relationships: positioned.relationships,
            namespaces: positioned.namespaces,
            notes: positioned.notes,
            accTitle: positioned.accTitle,
            accDescr: positioned.accDescription,
            diagramTitle: positioned.diagramTitle
        ))
    }
)
```

### Finding A3: ASCII rendering is a god object with its own dispatch and parse rules

Evidence:

- `Sources/DiagramKit/src_ascii_index.swift:221` exposes `original_src_ascii_index` as a large public class.
- `Sources/DiagramKit/src_ascii_index.swift:346-378` maps `DiagramType` to legacy ASCII string identifiers.
- `Sources/DiagramKit/src_ascii_index.swift:406-557` contains a 28-family render switch, including repeated source normalization and parser calls.
- `Sources/DiagramKit/src_ascii_index.swift:576-597` re-preprocesses and reparses flowchart/state sources in a private ASCII-specific path.

Impact:

ASCII rendering now has its own orchestration layer alongside `DiagramRegistry`, `SVGRenderRegistry`, and `GraphLayout`. This increases the chance that frontmatter handling, source normalization, and parser behavior diverge by output format. The file is also 670 lines, above the local size warning threshold.

Recommendation:

Create an `AsciiRenderRegistry` with per-family descriptors. The top-level function should parse once through `DiagramPipeline.parse`, then dispatch on `DiagramDocument.payload` or `PositionedGraph.content` where layout is required.

Illustrative refactor:

```swift
struct AsciiRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (DiagramDocument, AsciiRenderContext) throws -> String
}

enum AsciiRenderRegistry {
    static let all: [DiagramType: AsciiRenderDescriptor] = [
        .classDiagram: .init(type: .classDiagram) { document, context in
            guard case let .classDiagram(model) = document.payload else {
                throw DiagramStructuralError.payloadMismatch(.classDiagram)
            }
            return renderClassAscii(model, context)
        }
    ]
}
```

### Finding A4: SVG has both a registry and legacy source-case functions

Evidence:

- `Sources/DiagramKit/SVGRenderRegistry.swift:50-406` declares a large registry for all SVG render descriptors.
- `Sources/DiagramKit/src_index.swift:79-344` still keeps per-family `_render*SvgCase` functions that parse and lay out source directly.
- `Sources/DiagramKit/DiagramPipeline.swift:130-168` has a positioned-graph SVG path with a source-based fallback.
- `Sources/DiagramKit/DiagramPipeline.swift:205-211` still exposes an options path that calls `_renderDiagramSVG`, bypassing the positioned-graph pipeline.

Impact:

The system has three related SVG pathways: positioned graph rendering, source-based registry rendering, and legacy case functions. That makes it hard to reason about which render path a public API call uses and whether a fix to parsing, frontmatter, IDs, or layout applies uniformly.

Recommendation:

Make the positioned-graph renderer canonical. Source-based SVG should become a thin adapter: parse through the importer registry, layout through `GraphLayout`, then call `SVGRenderRegistry.render(positioned:)`. Keep legacy `_render*SvgCase` functions only where a family genuinely lacks positioned rendering, and track that list explicitly.

Illustrative refactor:

```swift
public static func renderSVG(
    source: String,
    theme: DiagramTheme = .default,
    layoutConfig: LayoutConfig = LayoutConfig(),
    idPolicy: SVGIDPolicy = .unique,
    registry: ImporterRegistry = defaultRegistry
) throws -> String {
    try runPipeline(operation: "DiagramPipeline.renderSVG") {
        let document = try loadDocument(source, registry: registry)
        let positioned = try GraphLayout(config: layoutConfig).layout(document)
        return try renderSVG(positioned: positioned, theme: theme, idPolicy: idPolicy, sourceIDSeed: source)
    }
}
```

### Finding A5: Legacy `original_src_*` wrappers remain public across the model surface

Evidence:

- There are 45 public/open `original_src_*` wrapper classes in `Sources/DiagramKit` and `Sources/DiagramKitModel`.
- Examples: `Sources/DiagramKitModel/src_parser.swift:1268`, `Sources/DiagramKitModel/src_layout.swift:1546`, `Sources/DiagramKitModel/src_renderer.swift:1128`, and `Sources/DiagramKit/src_ascii_index.swift:221`.
- There are 544 `original_src_` references in `Sources`.

Impact:

These names document the porting history, but they are now part of the public module surface where marked `public` or `open`. That conflicts with the format-neutral API direction and makes autocomplete and generated docs noisier. It also keeps new work anchored to TypeScript-file identity rather than Swift domain concepts.

Recommendation:

Classify each `original_src_*` wrapper as one of: public compatibility, SPI-only, or internal implementation detail. Move compatibility wrappers behind deprecation annotations or SPI, and route new code through format-neutral facades.

Illustrative refactor:

```swift
@_spi(PortCompatibility)
@available(*, deprecated, message: "Use DiagramPipeline.layout or GraphLayout instead.")
public enum OriginalSourceLayoutCompatibility {
    public static func layoutGraphSync(_ graph: DiagramDocument, _ options: RenderOptions = RenderOptions()) throws -> PositionedGraph {
        try DiagramPipeline.layout(graph)
    }
}
```

## Pattern Consistency Review

### Finding P1: Target dependency declarations are inconsistent with source imports

Evidence:

- `Package.swift:90-92` declares `DiagramKitGraphviz` dependencies as `["DiagramKitModel", "DiagramKitImport"]`.
- `Sources/DiagramKitGraphviz/DOTExporter.swift:1-5` imports `DiagramKitExport`.
- `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:1-5` imports `DiagramKitExport`.
- Comparable format targets do declare the exporter dependency: `Package.swift:84-87` for D2, `Package.swift:94-97` for Structurizr, and `Package.swift:99-102` for PlantUML.

Impact:

The package manifest understates the Graphviz target's architectural dependency. Even though `swift build --target DiagramKitGraphviz` succeeds under the current toolchain, the declared layer map is inaccurate and future target extraction, documentation, or build tooling may treat Graphviz as import-only when it also exports.

Recommendation:

Add `DiagramKitExport` to the Graphviz target dependencies, or split DOT exporting into a separate target if the intended architecture is import-only Graphviz.

Illustrative refactor:

```swift
.target(
    name: "DiagramKitGraphviz",
    dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
    swiftSettings: strictConcurrencySettings
)
```

### Finding P2: Font resolution is inconsistent between layout and rendering

Evidence:

- `Sources/DiagramKitModel/RenderConfig.swift:14-24` describes `RenderConfig`, `RenderTokens`, `DiagramFontResolver`, and `TextMetrics` as the rendering configuration path.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+TreeView.swift:92-98` uses `fontResolver.proportionalFont(...)`.
- `Sources/DiagramKitModel/src_treeview_layout.swift:29-33` measures labels with a local `BMFont`.
- `Sources/DiagramKitModel/src_treeview_layout.swift:184-189` returns `BMFont.systemFont(ofSize:)` directly.

Impact:

TreeView layout and CG rendering can measure text with different font resolution rules. That increases snapshot drift risk and makes bundled-font determinism harder to reason about. It also violates the repository convention that renderer font families route through `RenderConfig`/`DiagramFontResolver`.

Recommendation:

Move TreeView measurement to `TextMetrics` or accept a `DiagramFontResolver`/`RenderConfig` dependency at layout construction. The same resolver should feed layout and rendering.

Illustrative refactor:

```swift
struct TreeViewLayoutContext {
    var textMetrics: TextMetrics
    var fontResolver: DiagramFontResolver
}

private func measureText(_ text: String, fontSize: Double, context: TreeViewLayoutContext) -> DiagramSize {
    let width = context.textMetrics.estimateTextWidth(
        text,
        fontSize: CGFloat(fontSize),
        fontWeight: .regular
    )
    return DiagramSize(width: Double(width), height: fontSize * 1.25)
}
```

### Finding P3: Error taxonomy is defined but parser code still uses `notYetImplemented` for malformed input

Evidence:

- `Sources/DiagramKitModel/Types.swift:759-767` distinguishes `.notYetImplemented`, `.unrecognizedFormat`, and `.malformedSource`.
- `Sources/DiagramKitD2/D2Parser.swift:102-116` throws `.notYetImplemented` for unbalanced or unterminated braces.
- `Sources/DiagramKitStructurizr/StructurizrParser.swift:23-31` throws `.notYetImplemented` for missing `workspace` or `{`.
- `Sources/DiagramKitGraphviz/DOTParserHelpers.swift:32-35` and `Sources/DiagramKitGraphviz/DOTParserHelpers.swift:98-100` throw `.notYetImplemented` for parse failures.
- `Sources/DiagramKitImport/DiagramLoader.swift:23-34` already treats loader-level recognition separately from importer parse failures.

Impact:

Callers cannot reliably tell the difference between unsupported features and invalid source. Diagnostics and UI messaging become less actionable, and tests that should assert malformed input may accidentally accept "implementation gap" behavior.

Recommendation:

Reserve `.notYetImplemented` for real missing features. Use `.malformedSource(message:)` for syntax errors and attach `.unsupported` diagnostics for valid but unsupported constructs.

Illustrative refactor:

```swift
guard depth == 0 else {
    throw DiagramError.malformedSource(message: "Unterminated D2 block: missing '}'")
}
```

### Finding P4: Transition comments and implementation state have drifted

Evidence:

- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:8-11` says a format-agnostic importer registry "will be introduced in Phase 1", but `ImporterRegistry` already exists.
- `Sources/DiagramKit/MermaidImporter.swift:29-31` references a future Phase 6D behavior while `DiagramError.unrecognizedFormat` is already present.
- `Sources/DiagramKit/DiagramPipeline.swift:126-129` says positioned SVG currently supports only a short list, while `Sources/DiagramKit/SVGRenderRegistry.swift:50-406` provides `renderPositioned` closures for every listed family.
- `Sources/DiagramKitModel/ShapeSpecRegistry+Defaults.swift:12-14` repeats the same `MARK` heading.

Impact:

Stale comments are not runtime defects, but they increase cognitive load in a project whose correctness already depends on ordering and layering invariants. New contributors may preserve obsolete transition boundaries or avoid abstractions that are already available.

Recommendation:

Treat architecture comments as code. Update comments during the same refactor that changes a phase boundary, and add a lightweight check for known stale phrases such as "will be introduced" in completed areas.

Illustrative refactor:

```swift
// Mermaid-family descriptor registry. Format-agnostic source dispatch lives in
// DiagramKitImport. This registry remains as the Mermaid family detector and
// descriptor catalog.
```

### Finding P5: New diagram-family work still fans out across too many central switch sites

Evidence:

- `Sources/DiagramKitModel/Types.swift:6-35` defines `DiagramType`.
- `Sources/DiagramKitModel/Types.swift:41-130` maps `DiagramPayload` cases back to `DiagramType`.
- `Sources/DiagramKitModel/Types.swift:162-220` initializes empty payloads per type.
- `Sources/DiagramKit/DiagramDescriptor.swift:131-162` orders the Mermaid family registry.
- `Sources/DiagramKitRenderingCG/DiagramRenderer.swift:55-110` dispatches CG rendering by `PositionedContent`.
- `Sources/DiagramKit/SVGRenderRegistry.swift:50-406` dispatches SVG rendering.
- `Sources/DiagramKit/src_ascii_index.swift:346-557` dispatches ASCII detection and rendering.

Impact:

Swift enums make some central dispatch unavoidable, but the current fan-out means a new family or family rename must be wired in many places. Missing one site may compile but degrade one output format or a convenience initializer.

Recommendation:

Move per-family capabilities into descriptors and generate or validate central tables from those descriptors. Keep `DiagramType` and payload enums hand-written, but make render/import/export/ASCII capability registration descriptor-driven.

Illustrative refactor:

```swift
protocol DiagramFamilyModule {
    static var type: DiagramType { get }
    static var mermaidDescriptor: DiagramDescriptor { get }
    static var svgDescriptor: SVGRenderDescriptor? { get }
    static var asciiDescriptor: AsciiRenderDescriptor? { get }
}
```

## Duplication and Reuse Audit

### Finding D1: Frontmatter bindings repeat the same state machine

Evidence:

- `Sources/DiagramKitModel/FrontmatterBinding.swift:55-83` provides only `extractKey(...)`.
- `Sources/DiagramKitModel/FrontmatterBinding+ER.swift:12-17` is the single-section apply pattern.
- `Sources/DiagramKitModel/FrontmatterBinding+Packet.swift:20-31` is the config/theme apply pattern.
- There are 27 `FrontmatterBinding+*.swift` files.
- Exact duplicate scan found a 10-line apply skeleton repeated across 10 files, a config/theme skeleton repeated across 7 files, and a second config/theme variant repeated across 4 files.

Impact:

Each binding has to remember how to detect prefixes, flip `hasConfig`/`hasTheme` flags, and commit sections. That repetition is mostly boilerplate, not domain logic. It increases the chance that new frontmatter keys parse differently across families.

Recommendation:

Introduce reusable binding runners that own prefix matching and section flags. Per-family code should provide key maps and commit behavior.

Illustrative refactor:

```swift
struct ConfigThemeBinding<Config, Theme> {
    var config: Config
    var theme: Theme
    var hasConfig = false
    var hasTheme = false

    mutating func apply(
        path: String,
        value: FrontmatterValue,
        configPrefixes: [String],
        themePrefixes: [String],
        applyConfig: (String, FrontmatterValue, inout Config) -> Bool,
        applyTheme: (String, FrontmatterValue, inout Theme) -> Bool
    ) -> Bool {
        if let key = FrontmatterPrefixMatcher.extractKey(path: path, prefixes: configPrefixes) {
            guard applyConfig(key, value, &config) else { return false }
            hasConfig = true
            return true
        }
        if let key = FrontmatterPrefixMatcher.extractKey(path: path, prefixes: themePrefixes) {
            guard applyTheme(key, value, &theme) else { return false }
            hasTheme = true
            return true
        }
        return false
    }
}
```

### Finding D2: ELK graph options and label dictionaries are repeated

Evidence:

- `Sources/DiagramKitModel/src_layout.swift:32-52` builds an edge-label dictionary.
- `Sources/DiagramKitModel/src_layout.swift:73-97` defines root layout options for flat graphs.
- `Sources/DiagramKitModel/src_layout.swift:1320-1324` repeats edge-label construction.
- `Sources/DiagramKitModel/src_layout.swift:1399-1423` repeats root layout options for hierarchical graphs.
- `Sources/DiagramKitModel/src_layout.swift:1426-1484` repeats a third graph builder for fallback layout.

Impact:

Spacing, padding, edge-label sizing, and hierarchy mode are encoded as repeated string dictionaries. Any tuning change has to be applied in several places, and missing one produces layout drift that may only show up in snapshot baselines.

Recommendation:

Extract root/subgraph option builders and edge-label builders. This can be done before fully migrating off dictionaries.

Illustrative refactor:

```swift
enum ElkLayoutOptions {
    static func root(direction: original_src_types.Direction, hierarchy: String) -> [String: String] {
        [
            "elk.algorithm": "layered",
            "elk.direction": _mapDirection(direction),
            "elk.spacing.nodeNode": "28",
            "elk.layered.spacing.nodeNodeBetweenLayers": "48",
            "elk.padding": "[top=40,left=40,bottom=40,right=40]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.hierarchyHandling": hierarchy
        ]
    }
}
```

### Finding D3: Bounds-from-polyline logic is duplicated across stable-element conformances

Evidence:

- `Sources/DiagramKitModel/DiagramBoundsLookup+Flowchart.swift:48-63`
- `Sources/DiagramKitModel/DiagramBoundsLookup+Class.swift:26-41`
- `Sources/DiagramKitModel/DiagramBoundsLookup+ER.swift:26-41`
- `Sources/DiagramKitCommon/DiagramGeometry.swift:43-100` already owns `DiagramRect` spatial operations but lacks a bounding factory.

Impact:

Hit-target padding and empty-point behavior are repeated. If one diagram family changes edge hit testing, others can drift.

Recommendation:

Add a portable `DiagramRect.bounding(points:paddedBy:)` helper to `DiagramGeometry.swift` and use it in every edge stable-element conformance.

Illustrative refactor:

```swift
extension DiagramRect {
    public static func bounding(points: [DiagramPoint], paddedBy pad: Double = 0) -> DiagramRect {
        guard let first = points.first else { return .zero }
        let bounds = points.reduce((first.x, first.y, first.x, first.y)) { acc, point in
            (
                Swift.min(acc.0, point.x),
                Swift.min(acc.1, point.y),
                Swift.max(acc.2, point.x),
                Swift.max(acc.3, point.y)
            )
        }
        return DiagramRect(
            x: bounds.0 - pad,
            y: bounds.1 - pad,
            width: bounds.2 - bounds.0 + pad * 2,
            height: bounds.3 - bounds.1 + pad * 2
        )
    }
}
```

### Finding D4: ASCII renderers duplicate canvas mutation helpers

Evidence:

- `Sources/DiagramKitModel/src_ascii_sequence.swift:334-345`
- `Sources/DiagramKitModel/src_ascii_class_diagram.swift:344-355`
- `Sources/DiagramKitModel/src_ascii_er_diagram.swift:322-333`
- `Sources/DiagramKitModel/src_ascii_canvas.swift:41-68` has role-canvas growth helpers and `setRole(...)`, but no combined canvas/role writer.

Impact:

The duplicated `setC` logic has identical bounds and growth behavior today. If role-canvas semantics change, each renderer must be updated manually. It also makes local renderers longer and less focused on diagram-specific drawing.

Recommendation:

Introduce an `AsciiCanvasWriter` that owns canvas growth, role growth, and character placement.

Illustrative refactor:

```swift
public struct AsciiCanvasWriter {
    public var canvas: Canvas
    public var roles: RoleCanvas

    public mutating func set(_ x: Int, _ y: Int, _ ch: Character, role: CharRole) {
        guard x >= 0, y >= 0 else { return }
        if x >= canvas.count || y >= (canvas.first?.count ?? 0) {
            increaseSize(&canvas, x, y)
            increaseRoleCanvasSize(&roles, x, y)
        }
        canvas[x][y] = ch
        setRole(&roles, x, y, role)
    }
}
```

### Finding D5: Flowchart exporters duplicate traversal and source assembly

Evidence:

- `Sources/DiagramKitD2/D2Exporter.swift:43-88` traverses `ParsedGraphModel` nodes and edges to produce D2.
- `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:9-50` traverses the same model to produce DOT.
- Shape mapping remains format-specific at `Sources/DiagramKitD2/D2Exporter.swift:113-128` and `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:79-95`.

Impact:

The exporters are small enough that this is not urgent, but future exporters will likely repeat title handling, direction handling, node iteration, edge iteration, and diagnostics scaffolding. Reuse is especially valuable because import/export coverage is a strategic direction for DiagramKit.

Recommendation:

Introduce a tiny flowchart export walking abstraction with format-specific callbacks for identifiers, labels, shapes, and line emission.

Illustrative refactor:

```swift
struct FlowchartExportWalker {
    let model: ParsedGraphModel

    func walk<S: FlowchartExportSink>(_ sink: inout S) throws {
        try sink.emitDirection(model.direction)
        for (nodeId, node) in model.nodesInOrder {
            try sink.emitNode(id: nodeId, node: node)
        }
        for edge in model.edges {
            try sink.emitEdge(edge)
        }
    }
}
```

### Finding D6: Some repetition is acceptable and should not be generalized yet

Evidence:

- `Sources/DiagramKitModel/ShapeSpecRegistry+Defaults.swift:16-129` is a declarative table of shape specs.
- Per-family parser files such as `Sources/DiagramKitModel/src_gantt_parser.swift:1-873`, `Sources/DiagramKitModel/src_requirement_parser.swift:1-816`, and `Sources/DiagramKitModel/src_sequence_parser.swift:1-803` encode distinct grammars.
- Per-family renderer files map to intentionally separate diagram semantics.

Impact:

Over-generalizing these areas would likely reduce clarity. Shape specs and grammar-specific parsers are domain repetition, not accidental duplication.

Recommendation:

Do not refactor declarative shape tables or grammar-specific parser bodies merely to reduce line count. Apply extraction only where the same control flow, adapter code, or error handling recurs across families.

## Prioritized Refactoring Roadmap

### Priority 1: Collapse the ELK dictionary boundary

Files:

- `Sources/DiagramKitModel/src_layout.swift:14-55`
- `Sources/DiagramKitModel/src_layout.swift:1238-1258`
- `Sources/DiagramKitModel/src_layout.swift:1297-1484`
- `Sources/DiagramKitModel/src_elk_instance.swift:4-45`
- `Sources/DiagramKitModel/ElkModels.swift:8-170`

Why first:

This has the highest maintainability and correctness payoff. It reduces silent layout failures and removes repeated stringly typed graph construction from the most complex path.

Suggested sequence:

1. Add dictionary encoders to `ElkGraphNode`, `ElkGraphEdge`, and `ElkGraphLabel`.
2. Extract `ElkLayoutOptions`.
3. Convert `_buildFlatElkGraph` first because it is smallest.
4. Convert `_buildElkGraphNoCrossEdges`.
5. Convert `_buildElkGraph`.

### Priority 2: Make render dispatch descriptor-driven

Files:

- `Sources/DiagramKit/SVGRenderRegistry.swift:50-456`
- `Sources/DiagramKit/src_index.swift:79-344`
- `Sources/DiagramKit/src_ascii_index.swift:346-557`
- `Sources/DiagramKit/DiagramPipeline.swift:130-211`

Why second:

This addresses the largest cognitive-load issue: multiple output formats parse, layout, and dispatch differently. It also reduces the chance of frontmatter and source-normalization drift.

Suggested sequence:

1. Make positioned SVG the default internal path.
2. Add `AsciiRenderRegistry`.
3. Keep legacy source-based helpers behind narrow adapters.
4. Add tests that parse/layout once and render SVG/ASCII from the same document or positioned graph.

### Priority 3: Adopt existing descriptor and frontmatter helpers

Files:

- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:14-47`
- `Sources/DiagramKit/DiagramRegistry+Sequence.swift:13-35`
- `Sources/DiagramKit/DiagramRegistry+Class.swift:13-34`
- `Sources/DiagramKit/DiagramRegistry+ER.swift:13-33`
- `Sources/DiagramKitModel/FrontmatterBinding.swift:55-83`
- `Sources/DiagramKitModel/FrontmatterBinding+*.swift`

Why third:

This is relatively low risk and removes a large amount of boilerplate. It also makes new diagram-family work less error-prone.

Suggested sequence:

1. Convert three simple registry descriptors to `_typed` as examples.
2. Add frontmatter binding runners for single-section and config/theme families.
3. Convert the most duplicated bindings first: ER/Ishikawa/Journey/Kanban/Class/C4/Mindmap/State and Architecture/Packet/XYChart/Timeline/Requirement/Venn/Quadrant.

### Priority 4: Normalize error taxonomy and target metadata

Files:

- `Package.swift:90-92`
- `Sources/DiagramKitGraphviz/DOTExporter.swift:1-5`
- `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:1-5`
- `Sources/DiagramKitModel/Types.swift:759-767`
- `Sources/DiagramKitD2/D2Parser.swift:102-116`
- `Sources/DiagramKitStructurizr/StructurizrParser.swift:23-31`
- `Sources/DiagramKitGraphviz/DOTParserHelpers.swift:32-35`

Why fourth:

These changes improve consistency and external behavior but are smaller in scope than the layout/rendering consolidation.

Suggested sequence:

1. Add `DiagramKitExport` to the Graphviz target dependencies or split DOT export.
2. Replace malformed-source uses of `.notYetImplemented`.
3. Add tests asserting malformed input yields `.malformedSource`.

### Priority 5: Clean public legacy port surfaces

Files:

- `Sources/DiagramKitModel/src_parser.swift:1268`
- `Sources/DiagramKitModel/src_layout.swift:1546`
- `Sources/DiagramKitModel/src_renderer.swift:1128`
- `Sources/DiagramKit/src_ascii_index.swift:221`

Why fifth:

This is important for API clarity but may have compatibility implications. It should follow the mechanical reuse work so compatibility shims can point to stable format-neutral APIs.

Suggested sequence:

1. Inventory the 45 public/open `original_src_*` wrappers.
2. Classify each as public compatibility, SPI, or internal.
3. Deprecate or hide wrappers that are not intentional public API.
4. Regenerate public docs and verify the public surface is format-neutral.

## Closing Assessment

DiagramKit's main architectural decisions are strong: the package has clear layers, typed payloads, and a public async facade. The current maintainability burden comes from incomplete migrations: old TypeScript-port surfaces and source-based render paths coexist with newer registries and typed adapters. The best refactoring strategy is incremental consolidation around the abstractions already present, starting with the ELK adapter and render dispatch paths.
