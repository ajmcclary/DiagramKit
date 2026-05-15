import DiagramKitModel

func diffMindmapDiagram(_ a: MindmapDiagram, _ b: MindmapDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []
    switch (a.root, b.root) {
    case (nil, nil):
        return deltas
    case (.some(let aRoot), .some(let bRoot)):
        diffMindmapNodes(aRoot, bRoot, path: "root", deltas: &deltas)
    default:
        deltas.append(.unexpected(
            path: "root",
            detail: "lhs=\(a.root == nil ? "nil" : "some") rhs=\(b.root == nil ? "nil" : "some")"
        ))
    }
    return deltas
}

private func diffMindmapNodes(
    _ a: MindmapNode,
    _ b: MindmapNode,
    path: String,
    deltas: inout [RoundTripDelta]
) {
    if a.descr != b.descr {
        deltas.append(.unexpected(
            path: "\(path).descr",
            detail: "lhs=\(a.descr) rhs=\(b.descr)"
        ))
    }
    if a.children.count != b.children.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(a.children.count) rhs=\(b.children.count)"
        ))
        return
    }
    for (i, (aChild, bChild)) in zip(a.children, b.children).enumerated() {
        diffMindmapNodes(aChild, bChild, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
