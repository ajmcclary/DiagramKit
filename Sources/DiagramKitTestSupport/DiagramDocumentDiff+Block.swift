import DiagramKitModel

func diffBlockDiagram(_ a: BlockDiagram, _ b: BlockDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "block.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "block.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "block.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    // Root children must appear in the same order — `rootChildren` is
    // the parser-visible declaration order.
    if a.rootChildren != b.rootChildren {
        deltas.append(.unexpected(
            path: "block.rootChildren",
            detail: "lhs=\(a.rootChildren) rhs=\(b.rootChildren)"
        ))
    }

    // Walk every user-named node in the database. Auto-generated ids
    // (matching `^id-`) may renumber on re-parse for space nodes; we
    // strip those to a placeholder before comparing children.
    let aIds = Set(a.blockDatabase.keys).filter { !$0.hasPrefix("id-") }
    let bIds = Set(b.blockDatabase.keys).filter { !$0.hasPrefix("id-") }
    if aIds != bIds {
        deltas.append(.unexpected(
            path: "block.nodes.userIds",
            detail: "onlyLhs=\(aIds.subtracting(bIds).sorted()) onlyRhs=\(bIds.subtracting(aIds).sorted())"
        ))
    }
    for id in aIds where bIds.contains(id) {
        guard let l = a.blockDatabase[id], let r = b.blockDatabase[id] else { continue }
        if l.label != r.label {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].label",
                detail: "lhs=\(l.label) rhs=\(r.label)"
            ))
        }
        if l.type != r.type {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].type",
                detail: "lhs=\(l.type) rhs=\(r.type)"
            ))
        }
        if l.columns != r.columns {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].columns",
                detail: "lhs=\(String(describing: l.columns)) rhs=\(String(describing: r.columns))"
            ))
        }
        if l.widthInColumns != r.widthInColumns {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].widthInColumns",
                detail: "lhs=\(String(describing: l.widthInColumns)) rhs=\(String(describing: r.widthInColumns))"
            ))
        }
        // Children — strip auto-generated space ids to a placeholder
        // so positional comparison stays meaningful when the parser
        // re-numbers space ids on re-parse.
        func normalizeChildren(_ ids: [String], _ db: [String: BlockNode]) -> [String] {
            ids.map { cid in
                if cid.hasPrefix("id-"), db[cid]?.type == .space { return "<space>" }
                return cid
            }
        }
        let lc = normalizeChildren(l.children, a.blockDatabase)
        let rc = normalizeChildren(r.children, b.blockDatabase)
        if lc != rc {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].children",
                detail: "lhs=\(lc) rhs=\(rc)"
            ))
        }
        if (l.classes ?? []) != (r.classes ?? []) {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].classes",
                detail: "lhs=\(l.classes ?? []) rhs=\(r.classes ?? [])"
            ))
        }
        if (l.styles ?? []) != (r.styles ?? []) {
            deltas.append(.unexpected(
                path: "block.nodes[\(id)].styles",
                detail: "lhs=\(l.styles ?? []) rhs=\(r.styles ?? [])"
            ))
        }
    }

    // Edges: the parser prefixes the edge id with a per-pair count to
    // disambiguate duplicate (start, end) pairs. Drop the count and
    // compare as a multiset on the normalized tuple.
    func edgeKey(_ e: BlockEdge) -> String {
        "\(e.start)|\(e.end)|\(e.label ?? "")|\(e.thickness)|\(e.pattern)|\(e.arrowTypeEnd)|\(e.arrowTypeStart)"
    }
    let lhsEdges = a.edges.map(edgeKey).sorted()
    let rhsEdges = b.edges.map(edgeKey).sorted()
    if lhsEdges != rhsEdges {
        deltas.append(.unexpected(
            path: "block.edges",
            detail: "lhs=\(lhsEdges) rhs=\(rhsEdges)"
        ))
    }

    // Classes by name.
    let aClassNames = Set(a.classes.keys)
    let bClassNames = Set(b.classes.keys)
    if aClassNames != bClassNames {
        deltas.append(.unexpected(
            path: "block.classes.keys",
            detail: "onlyLhs=\(aClassNames.subtracting(bClassNames).sorted()) onlyRhs=\(bClassNames.subtracting(aClassNames).sorted())"
        ))
    }
    for name in aClassNames where bClassNames.contains(name) {
        guard let l = a.classes[name], let r = b.classes[name] else { continue }
        if l.styles != r.styles {
            deltas.append(.unexpected(
                path: "block.classes[\(name)].styles",
                detail: "lhs=\(l.styles) rhs=\(r.styles)"
            ))
        }
    }
    return deltas
}
