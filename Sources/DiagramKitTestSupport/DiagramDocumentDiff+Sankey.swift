import DiagramKitModel

func diffSankeyDiagram(_ a: SankeyDiagram, _ b: SankeyDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "sankey.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    // Links carry source/target/value; nodes are derived from link
    // endpoints and order can vary, so compare on the link triple set.
    let lhsTriples = Set(a.links.map { "\($0.source.id)|\($0.target.id)|\($0.value)" })
    let rhsTriples = Set(b.links.map { "\($0.source.id)|\($0.target.id)|\($0.value)" })
    if lhsTriples != rhsTriples {
        let onlyLhs = lhsTriples.subtracting(rhsTriples).sorted()
        let onlyRhs = rhsTriples.subtracting(lhsTriples).sorted()
        deltas.append(.unexpected(
            path: "sankey.links",
            detail: "onlyLhs=\(onlyLhs.joined(separator: ";")) onlyRhs=\(onlyRhs.joined(separator: ";"))"
        ))
    }
    return deltas
}
