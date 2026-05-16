// Extracted from src_layout.swift (audit A2 split). Converts a laid-out
// ELK graph into a public `PositionedGraph`: collects leaf nodes from all
// compound levels with their cumulative offsets, stitches the
// outgoing/external/incoming edge segment trio per original edge,
// resolves inline node/edge styles, lifts subgraphs to positioned groups,
// and (for state diagrams) applies the optional scaleWidth factor.
import Foundation
import DiagramKitCommon

/// Collect all leaf-node children from the ELK result, including those nested inside compound nodes.
/// Returns tuples of (child node, cumulative parent offset).
private func _collectAllChildren(
    _ elkNode: ElkGraphNode,
    nodeById: [String: original_src_types.MermaidNode],
    parentOffset: (x: Double, y: Double) = (0, 0),
    depth: Int = 0
) -> [(ElkGraphNode, (x: Double, y: Double))] {
    var result: [(ElkGraphNode, (x: Double, y: Double))] = []
    guard _recursionGuard(depth: depth, location: "ELK._collectAllChildren") else {
        return result
    }
    for child in elkNode.children {
        if nodeById[child.id] != nil && child.children.isEmpty {
            // Leaf node
            result.append((child, parentOffset))
        } else {
            // Compound node — recurse into its children with accumulated offset
            let cx = child.x + parentOffset.x
            let cy = child.y + parentOffset.y
            result += _collectAllChildren(child, nodeById: nodeById, parentOffset: (cx, cy), depth: depth + 1)
        }
    }
    return result
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

/// Extract positioned subgraph groups from the ELK result.
private func _extractSubgraphGroups(
    _ elkNode: ElkGraphNode,
    source: _ParsedGraph,
    graphHeight: Double,
    parentOffset: (x: Double, y: Double) = (0, 0),
    depth: Int = 0,
    diagnostics: _LayoutDiagnostics? = nil
) -> [_PositionedGroupPayload] {
    let subgraphIds = Set(_allSubgraphIds(source.subgraphs))
    var groups: [_PositionedGroupPayload] = []
    for child in elkNode.children {
        guard subgraphIds.contains(child.id) else { continue }
        let rawX = child.x + parentOffset.x
        let rawY = child.y + parentOffset.y
        let w = child.width
        let h = child.height
        let sub = _findSubgraph(child.id, in: source.subgraphs, diagnostics: diagnostics)
        let label = sub?.label ?? child.id
        let shape = sub?.shape?.rawValue
        let altBkg = sub?.altBkg ?? false
        let childGroups = _extractSubgraphGroups(
            child, source: source, graphHeight: graphHeight,
            parentOffset: (rawX, rawY),
            depth: depth + 1,
            diagnostics: diagnostics
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

private func _findSubgraph(
    _ id: String,
    in subs: [original_src_types.MermaidSubgraph],
    depth: Int = 0,
    diagnostics: _LayoutDiagnostics? = nil
) -> original_src_types.MermaidSubgraph? {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        diagnostics?.warn("_findSubgraph: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); aborting search for '\(id)'.")
        return nil
    }
    for sub in subs {
        if sub.id == id { return sub }
        if let found = _findSubgraph(id, in: sub.children, depth: depth + 1, diagnostics: diagnostics) { return found }
    }
    return nil
}

private func _findSubgraphLabel(_ id: String, in subs: [original_src_types.MermaidSubgraph], diagnostics: _LayoutDiagnostics? = nil) -> String? {
    _findSubgraph(id, in: subs, diagnostics: diagnostics)?.label
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

func _extractPositionedGraph(
    _ source: _ParsedGraph,
    _ laidOut: ElkGraphNode,
    diagramType: DiagramType,
    diagnostics: _LayoutDiagnostics? = nil
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
    var groups = _extractSubgraphGroups(laidOut, source: source, graphHeight: graphHeight, diagnostics: diagnostics)

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
