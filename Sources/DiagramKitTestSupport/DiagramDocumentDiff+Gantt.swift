import DiagramKitModel

func diffGanttDiagram(_ a: GanttDiagram, _ b: GanttDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // Tasks: position-significant; compare by id.
    if a.tasks.count != b.tasks.count {
        deltas.append(.unexpected(
            path: "tasks.count",
            detail: "lhs=\(a.tasks.count) rhs=\(b.tasks.count)"
        ))
    } else {
        for (i, (at, bt)) in zip(a.tasks, b.tasks).enumerated() {
            if at.id != bt.id {
                deltas.append(.unexpected(
                    path: "tasks[\(i)].id",
                    detail: "lhs=\(at.id) rhs=\(bt.id)"
                ))
            }
            if at.task != bt.task {
                deltas.append(.unexpected(
                    path: "tasks[\(i)].task",
                    detail: "lhs=\(at.task) rhs=\(bt.task)"
                ))
            }
        }
    }

    // Sections: position-significant.
    if a.sections.count != b.sections.count {
        deltas.append(.unexpected(
            path: "sections.count",
            detail: "lhs=\(a.sections.count) rhs=\(b.sections.count)"
        ))
    }

    return deltas
}
