# Code Quality Audit

Date: 2026-05-09  
Scope: `Sources/BeautifulMermaidSwift` structural design, maintainability, abstraction efficacy, pattern consistency, duplication, and reuse potential.

## Executive Summary

The codebase has a sound high-level architecture: a public async facade, a synchronous pipeline boundary, type-safe parsed and positioned payload enums, and clear separation between parsing, layout, image rendering, SVG rendering, and ASCII rendering. That foundation is maintainable and appropriate for a native Swift port of a broad Mermaid surface.

Structural health is currently **moderate**. The main maintainability risk is not absence of abstraction, but **partial adoption of abstractions that were clearly introduced to reduce drift**. `DiagramRegistry`, `MermaidSourceNormalizer`, `FrontmatterBinding`, `ShapeSpecRegistry`, `RenderTokens`, and `EdgePathBuilder` exist, but several hot paths still use older parallel switch statements and local helpers. As a result, adding or changing one diagram type requires edits across multiple registries, renderers, and parsing paths.

Quantitatively, the package contains roughly **82,482 Swift source lines** under `Sources/BeautifulMermaidSwift`. The current structure includes **27 Core Graphics diagram renderer extensions**, **26 SVG renderer files**, **26 parser files**, and **26 layout files**. Some repetition is acceptable because this is a JS port with many independent diagram grammars, but several forms of duplication are now redundant because central abstractions already exist.

Highest-impact issues:

1. `DiagramRegistry` owns parse and layout closures, but `GraphLayout` still repeats layout dispatch and SVG still reparses per diagram type. This creates direct behavior drift, including state config forwarding differences.
2. `SourcePreprocessing.swift` is a 2,039-line "God object" combining source splitting, frontmatter parsing, JSON init handling, config binding, theme binding, and YAML parsing.
3. `ShapeSpecRegistry` and `EdgePathBuilder` are effectively unused despite comments declaring them the shared geometry contract. CG and SVG still carry independent shape and curve implementations.
4. Source normalization, raw line splitting, hex color parsing, and frontmatter binding have multiple parallel implementations.

## Abstraction Analysis

### A1. `DiagramRegistry` is underused as the canonical diagram dispatcher

Evidence:

- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:37` defines a descriptor for one diagram family.
- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:49` stores the parse closure.
- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:52` stores the layout closure.
- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:69` states that `DiagramRegistry` is the canonical routing source.
- `Sources/BeautifulMermaidSwift/Parser.swift:26` and `Sources/BeautifulMermaidSwift/Parser.swift:28` correctly delegate parse routing through the registry.
- `Sources/BeautifulMermaidSwift/Layout.swift:13` through `Sources/BeautifulMermaidSwift/Layout.swift:135` still performs a full manual layout switch over every `DiagramPayload`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:80` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:151` introduces a second routing enum and maps `DiagramType` to it.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:240` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:307` repeats a full SVG switch.

Negative impact:

The registry has not become the single source of truth. Adding a diagram family still requires edits in the type enum, payload enum, registry, layout switch, CG renderer switch, SVG routing enum, and SVG switch. That increases cognitive load and makes behavior drift likely.

There is already a concrete drift risk: `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:403` forwards both `flowchartConfig` and `stateConfig` into `parseMermaid`, while `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:726` and `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:745` forward only `flowchartConfig`. State diagrams parsed through image/layout paths can therefore diverge from SVG behavior.

Recommendation:

Make `DiagramRegistry` the dispatch boundary for layout as well as parse. Add descriptor lookup by `DiagramType`, then replace `GraphLayout.layout` with descriptor delegation.

Illustrative refactor:

```swift
extension DiagramRegistry {
    static func descriptor(for type: DiagramType) throws -> DiagramDescriptor {
        guard let descriptor = all.first(where: { $0.type == type }) else {
            throw MermaidStructuralError.payloadMismatch(type)
        }
        return descriptor
    }
}

public struct GraphLayout {
    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "GraphLayout.layout") {
            let descriptor = try DiagramRegistry.descriptor(for: graph.type)
            return try descriptor.layout(graph, config)
        }
    }
}
```

Then make SVG routing consume the parsed graph produced by the descriptor where possible, rather than reparsing in each `_render<Type>SvgCase`.

### A2. `SourcePreprocessing.swift` is an overburdened preprocessing God object

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:6` exposes top-level preprocessing.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:21` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:70` implements statement splitting.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:74` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:127` handles frontmatter stripping.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:129` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:194` handles Mermaid init directives.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:446` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:527` declares state for almost every diagram family's config and theme.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:537` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:572` uses a cascading apply chain for diagram-specific frontmatter.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1348` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1394` finalizes all accumulated frontmatter sections.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1399` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:2039` contains many diagram-specific theme helpers.

Negative impact:

This file owns too many axes of change. A developer adding a single theme variable for one diagram must reason about YAML flattening, JSON init parsing, config accumulation, finalization, global options, and every other diagram's theme keys. That creates merge pressure and makes local changes risky.

Recommendation:

Split responsibilities into small units:

- `SourceDirectiveScanner`: detects and removes YAML fences and init directives.
- `MermaidStatementSplitter`: owns quote-aware splitting.
- `YamlFrontmatterParser`: converts YAML-like lines into `(path, FrontmatterValue)` pairs only.
- `FrontmatterBindingRegistry`: commits typed config/theme bindings.
- Per-diagram `FrontmatterBinding+<Type>.swift` files: own all config and theme keys for one diagram family.

Illustrative refactor:

```swift
struct FrontmatterBindingRegistry {
    static func apply(
        pairs: [(path: String, value: FrontmatterValue)],
        to frontmatter: inout DiagramFrontmatter
    ) {
        var bindings: [any FrontmatterBinding] = [
            SequenceFrontmatterBinding(),
            RequirementFrontmatterBinding(),
            RadarFrontmatterBinding(),
            // ...
        ]

        for pair in pairs {
            for index in bindings.indices {
                _ = bindings[index].apply(path: pair.path, value: pair.value)
            }
        }

        for binding in bindings {
            binding.commit(into: &frontmatter)
        }
    }
}
```

### A3. `FrontmatterBinding` exists, but YAML does not use it

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding.swift:39` through `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding.swift:40` states that bindings are used by both YAML frontmatter and JSON init directives.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:178` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:193` applies bindings only for JSON init directives.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:411` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:413` routes YAML through `_StackSafeYamlFrontmatterParser`.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:729` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:760` duplicates sequence config binding inline.
- `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding+Sequence.swift:13` through `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding+Sequence.swift:87` implements the same sequence config binding as a reusable abstraction.

Negative impact:

YAML and JSON init directives can drift in supported keys, conversion rules, and defaults. Developers also have to update both `SourcePreprocessing.swift` and a `FrontmatterBinding+*.swift` file for the same semantic option.

Recommendation:

Make `_parseYamlFrontmatter` flatten YAML into the same pair representation used by init directives, then invoke the binding registry. Keep only global shared options in one shared binding.

Illustrative refactor:

```swift
func _parseYamlFrontmatter(_ lines: [String]) -> DiagramFrontmatter? {
    let entries = _flattenYamlFrontmatterLines(lines)
    guard !entries.isEmpty else { return nil }

    var frontmatter = DiagramFrontmatter()
    let pairs = entries.map {
        (path: $0.path, value: FrontmatterValue(raw: $0.value))
    }

    FrontmatterBindingRegistry.apply(pairs: pairs, to: &frontmatter)
    return frontmatter
}
```

### A4. Shape and edge geometry abstractions exist but are bypassed

Evidence:

- `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:8` through `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:11` declares `ShapeSpec` as the single source of truth for shape sizing and paths.
- `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:75` through `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:83` defines a shape registry.
- `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91` through `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:197` still uses a large shape switch for CG paths.
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:583` through `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:719` still uses a separate large shape switch for SVG paths.
- `Sources/BeautifulMermaidSwift/Render/EdgePathBuilder.swift:31` through `Sources/BeautifulMermaidSwift/Render/EdgePathBuilder.swift:33` says CG and SVG consume shared path commands.
- `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:51` through `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:77` implements CG curve path building independently.
- `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:426` through `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:464` implements SVG curve path building independently.

Negative impact:

The codebase has a declared geometry abstraction, but production code still relies on duplicated renderer-specific switches. That undermines the abstraction and leaves shape additions prone to CG/SVG drift.

There is also a concrete naming bug risk in `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1774` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1818`: the clipping code compares strings such as `"stateStart"`, `"stateEnd"`, `"stateFork"`, and `"stateChoice"`, while `NodeShape` raw values use kebab case at `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:28` through `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:31`, and renderers check `"state-start"` at `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:15` and `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:618`.

Recommendation:

Use `ShapeSpecRegistry` and `EdgePathBuilder` in both render paths. Keep shape aliases in one model and serialize that model to CG or SVG.

Illustrative refactor:

```swift
public struct ShapeDrawing {
    let path: ShapePath
    let details: [ShapePath]
}

extension NodeShapeRenderer {
    func shapePath(for shape: String, in bounds: CGRect) -> CGPath {
        let spec = ShapeSpecRegistry.spec(for: shape)
        return CGPathRenderer.makePath(spec.path(bounds, config))
    }
}

extension EdgeRenderer {
    func buildCurvedPath(points: [CGPoint], curveType: String?) -> CGPath {
        CGPathRenderer.makePath(EdgePathBuilder.commands(points: points, curveType: curveType))
    }
}
```

### A5. `src_layout.swift` is too broad and too weakly typed

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:8` defines `_ElkNode` as `[String: Any]`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:78` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:163` performs node sizing.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:165` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:230` builds ELK graph dictionaries.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:799` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:850` performs edge bundling.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1104` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1160` extracts positioned graph data.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1357` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1405` owns public layout entry points and fallback behavior.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1701` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1838` owns shape clipping.
- `Sources/BeautifulMermaidSwift/Mermaid/src_elk_instance.swift:4` repeats `LayoutNode = [String: Any]`, and `Sources/BeautifulMermaidSwift/Mermaid/src_elk_instance.swift:45` through `Sources/BeautifulMermaidSwift/Mermaid/src_elk_instance.swift:112` reparses typed values out of dictionaries.

Negative impact:

Flowchart layout combines graph construction, layout configuration, engine adaptation, post-processing, edge routing, shape clipping, and extraction into one large module. The `[String: Any]` boundary means structural errors are discovered late and often silently defaulted.

Recommendation:

Introduce typed ELK adapter models and split the file along pipeline boundaries.

Illustrative refactor:

```swift
struct ElkGraph: Sendable {
    var id: String
    var children: [ElkNode]
    var edges: [ElkEdge]
    var layoutOptions: ElkLayoutOptions
}

enum FlowLayout {
    static func buildElkGraph(from graph: ParsedGraphModel, config: LayoutConfig) -> ElkGraph
    static func extractPositionedGraph(from laidOut: ElkGraph, source: ParsedGraphModel) -> PositionedGraph
}
```

## Pattern Consistency Review

### P1. Worker-thread policy is duplicated outside the public facade

Evidence:

- `Sources/BeautifulMermaidSwift/BeautifulMermaid.swift:112` through `Sources/BeautifulMermaidSwift/BeautifulMermaid.swift:139` documents and implements the canonical 8 MB stack worker thread.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:604` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:618` implements a second SVG-specific worker thread helper.

Negative impact:

The project has a critical architectural constraint around worker thread stack size. Duplicating that helper weakens the constraint by creating two places to update naming, stack size, cancellation behavior, instrumentation, and future profiling hooks.

Recommendation:

Route all async SVG free functions through `MermaidRenderer._runOnWorker`, or move the helper to a single internal `MermaidWorkerExecutor`.

Illustrative refactor:

```swift
public func renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await MermaidRenderer._runOnWorker {
        try MermaidPipeline.renderSVG(text, options: options)
    }
}
```

### P2. Font routing is not consistently centralized

Evidence:

- `Sources/BeautifulMermaidSwift/Render/RenderTokens.swift:10` through `Sources/BeautifulMermaidSwift/Render/RenderTokens.swift:12` instructs SVG renderers to derive font families through `RenderTokens`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_zenuml_renderer.swift:10` defaults ZenUML SVG to `"Helvetica"`.
- `Sources/BeautifulMermaidSwift/Mermaid/src_zenuml_renderer.swift:104` through `Sources/BeautifulMermaidSwift/Mermaid/src_zenuml_renderer.swift:121` hardcodes `Helvetica, Verdana, serif` in CSS classes.
- `Sources/BeautifulMermaidSwift/Mermaid/src_eventmodeling_layout.swift:22` hardcodes a CSS font-family string.
- `Sources/BeautifulMermaidSwift/Mermaid/src_eventmodeling_layout.swift:393` creates a `CTFont` with `"TrebuchetMS"` directly.

Negative impact:

Fonts are central to snapshot determinism in this project. Hardcoded fonts can cause platform drift and make it harder to reason about which diagrams honor `RenderConfig.defaultFontFamily` or `RenderConfig.defaultProportionalFontFamily`.

Recommendation:

Use `RenderTokens` or `RenderConfig` at every layout and SVG font boundary. If a Mermaid-specific fallback is required, isolate it behind a resolver instead of embedding it in layout/render bodies.

Illustrative refactor:

```swift
struct DiagramFontResolver {
    let tokens: RenderTokens

    func eventModelingFont(size: CGFloat) -> CTFont {
        let family = tokens.config.defaultProportionalFontFamily ?? "TrebuchetMS"
        return CTFontCreateWithName(family as CFString, size, nil)
    }
}
```

### P3. Shape identity is stringly typed and inconsistent

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:15` through `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:83` defines `NodeShape` as a typed enum.
- `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:84` through `Sources/BeautifulMermaidSwift/Mermaid/src_types.swift:130` defines alias resolution.
- `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:182` through `Sources/BeautifulMermaidSwift/Render/ShapeSpec.swift:295` defines another alias/spec registry for the same shapes.
- `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1774` through `Sources/BeautifulMermaidSwift/Mermaid/src_layout.swift:1818` compares shape names with raw strings.
- `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91` through `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:197` repeats shape-name switches with raw strings.

Negative impact:

Shape semantics are distributed across at least three representations. This directly creates misspellings and naming mismatches, and it makes a new shape a multi-file, multi-switch change.

Recommendation:

Carry `NodeShape` or a `ShapeIdentifier` through positioned payloads instead of `String`, and let `ShapeSpecRegistry` be the single alias registry.

Illustrative refactor:

```swift
public struct PositionedNodeShape: Sendable, Equatable {
    public var rawName: String
    public var resolved: original_src_types.NodeShape?
}
```

### P4. `MermaidSourceNormalizer` is incomplete and coexists with older splitters

Evidence:

- `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:3` through `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:5` says it replaces duplicated splitting logic.
- `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:25` and `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:41` expose `stripFrontmatter` parameters that are currently unused.
- `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:51` through `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:55` declares multiline joining but returns the source unchanged.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:21` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:63` retains a separate quote-aware splitter.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:158` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:214` retains another quote-aware splitter.
- `Sources/BeautifulMermaidSwift/Parser.swift:4` through `Sources/BeautifulMermaidSwift/Parser.swift:18` contains unused parser-local line helpers.

Negative impact:

The normalizer reads as canonical, but behavior still depends on which path a parser or renderer calls. Stubbed parameters and duplicate splitters increase the risk that escaping, multiline labels, comments, or frontmatter stripping behave differently across diagram types.

Recommendation:

Make `MermaidSourceNormalizer` the only source splitting API, implement or remove `stripFrontmatter`, and delete local splitting helpers once call sites are migrated.

Illustrative refactor:

```swift
public enum MermaidSourceNormalizer {
    public static func statements(
        _ source: String,
        separators: CharacterSet = CharacterSet(charactersIn: "\n;")
    ) -> [String] {
        splitQuoteAware(_joinMultiLineBlocks(source), separators: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }
}
```

### P5. Registry validation exists but is not enforced by tests

Evidence:

- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:120` through `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:145` defines `DiagramRegistry.validate()`.
- A repository search found references to `DiagramRegistry` only in `Parser.swift`, `src_index.swift`, and `DiagramDescriptor.swift`; no test currently calls `validate()`.

Negative impact:

The registry can drift from `DiagramType.allCases` without a failing test. Because the registry is order-sensitive, missing descriptors and ordering mistakes should be caught immediately.

Recommendation:

Add a small unit test that asserts `DiagramRegistry.validate()` and verifies that registered types match `DiagramType.allCases`.

Illustrative test:

```swift
func testDiagramRegistryCoversAllDiagramTypes() {
    XCTAssertTrue(DiagramRegistry.validate())
    XCTAssertEqual(
        Set(DiagramRegistry.all.map(\.type)),
        Set(DiagramType.allCases)
    )
}
```

## Duplication and Reuse Audit

### D1. Diagram dispatch is repeated across parse, layout, CG render, and SVG render

Evidence and quantification:

- `Sources/BeautifulMermaidSwift/Types.swift:4` through `Sources/BeautifulMermaidSwift/Types.swift:33` defines 28 diagram types.
- `Sources/BeautifulMermaidSwift/Types.swift:39` through `Sources/BeautifulMermaidSwift/Types.swift:67` repeats those as parsed payload cases.
- `Sources/BeautifulMermaidSwift/Types.swift:233` through `Sources/BeautifulMermaidSwift/Types.swift:297` repeats those as positioned content cases.
- `Sources/BeautifulMermaidSwift/Layout.swift:13` through `Sources/BeautifulMermaidSwift/Layout.swift:135` repeats layout dispatch.
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:37` through `Sources/BeautifulMermaidSwift/Render/DiagramRenderer.swift:92` repeats CG render dispatch.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:119` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:151` repeats diagram type mapping.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:252` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:307` repeats SVG render dispatch.

Assessment:

Some repetition is acceptable for type-safe enums. The problematic duplication is the behavioral dispatch in `Layout.swift` and `src_index.swift`, because `DiagramDescriptor` already contains parse and layout closures.

Reuse opportunity:

Use `DiagramRegistry` for parse and layout. Introduce `SvgRendererRegistry` for rendering `PositionedContent` to SVG so `src_index.swift` does not own parse and layout again.

Illustrative direction:

```swift
struct SvgRendererDescriptor {
    let type: DiagramType
    let render: (PositionedGraph, DiagramColors, String, Bool) throws -> String
}
```

### D2. Statement and raw-line splitting are duplicated

Evidence and quantification:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:21` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:63` implements quote-aware splitting.
- `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:59` through `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:106` implements another quote-aware splitter.
- `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:158` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:214` implements a third quote-aware splitter.
- `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:23` through `Sources/BeautifulMermaidSwift/DiagramDescriptor.swift:31`, `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:11` through `Sources/BeautifulMermaidSwift/Mermaid/MermaidSourceNormalizer.swift:17`, and `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:580` through `Sources/BeautifulMermaidSwift/Mermaid/src_index.swift:586` each normalize raw lines.

Assessment:

This is genuine redundancy. The codebase already has a normalizer abstraction, so behavior should not be copied into individual parser or renderer paths.

Reuse opportunity:

Consolidate raw-line and statement splitting into `MermaidSourceNormalizer`; keep private helpers only inside that type.

### D3. Frontmatter config and theme binding is duplicated

Evidence and quantification:

- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift` contains **68** apply/theme helper declarations matching `apply*`, `_is*Theme*`, `_apply*Theme*`, and related config helper patterns.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:446` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:527` stores per-diagram config/theme state centrally.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:729` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:760` duplicates sequence binding.
- `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding+Sequence.swift:13` through `Sources/BeautifulMermaidSwift/Mermaid/FrontmatterBinding+Sequence.swift:87` provides the reusable sequence binding.
- `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:1399` through `Sources/BeautifulMermaidSwift/Mermaid/SourcePreprocessing.swift:2039` contains many theme key recognizers and appliers.

Assessment:

This is genuine redundancy, not acceptable repetition. The binding abstraction exists and should absorb both YAML and init directive paths.

Reuse opportunity:

Move each diagram's YAML and JSON key handling into its `FrontmatterBinding+<Type>.swift` file. Keep `SourcePreprocessing.swift` limited to scanning and producing normalized key/value pairs.

### D4. Shape and edge geometry are duplicated across CG and SVG

Evidence and quantification:

- There are **27** `Render/DiagramRenderer+*.swift` CG renderer files.
- There are **26** `Mermaid/src_*_renderer.swift` or `Mermaid/src_*_svg.swift` SVG renderer files.
- `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:91` through `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift:197` and `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:583` through `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:719` duplicate node shape dispatch.
- `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:51` through `Sources/BeautifulMermaidSwift/Render/EdgeRenderer.swift:96` and `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:426` through `Sources/BeautifulMermaidSwift/Mermaid/src_renderer.swift:464` duplicate curve interpolation.

Assessment:

Two independent renderers are an explicit project constraint today, so complete renderer duplication is currently acceptable. The **geometry duplication inside shared concepts** is not acceptable because `ShapeSpecRegistry` and `EdgePathBuilder` already exist to reduce that drift.

Reuse opportunity:

Start with shared edges and flowchart/state shapes, where the shape and curve surface is largest. Do not attempt a full renderer unification first.

### D5. Hex color parsing is duplicated in renderer extensions

Evidence:

- `Sources/BeautifulMermaidSwift/CrossPlatform.swift:104` through `Sources/BeautifulMermaidSwift/CrossPlatform.swift:137` defines `BMColor(hex:)`.
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Journey.swift:248` through `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Journey.swift:261` implements a local hex-to-`CGColor` parser.
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Gantt.swift:266` through `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Gantt.swift:279` implements the same parser.
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Timeline.swift:195` through `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Timeline.swift:208` implements a third variant.
- `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Sequence.swift:585` through `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+Sequence.swift:604` implements a CSS color parser that only handles `transparent` and `rgb/rgba`.

Assessment:

This is genuine redundancy. Local parsers differ in supported input, invalid-input behavior, and alpha support.

Reuse opportunity:

Introduce one optional parser that returns `BMColor?` and supports the required CSS subset. Use `BMColor(hex:)` for validated hex strings but avoid defaulting invalid optional inputs to black.

Illustrative refactor:

```swift
enum MermaidColorParser {
    static func color(_ value: String) -> BMColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "transparent" {
            return BMColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        if trimmed.hasPrefix("#"), isValidHex(trimmed) {
            return BMColor(hex: trimmed)
        }
        return parseRGBFunction(trimmed)
    }
}
```

## Prioritized Refactoring Roadmap

### 1. Complete `DiagramRegistry` adoption

Impact: Very high  
Effort: Medium  
Priority rationale: This reduces the number of files touched for every diagram addition and fixes current parse/layout drift.

Actions:

1. Add `DiagramRegistry.descriptor(for:)`.
2. Replace `GraphLayout.layout` switch with descriptor delegation.
3. Fix flowchart/state descriptor parsing to forward `stateConfig` consistently.
4. Add registry coverage tests.

### 2. Route YAML frontmatter through `FrontmatterBinding`

Impact: Very high  
Effort: Medium to high  
Priority rationale: Frontmatter is currently one of the highest-change surfaces, and duplicated YAML/init semantics will continue to drift.

Actions:

1. Convert YAML entries to `FrontmatterValue` pairs.
2. Apply existing bindings from YAML and init directives.
3. Move remaining diagram-specific helpers out of `SourcePreprocessing.swift`.
4. Add tests that assert YAML and init directives produce the same `DiagramFrontmatter`.

### 3. Consolidate source normalization

Impact: High  
Effort: Low to medium  
Priority rationale: Three quote-aware splitters are unnecessary and make parser behavior hard to reason about.

Actions:

1. Make `MermaidSourceNormalizer` the sole splitter.
2. Implement or remove `stripFrontmatter`.
3. Delete parser-local and SVG-local splitters.
4. Add focused tests for semicolons, quotes, comments, CRLF, and multiline labels.

### 4. Adopt `ShapeSpecRegistry` and `EdgePathBuilder` in flowchart/state rendering

Impact: High  
Effort: Medium  
Priority rationale: Flowchart/state diagrams have the broadest shape and edge surface and currently show concrete shape-name drift.

Actions:

1. Change positioned node shape handling to use a typed shape identifier.
2. Update `NodeShapeRenderer` to consume `ShapeSpecRegistry`.
3. Update SVG flowchart renderer to serialize `ShapePath`.
4. Update `EdgeRenderer` and SVG edge rendering to consume `EdgePathBuilder`.

### 5. Split `src_layout.swift` into typed layout components

Impact: High  
Effort: High  
Priority rationale: This is a large, risky file with weak type boundaries. It should be split after registry and shape abstractions reduce surrounding churn.

Actions:

1. Introduce typed ELK adapter models.
2. Extract node sizing into a `FlowNodeSizer`.
3. Extract ELK graph construction.
4. Extract positioned graph extraction.
5. Extract shape clipping and edge post-processing.

### 6. Centralize font and color utilities

Impact: Medium  
Effort: Low to medium  
Priority rationale: This improves snapshot determinism and removes small but recurring renderer inconsistencies.

Actions:

1. Create `DiagramFontResolver` over `RenderConfig`/`RenderTokens`.
2. Replace hardcoded SVG CSS font families where feasible.
3. Create `MermaidColorParser`.
4. Remove local `_hexToCGColor`, `_thexToCGColor`, and equivalent helpers.

### 7. Treat full CG/SVG renderer unification as a later strategic project

Impact: Very high  
Effort: Very high  
Priority rationale: The two-renderer architecture is explicitly acknowledged and snapshot-guarded. Immediate value is better achieved by centralizing shared geometry, fonts, colors, and dispatch before attempting a full render backend unification.

Actions:

1. Continue using snapshot tests to guard current dual renderers.
2. Move shared primitives first.
3. Reassess full renderer unification once shared shape and edge infrastructure is in production use.
