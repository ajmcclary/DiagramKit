import Foundation

// MARK: - Public Entry Point

public func layoutVennDiagram(_ diagram: VennDiagram) -> PositionedVennDiagram {
    let config = diagram.config
    let width = config.width
    let height = config.height
    let padding = config.padding
    let REFERENCE_WIDTH: Double = 1600.0
    let scale = width / REFERENCE_WIDTH
    let titleHeight = diagram.diagramTitle != nil ? 48.0 * scale : 0.0

    let areas = diagram.areas

    if areas.isEmpty {
        return PositionedVennDiagram(
            width: width, height: height, titleHeight: titleHeight,
            title: _makeTitle(diagram.diagramTitle, width: width, scale: scale),
            areas: [], textNodes: [], accTitle: diagram.accTitle,
            accDescr: diagram.accDescr, diagramTitle: diagram.diagramTitle,
            config: config, themeName: diagram.themeName,
            themeVariables: diagram.themeVariables,
            useDebugLayout: config.useDebugLayout
        )
    }

    let layoutWidth = width
    let layoutHeight = height - titleHeight

    // Collect all unique set ids
    let allSetIds = collectAllSetIds(from: areas)
    let setCount = allSetIds.count
    var setIdToIndex: [String: Int] = [:]
    for (i, setId) in allSetIds.enumerated() {
        setIdToIndex[setId] = i
    }

    // Compute raw radii from area sizes: r = sqrt(size / pi)
    var rawRadii: [Double] = Array(repeating: 0, count: setCount)
    for area in areas where area.isSingleSet {
        if let idx = setIdToIndex[area.sets[0]] {
            rawRadii[idx] = sqrt(max(area.size, 0.01) / .pi)
        }
    }

    // Scale radii to fit viewport: largest radius uses ~40% of smaller viewport dimension
    let maxRadius = rawRadii.max() ?? 1.0
    let targetMaxRadius = min(layoutWidth, layoutHeight) * 0.35 - padding
    let radiusScale = maxRadius > 0 ? targetMaxRadius / maxRadius : 30.0
    let radii = rawRadii.map { $0 * radiusScale }

    // Compute circle centers
    let centers = computeCircleCenters(
        setIds: allSetIds,
        areas: areas,
        radii: radii,
        radiusScale: radiusScale,
        layoutWidth: layoutWidth,
        layoutHeight: layoutHeight,
        padding: padding
    )

    // Build positioned areas
    var positionedAreas: [PositionedVennArea] = []
    for (areaIndex, area) in areas.enumerated() {
        let pa = makePositionedArea(
            area: area,
            areaIndex: areaIndex,
            setIdToIndex: setIdToIndex,
            centers: centers,
            radii: radii,
            scale: scale,
            styleEntries: diagram.styleEntries,
            themeVariables: diagram.themeVariables,
            layoutWidth: layoutWidth,
            layoutHeight: layoutHeight
        )
        positionedAreas.append(pa)
    }

    // Build positioned text nodes
    var positionedTextNodes: [PositionedVennTextNode] = []
    let nodesByArea = Dictionary(grouping: diagram.textNodes) { $0.sets.sorted().joined(separator: "|") }
    for area in positionedAreas {
        guard let nodes = nodesByArea[area.setsKey] else { continue }
        let pnodes = layoutTextNodes(
            for: area,
            nodes: nodes,
            nodeIndex: positionedTextNodes.count,
            scale: scale,
            styleEntries: diagram.styleEntries,
            debugLayout: config.useDebugLayout
        )
        positionedTextNodes.append(contentsOf: pnodes)
    }

    return PositionedVennDiagram(
        width: width, height: height, titleHeight: titleHeight,
        title: _makeTitle(diagram.diagramTitle, width: width, scale: scale),
        areas: positionedAreas, textNodes: positionedTextNodes,
        accTitle: diagram.accTitle, accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle, config: config,
        themeName: diagram.themeName, themeVariables: diagram.themeVariables,
        useDebugLayout: config.useDebugLayout
    )
}

// MARK: - Circle Center Computation

private func computeCircleCenters(
    setIds: [String],
    areas: [VennArea],
    radii: [Double],
    radiusScale: Double,
    layoutWidth: Double,
    layoutHeight: Double,
    padding: Double
) -> [VennPoint] {
    let setCount = setIds.count
    let cx = layoutWidth / 2
    let cy = layoutHeight / 2

    var centers: [VennPoint] = Array(repeating: VennPoint(x: cx, y: cy), count: setCount)
    let pairDistances = desiredPairDistances(setIds: setIds, areas: areas, radii: radii, radiusScale: radiusScale)

    switch setCount {
    case 0:
        break
    case 1:
        centers[0] = VennPoint(x: cx, y: cy)
    case 2:
        let fallback = min(radii[0], radii[1]) * 1.6
        let distance = pairDistances[[0, 1]] ?? fallback
        let halfDist = distance / 2
        centers[0] = VennPoint(x: cx - halfDist, y: cy)
        centers[1] = VennPoint(x: cx + halfDist, y: cy)
    case 3:
        centers = triangleCenters(
            radii: radii,
            pairDistances: pairDistances,
            centerX: cx,
            centerY: cy
        )
    default:
        let ringRadius = min(layoutWidth, layoutHeight) * 0.25
        for i in 0..<setCount {
            let angle = 2.0 * .pi * Double(i) / Double(setCount) - .pi / 2
            centers[i] = VennPoint(x: cx + ringRadius * cos(angle), y: cy + ringRadius * sin(angle))
        }
    }

    return centers
}

private func desiredPairDistances(
    setIds: [String],
    areas: [VennArea],
    radii: [Double],
    radiusScale: Double
) -> [Set<Int>: Double] {
    var setIdToIndex: [String: Int] = [:]
    for (idx, setId) in setIds.enumerated() {
        setIdToIndex[setId] = idx
    }

    var distances: [Set<Int>: Double] = [:]
    for area in areas where area.sets.count == 2 {
        guard
            let first = setIdToIndex[area.sets[0]],
            let second = setIdToIndex[area.sets[1]],
            first < radii.count,
            second < radii.count
        else { continue }
        let requestedArea = max(0, area.size) * radiusScale * radiusScale
        distances[Set([first, second])] = distanceForCircleOverlap(
            r0: radii[first],
            r1: radii[second],
            targetArea: requestedArea
        )
    }
    return distances
}

private func triangleCenters(
    radii: [Double],
    pairDistances: [Set<Int>: Double],
    centerX: Double,
    centerY: Double
) -> [VennPoint] {
    let fallback = max((radii.min() ?? 10) * 1.2, 10)
    let d01 = max(pairDistances[[0, 1]] ?? fallback, 1)
    let d02 = max(pairDistances[[0, 2]] ?? fallback, 1)
    let d12 = max(pairDistances[[1, 2]] ?? fallback, 1)

    let x2 = (d02 * d02 + d01 * d01 - d12 * d12) / (2 * d01)
    let y2Squared = d02 * d02 - x2 * x2

    let raw: [VennPoint]
    if y2Squared.isFinite, y2Squared > 0 {
        raw = [
            VennPoint(x: 0, y: 0),
            VennPoint(x: d01, y: 0),
            VennPoint(x: x2, y: sqrt(y2Squared))
        ]
    } else {
        let angleOffset = 2.0 * .pi / 3.0
        raw = [
            VennPoint(x: fallback * cos(0), y: fallback * sin(0)),
            VennPoint(x: fallback * cos(angleOffset), y: fallback * sin(angleOffset)),
            VennPoint(x: fallback * cos(2 * angleOffset), y: fallback * sin(2 * angleOffset))
        ]
    }

    let minX = raw.map(\.x).min() ?? 0
    let maxX = raw.map(\.x).max() ?? 0
    let minY = raw.map(\.y).min() ?? 0
    let maxY = raw.map(\.y).max() ?? 0
    let rawCenterX = (minX + maxX) / 2
    let rawCenterY = (minY + maxY) / 2

    return raw.map {
        VennPoint(x: centerX + $0.x - rawCenterX, y: centerY + $0.y - rawCenterY)
    }
}

private func distanceForCircleOverlap(r0: Double, r1: Double, targetArea: Double) -> Double {
    let maxArea = .pi * min(r0, r1) * min(r0, r1)
    guard targetArea > 0 else { return r0 + r1 }
    guard targetArea < maxArea else { return abs(r0 - r1) }

    var low = abs(r0 - r1)
    var high = r0 + r1
    for _ in 0..<60 {
        let mid = (low + high) / 2
        let area = circleOverlapArea(r0: r0, r1: r1, distance: mid)
        if area > targetArea {
            low = mid
        } else {
            high = mid
        }
    }
    return (low + high) / 2
}

private func circleOverlapArea(r0: Double, r1: Double, distance d: Double) -> Double {
    if d >= r0 + r1 { return 0 }
    if d <= abs(r0 - r1) {
        let r = min(r0, r1)
        return .pi * r * r
    }

    let alpha = acos(max(-1, min(1, (d * d + r0 * r0 - r1 * r1) / (2 * d * r0))))
    let beta = acos(max(-1, min(1, (d * d + r1 * r1 - r0 * r0) / (2 * d * r1))))
    let area0 = r0 * r0 * alpha
    let area1 = r1 * r1 * beta
    let area2 = 0.5 * sqrt(max(0, (-d + r0 + r1) * (d + r0 - r1) * (d - r0 + r1) * (d + r0 + r1)))
    return area0 + area1 - area2
}

// MARK: - Positioned Area Construction

private func makePositionedArea(
    area: VennArea,
    areaIndex: Int,
    setIdToIndex: [String: Int],
    centers: [VennPoint],
    radii: [Double],
    scale: Double,
    styleEntries: [VennStyleEntry],
    themeVariables: [String: String]?,
    layoutWidth: Double,
    layoutHeight: Double
) -> PositionedVennArea {
    let setsKey = area.setsKey
    let centerX = layoutWidth / 2
    let centerY = layoutHeight / 2

    var circles: [VennCircle] = []
    if area.isSingleSet, let idx = setIdToIndex[area.sets[0]], idx < centers.count, idx < radii.count {
        circles = [VennCircle(center: centers[idx], radius: radii[idx])]
    }

    // Text point
    let textPoint: VennPoint
    if area.isSingleSet, let idx = setIdToIndex[area.sets[0]], idx < centers.count {
        textPoint = centers[idx]
    } else {
        let involvedCenters = area.sets.compactMap { setIdToIndex[$0] }.filter { $0 < centers.count }.map { centers[$0] }
        if involvedCenters.isEmpty {
            textPoint = VennPoint(x: centerX, y: centerY)
        } else {
            let avgX = involvedCenters.map(\.x).reduce(0, +) / Double(involvedCenters.count)
            let avgY = involvedCenters.map(\.y).reduce(0, +) / Double(involvedCenters.count)
            textPoint = VennPoint(x: avgX, y: avgY)
        }
    }

    // Path spec for intersections
    var pathSpec: String? = nil
    if !area.isSingleSet, area.sets.count >= 2 {
        pathSpec = makeIntersectionPath(
            setIds: area.sets,
            setIdToIndex: setIdToIndex,
            centers: centers,
            radii: radii
        )
    }

    let colorIndex = areaIndex % 8
    let colorClass = "venn-set-\(colorIndex)"

    let defaultFillColor = themeVariables?["venn\(colorIndex + 1)"] ?? VennThemeDefaults.defaultColors[colorIndex]
    let fillColor = style(for: setsKey, entries: styleEntries, key: "fill") ?? defaultFillColor
    let hasCustomFill = style(for: setsKey, entries: styleEntries, key: "fill") != nil
    let fillOpacity = styleOpacity(for: setsKey, entries: styleEntries, key: "fill-opacity") ?? (area.isSingleSet ? 0.1 : (hasCustomFill ? 1.0 : 0.0))
    let strokeColor = style(for: setsKey, entries: styleEntries, key: "stroke") ?? fillColor
    let strokeWidth = styleDouble(for: setsKey, entries: styleEntries, key: "stroke-width") ?? 5.0 * scale
    let textColor = style(for: setsKey, entries: styleEntries, key: "color") ?? themeVariables?["vennSetTextColor"] ?? VennThemeDefaults.defaultSetTextColor

    return PositionedVennArea(
        setsKey: setsKey,
        sets: area.sets,
        label: area.label,
        size: area.size,
        circles: circles,
        pathSpec: pathSpec,
        textPoint: textPoint,
        fillColor: fillColor,
        fillOpacity: fillOpacity,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        textColor: textColor,
        textFontSize: 48.0 * scale,
        colorClass: colorClass,
        debugFlags: false
    )
}

// MARK: - Intersection Path Generation

private func makeIntersectionPath(
    setIds: [String],
    setIdToIndex: [String: Int],
    centers: [VennPoint],
    radii: [Double]
) -> String? {
    let indices = setIds.compactMap { setIdToIndex[$0] }
    guard indices.count >= 2, indices.allSatisfy({ $0 < centers.count && $0 < radii.count }) else { return nil }

    if indices.count == 2 {
        return makeTwoSetIntersectionPath(
            c0: centers[indices[0]], r0: radii[indices[0]],
            c1: centers[indices[1]], r1: radii[indices[1]]
        )
    }
    return makeMultiSetIntersectionPath(indices: indices, centers: centers, radii: radii)
}

private func makeTwoSetIntersectionPath(c0: VennPoint, r0: Double, c1: VennPoint, r1: Double) -> String? {
    let dx = c1.x - c0.x
    let dy = c1.y - c0.y
    let dist = sqrt(dx * dx + dy * dy)

    guard dist > 0, dist < r0 + r1 else { return nil }

    let a = (r0 * r0 - r1 * r1 + dist * dist) / (2 * dist)
    let h_sq = r0 * r0 - a * a
    guard h_sq > 0 else { return nil }
    let h = sqrt(h_sq)

    let px = c0.x + a * dx / dist
    let py = c0.y + a * dy / dist

    let ix1 = px - h * dy / dist
    let iy1 = py + h * dx / dist
    let ix2 = px + h * dy / dist
    let iy2 = py - h * dx / dist

    let theta1 = atan2(iy1 - c0.y, ix1 - c0.x)
    let theta2 = atan2(iy2 - c0.y, ix2 - c0.x)
    let phi1 = atan2(iy1 - c1.y, ix1 - c1.x)
    let phi2 = atan2(iy2 - c1.y, ix2 - c1.x)

    let thetaSweep = abs(theta2 - theta1)
    let phiSweep = abs(phi2 - phi1)

    let useThetaLarge = thetaSweep > .pi
    let usePhiLarge = phiSweep > .pi

    let fmt: (Double) -> String = { String(format: "%.3f", $0) }

    return [
        "M \(fmt(ix1)) \(fmt(iy1))",
        "A \(fmt(r0)) \(fmt(r0)) 0 \(useThetaLarge ? "1" : "0") 0 \(fmt(ix2)) \(fmt(iy2))",
        "A \(fmt(r1)) \(fmt(r1)) 0 \(usePhiLarge ? "1" : "0") 1 \(fmt(ix1)) \(fmt(iy1))",
        "Z"
    ].joined(separator: " ")
}

private func makeMultiSetIntersectionPath(indices: [Int], centers: [VennPoint], radii: [Double]) -> String? {
    var candidates: [VennPoint] = []

    for i in 0..<indices.count {
        for j in (i + 1)..<indices.count {
            let a = indices[i]
            let b = indices[j]
            for point in circleIntersectionPoints(c0: centers[a], r0: radii[a], c1: centers[b], r1: radii[b]) {
                if pointIsInsideAllCircles(point, indices: indices, centers: centers, radii: radii) {
                    candidates.append(point)
                }
            }
        }
    }

    let unique = uniquePoints(candidates)
    guard unique.count >= 3 else { return nil }

    let centroid = VennPoint(
        x: unique.map(\.x).reduce(0, +) / Double(unique.count),
        y: unique.map(\.y).reduce(0, +) / Double(unique.count)
    )
    let sorted = unique.sorted {
        atan2($0.y - centroid.y, $0.x - centroid.x) < atan2($1.y - centroid.y, $1.x - centroid.x)
    }

    let fmt: (Double) -> String = { String(format: "%.3f", $0) }
    var commands = ["M \(fmt(sorted[0].x)) \(fmt(sorted[0].y))"]
    for point in sorted.dropFirst() {
        commands.append("L \(fmt(point.x)) \(fmt(point.y))")
    }
    commands.append("Z")
    return commands.joined(separator: " ")
}

private func circleIntersectionPoints(c0: VennPoint, r0: Double, c1: VennPoint, r1: Double) -> [VennPoint] {
    let dx = c1.x - c0.x
    let dy = c1.y - c0.y
    let d = sqrt(dx * dx + dy * dy)
    guard d > 0, d <= r0 + r1, d >= abs(r0 - r1) else { return [] }

    let a = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
    let hSquared = r0 * r0 - a * a
    guard hSquared >= 0 else { return [] }
    let h = sqrt(max(0, hSquared))
    let px = c0.x + a * dx / d
    let py = c0.y + a * dy / d
    let rx = -dy * h / d
    let ry = dx * h / d

    return [
        VennPoint(x: px + rx, y: py + ry),
        VennPoint(x: px - rx, y: py - ry)
    ]
}

private func pointIsInsideAllCircles(_ point: VennPoint, indices: [Int], centers: [VennPoint], radii: [Double]) -> Bool {
    indices.allSatisfy { idx in
        let dx = point.x - centers[idx].x
        let dy = point.y - centers[idx].y
        return sqrt(dx * dx + dy * dy) <= radii[idx] + 0.001
    }
}

private func uniquePoints(_ points: [VennPoint]) -> [VennPoint] {
    var result: [VennPoint] = []
    for point in points {
        if !result.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 0.01 }) {
            result.append(point)
        }
    }
    return result
}

// MARK: - Text Node Layout

private func layoutTextNodes(
    for area: PositionedVennArea,
    nodes: [VennTextNode],
    nodeIndex: Int,
    scale: Double,
    styleEntries: [VennStyleEntry],
    debugLayout: Bool
) -> [PositionedVennTextNode] {
    var result: [PositionedVennTextNode] = []

    let nodeCount = nodes.count
    guard nodeCount > 0 else { return result }

    var innerRadius: Double = 30
    if let circle = area.circles.first {
        innerRadius = circle.radius * 0.6
    } else if area.sets.count >= 2 {
        innerRadius = area.size * 2.0
    }
    innerRadius = max(innerRadius, 20)

    let cols = Int(ceil(sqrt(Double(nodeCount))))
    let rows = Int(ceil(Double(nodeCount) / Double(cols)))

    let cellWidth = innerRadius * 1.4 / Double(cols)
    let cellHeight = innerRadius * 1.4 / Double(rows)
    let startX = area.textPoint.x - innerRadius * 0.7
    let startY = area.textPoint.y - innerRadius * 0.7

    for (i, node) in nodes.enumerated() {
        let col = i % cols
        let row = i / cols
        let x = startX + Double(col) * cellWidth + cellWidth / 2
        let y = startY + Double(row) * cellHeight + cellHeight / 2

        let textColor = style(for: node.id, entries: styleEntries, key: "color") ?? area.textColor

        result.append(PositionedVennTextNode(
            areaKey: area.setsKey,
            id: node.id,
            label: node.label ?? node.id,
            x: x - cellWidth / 2 + 2,
            y: y - cellHeight / 2 + 2,
            width: max(cellWidth - 4, 10),
            height: max(cellHeight - 4, 10),
            textColor: textColor,
            debugCell: debugLayout
        ))
    }

    return result
}

// MARK: - Style Helpers

private func style(for targetKey: String, entries: [VennStyleEntry], key: String) -> String? {
    for entry in entries where entry.targetsKey == targetKey || entry.targets.contains(targetKey) {
        if let val = entry.styles[key] { return val }
    }
    return nil
}

private func styleOpacity(for targetKey: String, entries: [VennStyleEntry], key: String) -> Double? {
    guard let val = style(for: targetKey, entries: entries, key: key) else { return nil }
    return Double(val)
}

private func styleDouble(for targetKey: String, entries: [VennStyleEntry], key: String) -> Double? {
    guard let val = style(for: targetKey, entries: entries, key: key) else { return nil }
    return Double(val)
}

// MARK: - Title

private func _makeTitle(_ title: String?, width: Double, scale: Double) -> PositionedVennTitle? {
    guard let t = title else { return nil }
    return PositionedVennTitle(
        text: t,
        x: width / 2,
        y: 32 * scale,
        fontSize: 32 * scale,
        fillColor: VennThemeDefaults.defaultTitleTextColor
    )
}

// MARK: - Utility

private func collectAllSetIds(from areas: [VennArea]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for area in areas {
        for s in area.sets {
            if !seen.contains(s) {
                seen.insert(s)
                result.append(s)
            }
        }
    }
    return result
}
