import Foundation

public func layoutSankeyDiagram(_ diagram: SankeyDiagram) -> PositionedSankeyDiagram {
    let config = diagram.config
    let width = config.width
    let height = config.height
    let nodeWidth = config.nodeWidth
    var nodePadding = config.nodePadding

    if config.showValues {
        nodePadding += 15
    }

    guard !diagram.nodes.isEmpty else {
        return PositionedSankeyDiagram(
            width: width,
            height: height,
            config: config,
            diagramTitle: diagram.accTitle ?? diagram.diagramTitle,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr
        )
    }

    let nodeCount = diagram.nodes.count
    let nodeIndexMap = Dictionary(uniqueKeysWithValues: diagram.nodes.enumerated().map { ($1.id, $0) })

    var nodeValues = [Double](repeating: 0, count: nodeCount)
    var sourceLinks = [[_SankeyLayoutLink]](repeating: [], count: nodeCount)
    var targetLinks = [[_SankeyLayoutLink]](repeating: [], count: nodeCount)

    for (linkIdx, link) in diagram.links.enumerated() {
        guard let sIdx = nodeIndexMap[link.source.id],
              let tIdx = nodeIndexMap[link.target.id] else { continue }
        let v = _sankeyLayoutValue(link.value)
        var layoutLink = _SankeyLayoutLink(sourceIdx: sIdx, targetIdx: tIdx, value: v)
        layoutLink.linkIndex = linkIdx
        sourceLinks[sIdx].append(layoutLink)
        targetLinks[tIdx].append(layoutLink)
        nodeValues[sIdx] += v
        nodeValues[tIdx] += v
    }

    for i in 0..<nodeCount {
        let totalSource = sourceLinks[i].reduce(0) { $0 + $1.value }
        let totalTarget = targetLinks[i].reduce(0) { $0 + $1.value }
        nodeValues[i] = max(totalSource, totalTarget)
    }

    let depths = _computeD3SankeyDepths(sourceLinks: sourceLinks, nodeCount: nodeCount)
    let heights = _computeD3SankeyHeights(targetLinks: targetLinks, nodeCount: nodeCount)
    let maxDepth = depths.max() ?? 0
    let n = maxDepth + 1

    let layerAssignment = _computeD3SankeyLayers(
        sourceLinks: sourceLinks,
        targetLinks: targetLinks,
        depths: depths,
        heights: heights,
        n: n,
        alignment: config.nodeAlignment,
        nodeCount: nodeCount
    )

    let columns = _groupByLayer(layerAssignment, nodeCount: nodeCount)
    var filteredColumns = columns.filter { !$0.isEmpty }
    let usedLayerCount = max(filteredColumns.count, 1)

    var x0s = [Double](repeating: 0, count: nodeCount)
    if usedLayerCount > 1 {
        let spacing = (width - nodeWidth) / Double(usedLayerCount - 1)
        var colIdx = 0
        for (_, indices) in columns.enumerated() {
            if indices.isEmpty { continue }
            let x = Double(colIdx) * spacing
            for i in indices {
                x0s[i] = x
            }
            colIdx += 1
        }
    } else {
        for i in 0..<nodeCount {
            x0s[i] = (width - nodeWidth) / 2
        }
    }

    var y0s = [Double](repeating: 0, count: nodeCount)
    var y1s = [Double](repeating: 0, count: nodeCount)

    _initializeNodeBreadths(
        columns: filteredColumns,
        nodeValues: nodeValues,
        y0s: &y0s,
        y1s: &y1s,
        sourceLinks: sourceLinks,
        height: height,
        py: nodePadding
    )

    var linkWidths = [Double](repeating: 0, count: diagram.links.count)
    _relaxBreadths(
        columns: &filteredColumns,
        sourceLinks: sourceLinks,
        targetLinks: targetLinks,
        y0s: &y0s,
        y1s: &y1s,
        py: nodePadding,
        height: height
    )

    _computeLinkBreadths(
        filteredColumns: filteredColumns,
        diagramLinks: diagram.links,
        nodeIndexMap: nodeIndexMap,
        sourceLinks: sourceLinks,
        targetLinks: targetLinks,
        y0s: y0s,
        y1s: y1s,
        nodeValues: nodeValues,
        linkWidths: &linkWidths
    )

    var positionedNodes: [PositionedSankeyNode] = []
    for i in 0..<nodeCount {
        positionedNodes.append(PositionedSankeyNode(
            id: diagram.nodes[i].id,
            x0: x0s[i],
            x1: x0s[i] + nodeWidth,
            y0: y0s[i],
            y1: y1s[i],
            value: nodeValues[i],
            layer: layerAssignment[i]
        ))
    }

    var positionedLinks: [PositionedSankeyLink] = []
    for (linkIdx, link) in diagram.links.enumerated() {
        guard let sIdx = nodeIndexMap[link.source.id],
              let tIdx = nodeIndexMap[link.target.id] else { continue }

        let value = _sankeyLayoutValue(link.value)
        let width = linkWidths[linkIdx]
        let halfWidth = width / 2

        let sNode = positionedNodes[sIdx]
        let tNode = positionedNodes[tIdx]

        let linksFromSource = sourceLinks[sIdx]
        var yOffset = sNode.y0
        for sl in linksFromSource.sorted(by: { diagram.links[$0.linkIndex].target.id < diagram.links[$1.linkIndex].target.id }) {
            let slWidth = linkWidths[sl.linkIndex]
            if sl.linkIndex == linkIdx {
                break
            }
            yOffset += slWidth
        }

        let sCY = yOffset + halfWidth
        let tCY = yOffset + halfWidth

        let midX = (sNode.x1 + tNode.x0) / 2
        let path = SankeyLinkPath(
            sourceX: sNode.x1,
            sourceY: sCY,
            targetX: tNode.x0,
            targetY: tCY,
            controlPoints: [
                CGPoint(x: midX, y: sCY),
                CGPoint(x: midX, y: tCY),
            ]
        )

        positionedLinks.append(PositionedSankeyLink(
            sourceID: link.source.id,
            targetID: link.target.id,
            value: value,
            width: max(1, width),
            y0: yOffset,
            y1: yOffset + width,
            path: path
        ))
    }

    return PositionedSankeyDiagram(
        width: width,
        height: height,
        nodes: positionedNodes,
        links: positionedLinks,
        config: config,
        diagramTitle: diagram.accTitle ?? diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr
    )
}

private struct _SankeyLayoutLink {
    let sourceIdx: Int
    let targetIdx: Int
    let value: Double
    var linkIndex: Int = 0
}

private func _sankeyLayoutValue(_ value: Double) -> Double {
    value.isFinite ? max(value, 0) : 0
}

private func _computeD3SankeyDepths(
    sourceLinks: [[_SankeyLayoutLink]],
    nodeCount: Int
) -> [Int] {
    var depths = [Int](repeating: -1, count: nodeCount)
    var current = Set(0..<nodeCount)
    var next = Set<Int>()
    var x = 0

    while !current.isEmpty {
        for node in current {
            depths[node] = x
        }
        next.removeAll()
        for node in current {
            for link in sourceLinks[node] {
                if depths[link.targetIdx] == -1 || depths[link.targetIdx] <= x {
                    next.insert(link.targetIdx)
                }
            }
        }
        x += 1
        if x > nodeCount { break }
        swap(&current, &next)
    }

    for i in 0..<nodeCount where depths[i] == -1 {
        depths[i] = x
    }

    return depths
}

private func _computeD3SankeyHeights(
    targetLinks: [[_SankeyLayoutLink]],
    nodeCount: Int
) -> [Int] {
    var heights = [Int](repeating: -1, count: nodeCount)
    var current = Set(0..<nodeCount)
    var next = Set<Int>()
    var x = 0

    while !current.isEmpty {
        for node in current {
            heights[node] = x
        }
        next.removeAll()
        for node in current {
            for link in targetLinks[node] {
                if heights[link.sourceIdx] == -1 || heights[link.sourceIdx] <= x {
                    next.insert(link.sourceIdx)
                }
            }
        }
        x += 1
        if x > nodeCount { break }
        swap(&current, &next)
    }

    for i in 0..<nodeCount where heights[i] == -1 {
        heights[i] = x
    }

    return heights
}

private func _computeD3SankeyLayers(
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    depths: [Int],
    heights: [Int],
    n: Int,
    alignment: SankeyNodeAlignment,
    nodeCount: Int
) -> [Int] {
    var layers = [Int](repeating: 0, count: nodeCount)

    for i in 0..<nodeCount {
        let layer: Int
        switch alignment {
        case .left:
            layer = depths[i]
        case .right:
            layer = n - 1 - heights[i]
        case .justify:
            layer = sourceLinks[i].isEmpty ? n - 1 : depths[i]
        case .center:
            if !targetLinks[i].isEmpty {
                layer = depths[i]
            } else if !sourceLinks[i].isEmpty {
                let minTargetDepth = sourceLinks[i].map({ depths[$0.targetIdx] }).min() ?? 0
                layer = minTargetDepth - 1
            } else {
                layer = 0
            }
        }
        layers[i] = max(0, min(layer, n - 1))
    }

    return layers
}

private func _groupByLayer(_ layers: [Int], nodeCount: Int) -> [[Int]] {
    let maxLayer = layers.max() ?? 0
    var columns = [[Int]](repeating: [], count: maxLayer + 1)
    for i in 0..<nodeCount {
        columns[layers[i]].append(i)
    }
    return columns
}

private func _initializeNodeBreadths(
    columns: [[Int]],
    nodeValues: [Double],
    y0s: inout [Double],
    y1s: inout [Double],
    sourceLinks: [[_SankeyLayoutLink]],
    height: Double,
    py: Double
) {
    for indices in columns {
        guard !indices.isEmpty else { continue }
        let totalValue = indices.reduce(0.0) { $0 + nodeValues[$1] }
        guard totalValue > 0 else { continue }
        let available = height - Double(indices.count - 1) * py
        let ky = available / totalValue
        var y: Double = 0
        for idx in indices {
            let nodeH = nodeValues[idx] * ky
            y0s[idx] = y
            y1s[idx] = y + nodeH
            y = y1s[idx] + py
        }
    }
}

private func _relaxBreadths(
    columns: inout [[Int]],
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: inout [Double],
    y1s: inout [Double],
    py: Double,
    height: Double
) {
    let iterations = 6
    for iter in 0..<iterations {
        let alpha = pow(0.99, Double(iter))
        let beta = max(1 - alpha, Double(iter + 1) / Double(iterations))
        _relaxRightToLeft(
            columns: &columns,
            sourceLinks: sourceLinks,
            targetLinks: targetLinks,
            y0s: &y0s,
            y1s: &y1s,
            py: py,
            alpha: alpha,
            beta: beta
        )
        _relaxLeftToRight(
            columns: &columns,
            sourceLinks: sourceLinks,
            targetLinks: targetLinks,
            y0s: &y0s,
            y1s: &y1s,
            py: py,
            alpha: alpha,
            beta: beta
        )
    }

    for indices in columns {
        _resolveCollisionsInColumn(indices, y0s: &y0s, y1s: &y1s, py: py, height: height, alpha: 1)
    }

    var maxY = 0.0
    for indices in columns {
        for idx in indices {
            if y1s[idx] > maxY { maxY = y1s[idx] }
        }
    }
    if maxY > height && height > 0 {
        let scale = height / maxY
        for i in 0..<y0s.count {
            y0s[i] *= scale
            y1s[i] *= scale
        }
    }
}

private func _relaxLeftToRight(
    columns: inout [[Int]],
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: inout [Double],
    y1s: inout [Double],
    py: Double,
    alpha: Double,
    beta: Double
) {
    for colIdx in 1..<columns.count {
        for targetIdx in columns[colIdx] {
            var y: Double = 0
            var w: Double = 0
            for link in targetLinks[targetIdx] {
                let srcLayer = columns.firstIndex(where: { $0.contains(link.sourceIdx) }) ?? 0
                let tgtLayer = colIdx
                let v = link.value * Double(tgtLayer - srcLayer)
                let top = _targetTop(link: link, sourceLinks: sourceLinks, targetLinks: targetLinks, y0s: y0s, y1s: y1s, py: py)
                y += top * v
                w += v
            }
            guard w > 0 else { continue }
            let dy = (y / w - y0s[targetIdx]) * alpha
            y0s[targetIdx] += dy
            y1s[targetIdx] += dy
        }
        columns[colIdx].sort { y0s[$0] < y0s[$1] }
        _resolveCollisionsInColumn(columns[colIdx], y0s: &y0s, y1s: &y1s, py: py, height: 1e9, alpha: beta)
    }
}

private func _relaxRightToLeft(
    columns: inout [[Int]],
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: inout [Double],
    y1s: inout [Double],
    py: Double,
    alpha: Double,
    beta: Double
) {
    for colIdx in stride(from: columns.count - 2, through: 0, by: -1) {
        for sourceIdx in columns[colIdx] {
            var y: Double = 0
            var w: Double = 0
            for link in sourceLinks[sourceIdx] {
                let srcLayer = colIdx
                let tgtLayer = columns.firstIndex(where: { $0.contains(link.targetIdx) }) ?? srcLayer + 1
                let v = link.value * Double(tgtLayer - srcLayer)
                let top = _sourceTop(link: link, sourceLinks: sourceLinks, targetLinks: targetLinks, y0s: y0s, y1s: y1s, py: py)
                y += top * v
                w += v
            }
            guard w > 0 else { continue }
            let dy = (y / w - y0s[sourceIdx]) * alpha
            y0s[sourceIdx] += dy
            y1s[sourceIdx] += dy
        }
        columns[colIdx].sort { y0s[$0] < y0s[$1] }
        _resolveCollisionsInColumn(columns[colIdx], y0s: &y0s, y1s: &y1s, py: py, height: 1e9, alpha: beta)
    }
}

private func _targetTop(
    link: _SankeyLayoutLink,
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: [Double],
    y1s: [Double],
    py: Double
) -> Double {
    let source = link.sourceIdx
    let target = link.targetIdx
    var y = y0s[source] - Double(sourceLinks[source].count - 1) * py / 2
    for sl in sourceLinks[source] {
        if sl.targetIdx == target { break }
        let w = y1s[source] - y0s[source]
        y += (sl.value / max(sl.value, 1e-6)) * w * 0.1 + py
    }
    for tl in targetLinks[target] {
        if tl.sourceIdx == source { break }
        let w = y1s[target] - y0s[target]
        y -= (tl.value / max(tl.value, 1e-6)) * w * 0.1
    }
    return y
}

private func _sourceTop(
    link: _SankeyLayoutLink,
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: [Double],
    y1s: [Double],
    py: Double
) -> Double {
    let source = link.sourceIdx
    let target = link.targetIdx
    var y = y0s[target] - Double(targetLinks[target].count - 1) * py / 2
    for tl in targetLinks[target] {
        if tl.sourceIdx == source { break }
        let w = y1s[target] - y0s[target]
        y += (tl.value / max(tl.value, 1e-6)) * w * 0.1 + py
    }
    for sl in sourceLinks[source] {
        if sl.targetIdx == target { break }
        let w = y1s[source] - y0s[source]
        y -= (sl.value / max(sl.value, 1e-6)) * w * 0.1
    }
    return y
}

private func _resolveCollisionsInColumn(
    _ indices: [Int],
    y0s: inout [Double],
    y1s: inout [Double],
    py: Double,
    height: Double,
    alpha: Double
) {
    guard indices.count > 1 else { return }
    let sorted = indices.sorted(by: { y0s[$0] < y0s[$1] })

    for i in 1..<sorted.count {
        let prev = sorted[i - 1]
        let curr = sorted[i]
        let overlap = y1s[prev] + py - y0s[curr]
        if overlap > 0 {
            let dy = overlap * alpha
            y0s[curr] += dy
            y1s[curr] += dy
        }
    }

    let maxBreadth = height
    if maxBreadth < 1e9 {
        for i in (0..<sorted.count).reversed() {
            let node = sorted[i]
            if y1s[node] > maxBreadth {
                let dy = (y1s[node] - maxBreadth) * alpha
                y0s[node] -= dy
                y1s[node] -= dy
            }
        }
    }
}

private func _computeLinkBreadths(
    filteredColumns: [[Int]],
    diagramLinks: [SankeyLink],
    nodeIndexMap: [String: Int],
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    y0s: [Double],
    y1s: [Double],
    nodeValues: [Double],
    linkWidths: inout [Double]
) {
    for indices in filteredColumns {
        for idx in indices {
            let totalSource = sourceLinks[idx].reduce(0.0) { $0 + $1.value }
            let nodeH = y1s[idx] - y0s[idx]
            if totalSource > 0 && nodeH > 0 {
                for j in 0..<sourceLinks[idx].count {
                    let linkIdx = sourceLinks[idx][j].linkIndex
                    linkWidths[linkIdx] = max(1, (sourceLinks[idx][j].value / totalSource) * nodeH)
                }
            }

            let totalTarget = targetLinks[idx].reduce(0.0) { $0 + $1.value }
            if totalTarget > 0 && nodeH > 0 {
                for j in 0..<targetLinks[idx].count {
                    let linkIdx = targetLinks[idx][j].linkIndex
                    let tw = max(1, (targetLinks[idx][j].value / totalTarget) * nodeH)
                    if linkWidths[linkIdx] > 0 {
                        linkWidths[linkIdx] = min(linkWidths[linkIdx], tw)
                    } else {
                        linkWidths[linkIdx] = tw
                    }
                }
            }
        }
    }
    for i in 0..<linkWidths.count {
        if linkWidths[i] <= 0 { linkWidths[i] = 1 }
    }
}
