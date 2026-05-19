import DiagramKitModel

func diffPieChart(_ a: PieChart, _ b: PieChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "pie.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.showData != b.showData {
        deltas.append(.unexpected(
            path: "pie.showData",
            detail: "lhs=\(a.showData) rhs=\(b.showData)"
        ))
    }
    if a.sections.count != b.sections.count {
        deltas.append(.unexpected(
            path: "pie.sections.count",
            detail: "lhs=\(a.sections.count) rhs=\(b.sections.count)"
        ))
        return deltas
    }
    for (i, (lhs, rhs)) in zip(a.sections, b.sections).enumerated() {
        if lhs.label != rhs.label {
            deltas.append(.unexpected(
                path: "pie.sections[\(i)].label",
                detail: "lhs=\(lhs.label) rhs=\(rhs.label)"
            ))
        }
        if lhs.value != rhs.value {
            deltas.append(.unexpected(
                path: "pie.sections[\(i)].value",
                detail: "lhs=\(lhs.value) rhs=\(rhs.value)"
            ))
        }
    }
    return deltas
}
