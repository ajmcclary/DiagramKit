import Foundation
import DiagramKitCommon
import DiagramKitModel

// MARK: - FlowchartExportSink

/// A per-format collector that observes a flowchart traversal and
/// produces format-specific source. Implementations buffer output in
/// their own storage; the walker only invokes the lifecycle methods in
/// order.
public protocol FlowchartExportSink {
    /// Called once before any node or edge. `title` is the document
    /// title, if any. Format-specific preamble (e.g. `digraph G {`)
    /// goes here.
    mutating func begin(title: String?)

    /// Called once after `begin`. Emits the direction declaration
    /// (`rankdir=LR`, `direction: down`, …).
    mutating func direction(_ direction: original_src_types.Direction)

    /// Called once per node in source order.
    mutating func node(id: String, node: original_src_types.MermaidNode)

    /// Called once per edge in source order.
    mutating func edge(_ edge: original_src_types.MermaidEdge)

    /// Whether this sink emits subgraph clustering output. When false,
    /// the walker surfaces a `.warning` diagnostic listing the dropped
    /// subgraphs. Default: `false`.
    var handlesSubgraphs: Bool { get }

    /// Called once per subgraph before walking its children. `depth`
    /// counts nesting: 0 for top-level subgraphs, 1+ for nested.
    /// Default no-op. Override to emit container syntax (D2
    /// `subgraph: {`, DOT `subgraph cluster_… {`).
    mutating func subgraphBegin(_ subgraph: original_src_types.MermaidSubgraph, depth: Int)

    /// Called once per subgraph after walking its children. Default
    /// no-op. Override to emit closing container syntax.
    mutating func subgraphEnd(_ subgraph: original_src_types.MermaidSubgraph, depth: Int)

    /// Called once after the last edge. Format-specific postamble
    /// (e.g. closing `}`) goes here.
    mutating func end()
}

public extension FlowchartExportSink {
    var handlesSubgraphs: Bool { false }
    mutating func subgraphBegin(_ subgraph: original_src_types.MermaidSubgraph, depth: Int) {}
    mutating func subgraphEnd(_ subgraph: original_src_types.MermaidSubgraph, depth: Int) {}
}

// MARK: - FlowchartExportWalker

/// Stateless walker that drives a `FlowchartExportSink` through the
/// canonical flowchart traversal order: begin → direction → nodes →
/// edges → subgraphs → end. Used by D2 and Graphviz DOT exporters;
/// future flowchart-format exporters can adopt the same walk.
public enum FlowchartExportWalker {
    @discardableResult
    public static func walk<Sink: FlowchartExportSink>(
        _ model: ParsedGraphModel,
        title: String?,
        into sink: inout Sink
    ) -> [DiagramDiagnostic] {
        sink.begin(title: title)
        sink.direction(model.direction)
        for (id, node) in model.nodesInOrder {
            sink.node(id: id, node: node)
        }
        for edge in model.edges {
            sink.edge(edge)
        }
        var diagnostics: [DiagramDiagnostic] = []
        walkSubgraphs(
            model.subgraphs,
            depth: 0,
            into: &sink,
            sinkHandlesSubgraphs: sink.handlesSubgraphs,
            diagnostics: &diagnostics
        )
        sink.end()
        return diagnostics
    }

    private static func walkSubgraphs<Sink: FlowchartExportSink>(
        _ subgraphs: [original_src_types.MermaidSubgraph],
        depth: Int,
        into sink: inout Sink,
        sinkHandlesSubgraphs: Bool,
        diagnostics: inout [DiagramDiagnostic]
    ) {
        for sg in subgraphs {
            if sinkHandlesSubgraphs {
                sink.subgraphBegin(sg, depth: depth)
                walkSubgraphs(
                    sg.children,
                    depth: depth + 1,
                    into: &sink,
                    sinkHandlesSubgraphs: sinkHandlesSubgraphs,
                    diagnostics: &diagnostics
                )
                sink.subgraphEnd(sg, depth: depth)
            } else {
                diagnostics.append(
                    .lossyTransform(
                        .subgraphFlatten,
                        message: "Subgraph '\(sg.id)' dropped — exporter does not yet support subgraph emission"
                    )
                )
                walkSubgraphs(
                    sg.children,
                    depth: depth + 1,
                    into: &sink,
                    sinkHandlesSubgraphs: sinkHandlesSubgraphs,
                    diagnostics: &diagnostics
                )
            }
        }
    }
}
