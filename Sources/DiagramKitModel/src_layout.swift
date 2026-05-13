// Ported from original/src/layout.ts
import Foundation
import DiagramKitCommon

/// Soft cap on nested-subgraph recursion. The 8 MB worker stack tolerates
/// deeper nesting, but pathological input shouldn't be able to exhaust it
/// without a diagnostic. Reaching the cap reports an issue and truncates
/// the traversal rather than continuing.
private let _MAX_SUBGRAPH_RECURSION_DEPTH = 1024

private typealias _ParsedGraph = original_src_types.MermaidGraph
private typealias _ParsedEdge = original_src_types.MermaidEdge

private typealias _ElkNode = [String: Any]

// Positioned-graph payload types moved to DiagramKitModel/PositionedPayloads.swift

private func _mapDirection(_ direction: original_src_types.Direction) -> String {
    switch direction {
    case .LR: return "RIGHT"
    case .RL: return "LEFT"
    case .BT: return "UP"
    case .TD, .TB: return "DOWN"
    }
}

private func _buildElkGraph(_ graph: _ParsedGraph) -> ElkGraphNode {
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs)

    func _makeEdge(_ idx: Int, _ edge: original_src_types.MermaidEdge) -> ElkGraphEdge {
        var labels: [ElkGraphLabel] = []
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            labels.append(ElkGraphLabel(
                text: label,
                width: m.width + 8,
                height: m.height + 6,
                layoutOptions: [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ))
        }
        return ElkGraphEdge(
            id: "e\(idx)",
            sources: [edge.source],
            targets: [edge.target],
            labels: labels
        )
    }

    if graph.subgraphs.isEmpty {
        var children: [ElkGraphNode] = []
        for entry in graph.nodesInOrder {
            let size = _nodeSize(entry.node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
            children.append(ElkGraphNode(
                id: entry.id,
                labels: [ElkGraphLabel(text: entry.node.label)],
                width: size.width,
                height: size.height
            ))
        }
        var edges: [ElkGraphEdge] = []
        for (idx, edge) in graph.edges.enumerated() {
            edges.append(_makeEdge(idx, edge))
        }
        return ElkGraphNode(
            id: "root",
            children: children,
            edges: edges,
            layoutOptions: ElkLayoutOptions.root(direction: graph.direction, hierarchy: .includeChildren)
        )
    }

    let allClaimedNodes = Set(subgraphOwnership.values.flatMap { $0 })
    let nodeById = Dictionary(graph.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })

    func _deepestSubgraph(for nodeId: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
        for sub in subs {
            if let deeper = _deepestSubgraph(for: nodeId, in: sub.children) {
                return deeper
            }
            if sub.nodeIds.contains(nodeId) {
                return sub.id
            }
        }
        return nil
    }

    var nodeToSubgraph: [String: String] = [:]
    for entry in graph.nodesInOrder {
        if let sg = _deepestSubgraph(for: entry.id, in: graph.subgraphs) {
            nodeToSubgraph[entry.id] = sg
        }
    }

    var edgesBySubgraph: [String: [ElkGraphEdge]] = [:]
    var rootOnlyEdges: [ElkGraphEdge] = []
    struct CrossEdge {
        let idx: Int
        let edge: original_src_types.MermaidEdge
        let srcSub: String?
        let tgtSub: String?
    }
    var crossEdges: [CrossEdge] = []

    for (idx, edge) in graph.edges.enumerated() {
        let srcSub = nodeToSubgraph[edge.source]
        let tgtSub = nodeToSubgraph[edge.target]
        if let s = srcSub, let t = tgtSub, s == t {
            edgesBySubgraph[s, default: []].append(_makeEdge(idx, edge))
        } else if srcSub == nil && tgtSub == nil {
            rootOnlyEdges.append(_makeEdge(idx, edge))
        } else {
            crossEdges.append(CrossEdge(idx: idx, edge: edge, srcSub: srcSub, tgtSub: tgtSub))
        }
    }

    var rootEdges = rootOnlyEdges
    var portsBySubgraph: [String: [(ElkGraphPort, ElkGraphEdge)]] = [:]

    for ce in crossEdges {
        let idx = ce.idx
        if let srcSg = ce.srcSub {
            let portId = "\(srcSg)_out_\(idx)"
            var labels: [ElkGraphLabel] = []
            if let label = ce.edge.label, !label.isEmpty {
                let m = original_src_text_metrics.measureMultilineText(
                    label,
                    fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                    fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
                )
                labels.append(ElkGraphLabel(
                    text: label,
                    width: m.width + 8,
                    height: m.height + 6,
                    layoutOptions: [
                        "elk.edgeLabels.inline": "true",
                        "elk.edgeLabels.placement": "CENTER"
                    ]
                ))
            }
            let internalEdge = ElkGraphEdge(
                id: "e\(idx)_out",
                sources: [ce.edge.source],
                targets: [portId],
                labels: labels
            )
            portsBySubgraph[srcSg, default: []].append((ElkGraphPort(id: portId), internalEdge))
        }

        if let tgtSg = ce.tgtSub {
            let portId = "\(tgtSg)_in_\(idx)"
            let internalEdge = ElkGraphEdge(
                id: "e\(idx)_in",
                sources: [portId],
                targets: [ce.edge.target]
            )
            portsBySubgraph[tgtSg, default: []].append((ElkGraphPort(id: portId), internalEdge))
        }

        let srcId = ce.srcSub.map { "\($0)_out_\(idx)" } ?? ce.edge.source
        let tgtId = ce.tgtSub.map { "\($0)_in_\(idx)" } ?? ce.edge.target
        var rootLabels: [ElkGraphLabel] = []
        if ce.srcSub == nil, let label = ce.edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            rootLabels.append(ElkGraphLabel(
                text: label,
                width: m.width + 8,
                height: m.height + 6,
                layoutOptions: [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ))
        }
        rootEdges.append(ElkGraphEdge(
            id: "e\(idx)",
            sources: [srcId],
            targets: [tgtId],
            labels: rootLabels
        ))
    }

    func buildSubgraphNode(_ sub: original_src_types.MermaidSubgraph) -> ElkGraphNode {
        let directNodeIds = sub.nodeIds.filter { nodeId in
            !sub.children.contains { child in
                _subgraphContainsNode(child, nodeId: nodeId)
            }
        }

        var children: [ElkGraphNode] = []
        for nodeId in directNodeIds {
            guard let node = nodeById[nodeId] else { continue }
            let size = _nodeSize(node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
            children.append(ElkGraphNode(
                id: nodeId,
                labels: [ElkGraphLabel(text: node.label)],
                width: size.width,
                height: size.height
            ))
        }
        for child in sub.children {
            children.append(buildSubgraphNode(child))
        }

        var ports: [ElkGraphPort] = []
        var internalEdges: [ElkGraphEdge] = []
        if let pairs = portsBySubgraph[sub.id] {
            for (port, edge) in pairs {
                ports.append(port)
                internalEdges.append(edge)
            }
        }

        var subgraphEdges = edgesBySubgraph[sub.id] ?? []
        subgraphEdges.append(contentsOf: internalEdges)

        return ElkGraphNode(
            id: sub.id,
            children: children,
            edges: subgraphEdges,
            ports: ports,
            layoutOptions: ElkLayoutOptions.subgraph(direction: sub.direction),
            labels: [ElkGraphLabel(text: sub.label)]
        )
    }

    var rootChildren: [ElkGraphNode] = []
    for entry in graph.nodesInOrder {
        if !allClaimedNodes.contains(entry.id) {
            let size = _nodeSize(entry.node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
            rootChildren.append(ElkGraphNode(
                id: entry.id,
                labels: [ElkGraphLabel(text: entry.node.label)],
                width: size.width,
                height: size.height
            ))
        }
    }
    for sub in graph.subgraphs {
        rootChildren.append(buildSubgraphNode(sub))
    }

    return ElkGraphNode(
        id: "root",
        children: rootChildren,
        edges: rootEdges,
        layoutOptions: ElkLayoutOptions.root(direction: graph.direction, hierarchy: .separate)
    )
}

/// Build a map of subgraph ID -> set of all transitively contained node IDs
private func _buildSubgraphOwnership(
    _ subs: [original_src_types.MermaidSubgraph]
) -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for sub in subs {
        result[sub.id] = _allNodeIds(in: sub)
        for (k, v) in _buildSubgraphOwnership(sub.children) {
            result[k] = v
        }
    }
    return result
}

private func _allNodeIds(in sub: original_src_types.MermaidSubgraph, depth: Int = 0) -> Set<String> {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        _reportDiagramIssue("_allNodeIds: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); truncating.")
        return Set(sub.nodeIds)
    }
    var ids = Set(sub.nodeIds)
    for child in sub.children {
        ids.formUnion(_allNodeIds(in: child, depth: depth + 1))
    }
    return ids
}

private func _subgraphContainsNode(_ sub: original_src_types.MermaidSubgraph, nodeId: String, depth: Int = 0) -> Bool {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        _reportDiagramIssue("_subgraphContainsNode: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); reporting absent.")
        return false
    }
    if sub.nodeIds.contains(nodeId) { return true }
    return sub.children.contains { _subgraphContainsNode($0, nodeId: nodeId, depth: depth + 1) }
}

// _PositionedGroupPayload moved to DiagramKitModel/PositionedPayloads.swift

/// Collect all leaf-node children from the ELK result, including those nested inside compound nodes.
/// Returns tuples of (child node, cumulative parent offset).
private func _collectAllChildren(
    _ elkNode: ElkGraphNode,
    nodeById: [String: original_src_types.MermaidNode],
    parentOffset: (x: Double, y: Double) = (0, 0)
) -> [(ElkGraphNode, (x: Double, y: Double))] {
    var result: [(ElkGraphNode, (x: Double, y: Double))] = []
    for child in elkNode.children {
        if nodeById[child.id] != nil && child.children.isEmpty {
            // Leaf node
            result.append((child, parentOffset))
        } else {
            // Compound node — recurse into its children with accumulated offset
            let cx = child.x + parentOffset.x
            let cy = child.y + parentOffset.y
            result += _collectAllChildren(child, nodeById: nodeById, parentOffset: (cx, cy))
        }
    }
    return result
}

/// Edge segments collected from ELK result, grouped by original edge index.
private struct _EdgeSegments {
    var external: [_PositionedPointPayload]?
    var incoming: [_PositionedPointPayload]?
    var outgoing: [_PositionedPointPayload]?
    var labelPosition: _PositionedPointPayload?
}

/// Recursively collect edge segments from ELK result.
/// Parses edge IDs to identify external ("e3"), outgoing ("e3_out"), and incoming ("e3_in") segments.
private func _collectEdgeSegments(
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

/// Flatten all group bounding boxes for margin computation.
private func _flattenGroupBounds(_ groups: [_PositionedGroupPayload]) -> [_PositionedGroupPayload] {
    var result: [_PositionedGroupPayload] = []
    for g in groups {
        result.append(g)
        result.append(contentsOf: _flattenGroupBounds(g.children))
    }
    return result
}

/// Ensure all edge segments are orthogonal (horizontal or vertical only).
/// Matches TS orthogonalizeEdgePoints: when margins are available, routes through
/// left/right margins (alternating sides with spacing). Without margins, uses Z-path
/// through the vertical midpoint.
/// Returns (points, didChange) so caller can track margin edge index.
private func _orthogonalizeEdgePoints(
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
private func _alignLayerNodes(
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
private func _bundleEdgePaths(
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

/// Extract positioned subgraph groups from the ELK result.
private func _extractSubgraphGroups(
    _ elkNode: ElkGraphNode,
    source: _ParsedGraph,
    graphHeight: Double,
    parentOffset: (x: Double, y: Double) = (0, 0),
    depth: Int = 0
) -> [_PositionedGroupPayload] {
    let subgraphIds = Set(_allSubgraphIds(source.subgraphs))
    var groups: [_PositionedGroupPayload] = []
    for child in elkNode.children {
        guard subgraphIds.contains(child.id) else { continue }
        let rawX = child.x + parentOffset.x
        let rawY = child.y + parentOffset.y
        let w = child.width
        let h = child.height
        let sub = _findSubgraph(child.id, in: source.subgraphs)
        let label = sub?.label ?? child.id
        let shape = sub?.shape?.rawValue
        let altBkg = sub?.altBkg ?? false
        let childGroups = _extractSubgraphGroups(
            child, source: source, graphHeight: graphHeight,
            parentOffset: (rawX, rawY),
            depth: depth + 1
        )
        groups.append(_PositionedGroupPayload(
            id: child.id, label: label,
            x: rawX, y: rawY,
            width: w, height: h,
            children: childGroups,
            shape: shape,
            altBkg: altBkg
        ))
    }
    return groups
}

private func _allSubgraphIds(_ subs: [original_src_types.MermaidSubgraph]) -> [String] {
    subs.flatMap { [$0.id] + _allSubgraphIds($0.children) }
}

private func _findSubgraph(_ id: String, in subs: [original_src_types.MermaidSubgraph], depth: Int = 0) -> original_src_types.MermaidSubgraph? {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        _reportDiagramIssue("_findSubgraph: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); aborting search for '\(id)'.")
        return nil
    }
    for sub in subs {
        if sub.id == id { return sub }
        if let found = _findSubgraph(id, in: sub.children, depth: depth + 1) { return found }
    }
    return nil
}

private func _findSubgraphLabel(_ id: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
    _findSubgraph(id, in: subs)?.label
}

private func _scaleGroups(_ groups: inout [_PositionedGroupPayload], by factor: Double) {
    for index in groups.indices {
        groups[index].x *= factor
        groups[index].y *= factor
        groups[index].width *= factor
        groups[index].height *= factor
        groups[index].headerHeight *= factor
        _scaleGroups(&groups[index].children, by: factor)
    }
}

private func _resolveInlineStyle(_ id: String, _ graph: _ParsedGraph) -> [String: String] {
    var style: [String: String] = [:]
    let classNames = graph.classAssignments[id] ?? []
    if !classNames.isEmpty {
        for className in classNames {
            if let classStyle = graph.classDefs[className] {
                for (k, v) in classStyle { style[k] = v }
            }
        }
    } else if let defaultStyle = graph.defaultClassDef {
        for (k, v) in defaultStyle { style[k] = v }
    }
    if let nodeStyle = graph.nodeStyles[id] {
        for (k, v) in nodeStyle { style[k] = v }
    }
    return style
}

/// Resolve inline styles for an edge from linkStyles map and edge class assignments.
/// Default link style (key -1) is applied first, then index-specific overrides,
/// then edge-class styles, then inline styles from properties.
private func _resolveEdgeStyle(edgeIndex: Int, edgeId: String?, graph: _ParsedGraph) -> [String: String]? {
    var result: [String: String]?
    if let defaultStyle = graph.linkStyles[-1] {
        result = defaultStyle
    }
    if let indexStyle = graph.linkStyles[edgeIndex] {
        if var r = result {
            for (k, v) in indexStyle { r[k] = v }
            result = r
        } else {
            result = indexStyle
        }
    }
    if let eid = edgeId, let className = graph.edgeClassAssignments[eid], let classStyle = graph.classDefs[className] {
        if var r = result {
            for (k, v) in classStyle { r[k] = v }
            result = r
        } else {
            result = classStyle
        }
    }
    return result
}

private func _extractPositionedGraph(
    _ source: _ParsedGraph,
    _ laidOut: ElkGraphNode,
    diagramType: DiagramType
) -> PositionedGraph {
    let nodeById = Dictionary(source.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })
    let graphHeight = laidOut.height

    // Collect nodes from root and all compound children (subgraphs) recursively
    let allChildren = _collectAllChildren(laidOut, nodeById: nodeById)

    // ELK coordinates (y=0 at top) — rendering handles CGContext flip
    var nodes: [_PositionedNodePayload] = allChildren.compactMap { (child, parentOffset) in
        guard let original = nodeById[child.id] else { return nil }
        let fallbackSize = _nodeSize(original, hideEmptyDescription: source.stateConfig.hideEmptyDescription)
        let w = child.width > 0 ? child.width : fallbackSize.width
        let h = child.height > 0 ? child.height : fallbackSize.height
        let rawX = child.x + parentOffset.x
        let rawY = child.y + parentOffset.y
        let id = child.id
        let effectiveLabel = original.properties?.label ?? original.label
        let effectiveShape: original_src_types.NodeShape = original.properties?.shape
            .flatMap { original_src_types.NodeShape.resolve(alias: $0) } ?? original.shape
        return _PositionedNodePayload(
            id: child.id,
            label: effectiveLabel,
            descriptions: original.descriptions,
            shape: effectiveShape.rawValue,
            x: rawX,
            y: rawY,
            width: w,
            height: h,
            inlineStyle: _resolveInlineStyle(id, source),
            properties: original.properties,
            interaction: source.nodeInteractions[id]
        )
    }

    // Collect edge segments from all levels (root + subgraphs) with coordinate offsets.
    // Groups segments by original edge index, combining outgoing + external + incoming.
    var segmentsByIndex: [Int: _EdgeSegments] = [:]
    _collectEdgeSegments(laidOut, segments: &segmentsByIndex, offsetX: 0, offsetY: 0)

    // Extract subgraph groups — needed for margin routing
    var groups = _extractSubgraphGroups(laidOut, source: source, graphHeight: graphHeight)

    // Compute margin positions for cross-hierarchy edge routing.
    // Margins sit outside all group bounding boxes so edges don't cross through subgraphs.
    let allBounds = _flattenGroupBounds(groups)
    let margins: (leftX: Double, rightX: Double)? = allBounds.isEmpty ? nil : (
        leftX: (allBounds.map(\.x).min() ?? 0) - 20,
        rightX: (allBounds.map { $0.x + $0.width }.max() ?? 0) + 20
    )

    // Track margin-routed edge count for spacing offsets (matching TS marginEdgeIndex)
    var marginEdgeIndex = 0

    var edges: [_PositionedEdgePayload] = []
    for (idx, edge) in source.edges.enumerated() {
        // Combine points from all segments in correct order:
        // outgoing (source→exit port) + external (exit port→entry port) + incoming (entry port→target)
        let seg = segmentsByIndex[idx]
        var points: [_PositionedPointPayload] = []

        // First: outgoing internal segment (source node → exit port)
        if let outgoing = seg?.outgoing, !outgoing.isEmpty {
            points.append(contentsOf: outgoing)
        }

        // Second: external segment (exit port → entry port)
        if let external = seg?.external, !external.isEmpty {
            if !points.isEmpty {
                // Skip first point to avoid duplicate at outgoing port
                points.append(contentsOf: Array(external.dropFirst()))
            } else {
                points.append(contentsOf: external)
            }
        }

        // Third: incoming internal segment (entry port → target node)
        if let incoming = seg?.incoming, !incoming.isEmpty {
            if !points.isEmpty {
                // Skip first point to avoid duplicate at incoming port
                points.append(contentsOf: Array(incoming.dropFirst()))
            } else {
                points.append(contentsOf: incoming)
            }
        }

        // Label position from ELK, or fall back to path midpoint later
        let labelPos = seg?.labelPosition

        // Orthogonalize: fix diagonal segments from SEPARATE mode stitching.
        // Route through left/right margins when available (matching TS behavior).
        let ortho = _orthogonalizeEdgePoints(points, margins: margins, edgeIndex: marginEdgeIndex)
        if ortho.changed {
            points = ortho.points
            marginEdgeIndex += 1
        }

        // Recalculate label position for margin-routed edges
        var finalLabelPos: _PositionedPointPayload? = nil
        if let _ = edge.label, !points.isEmpty {
            if ortho.changed {
                finalLabelPos = _edgePathMidpoint(points, direction: source.direction)
            } else {
                finalLabelPos = labelPos
            }
        }

        edges.append(
            _PositionedEdgePayload(
                source: edge.source,
                target: edge.target,
                label: edge.label,
                style: edge.style.rawValue,
                arrowHeadStart: edge.arrowHeadStart,
                arrowHeadEnd: edge.arrowHeadEnd,
                points: points,
                labelPosition: finalLabelPos,
                inlineStyle: _resolveEdgeStyle(edgeIndex: idx, edgeId: edge.id, graph: source),
                edgeId: edge.id,
                properties: edge.properties,
                animate: edge.animate,
                animationSpeed: edge.animationSpeed,
                classes: edge.classes,
                curve: edge.curve
            )
        )
    }

    // Layer alignment: snap same-layer nodes to uniform positions
    _alignLayerNodes(&nodes, &edges, source.direction)

    // Bundle fan-out/fan-in edge paths into shared trunks
    _bundleEdgePaths(&edges, nodes, groups, source.direction)

    // Shape clipping: adjust edge endpoints to actual shape boundaries
    let nodeMap = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    for i in edges.indices {
        guard edges[i].points.count >= 2 else { continue }
        if let srcNode = nodeMap[edges[i].source] {
            edges[i].points = _clipEdgeToShape(points: edges[i].points, node: srcNode, isStart: true)
        }
        if let tgtNode = nodeMap[edges[i].target] {
            edges[i].points = _clipEdgeToShape(points: edges[i].points, node: tgtNode, isStart: false)
        }
    }

    // Compute label positions for edges that don't have an ELK-provided position
    for i in edges.indices {
        if let label = edges[i].label, !label.isEmpty, edges[i].points.count >= 2,
           edges[i].labelPosition == nil {
            edges[i].labelPosition = _edgePathMidpoint(edges[i].points, direction: source.direction)
        }
    }

    // Calculate final bounds including all edge points and labels
    var minX: Double = 0
    var minY: Double = 0
    var maxX = laidOut.width
    var maxY = graphHeight
    let arrowMargin: Double = 10
    let padding: Double = 40
    let labelHalfW: Double = 60  // estimated half-width of label pill
    let labelHalfH: Double = 16  // estimated half-height of label pill
    for edge in edges {
        for p in edge.points {
            maxX = max(maxX, p.x + arrowMargin + padding)
            maxY = max(maxY, p.y + arrowMargin + padding)
        }
        if let lp = edge.labelPosition {
            minX = min(minX, lp.x - labelHalfW - padding)
            minY = min(minY, lp.y - labelHalfH - padding)
            maxX = max(maxX, lp.x + labelHalfW + padding)
            maxY = max(maxY, lp.y + labelHalfH + padding)
        }
    }

    // If any label extends past origin, shift everything right/down
    if minX < 0 || minY < 0 {
        let shiftX = minX < 0 ? -minX : 0
        let shiftY = minY < 0 ? -minY : 0
        for i in nodes.indices {
            nodes[i].x += shiftX
            nodes[i].y += shiftY
        }
        for i in edges.indices {
            for j in edges[i].points.indices {
                edges[i].points[j].x += shiftX
                edges[i].points[j].y += shiftY
            }
            if var lp = edges[i].labelPosition {
                lp.x += shiftX
                lp.y += shiftY
                edges[i].labelPosition = lp
            }
        }
        for i in groups.indices {
            groups[i].x += shiftX
            groups[i].y += shiftY
        }
        maxX += shiftX
        maxY += shiftY
    }

    var finalWidth = maxX
    var finalHeight = maxY
    if diagramType == .stateDiagram,
       let scaleWidth = source.stateConfig.scaleWidth,
       scaleWidth > 0,
       maxX > 0
    {
        let factor = Double(scaleWidth) / maxX
        for i in nodes.indices {
            nodes[i].x *= factor
            nodes[i].y *= factor
            nodes[i].width *= factor
            nodes[i].height *= factor
        }
        for i in edges.indices {
            for j in edges[i].points.indices {
                edges[i].points[j].x *= factor
                edges[i].points[j].y *= factor
            }
            if var labelPosition = edges[i].labelPosition {
                labelPosition.x *= factor
                labelPosition.y *= factor
                edges[i].labelPosition = labelPosition
            }
        }
        _scaleGroups(&groups, by: factor)
        finalWidth = Double(scaleWidth)
        finalHeight = maxY * factor
    }

    let content: PositionedContent
    switch diagramType {
    case .stateDiagram:
        content = .stateDiagram(nodes: nodes, edges: edges, groups: groups)
    default:
        content = .flowchart(nodes: nodes, edges: edges, groups: groups)
    }
    return PositionedGraph(
        diagram: DiagramDocument(payload: diagramType == .stateDiagram ? .stateDiagram(source) : .flowchart(source)),
        width: finalWidth,
        height: finalHeight,
        content: content
    )
}

public func layoutGraphSync(
    _ graph: DiagramDocument,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    // layout.ts re-exports layout-engine.ts; route through the same public entry.
    return try _layoutGraphSyncEntry(graph, options)
}

/// Overload that accepts LayoutConfig to control ELK spacing parameters.
public func layoutGraphSync(
    _ graph: DiagramDocument,
    config: LayoutConfig
) throws -> PositionedGraph {
    return try _layoutGraphSyncWithConfig(graph, config)
}

private func _layoutGraphSyncWithConfig(
    _ graph: DiagramDocument,
    _ config: LayoutConfig
) throws -> PositionedGraph {
    let parsed: _ParsedGraph
    switch graph.payload {
    case .flowchart(let graph), .stateDiagram(let graph):
        parsed = graph
    default:
        return PositionedGraph(diagram: graph)
    }

    var elkGraph: ElkGraphNode
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        elkGraph = hasDirectionOverride
            ? _buildElkGraph(parsed)
            : _buildElkGraphNoCrossEdges(parsed)
    } else {
        elkGraph = _buildElkGraph(parsed)
    }

    // Override ELK spacing options with LayoutConfig values
    _applyLayoutConfig(config, to: &elkGraph)

    do {
        let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
        let laidOut = ElkGraphNode(from: rawLaidOut)
        return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
    } catch {
        var flatGraph = _buildFlatElkGraph(parsed)
        _applyLayoutConfig(config, to: &flatGraph)
        let rawLaidOut = try layoutEngineSync(flatGraph.toDictionary())
        let laidOut = ElkGraphNode(from: rawLaidOut)
        return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
    }
}

/// Patch ELK layout options on a built graph with LayoutConfig values.
private func _applyLayoutConfig(_ config: LayoutConfig, to elkGraph: inout ElkGraphNode) {
    let p = Int(config.padding)
    elkGraph.layoutOptions["elk.spacing.nodeNode"] = "\(Int(config.nodeSpacing))"
    elkGraph.layoutOptions["elk.layered.spacing.nodeNodeBetweenLayers"] = "\(Int(config.layerSpacing))"
    elkGraph.layoutOptions["elk.padding"] = "[top=\(p),left=\(p),bottom=\(p),right=\(p)]"
    elkGraph.layoutOptions["elk.spacing.componentComponent"] = "\(Int(config.componentSpacing))"
}

public func layoutGraphWithDiagnosticsSync(
    _ graph: DiagramDocument,
    _ options: RenderOptions = RenderOptions()
) throws -> PositionedGraph {
    return try _layoutGraphWithDiagnosticsEntry(graph, options)
}

private func _layoutGraphSyncEntry(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _layoutGraphWithDiagnosticsEntry(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphWithDiagnosticsSyncFromLayoutEngine(graph, options)
}

/// Build hierarchical ELK graph but EXCLUDE cross-subgraph edges that crash ELK JS.
/// INCLUDE_CHILDREN mode: all edges at root level, ELK resolves nested node IDs.
/// Used when no subgraph has a direction override.
private func _buildElkGraphNoCrossEdges(_ graph: _ParsedGraph) -> ElkGraphNode {
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs)
    let allClaimedNodes = Set(subgraphOwnership.values.flatMap { $0 })
    let nodeById = Dictionary(graph.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })

    func _deepestSubgraph(for nodeId: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
        for sub in subs {
            if let deeper = _deepestSubgraph(for: nodeId, in: sub.children) { return deeper }
            if sub.nodeIds.contains(nodeId) { return sub.id }
        }
        return nil
    }

    func _makeEdge(_ idx: Int, _ edge: original_src_types.MermaidEdge) -> ElkGraphEdge {
        var labels: [ElkGraphLabel] = []
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            labels.append(ElkGraphLabel(
                text: label,
                width: m.width + 8,
                height: m.height + 6,
                layoutOptions: [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ))
        }
        return ElkGraphEdge(
            id: "e\(idx)",
            sources: [edge.source],
            targets: [edge.target],
            labels: labels
        )
    }

    // Classify edges into: internal (same subgraph), root-level (no subgraph),
    // cross-hierarchy (different subgraph levels). Matching TS edge ordering:
    // root-level edges first, then cross-hierarchy edges.
    var edgesBySubgraph: [String: [ElkGraphEdge]] = [:]
    var rootLevelEdges: [ElkGraphEdge] = []
    var crossHierarchyEdges: [ElkGraphEdge] = []
    for (idx, edge) in graph.edges.enumerated() {
        let srcSub = _deepestSubgraph(for: edge.source, in: graph.subgraphs)
        let tgtSub = _deepestSubgraph(for: edge.target, in: graph.subgraphs)
        let typedEdge = _makeEdge(idx, edge)
        if let s = srcSub, let t = tgtSub, s == t {
            edgesBySubgraph[s, default: []].append(typedEdge)
        } else if srcSub == nil && tgtSub == nil {
            rootLevelEdges.append(typedEdge)
        } else {
            crossHierarchyEdges.append(typedEdge)
        }
    }
    // Match TS ordering: root-level edges first, then cross-hierarchy
    let rootEdges = rootLevelEdges + crossHierarchyEdges

    func buildSubgraphNode(_ sub: original_src_types.MermaidSubgraph) -> ElkGraphNode {
        let directNodeIds = sub.nodeIds.filter { nodeId in
            !sub.children.contains { child in _subgraphContainsNode(child, nodeId: nodeId) }
        }
        var children: [ElkGraphNode] = []
        for nodeId in directNodeIds {
            guard let node = nodeById[nodeId] else { continue }
            let size = _nodeSize(node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
            children.append(ElkGraphNode(
                id: nodeId,
                labels: [ElkGraphLabel(text: node.label)],
                width: size.width,
                height: size.height
            ))
        }
        for child in sub.children { children.append(buildSubgraphNode(child)) }

        // Direction is only set on a subgraph when it carries an explicit
        // override. In INCLUDE_CHILDREN mode direction inherits from the
        // root automatically; setting it can otherwise widen the compound
        // node by creating different external-port dummy structures.
        let subgraphEdges = edgesBySubgraph[sub.id] ?? []
        return ElkGraphNode(
            id: sub.id,
            children: children,
            edges: subgraphEdges,
            layoutOptions: ElkLayoutOptions.subgraph(direction: sub.direction),
            labels: [ElkGraphLabel(text: sub.label)]
        )
    }

    var rootChildren: [ElkGraphNode] = []
    for entry in graph.nodesInOrder {
        if !allClaimedNodes.contains(entry.id) {
            let size = _nodeSize(entry.node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
            rootChildren.append(ElkGraphNode(
                id: entry.id,
                labels: [ElkGraphLabel(text: entry.node.label)],
                width: size.width,
                height: size.height
            ))
        }
    }
    for sub in graph.subgraphs { rootChildren.append(buildSubgraphNode(sub)) }

    return ElkGraphNode(
        id: "root",
        children: rootChildren,
        edges: rootEdges,
        layoutOptions: ElkLayoutOptions.root(direction: graph.direction, hierarchy: .includeChildren)
    )
}

private func _buildFlatElkGraph(_ graph: _ParsedGraph) -> ElkGraphNode {
    var children: [ElkGraphNode] = []
    for entry in graph.nodesInOrder {
        let size = _nodeSize(entry.node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
        children.append(ElkGraphNode(id: entry.id, width: size.width, height: size.height))
    }
    var edges: [ElkGraphEdge] = []
    for (idx, edge) in graph.edges.enumerated() {
        var labels: [ElkGraphLabel] = []
        if let label = edge.label, !label.isEmpty {
            let m = original_src_text_metrics.measureMultilineText(
                label,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            labels.append(ElkGraphLabel(
                text: label,
                width: m.width + 8,
                height: m.height + 6,
                layoutOptions: [
                    "elk.edgeLabels.inline": "true",
                    "elk.edgeLabels.placement": "CENTER"
                ]
            ))
        }
        edges.append(ElkGraphEdge(
            id: "e\(idx)",
            sources: [edge.source],
            targets: [edge.target],
            labels: labels
        ))
    }
    return ElkGraphNode(
        id: "root",
        children: children,
        edges: edges,
        layoutOptions: ElkLayoutOptions.flatRoot(direction: graph.direction)
    )
}

private func _layoutGraphSyncFromLayoutEngine(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    _ = options
    let parsed: _ParsedGraph
    switch graph.payload {
    case .flowchart(let graph), .stateDiagram(let graph):
        parsed = graph
    default:
        return PositionedGraph(diagram: graph)
    }
    // Matching TS: use SEPARATE when any subgraph has a direction override,
    // INCLUDE_CHILDREN otherwise (simpler cross-hierarchy edge routing).
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        let elkGraph: ElkGraphNode
        if hasDirectionOverride {
            // SEPARATE mode: port-based edge splitting for proper direction handling
            elkGraph = _buildElkGraph(parsed)
        } else {
            // INCLUDE_CHILDREN mode: ELK handles cross-hierarchy edges natively
            elkGraph = _buildElkGraphNoCrossEdges(parsed)
        }
        do {
            let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
            let laidOut = ElkGraphNode(from: rawLaidOut)
            return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
        } catch {
            // Fallback: fully flat layout
            let flatGraph = _buildFlatElkGraph(parsed)
            let rawLaidOut = try layoutEngineSync(flatGraph.toDictionary())
            let laidOut = ElkGraphNode(from: rawLaidOut)
            return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
        }
    }
    // No subgraphs — use the standard flat graph builder
    let elkGraph = _buildElkGraph(parsed)
    let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
    let laidOut = ElkGraphNode(from: rawLaidOut)
    return _extractPositionedGraph(parsed, laidOut, diagramType: graph.type)
}

private func _layoutGraphWithDiagnosticsSyncFromLayoutEngine(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _convertToElkFormat(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws {
    _ = graph
    _ = options
    // Intentionally a no-op adapter until full layout-engine parity lands.
}

open class original_src_layout {
    public init() {}

    // Export inventory from TypeScript source:
    // - export { layoutGraphSync } from './layout-engine.ts'
    public static func layoutGraphSync(
        _ graph: DiagramDocument,
        _ options: RenderOptions = RenderOptions()
    ) throws -> PositionedGraph {
        try _layoutGraphSyncEntry(graph, options)
    }
}
