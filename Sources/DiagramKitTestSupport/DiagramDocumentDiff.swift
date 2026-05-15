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
    case (.gantt(let lhs), .gantt(let rhs)):
        deltas.append(contentsOf: diffGanttDiagram(lhs, rhs))
    default:
        deltas.append(.unexpected(
            path: "payload.type",
            detail: "lhs=\(a.payload.type) rhs=\(b.payload.type)"
        ))
    }

    return deltas
}

// MARK: - Per-family stubs (filled in by subsequent cell tasks)
// Each stub returns `[.unexpected("not-yet-implemented", "<family>")]` until
// its cell task lands the real comparator.

func diffC4Diagram(_ a: C4Diagram, _ b: C4Diagram) -> [RoundTripDelta] {
    [.unexpected(path: "c4", detail: "not-yet-implemented")]
}

func diffMindmapDiagram(_ a: MindmapDiagram, _ b: MindmapDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "mindmap", detail: "not-yet-implemented")]
}

func diffGanttDiagram(_ a: GanttDiagram, _ b: GanttDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "gantt", detail: "not-yet-implemented")]
}
