import DiagramKitModel

func diffKanbanDiagram(_ a: KanbanDiagram, _ b: KanbanDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "kanban.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.sections.count != b.sections.count {
        deltas.append(.unexpected(
            path: "kanban.sections.count",
            detail: "lhs=\(a.sections.count) rhs=\(b.sections.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.sections, b.sections).enumerated() {
        if l.id != r.id || l.label != r.label {
            deltas.append(.unexpected(
                path: "kanban.sections[\(i)]",
                detail: "lhs=\(l.id):\(l.label) rhs=\(r.id):\(r.label)"
            ))
        }
    }
    if a.nodes.count != b.nodes.count {
        deltas.append(.unexpected(
            path: "kanban.nodes.count",
            detail: "lhs=\(a.nodes.count) rhs=\(b.nodes.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.nodes, b.nodes).enumerated() {
        if l.id != r.id
            || l.label != r.label
            || l.parentId != r.parentId
            || l.assigned != r.assigned
            || l.ticket != r.ticket
            || l.priority != r.priority {
            deltas.append(.unexpected(
                path: "kanban.nodes[\(i)]",
                detail: "lhs=\(l.id):\(l.label) parent=\(l.parentId ?? "nil") meta=[\(l.assigned ?? "")|\(l.ticket ?? "")|\(l.priority ?? "")] rhs=\(r.id):\(r.label) parent=\(r.parentId ?? "nil") meta=[\(r.assigned ?? "")|\(r.ticket ?? "")|\(r.priority ?? "")]"
            ))
        }
    }
    return deltas
}
