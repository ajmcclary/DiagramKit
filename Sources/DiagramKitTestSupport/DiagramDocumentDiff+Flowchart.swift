import DiagramKitModel

func diffParsedGraphModel(_ a: ParsedGraphModel, _ b: ParsedGraphModel) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    let aNodes = Dictionary(uniqueKeysWithValues: a.nodesInOrder.map { ($0.id, $0.node) })
    let bNodes = Dictionary(uniqueKeysWithValues: b.nodesInOrder.map { ($0.id, $0.node) })

    // 1) Node id symmetry. Renames map across via .idSanitization.
    let aSanitizationMap = diffNodeIDs(a: aNodes, b: bNodes, deltas: &deltas)

    // 2) Per-node label + shape comparison (for ids that are in both directly
    // or via the sanitization map).
    for (id, aNode) in aNodes {
        let mappedID = aSanitizationMap[id] ?? id
        guard let bNode = bNodes[mappedID] else { continue }
        if aNode.label != bNode.label {
            deltas.append(.unexpected(
                path: "nodes[\(id)].label",
                detail: "lhs=\(aNode.label) rhs=\(bNode.label)"
            ))
        }
        if aNode.shape != bNode.shape {
            deltas.append(.loss(.shapeDowngrade(nodeID: id, from: aNode.shape, to: bNode.shape)))
        }
    }

    // 3) Edge symmetry. Edges are ordered, but Mermaid re-emission order is
    // not guaranteed to match the input. Sort both sides by canonical
    // (source, target, label, style, arrowheads) and zip-compare.
    let aEdges = a.edges.sorted(by: edgeOrder)
    let bEdges = b.edges.sorted(by: edgeOrder)
    if aEdges.count != bEdges.count {
        deltas.append(.unexpected(
            path: "edges.count",
            detail: "lhs=\(aEdges.count) rhs=\(bEdges.count)"
        ))
    } else {
        for (i, (ae, be)) in zip(aEdges, bEdges).enumerated() {
            let aMappedSource = aSanitizationMap[ae.source] ?? ae.source
            let aMappedTarget = aSanitizationMap[ae.target] ?? ae.target
            if aMappedSource != be.source || aMappedTarget != be.target {
                deltas.append(.unexpected(
                    path: "edges[\(i)].endpoints",
                    detail: "lhs=(\(ae.source)→\(ae.target)) rhs=(\(be.source)→\(be.target))"
                ))
            }
            if (ae.label ?? "") != (be.label ?? "") {
                deltas.append(.unexpected(
                    path: "edges[\(i)].label",
                    detail: "lhs=\(ae.label ?? "nil") rhs=\(be.label ?? "nil")"
                ))
            }
            // Edge style + arrowheads. A style present on the source side
            // and absent after the round-trip is a `.styleDrop` loss so the
            // harness can require a paired exporter diagnostic.
            if ae.style != be.style {
                deltas.append(.loss(.styleDrop(
                    target: "\(ae.source)→\(ae.target)",
                    attribute: "style lhs=\(ae.style.rawValue) rhs=\(be.style.rawValue)"
                )))
            }
            if ae.arrowHeadStart != be.arrowHeadStart || ae.arrowHeadEnd != be.arrowHeadEnd {
                deltas.append(.loss(.styleDrop(
                    target: "\(ae.source)→\(ae.target)",
                    attribute: "arrowheads lhs=(\(ae.arrowHeadStart.rawValue),\(ae.arrowHeadEnd.rawValue)) " +
                        "rhs=(\(be.arrowHeadStart.rawValue),\(be.arrowHeadEnd.rawValue))"
                )))
            }
        }
    }

    // 4) Subgraphs. Anonymous subgraph ids are positional; emit
    // .anonymousSubgraphRename for the (old → new) pair and continue.
    deltas.append(contentsOf: diffSubgraphs(a: a.subgraphs, b: b.subgraphs))

    return deltas
}

private func edgeOrder(
    _ lhs: original_src_types.MermaidEdge,
    _ rhs: original_src_types.MermaidEdge
) -> Bool {
    let lk = "\(lhs.source)|\(lhs.target)|\(lhs.label ?? "")|\(lhs.style.rawValue)|" +
        "\(lhs.arrowHeadStart.rawValue)|\(lhs.arrowHeadEnd.rawValue)"
    let rk = "\(rhs.source)|\(rhs.target)|\(rhs.label ?? "")|\(rhs.style.rawValue)|" +
        "\(rhs.arrowHeadStart.rawValue)|\(rhs.arrowHeadEnd.rawValue)"
    return lk < rk
}

private func diffNodeIDs(
    a: [String: original_src_types.MermaidNode],
    b: [String: original_src_types.MermaidNode],
    deltas: inout [RoundTripDelta]
) -> [String: String] {
    var sanitizationMap: [String: String] = [:]
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aNode = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID)
                && b[bID]?.label == aNode.label
                && b[bID]?.shape == aNode.shape
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            sanitizationMap[aID] = bID
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "nodes", detail: "lhs-only id=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "nodes", detail: "rhs-only id=\(bID)"))
    }
    return sanitizationMap
}

private func diffSubgraphs(
    a: [original_src_types.MermaidSubgraph],
    b: [original_src_types.MermaidSubgraph]
) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []
    if a.count != b.count {
        deltas.append(.unexpected(
            path: "subgraphs.count",
            detail: "lhs=\(a.count) rhs=\(b.count)"
        ))
        return deltas
    }
    for (aSub, bSub) in zip(a, b) where aSub.id != bSub.id {
        let isAnonymous = aSub.id.hasPrefix("subgraph_") && bSub.id.hasPrefix("subgraph_")
        if isAnonymous {
            deltas.append(.loss(.anonymousSubgraphRename(old: aSub.id, new: bSub.id)))
        } else {
            deltas.append(.unexpected(
                path: "subgraphs",
                detail: "lhs id=\(aSub.id) rhs id=\(bSub.id)"
            ))
        }
    }
    return deltas
}
