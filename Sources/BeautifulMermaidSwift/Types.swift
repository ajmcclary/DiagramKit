import Foundation
import CoreGraphics

public enum DiagramType: String, CaseIterable, Sendable {
    case flowchart
    case stateDiagram
    case sequenceDiagram
    case classDiagram
    case erDiagram
    case xyChart
    case pie
    case journey
    case gantt
    case quadrantChart
    case requirement
    case gitGraph
    case mindmap
    case timeline
    case sankey
    case block
    case packet
    case kanban
    case architecture
}

/// The parsed graph model for flowcharts and state diagrams.
public typealias ParsedGraphModel = original_src_types.MermaidGraph

/// Type-safe diagram payload. Use pattern matching to access the parsed model.
public enum DiagramPayload: Sendable {
    case flowchart(ParsedGraphModel)
    case stateDiagram(ParsedGraphModel)
    case sequenceDiagram(SequenceDiagram)
    case classDiagram(ClassDiagram)
    case erDiagram(ErDiagram)
    case xyChart(XYChart)
    case pie(PieChart)
    case journey(JourneyDiagram)
    case gantt(GanttDiagram)
    case quadrantChart(QuadrantChart)
    case requirement(RequirementDiagram)
    case gitGraph(GitGraphDiagram)
    case mindmap(MindmapDiagram)
    case timeline(TimelineDiagram)
    case sankey(SankeyDiagram)
    case block(BlockDiagram)
    case packet(PacketDiagram)
    case kanban(KanbanDiagram)
    case architecture(ArchitectureDiagram)

    public var type: DiagramType {
        switch self {
        case .flowchart:
            return .flowchart
        case .stateDiagram:
            return .stateDiagram
        case .sequenceDiagram:
            return .sequenceDiagram
        case .classDiagram:
            return .classDiagram
        case .erDiagram:
            return .erDiagram
        case .xyChart:
            return .xyChart
        case .pie:
            return .pie
        case .journey:
            return .journey
        case .gantt:
            return .gantt
        case .quadrantChart:
            return .quadrantChart
        case .requirement:
            return .requirement
        case .gitGraph:
            return .gitGraph
        case .mindmap:
            return .mindmap
        case .timeline:
            return .timeline
        case .sankey:
            return .sankey
        case .block:
            return .block
        case .packet:
            return .packet
        case .kanban:
            return .kanban
        case .architecture:
            return .architecture
        }
    }
}

public struct MermaidGraph: Sendable {
    public var payload: DiagramPayload

    public var type: DiagramType {
        payload.type
    }

    /// Type-safe access to the parsed diagram model.
    /// Use pattern matching to access the typed data:
    /// ```swift
    /// let graph = try await MermaidRenderer.parse(source)
    /// switch graph.typedPayload {
    /// case .flowchart(let model): // ...
    /// case .sequenceDiagram(let seq): // ...
    /// }
    /// ```
    public var typedPayload: DiagramPayload {
        payload
    }

    public init(payload: DiagramPayload) {
        self.payload = payload
    }

    public init(type: DiagramType = .flowchart) {
        switch type {
        case .flowchart:
            self.payload = .flowchart(Self.emptyParsedGraph())
        case .stateDiagram:
            self.payload = .stateDiagram(Self.emptyParsedGraph())
        case .sequenceDiagram:
            self.payload = .sequenceDiagram(SequenceDiagram(actors: [], messages: [], blocks: [], notes: []))
        case .classDiagram:
            self.payload = .classDiagram(ClassDiagram(classes: [], relationships: [], namespaces: []))
        case .erDiagram:
            self.payload = .erDiagram(ErDiagram(entities: [], relationships: []))
        case .xyChart:
            self.payload = .xyChart(XYChart())
        case .pie:
            self.payload = .pie(PieChart())
        case .journey:
            self.payload = .journey(JourneyDiagram())
        case .gantt:
            self.payload = .gantt(GanttDiagram.empty)
        case .quadrantChart:
            self.payload = .quadrantChart(QuadrantChart())
        case .requirement:
            self.payload = .requirement(RequirementDiagram(requirements: [], elements: [], relationships: [], classDefs: [], direction: .TB, config: RequirementDiagramConfig()))
        case .gitGraph:
            self.payload = .gitGraph(GitGraphDiagram())
        case .mindmap:
            self.payload = .mindmap(MindmapDiagram.empty)
        case .timeline:
            self.payload = .timeline(TimelineDiagram.empty)
        case .sankey:
            self.payload = .sankey(SankeyDiagram.empty)
        case .block:
            self.payload = .block(BlockDiagram.empty)
        case .packet:
            self.payload = .packet(PacketDiagram.empty)
        case .kanban:
            self.payload = .kanban(KanbanDiagram(nodes: [], sections: [], config: KanbanDiagramConfig()))
        case .architecture:
            self.payload = .architecture(ArchitectureDiagram.empty)
        }
    }

    private static func emptyParsedGraph() -> ParsedGraphModel {
        ParsedGraphModel(direction: .TD, nodesInOrder: [], edges: [])
    }
}

// MARK: - Public type aliases (drop underscore prefix)

/// A positioned node in a flowchart or state diagram.
public typealias PositionedNode = _PositionedNodePayload
/// A positioned edge in a flowchart or state diagram.
public typealias PositionedEdge = _PositionedEdgePayload
/// A positioned group (subgraph) in a flowchart or state diagram.
public typealias PositionedGroup = _PositionedGroupPayload
/// A positioned point (x, y coordinate).
public typealias PositionedPoint = _PositionedPointPayload

/// Type-safe positioned diagram content. Use pattern matching to access layout results.
public enum PositionedContent: Sendable {
    case flowchart(
        nodes: [PositionedNode],
        edges: [PositionedEdge],
        groups: [PositionedGroup]
    )
    case stateDiagram(
        nodes: [PositionedNode],
        edges: [PositionedEdge],
        groups: [PositionedGroup]
    )
    case sequenceDiagram(
        actors: [PositionedSequenceActor],
        messages: [PositionedSequenceMessage],
        blocks: [PositionedSequenceBlock],
        lifelines: [SequenceLifeline],
        activations: [SequenceActivation],
        notes: [PositionedSequenceNote],
        boxes: [PositionedSequenceBox],
        bottomActors: [PositionedSequenceActor],
        rectHighlights: [PositionedRectHighlight],
        title: String?,
        accTitle: String?,
        accDescr: String?
    )
    case classDiagram(
        classes: [PositionedClassNode],
        relationships: [PositionedClassRelationship],
        namespaces: [PositionedClassNamespace],
        notes: [PositionedClassNote],
        accTitle: String?,
        accDescr: String?,
        diagramTitle: String?
    )
    case erDiagram(
        entities: [PositionedErEntity],
        relationships: [PositionedErRelationship],
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil
    )
    case xyChart(PositionedXYChart)
    case pie(PositionedPieChart)
    case journey(PositionedJourneyDiagram)
    case gantt(PositionedGanttDiagram)
    case quadrantChart(PositionedQuadrantChart)
    case requirement(PositionedRequirementDiagram)
    case gitGraph(PositionedGitGraphDiagram)
    case mindmap(PositionedMindmapDiagram)
    case timeline(PositionedTimelineDiagram)
    case sankey(PositionedSankeyDiagram)
    case block(PositionedBlockDiagram)
    case packet(PositionedPacketDiagram)
    case kanban(PositionedKanbanDiagram)
    case architecture(PositionedArchitectureDiagram)
}

public struct PositionedGraph: Sendable {
    public var diagram: MermaidGraph
    public var width: Double
    public var height: Double
    /// Type-safe positioned content. Use pattern matching to access layout results:
    /// ```swift
    /// let graph = try await MermaidRenderer.layout(source)
    /// switch graph.content {
    /// case .flowchart(let nodes, let edges, let groups):
    ///     // use nodes, edges, groups directly
    /// case .sequenceDiagram(let actors, let messages, ...):
    ///     // ...
    /// }
    /// ```
    public var content: PositionedContent

    public init(diagram: MermaidGraph, width: Double = 0, height: Double = 0, content: PositionedContent) {
        self.diagram = diagram
        self.width = width
        self.height = height
        self.content = content
    }

    /// Convenience initializer that creates an empty positioned graph based on the diagram type.
    public init(diagram: MermaidGraph, width: Double = 0, height: Double = 0) {
        self.diagram = diagram
        self.width = width
        self.height = height
        switch diagram.type {
        case .flowchart:
            self.content = .flowchart(nodes: [], edges: [], groups: [])
        case .stateDiagram:
            self.content = .stateDiagram(nodes: [], edges: [], groups: [])
        case .sequenceDiagram:
            self.content = .sequenceDiagram(actors: [], messages: [], blocks: [], lifelines: [], activations: [], notes: [], boxes: [], bottomActors: [], rectHighlights: [], title: nil, accTitle: nil, accDescr: nil)
        case .classDiagram:
            self.content = .classDiagram(classes: [], relationships: [], namespaces: [], notes: [], accTitle: nil, accDescr: nil, diagramTitle: nil)
        case .erDiagram:
            self.content = .erDiagram(entities: [], relationships: [], accTitle: nil, accDescr: nil, diagramTitle: nil)
        case .xyChart:
            self.content = .xyChart(.empty)
        case .pie:
            self.content = .pie(.empty)
        case .journey:
            self.content = .journey(.empty)
        case .gantt:
            self.content = .gantt(.empty)
        case .quadrantChart:
            self.content = .quadrantChart(.empty)
        case .requirement:
            self.content = .requirement(PositionedRequirementDiagram(width: 0, height: 0, nodes: [], edges: [], config: RequirementDiagramConfig()))
        case .gitGraph:
            self.content = .gitGraph(.empty)
        case .mindmap:
            self.content = .mindmap(.empty)
        case .timeline:
            self.content = .timeline(.empty)
        case .sankey:
            self.content = .sankey(.empty)
        case .block:
            self.content = .block(.empty)
        case .packet:
            self.content = .packet(.empty)
        case .kanban:
            self.content = .kanban(.empty)
        case .architecture:
            self.content = .architecture(.empty)
        }
    }

    // MARK: - Typed accessors (convenience)

    /// Flowchart/state diagram positioned nodes (nil for other diagram types).
    public var flowchartNodes: [PositionedNode]? {
        switch content {
        case .flowchart(let nodes, _, _), .stateDiagram(let nodes, _, _): return nodes
        default: return nil
        }
    }
    /// Flowchart/state diagram positioned edges (nil for other diagram types).
    public var flowchartEdges: [PositionedEdge]? {
        switch content {
        case .flowchart(_, let edges, _), .stateDiagram(_, let edges, _): return edges
        default: return nil
        }
    }
    /// Flowchart/state diagram positioned groups (nil for other diagram types).
    public var flowchartGroups: [PositionedGroup]? {
        switch content {
        case .flowchart(_, _, let groups), .stateDiagram(_, _, let groups): return groups
        default: return nil
        }
    }

    public var sequenceActors: [PositionedSequenceActor]? {
        switch content {
        case .sequenceDiagram(let actors, _, _, _, _, _, _, _, _, _, _, _): return actors
        default: return nil
        }
    }
    public var sequenceMessages: [PositionedSequenceMessage]? {
        switch content {
        case .sequenceDiagram(_, let messages, _, _, _, _, _, _, _, _, _, _): return messages
        default: return nil
        }
    }
    public var sequenceBlocks: [PositionedSequenceBlock]? {
        switch content {
        case .sequenceDiagram(_, _, let blocks, _, _, _, _, _, _, _, _, _): return blocks
        default: return nil
        }
    }
    public var seqLifelines: [SequenceLifeline] {
        switch content {
        case .sequenceDiagram(_, _, _, let lifelines, _, _, _, _, _, _, _, _): return lifelines
        default: return []
        }
    }
    public var seqActivations: [SequenceActivation] {
        switch content {
        case .sequenceDiagram(_, _, _, _, let activations, _, _, _, _, _, _, _): return activations
        default: return []
        }
    }
    public var seqNotes: [PositionedSequenceNote] {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, let notes, _, _, _, _, _, _): return notes
        default: return []
        }
    }
    public var seqBoxes: [PositionedSequenceBox] {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, let boxes, _, _, _, _, _): return boxes
        default: return []
        }
    }
    public var seqBottomActors: [PositionedSequenceActor] {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, _, let bottomActors, _, _, _, _): return bottomActors
        default: return []
        }
    }
    public var seqRectHighlights: [PositionedRectHighlight] {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, _, _, let rectHighlights, _, _, _): return rectHighlights
        default: return []
        }
    }
    public var seqTitle: String? {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, _, _, _, let title, _, _): return title
        default: return nil
        }
    }
    public var seqAccTitle: String? {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, _, _, _, _, let accTitle, _): return accTitle
        default: return nil
        }
    }
    public var seqAccDescr: String? {
        switch content {
        case .sequenceDiagram(_, _, _, _, _, _, _, _, _, _, _, let accDescr): return accDescr
        default: return nil
        }
    }

    public var classNodes: [PositionedClassNode]? {
        switch content {
        case .classDiagram(let classes, _, _, _, _, _, _): return classes
        default: return nil
        }
    }
    public var classRelationships: [PositionedClassRelationship]? {
        switch content {
        case .classDiagram(_, let relationships, _, _, _, _, _): return relationships
        default: return nil
        }
    }
    public var classNamespaces: [PositionedClassNamespace]? {
        switch content {
        case .classDiagram(_, _, let namespaces, _, _, _, _): return namespaces
        default: return nil
        }
    }
    public var classNotes: [PositionedClassNote]? {
        switch content {
        case .classDiagram(_, _, _, let notes, _, _, _): return notes
        default: return nil
        }
    }
    public var classAccTitle: String? {
        switch content {
        case .classDiagram(_, _, _, _, let accTitle, _, _): return accTitle
        default: return nil
        }
    }
    public var classAccDescr: String? {
        switch content {
        case .classDiagram(_, _, _, _, _, let accDescr, _): return accDescr
        default: return nil
        }
    }
    public var classDiagramTitle: String? {
        switch content {
        case .classDiagram(_, _, _, _, _, _, let diagramTitle): return diagramTitle
        default: return nil
        }
    }

    public var erEntities: [PositionedErEntity]? {
        switch content {
        case .erDiagram(let entities, _, _, _, _): return entities
        default: return nil
        }
    }
    public var erRelationships: [PositionedErRelationship]? {
        switch content {
        case .erDiagram(_, let relationships, _, _, _): return relationships
        default: return nil
        }
    }

    public var xyChartData: PositionedXYChart? {
        switch content {
        case .xyChart(let chart): return chart
        default: return nil
        }
    }

    public var pieData: PositionedPieChart? {
        switch content {
        case .pie(let chart): return chart
        default: return nil
        }
    }

    public var journeyData: PositionedJourneyDiagram? {
        switch content {
        case .journey(let data): return data
        default: return nil
        }
    }

    public var gitGraphData: PositionedGitGraphDiagram? {
        switch content {
        case .gitGraph(let data): return data
        default: return nil
        }
    }

    public var mindmapData: PositionedMindmapDiagram? {
        switch content {
        case .mindmap(let data): return data
        default: return nil
        }
    }

    public var timelineData: PositionedTimelineDiagram? {
        switch content {
        case .timeline(let data): return data
        default: return nil
        }
    }

    public var sankeyData: PositionedSankeyDiagram? {
        switch content {
        case .sankey(let data): return data
        default: return nil
        }
    }

    public var blockData: PositionedBlockDiagram? {
        switch content {
        case .block(let data): return data
        default: return nil
        }
    }

    public var packetData: PositionedPacketDiagram? {
        switch content {
        case .packet(let data): return data
        default: return nil
        }
    }

    public var kanbanData: PositionedKanbanDiagram? {
        switch content {
        case .kanban(let data): return data
        default: return nil
        }
    }

    public var architectureData: PositionedArchitectureDiagram? {
        switch content {
        case .architecture(let data): return data
        default: return nil
        }
    }
}

public struct LayoutConfig: Sendable, Equatable {
    /// Padding around the diagram (default: 40, matches TS/ELK)
    public var padding: CGFloat
    /// Horizontal space between nodes in the same layer (default: 28)
    public var nodeSpacing: CGFloat
    /// Vertical space between layers (default: 48)
    public var layerSpacing: CGFloat
    /// Space between disconnected components (default: 20)
    public var componentSpacing: CGFloat

    public init(
        padding: CGFloat = 40,
        nodeSpacing: CGFloat = 28,
        layerSpacing: CGFloat = 48,
        componentSpacing: CGFloat = 20
    ) {
        self.padding = padding
        self.nodeSpacing = nodeSpacing
        self.layerSpacing = layerSpacing
        self.componentSpacing = componentSpacing
    }
}

public enum LineStyle: String, CaseIterable, Sendable {
    case solid
    case dotted
    case dashed
    case thick
    case invisible
}

public enum ArrowHead: String, CaseIterable, Sendable {
    case none
    case arrow
    case open
    case circle
    case cross
    case diamond
}

public struct EdgeStyle: Sendable, Equatable {
    public var lineStyle: LineStyle
    public var sourceArrow: ArrowHead
    public var targetArrow: ArrowHead
    public var color: String?
    /// Explicit stroke width from linkStyle directive (e.g. "2px" → 2.0)
    public var strokeWidth: CGFloat?

    public init(
        lineStyle: LineStyle = .solid,
        sourceArrow: ArrowHead = .none,
        targetArrow: ArrowHead = .arrow,
        color: String? = nil,
        strokeWidth: CGFloat? = nil
    ) {
        self.lineStyle = lineStyle
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.color = color
        self.strokeWidth = strokeWidth
    }
}

public struct MermaidNode: Sendable {
    public var id: String
    public var inlineStyles: [String: String]
    public init(id: String, inlineStyles: [String: String] = [:]) {
        self.id = id
        self.inlineStyles = inlineStyles
    }
}

public enum BeautifulMermaidError: Error, LocalizedError {
    case notYetImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notYetImplemented(let feature):
            return "\(feature) is not yet implemented."
        }
    }
}
