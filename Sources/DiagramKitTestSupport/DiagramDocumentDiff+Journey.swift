import DiagramKitModel

func diffJourneyDiagram(_ a: JourneyDiagram, _ b: JourneyDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        deltas.append(.unexpected(
            path: "journey.title",
            detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
        ))
    }
    if a.tasks.count != b.tasks.count {
        deltas.append(.unexpected(
            path: "journey.tasks.count",
            detail: "lhs=\(a.tasks.count) rhs=\(b.tasks.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.tasks, b.tasks).enumerated() {
        if l.section != r.section || l.task != r.task || l.score != r.score || l.people != r.people {
            deltas.append(.unexpected(
                path: "journey.tasks[\(i)]",
                detail: "lhs=[\(l.section)]\(l.task):\(l.score):\(l.people) rhs=[\(r.section)]\(r.task):\(r.score):\(r.people)"
            ))
        }
    }
    return deltas
}
