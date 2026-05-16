// Extracted from src_layout.swift (audit A2 split). Builds the ELK graph
// representations consumed by `_layoutGraphSyncFromLayoutEngine`:
//   - `_buildElkGraph` (SEPARATE mode, port-based cross-hierarchy edges),
//   - `_buildElkGraphNoCrossEdges` (INCLUDE_CHILDREN mode, no ports), and
//   - `_buildFlatElkGraph` (fallback when nested layout throws).
// Subgraph ownership, deep-subgraph lookups, ELK edge construction, and
// edge-label measurement live here too because they back all three builders.
import Foundation
import DiagramKitCommon

private func _mapDirection(_ direction: original_src_types.Direction) -> String {
    ElkLayoutOptions.mapDirection(direction)
}

/// Builds the measured `[ElkGraphLabel]` ELK uses for an edge label.
/// Returns `[]` when the label is nil or empty so callers can pass the result
/// directly into `ElkGraphEdge(labels:)` without conditional wrapping.
private func _makeEdgeLabels(_ label: String?) -> [ElkGraphLabel] {
    guard let label, !label.isEmpty else { return [] }
    let m = original_src_text_metrics.measureMultilineText(
        label,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )
    return [ElkGraphLabel(
        text: label,
        width: m.width + 8,
        height: m.height + 6,
        layoutOptions: [
            "elk.edgeLabels.inline": "true",
            "elk.edgeLabels.placement": "CENTER"
        ]
    )]
}

/// Constructs the canonical root-level `ElkGraphEdge` for a parsed Mermaid edge.
/// Shared between hierarchical, flat-fallback, and no-cross-edges graph builders
/// so edge ID, source/target, and label measurement stay identical across paths.
private func _makeElkEdge(idx: Int, edge: original_src_types.MermaidEdge) -> ElkGraphEdge {
    ElkGraphEdge(
        id: "e\(idx)",
        sources: [edge.source],
        targets: [edge.target],
        labels: _makeEdgeLabels(edge.label)
    )
}

/// Walks the subgraph tree and returns the most-nested subgraph that directly
/// contains `nodeId`, or nil if the node lives at the root.
private func _deepestSubgraphID(for nodeId: String, in subs: [original_src_types.MermaidSubgraph]) -> String? {
    for sub in subs {
        if let deeper = _deepestSubgraphID(for: nodeId, in: sub.children) {
            return deeper
        }
        if sub.nodeIds.contains(nodeId) {
            return sub.id
        }
    }
    return nil
}

func _buildElkGraph(_ graph: _ParsedGraph, diagnostics: _LayoutDiagnostics? = nil) -> ElkGraphNode {
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs, diagnostics: diagnostics)

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
            edges.append(_makeElkEdge(idx: idx, edge: edge))
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

    var nodeToSubgraph: [String: String] = [:]
    for entry in graph.nodesInOrder {
        if let sg = _deepestSubgraphID(for: entry.id, in: graph.subgraphs) {
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
            edgesBySubgraph[s, default: []].append(_makeElkEdge(idx: idx, edge: edge))
        } else if srcSub == nil && tgtSub == nil {
            rootOnlyEdges.append(_makeElkEdge(idx: idx, edge: edge))
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
            let internalEdge = ElkGraphEdge(
                id: "e\(idx)_out",
                sources: [ce.edge.source],
                targets: [portId],
                labels: _makeEdgeLabels(ce.edge.label)
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
        // Root label only when the source is at root; when source is in a
        // subgraph, the out-port internal edge already carries the label.
        let rootLabels = ce.srcSub == nil ? _makeEdgeLabels(ce.edge.label) : []
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
                _subgraphContainsNode(child, nodeId: nodeId, diagnostics: diagnostics)
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
    _ subs: [original_src_types.MermaidSubgraph],
    diagnostics: _LayoutDiagnostics? = nil
) -> [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for sub in subs {
        result[sub.id] = _allNodeIds(in: sub, diagnostics: diagnostics)
        for (k, v) in _buildSubgraphOwnership(sub.children, diagnostics: diagnostics) {
            result[k] = v
        }
    }
    return result
}

private func _allNodeIds(
    in sub: original_src_types.MermaidSubgraph,
    depth: Int = 0,
    diagnostics: _LayoutDiagnostics? = nil
) -> Set<String> {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        diagnostics?.warn("_allNodeIds: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); truncating.")
        return Set(sub.nodeIds)
    }
    var ids = Set(sub.nodeIds)
    for child in sub.children {
        ids.formUnion(_allNodeIds(in: child, depth: depth + 1, diagnostics: diagnostics))
    }
    return ids
}

private func _subgraphContainsNode(
    _ sub: original_src_types.MermaidSubgraph,
    nodeId: String,
    depth: Int = 0,
    diagnostics: _LayoutDiagnostics? = nil
) -> Bool {
    if depth >= _MAX_SUBGRAPH_RECURSION_DEPTH {
        diagnostics?.warn("_subgraphContainsNode: subgraph recursion depth exceeded \(_MAX_SUBGRAPH_RECURSION_DEPTH); reporting absent.")
        return false
    }
    if sub.nodeIds.contains(nodeId) { return true }
    return sub.children.contains { _subgraphContainsNode($0, nodeId: nodeId, depth: depth + 1, diagnostics: diagnostics) }
}

/// Build hierarchical ELK graph but EXCLUDE cross-subgraph edges that crash ELK JS.
/// INCLUDE_CHILDREN mode: all edges at root level, ELK resolves nested node IDs.
/// Used when no subgraph has a direction override.
func _buildElkGraphNoCrossEdges(_ graph: _ParsedGraph, diagnostics: _LayoutDiagnostics? = nil) -> ElkGraphNode {
    let subgraphOwnership = _buildSubgraphOwnership(graph.subgraphs, diagnostics: diagnostics)
    let allClaimedNodes = Set(subgraphOwnership.values.flatMap { $0 })
    let nodeById = Dictionary(graph.nodesInOrder.map { ($0.id, $0.node) }, uniquingKeysWith: { _, last in last })

    // Classify edges into: internal (same subgraph), root-level (no subgraph),
    // cross-hierarchy (different subgraph levels). Matching TS edge ordering:
    // root-level edges first, then cross-hierarchy edges.
    var edgesBySubgraph: [String: [ElkGraphEdge]] = [:]
    var rootLevelEdges: [ElkGraphEdge] = []
    var crossHierarchyEdges: [ElkGraphEdge] = []
    for (idx, edge) in graph.edges.enumerated() {
        let srcSub = _deepestSubgraphID(for: edge.source, in: graph.subgraphs)
        let tgtSub = _deepestSubgraphID(for: edge.target, in: graph.subgraphs)
        let typedEdge = _makeElkEdge(idx: idx, edge: edge)
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
            !sub.children.contains { child in _subgraphContainsNode(child, nodeId: nodeId, diagnostics: diagnostics) }
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

func _buildFlatElkGraph(_ graph: _ParsedGraph, diagnostics: _LayoutDiagnostics? = nil) -> ElkGraphNode {
    var children: [ElkGraphNode] = []
    for entry in graph.nodesInOrder {
        let size = _nodeSize(entry.node, hideEmptyDescription: graph.stateConfig.hideEmptyDescription)
        children.append(ElkGraphNode(id: entry.id, width: size.width, height: size.height))
    }
    var edges: [ElkGraphEdge] = []
    for (idx, edge) in graph.edges.enumerated() {
        edges.append(_makeElkEdge(idx: idx, edge: edge))
    }
    return ElkGraphNode(
        id: "root",
        children: children,
        edges: edges,
        layoutOptions: ElkLayoutOptions.flatRoot(direction: graph.direction)
    )
}
