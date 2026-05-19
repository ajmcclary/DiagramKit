import DiagramKitModel

func diffIshikawaDiagram(_ a: IshikawaDiagram, _ b: IshikawaDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "ishikawa.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    switch (a.root, b.root) {
    case (nil, nil):
        break
    case (let l?, let r?):
        diffIshikawaNode(l, r, path: "ishikawa.root", deltas: &deltas)
    default:
        deltas.append(.unexpected(
            path: "ishikawa.root",
            detail: "lhs=\(a.root == nil ? "nil" : "present") rhs=\(b.root == nil ? "nil" : "present")"
        ))
    }
    return deltas
}

private func diffIshikawaNode(_ a: IshikawaNode, _ b: IshikawaNode, path: String, deltas: inout [RoundTripDelta]) {
    if a.text != b.text {
        deltas.append(.unexpected(
            path: "\(path).text",
            detail: "lhs=\(a.text) rhs=\(b.text)"
        ))
    }
    if a.children.count != b.children.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(a.children.count) rhs=\(b.children.count)"
        ))
        return
    }
    for (i, (l, r)) in zip(a.children, b.children).enumerated() {
        diffIshikawaNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
