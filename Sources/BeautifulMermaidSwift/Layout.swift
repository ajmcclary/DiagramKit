import Foundation

public struct GraphLayout {
    public var config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "GraphLayout.layout") {
            switch graph.type {
            case .flowchart, .stateDiagram:
                return try layoutGraphSync(graph, config: config)
            case .classDiagram:
                guard case let .classDiagram(parsed) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched class diagram payload.")
                    return PositionedGraph(diagram: graph, content: .classDiagram(classes: [], relationships: [], namespaces: [], notes: [], accTitle: nil, accDescr: nil, diagramTitle: nil))
                }
                let positioned = try layoutClassDiagramSync(parsed)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .classDiagram(
                        classes: positioned.classes,
                        relationships: positioned.relationships,
                        namespaces: positioned.namespaces,
                        notes: positioned.notes,
                        accTitle: positioned.accTitle,
                        accDescr: positioned.accDescription,
                        diagramTitle: positioned.diagramTitle
                    )
                )
            case .erDiagram:
                guard case let .erDiagram(parsed) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched ER diagram payload.")
                    return PositionedGraph(diagram: graph, content: .erDiagram(entities: [], relationships: [], accTitle: nil, accDescr: nil, diagramTitle: nil))
                }
                let positioned = try layoutErDiagramSync(parsed, config: parsed.config)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .erDiagram(
                        entities: positioned.entities,
                        relationships: positioned.relationships,
                        accTitle: positioned.accTitle,
                        accDescr: positioned.accDescr,
                        diagramTitle: positioned.diagramTitle
                    )
                )
            case .sequenceDiagram:
                guard case let .sequenceDiagram(parsed) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched sequence diagram payload.")
                    return PositionedGraph(diagram: graph, content: .sequenceDiagram(actors: [], messages: [], blocks: [], lifelines: [], activations: [], notes: [], boxes: [], bottomActors: [], rectHighlights: [], title: nil, accTitle: nil, accDescr: nil))
                }
                let positioned = try layoutSequenceDiagram(parsed)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .sequenceDiagram(
                        actors: positioned.actors,
                        messages: positioned.messages,
                        blocks: positioned.blocks,
                        lifelines: positioned.lifelines,
                        activations: positioned.activations,
                        notes: positioned.notes,
                        boxes: positioned.boxes,
                        bottomActors: positioned.bottomActors,
                        rectHighlights: positioned.rectHighlights,
                        title: positioned.title,
                        accTitle: positioned.accTitle,
                        accDescr: positioned.accDescr
                    )
                )
            case .journey:
                guard case let .journey(parsed) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched journey payload.")
                    return PositionedGraph(diagram: graph, content: .journey(.empty))
                }
                let config = parsed.config ?? .default
                let positioned = layoutJourneyDiagram(parsed, options: RenderOptions(), config: config)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .journey(positioned)
                )
            case .xyChart:
                guard case let .xyChart(chart) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched XY chart payload.")
                    return PositionedGraph(diagram: graph, content: .xyChart(PositionedXYChart.empty))
                }
                let positioned = layoutXYChart(chart)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .xyChart(positioned)
                )
            case .pie:
                guard case let .pie(chart) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched pie chart payload.")
                    return PositionedGraph(diagram: graph, content: .pie(.empty))
                }
                let positioned = layoutPieChart(chart)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .pie(positioned)
                )
            case .gantt:
                guard case let .gantt(parsed) = graph.payload else {
                    _reportMermaidIssue("GraphLayout.layout found mismatched Gantt payload.")
                    return PositionedGraph(diagram: graph, content: .gantt(.empty))
                }
                let config = parsed.config ?? .default
                var merged = parsed
                merged.config = config
                let positioned = layoutGanttDiagram(merged)
                return PositionedGraph(
                    diagram: graph,
                    width: positioned.width,
                    height: positioned.height,
                    content: .gantt(positioned)
                )
            }
        }
    }
}
