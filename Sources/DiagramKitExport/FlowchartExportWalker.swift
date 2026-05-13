import Foundation
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

    /// Called once after the last edge. Format-specific postamble
    /// (e.g. closing `}`) goes here.
    mutating func end()
}

// MARK: - FlowchartExportWalker

/// Stateless walker that drives a `FlowchartExportSink` through the
/// canonical flowchart traversal order: begin → direction → nodes →
/// edges → end. Used by D2 and Graphviz DOT exporters; future
/// flowchart-format exporters can adopt the same walk.
public enum FlowchartExportWalker {
    public static func walk<Sink: FlowchartExportSink>(
        _ model: ParsedGraphModel,
        title: String?,
        into sink: inout Sink
    ) {
        sink.begin(title: title)
        sink.direction(model.direction)
        for (id, node) in model.nodesInOrder {
            sink.node(id: id, node: node)
        }
        for edge in model.edges {
            sink.edge(edge)
        }
        sink.end()
    }
}
