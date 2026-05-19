import DiagramKitModel

func diffRadarDiagram(_ a: RadarDiagram, _ b: RadarDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "radar.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    let aAxes = a.axes.map { "\($0.name)|\($0.label)" }
    let bAxes = b.axes.map { "\($0.name)|\($0.label)" }
    if aAxes != bAxes {
        deltas.append(.unexpected(
            path: "radar.axes",
            detail: "lhs=\(aAxes) rhs=\(bAxes)"
        ))
    }

    if a.curves.count != b.curves.count {
        deltas.append(.unexpected(
            path: "radar.curves.count",
            detail: "lhs=\(a.curves.count) rhs=\(b.curves.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.curves, b.curves).enumerated() {
        if l.name != r.name || l.label != r.label || l.entries != r.entries {
            deltas.append(.unexpected(
                path: "radar.curves[\(i)]",
                detail: "lhs=\(l.name):\(l.label)={\(l.entries)} rhs=\(r.name):\(r.label)={\(r.entries)}"
            ))
        }
    }

    if a.options.showLegend != b.options.showLegend
        || a.options.ticks != b.options.ticks
        || a.options.min != b.options.min
        || a.options.max != b.options.max
        || a.options.graticule != b.options.graticule {
        deltas.append(.unexpected(
            path: "radar.options",
            detail: "lhs=legend=\(a.options.showLegend) ticks=\(a.options.ticks) min=\(a.options.min) max=\(String(describing: a.options.max)) grat=\(a.options.graticule) rhs=legend=\(b.options.showLegend) ticks=\(b.options.ticks) min=\(b.options.min) max=\(String(describing: b.options.max)) grat=\(b.options.graticule)"
        ))
    }
    return deltas
}
