import DiagramKitModel

func diffWardleyMapDiagram(_ a: WardleyMapDiagram, _ b: WardleyMapDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "wardley.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.accTitle != b.accTitle {
        deltas.append(.unexpected(
            path: "wardley.accTitle",
            detail: "lhs=\(a.accTitle ?? "nil") rhs=\(b.accTitle ?? "nil")"
        ))
    }
    if a.accDescr != b.accDescr {
        deltas.append(.unexpected(
            path: "wardley.accDescr",
            detail: "lhs=\(a.accDescr ?? "nil") rhs=\(b.accDescr ?? "nil")"
        ))
    }

    let aSize = a.size.map { ($0.width, $0.height) }
    let bSize = b.size.map { ($0.width, $0.height) }
    if aSize?.0 != bSize?.0 || aSize?.1 != bSize?.1 {
        deltas.append(.unexpected(
            path: "wardley.size",
            detail: "lhs=\(String(describing: aSize)) rhs=\(String(describing: bSize))"
        ))
    }

    if a.axes.xLabel != b.axes.xLabel
        || a.axes.yLabel != b.axes.yLabel
        || (a.axes.stages ?? []) != (b.axes.stages ?? [])
        || (a.axes.stageBoundaries ?? []) != (b.axes.stageBoundaries ?? []) {
        deltas.append(.unexpected(
            path: "wardley.axes",
            detail: "lhs={xLabel=\(a.axes.xLabel ?? "nil"), yLabel=\(a.axes.yLabel ?? "nil"), stages=\(a.axes.stages ?? []), boundaries=\(a.axes.stageBoundaries ?? [])} rhs={xLabel=\(b.axes.xLabel ?? "nil"), yLabel=\(b.axes.yLabel ?? "nil"), stages=\(b.axes.stages ?? []), boundaries=\(b.axes.stageBoundaries ?? [])}"
        ))
    }

    // Round coordinates to 4 decimal places to absorb floating-point
    // drift through the 0-1 / 0-100 normalization.
    func roundedCoord(_ v: Double) -> Double {
        (v * 10000).rounded() / 10000
    }

    func nodeKey(_ n: WardleyNode) -> String {
        let x = roundedCoord(n.x), y = roundedCoord(n.y)
        return "\(n.id)|x=\(x)|y=\(y)|label=\(n.label)|cls=\(n.className?.rawValue ?? "nil")|inertia=\(n.inertia)|strategy=\(n.sourceStrategy?.rawValue ?? "nil")"
    }
    let lhsNodes = Set(a.nodes.map(nodeKey))
    let rhsNodes = Set(b.nodes.map(nodeKey))
    if lhsNodes != rhsNodes {
        deltas.append(.unexpected(
            path: "wardley.nodes",
            detail: "onlyLhs=\(lhsNodes.subtracting(rhsNodes).sorted()) onlyRhs=\(rhsNodes.subtracting(lhsNodes).sorted())"
        ))
    }

    func linkKey(_ l: WardleyLink) -> String {
        "\(l.source)|\(l.target)|dashed=\(l.dashed)|label=\(l.label ?? "")|flow=\(l.flow?.rawValue ?? "nil")"
    }
    let lhsLinks = a.links.map(linkKey).sorted()
    let rhsLinks = b.links.map(linkKey).sorted()
    if lhsLinks != rhsLinks {
        deltas.append(.unexpected(
            path: "wardley.links",
            detail: "lhs=\(lhsLinks) rhs=\(rhsLinks)"
        ))
    }

    func trendKey(_ t: WardleyTrend) -> String {
        "\(t.nodeId)|tx=\(roundedCoord(t.targetX))"
    }
    let lhsTrends = a.trends.map(trendKey).sorted()
    let rhsTrends = b.trends.map(trendKey).sorted()
    if lhsTrends != rhsTrends {
        deltas.append(.unexpected(
            path: "wardley.trends",
            detail: "lhs=\(lhsTrends) rhs=\(rhsTrends)"
        ))
    }

    func pipelineKey(_ p: WardleyPipeline) -> String {
        "\(p.nodeId)|children=\(p.componentIds.joined(separator: ","))"
    }
    let lhsPipelines = Set(a.pipelines.map(pipelineKey))
    let rhsPipelines = Set(b.pipelines.map(pipelineKey))
    if lhsPipelines != rhsPipelines {
        deltas.append(.unexpected(
            path: "wardley.pipelines",
            detail: "onlyLhs=\(lhsPipelines.subtracting(rhsPipelines).sorted()) onlyRhs=\(rhsPipelines.subtracting(lhsPipelines).sorted())"
        ))
    }

    func noteKey(_ n: WardleyNote) -> String {
        "\(n.text)|x=\(roundedCoord(n.x))|y=\(roundedCoord(n.y))"
    }
    let lhsNotes = Set(a.notes.map(noteKey))
    let rhsNotes = Set(b.notes.map(noteKey))
    if lhsNotes != rhsNotes {
        deltas.append(.unexpected(
            path: "wardley.notes",
            detail: "onlyLhs=\(lhsNotes.subtracting(rhsNotes).sorted()) onlyRhs=\(rhsNotes.subtracting(lhsNotes).sorted())"
        ))
    }

    func annotationKey(_ ann: WardleyAnnotation) -> String {
        let coords = ann.coordinates.map { "(\(roundedCoord($0.x)),\(roundedCoord($0.y)))" }.joined(separator: ",")
        return "#\(ann.number)|coords=\(coords)|text=\(ann.text ?? "")"
    }
    let lhsAnnos = Set(a.annotations.map(annotationKey))
    let rhsAnnos = Set(b.annotations.map(annotationKey))
    if lhsAnnos != rhsAnnos {
        deltas.append(.unexpected(
            path: "wardley.annotations",
            detail: "onlyLhs=\(lhsAnnos.subtracting(rhsAnnos).sorted()) onlyRhs=\(rhsAnnos.subtracting(lhsAnnos).sorted())"
        ))
    }

    let aBox = a.annotationsBox.map { (roundedCoord($0.x), roundedCoord($0.y)) }
    let bBox = b.annotationsBox.map { (roundedCoord($0.x), roundedCoord($0.y)) }
    if aBox?.0 != bBox?.0 || aBox?.1 != bBox?.1 {
        deltas.append(.unexpected(
            path: "wardley.annotationsBox",
            detail: "lhs=\(String(describing: aBox)) rhs=\(String(describing: bBox))"
        ))
    }

    func accelKey(_ a: WardleyAccelerator) -> String {
        "\(a.name)|x=\(roundedCoord(a.x))|y=\(roundedCoord(a.y))"
    }
    func deaccelKey(_ d: WardleyDeaccelerator) -> String {
        "\(d.name)|x=\(roundedCoord(d.x))|y=\(roundedCoord(d.y))"
    }
    let lhsAccels = Set(a.accelerators.map(accelKey))
    let rhsAccels = Set(b.accelerators.map(accelKey))
    if lhsAccels != rhsAccels {
        deltas.append(.unexpected(
            path: "wardley.accelerators",
            detail: "onlyLhs=\(lhsAccels.subtracting(rhsAccels).sorted()) onlyRhs=\(rhsAccels.subtracting(lhsAccels).sorted())"
        ))
    }
    let lhsDeaccels = Set(a.deaccelerators.map(deaccelKey))
    let rhsDeaccels = Set(b.deaccelerators.map(deaccelKey))
    if lhsDeaccels != rhsDeaccels {
        deltas.append(.unexpected(
            path: "wardley.deaccelerators",
            detail: "onlyLhs=\(lhsDeaccels.subtracting(rhsDeaccels).sorted()) onlyRhs=\(rhsDeaccels.subtracting(lhsDeaccels).sorted())"
        ))
    }
    return deltas
}
