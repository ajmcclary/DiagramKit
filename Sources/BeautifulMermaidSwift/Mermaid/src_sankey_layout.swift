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

    for link in diagram.links {
        guard let sIdx = nodeIndexMap[link.source.id],
              let tIdx = nodeIndexMap[link.target.id] else { continue }
        let v = _sankeyLayoutValue(link.value)
        let layoutLink = _SankeyLayoutLink(sourceIdx: sIdx, targetIdx: tIdx, value: v)
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

    var depths = _computeSankeyDepths(
        sourceLinks: sourceLinks,
        targetLinks: targetLinks,
        nodeCount: nodeCount,
        alignment: config.nodeAlignment
    )

    let maxDepth = depths.max() ?? 0
    let layerCount = maxDepth > 0 ? maxDepth + 1 : 2

    var nodesByLayer = [[Int]](repeating: [], count: layerCount)
    for i in 0..<nodeCount {
        depths[i] = min(depths[i], layerCount - 1)
        nodesByLayer[depths[i]].append(i)
    }

    let xPad = width * 0.05
    let availableWidth = width - 2 * xPad - nodeWidth

    var xs = [Double](repeating: 0, count: nodeCount)
    if layerCount > 1 {
        for i in 0..<nodeCount {
            xs[i] = xPad + (availableWidth * Double(depths[i])) / Double(layerCount - 1)
        }
    } else {
        for i in 0..<nodeCount {
            xs[i] = width / 2 - nodeWidth / 2
        }
    }

    var ys = [Double](repeating: 0, count: nodeCount)
    for layer in 0..<layerCount {
        let nodesInLayer = nodesByLayer[layer]
        let totalValue = nodesInLayer.reduce(0.0) { $0 + nodeValues[$1] }
        guard totalValue > 0 else { continue }
        let effectiveHeight = height - 2 * nodePadding
        var y = nodePadding
        for idx in nodesInLayer {
            ys[idx] = y
            let nodeH = max(1, (nodeValues[idx] / totalValue) * effectiveHeight)
            y += max(nodeH + nodePadding, 1)
        }
    }

    let actualMaxY = (0..<nodeCount).map { i in
        let nodeH = max(1, (nodeValues[i] / max(nodeValues.reduce(0, +), 1)) * (height - 2 * nodePadding))
        return ys[i] + nodeH + nodePadding
    }.max() ?? height

    let scale = min(1.0, (height - nodePadding) / max(actualMaxY, 1))
    if scale < 1.0 {
        for i in 0..<nodeCount {
            ys[i] *= scale
        }
    }

    var positionedNodes: [PositionedSankeyNode] = []
    for i in 0..<nodeCount {
        let totalValue = max(nodeValues.reduce(0, +), 1)
        let effectiveHeight = height - 2 * nodePadding
        let nodeH = max(1, (nodeValues[i] / totalValue) * effectiveHeight * scale)
        positionedNodes.append(PositionedSankeyNode(
            id: diagram.nodes[i].id,
            x0: xs[i],
            x1: xs[i] + nodeWidth,
            y0: ys[i],
            y1: ys[i] + nodeH,
            value: nodeValues[i],
            layer: depths[i]
        ))
    }

    var positionedLinks: [PositionedSankeyLink] = []
    var sourceOffsets = [Double](repeating: 0, count: nodeCount)
    var targetOffsets = [Double](repeating: 0, count: nodeCount)

    for link in diagram.links {
        guard let sIdx = nodeIndexMap[link.source.id],
              let tIdx = nodeIndexMap[link.target.id] else { continue }

        let value = _sankeyLayoutValue(link.value)
        let sNode = positionedNodes[sIdx]
        let tNode = positionedNodes[tIdx]

        let sValue = nodeValues[sIdx]
        let tValue = nodeValues[tIdx]

        let sHeight = sNode.y1 - sNode.y0
        let tHeight = tNode.y1 - tNode.y0

        let sYStart = sNode.y0 + (sValue > 0 ? (sourceOffsets[sIdx] / sValue) * sHeight : 0)
        let tYStart = tNode.y0 + (tValue > 0 ? (targetOffsets[tIdx] / tValue) * tHeight : 0)

        let sourceWidth = sHeight > 0 && sValue > 0 ? (value / sValue) * sHeight : 1
        let targetWidth = tHeight > 0 && tValue > 0 ? (value / tValue) * tHeight : 1
        let maxWidth = min(sourceWidth, targetWidth)
        let linkWidth = max(1, min(maxWidth, sHeight, tHeight))

        let halfWidth = linkWidth / 2
        let sCY = sYStart + halfWidth
        let tCY = tYStart + halfWidth

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
            width: linkWidth,
            y0: sYStart,
            y1: sYStart + linkWidth,
            path: path
        ))

        sourceOffsets[sIdx] += value
        targetOffsets[tIdx] += value
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
}

private func _sankeyLayoutValue(_ value: Double) -> Double {
    value.isFinite ? max(value, 0) : 0
}

private func _computeSankeyDepths(
    sourceLinks: [[_SankeyLayoutLink]],
    targetLinks: [[_SankeyLayoutLink]],
    nodeCount: Int,
    alignment: SankeyNodeAlignment
) -> [Int] {
    var depths = [Int](repeating: 0, count: nodeCount)
    var changed = true
    let maxIter = nodeCount * 2

    for _ in 0..<maxIter where changed {
        changed = false
        for i in 0..<nodeCount {
            for link in sourceLinks[i] {
                if depths[link.targetIdx] <= depths[i] {
                    depths[link.targetIdx] = depths[i] + 1
                    changed = true
                }
            }
        }
    }

    let maxDepth = depths.max() ?? 0
    if maxDepth == 0 { return depths }

    switch alignment {
    case .left:
        break
    case .right:
        for i in 0..<nodeCount {
            depths[i] = maxDepth
        }
        changed = true
        for _ in 0..<maxIter where changed {
            changed = false
            for i in 0..<nodeCount {
                for link in targetLinks[i] {
                    if depths[link.sourceIdx] >= depths[i] {
                        depths[link.sourceIdx] = max(0, depths[i] - 1)
                        changed = true
                    }
                }
            }
        }
        let minD = depths.min() ?? 0
        if minD > 0 {
            for i in 0..<nodeCount { depths[i] -= minD }
        }
    case .center:
        let halfMax = (maxDepth + 1) / 2
        for i in 0..<nodeCount {
            depths[i] = min(max(depths[i], halfMax), maxDepth)
        }
    case .justify:
        break
    }

    return depths
}
