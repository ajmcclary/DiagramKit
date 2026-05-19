import DiagramKitModel

func diffTreeViewDiagram(_ a: TreeViewDiagram, _ b: TreeViewDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []
    diffTreeViewNode(a.root, b.root, path: "treeview.root", deltas: &deltas)
    return deltas
}

private func diffTreeViewNode(_ a: TreeViewNode, _ b: TreeViewNode, path: String, deltas: inout [RoundTripDelta]) {
    if a.name != b.name || a.nodeType != b.nodeType || a.iconId != b.iconId {
        deltas.append(.unexpected(
            path: "\(path).self",
            detail: "lhs=\(a.name)[\(a.nodeType)]icon=\(a.iconId ?? "nil") rhs=\(b.name)[\(b.nodeType)]icon=\(b.iconId ?? "nil")"
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
        diffTreeViewNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
