// Ported from original/src/layout.ts
//
// Public entry points for the ELK-backed flowchart/state layout pipeline
// plus the shared `_LayoutDiagnostics` accumulator and the
// `_MAX_SUBGRAPH_RECURSION_DEPTH` cap that subgraph-walking helpers honor.
//
// The implementation is split across four files in this target (audit A2):
//   - src_layout_factory.swift     — ELK graph construction
//   - src_layout_runner.swift      — ELK invocation + fallback orchestration
//   - src_layout_extractor.swift   — ELK result → PositionedGraph conversion
//   - src_layout_postprocess.swift — edge segment collection / orthogonalize /
//                                    layer align / fan-in-out trunk bundling
import Foundation
import DiagramKitCommon

/// Soft cap on nested-subgraph recursion. The 8 MB worker stack tolerates
/// deeper nesting, but pathological input shouldn't be able to exhaust it
/// without a diagnostic. Reaching the cap reports an issue and truncates
/// the traversal rather than continuing.
let _MAX_SUBGRAPH_RECURSION_DEPTH = 1024

/// Mutable accumulator for layout-time non-fatal diagnostics. Created at the
/// entry of `_layoutGraphSyncFromLayoutEngine`, threaded as an optional
/// parameter through subgraph-walking helpers.
///
/// Concurrency Contract: each `_layoutGraphSyncFromLayoutEngine` call runs
/// on its own fresh worker thread (the 8 MB-per-call invariant in
/// `DiagramEngine._runOnWorker` / `DiagramWorkerThread.run`). The instance
/// is created on that worker, mutated only by the synchronous layout walk
/// on the same worker, and never escapes. No cross-thread access ever
/// happens, so `@unchecked Sendable` is safe.
final class _LayoutDiagnostics: @unchecked Sendable {
    var items: [DiagramDiagnostic] = []

    func warn(_ message: String) {
        // Layout-tier diagnostic helper. Flowchart subgraph recursion
        // truncation is the load-bearing caller — .subgraphFlatten covers it.
        items.append(.lossyTransform(.subgraphFlatten, message: message, location: nil))
    }
}

typealias _ParsedGraph = original_src_types.MermaidGraph
typealias _ParsedEdge = original_src_types.MermaidEdge

// Positioned-graph payload types moved to DiagramKitModel/PositionedPayloads.swift

public func layoutGraphSync(
    _ graph: DiagramDocument,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    // layout.ts re-exports layout-engine.ts; route through the same public entry.
    return try _layoutGraphSyncEntry(graph, options)
}

/// Overload that accepts LayoutConfig to control ELK spacing parameters.
public func layoutGraphSync(
    _ graph: DiagramDocument,
    config: LayoutConfig
) throws -> PositionedGraph {
    return try _layoutGraphSyncWithConfig(graph, config)
}

public func layoutGraphWithDiagnosticsSync(
    _ graph: DiagramDocument,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    return try _layoutGraphWithDiagnosticsEntry(graph, options)
}

private func _layoutGraphSyncEntry(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _layoutGraphWithDiagnosticsEntry(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphWithDiagnosticsSyncFromLayoutEngine(graph, options)
}

final class original_src_layout {
    public init() {}

    // Export inventory from TypeScript source:
    // - export { layoutGraphSync } from './layout-engine.ts'
    public static func layoutGraphSync(
        _ graph: DiagramDocument,
        _ options: RenderOptions = RenderOptions()
    ) throws -> PositionedGraph {
        try _layoutGraphSyncEntry(graph, options)
    }
}
