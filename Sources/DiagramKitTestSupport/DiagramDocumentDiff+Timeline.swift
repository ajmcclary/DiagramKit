import DiagramKitModel

func diffTimelineDiagram(_ a: TimelineDiagram, _ b: TimelineDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "timeline.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.tasks.count != b.tasks.count {
        deltas.append(.unexpected(
            path: "timeline.tasks.count",
            detail: "lhs=\(a.tasks.count) rhs=\(b.tasks.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.tasks, b.tasks).enumerated() {
        if l.section != r.section || l.text != r.text {
            deltas.append(.unexpected(
                path: "timeline.tasks[\(i)]",
                detail: "lhs=[\(l.section)]\(l.text) rhs=[\(r.section)]\(r.text)"
            ))
        }
        if l.events.count != r.events.count {
            deltas.append(.unexpected(
                path: "timeline.tasks[\(i)].events.count",
                detail: "lhs=\(l.events.count) rhs=\(r.events.count)"
            ))
            continue
        }
        for (j, (le, re)) in zip(l.events, r.events).enumerated() {
            if le.text != re.text {
                deltas.append(.unexpected(
                    path: "timeline.tasks[\(i)].events[\(j)]",
                    detail: "lhs=\(le.text) rhs=\(re.text)"
                ))
            }
        }
    }
    return deltas
}
