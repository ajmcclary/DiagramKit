import Foundation
import DiagramKitCommon

public struct GraphLayout {
    public var config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    /// Layout a parsed graph into positioned geometry.
    /// Delegates to `DiagramRegistry.descriptor(for:)` so the registry is the
    /// single source of truth for layout dispatch. Adding a diagram type now
    /// requires only an entry in `DiagramRegistry.all` — no switch changes.
    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "GraphLayout.layout") {
            let descriptor = try DiagramRegistry.descriptor(for: graph.type)
            return try descriptor.layout(graph, config)
        }
    }
}
