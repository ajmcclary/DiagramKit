import DiagramKitModel

func diffArchitectureDiagram(_ a: ArchitectureDiagram, _ b: ArchitectureDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "architecture.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "architecture.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "architecture.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    // Groups, services, junctions: compare by id with full-tuple
    // value equality (id, icon, title, parentGroupId — and for
    // services also iconText).
    func groupKey(_ g: ArchitectureGroup) -> String {
        "\(g.id)|\(g.icon ?? "")|\(g.title ?? "")|\(g.parentGroupId ?? "")"
    }
    let lhsGroups = Set(a.groups.map(groupKey))
    let rhsGroups = Set(b.groups.map(groupKey))
    if lhsGroups != rhsGroups {
        deltas.append(.unexpected(
            path: "architecture.groups",
            detail: "onlyLhs=\(lhsGroups.subtracting(rhsGroups).sorted()) onlyRhs=\(rhsGroups.subtracting(lhsGroups).sorted())"
        ))
    }

    func serviceKey(_ s: ArchitectureService) -> String {
        "\(s.id)|\(s.icon ?? "")|\(s.iconText ?? "")|\(s.title ?? "")|\(s.parentGroupId ?? "")"
    }
    let lhsServices = Set(a.services.map(serviceKey))
    let rhsServices = Set(b.services.map(serviceKey))
    if lhsServices != rhsServices {
        deltas.append(.unexpected(
            path: "architecture.services",
            detail: "onlyLhs=\(lhsServices.subtracting(rhsServices).sorted()) onlyRhs=\(rhsServices.subtracting(lhsServices).sorted())"
        ))
    }

    func junctionKey(_ j: ArchitectureJunction) -> String {
        "\(j.id)|\(j.parentGroupId ?? "")"
    }
    let lhsJunctions = Set(a.junctions.map(junctionKey))
    let rhsJunctions = Set(b.junctions.map(junctionKey))
    if lhsJunctions != rhsJunctions {
        deltas.append(.unexpected(
            path: "architecture.junctions",
            detail: "onlyLhs=\(lhsJunctions.subtracting(rhsJunctions).sorted()) onlyRhs=\(rhsJunctions.subtracting(lhsJunctions).sorted())"
        ))
    }

    // Edges: sorted multiset on the normalized tuple.
    func edgeKey(_ e: ArchitectureEdge) -> String {
        "\(e.lhsId):\(e.lhsDirection.rawValue)\(e.lhsGroupBoundary ? "{g}" : "")|\(e.rhsId):\(e.rhsDirection.rawValue)\(e.rhsGroupBoundary ? "{g}" : "")|sa=\(e.sourceArrow)|ta=\(e.targetArrow)|label=\(e.label ?? "")"
    }
    let lhsEdges = a.edges.map(edgeKey).sorted()
    let rhsEdges = b.edges.map(edgeKey).sorted()
    if lhsEdges != rhsEdges {
        deltas.append(.unexpected(
            path: "architecture.edges",
            detail: "lhs=\(lhsEdges) rhs=\(rhsEdges)"
        ))
    }
    return deltas
}
