import DiagramKitModel

func diffTreemapDiagram(_ a: TreemapDiagram, _ b: TreemapDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "treemap.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.nodes.count != b.nodes.count {
        deltas.append(.unexpected(
            path: "treemap.nodes.count",
            detail: "lhs=\(a.nodes.count) rhs=\(b.nodes.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.nodes, b.nodes).enumerated() {
        diffTreemapNode(l, r, path: "treemap.nodes[\(i)]", deltas: &deltas)
    }
    return deltas
}

private func diffTreemapNode(
    _ a: TreemapNode,
    _ b: TreemapNode,
    path: String,
    deltas: inout [RoundTripDelta]
) {
    if a.name != b.name {
        deltas.append(.unexpected(
            path: "\(path).name",
            detail: "lhs=\(a.name) rhs=\(b.name)"
        ))
    }
    if a.value != b.value {
        let lhsStr = a.value.map { String($0) } ?? "nil"
        let rhsStr = b.value.map { String($0) } ?? "nil"
        deltas.append(.unexpected(
            path: "\(path).value",
            detail: "lhs=\(lhsStr) rhs=\(rhsStr)"
        ))
    }
    let aChildren = a.children ?? []
    let bChildren = b.children ?? []
    if aChildren.count != bChildren.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(aChildren.count) rhs=\(bChildren.count)"
        ))
        return
    }
    for (i, (l, r)) in zip(aChildren, bChildren).enumerated() {
        diffTreemapNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
