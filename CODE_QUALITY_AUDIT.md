# Code Quality Audit: Structural Design and Maintainability

Date: 2026-05-08

## Executive Summary

The codebase has a strong functional foundation: the public API is small, the pipeline model is clear, the project has broad snapshot coverage, and type-safe payload enums are a good fit for a native Swift port of many Mermaid diagram families. The overall structural health is **moderate**: the system is usable and extensible in principle, but extension cost is high because major domain decisions are repeated across parser dispatch, SVG dispatch, CG dispatch, layout dispatch, frontmatter binding, and shape geometry.

Measured shape:

| Area | Files / LOC |
| --- | ---: |
| `Sources/BeautifulMermaidSwift` total Swift LOC | 81,383 |
| `Sources/BeautifulMermaidSwift/Mermaid` | 68,485 LOC across 152 Swift files |
| `Sources/BeautifulMermaidSwift/Render` | 9,595 LOC across 35 Swift files |
| Tests | 31,825 LOC |

Primary structural risks:

1. `SourcePreprocessing.swift` has grown into a frontmatter, init-directive, YAML, config, and theme binding God object.
2. Diagram routing is duplicated in at least seven places, so adding or changing a diagram type is a multi-file, order-sensitive operation.
3. SVG and CG rendering duplicate core shape and edge semantics, with no shared geometry abstraction.
4. Several helper abstractions exist but are under-used, especially XML escaping, source statement splitting, SVG document construction, and `RenderConfig`.
5. Porting artifacts are exposed as public API, increasing the future cost of cleanup.

The most valuable refactoring path is to establish a single diagram descriptor/routing layer, split frontmatter binding into per-diagram binders, remove `Mirror`/`Any` extraction from the flow SVG renderer, and centralize SVG construction and escaping.

## Abstraction Analysis

### A1. `SourcePreprocessing.swift` is a God object

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:6-19` handles source preprocessing and statement splitting entry points.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:74-127` parses frontmatter and init directives.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:179-281` dispatches JSON init directive payloads across many diagram-specific config and theme handlers.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:317-838` implements per-diagram init config/theme application.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1044-1124` stores per-diagram parser state in one `_StackSafeYamlFrontmatterParser`.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1135-1170` chains every per-diagram YAML handler in one method.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1946-1992` finalizes every possible frontmatter section in one place.

Impact:

This file is 2,637 LOC and owns unrelated responsibilities: source normalization, YAML flattening, init directive parsing, scalar conversion, per-diagram config binding, theme binding, and frontmatter assembly. Adding a config key requires knowing both the JSON init path and YAML frontmatter path. The current form also encourages inconsistent scalar parsing: JSON init uses helpers like `_jsonDouble` at `SourcePreprocessing.swift:882-910`, while YAML handlers use direct `Double(value)` / `Int(value)` conversions throughout `SourcePreprocessing.swift:1191-1846`.

Recommendation:

Split this into four abstractions:

- `MermaidSourceNormalizer`: newline normalization, statement splitting, comment filtering.
- `FrontmatterDocumentParser`: YAML-like flattening only.
- `InitDirectiveParser`: `%%{init: ...}%%` extraction and JSON decoding only.
- Per-diagram `FrontmatterBinding` implementations that map keys into typed config/theme values.

Illustrative refactoring:

```swift
struct FrontmatterValue {
    let raw: String

    var bool: Bool? {
        switch raw.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    var double: Double? { Double(raw) }
    var int: Int? { Int(raw) }
}

protocol FrontmatterBinding {
    static var prefixes: [String] { get }
    mutating func apply(path: String, value: FrontmatterValue) -> Bool
    func commit(into frontmatter: inout DiagramFrontmatter)
}

struct SequenceFrontmatterBinding: FrontmatterBinding {
    static let prefixes = ["config.sequence."]
    private var config = SequenceDiagramConfig()
    private var hasSection = false

    mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        guard path.hasPrefix(Self.prefixes[0]) else { return false }
        hasSection = true
        switch path.dropFirst(Self.prefixes[0].count) {
        case "diagramMarginX": config.diagramMarginX = value.double ?? config.diagramMarginX
        case "useMaxWidth": config.useMaxWidth = value.bool ?? config.useMaxWidth
        default: break
        }
        return true
    }

    func commit(into frontmatter: inout DiagramFrontmatter) {
        if hasSection { frontmatter.sequenceConfig = config }
    }
}
```

### A2. Diagram routing lacks a single source of truth

Evidence:

- Parser dispatch: `Sources/BeautifulMermaidSwift/Parser.swift:20-250`.
- SVG type detection: `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:119-207`.
- SVG render dispatch: `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:295-362`.
- Layout dispatch: `Sources/BeautifulMermaidSwift/Layout.swift:10-358`.
- CG render dispatch: `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:37-92`.
- Payload-to-type mapping: `Sources/BeautifulMermaidSwift/Types.swift:69-128`.
- Empty payload/content initialization: `Sources/BeautifulMermaidSwift/Types.swift:155-213` and `Sources/BeautifulMermaidSwift/Types.swift:327-384`.

Impact:

The codebase pays a high coordination cost for every diagram type. A new diagram requires updates to multiple switches and header detectors, and omissions can compile if they occur outside exhaustive enum switches. It also creates behavioral drift: C4 detection is a regex at `Parser.swift:235-239` and duplicated at `src_index.swift:201-204`; treeView detection is helper-based in `Parser.swift:182-184` but direct string logic in `src_index.swift:186-187`.

Recommendation:

Introduce a central `DiagramDescriptor` table. Keep the type-safe enum payloads, but let detection and common parse/layout/render metadata live in one place.

Illustrative refactoring:

```swift
struct DiagramHeader {
    var raw: String
    var normalized: String { raw.lowercased() }
}

struct DiagramDescriptor {
    let type: DiagramType
    let matches: (DiagramHeader) -> Bool
    let parse: (String, DiagramFrontmatter?) throws -> MermaidGraph
    let layout: (MermaidGraph, LayoutConfig) throws -> PositionedGraph
}

enum DiagramRegistry {
    static let descriptors: [DiagramDescriptor] = [
        .init(
            type: .sequenceDiagram,
            matches: { $0.normalized.hasPrefix("sequencediagram") },
            parse: { source, frontmatter in
                let lines = MermaidSourceNormalizer.diagramLines(source)
                return MermaidGraph(payload: .sequenceDiagram(try parseSequenceDiagram(lines)))
            },
            layout: { graph, _ in
                guard case let .sequenceDiagram(diagram) = graph.typedPayload else {
                    throw MermaidStructuralError.payloadMismatch(.sequenceDiagram)
                }
                let positioned = try layoutSequenceDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .sequenceDiagram(positioned))
            }
        )
    ]
}
```

### A3. Flow SVG rendering bypasses type safety with `Mirror` and `Any`

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1264-1279` extracts a flow SVG model by mapping typed nodes, edges, and groups through `Any`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1282-1345` reconstructs `_SvgNode`, `_SvgEdge`, `_SvgGroup`, and `_SvgPoint` through string labels.
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1348-1424` implements generic `Mirror` readers for optional unboxing, arrays, strings, doubles, booleans, and maps.

Impact:

This negates the project convention that graph payloads and positioned content should be pattern-matched directly. Property renames, field type changes, or optional shape changes can silently render empty strings or zero geometry instead of producing compile-time errors. It also creates hidden coupling between private struct field names and rendering behavior.

Recommendation:

Replace reflection with typed adapters from `PositionedNode`, `PositionedEdge`, and `PositionedGroup`.

Illustrative refactoring:

```swift
private extension _SvgPoint {
    init(_ point: PositionedPoint) {
        self.init(x: point.x, y: point.y)
    }
}

private extension _SvgNode {
    init(_ node: PositionedNode, securityLevel: String?) {
        self.init(
            id: node.id,
            label: node.label,
            descriptions: node.descriptions,
            shape: node.shape,
            x: node.x,
            y: node.y,
            width: node.width,
            height: node.height,
            inlineStyle: node.inlineStyle,
            interaction: node.interaction,
            icon: node.properties?.icon,
            img: node.properties?.img,
            securityLevel: securityLevel
        )
    }
}

private func _extractSvgGraphModel(_ graph: PositionedGraph) -> _SvgGraphModel {
    let securityLevel = _graphSecurityLevel(graph.diagram)
    switch graph.content {
    case let .flowchart(nodes, edges, groups), let .stateDiagram(nodes, edges, groups):
        return _SvgGraphModel(
            width: graph.width,
            height: graph.height,
            nodes: nodes.map { _SvgNode($0, securityLevel: securityLevel) },
            edges: edges.map(_SvgEdge.init),
            groups: groups.map(_SvgGroup.init),
            securityLevel: securityLevel,
            isStateDiagram: graph.diagram.type == .stateDiagram
        )
    default:
        return _SvgGraphModel(width: graph.width, height: graph.height, nodes: [], edges: [], groups: [], securityLevel: securityLevel)
    }
}
```

### A4. `RenderConfig` is useful but not the canonical source for geometry and fonts

Evidence:

- `Sources/BeautifulMermaidSwift/Render/RenderConfig.swift:18-126` defines node padding, font sizes, spacing, minimum sizes, shape constants, and font families.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:93-161` hardcodes flow node padding, shape adjustments, and minimum sizes independently.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:213-231` hardcodes ELK spacing and padding strings.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:300-302` defaults SVG rendering to `"Inter"`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_requirement_svg.swift:6`, `src_sequence_renderer.swift:7`, `src_class_renderer.swift:15`, `src_xychart_renderer.swift:52`, and many sibling SVG renderers default to `"Inter"` independently.
- `Sources/BeautifulMermaidSwift/Mermaid/src_ishikawa_layout.swift:29` creates a `"Menlo"` CoreText font directly.

Impact:

Config changes do not consistently affect layout, CG rendering, and SVG rendering. The project has a stated determinism constraint around bundled fonts, but the SVG path and some layout measurement paths still use renderer-local font defaults. That increases snapshot drift and makes visual changes difficult to reason about.

Recommendation:

Promote `RenderConfig` into a pipeline-level `RenderTokens` value used by layout, CG, and SVG. If SVG needs CSS family strings rather than `BMFont`, derive those strings from the same config defaults.

Illustrative refactoring:

```swift
struct RenderTokens: Sendable {
    var config: RenderConfig

    var svgFontFamily: String {
        config.defaultProportionalFontFamily ?? "system-ui"
    }

    var nodePaddingX: Double { Double(config.nodePaddingHorizontal) }
    var nodePaddingY: Double { Double(config.nodePaddingVertical) }
    var graphPadding: Double { Double(config.graphPadding) }
}
```

### A5. Porting artifacts are exposed as public API

Evidence:

- The package exports `BeautifulMermaid` as a library at `Package.swift:12-14`.
- The `Mermaid` source tree contains 740 `public` or `open` declarations.
- Port namespace classes are public/open, for example `Sources/BeautifulMermaidSwift/Mermaid/src_multiline_utils.swift:4-5`, `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1461`, `Sources/BeautifulMermaidSwift/Mermaid/src_parser.swift:1265`, and `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:700`.
- Lower-level functions are public, including `parseMermaid` at `Sources/BeautifulMermaidSwift/Mermaid/src_parser.swift:176`, `layoutGraphSync` at `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1357-1370`, and compatibility rendering functions at `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:643-685`.

Impact:

Accidental public API makes internal cleanup harder. Consumers can start depending on JS-port implementation names, lower-level parser functions, and renderer helpers that are not part of the documented facade. That increases semantic-versioning pressure and discourages internal redesign.

Recommendation:

Define a formal public API boundary. Keep `MermaidRenderer`, `MermaidImageRenderer`, `MermaidParser`, core public payload types, and documented diagram model types public. Move port scaffolding and implementation-only functions to `internal` where possible. For symbols that may already be used externally, deprecate first and point callers to facade APIs.

Illustrative refactoring:

```swift
@available(*, deprecated, message: "Use MermaidRenderer.renderSVG(source:theme:) instead.")
public func renderMermaidSVG(_ text: String, _ options: RenderOptions = RenderOptions()) throws -> String {
    try _renderMermaidSVG(text, options)
}

// Implementation detail after the deprecation window.
func _renderMermaidSVG(_ text: String, _ options: RenderOptions = RenderOptions()) throws -> String {
    ...
}
```

## Pattern Consistency Review

### P1. Font registration contract is inconsistently applied

Evidence:

- `MermaidPipeline.layout` registers fonts at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:24`.
- `MermaidPipeline.prepare` registers fonts at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:48`.
- `MermaidPipeline.renderSVG` registers fonts at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:62` and `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:72`.
- `MermaidPipeline.renderASCII` registers fonts at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:87`.
- `MermaidPipeline.parse` does not register fonts at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:12-15`.
- `MermaidRenderer.parse` delegates directly to `MermaidPipeline.parse` at `Sources/BeautifulMermaidSwift/BeautifulMermaid.swift:26-29`.
- `MermaidImageRenderer.prepareSync` bypasses `MermaidPipeline.prepare` at `Sources/BeautifulMermaidSwift/ImageRenderer.swift:33-39`.

Impact:

The project documentation says bundled font registration must happen first in every pipeline method for deterministic behavior. The current exception is easy to miss because all other pipeline methods follow the rule. Even if parsing normally does not measure text, the inconsistent boundary creates future regression risk when parse-time frontmatter or markdown handling changes.

Recommendation:

Centralize entry-point setup instead of repeating it manually.

Illustrative refactoring:

```swift
private static func runPipeline<T>(
    operation: String,
    _ work: () throws -> T
) throws -> T {
    BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()
    return try _withMermaidIssueReporting(operation: operation, work)
}

public static func parse(_ source: String) throws -> MermaidGraph {
    try runPipeline(operation: "MermaidPipeline.parse") {
        try MermaidParser.parse(source)
    }
}
```

### P2. Layout mismatch handling repeats defensive empty fallbacks

Evidence:

- `Sources/BeautifulMermaidSwift/Layout.swift:15-19` reports a class payload mismatch and returns an empty class diagram.
- `Sources/BeautifulMermaidSwift/Layout.swift:35-39` does the same for ER.
- `Sources/BeautifulMermaidSwift/Layout.swift:53-57` does the same for sequence.
- The same pattern repeats through `Sources/BeautifulMermaidSwift/Layout.swift:78-357`.

Impact:

`MermaidGraph.type` is derived from `MermaidGraph.payload` at `Sources/BeautifulMermaidSwift/Types.swift:131-136`, so most mismatch branches should be unreachable. Returning empty diagrams can hide programmer errors as blank renders, which overlaps with the known snapshot gap where missing image baselines can indicate 0x0 layout bugs.

Recommendation:

Switch on `graph.typedPayload` directly. This keeps the compiler in charge of pairing payloads with layout functions and removes empty fallback boilerplate.

Illustrative refactoring:

```swift
public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
    try _withMermaidIssueReporting(operation: "GraphLayout.layout") {
        switch graph.typedPayload {
        case .flowchart, .stateDiagram:
            return try layoutGraphSync(graph, config: config)

        case let .sequenceDiagram(parsed):
            let positioned = try layoutSequenceDiagram(parsed)
            return PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .sequenceDiagram(positioned)
            )

        case let .pie(chart):
            let positioned = layoutPieChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    }
}
```

### P3. Statement splitting is implemented in multiple places

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:21-63` implements quote-aware statement splitting.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:213-269` implements a second quote-aware source splitting function.
- `Sources/BeautifulMermaidSwift/Parser.swift:12-18` has a third newline normalization helper for raw line arrays.

Impact:

Parser and SVG routes can disagree on semicolon handling, quote escaping, CRLF normalization, and comment filtering. Since header detection is order-sensitive, even small differences here can send the same source through different diagram paths.

Recommendation:

Move all normalization and statement splitting behind one internal API and require callers to choose only whether frontmatter should already be stripped.

Illustrative refactoring:

```swift
enum MermaidSourceNormalizer {
    static func rawLines(_ source: String) -> [String] { ... }

    static func statements(
        _ source: String,
        separators: CharacterSet = CharacterSet(charactersIn: "\n;"),
        stripFrontmatter: Bool
    ) -> [String] { ... }
}
```

### P4. SVG document construction conventions vary by renderer

Evidence:

- Flow, sequence, ER, class, and XY chart use `original_src_theme.svgOpenTag` and `buildStyleBlock` at `src_renderer.swift:90-99`, `src_sequence_renderer.swift:30-32`, `src_er_renderer.swift:80`, `src_class_renderer.swift:43-57`, and `src_xychart_renderer.swift:70-82`.
- Treemap, architecture, kanban, packet, C4, ZenUML, and other renderers hand-build SVG wrappers at `src_treemap_svg.swift:18-34`, `src_architecture_renderer.swift:27-42`, `src_kanban_renderer.swift:28-45`, `src_packet_renderer.swift:39-97`, `src_c4_renderer.swift:30-71`, and `src_zenuml_renderer.swift:132-134`.
- Accessibility tags are similarly repeated, for example `src_sequence_renderer.swift:43-46`, `src_requirement_svg.swift:21-24`, `src_gantt_renderer.swift:84-87`, and `src_kanban_renderer.swift:37-40`.

Impact:

Accessibility, background transparency, viewBox construction, CSS variable definitions, and `<defs>` handling vary per renderer. This makes renderer changes error-prone and makes it harder to guarantee parity across diagram families.

Recommendation:

Create an internal `SVGDocumentBuilder` that owns open tags, accessibility tags, background handling, style blocks, and defs.

Illustrative refactoring:

```swift
struct SVGDocumentBuilder {
    var id: String?
    var width: Double
    var height: Double
    var viewBox: String?
    var colors: DiagramColors
    var transparent: Bool

    func open(className: String) -> String { ... }
    func accessibility(title: String?, description: String?) -> String { ... }
    func style(fontFamily: String, includeHtmlLabelCSS: Bool) -> String { ... }
    func close() -> String { "</svg>" }
}
```

### P5. Access control and naming patterns mix public Swift API with JS-port namespaces

Evidence:

- Public facade methods live in `Sources/BeautifulMermaidSwift/BeautifulMermaid.swift:25-110`.
- JS-port namespace classes use names such as `original_src_multiline_utils` at `Sources/BeautifulMermaidSwift/Mermaid/src_multiline_utils.swift:4`.
- Lower-level public parser/layout/render functions exist throughout the `Mermaid` folder, including `parseC4Diagram` at `Sources/BeautifulMermaidSwift/Mermaid/src_c4_parser.swift:10`, `layoutC4Diagram` at `Sources/BeautifulMermaidSwift/Mermaid/src_c4_layout.swift:91`, and `renderC4Svg` at `Sources/BeautifulMermaidSwift/Mermaid/src_c4_renderer.swift:13`.

Impact:

The repository communicates two API styles at once: idiomatic Swift facade APIs and JS-port module names. That raises cognitive load for contributors and makes it unclear which symbols are stable.

Recommendation:

Document and enforce access levels:

- Public: facade, payload/model types intentionally supported by clients.
- Internal: parser/layout/render functions and JS-port namespaces.
- SPI: underscore-prefixed internal extension points that tests or playgrounds may need.

## Duplication and Reuse Audit

### D1. Diagram type handling is duplicated across dispatch layers

Evidence:

- Diagram cases are declared at `Sources/BeautifulMermaidSwift/Types.swift:4-33`.
- Payload cases are declared at `Sources/BeautifulMermaidSwift/Types.swift:39-67`.
- Payload-to-type repeats the full list at `Sources/BeautifulMermaidSwift/Types.swift:69-128`.
- Empty parsed graph initialization repeats the full list at `Sources/BeautifulMermaidSwift/Types.swift:155-213`.
- Empty positioned content repeats the full list at `Sources/BeautifulMermaidSwift/Types.swift:327-384`.
- Parser routing repeats the list at `Sources/BeautifulMermaidSwift/Parser.swift:29-247`.
- Layout routing repeats the list at `Sources/BeautifulMermaidSwift/Layout.swift:12-358`.
- CG render routing repeats the list at `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:37-92`.
- SVG routing repeats a parallel list at `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:80-108`, `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:119-207`, and `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:307-362`.

Impact:

This is the largest maintainability tax in the project. The repetition is not only textual; it is behavioral. Each list can drift in ordering, supported aliases, defaults, frontmatter application, and render support.

Reuse opportunity:

Adopt the `DiagramDescriptor` registry described in A2. Even if exhaustive enum switches remain for type safety, header matching and facade-level routing should be centralized.

### D2. Frontmatter scalar binding duplicates hundreds of small conversions

Evidence:

- `case "useMaxWidth"` appears 32 times in `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift`.
- Scalar parsing patterns using `Double(value)`, `Int(value)`, and `value.lowercased() == "true"` occur 320 times in `SourcePreprocessing.swift`.
- Sequence config binding is duplicated between JSON init directives at `SourcePreprocessing.swift:317-406` and YAML frontmatter at `SourcePreprocessing.swift:1327-1367`.
- Requirement config binding is duplicated between `SourcePreprocessing.swift:409-452` and `SourcePreprocessing.swift:1467-1488`.
- Venn config binding is duplicated between `SourcePreprocessing.swift:715-740` and `SourcePreprocessing.swift:1782-1801`.
- Radar config/theme binding is duplicated between `SourcePreprocessing.swift:762-863` and `SourcePreprocessing.swift:1732-1753`.

Impact:

The same config keys have multiple parsing semantics. Some paths preserve previous defaults with `?? existing`, some assign optionals directly, some fallback to magic values such as `50` at `SourcePreprocessing.swift:1482-1483`, and some report `applied` only if conversion succeeds. This increases the likelihood that YAML frontmatter and init directives produce different results.

Reuse opportunity:

Use shared typed bindings that can consume either JSON init objects or flattened YAML entries.

Illustrative refactoring:

```swift
struct ConfigField<Root> {
    let key: String
    let apply: (inout Root, FrontmatterValue) -> Bool
}

let sequenceFields: [ConfigField<SequenceDiagramConfig>] = [
    .init(key: "diagramMarginX") { config, value in
        guard let v = value.double else { return false }
        config.diagramMarginX = v
        return true
    },
    .init(key: "useMaxWidth") { config, value in
        guard let v = value.bool else { return false }
        config.useMaxWidth = v
        return true
    }
]
```

### D3. Shape geometry is duplicated across layout, CG, and SVG

Evidence:

- Flow layout estimates shape sizes in `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:78-163`.
- CG shape paths are selected in `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91-197`.
- SVG node shapes are selected in `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:583-719`.
- Many shape-specific constants are independently encoded, for example cylinder radius in `ShapeRenderer.swift:123-126` and `src_renderer.swift:785-794`, title header heights in `ShapeRenderer.swift:614-664` and `src_renderer.swift:847-862`, and parallelogram/trapezoid skew ratios in `ShapeRenderer.swift:239-280` and `src_renderer.swift:809-893`.

Impact:

Adding or correcting a shape requires at least three changes. Layout can size a shape differently than CG or SVG draws it, causing clipping, label drift, or snapshot divergence.

Reuse opportunity:

Define a canonical `ShapeSpec` that owns sizing adjustments and normalized geometry. Renderers can convert the same spec into `CGPath` or SVG path data.

Illustrative refactoring:

```swift
struct ShapeSpec {
    var aliases: Set<String>
    var minimumSize: CGSize
    var sizeAdjustment: (CGSize, RenderConfig) -> CGSize
    var path: (CGRect, RenderConfig) -> ShapePath
}

enum ShapePath {
    case rect(cornerRadius: CGFloat)
    case ellipse
    case polygon([CGPoint])
    case path(CGPath)
}
```

### D4. Edge and arrow rendering logic is duplicated

Evidence:

- CG edge curve construction lives in `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:51-77`.
- SVG edge curve construction lives in `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:426-463`.
- CG arrowheads are drawn in `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:125-192`.
- SVG arrow marker definitions are assembled in `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:181-260`.
- `Sources/BeautifulMermaidSwift/Render/ArrowRenderer.swift:4-49` defines a separate public arrow path helper, but `rg` found no usages outside its own declaration.

Impact:

Curve support and arrow semantics can drift between image and SVG output. The unused `ArrowRenderer` suggests an intended abstraction exists but is not integrated.

Reuse opportunity:

Use a shared edge geometry service that emits logical path commands and arrowhead shapes. CG can convert commands into `CGPath`; SVG can serialize them.

Illustrative refactoring:

```swift
enum PathCommand {
    case move(CGPoint)
    case line(CGPoint)
    case cubic(CGPoint, CGPoint, CGPoint)
}

enum EdgePathBuilder {
    static func commands(points: [CGPoint], curveType: String?) -> [PathCommand] { ... }
    static func arrow(style: ArrowHead, size: CGSize) -> ShapePath { ... }
}
```

### D5. XML/SVG escaping is repeated and inconsistent

Evidence:

- A central XML escape helper exists at `Sources/BeautifulMermaidSwift/Mermaid/src_multiline_utils.swift:45-52`.
- Additional escape helpers are defined at `src_requirement_svg.swift:342`, `src_sequence_renderer.swift:538-546`, `src_timeline_renderer.swift:273-280`, `src_xychart_renderer.swift:589-595`, `src_radar_svg.swift:145`, `src_gantt_renderer.swift:195`, `src_quadrant_renderer.swift:106`, `src_architecture_renderer.swift:312`, `src_pie_renderer.swift:149`, `src_venn_svg.swift:300-305`, `src_kanban_renderer.swift:307`, `src_treemap_svg.swift:164`, `src_class_renderer.swift:501`, and `src_renderer.swift:1256`.
- Apostrophe handling differs: timeline uses `&#39;` at `src_timeline_renderer.swift:279`, venn uses `&apos;` at `src_venn_svg.swift:305`, XY chart omits apostrophe escaping at `src_xychart_renderer.swift:589-595`, and block renderer omits apostrophe escaping at `src_block_renderer.swift:444-450`.

Impact:

Inconsistent escaping is both a maintainability problem and a correctness risk for SVG attributes, data attributes, and embedded text. It is easy to apply a text escaping helper in an attribute context or vice versa.

Reuse opportunity:

Create a tiny `SVG` utility with explicit text and attribute functions, then delete per-renderer variants.

Illustrative refactoring:

```swift
enum SVG {
    static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ value: String) -> String {
        escapeText(value)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
```

### D6. SVG rendering duplicates parse-layout-render pipelines rather than reusing `MermaidPipeline`

Evidence:

- `MermaidPipeline.renderSVG(source:theme:)` delegates to `MermaidImageRenderer.renderSVGSync` at `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:58-65`.
- `MermaidImageRenderer.renderSVGSync` builds options and calls `_renderMermaidSVG` at `Sources/BeautifulMermaidSwift/ImageRenderer.swift:97-113`.
- `_renderMermaidSVG` performs its own preprocessing and routing at `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:283-362`.
- The per-diagram SVG cases then parse and layout again in local case functions, for example sequence at `src_index.swift:375-379`, class at `src_index.swift:381-385`, ER at `src_index.swift:387-390`, flowchart at `src_index.swift:457-460`, and many more through `src_index.swift:692-696`.

Impact:

The SVG path is a parallel pipeline rather than a renderer behind the canonical parse/layout pipeline. It duplicates frontmatter handling, line splitting, type detection, config merging, and parse/layout calls. This is a major source of drift between image and SVG behavior.

Reuse opportunity:

Make `renderSVG` follow the same staged pipeline as `prepare`:

```swift
public static func renderSVG(source: String, theme: DiagramTheme = .default) throws -> String {
    try runPipeline(operation: "MermaidPipeline.renderSVG") {
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        return try SVGDiagramRenderer(theme: theme).render(positioned)
    }
}
```

For diagram families that still require specialized SVG renderers, dispatch from `PositionedContent` rather than reparsing source.

### D7. Image context setup duplicates platform-specific rendering code

Evidence:

- `Sources/BeautifulMermaidSwift/ImageRenderer.swift:147-197` creates a bitmap/native image for natural diagram bounds.
- `Sources/BeautifulMermaidSwift/ImageRenderer.swift:200-267` repeats the same UIKit/AppKit context creation, background fill, AppKit y-axis flip, scaling, and translation for fitted output.

Impact:

Small platform fixes must be made in two methods. The duplication is localized and lower risk than the routing/frontmatter issues, but it is still an obvious helper extraction.

Reuse opportunity:

Extract a single platform image context helper that accepts a render transform closure.

Illustrative refactoring:

```swift
@MainActor
private func renderBitmap(
    size: CGSize,
    scale: CGFloat,
    draw: (CGContext) -> Void
) -> BMImage? {
    // Own UIKit/AppKit context creation and y-axis normalization here.
}
```

### D8. Acceptable repetition

Not all repetition should be removed:

- Separate per-diagram parser, layout, and renderer files are appropriate because Mermaid diagram grammars and visual models differ substantially.
- Snapshot tests across SVG, image, and ASCII paths are intentionally repetitive because they protect against visual regressions.
- Type-safe payload and positioned content enums are worth keeping because they make cross-module contracts explicit.

The refactoring goal should be to remove duplicated routing, binding, escaping, and geometry decisions, not to force every diagram family into one generic renderer.

## Prioritized Refactoring Roadmap

### Priority 1: Establish a canonical diagram registry

Impact: Very high maintainability and scalability.

Targets:

- `Sources/BeautifulMermaidSwift/Parser.swift:20-250`
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:119-207`
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:295-362`
- `Sources/BeautifulMermaidSwift/Layout.swift:10-358`
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:37-92`

Outcome:

One descriptor list owns header detection and high-level parse/layout/render routing. Adding a diagram becomes a descriptor addition plus per-diagram implementation, not a hunt through multiple switches.

### Priority 2: Split frontmatter and init directive binding

Impact: Very high developer productivity and correctness.

Targets:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:179-281`
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:317-838`
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1044-1992`

Outcome:

Per-diagram config and theme binding becomes isolated, testable, and reusable across YAML frontmatter and JSON init directives.

### Priority 3: Remove reflection from flow SVG rendering

Impact: High maintainability and safety.

Targets:

- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:1264-1424`

Outcome:

SVG flow rendering returns to compile-time type safety and no longer depends on field-name reflection.

### Priority 4: Centralize SVG escaping and document construction

Impact: High correctness, medium implementation cost.

Targets:

- `Sources/BeautifulMermaidSwift/Mermaid/src_multiline_utils.swift:45-52`
- Renderer-local escape functions listed in D5.
- SVG wrapper construction in `src_renderer.swift`, `src_sequence_renderer.swift`, `src_er_renderer.swift`, `src_treemap_svg.swift`, `src_architecture_renderer.swift`, `src_kanban_renderer.swift`, and related files.

Outcome:

Consistent text/attribute escaping, accessibility tags, transparency behavior, style blocks, and defs management across all SVG renderers.

### Priority 5: Consolidate shape and edge geometry

Impact: High visual consistency, medium-to-high implementation cost.

Targets:

- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:78-163`
- `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91-197`
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:583-719`
- `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:51-192`
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:181-260` and `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:426-463`
- `Sources/BeautifulMermaidSwift/Render/ArrowRenderer.swift:4-49`

Outcome:

One canonical shape/edge model feeds layout, CG, and SVG renderers. Snapshot drift becomes easier to diagnose because geometry decisions live in one abstraction.

### Priority 6: Tighten public API boundaries

Impact: Medium-to-high long-term maintainability.

Targets:

- Public facade in `Sources/BeautifulMermaidSwift/BeautifulMermaid.swift:25-110`
- Port namespaces and lower-level public functions throughout `Sources/BeautifulMermaidSwift/Mermaid`

Outcome:

Consumers see a stable Swift API; implementation details can be refactored without preserving accidental JS-port symbols forever.

### Priority 7: Normalize pipeline entry-point setup

Impact: Medium correctness, low implementation cost.

Targets:

- `Sources/BeautifulMermaidSwift/MermaidPipeline.swift:12-15`
- `Sources/BeautifulMermaidSwift/ImageRenderer.swift:33-39`

Outcome:

Every public and internal pipeline path uses the same font-registration and issue-reporting boundary.

### Priority 8: Extract image context setup

Impact: Low-to-medium maintainability, low implementation cost.

Targets:

- `Sources/BeautifulMermaidSwift/ImageRenderer.swift:147-267`

Outcome:

Platform image rendering has one place for AppKit/UIKit fixes, y-axis normalization, background fill, and scale handling.

