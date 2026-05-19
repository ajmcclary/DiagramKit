import DiagramKitModel

func diffQuadrantChart(_ a: QuadrantChart, _ b: QuadrantChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    let aTitle = a.diagramTitle ?? a.titleText
    let bTitle = b.diagramTitle ?? b.titleText
    if aTitle != bTitle {
        deltas.append(.unexpected(
            path: "quadrant.title",
            detail: "lhs=\(aTitle ?? "nil") rhs=\(bTitle ?? "nil")"
        ))
    }

    let labels: [(String, String?, String?)] = [
        ("xAxisLeft", a.xAxisLeftText, b.xAxisLeftText),
        ("xAxisRight", a.xAxisRightText, b.xAxisRightText),
        ("yAxisBottom", a.yAxisBottomText, b.yAxisBottomText),
        ("yAxisTop", a.yAxisTopText, b.yAxisTopText),
        ("quadrant1", a.quadrant1Text, b.quadrant1Text),
        ("quadrant2", a.quadrant2Text, b.quadrant2Text),
        ("quadrant3", a.quadrant3Text, b.quadrant3Text),
        ("quadrant4", a.quadrant4Text, b.quadrant4Text),
    ]
    for (name, lhs, rhs) in labels where lhs != rhs {
        deltas.append(.unexpected(
            path: "quadrant.\(name)",
            detail: "lhs=\(lhs ?? "nil") rhs=\(rhs ?? "nil")"
        ))
    }

    func pointKey(_ p: QuadrantPoint) -> String {
        "\(p.text)|\(p.x)|\(p.y)|\(p.className ?? "")"
    }
    let lhsPoints = Set(a.points.map(pointKey))
    let rhsPoints = Set(b.points.map(pointKey))
    if lhsPoints != rhsPoints {
        deltas.append(.unexpected(
            path: "quadrant.points",
            detail: "onlyLhs=\(lhsPoints.subtracting(rhsPoints).sorted()) onlyRhs=\(rhsPoints.subtracting(lhsPoints).sorted())"
        ))
    }

    let lhsClassNames = Set(a.classes.keys)
    let rhsClassNames = Set(b.classes.keys)
    if lhsClassNames != rhsClassNames {
        deltas.append(.unexpected(
            path: "quadrant.classes.keys",
            detail: "onlyLhs=\(lhsClassNames.subtracting(rhsClassNames).sorted()) onlyRhs=\(rhsClassNames.subtracting(lhsClassNames).sorted())"
        ))
    }
    return deltas
}
