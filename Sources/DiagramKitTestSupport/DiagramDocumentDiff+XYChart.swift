import DiagramKitModel

func diffXYChart(_ a: XYChart, _ b: XYChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "xychart.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.horizontal != b.horizontal {
        deltas.append(.unexpected(
            path: "xychart.horizontal",
            detail: "lhs=\(a.horizontal) rhs=\(b.horizontal)"
        ))
    }

    if a.xAxis.title != b.xAxis.title {
        deltas.append(.unexpected(
            path: "xychart.xAxis.title",
            detail: "lhs=\(a.xAxis.title ?? "nil") rhs=\(b.xAxis.title ?? "nil")"
        ))
    }
    if (a.xAxis.categories ?? []) != (b.xAxis.categories ?? []) {
        deltas.append(.unexpected(
            path: "xychart.xAxis.categories",
            detail: "lhs=\(a.xAxis.categories ?? []) rhs=\(b.xAxis.categories ?? [])"
        ))
    }
    if a.yAxis.title != b.yAxis.title {
        deltas.append(.unexpected(
            path: "xychart.yAxis.title",
            detail: "lhs=\(a.yAxis.title ?? "nil") rhs=\(b.yAxis.title ?? "nil")"
        ))
    }
    let aRange = a.yAxis.range.map { ($0.min, $0.max) }
    let bRange = b.yAxis.range.map { ($0.min, $0.max) }
    if aRange?.0 != bRange?.0 || aRange?.1 != bRange?.1 {
        deltas.append(.unexpected(
            path: "xychart.yAxis.range",
            detail: "lhs=\(String(describing: aRange)) rhs=\(String(describing: bRange))"
        ))
    }

    if a.series.count != b.series.count {
        deltas.append(.unexpected(
            path: "xychart.series.count",
            detail: "lhs=\(a.series.count) rhs=\(b.series.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.series, b.series).enumerated() {
        if l.type != r.type {
            deltas.append(.unexpected(
                path: "xychart.series[\(i)].type",
                detail: "lhs=\(l.type) rhs=\(r.type)"
            ))
        }
        if l.data != r.data {
            deltas.append(.unexpected(
                path: "xychart.series[\(i)].data",
                detail: "lhs=\(l.data) rhs=\(r.data)"
            ))
        }
    }
    return deltas
}
