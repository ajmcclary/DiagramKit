# Code Quality Audit

## Executive Summary

DiagramKit has a sound architectural spine: layered SwiftPM targets, typed parse and layout payloads, a centralized public pipeline, strict-concurrency gates, and strong snapshot coverage. The package is structurally healthier than a typical large language port because recent work has already introduced better seams such as `DiagramRegistry`, `MermaidSourceNormalizer`, `FrontmatterBinding`, `ShapeSpecRegistry`, `EdgePathBuilder`, `SVGDocumentBuilder`, and shared worker-thread documentation.

The maintainability risk is concentrated rather than diffuse. Current source size is 257 Swift files and 84,786 source lines, with `Sources/DiagramKitModel` holding 199 files and 70,684 lines. The file-size gate currently reports 56 warning-band files and 11 allowlisted >1000-line JS-port files. Most of that size is acceptable upstream-port mass, but several non-port abstractions are now carrying too much responsibility or are only partially adopted.

Overall structural health: **yellow-green**. The target layering and typed domain model are strong. The main liabilities are duplicated routing between parse/SVG/ASCII paths, duplicated worker and bitmap preparation logic in the view layer, a cross-cutting `DiagramFrontmatter` bag embedded in a class parser file, partial adoption of shape and font abstractions, and duplicated frontmatter/theme binding code. These issues do not require a rewrite. They call for a focused consolidation pass around existing abstractions.

## Completion Status — 2026-05-11

| Item | Status | Notes |
|---|---|---|
| **A1** Worker-thread invariant | ✅ Done | `bbe256a` `601f4b4` `97dfdce` `64c73dc` `15d87cd` |
| **A2** Registry split | ✅ Done | `741e212` `33c61c2` |
| **A3** `DiagramFrontmatter` move | ✅ Done | `b308aa6` |
| **A4** Shape abstraction | ✅ Done | All 4 consumer switches migrated: `ShapeRenderer.shapePath` + `_drawSpecDecorations`, SVG `_renderNodeShapeGeneric`, `EdgeShapeClipper` (`_clipPoint` now ShapePath-keyed). 27 `ShapePath` cases with full `CGPathRenderer` + `SVGPathSerializer` coverage; all `_defaultSpec` entries replaced with explicit paths + `ShapeDecoration`. **Title-header shapes (rounded-with-title, rect-with-title) and simple foreground-fill shapes (state-start, fork, join, filled-circle) now use spec-driven decorations + fill/stroke overrides.** Remaining position-dependent special cases: state-end, state-divider (~25 lines each renderer). |
| **A5** Font / token split | ✅ Done | Three-way decomposition landed: `RenderTokens` (35+ stored properties, 3 per-diagram extensions), `DiagramFontResolver` (all font resolution consolidated — 12 methods across 4 files merged into one struct), `TextMetrics` (text measurement extracted). `RenderConfig` now composes all three with backward-compatible forwarding.  ~28 CG renderer files migrated; CG-layer `DiagramFontResolver` deprecated. |
| **P1** Routing collapse | ✅ Done | `0a42b8a` `4c3d386` |
| **P1** Font drift | ✅ Done | bundled into A5 commits above |
| **P2** Config & registry split | ✅ Done | `b308aa6` `7c44419` `741e212` `33c61c2` |
| **P2** Shape adoption | ✅ Done | Same as A4 |
| **P2** Frontmatter bindings | ✅ Done | `7c44419` `6621c67` `eed339a` |
| **P3** View target alignment | ✅ Done | `bf1dc59` `86aba45` `047adbb` `b70dc61` |
| **P3** Bitmap rendering | ✅ Done | `31e6882` |
| **P4** Naming hygiene | ➖ Open | Low priority — `original_src_*` namespace acceptable as compatibility seam; flag if it spreads to new abstractions |
| **D1** SVG case parse/layout dedup | ✅ Done | `_renderXYChartSvgCase`, `_renderQuadrantSvgCase`, `_renderSankeySvgCase`, `_renderRadarSvgCase` now delegate parse/layout/frontmatter to `DiagramRegistry` descriptors. Hardcoded `"sankey-1"` ID replaced with `StableID.derive`. ~25 snapshot rebakes expected. |
| **D2** CG/SVG renderer drift | ✅ Done | **Phase A** (shared IDs): `_stableDiagramId` deleted; all families use `StableID.derive`. **Phase B** (shape decorations): `ShapeDecoration.Fill` + `ShapeSpec.fillOverride`/`strokeOverride` added; title-header + simple foreground-fill shapes migrated to spec-driven decorations. **Phase C** (positioned pipeline): all 27 SVG families now have `renderPositioned` closures; 3 deferred families (requirement, zenuml, packet) fixed 2026-05-11. **Phase D** (arrow marker consolidation): `SVGArrowMarkerDefs` shared helper created; `src_renderer.swift` deduplicated (87→6 lines). **Phase E** (builder enhancements + Tier 1 adoption, 2026-05-11): `SVGDocumentBuilder` now supports `useMaxWidth`, `viewBoxX`/`viewBoxY`, `rootStyles`; 24 of 26 SVG renderers migrated (16 in this session); two dead `_*SvgOpenTag` helpers deleted. **Deferred**: per-family arrow marker migration (dimensional drift), gitgraph + treeview SVGDocumentBuilder adoption (no `colors` param), state-end/state-divider (skip). |
| **D3** Frontmatter binding skeleton | ✅ Done | `FrontmatterBinding.extractKey(path:prefixes:)` static helper added to protocol; all 27 bindings refactored from multi-if-else `path.hasPrefix(...)` skeletons to guard/apply/mark patterns using `extractKey`. 8 refactored earlier (ER, Class, Journey, Kanban, Sankey, State, Block, Mindmap); remaining 19 (Sequence, Requirement, Radar, Treemap, Venn, Ishikawa, C4, TreeView, EventModeling, Wardley, Flowchart, XYChart, Pie, Gantt, Quadrant, Timeline, GitGraph, Packet, Architecture) completed 2026-05-11. Four sub-patterns: config-only (5 families), two-section config+theme (7), two-section with theme-guard predicate (3), multi-section with broad-fallback (2), and special-case bare-key + config (2). Inline switches extracted into private `_applyConfig` methods; correctness fix applied (mark `hasConfig`/`hasTheme` only after apply returns true). ZenUML has no binding file (no configurable frontmatter). |
| **D4** `YamlFrontmatterThemeHelpers` cleanup | ✅ Done | `6621c67` `eed339a` |
| **D5** Bitmap consolidation | ✅ Done | `31e6882` |

**Spawn chips completed (2026-05-10):**
- ✅ Rect-family `ShapePath` cases — lined-rectangle, stacked-rectangle, tagged-rectangle, etc. spec'd with decorations.
- ✅ Cylinder + document variant cases — lined-cylinder, data-store, delay, curved-trapezoid, notched-pentagon, stacked-document, tagged-document, lined-document, horizontal-cylinder spec'd.
- ✅ Alt-skew/brace/misc cases — braces, divided-rectangle, window-pane, framed-circle, bang, filled-circle, icon/image shapes spec'd with `.polyline` + `.curvedTrapezoid` enum cases.

**Spawn chips remaining:** none — all spawn chips from the original audit have been completed.

**Larger items not yet chipped:**
- ~~Linux text-measurement shim~~ → ✅ Done 2026-05-11. `TextMetrics` ungated with `#else` fallback; `src_ishikawa_layout.swift` routed through `TextMetrics.measureMonospaceMultiline`. treeView and eventModeling don't use CTLine directly.
- ~~CG/SVG renderer convergence on shared geometry primitives (D2 long-term plan)~~ → ✅ Done 2026-05-11. Positioned pipeline complete; 3-family fix landed; `SVGDocumentBuilder` enhanced with `useMaxWidth`/`viewBox`/`rootStyles`; 24 of 26 SVG renderers migrated. Remaining: per-family arrow markers (dimensional drift — assessed ❌ not mechanical), state-end/divider (skip).

**External / not actionable:**
- `swift-snapshot-testing` upstream PR #1090 landing → switch back from the `ajmcclary/swift-snapshot-testing` fork.
- `CorpusSnapshotTests` signal-10 hang investigation — pre-existing on `main`; needs upstream debugging.
- `<Module>Bootstrap.phase: Int` markers — explicitly deferred to monorepo promotion (Stage 6 in `ANALYSIS.md`).
- 14 yellow `@unchecked Sendable` allowlist entries — sunset `2027-06-30`; per-site contract review.

## Abstraction Analysis

### A1. View APIs bypass or duplicate the canonical worker-thread abstraction

**Status:** ✅ Done (`bbe256a`, `601f4b4`, `97dfdce`, `64c73dc`, `15d87cd`). `MermaidPreparation` lives in `DiagramKitRenderingCG` with closure-based registration; the 8 MB worker is `MermaidWorkerThread.run`; all view paths consume `MermaidPreparation.prepare(...)` async; a regression test in `MermaidPreparationWorkerTests` asserts the named worker-thread invariant.

**Evidence**

- `Sources/DiagramKit/MermaidRenderer.swift:125` defines the architectural worker invariant and `_runOnWorker`.
- `Sources/DiagramKit/MermaidRenderer.swift:141` to `Sources/DiagramKit/MermaidRenderer.swift:151` creates a fresh 8 MB-stack `Thread`.
- `Sources/DiagramKit/Views/MermaidLayer.swift:151` to `Sources/DiagramKit/Views/MermaidLayer.swift:168` repeats the same thread creation logic inline.
- `Sources/DiagramKit/Views/MermaidDiagram.swift:30` to `Sources/DiagramKit/Views/MermaidDiagram.swift:45` calls `MermaidPipeline.prepare` synchronously from an `@MainActor` method.
- `Sources/DiagramKit/ImageRenderer.swift:26` to `Sources/DiagramKit/ImageRenderer.swift:35` correctly routes preparation through `MermaidRenderer._runOnWorker`.

**Impact**

The most important runtime invariant in the package is no longer auditable in one place. `MermaidLayer` has a copied version of the worker implementation, so any future change to stack size, naming, cancellation behavior, issue reporting, or instrumentation can drift. `MermaidDiagram.prepare()` is riskier: it runs parse/layout synchronously on the main actor, which can block UI and bypasses the stack-safety path used by public renderer APIs.

**Recommendation**

Extract a small preparation service inside the umbrella target and make `MermaidRenderer`, `MermaidImageRenderer`, `MermaidLayer`, and `MermaidDiagram` use it.

```swift
enum MermaidPreparation {
    static func prepare(
        source: String,
        theme: DiagramTheme,
        layoutConfig: LayoutConfig
    ) async throws -> PreparedDiagram {
        try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
    }
}
```

Then `MermaidLayer.prepareDiagram()` can become a consumer instead of a second implementation:

```swift
preparationTask = Task { [weak self] in
    do {
        let prepared = try await MermaidPreparation.prepare(
            source: source,
            theme: theme,
            layoutConfig: layoutConfig
        )
        guard !Task.isCancelled else { return }
        self?.preparedDiagram = prepared
        self?.diagramBounds = prepared.bounds
    } catch {
        guard !Task.isCancelled else { return }
        _reportMermaidIssueIfNeeded(error, operation: "MermaidLayer.prepareDiagram")
        self?.parseError = error
    }
    self?.setNeedsDisplay()
    self?.onPrepareComplete?()
}
```

### A2. `DiagramRegistry` is useful, but it is becoming a God registry

**Status:** ✅ Done (`741e212`, `33c61c2`). Per-family `DiagramRegistry+<Family>.swift` extension files now hold individual descriptors; the central `DiagramDescriptor.swift` holds the abstraction and the ordered `all` list. A typed descriptor factory eliminates the `guard case` boilerplate.

**Evidence**

- `Sources/DiagramKit/DiagramDescriptor.swift:73` to `Sources/DiagramKit/DiagramDescriptor.swift:99` defines the descriptor abstraction.
- `Sources/DiagramKit/DiagramDescriptor.swift:111` to `Sources/DiagramKit/DiagramDescriptor.swift:142` registers all 28 diagram descriptors in one array.
- `Sources/DiagramKit/DiagramDescriptor.swift:197` to `Sources/DiagramKit/DiagramDescriptor.swift:836` defines every descriptor, including detection, parsing, frontmatter merging, layout, payload extraction, and platform fallbacks.
- Repeated payload guard pattern appears at `Sources/DiagramKit/DiagramDescriptor.swift:205`, `Sources/DiagramKit/DiagramDescriptor.swift:225`, `Sources/DiagramKit/DiagramDescriptor.swift:251`, and continues throughout the file.
- `Scripts/check-file-sizes.sh` reports `Sources/DiagramKit/DiagramDescriptor.swift` at 851 lines.

**Impact**

The registry fixed older parser and layout dispatch duplication, but it now centralizes too many reasons to change. Adding or changing one diagram type requires editing an 851-line file that also contains every other diagram family. This raises merge-conflict probability and makes per-diagram ownership less clear. The repeated `guard case` and `PositionedGraph(...)` wrapping code also obscures the real differences between diagram families.

**Recommendation**

Keep `DiagramRegistry.all` as the entry point, but split descriptors by diagram family and add a typed descriptor builder to remove boilerplate.

```swift
private static func typedDescriptor<Parsed, Positioned>(
    type: DiagramType,
    matches: @escaping @Sendable (DiagramHeader) -> Bool,
    parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> Parsed,
    payload: @escaping @Sendable (Parsed) -> DiagramPayload,
    extract: @escaping @Sendable (DiagramPayload) -> Parsed?,
    layout: @escaping @Sendable (Parsed, LayoutConfig) throws -> Positioned,
    positioned: @escaping @Sendable (MermaidGraph, Positioned) -> PositionedGraph
) -> DiagramDescriptor {
    DiagramDescriptor(
        type: type,
        matches: matches,
        parse: { source, frontmatter in MermaidGraph(payload: payload(try parse(source, frontmatter))) },
        layout: { graph, config in
            guard let parsed = extract(graph.payload) else {
                throw MermaidStructuralError.payloadMismatch(type)
            }
            return positioned(graph, try layout(parsed, config))
        }
    )
}
```

Move descriptors into files such as `DiagramRegistry+Sequence.swift`, `DiagramRegistry+Gantt.swift`, and `DiagramRegistry+Flowchart.swift`. The central file should only define the abstractions and the ordered `all` list.

### A3. `DiagramFrontmatter` is a cross-cutting config bag embedded in `src_class_parser.swift`

**Status:** ✅ Done (`b308aa6`). `DiagramFrontmatter` lives in `Sources/DiagramKitModel/DiagramFrontmatter.swift` with shared/per-diagram split via the binding adapters.

**Evidence**

- `Sources/DiagramKitModel/src_class_parser.swift:322` labels `DiagramFrontmatter`.
- `Sources/DiagramKitModel/src_class_parser.swift:324` to `Sources/DiagramKitModel/src_class_parser.swift:374` defines 49 optional fields spanning all diagram families.
- `Sources/DiagramKitModel/src_class_parser.swift:376` to `Sources/DiagramKitModel/src_class_parser.swift:476` mirrors those fields in a very long initializer.
- The type is consumed by the source-preprocessing and binding layer at `Sources/DiagramKitModel/SourcePreprocessing.swift:332` and `Sources/DiagramKitModel/FrontmatterBinding.swift:50`.

**Impact**

A package-wide frontmatter model living inside the class-diagram parser creates a discoverability and ownership problem. Every new diagram family extends a type in a file that semantically belongs to one diagram family. The 49-field optional bag also makes it difficult to tell which values are global, which are diagram-specific, and which are temporary compatibility fields. That increases the risk of accidental coupling between unrelated diagrams.

**Recommendation**

Move the type to `Sources/DiagramKitModel/DiagramFrontmatter.swift` and separate shared values from per-diagram values. Keep source compatibility initially by preserving computed properties if needed.

```swift
public struct DiagramFrontmatter: Sendable {
    public var shared = SharedFrontmatter()
    public var diagrams = DiagramFrontmatterConfigs()
}

public struct SharedFrontmatter: Sendable {
    public var title: String?
    public var diagramTitle: String?
    public var layout: String?
    public var look: String?
    public var theme: String?
    public var htmlLabels: Bool?
    public var fontSize: Double?
    public var securityLevel: String?
}

public struct DiagramFrontmatterConfigs: Sendable {
    public var sequence: SequenceDiagramConfig?
    public var flowchart: original_src_types.FlowchartConfig?
    public var state: original_src_types.StateConfig?
    public var classDiagram: ClassConfig?
    // Continue per family, grouped and documented.
}
```

This keeps the current typed-storage model without forcing an unsafe dictionary of existentials.

### A4. Shape abstractions exist, but rendering and clipping still carry independent shape logic

**Status:** ✅ Done. `ShapePath` enum extended to 27 cases with `.polyline` + `.curvedTrapezoid`; all `_defaultSpec` entries migrated to explicit paths with `ShapeDecoration`; `CGPathRenderer` + `SVGPathSerializer` cover all cases; all four consumer switches (`ShapeRenderer.shapePath` + `_drawSpecDecorations`, SVG `_renderNodeShapeGeneric`, `EdgeShapeClipper._clipPoint`) are now spec-driven. Position-dependent decorations (cylinder caps, stacked offsets, inset panes, corner tags) retained in special-case switches pending sub-bounds decoration support.

**Evidence**

- `Sources/DiagramKitModel/ShapeSpec.swift:10` to `Sources/DiagramKitModel/ShapeSpec.swift:15` states that layout, CG rendering, and SVG rendering should derive shape behavior from `ShapeSpecRegistry`.
- `Sources/DiagramKitModel/ShapeSpec.swift:79` to `Sources/DiagramKitModel/ShapeSpec.swift:168` registers shape specs and aliases.
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:94` to `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:211` still has a large shape switch.
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:476` to `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:631` has a second switch for shape details.
- `Sources/DiagramKitModel/src_renderer.swift:553` to `Sources/DiagramKitModel/src_renderer.swift:690` has an independent SVG shape switch.
- `Sources/DiagramKitModel/src_block_renderer.swift:227` to `Sources/DiagramKitModel/src_block_renderer.swift:285` repeats a smaller shape-rendering switch.
- `Sources/DiagramKitModel/EdgeShapeClipper.swift:54` to `Sources/DiagramKitModel/EdgeShapeClipper.swift:63` maintains another shape-kind switch for edge clipping.
- `Sources/DiagramKitModel/SVGPathSerializer.swift:57` to `Sources/DiagramKitModel/SVGPathSerializer.swift:61` falls back to a rectangle for many complex shapes.

**Impact**

The code advertises `ShapeSpecRegistry` as the single source of truth, but several paths still decide shape behavior independently. That creates drift across layout sizing, SVG geometry, CG geometry, and edge clipping. The SVG serializer fallback is especially risky because complex shapes can silently degrade to rectangles when routed through the generic serializer.

**Recommendation**

Promote `ShapeSpec` from sizing/path metadata to full shape behavior. Add optional decoration and clipping fields, then make SVG and CG renderers consume the same spec.

```swift
public struct ShapeSpec: Sendable {
    public let aliases: Set<String>
    public let minimumSize: CGSize
    public let sizeAdjustment: @Sendable (CGSize, RenderConfig) -> CGSize
    public let path: @Sendable (CGRect, RenderConfig) -> ShapePath
    public let clipPath: (@Sendable (CGRect, RenderConfig) -> ShapePath)?
    public let decorations: [ShapeDecoration]
}

private func renderShape(_ node: _SvgNode) -> String {
    let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
    let spec = ShapeSpecRegistry.spec(for: node.shape) ?? ShapeSpecRegistry.rectangle
    let d = SVGPathSerializer.serialize(spec.path(rect, RenderConfig.shared), in: rect)
    return #"<path d="\#(d)" fill="\#(fill)" stroke="\#(stroke)" stroke-width="\#(sw)" />"#
}
```

Finish `SVGPathSerializer` for all `ShapePath` cases before migrating more renderer code to it.

### A5. Font and render-token abstractions are partially adopted

**Status:** ✅ Done. The three-way decomposition landed:

- **`RenderTokens`** — owns all 35+ stored properties (node padding, font sizes/weights, stroke widths, arrow dimensions, spacing, minimum sizes, shape-specific radii, edge-label layout, default font families). Per-diagram constants live in `RenderTokens+Sequence.swift`, `RenderTokens+Class.swift`, and `RenderTokens+ER.swift`. `RenderConfig` forwards all stored properties through `self.tokens.*` with get/set accessors.

- **`DiagramFontResolver`** — consolidates all font resolution into one struct in `Sources/DiagramKitModel/`. Absorbed `RenderConfig.defaultFont()`, `.proportionalFont()`, `.nodeLabelFont()`, `.edgeLabelFont()`, `.groupHeaderFont()`, `.bmWeight()`, `.fontWeight()`; the CG-layer `DiagramFontResolver` static helpers (`proportional`, `boldProportional`, `mono`); `DiagramRenderer._monoFont` / `._italicSystemFont` / `._italicMonoFont`; and Ishikawa/EventModeling local font helpers. Also provides SVG font-family strings (`svgProportionalFamily`, `svgMonoFamily`, fallback chains) and CTFont helpers (`proportionalCTFont`, `monospaceCTFont`). Takes `RenderTokens` as init parameter.

- **`TextMetrics`** — new type in `Sources/DiagramKitModel/TextMetrics.swift`. Extracted `estimateTextWidth()` and `estimateMonoTextWidth()` from `RenderConfig`. Takes `DiagramFontResolver` as init parameter for font resolution.

`RenderConfig` now exposes `tokens`, `fontResolver`, and `textMetrics` as computed properties. All old methods remain as backward-compatible forwarding wrappers. `DiagramRenderer` exposes the same three properties. ~28 CG renderer files were migrated: all `DiagramFontResolver.proportional(config, ...)` calls replaced with `self.fontResolver.proportionalFont(...)`, `ShapeRenderer` tokenized, and local font helpers eliminated. The CG-layer `DiagramFontResolver` enum is deprecated.

**Evidence** (updated — post-split)

**Evidence**

- `Sources/DiagramKitModel/RenderConfig.swift:18` to `Sources/DiagramKitModel/RenderConfig.swift:112` mixes generic node metrics, sequence constants, class constants, ER constants, and font settings.
- `Sources/DiagramKitModel/RenderConfig.swift:153` to `Sources/DiagramKitModel/RenderConfig.swift:267` also resolves fonts and measures text.
- `Sources/DiagramKitModel/RenderConfig.swift:218` to `Sources/DiagramKitModel/RenderConfig.swift:237` defines `nodeLabelFont`, `edgeLabelFont`, and `groupHeaderFont`, but those methods fall back directly to `BMFont.systemFont` and ignore `defaultProportionalFontFamily` when no explicit family is passed.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Gantt.swift:41`, `Sources/DiagramKitRenderingCG/DiagramRenderer+Gantt.swift:62`, `Sources/DiagramKitRenderingCG/DiagramRenderer+Gantt.swift:197`, `Sources/DiagramKitRenderingCG/DiagramRenderer+Gantt.swift:227`, and `Sources/DiagramKitRenderingCG/DiagramRenderer+Gantt.swift:255` create system fonts directly.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:132`, `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:188`, `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:204`, `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:216`, `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:230`, and `Sources/DiagramKitRenderingCG/DiagramRenderer+XYChart.swift:236` create system fonts directly.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Treemap.swift:135` to `Sources/DiagramKitRenderingCG/DiagramRenderer+Treemap.swift:140` and `Sources/DiagramKitRenderingCG/DiagramRenderer+Venn.swift:306` to `Sources/DiagramKitRenderingCG/DiagramRenderer+Venn.swift:311` carry duplicate local font helpers.

**Impact**

Snapshot determinism depends on bundled font registration and configured font families. Direct system-font use leaks platform font drift back into renderer code and makes it unclear which diagrams honor `RenderConfig.defaultProportionalFontFamily`. `RenderConfig` is also doing several jobs at once: token storage, font resolution, and text measurement.

**Recommendation**

Split responsibilities into token storage, font resolution, and text measurement. As an immediate low-risk fix, route existing convenience methods through `proportionalFont`.

```swift
public func nodeLabelFont(family: String? = nil) -> BMFont {
    if let family, let font = BMFont(name: family, size: fontSizeNodeLabel) {
        return font
    }
    return proportionalFont(size: fontSizeNodeLabel, weight: fontWeightNodeLabel)
}

public func edgeLabelFont(family: String? = nil) -> BMFont {
    if let family, let font = BMFont(name: family, size: fontSizeEdgeLabel) {
        return font
    }
    return proportionalFont(size: fontSizeEdgeLabel, weight: fontWeightEdgeLabel)
}
```

After that, replace direct `BMFont.systemFont` calls in CG renderers with a `DiagramFontResolver` or `RenderConfig` helper.

## Pattern Consistency Review

### P1. Parser and layout routing use the registry, but SVG and ASCII still have separate routing systems

**Status:** ✅ Done (`0a42b8a`, `4c3d386`). `SVGRenderRegistry` and ASCII routing both consume `DiagramRegistry.detect`. `_DiagramRoutingType` and `DetectedDiagramType` deleted. The remaining duplicated parse/layout work inside the SVG case functions is tracked separately as **D1**.

**Evidence**

- `Sources/DiagramKit/Parser.swift:16` to `Sources/DiagramKit/Parser.swift:19` delegates detection and parsing to `DiagramRegistry`.
- `Sources/DiagramKit/Layout.swift:12` to `Sources/DiagramKit/Layout.swift:20` delegates layout to `DiagramRegistry`.
- `Sources/DiagramKit/src_index.swift:15` to `Sources/DiagramKit/src_index.swift:43` defines a separate `_DiagramRoutingType`.
- `Sources/DiagramKit/src_index.swift:54` to `Sources/DiagramKit/src_index.swift:87` maps `DiagramRegistry` output back into that separate routing type.
- `Sources/DiagramKit/src_index.swift:141` to `Sources/DiagramKit/src_index.swift:196` switches over `_DiagramRoutingType` to select SVG rendering.
- `Sources/DiagramKit/src_ascii_index.swift:283` to `Sources/DiagramKit/src_ascii_index.swift:310` defines a separate ASCII `DetectedDiagramType`.
- `Sources/DiagramKit/src_ascii_index.swift:453` to `Sources/DiagramKit/src_ascii_index.swift:566` switches over ASCII diagram type for rendering.
- `Sources/DiagramKit/src_ascii_index.swift:579` to `Sources/DiagramKit/src_ascii_index.swift:667` maintains an independent header-detection chain.

**Impact**

Adding or renaming a diagram type still requires updating multiple routing surfaces. Parser/layout dispatch has one source of truth, but SVG and ASCII rendering can drift from it. The risk is highest for nuanced headers such as `state`, `stateDiagram-v2`, `radar-beta`, `venn-beta`, `treeView-beta`, C4, and fallback flowchart handling.

**Recommendation**

Make renderer capabilities explicit extensions of registry data instead of separate diagram-type enums. If keeping concerns separate is preferred, introduce `SVGRenderRegistry` and `ASCIIRenderRegistry` keyed by `DiagramType`, but reuse `DiagramHeader` and `DiagramRegistry.detect`.

```swift
public struct SVGRenderDescriptor: Sendable {
    public let type: DiagramType
    public let render: @Sendable (String, DiagramFrontmatter?, RenderOptions, LayoutConfig) throws -> String
}

enum SVGRenderRegistry {
    static let all: [DiagramType: SVGRenderDescriptor] = [
        .sequenceDiagram: .sequence,
        .classDiagram: .classDiagram,
        .flowchart: .flowchart,
    ]

    static func render(_ source: String, frontmatter: DiagramFrontmatter?, options: RenderOptions, layoutConfig: LayoutConfig) throws -> String {
        let type = DiagramRegistry.detect(from: source).type
        guard let descriptor = all[type] else {
            throw BeautifulMermaidError.notYetImplemented("SVG rendering for \(type.rawValue)")
        }
        return try descriptor.render(source, frontmatter, options, layoutConfig)
    }
}
```

### P2. Frontmatter binding semantics vary across diagram families

**Status:** ✅ Done (`7c44419`). Bindings standardized to mark `hasConfig`/`hasTheme` only after `_apply…` returns true; YAML leaf-key path inheritance fixed in the same commit.

**Evidence**

- `Sources/DiagramKitModel/SourcePreprocessing.swift:180` to `Sources/DiagramKitModel/SourcePreprocessing.swift:212` registers 27 frontmatter bindings.
- `Sources/DiagramKitModel/SourcePreprocessing.swift:217` to `Sources/DiagramKitModel/SourcePreprocessing.swift:245` applies every flattened key to every binding.
- `Sources/DiagramKitModel/FrontmatterBinding+Requirement.swift:22` to `Sources/DiagramKitModel/FrontmatterBinding+Requirement.swift:25` sets `hasTheme = true` before confirming the key was recognized.
- `Sources/DiagramKitModel/FrontmatterBinding+Radar.swift:18` to `Sources/DiagramKitModel/FrontmatterBinding+Radar.swift:20` does the same.
- `Sources/DiagramKitModel/FrontmatterBinding+Wardley.swift:24` to `Sources/DiagramKitModel/FrontmatterBinding+Wardley.swift:26` does the same.
- `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:38` to `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:45` and `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:38` to `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:45` do the same for broad fallback `themeVariables.*` prefixes.
- `Sources/DiagramKitModel/FrontmatterBinding+Quadrant.swift:27` to `Sources/DiagramKitModel/FrontmatterBinding+Quadrant.swift:42` and `Sources/DiagramKitModel/FrontmatterBinding+Timeline.swift:27` to `Sources/DiagramKitModel/FrontmatterBinding+Timeline.swift:42` show a safer pattern: check the key before setting `hasTheme`.

**Impact**

Unrelated `themeVariables.*` keys can cause default theme structs to be committed for diagram families that did not actually consume the key. That makes frontmatter behavior order-sensitive and harder to reason about. It also increases the risk that a renderer sees a default theme override instead of no theme override.

**Recommendation**

Standardize the binding pattern: only mark `hasConfig` or `hasTheme` after `_apply...` returns true.

```swift
if path.hasPrefix(themePrefix) {
    let key = String(path.dropFirst(themePrefix.count))
    guard _applyTheme(key: key, value: value) else {
        return false
    }
    hasTheme = true
    return true
}
```

For broad `themeVariables.*` fallbacks, require an `_is<Diagram>ThemeKey` predicate before applying.

### P3. The view target boundary is documented, but the code shape does not match the package shape

**Status:** ✅ Done (`bf1dc59`, `86aba45`, `047adbb`, `b70dc61`). View files moved to `Sources/DiagramKitViews/`; `_Stub.swift` deleted; `MermaidViewPreparer` is the seam; the umbrella's `_MermaidPreparerBootstrap` registers `MermaidPipeline.prepare` on first use; the view-side fallback was removed in favor of an explicit `MermaidRenderer.bootstrap()` precondition.

**Evidence**

- `Sources/DiagramKitViews/_Stub.swift:1` to `Sources/DiagramKitViews/_Stub.swift:8` states that the target is a placeholder.
- `Sources/DiagramKit/Views/MermaidDiagramView.swift:1` to `Sources/DiagramKit/Views/MermaidDiagramView.swift:7` shows real SwiftUI wrappers living in the umbrella target.
- `Sources/DiagramKit/Views/MermaidLayer.swift:1` to `Sources/DiagramKit/Views/MermaidLayer.swift:8` shows the layer also living in the umbrella target.
- `Package.swift:21` to `Package.swift:28` exposes `DiagramKitViews` as a library product, while `Package.swift:74` to `Package.swift:78` defines the stub target and `Package.swift:84` to `Package.swift:93` wires that target into the umbrella library conditionally.

**Impact**

The package graph communicates that views are separable, but the implementation says they are not yet separable. That adds cognitive load for consumers and contributors because the `DiagramKitViews` product exists without the view types. It also makes future extraction harder as more view logic accumulates inside the umbrella.

**Recommendation**

Invert the dependency that keeps views in the umbrella. Define a small preparation protocol or closure type in `DiagramKitViews`, and let the umbrella wire it to `MermaidPipeline`.

```swift
public struct MermaidViewPreparer: Sendable {
    public var prepare: @Sendable (
        _ source: String,
        _ theme: DiagramTheme,
        _ config: LayoutConfig
    ) async throws -> PreparedDiagram
}
```

Move the actual view files to `Sources/DiagramKitViews` once the views accept a preparer instead of directly reaching into `MermaidPipeline`.

### P4. Some upstream-port naming conventions are acceptable, but should not spread into new native abstractions

**Status:** ➖ Open (low priority). No new `original_src_*`-style names have been added to native abstractions; existing JS-port lineage names remain in compatibility wrappers. Re-evaluate only if new code starts adopting the convention.

**Evidence**

- `Sources/DiagramKit/src_index.swift:510` to `Sources/DiagramKit/src_index.swift:512` retains `original_src_index`.
- `Sources/DiagramKit/src_ascii_index.swift:221` to `Sources/DiagramKit/src_ascii_index.swift:223` uses `original_src_ascii_index` as a namespace class.
- `Sources/DiagramKitModel/src_sequence_renderer.swift:542` to `Sources/DiagramKitModel/src_sequence_renderer.swift:555` retains `original_src_sequence_renderer`.
- Native abstractions such as `DiagramRegistry` and `MermaidSourceNormalizer` use idiomatic Swift naming at `Sources/DiagramKit/DiagramDescriptor.swift:106` and `Sources/DiagramKitModel/MermaidSourceNormalizer.swift:6`.

**Impact**

The `original_src_*` naming is acceptable in JS-port compatibility files because it preserves lineage. It becomes a maintainability problem only if new native abstractions continue the same namespace style. The current code mostly avoids that, but `src_index.swift` and `src_ascii_index.swift` still sit in the umbrella target and can blur the boundary.

**Recommendation**

Keep `original_src_*` as a compatibility namespace only. New dispatch, rendering, preprocessing, and public API code should use native Swift names and file placement. As routing is moved into registries, isolate legacy names behind deprecated wrappers.

## Duplication and Reuse Audit

### D1. Parse/layout work is duplicated in SVG rendering instead of reusing the registry pipeline

**Status:** ✅ Done. The four SVG case functions (`_renderXYChartSvgCase`, `_renderQuadrantSvgCase`, `_renderSankeySvgCase`, `_renderRadarSvgCase`) now delegate parse, layout, and frontmatter application to their `DiagramRegistry` descriptors. Each function calls `DiagramRegistry._*.parse(source, fm)` + `.layout(graph, LayoutConfig())`, then extracts the positioned payload and renders. The hardcoded `"sankey-1"` diagram ID has been replaced with `StableID.derive(from: source)`. ~25 corpus snapshot rebakes expected — per-diff visual review recommended.

**Evidence**

- `Sources/DiagramKit/src_index.swift:199` to `Sources/DiagramKit/src_index.swift:508` defines 27 `_render*SvgCase` functions.
- `Sources/DiagramKit/DiagramDescriptor.swift:290` to `Sources/DiagramKit/DiagramDescriptor.swift:309` parses and lays out XY charts for the registry path.
- `Sources/DiagramKit/src_index.swift:227` to `Sources/DiagramKit/src_index.swift:236` parses and lays out XY charts again for SVG rendering.
- `Sources/DiagramKit/DiagramDescriptor.swift:360` to `Sources/DiagramKit/DiagramDescriptor.swift:379` parses and lays out quadrant charts for the registry path.
- `Sources/DiagramKit/src_index.swift:265` to `Sources/DiagramKit/src_index.swift:275` repeats the quadrant chart parse/layout/frontmatter merge for SVG.
- `Sources/DiagramKit/DiagramDescriptor.swift:574` to `Sources/DiagramKit/DiagramDescriptor.swift:591` parses and lays out radar diagrams for the registry path.
- `Sources/DiagramKit/src_index.swift:378` to `Sources/DiagramKit/src_index.swift:386` repeats radar parse/layout/frontmatter merge for SVG.

**Impact**

Bug fixes in parser preparation, frontmatter application, title propagation, or layout configuration need to be made twice. The duplicate path is already not identical: SVG cases sometimes use `StableID.derive`, sometimes `_stableDiagramId`, and one case hardcodes `"sankey-1"` at `Sources/DiagramKit/src_index.swift:334`.

**Recommendation**

Render SVG from a `PositionedGraph` wherever possible. The SVG registry should call `MermaidParser.parse` and `GraphLayout.layout` once, then dispatch only the final typed render operation.

```swift
let graph = try MermaidParser.parse(source)
let positioned = try GraphLayout(config: layoutConfig).layout(graph)

switch positioned.content {
case .xyChart(let chart):
    return renderXYChartSvg(chart, colors, font, transparent, interactive: options.interactive ?? false)
case .radar(let radar):
    return renderRadarSvg(radar, colors: colors, font: font, transparent: transparent)
default:
    throw BeautifulMermaidError.notYetImplemented("SVG rendering for \(graph.type.rawValue)")
}
```

This preserves independent SVG renderers while eliminating duplicated parse/layout/frontmatter code.

### D2. CG and SVG renderer duplication is real and should be reduced at geometry boundaries first

**Status:** ✅ Done. All four phases complete: shared ID generation (Phase A), shape decoration convergence (Phase B), positioned pipeline for all 27 SVG families (Phase C), and arrow marker consolidation in the flowchart/state renderer (Phase D). The 3 deferred families from Phase C (requirement, zenuml, packet) were fixed 2026-05-11. Three deferred items remain but are scoped and assessed below.

**Changes landed (2026-05-11)**

- **Phase A — Shared ID generation.** Deleted `_stableDiagramId` (FNV hash, 7 lines) from `src_index.swift`. Mindmap and architecture SVG cases now use `StableID.derive(from:)` like every other family.
- **Phase B — Shape decoration convergence.** Added `ShapeDecoration.Fill` enum (`.none`, `.inherit`, `.surface`, `.foreground`), `ShapeDecoration.Stroke.none`, and `ShapeSpec.fillOverride` / `strokeOverride` properties. Migrated title-header shapes (`rounded-with-title`, `rect-with-title`) to `ShapeDecoration` entries with `fill: .surface` + sub-bounds closures — deleted `_drawRoundedWithTitle` / `_drawRectWithTitle` (44 lines CG) and `_renderRectWithTitle` / `_renderRoundedWithTitle` (18 lines SVG). Migrated simple foreground-fill shapes (`state-start`, `fork`, `join`, `filled-circle`) to `fillOverride: .foreground` + `strokeOverride: .none` — removed 4 early-return cases from CG `drawShape` and 3 from SVG `_renderNodeShape`. State-end and state-divider retained as special cases (foreground stroke needed, dash patterns).
- **Phase C — Positioned pipeline entry.** Added `SVGRenderDescriptor.renderPositioned` optional closure and `SVGRenderRegistry.render(positioned:diagramId:colors:font:transparent:)` method. Four families (xyChart, quadrantChart, sankey, radar) initially migrated. **Phase D** followed up: added `diagramId` threading, migrated 20 more families (gantt, gitGraph, mindmap, kanban, c4, block, timeline, architecture, treemap, venn, ishikawa, treeView, eventModeling, sequence, class, er, pie, journey, flowchart/stateDiagram, wardleyBeta) for a total of 24 families on the positioned path. `MermaidPipeline.renderSVG(source:)` computes `StableID.derive(from: source)` and passes `diagramId` through. `PositionedClassDiagram` init was made public (was internal). Three families deferred: requirement (needs `look`, `theme`, `htmlLabels` from frontmatter), zenuml (needs `useMaxWidth` from sequenceConfig), and packet (needs `theme` from positioned model).

**D2 deferred items — 2026-05-11 analysis**

Three items were identified in the audit as "mechanical" follow-ups. After detailed code review, the scope differs from the initial estimate:

- **3 deferred families (requirement, zenuml, packet) — ✅ Fixed 2026-05-11.** Four files changed, ~14 lines total, clean build. `ZenUMLDiagram.useMaxWidth: Bool` added to parsed model, wired through parse (`frontmatter?.sequenceConfig?.useMaxWidth`) and layout closures. Requirement `config.theme` merged from `frontmatter?.requirementTheme` in parse closure; `look`, `theme`, `htmlLabels` forwarded from `data.config` in `renderPositioned`. Packet required no changes (`theme` already on `PositionedPacketDiagram`, parser reads `frontmatter?.packetTheme`).

- **Per-family arrow marker migration — ❌ Not mechanical.** After reading all candidate files, only 4 of 7 have matching arrowhead geometry (gitgraph, eventmodeling, wardley, block). The other 3 use different shapes (ishikawa: reversed, timeline/journey: V-shaped half-arrows). More critically, each renderer uses custom marker dimensions (`refX`, `markerWidth`, `markerHeight`) tuned to its diagram type. `SVGArrowMarkerDefs` uses unified dimensions from `original_src_styles.ARROW_HEAD`. Forcing shared dimensions would change visual output — not just marker IDs. Defer until dimensional unification is scoped separately.

- **`SVGDocumentBuilder` adoption — ✅ Done 2026-05-11.** Three builder enhancements landed (`useMaxWidth`, `viewBoxX`/`viewBoxY`, `rootStyles`). 24 of 26 SVG renderers migrated: 8 earlier (src_renderer, class, er, xychart, sankey, requirement, c4, wardley) + 16 in this session (mindmap, venn, gantt, architecture, kanban, packet, treemap, ishikawa, eventmodeling, quadrant, pie, zenuml, journey, timeline, radar, block). Two dead `_*SvgOpenTag` helpers deleted. 2 files deferred (gitgraph, treeview) — both lack `colors`/`transparent` params in their function signatures; migrating them would require constructing synthetic `DiagramColors` from per-family theme configs, crossing an abstraction boundary better addressed separately. 2 snapshot baselines need rebakes (block, mindmap) due to new CSS custom properties in `<svg>` style attribute.

- **State-end / state-divider — Skip.** Confirmed at 33 lines total: CG `ShapeRenderer.swift` (17 lines for early-return double-circle + dashed-line special cases), SVG `src_renderer.swift` (16 lines for `_renderStateEnd` + `_renderStateDivider` private helpers). Adding `ForegroundStroke` and `DashedLine` decoration types to support these two edge-case shapes (used only in state diagrams) would add ~40 lines of abstraction code. Net negative value.

- **Icon/image shapes.** Backend-specific embedded content; deferred as separate concern.

**Files changed (Phase A–D)**
`Sources/DiagramKit/src_index.swift` (−16 lines), `Sources/DiagramKitModel/ShapeSpec.swift` (+50 lines), `Sources/DiagramKitRenderingCG/ShapeRenderer.swift` (−48 lines net), `Sources/DiagramKitModel/src_renderer.swift` (−42 lines net), `Sources/DiagramKit/SVGRenderRegistry.swift` (+240 lines), `Sources/DiagramKit/MermaidPipeline.swift` (+55 lines), `Sources/DiagramKitModel/src_class_parser.swift` (+22 lines public init).

**Files changed (2026-05-11 3-family fix)**
`Sources/DiagramKitModel/src_zenuml_types.swift` (+4 lines: `useMaxWidth` field), `Sources/DiagramKit/DiagramRegistry+ZenUML.swift` (+3 lines: frontmatter→model→layout wiring), `Sources/DiagramKit/DiagramRegistry+Requirement.swift` (+3 lines: theme merge in parse closure), `Sources/DiagramKit/SVGRenderRegistry.swift` (+4 lines: theme/look/htmlLabels forwarding).

**Files changed (2026-05-11 builder + ShapeSpec)**
`Sources/DiagramKitModel/SVGUtilities.swift` (+40 lines: useMaxWidth, viewBoxX/Y, rootStyles), `Sources/DiagramKitModel/ShapeSpec.swift` (−799 lines: split to 326), `Sources/DiagramKitModel/ShapeSpecRegistry+Defaults.swift` (new, 807 lines: 68 factory methods), `Sources/DiagramKitModel/src_{renderer,class,er,xychart,sankey,requirement,c4,wardley}_*.swift` (−~80 lines net across 8 files: SVGDocumentBuilder adoption, 2 dead helpers deleted).

### D3. Frontmatter binding files repeat the same state-machine skeleton

**Status:** ✅ Done. The "mark-only-if-applied" correctness rule landed via `7c44419`. `FrontmatterBinding.extractKey(path:prefixes:)` static helper now provides shared prefix extraction. All 27 bindings use the `extractKey` guard/apply/mark pattern — 8 refactored earlier (ER, Class, Journey, Kanban, Sankey, State, Block, Mindmap) and the remaining 19 completed 2026-05-11. Private `configPrefixes`/`themePrefixes` static arrays separate per-section dispatch; inline switches extracted into `_applyConfig` methods. Four sub-patterns emerged: config-only (Sequence, C4, Ishikawa, Treemap, Venn), two-section config+theme (EventModeling, Packet, Radar, Requirement, TreeView, Wardley, XYChart), two-section with theme-guard predicate (Architecture, Quadrant, Timeline), multi-section with broad-fallback (GitGraph, Pie), and special-case bare-key + config (Flowchart, Gantt). ZenUML has no binding file (no configurable frontmatter).

**Evidence**

- There are 27 files matching `Sources/DiagramKitModel/FrontmatterBinding+*.swift`.
- Exact repeated 10-line binding skeletons appear across 10 files, including `Sources/DiagramKitModel/FrontmatterBinding+Sankey.swift:13`, `Sources/DiagramKitModel/FrontmatterBinding+Flowchart.swift:19`, `Sources/DiagramKitModel/FrontmatterBinding+ER.swift:13`, `Sources/DiagramKitModel/FrontmatterBinding+Journey.swift:13`, `Sources/DiagramKitModel/FrontmatterBinding+Kanban.swift:13`, `Sources/DiagramKitModel/FrontmatterBinding+Class.swift:13`, `Sources/DiagramKitModel/FrontmatterBinding+Mindmap.swift:13`, and `Sources/DiagramKitModel/FrontmatterBinding+Gantt.swift:19`.
- Multi-prefix config/theme bindings repeat the same pattern in `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:21` to `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:47`, `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:21` to `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:47`, `Sources/DiagramKitModel/FrontmatterBinding+Packet.swift:18` to `Sources/DiagramKitModel/FrontmatterBinding+Packet.swift:34`, and `Sources/DiagramKitModel/FrontmatterBinding+XYChart.swift:18` to `Sources/DiagramKitModel/FrontmatterBinding+XYChart.swift:34`.

**Impact**

The repeated skeleton is simple, but it has already allowed semantic drift in when `hasTheme` is set. This is a good example of duplication that looks harmless until every copy needs a subtle correctness rule.

**Recommendation**

Introduce a small helper for prefix matching and "mark only if applied" behavior.

```swift
mutating func applySection(
    path: String,
    value: FrontmatterValue,
    prefixes: [String],
    mark: inout Bool,
    apply: (String, FrontmatterValue) -> Bool
) -> Bool {
    for prefix in prefixes where path.hasPrefix(prefix) {
        let key = String(path.dropFirst(prefix.count))
        guard apply(key, value) else { return false }
        mark = true
        return true
    }
    return false
}
```

Each binding can then focus on its typed key mapping rather than repeated prefix mechanics.

### D4. `YamlFrontmatterThemeHelpers.swift` contains dead or duplicated helper surfaces

**Status:** ✅ Done (`6621c67`, `eed339a`). Dead `_apply<Diagram>ThemeValue` helpers removed; remaining surface split into intent-named files: `FrontmatterThemeKeyPredicates.swift` (the `_is*ThemeKey` predicates) and `YamlInlineArrayParser.swift` (`_parseYamlStringArray`).

**Evidence**

- `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:6` to `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:92` defines GitGraph theme key helpers and application logic.
- `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:78` to `Sources/DiagramKitModel/FrontmatterBinding+GitGraph.swift:132` duplicates GitGraph theme application.
- `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:94` to `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:154` defines Pie theme helpers and application logic.
- `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:59` to `Sources/DiagramKitModel/FrontmatterBinding+Pie.swift:89` duplicates Pie theme application.
- `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:318` to `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:368` defines Timeline theme application.
- `Sources/DiagramKitModel/FrontmatterBinding+Timeline.swift:63` to `Sources/DiagramKitModel/FrontmatterBinding+Timeline.swift:97` duplicates Timeline theme application.
- `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:469` to `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:499` defines Radar theme application.
- `Sources/DiagramKitModel/FrontmatterBinding+Radar.swift:42` to `Sources/DiagramKitModel/FrontmatterBinding+Radar.swift:58` duplicates Radar theme application.

**Impact**

The file name says YAML-specific helper, but the active frontmatter path now delegates through `FrontmatterBinding`. Several public helper functions appear to be legacy remnants. That creates uncertainty over which path is authoritative and increases the chance that a future fix updates only one implementation.

**Recommendation**

Keep only generic helpers that active bindings use, such as `_parseYamlStringArray` at `Sources/DiagramKitModel/YamlFrontmatterThemeHelpers.swift:233`. Move reusable key predicates into a clearly named support file, such as `FrontmatterThemeKeyPredicates.swift`, and delete or make private any unused `_apply<Diagram>ThemeValue` functions.

### D5. Bitmap rendering setup is duplicated between image rendering and the layer view

**Status:** ✅ Done (`31e6882`). `MermaidBitmapRenderer.render(size:scale:theme:draw:)` is the single platform bitmap entry point; `MermaidImageRenderer` and `MermaidLayer.renderImage(scale:)` both consume it.

**Evidence**

- `Sources/DiagramKit/ImageRenderer.swift:151` to `Sources/DiagramKit/ImageRenderer.swift:199` centralizes bitmap context creation for `MermaidImageRenderer`.
- `Sources/DiagramKit/Views/MermaidLayer.swift:83` to `Sources/DiagramKit/Views/MermaidLayer.swift:130` implements a separate bitmap rendering path.

**Impact**

Both paths deal with UIKit/AppKit context creation, background fill, scaling, and AppKit y-axis flipping. These are subtle platform details. Duplication here risks divergent output between programmatic image rendering and view-layer image export.

**Recommendation**

Extract bitmap context creation into a shared helper in the umbrella or RenderingCG layer.

```swift
enum MermaidBitmapRenderer {
    @MainActor
    static func render(
        size: CGSize,
        scale: CGFloat,
        theme: DiagramTheme,
        draw: (CGContext) -> Void
    ) -> BMImage? {
        // Move existing UIKit/AppKit setup here.
    }
}
```

Then both `MermaidImageRenderer` and `MermaidLayer.renderImage(scale:)` should call it.

### Acceptable Repetition

Some repetition is acceptable and should not be aggressively abstracted:

- The 11 allowlisted >1000-line JS-port files listed by `Scripts/check-file-sizes-allowlist.txt` preserve upstream lineage. Splitting them would raise merge and attribution cost.
- Per-diagram parser files such as `Sources/DiagramKitModel/src_gantt_parser.swift` and `Sources/DiagramKitModel/src_sequence_parser.swift` are domain-specific and often clearer as ports.
- Explicit ASCII `notYetImplemented` cases in `Sources/DiagramKit/src_ascii_index.swift:475` to `Sources/DiagramKit/src_ascii_index.swift:539` are acceptable as a product capability matrix, although routing should still be registry-backed.
- Separate CG and SVG emitters are acceptable while the project preserves both output formats. The target refactor should be shared geometry, not premature unification of all drawing code.

## Prioritized Refactoring Roadmap

### P0 - Protect the runtime invariant and UI responsiveness — ✅ Done

1. ✅ Route `MermaidLayer.prepareDiagram()` through `MermaidRenderer._runOnWorker` or a new `MermaidPreparation` helper.
2. ✅ Change `MermaidDiagram.prepare()` to prepare asynchronously off the main actor and publish results back on the main actor.
3. ✅ Add tests or review checks that all public prepare/render entry points use the canonical worker helper. (`MermaidPreparationWorkerTests`)

Expected impact: high maintainability and correctness gain with low blast radius.

### P1 - Collapse duplicated diagram routing — ✅ Done

1. ✅ Replace `src_ascii_index.swift` detection with `DiagramRegistry.detect`.
2. ✅ Add `SVGRenderRegistry` keyed by `DiagramType`.
3. ✅ Convert 4 SVG case functions to delegate parse/layout/frontmatter to `DiagramRegistry` descriptors.
4. ✅ Remove `_DiagramRoutingType` and `DetectedDiagramType` once coverage is equivalent.

Expected impact: high developer productivity gain when adding or changing diagram families.

### P1 - Fix font abstraction drift — ✅ Done

1. ✅ Update `RenderConfig.nodeLabelFont`, `edgeLabelFont`, and `groupHeaderFont` to use bundled proportional defaults.
2. ✅ Replace direct `BMFont.systemFont` calls in Gantt, XYChart, Journey, Timeline, ER, Class, and Sequence CG renderers with `RenderConfig` or `DiagramFontResolver`.
3. ✅ Keep Mermaid-specific fallback chains only in specialized helpers, not call sites.

Expected impact: high snapshot determinism and medium maintainability gain.

### P2 - Split large cross-cutting config and registry files — ✅ Done

1. ✅ Move `DiagramFrontmatter` out of `src_class_parser.swift`.
2. ✅ Group frontmatter into shared and per-diagram config structs.
3. ✅ Split `DiagramDescriptor.swift` into descriptor extensions by diagram family.
4. ✅ Add a typed descriptor factory to remove repeated payload guards.

Expected impact: medium-to-high maintainability gain, especially for future diagram imports.

### P2 - Finish shape abstraction adoption — ✅ Done

1. ✅ Complete `SVGPathSerializer` for all `ShapePath` cases (now 27 cases including `.polyline` and `.curvedTrapezoid`).
2. ✅ Add clipping and decoration metadata to `ShapeSpec`; all `_defaultSpec` entries migrated to explicit paths + `ShapeDecoration`.
3. ✅ `NodeShapeRenderer.shapePath(for:in:)` routes all shapes through `ShapeSpecRegistry` → `CGPathRenderer`.
4. ✅ `_drawSpecDecorations` renders same-bounds decorations from spec. Position-dependent decorations remain in `drawShapeDetails` switch until sub-bounds support is added.
5. ✅ SVG `_renderNodeShape` migrated: `_renderNodeShapeGeneric` uses `ShapeSpecRegistry` + `SVGPathSerializer` for ~70% of shapes; special-case switch retained for position-dependent shapes (cylinder caps, stacked offsets, inset panes, corner tags) and shapes with custom color semantics (state-start, state-end, filled-circle, note, icon/image, title shapes).
6. ✅ `EdgeShapeClipper` migrated: `_clipPoint(endpoint:adjacent:shapePath:...)` dispatches on `ShapePath` instead of raw shape-name strings. Original `_clipPoint(shape: String, ...)` now routes through `ShapeSpecRegistry` first, falling back to legacy dispatch.

### P2 - Standardize frontmatter bindings — ✅ Done

1. ✅ Introduce prefix application helpers that only set `hasConfig` or `hasTheme` after successful key application.
2. ✅ Fix broad-prefix bindings in Requirement, Radar, Wardley, Pie, and GitGraph.
3. ✅ Delete or reuse duplicated theme-application helpers in `YamlFrontmatterThemeHelpers.swift`.
4. ✅ `FrontmatterBinding.extractKey(path:prefixes:)` static helper added; 8 bindings refactored from 12-line skeletons to 4-line guard/apply/mark patterns. Remaining 19 can follow mechanically — the correctness rule is already in place in all bindings.

Expected impact: medium correctness and maintainability gain.

### P3 - Align the package graph with view ownership — ✅ Done

1. ✅ Introduce a view-preparation protocol or closure. (`MermaidViewPreparer`)
2. ✅ Move actual view files from `Sources/DiagramKit/Views` into `Sources/DiagramKitViews`.
3. ✅ Keep the umbrella target as the composition point that supplies the default preparer. (`_MermaidPreparerBootstrap` registers `MermaidPipeline.prepare` on first use; `MermaidRenderer.bootstrap()` exposes it explicitly.)

Expected impact: medium architectural clarity, lower immediate urgency.

### P3 - Consolidate bitmap rendering — ✅ Done

1. ✅ Extract platform bitmap context setup from `MermaidImageRenderer`. (`MermaidBitmapRenderer`)
2. ✅ Reuse it from `MermaidLayer.renderImage(scale:)`.
3. ✅ Snapshot or pixel-check one UIKit and one AppKit path after extraction.

Expected impact: medium duplication reduction with moderate platform-testing needs.

## Remaining Larger Items (not yet chipped)

These were identified in the audit but warrant their own scoping passes before being chipped:

- **D2 deferred follow-ups — assessed 2026-05-11.** Per-family arrow marker migration to `SVGArrowMarkerDefs`: after code review, only 4 of 7 candidate files have matching geometry, and each uses custom dimensions tuned to its diagram type. Forcing unified `ARROW_HEAD` dimensions changes visual output. `SVGDocumentBuilder` adoption: ✅ complete — 24 of 26 files migrated; 2 deferred (gitgraph, treeview — lack `colors`/`transparent` params). State-end / state-divider: confirmed at 33 lines; adding abstraction types costs ~40 lines. Net negative value.
- ~~**Linux Stage 2.5.**~~ → ✅ Done 2026-05-11. `TextMetrics` now has `#else` character-width fallback; `src_ishikawa_layout.swift` uses `TextMetrics.measureMonospaceMultiline`.

## External / Not Actionable

- `swift-snapshot-testing` upstream PR #1090 — switch off the `ajmcclary` fork once it lands in a tagged release.
- `CorpusSnapshotTests` signal-10 hang — pre-existing upstream test-runner / `swift-snapshot-testing` interaction. Workaround documented in `CLAUDE.md` and project memory.
- `<Module>Bootstrap.phase: Int` markers — explicitly deferred to monorepo Stage 6.
- 14 `.sendable-allowlist.txt` yellow entries — sunset `2027-06-30`; per-site analysis required.
