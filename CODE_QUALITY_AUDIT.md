# Code Quality Audit

Date: 2026-05-18

Scope: structural design, maintainability, abstraction boundaries, pattern consistency, and duplication/reuse across the DiagramKit Swift package and sample application.

## Executive Summary

DiagramKit has a strong structural foundation. The package is split into layered SwiftPM products, imports generally flow downward, and several important abstractions are already doing useful work: `DiagramPipeline` centralizes parsing/layout/render orchestration, typed diagram descriptors reduce format-specific dispatch, importer/exporter registries avoid large public API switches, and snapshot coverage is broad enough to guard renderer drift.

The codebase is nevertheless in a mid-refactor state. The main maintainability risks are not architectural collapse, but residual legacy paths and partially completed abstraction migrations. The largest examples are dead shape-rendering fallback code that is made unreachable by `ShapeSpecRegistry`, `RenderConfig` still acting as a font and measurement facade after `DiagramFontResolver` and `TextMetricsProvider` were introduced, and a sample-app `LiveEditorStore` that has grown into a multi-domain controller and currently violates the repository file-size gate.

Measured indicators:

- Swift source files inspected: 585 under `Sources/`.
- Swift test files inspected: 301 under `Tests/`.
- Source LOC: approximately 124,391.
- Files over 500 lines: 61.
- Files over 1000 lines: 11.
- `Scripts/check-file-sizes.sh` currently fails because `Sources/DiagramKitSample/Models/LiveEditorStore.swift` is 1053 lines and is not allowlisted.

Overall structural health: good, with targeted refactoring needed. The highest-impact work is to finish existing abstraction migrations rather than introduce new architectural concepts.

## Abstraction Analysis

### A1. Shape rendering abstraction is partially inverted and leaves unreachable duplicate code

References:

- `Sources/DiagramKitModel/ShapeSpec.swift:219`
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:102`
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:111`
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:221`
- `Sources/DiagramKitModel/CGPathRenderer.swift:17`
- `Sources/DiagramKitModel/CGPathRenderer.swift:129`
- `Sources/DiagramKitModel/src_renderer.swift:483`

`ShapeSpecRegistry.spec(for:)` returns `aliasIndex[key] ?? fallbackSpec`, which means callers always receive a shape specification. However, `NodeShapeRenderer.shapePath(for:in:)` still treats the lookup as optional and contains a large fallback `switch shape` plus many private path builders. That fallback is effectively dead code. The same pattern appears in `src_renderer.swift`, where the `guard let spec = ShapeSpecRegistry.spec(for: shape)` fallback cannot be reached if the registry keeps returning `fallbackSpec`.

Negative impact:

- The code advertises two shape authorities, but only one is reachable.
- The ~19 private path builders in `ShapeRenderer.swift` increase maintenance cost and make renderer behavior harder to reason about.
- Future shape fixes may be applied to the fallback implementation and never affect output.
- The optional API shape implies failure semantics that no longer exist.

Recommendation:

Make `ShapeSpecRegistry.spec(for:)` non-optional and remove unreachable fallback branches from CG and SVG call sites. If a caller needs to distinguish registered shapes from fallback shapes, expose that as a separate API such as `registeredSpec(for:)`.

Illustrative refactor:

```swift
public enum ShapeSpecRegistry {
    public static func spec(for shapeName: String) -> ShapeSpec {
        aliasIndex[shapeName.lowercased()] ?? fallbackSpec
    }

    public static func registeredSpec(for shapeName: String) -> ShapeSpec? {
        aliasIndex[shapeName.lowercased()]
    }
}

public final class NodeShapeRenderer {
    public func shapePath(for shape: String, in bounds: CGRect) -> CGPath {
        let spec = ShapeSpecRegistry.spec(for: shape)
        return CGPathRenderer.makePath(
            from: spec.path(bounds, config),
            in: bounds,
            config: config
        )
    }
}
```

The private path builders in `ShapeRenderer.swift` should then be deleted unless they are covered by a live test and intentionally retained behind `registeredSpec(for:)`.

### A2. `RenderConfig` remains overburdened after font and text abstractions were introduced

References:

- `Sources/DiagramKitModel/RenderConfig.swift:200`
- `Sources/DiagramKitModel/RenderConfig.swift:216`
- `Sources/DiagramKitModel/RenderConfig.swift:322`
- `Sources/DiagramKitModel/DiagramFontResolver.swift:20`
- `Sources/DiagramKitModel/DiagramFontResolver.swift:92`
- `Sources/DiagramKitModel/DiagramFontResolver.swift:203`
- `Sources/DiagramKitRenderingCG/DiagramRenderer+ER.swift:104`
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Class.swift:259`
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Class.swift:313`

`RenderConfig` now contains `fontResolver` and `textMetrics`, and its comments explicitly say new code should prefer those abstractions. Despite that, `RenderConfig` still exposes direct font-construction methods, direct text-width estimation methods, and compatibility wrappers. Several CG renderer call sites still use `config.estimateTextWidth` and `config.edgeLabelFont` directly.

`DiagramFontResolver` is the right abstraction for deterministic font resolution and includes lock-protected helpers, but `monoFont(size:weight:)` still performs direct `BMFont` construction rather than routing through the same locked resolver pattern.

Negative impact:

- Font lookup has multiple authorities, which weakens determinism guarantees.
- New renderer code has to choose between `RenderConfig`, `DiagramFontResolver`, and `TextMetricsProvider`.
- The migration path is unclear because old APIs are still active and used by production renderers.
- Font locking and fallback behavior can diverge between proportional and monospaced paths.

Recommendation:

Treat `RenderConfig` as immutable configuration plus compatibility forwarding only. New renderer code should call `config.fontResolver` and `config.textMetrics` directly. Existing `RenderConfig` methods should either be deprecated wrappers or removed in a major version. `DiagramFontResolver.monoFont` should use the same lock-protected resolution approach as the other resolver methods.

Illustrative refactor:

```swift
extension RenderConfig {
    @available(*, deprecated, message: "Use fontResolver.defaultFont(size:weight:)")
    public func defaultFont(size: CGFloat, weight: Int = 400) -> BMFont {
        fontResolver.defaultFont(size: size, weight: weight)
    }

    @available(*, deprecated, message: "Use textMetrics.estimateTextWidth(_:fontSize:fontWeight:)")
    public func estimateTextWidth(
        _ text: String,
        fontSize: CGFloat,
        fontWeight: Int
    ) -> CGFloat {
        textMetrics.estimateTextWidth(
            text,
            fontSize: fontSize,
            fontWeight: fontWeight
        )
    }
}
```

Renderer call sites can then move toward:

```swift
let width = config.textMetrics.estimateTextWidth(
    label,
    fontSize: 14,
    fontWeight: 400
)
let font = config.fontResolver.edgeLabelFont(size: 12)
```

### A3. `LiveEditorStore` is a sample-app God object and already violates governance

References:

- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:5`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:34`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:43`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:456`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:741`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:769`
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift:806`
- `Scripts/check-file-sizes.sh`

The file header says `LiveEditorStore` owns serialized state, render lifecycle, UI interactions, export actions, clipboard/share helpers, and import behavior. The implementation confirms that it mixes render session state, export workflows, loader coordination, pasteboard operations, selection state, mutation helpers, and UI sheet coordination in one observable object.

The repository's file-size gate enforces 500 warning / 1000 error thresholds. `LiveEditorStore.swift` is 1053 lines and is not in `Scripts/check-file-sizes-allowlist.txt`, so the current codebase fails its own file-size gate.

Negative impact:

- The object is difficult to review because unrelated behaviors share the same mutation surface.
- Observation side effects are harder to reason about when render state, selection state, export state, and sheet state live together.
- The file is a merge-conflict hotspot.
- Governance failure makes unrelated future changes noisier.

Recommendation:

Split the store by responsibility while preserving a single UI-facing observable root. Because Swift extensions cannot add stored properties, move grouped state into value types or dedicated coordinator objects stored on the root.

Illustrative refactor:

```swift
@Observable
public final class LiveEditorStore {
    public var state: LiveEditorState

    public private(set) var render = RenderSessionState()
    public private(set) var selection = LiveSelectionState()

    private let exporter: LiveEditorExporting
    private let loader: LiveEditorLoading
    private let clipboard: LiveEditorClipboarding

    public init(
        state: LiveEditorState,
        exporter: LiveEditorExporting = LiveEditorExporter(),
        loader: LiveEditorLoading = LiveEditorLoader(),
        clipboard: LiveEditorClipboarding = SystemClipboard()
    ) {
        self.state = state
        self.exporter = exporter
        self.loader = loader
        self.clipboard = clipboard
    }
}

public struct RenderSessionState: Sendable {
    public var status: LiveRenderStatus = .idle
    public var parseErrorDescription: String?
    public var renderBounds: CGRect = .zero
    public var pendingSnapshot: LiveEditorState?
}
```

Prioritize extracting export and loading first, because those are the least coupled to SwiftUI observation and should reduce the file below the gate quickly.

### A4. ASCII rendering has a half-migrated abstraction boundary

References:

- `Sources/DiagramKit/AsciiDocumentRenderRegistry.swift:147`
- `Sources/DiagramKit/AsciiDocumentRenderRegistry.swift:226`
- `Sources/DiagramKit/DiagramPipeline.swift:302`
- `Sources/DiagramKit/DiagramPipeline.swift:331`
- `Sources/DiagramKit/src_ascii_index.swift:296`
- `Sources/DiagramKit/AsciiRenderRegistry.swift:264`

`AsciiDocumentRenderRegistry` describes the current state: 22 diagram families render from typed payloads and 6 still use source fallback. `DiagramPipeline.renderASCII` repeats that behavior by exporting non-Mermaid fallback documents to Mermaid and then rendering through the legacy ASCII path.

Color and theme mapping are also duplicated between `original_src_ascii_index._mapColorMode/_mapTheme` and `AsciiRenderRegistry._asciiMapColorMode/_asciiMapTheme`.

Negative impact:

- Two ASCII execution paths must be kept consistent.
- Fallback rendering can require export/reparse behavior that typed renderers avoid.
- Theme behavior can drift between document-based and source-based paths.
- The registry names imply a completed abstraction even though six families still escape it.

Recommendation:

Finish typed ASCII renderers for the remaining fallback families, then remove or deprecate the source fallback registry. Centralize theme mapping while the migration is in progress.

Illustrative refactor:

```swift
enum AsciiThemeMapper {
    static func map(
        _ mode: original_src_ascii_index.AsciiThemeColorMode
    ) -> ColorMode {
        switch mode {
        case .auto: return .auto
        case .ansi16: return .ansi16
        case .ansi256: return .ansi256
        case .truecolor: return .truecolor
        case .html: return .html
        case .none: return .none
        }
    }

    static func map(
        _ theme: original_src_ascii_index.AsciiTheme,
        includeAccentBackground: Bool = false
    ) -> original_src_ascii_types.AsciiTheme {
        original_src_ascii_types.AsciiTheme(
            text: theme.text,
            border: theme.border,
            background: theme.background,
            accent: theme.accent,
            accentBackground: includeAccentBackground ? theme.accentBackground : nil,
            colorMode: map(theme.colorMode)
        )
    }
}
```

### A5. Important abstractions are working and should be preserved

References:

- `Sources/DiagramKit/DiagramPipeline.swift:35`
- `Sources/DiagramKitImport/ImporterRegistry.swift:1`
- `Sources/DiagramKitExport/ExporterRegistry.swift:1`
- `Sources/DiagramKitExport/FlowchartExportWalker.swift:1`
- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:11`

Several abstractions are effective and should be treated as preferred patterns:

- `DiagramPipeline.runPipeline` centralizes font registration, issue reporting, parsing, layout, and error handling.
- `ImporterRegistry` and `ExporterRegistry` keep format support out of public facade methods.
- `FlowchartExportWalker` centralizes flowchart traversal logic for exporters.
- Typed diagram descriptors avoid repeated manual typed-payload handling across many families.

Recommendation:

Use these as reference patterns for future refactors. In particular, the CG renderer and bounds lookup code should move toward descriptor or registry dispatch rather than expanding large `switch` statements.

## Pattern Consistency Review

### P1. CG renderer dispatch is inconsistent with SVG and ASCII registry patterns

References:

- `Sources/DiagramKitRenderingCG/DiagramRenderer.swift:53`
- `Sources/DiagramKit/SVGRenderRegistry.swift:181`
- `Sources/DiagramKit/AsciiDocumentRenderRegistry.swift:156`
- `Sources/DiagramKitModel/DiagramBoundsLookup+PositionedGraph.swift:11`

`DiagramRenderer.render` dispatches through a large `switch positioned.content` with one branch per diagram family. SVG and ASCII rendering use descriptor registries instead. `PositionedGraph.lookup` also uses a large family switch.

Negative impact:

- Adding a diagram family requires updating multiple independent dispatch structures.
- Renderer coverage is harder to audit because CG does not advertise its supported families as data.
- The mental model differs between CG, SVG, ASCII, and bounds lookup.
- Future partial implementations can compile even when one dispatch table is missed.

Recommendation:

Introduce a `CGRenderRegistry` that mirrors `SVGRenderRegistry` and `AsciiDocumentRenderRegistry`. A similar registry can later be introduced for bounds lookup.

Illustrative refactor:

```swift
struct CGRenderDescriptor {
    let type: DiagramType
    let render: (
        DiagramRenderer,
        PositionedGraph,
        CGContext,
        CGRect
    ) -> Void
}

enum CGRenderRegistry {
    static let all: [DiagramType: CGRenderDescriptor] = [
        .classDiagram: CGRenderDescriptor(type: .classDiagram) {
            renderer,
            graph,
            context,
            bounds in
            renderer._drawClass(graph, in: context, bounds: bounds)
        }
    ]

    static func render(
        _ graph: PositionedGraph,
        renderer: DiagramRenderer,
        in context: CGContext,
        bounds: CGRect
    ) {
        guard let descriptor = all[graph.diagram.type] else { return }
        descriptor.render(renderer, graph, context, bounds)
    }
}
```

This does not need to be a public API. The main value is consistency and coverage discoverability.

### P2. `DiagramEngine` repeats bootstrap and worker-thread boilerplate

References:

- `Sources/DiagramKit/DiagramEngine.swift:50`
- `Sources/DiagramKit/DiagramEngine.swift:63`
- `Sources/DiagramKit/DiagramEngine.swift:78`
- `Sources/DiagramKit/DiagramEngine.swift:155`
- `Sources/DiagramKit/DiagramEngine.swift:183`
- `Sources/DiagramKit/DiagramEngine.swift:200`

Most public `DiagramEngine` entry points repeat the same pattern: install Apple preparer bootstrap when CoreGraphics is available, then run work on the dedicated worker thread. This pattern is an architectural invariant, but it is enforced by repetition rather than a single helper.

Negative impact:

- A future entry point can accidentally skip bootstrap or worker-thread dispatch.
- Public API additions require copying boilerplate.
- The invariant is documented externally but not represented as a single local construct.

Recommendation:

Add a private helper that wraps bootstrap plus `_runOnWorker`, then route all non-main-actor public methods through it.

Illustrative refactor:

```swift
private extension DiagramEngine {
    static func runEngine<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker(operation)
    }
}

public static func parse(_ source: String) async throws -> DiagramDocument {
    try await runEngine {
        try DiagramPipeline.parse(source)
    }
}
```

### P3. Frontmatter prefix extraction is duplicated in two nearby abstractions

References:

- `Sources/DiagramKitModel/FrontmatterBinding.swift:78`
- `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift:8`

`FrontmatterBinding.extractKey(from:prefix:)` and `FrontmatterPrefixMatcher.extractKey(from:prefix:)` implement the same prefix-stripping logic. The runner abstraction should have removed this duplication, but both versions remain active.

Negative impact:

- Minor but unnecessary drift risk in parsing frontmatter keys.
- The reusable runner abstraction is weakened by local duplication.
- Future edge-case fixes must be applied twice.

Recommendation:

Keep one implementation and forward the other to it.

Illustrative refactor:

```swift
extension FrontmatterBinding {
    static func extractKey(from key: String, prefix: String) -> String? {
        FrontmatterPrefixMatcher.extractKey(from: key, prefix: prefix)
    }
}
```

Or, if `FrontmatterBinding` is not the right owner, delete the protocol extension method and require conformers to use `FrontmatterPrefixMatcher`.

### P4. Descriptor pattern is mostly consistent, with three justified exceptions

References:

- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift:11`
- `Sources/DiagramKitModel/DiagramRegistry.swift:15`
- `Sources/DiagramKitModel/DiagramRegistry.swift:40`
- `Sources/DiagramKitModel/DiagramRegistry.swift:59`

Most diagram families use `_typed` descriptors, which is the right pattern for eliminating repeated parse/layout/render payload casts. The direct `DiagramDescriptor` exceptions are flowchart, state, and C4. These appear justified because they perform extra diagnostics, cross-family emission, or compatibility behavior that does not fit the generic helper cleanly.

Negative impact:

This is not currently a defect. The risk is that future contributors may copy a direct descriptor when `_typed` would be sufficient.

Recommendation:

Document the exception criteria near the direct descriptor definitions:

```swift
// Uses a direct descriptor instead of `_typed` because C4 parsing can emit
// Structurizr-compatible content and needs custom diagnostics before layout.
```

The rule should be: new families use `_typed` unless they need cross-family emission or pre-layout diagnostics that cannot be expressed by the helper.

### P5. Sample UI repeats a close-button pattern across sheets and full-window views

References:

- `Sources/DiagramKitSample/Views/FullWindow/CorpusBrowserView.swift:57`
- `Sources/DiagramKitSample/Views/FullWindow/ImporterProbeView.swift:57`
- `Sources/DiagramKitSample/Views/Sheets/ExportSheet.swift:59`

Multiple sample views repeat the same plain `xmark` close button styling and placement (audit drafted referenced `xmark.circle.fill`; the cited views actually use plain `xmark` — `xmark.circle.fill` is used elsewhere in the sample for the search-field clear button, a different pattern).

Negative impact:

- Low severity, but it causes visual drift and repetitive UI code.
- Accessibility and hit-target improvements must be applied multiple times.

Recommendation:

Extract a small reusable component.

Illustrative refactor:

```swift
struct HeaderCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close")
    }
}
```

## Duplication and Reuse Audit

### D1. Shape path duplication is the largest genuine redundancy

References:

- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:111`
- `Sources/DiagramKitRenderingCG/ShapeRenderer.swift:221`
- `Sources/DiagramKitModel/CGPathRenderer.swift:17`
- `Sources/DiagramKitModel/CGPathRenderer.swift:129`
- `Sources/DiagramKitModel/ShapeSpec.swift:219`

This is genuine redundancy, not acceptable repetition. Shape geometry should have one source of truth: `ShapeSpecRegistry` plus path serializers/renderers. The fallback shape builders in `ShapeRenderer.swift` are unreachable because the registry always returns `fallbackSpec`.

Duplication estimate:

- One large fallback switch.
- ~19 private shape-builder helpers in `ShapeRenderer.swift`.
- Parallel path-construction behavior in `CGPathRenderer`.

Recommendation:

Remove the unreachable fallback and add focused regression tests that assert unknown shapes use the registry fallback. This turns a large duplicated implementation into a single-source-of-truth contract.

Illustrative test:

```swift
func testUnknownShapeUsesFallbackSpec() {
    let unknown = ShapeSpecRegistry.spec(for: "not-a-shape")
    let fallback = ShapeSpecRegistry.spec(for: "rect")

    XCTAssertEqual(unknown.kind, fallback.kind)
}
```

### D2. Long-tail bounds lookup repeats bounding-box loops instead of using the shared geometry helper

References:

- `Sources/DiagramKitCommon/DiagramGeometry.swift:106`
- `Sources/DiagramKitModel/DiagramBoundsLookup+LongTail.swift:50`
- `Sources/DiagramKitModel/DiagramBoundsLookup+LongTail.swift:85`
- `Sources/DiagramKitModel/DiagramBoundsLookup+LongTail.swift:128`
- `Sources/DiagramKitModel/DiagramBoundsLookup+LongTail.swift:355`

`DiagramRect.bounding(points:paddedBy:)` already exists, but several long-tail bounds lookup implementations manually compute min/max over edge points. These loops differ slightly in padding and minimum extents.

Negative impact:

- Hit-testing and stable element bounds can drift across families.
- Future fixes to point bounds behavior must be repeated.
- Repeated loops obscure the family-specific logic.

Recommendation:

Add a small `CGPoint` convenience overload or convert to `DiagramPoint`, then reuse it from every long-tail edge implementation.

Illustrative refactor:

```swift
extension DiagramRect {
    static func boundingCG(
        points: [CGPoint],
        paddedBy padding: Double = 0,
        minimumExtent: Double = 0
    ) -> DiagramRect {
        let rect = bounding(
            points: points.map { DiagramPoint(x: Double($0.x), y: Double($0.y)) },
            paddedBy: padding
        )

        return DiagramRect(
            x: rect.x,
            y: rect.y,
            width: max(rect.width, minimumExtent),
            height: max(rect.height, minimumExtent)
        )
    }
}
```

### D3. `DiagramPipeline` repeats SVG render setup and theme conversion

References:

- `Sources/DiagramKit/DiagramPipeline.swift:232`
- `Sources/DiagramKit/DiagramPipeline.swift:264`
- `Sources/DiagramKit/DiagramPipeline.swift:323`
- `Sources/DiagramKitModel/CrossPlatform.swift:148`

Both `renderSVG(source:)` and `renderSVG(positioned:)` build `DiagramColors` from `RenderConfig.theme` inline. `renderASCII` separately builds an ASCII theme using `hexString`, while `BMColor` also exposes CSS-oriented color serialization that can preserve alpha semantics better than a plain hex round-trip.

Negative impact:

- Small but unnecessary duplication in a central pipeline file.
- Theme conversion behavior can drift between SVG and ASCII.
- Alpha handling is easy to overlook when every pipeline path performs conversion manually.

Recommendation:

Extract theme conversion helpers and use them from every render path.

Illustrative refactor:

```swift
private extension DiagramColors {
    init(renderTheme theme: RenderTheme) {
        self.init(
            background: theme.background,
            primary: theme.primary,
            secondary: theme.secondary,
            accent: theme.accent
        )
    }
}

private extension original_src_ascii_index.AsciiTheme {
    init(renderTheme theme: RenderTheme) {
        self.init(
            text: theme.primary.cssColorString,
            border: theme.secondary.cssColorString,
            background: theme.background.cssColorString,
            accent: theme.accent.cssColorString,
            colorMode: .html
        )
    }
}
```

### D4. Diagram editor mutation flows duplicate the same transaction pattern

References:

- `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift:47`
- `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift:162`
- `Sources/DiagramKitInteractive/DiagramEditor+Gantt.swift:91`
- `Sources/DiagramKitInteractive/DiagramEditor+Sequence.swift:94`

Several editor mutation paths repeat the same workflow: create or mutate a typed document, export it, map export diagnostics or errors, capture the old snapshot, commit the new document/source/diagnostics, update selection, register undo, and set an action name.

Negative impact:

- Undo registration semantics can drift by diagram family.
- Diagnostics handling can become inconsistent.
- New family-specific editors have to copy transaction boilerplate.

Recommendation:

Introduce a private transaction helper that accepts the new document, diagnostics, action name, and selection update.

Illustrative refactor:

```swift
private struct MutationCommit {
    let document: DiagramDocument
    let diagnostics: [DiagramDiagnostic]
    let actionName: String
    let selection: DiagramSelection?
}

@MainActor
private func _commitMutation(_ commit: MutationCommit) async throws {
    let export = try await _exportAsync(commit.document)
    let old = _snapshot()

    _commitDocument(commit.document)
    _commitSource(export.source)
    _commitDiagnostics(commit.diagnostics + export.diagnostics)
    selection = commit.selection

    _registerUndo(restoring: old, actionName: commit.actionName)
}
```

Family-specific methods should prepare the typed document and then call the helper.

### D5. Frontmatter bindings contain acceptable boilerplate, with one reuse opportunity

References:

- `Sources/DiagramKitModel/FrontmatterBinding.swift:1`
- `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift:1`
- `Sources/DiagramKitModel/FrontmatterBinding.swift:78`
- `Sources/DiagramKitModel/FrontmatterBinding+Runners.swift:8`

Most frontmatter binding repetition is acceptable because each family maps different keys and domain-specific values. The duplication that should be removed is the prefix extraction helper already covered in P3.

Recommendation:

Avoid over-generalizing family-specific bindings into a declarative schema until there are more repeated validation rules. The current explicit mapping is easier to audit than a premature generic DSL. Only centralize mechanical helpers such as prefix extraction and common numeric parsing.

### D6. Large JS-ported parser files are acceptable technical debt when isolated and allowlisted

References:

- `Sources/DiagramKitModel/src_class_parser.swift:1`
- `Sources/DiagramKitModel/src_zenuml_parser.swift:1`
- `Sources/DiagramKitModel/src_er_parser.swift:1`
- `Sources/DiagramKitModel/src_parser.swift:1`
- `Scripts/check-file-sizes-allowlist.txt`

Several `src_*` files exceed 1000 lines and are allowlisted. This is acceptable repetition and size debt if they are faithful ports of upstream parser modules and are not being used as models for new native code.

Negative impact:

- Large parser files remain hard to review.
- Generated or ported style can leak into hand-written native modules if not clearly marked.

Recommendation:

Keep these files allowlisted only when they are intentionally port-faithful. For new native code, continue enforcing the file-size gate. Add short file headers where missing to distinguish ported compatibility code from preferred native architecture.

## Prioritized Refactoring Roadmap

### Priority 0: Restore the file-size gate by splitting `LiveEditorStore`

Impact: high maintainability, high developer productivity.

Actions:

1. Extract export behavior from `LiveEditorStore` into `LiveEditorExporter`.
2. Extract loading/import behavior into `LiveEditorLoader`.
3. Group render session state into `RenderSessionState`.
4. Re-run `Scripts/check-file-sizes.sh` until the gate passes.

Expected outcome: the sample app becomes easier to modify, and the repository returns to a passing governance baseline.

### Priority 1: Remove unreachable shape fallback code and make shape lookup semantics explicit

Impact: high maintainability, medium scalability.

Actions:

1. Change `ShapeSpecRegistry.spec(for:)` to return `ShapeSpec` instead of `ShapeSpec?`.
2. Add `registeredSpec(for:)` if any caller needs nil semantics.
3. Delete the unreachable fallback switch and private path builders in `ShapeRenderer.swift`.
4. Add tests for unknown-shape fallback behavior.

Expected outcome: shape rendering has one source of truth and less dead code.

### Priority 1: Finish the font/text abstraction migration

Impact: high maintainability, high rendering determinism.

Actions:

1. Route all font construction through `DiagramFontResolver`.
2. Route text measurement through `TextMetricsProvider`.
3. Deprecate or remove direct `RenderConfig` compatibility methods.
4. Update CG renderer call sites that still use `config.estimateTextWidth` and direct font helpers.

Expected outcome: renderer code has a clear, deterministic font and measurement path.

### Priority 2: Align CG renderer dispatch with descriptor registries

Impact: medium maintainability, high scalability for new families.

Actions:

1. Introduce internal `CGRenderRegistry`.
2. Move `DiagramRenderer.render` family dispatch into descriptors.
3. Add a coverage assertion that all supported `DiagramType` cases have matching CG descriptors where intended.
4. Consider a follow-on `BoundsLookupRegistry`.

Expected outcome: CG, SVG, and ASCII render dispatch follow the same architectural pattern.

### Priority 2: Centralize interactive editor mutation commits

Impact: medium maintainability, medium defect reduction.

Actions:

1. Add a private mutation transaction helper.
2. Migrate flowchart, sequence, gantt, and generic mutation paths.
3. Add targeted tests for undo and diagnostics behavior.

Expected outcome: family-specific editors focus on domain mutations instead of repeated commit mechanics.

### Priority 3: Complete typed ASCII renderer migration

Impact: medium maintainability, medium runtime predictability.

Actions:

1. Implement typed ASCII renderers for the six fallback families.
2. Remove lazy Mermaid export fallback from `DiagramPipeline.renderASCII`.
3. Centralize ASCII theme mapping.

Expected outcome: ASCII rendering no longer depends on source fallback behavior and becomes easier to reason about.

### Priority 3: Reuse `DiagramRect.bounding` in long-tail bounds lookup

Impact: low-to-medium maintainability, low risk.

Actions:

1. Add a `CGPoint` convenience overload.
2. Replace manual min/max loops in `DiagramBoundsLookup+LongTail.swift`.
3. Keep family-specific padding and minimum extent as explicit call-site parameters.

Expected outcome: less duplicated geometry code and more consistent hit-target behavior.

### Priority 4: Clean up small helper and sample UI duplication

Impact: low maintainability, low risk.

Actions:

1. Forward or delete duplicate frontmatter prefix extraction.
2. Extract `HeaderCloseButton` in the sample app.
3. Keep domain-specific frontmatter bindings explicit unless more repeated validation rules emerge.

Expected outcome: minor reduction in drift and visual inconsistency without over-abstracting small code.

## Closing Assessment

DiagramKit's core architecture is sound. The package already has the right major boundaries: common geometry and color types, model-level descriptors, import/export registries, renderer-specific products, and platform-guarded Apple rendering/UI modules. The main opportunity is consolidation: finish migrations that are already underway, remove dead compatibility code, and make the strongest existing patterns the default for new work.

The recommended roadmap intentionally starts with changes that restore governance and delete unreachable code before broader registry alignment. That sequencing should produce immediate maintenance wins while keeping rendering behavior protected by the existing snapshot suite.

## Remediation Status (2026-05-18)

The prioritized roadmap above landed as a series of commits on `main`. Findings are paired with their shipping commit below; two are partially deferred and noted as such.

| Finding | Priority | Status | Commit |
|---|---|---|---|
| A3 — Split `LiveEditorStore` (restore gate) | P0 | Landed | `5e783aa` |
| A1 + D1 — Remove unreachable shape fallback | P1 | Landed | `65efa2f` |
| A2 — Finish font/text resolver migration | P1 | Landed | `a3939aa` |
| P1 — `CGRenderRegistry` alignment | P2 | Landed | `75560fa` |
| D4 — Centralize `DiagramEditor` mutation commits | P2 | Landed | `8a5d7db` |
| A4 — Typed ASCII renderers for 6 source-fallback families | P3 | **Partial** — theme-mapper dedup landed (`5256079`); typed renderer migration deferred (each family's typed payload differs from the ASCII renderer's internal model, so per-family converters belong in follow-up commits with their own snapshot review). |
| D2 — Reuse `DiagramRect.bounding` in long-tail bounds | P3 | Landed | `761454d` |
| P3 — Forward `FrontmatterBinding.extractKey` | P4 | Landed | `95c7970` |
| P5 — Extract `HeaderCloseButton` (corrected icon) | P4 | Landed | `c9c376c` |
| P2 — `DiagramEngine._runEngine` helper | P4 | Landed | `e38e7f6` |
| D3 — Centralize theme conversion in `DiagramPipeline` | P4 | **Partial** — SVG `_diagramColors` helper landed (`c0cacf4`); the ASCII path's `hexString` → `cssColorString` alpha-handling change deferred (no-op for alpha-1.0 corpus today, but a behavior change in principle and belongs in its own commit). |

A5, D5, D6 were observational findings (preserved patterns / acceptable repetition / allowlisted ports) and required no code changes.
