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
            useDebugLayout: config.useDebugLayout,
            isHandDrawn: config.isHandDrawn,
            handDrawnSeed: config.handDrawnSeed
        )
    }

    let layoutWidth = width
    let layoutHeight = height - titleHeight

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

    // Scale radii to fit viewport
    let maxRadius = rawRadii.max() ?? 1.0
    let targetMaxRadius = min(layoutWidth, layoutHeight) * 0.35 - padding
    let radiusScale = maxRadius > 0 ? targetMaxRadius / maxRadius : 30.0
    let radii = rawRadii.map { $0 * radiusScale }

    // Detect disjoint clusters
    let clusters = detectDisjointClusters(setIds: allSetIds, areas: areas)
    var centers: [VennPoint] = Array(repeating: VennPoint(x: layoutWidth / 2, y: layoutHeight / 2), count: setCount)

    if clusters.count == 1 {
        centers = optimizeCircleCenters(
            setIds: allSetIds,
            areas: areas,
            radii: radii,
            radiusScale: radiusScale,
            layoutWidth: layoutWidth,
            layoutHeight: layoutHeight
        )
    } else {
        // Lay out each cluster in a grid
        let cols = Int(ceil(sqrt(Double(clusters.count))))
        let rows = Int(ceil(Double(clusters.count) / Double(cols)))
        let cellW = layoutWidth / Double(cols)
        let cellH = layoutHeight / Double(rows)

        for (ci, cluster) in clusters.enumerated() {
            let col = ci % cols
            let row = ci / cols
            let cx = Double(col) * cellW + cellW / 2
            let cy = Double(row) * cellH + cellH / 2
            let cW = cellW - padding * 2
            let cH = cellH - padding * 2

            // Filter areas belonging to this cluster
            let clusterSetIdSet = Set(cluster)
            let clusterAreas = areas.filter { area in
                area.sets.allSatisfy { clusterSetIdSet.contains($0) }
            }
            let clusterSetIds = clusterAreas.flatMap(\.sets).uniqueSorted()

            var clusterRadii: [Double] = []
            var clusterSetIdToIdx: [String: Int] = [:]
            for (i, sid) in clusterSetIds.enumerated() {
                clusterSetIdToIdx[sid] = i
                if let globalIdx = setIdToIndex[sid], globalIdx < radii.count {
                    clusterRadii.append(radii[globalIdx])
                } else {
                    clusterRadii.append(30)
                }
            }

            let clusterCenters = optimizeCircleCenters(
                setIds: clusterSetIds,
                areas: clusterAreas,
                radii: clusterRadii,
                radiusScale: radiusScale,
                layoutWidth: cW,
                layoutHeight: cH
            )

            for (i, sid) in clusterSetIds.enumerated() {
                if let globalIdx = setIdToIndex[sid] {
                    centers[globalIdx] = VennPoint(
                        x: cx + clusterCenters[i].x - cW / 2,
                        y: cy + clusterCenters[i].y - cH / 2
                    )
                }
            }
        }
    }

    // Build positioned areas
    var positionedAreas: [PositionedVennArea] = []
    let mergedStyles = buildMergedStyles(styleEntries: diagram.styleEntries)

    for (areaIndex, area) in areas.enumerated() {
        let pa = makePositionedArea(
            area: area,
            areaIndex: areaIndex,
            setIdToIndex: setIdToIndex,
            centers: centers,
            radii: radii,
            scale: scale,
            mergedStyles: mergedStyles,
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
            mergedStyles: mergedStyles,
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
        useDebugLayout: config.useDebugLayout,
        isHandDrawn: config.isHandDrawn,
        handDrawnSeed: config.handDrawnSeed
    )
}

// MARK: - Disjoint Cluster Detection

private func detectDisjointClusters(setIds: [String], areas: [VennArea]) -> [[String]] {
    let setCount = setIds.count
    if setCount <= 1 { return [setIds] }

    var setIdToIdx: [String: Int] = [:]
    for (i, sid) in setIds.enumerated() {
        setIdToIdx[sid] = i
    }

    // Union-find
    var parent = Array(0..<setCount)

    func find(_ x: Int) -> Int {
        if parent[x] != x {
            parent[x] = find(parent[x])
        }
        return parent[x]
    }

    func union(_ a: Int, _ b: Int) {
        parent[find(a)] = find(b)
    }

    for area in areas where area.sets.count >= 2 {
        let indices = area.sets.compactMap { setIdToIdx[$0] }
        for i in 1..<indices.count {
            union(indices[0], indices[i])
        }
    }

    var clusterMap: [Int: [String]] = [:]
    for (i, sid) in setIds.enumerated() {
        let root = find(i)
        clusterMap[root, default: []].append(sid)
    }

    // Sort clusters by their root index for deterministic iteration (Dictionary
    // `.values` order is unspecified in Swift).
    return clusterMap.keys.sorted().map { clusterMap[$0]! }
}

// MARK: - Loss-Function Optimizer (Nelder-Mead)

private func optimizeCircleCenters(
    setIds: [String],
    areas: [VennArea],
    radii: [Double],
    radiusScale: Double,
    layoutWidth: Double,
    layoutHeight: Double
) -> [VennPoint] {
    let setCount = setIds.count
    let cx = layoutWidth / 2
    let cy = layoutHeight / 2

    if setCount == 0 { return [] }
    if setCount == 1 {
        return [VennPoint(x: cx, y: cy)]
    }

    // Build target overlap map
    var setIdToIdx: [String: Int] = [:]
    for (i, sid) in setIds.enumerated() {
        setIdToIdx[sid] = i
    }

    // Collect target areas: keyed by sorted index tuple
    var targetAreas: [Set<Int>: Double] = [:]
    for area in areas where area.sets.count >= 2 {
        let indices = area.sets.compactMap { setIdToIdx[$0] }
        guard indices.count >= 2 else { continue }
        targetAreas[Set(indices)] = max(0, area.size) * radiusScale * radiusScale
    }

    guard !targetAreas.isEmpty else {
        // No overlap targets: arrange in a ring
        let ringRadius = min(layoutWidth, layoutHeight) * 0.3
        var result: [VennPoint] = []
        for i in 0..<setCount {
            let angle = 2.0 * .pi * Double(i) / Double(setCount) - .pi / 2
            result.append(VennPoint(x: cx + ringRadius * cos(angle), y: cy + ringRadius * sin(angle)))
        }
        return result
    }

    // Initial guess: arrange in ring
    let ringRadius = min(layoutWidth, layoutHeight) * 0.25
    var initial: [Double] = []
    for i in 0..<setCount {
        let angle = 2.0 * .pi * Double(i) / Double(setCount) - .pi / 2
        initial.append(cx + ringRadius * cos(angle))
        initial.append(cy + ringRadius * sin(angle))
    }

    // Loss function. Iterate `targetAreas` in a deterministic order so
    // floating-point accumulation is identical across runs (Dictionary
    // iteration order is unspecified in Swift).
    let sortedTargetAreas: [(Set<Int>, Double)] = targetAreas
        .map { ($0.key, $0.value) }
        .sorted { lhs, rhs in
            let l = lhs.0.sorted()
            let r = rhs.0.sorted()
            if l.count != r.count { return l.count < r.count }
            for (a, b) in zip(l, r) where a != b { return a < b }
            return false
        }
    func loss(_ coords: [Double]) -> Double {
        var totalError: Double = 0
        for (indices, targetArea) in sortedTargetAreas {
            let actual = computeMultiCircleOverlapArea(indices: Array(indices), coords: coords, radii: radii)
            let err = actual - targetArea
            let weight = indices.count == 2 ? 1.0 : 2.0
            totalError += weight * err * err
        }
        // Penalize centers drifting too far from viewport
        for i in 0..<setCount {
            let x = coords[i * 2]
            let y = coords[i * 2 + 1]
            if x < -layoutWidth || x > layoutWidth * 2 || y < -layoutHeight || y > layoutHeight * 2 {
                totalError += 1e6
            }
        }
        return totalError
    }

    // Nelder-Mead optimization
    let n = setCount * 2
    let alpha: Double = 1.0
    let gamma: Double = 2.0
    let rho: Double = 0.5
    let sigma: Double = 0.5
    let maxIterations = 400
    let convergenceThreshold = 1e-6 * max(radii.max() ?? 10, 10)

    var simplex: [[Double]] = []
    simplex.append(initial)
    for i in 0..<n {
        var point = initial
        point[i] += max(radii[i / 2] * 0.1, 5)
        simplex.append(point)
    }

    for _ in 0..<maxIterations {
        // Sort by loss
        simplex.sort { loss($0) < loss($1) }

        // Check convergence
        let bestLoss = loss(simplex[0])
        let worstLoss = loss(simplex[n])
        if abs(worstLoss - bestLoss) < convergenceThreshold {
            break
        }

        // Centroid of best n points
        var centroid = Array(repeating: 0.0, count: n)
        for i in 0..<n {
            for j in 0..<n {
                centroid[j] += simplex[i][j]
            }
        }
        for j in 0..<n {
            centroid[j] /= Double(n)
        }

        // Reflection
        var reflected = Array(repeating: 0.0, count: n)
        for j in 0..<n {
            reflected[j] = centroid[j] + alpha * (centroid[j] - simplex[n][j])
        }

        if loss(reflected) < loss(simplex[n - 1]) {
            // Better than second-worst, keep it
            simplex[n] = reflected
            continue
        }

        if loss(reflected) < loss(simplex[0]) {
            // Best so far: try expansion
            var expanded = Array(repeating: 0.0, count: n)
            for j in 0..<n {
                expanded[j] = centroid[j] + gamma * (reflected[j] - centroid[j])
            }
            simplex[n] = loss(expanded) < loss(reflected) ? expanded : reflected
            continue
        }

        // Reflection was worse than second-worst
        if loss(reflected) < loss(simplex[n]) {
            // Outside contraction
            var contracted = Array(repeating: 0.0, count: n)
            for j in 0..<n {
                contracted[j] = centroid[j] + rho * (reflected[j] - centroid[j])
            }
            if loss(contracted) < loss(reflected) {
                simplex[n] = contracted
                continue
            }
        } else {
            // Inside contraction
            var contracted = Array(repeating: 0.0, count: n)
            for j in 0..<n {
                contracted[j] = centroid[j] + rho * (simplex[n][j] - centroid[j])
            }
            if loss(contracted) < loss(simplex[n]) {
                simplex[n] = contracted
                continue
            }
        }

        // Shrink
        for i in 1...n {
            for j in 0..<n {
                simplex[i][j] = simplex[0][j] + sigma * (simplex[i][j] - simplex[0][j])
            }
        }
    }

    // Return best
    simplex.sort { loss($0) < loss($1) }
    let best = simplex[0]
    var result: [VennPoint] = []
    for i in 0..<setCount {
        result.append(VennPoint(x: best[i * 2], y: best[i * 2 + 1]))
    }
    return result
}

// MARK: - Multi-Circle Overlap Area Computation

/// Compute the actual overlap area of N circles using intersection-point polygon + arc segments.
private func computeMultiCircleOverlapArea(indices: [Int], coords: [Double], radii: [Double]) -> Double {
    guard indices.count >= 2 else { return 0 }
    guard indices.allSatisfy({ $0 < radii.count }) else { return 0 }

    let n = indices.count

    // Build point arrays from coords
    let centers: [VennPoint] = indices.map { i in
        VennPoint(x: coords[i * 2], y: coords[i * 2 + 1])
    }
    let cr: [Double] = indices.map { radii[$0] }

    // Check if all circles contain at least one circle entirely
    for i in 0..<n {
        for j in i+1..<n {
            let dx = centers[j].x - centers[i].x
            let dy = centers[j].y - centers[i].y
            let dist = hypot(dx, dy)
            if cr[i] > dist + cr[j] {
                // Circle i completely contains circle j, overlap is just circle j area
                // But we need ALL circles' intersection, check further
                var allContain = true
                for k in 0..<n where k != i {
                    let dk = hypot(centers[k].x - centers[j].x, centers[k].y - centers[j].y)
                    if !(cr[k] > dk + cr[j]) { allContain = false; break }
                }
                if allContain { return .pi * cr[j] * cr[j] }
            }
        }
    }

    // Find intersection points between all pairs of circles that lie inside ALL circles
    var candidatePoints: [VennPoint] = []
    for i in 0..<n {
        for j in (i + 1)..<n {
            let pts = circleIntersectionPoints(c0: centers[i], r0: cr[i], c1: centers[j], r1: cr[j])
            for pt in pts {
                var inside = true
                for k in 0..<n {
                    let d = hypot(pt.x - centers[k].x, pt.y - centers[k].y)
                    if d > cr[k] + 0.001 { inside = false; break }
                }
                if inside {
                    candidatePoints.append(pt)
                }
            }
        }
    }

    let unique = uniquePoints(candidatePoints)
    let m = unique.count

    if m < 3 {
        // Not enough intersection points to form a polygon.
        // Fall back to minimum circle area approximation
        let minArea = .pi * (cr.min() ?? 0) * (cr.min() ?? 0)
        let maxOverlap = circleOverlapArea(r0: cr[0], r1: cr[1], distance: hypot(centers[0].x - centers[1].x, centers[0].y - centers[1].y))
        if n == 2 { return maxOverlap }
        // For 3+, estimate from pairwise overlaps
        var est = maxOverlap
        for k in 2..<n {
            let dk = hypot(centers[k].x - centers[0].x, centers[k].y - centers[0].y)
            est = min(est, circleOverlapArea(r0: cr[0], r1: cr[k], distance: dk))
        }
        return min(est, minArea)
    }

    // Sort points angularly around centroid
    let centroid = VennPoint(
        x: unique.map(\.x).reduce(0, +) / Double(m),
        y: unique.map(\.y).reduce(0, +) / Double(m)
    )
    let sorted = unique.sorted {
        atan2($0.y - centroid.y, $0.x - centroid.x) < atan2($1.y - centroid.y, $1.x - centroid.x)
    }

    // Polygon area
    var polyArea: Double = 0
    for i in 0..<m {
        let j = (i + 1) % m
        polyArea += sorted[i].x * sorted[j].y - sorted[j].x * sorted[i].y
    }
    polyArea = abs(polyArea) / 2

    // Arc segment areas: for each polygon edge, add the circular segment area
    var arcArea: Double = 0
    for i in 0..<m {
        let j = (i + 1) % m
        let p1 = sorted[i]
        let p2 = sorted[j]

        // Determine which circle this edge belongs to
        for k in 0..<n {
            let d1 = hypot(p1.x - centers[k].x, p1.y - centers[k].y)
            let d2 = hypot(p2.x - centers[k].x, p2.y - centers[k].y)
            if abs(d1 - cr[k]) < 0.01 && abs(d2 - cr[k]) < 0.01 {
                let angle1 = atan2(p1.y - centers[k].y, p1.x - centers[k].x)
                let angle2 = atan2(p2.y - centers[k].y, p2.x - centers[k].x)
                var delta = angle2 - angle1
                if delta < 0 { delta += 2 * .pi }
                if delta > .pi {
                    let sectorArea = 0.5 * cr[k] * cr[k] * delta
                    let triArea = 0.5 * cr[k] * cr[k] * sin(delta)
                    arcArea += sectorArea - triArea
                } else {
                    // Need to check if this is interior - compute cross product
                    let midAngle = angle1 + delta / 2
                    let mx = centers[k].x + cr[k] * 0.5 * cos(midAngle)
                    let my = centers[k].y + cr[k] * 0.5 * sin(midAngle)
                    var inside = true
                    for other in 0..<n where other != k {
                        if hypot(mx - centers[other].x, my - centers[other].y) > cr[other] + 0.001 {
                            inside = false
                            break
                        }
                    }
                    if !inside {
                        let sectorArea = 0.5 * cr[k] * cr[k] * delta
                        let triArea = 0.5 * cr[k] * cr[k] * sin(delta)
                        arcArea += sectorArea - triArea
                    }
                }
                break
            }
        }
    }

    return polyArea + arcArea
}

// MARK: - Circle Geometry Helpers

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

private func uniquePoints(_ points: [VennPoint]) -> [VennPoint] {
    var result: [VennPoint] = []
    for point in points {
        if !result.contains(where: { hypot($0.x - point.x, $0.y - point.y) < 0.01 }) {
            result.append(point)
        }
    }
    return result
}

// MARK: - Merged Style Helpers

private func buildMergedStyles(styleEntries: [VennStyleEntry]) -> [String: [String: String]] {
    var merged: [String: [String: String]] = [:]
    for entry in styleEntries {
        let key = entry.targetsKey.isEmpty ? entry.targets.joined(separator: "|") : entry.targetsKey
        if merged[key] == nil {
            merged[key] = [:]
        }
        for (k, v) in entry.styles {
            merged[key]?[k] = v
        }
    }
    return merged
}

private func mergedStyle(for targetKey: String, mergedStyles: [String: [String: String]], key: String) -> String? {
    if let exact = mergedStyles[targetKey]?[key] {
        return exact
    }
    // Prefer single-target keys, then multi-target. Sort lexicographically
    // within each tier for deterministic iteration order across runs.
    let candidates = mergedStyles
        .filter { $0.key.split(separator: "|").contains(where: { $0 == targetKey }) }
        .sorted { lhs, rhs in
            let lc = lhs.key.split(separator: "|").count
            let rc = rhs.key.split(separator: "|").count
            if lc != rc { return lc < rc }
            return lhs.key < rhs.key
        }
    return candidates.first(where: { $0.value[key] != nil })?.value[key]
}

private func mergedStyle(forTargets targets: [String], mergedStyles: [String: [String: String]], key: String) -> String? {
    let targetsKey = targets.sorted().joined(separator: "|")
    if let val = mergedStyles[targetsKey]?[key] { return val }
    for target in targets {
        if let val = mergedStyles[target]?[key] { return val }
    }
    return nil
}

// MARK: - Dark Theme / Text Contrast

private func hexToRGBA(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
    var cleaned = hex.trimmingCharacters(in: .whitespaces)
    if cleaned.hasPrefix("#") { cleaned = String(cleaned.dropFirst()) }
    if cleaned.count == 3 {
        let r = Double(Int(String(cleaned[cleaned.startIndex]), radix: 16) ?? 0) * 17
        let g = Double(Int(String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 1)]), radix: 16) ?? 0) * 17
        let b = Double(Int(String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: 2)]), radix: 16) ?? 0) * 17
        return (r, g, b, 255)
    }
    if cleaned.count >= 6 {
        let r = Double(Int(String(cleaned.prefix(2)), radix: 16) ?? 0)
        let g = Double(Int(String(cleaned.dropFirst(2).prefix(2)), radix: 16) ?? 0)
        let b = Double(Int(String(cleaned.dropFirst(4).prefix(2)), radix: 16) ?? 0)
        var a: Double = 255
        if cleaned.count >= 8 {
            a = Double(Int(String(cleaned.dropFirst(6).prefix(2)), radix: 16) ?? 255)
        }
        return (r, g, b, a)
    }
    return (0, 0, 0, 255)
}

private func luminance(_ hex: String) -> Double {
    let (r, g, b, _) = hexToRGBA(hex)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
}

private func isDark(_ hex: String) -> Bool {
    luminance(hex) < 0.5
}

private func contrastTextColor(for fillColor: String, isDarkTheme: Bool) -> String {
    let (r, g, b, _) = hexToRGBA(fillColor)
    let factor: Double = isDarkTheme ? 0.55 : -0.40
    let nr = max(0, min(255, r + r * factor))
    let ng = max(0, min(255, g + g * factor))
    let nb = max(0, min(255, b + b * factor))
    return String(format: "#%02X%02X%02X", Int(nr), Int(ng), Int(nb))
}

private func brighten(_ hex: String, amount: Double) -> String {
    let (r, g, b, _) = hexToRGBA(hex)
    let nr = min(255, r + (255 - r) * amount)
    let ng = min(255, g + (255 - g) * amount)
    let nb = min(255, b + (255 - b) * amount)
    return String(format: "#%02X%02X%02X", Int(nr), Int(ng), Int(nb))
}

private func darkenColor(_ hex: String, amount: Double) -> String {
    let (r, g, b, _) = hexToRGBA(hex)
    let nr = max(0, r * (1 - amount))
    let ng = max(0, g * (1 - amount))
    let nb = max(0, b * (1 - amount))
    return String(format: "#%02X%02X%02X", Int(nr), Int(ng), Int(nb))
}

// MARK: - Positioned Area Construction

private func makePositionedArea(
    area: VennArea,
    areaIndex: Int,
    setIdToIndex: [String: Int],
    centers: [VennPoint],
    radii: [Double],
    scale: Double,
    mergedStyles: [String: [String: String]],
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

    // Text point: for single sets use center; for intersections compute centroid
    let textPoint: VennPoint
    if area.isSingleSet, let idx = setIdToIndex[area.sets[0]], idx < centers.count {
        textPoint = centers[idx]
    } else {
        let involvedCenters = area.sets.compactMap { setIdToIndex[$0] }.filter { $0 < centers.count }.map { centers[$0] }
        if involvedCenters.isEmpty {
            textPoint = VennPoint(x: centerX, y: centerY)
        } else {
            // Compute centroid of intersection region if possible
            let indices = area.sets.compactMap { setIdToIndex[$0] }
            if indices.count >= 2 {
                let interPoints = allIntersectionPointsInOverlap(indices: indices, centers: centers, radii: radii)
                if let ctr = centroidOfPoints(interPoints) {
                    textPoint = ctr
                } else {
                    let avgX = involvedCenters.map(\.x).reduce(0, +) / Double(involvedCenters.count)
                    let avgY = involvedCenters.map(\.y).reduce(0, +) / Double(involvedCenters.count)
                    textPoint = VennPoint(x: avgX, y: avgY)
                }
            } else {
                let avgX = involvedCenters.map(\.x).reduce(0, +) / Double(involvedCenters.count)
                let avgY = involvedCenters.map(\.y).reduce(0, +) / Double(involvedCenters.count)
                textPoint = VennPoint(x: avgX, y: avgY)
            }
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

    let customFill = mergedStyle(forTargets: area.sets, mergedStyles: mergedStyles, key: "fill") ?? mergedStyle(for: setsKey, mergedStyles: mergedStyles, key: "fill")
    let fillColor = customFill ?? defaultFillColor
    let hasCustomFill = customFill != nil
    let customFillOpacity = mergedStyle(forTargets: area.sets, mergedStyles: mergedStyles, key: "fill-opacity") ?? mergedStyle(for: setsKey, mergedStyles: mergedStyles, key: "fill-opacity")
    let fillOpacity = customFillOpacity.flatMap(Double.init)
        ?? (area.isSingleSet ? 0.1 : (hasCustomFill ? 1.0 : 0.0))
    let customStroke = mergedStyle(forTargets: area.sets, mergedStyles: mergedStyles, key: "stroke") ?? mergedStyle(for: setsKey, mergedStyles: mergedStyles, key: "stroke")
    let strokeColor = customStroke ?? fillColor
    let customStrokeWidth = mergedStyle(forTargets: area.sets, mergedStyles: mergedStyles, key: "stroke-width") ?? mergedStyle(for: setsKey, mergedStyles: mergedStyles, key: "stroke-width")
    let strokeWidth = customStrokeWidth.flatMap(Double.init) ?? 5.0 * scale

    // Text color: custom > theme contrast > fallback
    let customColor = mergedStyle(forTargets: area.sets, mergedStyles: mergedStyles, key: "color") ?? mergedStyle(for: setsKey, mergedStyles: mergedStyles, key: "color")
    let defaultBg = themeVariables?["background"] ?? themeVariables?["mainBkg"] ?? "#f4f4f4"
    let isDarkBg = isDark(defaultBg)
    let textColor: String
    if let cc = customColor {
        textColor = cc
    } else {
        textColor = contrastTextColor(for: fillColor, isDarkTheme: isDarkBg)
    }

    // Inner radius for text node layout
    let innerRadius = computeSafestInnerRadius(area: area, setIdToIndex: setIdToIndex, centers: centers, radii: radii, textPoint: textPoint)

    // Has label
    let hasLabel = (area.label?.count ?? 0) > 0

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
        hasLabel: hasLabel,
        innerRadius: innerRadius,
        debugFlags: false
    )
}

private func computeSafestInnerRadius(area: VennArea, setIdToIndex: [String: Int], centers: [VennPoint], radii: [Double], textPoint: VennPoint) -> Double {
    let indices = area.sets.compactMap { setIdToIndex[$0] }
    guard !indices.isEmpty else { return 30 }

    let relevantRadii = indices.compactMap { $0 < radii.count ? radii[$0] : nil }
    let relevantCenters = indices.compactMap { $0 < centers.count ? centers[$0] : nil }
    guard !relevantRadii.isEmpty, !relevantCenters.isEmpty else { return 30 }

    let minCircleRadius = relevantRadii.min() ?? 30

    let innerDistances = zip(relevantCenters, relevantRadii).map { (c, r) in
        r - hypot(textPoint.x - c.x, textPoint.y - c.y)
    }
    let innerRadiusRaw = innerDistances.min() ?? 0
    var innerRadius = innerRadiusRaw.isFinite ? max(0, innerRadiusRaw) : 0
    if innerRadius == 0 {
        innerRadius = minCircleRadius * 0.6
    }
    return max(innerRadius, 10)
}

private func allIntersectionPointsInOverlap(indices: [Int], centers: [VennPoint], radii: [Double]) -> [VennPoint] {
    var candidates: [VennPoint] = []
    for i in 0..<indices.count {
        for j in (i + 1)..<indices.count {
            let a = indices[i]
            let b = indices[j]
            for pt in circleIntersectionPoints(c0: centers[a], r0: radii[a], c1: centers[b], r1: radii[b]) {
                var inside = true
                for k in indices {
                    if hypot(pt.x - centers[k].x, pt.y - centers[k].y) > radii[k] + 0.001 {
                        inside = false
                        break
                    }
                }
                if inside { candidates.append(pt) }
            }
        }
    }
    return candidates
}

private func centroidOfPoints(_ points: [VennPoint]) -> VennPoint? {
    let uniq = uniquePoints(points)
    guard !uniq.isEmpty else { return nil }
    return VennPoint(
        x: uniq.map(\.x).reduce(0, +) / Double(uniq.count),
        y: uniq.map(\.y).reduce(0, +) / Double(uniq.count)
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
    let candidates = allIntersectionPointsInOverlap(indices: indices, centers: centers, radii: radii)
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

// MARK: - Text Node Layout (Mermaid parity)

private func layoutTextNodes(
    for area: PositionedVennArea,
    nodes: [VennTextNode],
    nodeIndex: Int,
    scale: Double,
    mergedStyles: [String: [String: String]],
    debugLayout: Bool
) -> [PositionedVennTextNode] {
    var result: [PositionedVennTextNode] = []

    let nodeCount = nodes.count
    guard nodeCount > 0 else { return result }

    let centerX = area.textPoint.x
    let centerY = area.textPoint.y
    let innerRadius = max(area.innerRadius, 10)

    // Compute grid dimensions matching Mermaid vennerRenderer.ts:299-300
    let innerWidth = max(80 * scale, innerRadius * 2 * 0.95)
    let innerHeight = max(60 * scale, innerRadius * 2 * 0.95)

    // Label offset matching Mermaid vennerRenderer.ts:301-303
    let labelOffsetBase = area.hasLabel ? min(32 * scale, innerRadius * 0.25) : 0
    let labelOffset = labelOffsetBase + (nodeCount <= 2 ? 30 * scale : 0)
    let startX = centerX - innerWidth / 2
    let startY = centerY - innerHeight / 2 + labelOffset

    let cols = Int(ceil(sqrt(Double(nodeCount))))
    let rows = Int(ceil(Double(nodeCount) / Double(cols)))
    let cellWidth = innerWidth / Double(cols)
    let cellHeight = innerHeight / Double(rows)

    for (i, node) in nodes.enumerated() {
        let col = i % cols
        let row = i / cols
        let x = startX + cellWidth * (Double(col) + 0.5)
        let y = startY + cellHeight * (Double(row) + 0.5)

        let boxWidth = cellWidth * 0.9
        let boxHeight = cellHeight * 0.9

        let nodeTextColor = mergedStyle(for: node.id, mergedStyles: mergedStyles, key: "color") ?? area.textColor
        let fontSize = 40.0 * scale

        result.append(PositionedVennTextNode(
            areaKey: area.setsKey,
            id: node.id,
            label: node.label ?? node.id,
            x: x - boxWidth / 2,
            y: y - boxHeight / 2,
            width: max(boxWidth, 10),
            height: max(boxHeight, 10),
            textColor: nodeTextColor,
            fontSize: fontSize,
            debugCell: debugLayout
        ))
    }

    return result
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

private extension Array where Element == String {
    func uniqueSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
