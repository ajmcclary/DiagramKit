// Extracted from src_layout.swift (audit A2 split). Edge segment collection
// and post-processing helpers for the ELK-backed flowchart/state layout:
// segment grouping by original edge index, orthogonalization, layer
// alignment, fan-in/fan-out trunk bundling, and junction adjustment for
// subgraph crossings.
import Foundation
import DiagramKitCommon

/// Edge segments collected from ELK result, grouped by original edge index.
struct _EdgeSegments {
    var external: [_PositionedPointPayload]?
    var incoming: [_PositionedPointPayload]?
    var outgoing: [_PositionedPointPayload]?
    var labelPosition: _PositionedPointPayload?
}

/// Recursively collect edge segments from ELK result.
/// Parses edge IDs to identify external ("e3"), outgoing ("e3_out"), and incoming ("e3_in") segments.
func _collectEdgeSegments(
    _ elkNode: ElkGraphNode,
    segments: inout [Int: _EdgeSegments],
    offsetX: Double,
    offsetY: Double
) {
    for elkEdge in elkNode.edges {
        let eid = elkEdge.id

        // Parse edge ID
        let isOut = eid.hasSuffix("_out")
        let isIn = eid.hasSuffix("_in")
        let isInternal = eid.hasSuffix("_internal")
        let indexStr: String
        if isOut {
            indexStr = String(eid.dropFirst(1).dropLast(4)) // "e3_out" → "3"
        } else if isIn {
            indexStr = String(eid.dropFirst(1).dropLast(3)) // "e3_in" → "3"
        } else if isInternal {
            indexStr = String(eid.dropFirst(1).dropLast(9)) // "e3_internal" → "3"
        } else {
            indexStr = String(eid.dropFirst(1)) // "e3" → "3"
        }
        guard let edgeIndex = Int(indexStr) else { continue }

        // Extract points from sections
        var points: [_PositionedPointPayload] = []
        if let section = elkEdge.sections.first {
            points.append(_PositionedPointPayload(
                x: section.startPoint.x + offsetX,
                y: section.startPoint.y + offsetY
            ))
            for bp in section.bendPoints {
                points.append(_PositionedPointPayload(
                    x: bp.x + offsetX,
                    y: bp.y + offsetY
                ))
            }
            points.append(_PositionedPointPayload(
                x: section.endPoint.x + offsetX,
                y: section.endPoint.y + offsetY
            ))
        }

        // Extract label position
        var labelPos: _PositionedPointPayload?
        if let label = elkEdge.labels.first {
            if label.x != 0 || label.y != 0 {
                labelPos = _PositionedPointPayload(
                    x: label.x + label.width / 2 + offsetX,
                    y: label.y + label.height / 2 + offsetY
                )
            }
        }

        // Store segment
        if segments[edgeIndex] == nil {
            segments[edgeIndex] = _EdgeSegments()
        }

        if isOut {
            segments[edgeIndex]?.outgoing = points
        } else if isIn {
            segments[edgeIndex]?.incoming = points
        } else if isInternal {
            let src = elkEdge.sources.first ?? ""
            if src.contains("_in_") || src.contains("_out_") {
                segments[edgeIndex]?.incoming = points
            } else {
                segments[edgeIndex]?.outgoing = points
            }
        } else {
            segments[edgeIndex]?.external = points
            if let lp = labelPos {
                segments[edgeIndex]?.labelPosition = lp
            }
        }
    }

    // Recurse into compound children with accumulated offset
    for child in elkNode.children {
        if !child.children.isEmpty {
            let cx = child.x + offsetX
            let cy = child.y + offsetY
            _collectEdgeSegments(child, segments: &segments, offsetX: cx, offsetY: cy)
        }
    }
}

/// Ensure all edge segments are orthogonal (horizontal or vertical only).
/// Matches TS orthogonalizeEdgePoints: when margins are available, routes through
/// left/right margins (alternating sides with spacing). Without margins, uses Z-path
/// through the vertical midpoint.
/// Returns (points, didChange) so caller can track margin edge index.
func _orthogonalizeEdgePoints(
    _ points: [_PositionedPointPayload],
    margins: (leftX: Double, rightX: Double)?,
    edgeIndex: Int
) -> (points: [_PositionedPointPayload], changed: Bool) {
    guard points.count >= 2 else { return (points, false) }

    var needsWork = false
    for i in 1..<points.count {
        let dx = abs(points[i].x - points[i-1].x)
        let dy = abs(points[i].y - points[i-1].y)
        if dx > 1 && dy > 1 { needsWork = true; break }
    }
    guard needsWork else { return (points, false) }

    let edgeSpacing: Double = 12
    var result: [_PositionedPointPayload] = [points[0]]

    for i in 1..<points.count {
        let prev = result[result.count - 1]
        let curr = points[i]
        let dx = abs(curr.x - prev.x)
        let dy = abs(curr.y - prev.y)

        if dx > 1 && dy > 1 {
            if let margins {
                // Margin routing: exit horizontally → travel vertically along margin → enter horizontally
                let useRight = edgeIndex % 2 == 0
                let offset = Double(edgeIndex / 2) * edgeSpacing
                let marginX = useRight
                    ? margins.rightX + offset
                    : margins.leftX - offset
                result.append(_PositionedPointPayload(x: marginX, y: prev.y))
                result.append(_PositionedPointPayload(x: marginX, y: curr.y))
            } else {
                // Fallback: Z-path through vertical midpoint
                let midY = (prev.y + curr.y) / 2
                result.append(_PositionedPointPayload(x: prev.x, y: midY))
                result.append(_PositionedPointPayload(x: curr.x, y: midY))
            }
        }
        result.append(curr)
    }
    return (result, true)
}


/// Snap same-layer nodes to uniform positions along the flow axis.
/// ELK's orthogonal routing staggers nodes within a layer; this post-processing
/// aligns them, matching the original TypeScript implementation.
func _alignLayerNodes(
    _ nodes: inout [_PositionedNodePayload],
    _ edges: inout [_PositionedEdgePayload],
    _ direction: original_src_types.Direction
) {
    guard !nodes.isEmpty else { return }

    let isHorizontal = direction == .LR || direction == .RL
    let layerSpacing: Double = 48
    let threshold = layerSpacing * 0.6

    // Build connected pairs set
    var connectedPairs = Set<String>()
    for edge in edges {
        connectedPairs.insert("\(edge.source):\(edge.target)")
        connectedPairs.insert("\(edge.target):\(edge.source)")
    }

    // Sort nodes by flow-axis position
    let sorted = nodes.sorted { a, b in
        isHorizontal ? a.x < b.x : a.y < b.y
    }

    // Cluster into layers using single-linkage with connected-pair exclusion
    var layers: [[Int]] = [] // indices into `nodes`
    let nodeIndexMap = Dictionary(nodes.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { _, last in last })
    let sortedIndices = sorted.compactMap { nodeIndexMap[$0.id] }

    var currentLayer: [Int] = [sortedIndices[0]]
    for i in 1..<sortedIndices.count {
        let idx = sortedIndices[i]
        let prevIdx = sortedIndices[i - 1]
        let pos = isHorizontal ? nodes[idx].x : nodes[idx].y
        let prevPos = isHorizontal ? nodes[prevIdx].x : nodes[prevIdx].y
        let gap = pos - prevPos

        let hasEdgeToLayer = currentLayer.contains { layerIdx in
            connectedPairs.contains("\(nodes[layerIdx].id):\(nodes[idx].id)")
        }

        if gap <= threshold && !hasEdgeToLayer {
            currentLayer.append(idx)
        } else {
            layers.append(currentLayer)
            currentLayer = [idx]
        }
    }
    layers.append(currentLayer)

    // Snap each layer's nodes to the center
    var deltas: [String: Double] = [:]
    for layer in layers {
        guard layer.count > 1 else { continue }
        let positions = layer.map { isHorizontal ? nodes[$0].x : nodes[$0].y }
        let minPos = positions.min() ?? positions[0]
        let maxPos = positions.max() ?? positions[0]
        guard maxPos - minPos > 1 else { continue }

        let target = (minPos + maxPos) / 2
        for idx in layer {
            let oldPos = isHorizontal ? nodes[idx].x : nodes[idx].y
            let delta = target - oldPos
            if abs(delta) > 0.5 {
                if isHorizontal {
                    nodes[idx].x = target
                } else {
                    nodes[idx].y = target
                }
                deltas[nodes[idx].id] = delta
            }
        }
    }

    guard !deltas.isEmpty else { return }

    // Adjust edge endpoints to match shifted nodes
    for i in edges.indices {
        guard edges[i].points.count >= 2 else { continue }

        if let srcDelta = deltas[edges[i].source] {
            if isHorizontal {
                let oldX = edges[i].points[0].x
                edges[i].points[0].x += srcDelta
                if edges[i].points.count > 1 && edges[i].points[1].x == oldX {
                    edges[i].points[1].x += srcDelta
                }
            } else {
                let oldY = edges[i].points[0].y
                edges[i].points[0].y += srcDelta
                if edges[i].points.count > 1 && edges[i].points[1].y == oldY {
                    edges[i].points[1].y += srcDelta
                }
            }
        }

        if let tgtDelta = deltas[edges[i].target] {
            let lastIdx = edges[i].points.count - 1
            if isHorizontal {
                let oldX = edges[i].points[lastIdx].x
                edges[i].points[lastIdx].x += tgtDelta
                if lastIdx > 0 && edges[i].points[lastIdx - 1].x == oldX {
                    edges[i].points[lastIdx - 1].x += tgtDelta
                }
            } else {
                let oldY = edges[i].points[lastIdx].y
                edges[i].points[lastIdx].y += tgtDelta
                if lastIdx > 0 && edges[i].points[lastIdx - 1].y == oldY {
                    edges[i].points[lastIdx - 1].y += tgtDelta
                }
            }
        }
    }
}

/// Bundle fan-out and fan-in edge paths so they share a common trunk segment.
/// Edges in a bundle must share the same style and have no labels.
func _bundleEdgePaths(
    _ edges: inout [_PositionedEdgePayload],
    _ nodes: [_PositionedNodePayload],
    _ groups: [_PositionedGroupPayload],
    _ direction: original_src_types.Direction
) {
    let nodeMap = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    var processed = Set<Int>() // edge indices

    let isLR = direction == .LR
    let isRL = direction == .RL
    let isBT = direction == .BT
    let isHorizontal = isLR || isRL

    // --- Fan-out: group edges by shared source ---
    var fanOutGroups: [String: [Int]] = [:]
    for (i, edge) in edges.enumerated() {
        guard edge.source != edge.target else { continue }
        fanOutGroups[edge.source, default: []].append(i)
    }

    for (sourceId, group) in fanOutGroups {
        guard group.count >= 2 else { continue }
        let style = edges[group[0]].style
        if group.contains(where: { edges[$0].label != nil || edges[$0].style != style }) { continue }
        guard let source = nodeMap[sourceId] else { continue }

        let forward = group.filter { idx in
            guard let t = nodeMap[edges[idx].target] else { return false }
            if isLR { return t.x > source.x + source.width }
            if isRL { return t.x + t.width < source.x }
            // y=0 at top: TD forward = target has higher y; BT forward = target has lower y
            if isBT { return t.y + t.height < source.y }
            return t.y > source.y + source.height // TD
        }
        guard forward.count >= 2 else { continue }

        let srcCX = source.x + source.width / 2
        let srcCY = source.y + source.height / 2

        if isHorizontal {
            let exitX = isLR ? source.x + source.width : source.x
            let exitY = srcCY
            let nearestX = isLR
                ? forward.compactMap { nodeMap[edges[$0].target]?.x }.min() ?? exitX
                : forward.compactMap { nodeMap[edges[$0].target] }.map { $0.x + $0.width }.max() ?? exitX
            let junctionX = _adjustJunctionForGroups(exitX + (nearestX - exitX) / 2, refX: srcCX, refY: srcCY, groups: groups, direction: direction)
            for idx in forward {
                guard let target = nodeMap[edges[idx].target] else { continue }
                let entryX = isLR ? target.x : target.x + target.width
                let entryY = target.y + target.height / 2
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: entryY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
                processed.insert(idx)
            }
        } else {
            let exitX = srcCX
            // y=0 at top: TD exit at bottom of node = node.y + height
            let exitY = isBT ? source.y : source.y + source.height
            let nearestY = isBT
                ? forward.compactMap { nodeMap[edges[$0].target] }.map { $0.y + $0.height }.max() ?? exitY
                : forward.compactMap { nodeMap[edges[$0].target]?.y }.min() ?? exitY
            let junctionY = _adjustJunctionForGroups(exitY + (nearestY - exitY) / 2, refX: srcCX, refY: srcCY, groups: groups, direction: direction)
            for idx in forward {
                guard let target = nodeMap[edges[idx].target] else { continue }
                let entryX = target.x + target.width / 2
                // y=0 at top: TD enter at top of node = node.y
                let entryY = isBT ? target.y + target.height : target.y
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: exitX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
                processed.insert(idx)
            }
        }
    }

    // --- Fan-in: group edges by shared target (skip already-bundled) ---
    var fanInGroups: [String: [Int]] = [:]
    for (i, edge) in edges.enumerated() {
        guard !processed.contains(i), edge.source != edge.target else { continue }
        fanInGroups[edge.target, default: []].append(i)
    }

    for (targetId, group) in fanInGroups {
        guard group.count >= 2 else { continue }
        let style = edges[group[0]].style
        if group.contains(where: { edges[$0].label != nil || edges[$0].style != style }) { continue }
        guard let target = nodeMap[targetId] else { continue }

        // y=0 at top: TD "forward" means source is above target (source has lower y)
        let forward = group.filter { idx in
            guard let s = nodeMap[edges[idx].source] else { return false }
            if isLR { return s.x + s.width < target.x }
            if isRL { return s.x > target.x + target.width }
            if isBT { return s.y > target.y + target.height }
            return s.y + s.height < target.y // TD
        }
        guard forward.count >= 2 else { continue }

        let tgtCX = target.x + target.width / 2
        let tgtCY = target.y + target.height / 2

        if isHorizontal {
            let entryX = isLR ? target.x : target.x + target.width
            let entryY = tgtCY
            let farthestX = isLR
                ? forward.compactMap { nodeMap[edges[$0].source] }.map { $0.x + $0.width }.max() ?? entryX
                : forward.compactMap { nodeMap[edges[$0].source]?.x }.min() ?? entryX
            let junctionX = _adjustJunctionForGroups(farthestX + (entryX - farthestX) / 2, refX: tgtCX, refY: tgtCY, groups: groups, direction: direction)
            for idx in forward {
                guard let src = nodeMap[edges[idx].source] else { continue }
                let exitX = isLR ? src.x + src.width : src.x
                let exitY = src.y + src.height / 2
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: exitY),
                    _PositionedPointPayload(x: junctionX, y: entryY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
            }
        } else {
            let entryX = tgtCX
            // y=0 at top: TD enter at top = node.y
            let entryY = isBT ? target.y + target.height : target.y
            let farthestY = isBT
                ? forward.compactMap { nodeMap[edges[$0].source]?.y }.min() ?? entryY
                : forward.compactMap { nodeMap[edges[$0].source] }.map { $0.y + $0.height }.max() ?? entryY
            let junctionY = _adjustJunctionForGroups(farthestY + (entryY - farthestY) / 2, refX: tgtCX, refY: tgtCY, groups: groups, direction: direction)
            for idx in forward {
                guard let src = nodeMap[edges[idx].source] else { continue }
                let exitX = src.x + src.width / 2
                // y=0 at top: TD exit at bottom = src.y + height
                let exitY = isBT ? src.y : src.y + src.height
                edges[idx].points = [
                    _PositionedPointPayload(x: exitX, y: exitY),
                    _PositionedPointPayload(x: exitX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: junctionY),
                    _PositionedPointPayload(x: entryX, y: entryY),
                ]
            }
        }
    }
}

private func _adjustJunctionForGroups(
    _ junctionMain: Double,
    refX: Double,
    refY: Double,
    groups: [_PositionedGroupPayload],
    direction: original_src_types.Direction
) -> Double {
    let gap: Double = 12
    let isLR = direction == .LR
    let isRL = direction == .RL
    let isBT = direction == .BT
    let isHorizontal = isLR || isRL

    let refGroupIds = Set(_findGroupsContainingPoint(refX, refY, groups).map { $0.id })
    let probeX = isHorizontal ? junctionMain : refX
    let probeY = isHorizontal ? refY : junctionMain
    let junctionGroups = _findGroupsContainingPoint(probeX, probeY, groups)

    guard let crossingGroup = junctionGroups.first(where: { !refGroupIds.contains($0.id) }) else {
        return junctionMain
    }

    if isLR { return crossingGroup.x - gap }
    if isRL { return crossingGroup.x + crossingGroup.width + gap }
    // y=0 at top: higher Y = visually lower on screen
    // y=0 at top: TD "above" = smaller y; BT "above" = larger y
    if isBT { return crossingGroup.y + crossingGroup.height + gap }
    return crossingGroup.y - gap  // TD: above group = smaller y
}

private func _findGroupsContainingPoint(
    _ x: Double, _ y: Double,
    _ groups: [_PositionedGroupPayload]
) -> [_PositionedGroupPayload] {
    var result: [_PositionedGroupPayload] = []
    for group in groups {
        if x >= group.x && x <= group.x + group.width &&
           y >= group.y && y <= group.y + group.height {
            result.append(group)
            result.append(contentsOf: _findGroupsContainingPoint(x, y, group.children))
        }
    }
    return result
}
