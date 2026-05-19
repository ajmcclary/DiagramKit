import DiagramKitModel

func diffVennDiagram(_ a: VennDiagram, _ b: VennDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "venn.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    func areaKey(_ area: VennArea) -> String {
        let sets = area.sets.sorted().joined(separator: ",")
        return "\(sets)|\(area.label ?? "")"
    }
    let lhs = Set(a.areas.map(areaKey))
    let rhs = Set(b.areas.map(areaKey))
    if lhs != rhs {
        deltas.append(.unexpected(
            path: "venn.areas",
            detail: "onlyLhs=\(lhs.subtracting(rhs).sorted()) onlyRhs=\(rhs.subtracting(lhs).sorted())"
        ))
    }
    return deltas
}
