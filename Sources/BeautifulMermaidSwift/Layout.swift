import Foundation

public struct GraphLayout {
    public var config: LayoutConfig

    public init(config: LayoutConfig = LayoutConfig()) {
        self.config = config
    }

    /// Layout a parsed graph into positioned geometry.
    /// Switches on `graph.typedPayload` directly so the compiler verifies
    /// exhaustiveness — no empty fallback branches, no `guard case` boilerplate.
    public func layout(_ graph: MermaidGraph) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "GraphLayout.layout") {
            switch graph.typedPayload {
            case .flowchart, .stateDiagram:
                return try layoutGraphSync(graph, config: config)

            case let .classDiagram(parsed):
                let positioned = try layoutClassDiagramSync(parsed)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height,
                    content: .classDiagram(classes: positioned.classes, relationships: positioned.relationships,
                        namespaces: positioned.namespaces, notes: positioned.notes,
                        accTitle: positioned.accTitle, accDescr: positioned.accDescription, diagramTitle: positioned.diagramTitle))

            case let .erDiagram(parsed):
                let positioned = try layoutErDiagramSync(parsed, config: parsed.config)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height,
                    content: .erDiagram(entities: positioned.entities, relationships: positioned.relationships,
                        accTitle: positioned.accTitle, accDescr: positioned.accDescr, diagramTitle: positioned.diagramTitle))

            case let .sequenceDiagram(parsed):
                let positioned = try layoutSequenceDiagram(parsed)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height,
                    content: .sequenceDiagram(actors: positioned.actors, messages: positioned.messages,
                        blocks: positioned.blocks, lifelines: positioned.lifelines, activations: positioned.activations,
                        notes: positioned.notes, boxes: positioned.boxes, bottomActors: positioned.bottomActors,
                        rectHighlights: positioned.rectHighlights, title: positioned.title,
                        accTitle: positioned.accTitle, accDescr: positioned.accDescr))

            case let .journey(parsed):
                let config = parsed.config ?? .default
                let positioned = layoutJourneyDiagram(parsed, options: RenderOptions(), config: config)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .journey(positioned))

            case let .xyChart(chart):
                let positioned = layoutXYChart(chart)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .xyChart(positioned))

            case let .pie(chart):
                let positioned = layoutPieChart(chart)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))

            case let .gantt(parsed):
                let config = parsed.config ?? .default
                var merged = parsed; merged.config = config
                let positioned = layoutGanttDiagram(merged)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gantt(positioned))

            case let .quadrantChart(chart):
                let positioned = layoutQuadrantChart(chart)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .quadrantChart(positioned))

            case let .requirement(diagram):
                let positioned = try layoutRequirementDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .requirement(positioned))

            case let .gitGraph(diagram):
                let positioned = layoutGitGraph(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gitGraph(positioned))

            case let .mindmap(diagram):
                let positioned = try layoutMindmap(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .mindmap(positioned))

            case let .timeline(diagram):
                let positioned = layoutTimelineDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .timeline(positioned))

            case let .sankey(diagram):
                let positioned = layoutSankeyDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .sankey(positioned))

            case let .block(diagram):
                let positioned = try layoutBlockDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .block(positioned))

            case let .packet(diagram):
                let positioned = layoutPacketDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))

            case let .kanban(diagram):
                let positioned = layoutKanbanDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .kanban(positioned))

            case let .architecture(diagram):
                let positioned = layoutArchitectureDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

            case let .radar(diagram):
                let positioned = layoutRadarDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .radar(positioned))

            case let .treemap(diagram):
                let positioned = layoutTreemapDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .treemap(positioned))

            case let .venn(diagram):
                let positioned = layoutVennDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .venn(positioned))

            case let .ishikawa(diagram):
                let positioned = layoutIshikawaDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))

            case let .treeView(diagram):
                let positioned = layoutTreeViewDiagram(diagram)
                return PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))

            case let .eventModeling(diagram):
                let positioned = layoutEventModeling(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .eventModeling(positioned))

            case let .wardleyBeta(diagram):
                let positioned = layoutWardleyMap(diagram)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .wardleyBeta(positioned))

            case let .zenuml(parsed):
                let positioned = layoutZenUMLDiagram(parsed)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))

            case let .c4(parsed):
                let positioned = layoutC4Diagram(parsed)
                return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .c4(positioned))
            }
        }
    }
}
