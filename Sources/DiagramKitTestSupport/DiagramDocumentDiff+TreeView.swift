import DiagramKitModel

func diffTreeViewDiagram(_ a: TreeViewDiagram, _ b: TreeViewDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // Wave I — detect synthetic-root flattening on cross-format paths
    // that traverse a single-root target format (PlantUML WBS). When
    // `a` is a Mermaid synthetic-`/` payload with 2+ children and `b`
    // has lost siblings (either as a real-root match against
    // a.children[0] or as a synthetic-`/` with fewer children), emit a
    // typed `.syntheticRootFlattened` loss so the harness can validate
    // it against `additionalAllowedLosses`.
    let aIsSynthetic = a.root.name == "/" && a.root.level == -1
    let bIsSynthetic = b.root.name == "/" && b.root.level == -1
    if aIsSynthetic, let aFirst = a.root.children.first, a.root.children.count > 1 {
        // Case 1: b is a real-root payload matching a's first child.
        if !bIsSynthetic, aFirst.name == b.root.name, aFirst.nodeType == b.root.nodeType {
            deltas.append(.loss(.syntheticRootFlattened))
            diffTreeViewNode(aFirst, b.root, path: "treeview.root[0]", deltas: &deltas)
            return deltas
        }
        // Case 2: b is synthetic but with fewer children (siblings dropped).
        if bIsSynthetic, b.root.children.count < a.root.children.count {
            deltas.append(.loss(.syntheticRootFlattened))
            for (i, (l, r)) in zip(a.root.children, b.root.children).enumerated() {
                diffTreeViewNode(l, r, path: "treeview.root.children[\(i)]", deltas: &deltas)
            }
            return deltas
        }
    }

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
