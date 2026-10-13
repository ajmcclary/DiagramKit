import Foundation
import DiagramKitModel
import DiagramKitCommon
#if canImport(CoreGraphics)
import DiagramKitRenderingCG
#endif

/// SPI (underscore-prefixed per the package convention): direct access to
/// the layout dispatch table. `layout` skips the two load-bearing pipeline
/// invariants unless invoked through `DiagramPipeline` / `DiagramEngine`:
///
/// 1. **Worker-thread dispatch** — layout recursion (nested flowchart
///    subgraphs) can exceed the cooperative thread pool's ~512 KB stack
///    budget, so callers on a structured-concurrency task must route
///    through `DiagramEngine.*` / `DiagramImageRenderer.*`, which dispatch
///    onto the fresh 8 MB-stack `DiagramWorkerThread`. This type cannot
///    enforce that (it is synchronous); it is documented here instead.
/// 2. **Bundled-font registration** — enforced directly: `layout` calls
///    `DiagramFontRegistry.registerBundledFontsIfNeeded()` first, the same
///    guarantee `DiagramPipeline.runPipeline` applies (layout measures
///    text through CoreText).
///
/// In-package callers (umbrella pipeline, tests) use `_GraphLayout`
/// directly. External callers should use `DiagramPipeline.layout(...)` /
/// `DiagramEngine.*`; the deprecated `GraphLayout` typealias keeps their
/// sources compiling.
public struct _GraphLayout {
    public var config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    /// Layout a parsed graph into positioned geometry.
    /// Delegates to `DiagramRegistry.descriptor(for:)` so the registry is the
    /// single source of truth for layout dispatch. Adding a diagram type now
    /// requires only an entry in `DiagramRegistry.all` — no switch changes.
    public func layout(_ graph: DiagramDocument) throws -> PositionedGraph {
        #if canImport(CoreGraphics)
        DiagramFontRegistry.registerBundledFontsIfNeeded()
        #endif
        return try _withDiagramIssueReporting(operation: "GraphLayout.layout") {
            let descriptor = try DiagramRegistry.descriptor(for: graph.type)
            let (positioned, diagnostics) = try descriptor.layout(graph, config)
            var result = positioned
            result.diagnostics = diagnostics
            return result
        }
    }
}

/// Deprecated compatibility alias for `_GraphLayout` (which is the SPI
/// definition). Prefer `DiagramPipeline.layout(...)` / `DiagramEngine.*`,
/// which add worker-thread dispatch on top of the raw layout call.
@available(*, deprecated, renamed: "_GraphLayout", message: "GraphLayout is SPI; use DiagramPipeline.layout / DiagramEngine, which dispatch onto the 8 MB-stack worker.")
public typealias GraphLayout = _GraphLayout
