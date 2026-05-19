import DiagramKitModel

/// Compares two `DiagramDocument`s and returns the categorised list of
/// divergences. Pure function; thread-safe.
///
/// The dispatcher inspects the payload variant on both sides. When they
/// differ, it emits a single `.unexpected("payload.type", ...)` delta
/// without descending further — different payload variants are by definition
/// not comparable as the same family.
///
/// Per-family arms live in `DiagramDocumentDiff+<Family>.swift`. Each arm
/// returns `[RoundTripDelta]` and is responsible for normalising ordering,
/// resolving renamed identifiers, and emitting `.loss(_)` vs `.unexpected(_)`
/// per the round-trip discipline.
public func compare(_ a: DiagramDocument, _ b: DiagramDocument) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        if a.title != nil && b.title == nil {
            deltas.append(.loss(.titleDrop))
        } else {
            deltas.append(.unexpected(
                path: "title",
                detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
            ))
        }
    }

    switch (a.payload, b.payload) {
    case (.flowchart(let lhs), .flowchart(let rhs)),
         (.stateDiagram(let lhs), .stateDiagram(let rhs)):
        deltas.append(contentsOf: diffParsedGraphModel(lhs, rhs))
    case (.sequenceDiagram(let lhs), .sequenceDiagram(let rhs)):
        deltas.append(contentsOf: diffSequenceDiagram(lhs, rhs))
    case (.classDiagram(let lhs), .classDiagram(let rhs)):
        deltas.append(contentsOf: diffClassDiagram(lhs, rhs))
    case (.erDiagram(let lhs), .erDiagram(let rhs)):
        deltas.append(contentsOf: diffErDiagram(lhs, rhs))
    case (.c4(let lhs), .c4(let rhs)):
        deltas.append(contentsOf: diffC4Diagram(lhs, rhs))
    case (.mindmap(let lhs), .mindmap(let rhs)):
        deltas.append(contentsOf: diffMindmapDiagram(lhs, rhs))
    case (.pie(let lhs), .pie(let rhs)):
        deltas.append(contentsOf: diffPieChart(lhs, rhs))
    case (.sankey(let lhs), .sankey(let rhs)):
        deltas.append(contentsOf: diffSankeyDiagram(lhs, rhs))
    case (.packet(let lhs), .packet(let rhs)):
        deltas.append(contentsOf: diffPacketDiagram(lhs, rhs))
    case (.journey(let lhs), .journey(let rhs)):
        deltas.append(contentsOf: diffJourneyDiagram(lhs, rhs))
    case (.timeline(let lhs), .timeline(let rhs)):
        deltas.append(contentsOf: diffTimelineDiagram(lhs, rhs))
    case (.kanban(let lhs), .kanban(let rhs)):
        deltas.append(contentsOf: diffKanbanDiagram(lhs, rhs))
    case (.treemap(let lhs), .treemap(let rhs)):
        deltas.append(contentsOf: diffTreemapDiagram(lhs, rhs))
    case (.gitGraph(let lhs), .gitGraph(let rhs)):
        deltas.append(contentsOf: diffGitGraphDiagram(lhs, rhs))
    case (.gantt(let lhs), .gantt(let rhs)):
        deltas.append(contentsOf: diffGanttDiagram(lhs, rhs))
    case (.xyChart(let lhs), .xyChart(let rhs)):
        deltas.append(contentsOf: diffXYChart(lhs, rhs))
    case (.quadrantChart(let lhs), .quadrantChart(let rhs)):
        deltas.append(contentsOf: diffQuadrantChart(lhs, rhs))
    case (.requirement(let lhs), .requirement(let rhs)):
        deltas.append(contentsOf: diffRequirementDiagram(lhs, rhs))
    case (.radar(let lhs), .radar(let rhs)):
        deltas.append(contentsOf: diffRadarDiagram(lhs, rhs))
    case (.venn(let lhs), .venn(let rhs)):
        deltas.append(contentsOf: diffVennDiagram(lhs, rhs))
    case (.ishikawa(let lhs), .ishikawa(let rhs)):
        deltas.append(contentsOf: diffIshikawaDiagram(lhs, rhs))
    case (.treeView(let lhs), .treeView(let rhs)):
        deltas.append(contentsOf: diffTreeViewDiagram(lhs, rhs))
    case (.zenuml(let lhs), .zenuml(let rhs)):
        deltas.append(contentsOf: diffZenUMLDiagram(lhs, rhs))
    case (.eventModeling(let lhs), .eventModeling(let rhs)):
        deltas.append(contentsOf: diffEventModelingDiagram(lhs, rhs))
    case (.block(let lhs), .block(let rhs)):
        deltas.append(contentsOf: diffBlockDiagram(lhs, rhs))
    default:
        deltas.append(.unexpected(
            path: "payload.type",
            detail: "lhs=\(a.payload.type) rhs=\(b.payload.type)"
        ))
    }

    return deltas
}

// Per-family comparators live in sibling files so each round-trip family can
// evolve independently while preserving a single public dispatcher.
