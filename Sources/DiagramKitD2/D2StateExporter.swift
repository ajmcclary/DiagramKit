import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `D2Document` describes a state diagram.
///
/// A D2 document is treated as a state diagram when it carries at least one
/// node whose identifier is `_start` or `_end` (the convention used by
/// `D2StateExport` and `D2StateMapper`). Class diagrams take precedence; if
/// any container has `shape: class`, the document is a class diagram, not a
/// state diagram.
enum D2StateProbe {

    static func detectsStateDiagram(_ document: D2Document) -> Bool {
        if D2ClassProbe.detectsClassDiagram(document) { return false }
        for stmt in document.statements {
            switch stmt {
            case .nodeDefinition(let def):
                if def.id == "_start" || def.id == "_end" { return true }
            case .edgeDefinition(let edge):
                if edge.source == "_start" || edge.source == "_end" { return true }
                if edge.target == "_start" || edge.target == "_end" { return true }
            case .containerOpen(let open):
                if open.id == "_start" || open.id == "_end" { return true }
            default:
                break
            }
        }
        return false
    }
}

/// Builds a `ParsedGraphModel` from a `D2Document` representing a state
/// machine. Nodes identified as `_start` / `_end` receive `.stateStart` /
/// `.stateEnd` shapes; every other node receives `.state`.
struct D2StateMapper {

    func map(_ document: D2Document) -> (ParsedGraphModel, [DiagramDiagnostic]) {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var diagnostics: [DiagramDiagnostic] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        // Per-container nodeId collectors. `subgraph` is the partial we'll
        // emit on close; `nodeIds` accumulates ids declared/referenced inside
        // this container so the subgraph's nodeIds end up populated.
        var subgraphStack: [(subgraph: original_src_types.MermaidSubgraph, nodeIds: [String])] = []

        func ensureNode(_ id: String, label: String? = nil) {
            guard nodesById[id] == nil else { return }
            let shape: original_src_types.NodeShape
            if id == "_start" {
                shape = .stateStart
            } else if id == "_end" {
                shape = .stateEnd
            } else {
                shape = .state
            }
            let displayLabel = (label?.isEmpty == false) ? label! : id
            nodesById[id] = original_src_types.MermaidNode(id: id, label: displayLabel, shape: shape)
            nodeOrder.append(id)
        }

        func appendUnique(_ id: String, to list: inout [String]) {
            if !list.contains(id) { list.append(id) }
        }

        func recordInCurrentSubgraph(_ id: String) {
            guard !subgraphStack.isEmpty else { return }
            let idx = subgraphStack.count - 1
            var current = subgraphStack[idx]
            appendUnique(id, to: &current.nodeIds)
            subgraphStack[idx] = current
        }

        for stmt in document.statements {
            switch stmt {
            case .containerOpen(let open):
                // The container itself surfaces as a composite-state node so
                // outer edges can target it (e.g. `Idle -> Active`).
                ensureNode(open.id)
                let subgraph = original_src_types.MermaidSubgraph(
                    id: open.id,
                    label: open.label ?? open.id,
                    nodeIds: []
                )
                subgraphStack.append((subgraph: subgraph, nodeIds: []))
            case .containerClose:
                guard !subgraphStack.isEmpty else { break }
                var closed = subgraphStack.removeLast()
                closed.subgraph.nodeIds = closed.nodeIds
                // Skip empty containers (e.g. `_start: { shape: circle }`
                // which only carry shape decoration, no inner states).
                // They roundtrip through D2 export as the same shape syntax
                // on the matching node, not as a subgraph.
                if closed.nodeIds.isEmpty && closed.subgraph.children.isEmpty {
                    break
                }
                if subgraphStack.isEmpty {
                    subgraphs.append(closed.subgraph)
                } else {
                    let parentIdx = subgraphStack.count - 1
                    var parent = subgraphStack[parentIdx]
                    parent.subgraph.children.append(closed.subgraph)
                    // The nested subgraph's contents also belong to the
                    // outer container's nodeIds for layout purposes.
                    for nodeId in closed.nodeIds {
                        appendUnique(nodeId, to: &parent.nodeIds)
                    }
                    subgraphStack[parentIdx] = parent
                }
            case .nodeDefinition(let def):
                if def.id.lowercased().hasPrefix("entry") || def.id.lowercased().hasPrefix("exit") {
                    // entry: / exit: lines inside a state container describe
                    // PlantUML-style state actions; D2 has no equivalent slot
                    // and Mermaid state v1 dropped them. Surface as a loss.
                    let phase: StateActionPhaseLabel = def.id.lowercased().hasPrefix("entry") ? .entry : .exit
                    let outerStateID = subgraphStack.last?.subgraph.id ?? nodeOrder.last ?? "unknown"
                    diagnostics.append(.lossyTransform(
                        .stateActionDrop,
                        message: "D2 has no native state \(phase.rawValue) action slot; dropping '\(def.id): \(def.label ?? "")' on state '\(outerStateID)'"
                    ))
                    continue
                }
                // `shape: <kind>` inside a state container describes the
                // container's appearance, not a child state. Consume it
                // silently — _start / _end shape derives from id naming.
                if def.id.lowercased() == "shape" && !subgraphStack.isEmpty {
                    continue
                }
                ensureNode(def.id, label: def.label)
                recordInCurrentSubgraph(def.id)
            case .edgeDefinition(let edge):
                ensureNode(edge.source)
                ensureNode(edge.target)
                recordInCurrentSubgraph(edge.source)
                recordInCurrentSubgraph(edge.target)
                edges.append(original_src_types.MermaidEdge(
                    source: edge.source,
                    target: edge.target,
                    label: edge.label,
                    style: .solid,
                    arrowHeadStart: edge.sourceArrow ? .arrow : .none,
                    arrowHeadEnd: edge.targetArrow ? .arrow : .none
                ))
            default:
                break
            }
        }

        let nodesInOrder = nodeOrder.compactMap { id -> (id: String, node: original_src_types.MermaidNode)? in
            guard let n = nodesById[id] else { return nil }
            return (id: id, node: n)
        }

        let graph = original_src_types.MermaidGraph(
            direction: .TD,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs
        )
        return (graph, diagnostics)
    }
}

private enum StateActionPhaseLabel: String { case entry, exit }

/// Emits D2 source for the `.stateDiagram` payload.
///
/// `_start` / `_end` pseudo-states emit as containers with `shape: circle`;
/// regular states emit as bare node names. Edge labels are preserved as
/// transition triggers.
enum D2StateExport {

    static func emit(_ graph: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        if let title = title, !title.isEmpty {
            lines.append("# title: \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        var nameRewrite: [String: String] = [:]
        var displayLabels: [String: String] = [:]
        for entry in graph.nodesInOrder {
            let id = entry.id
            let canonicalName: String
            switch entry.node.shape {
            case .stateStart:
                canonicalName = "_start"
                lines.append("_start: {")
                lines.append("  shape: circle")
                lines.append("}")
            case .stateEnd:
                canonicalName = "_end"
                lines.append("_end: {")
                lines.append("  shape: circle")
                lines.append("}")
            default:
                canonicalName = sanitizeID(id)
            }
            nameRewrite[id] = canonicalName
            let label = entry.node.label
            if !label.isEmpty && label != id {
                displayLabels[id] = label
            }
        }

        if !lines.isEmpty {
            lines.append("")
        }

        // Composite states surface as `Container: { … }` blocks built
        // from MermaidSubgraph.nodeIds — nested composites as nested D2
        // containers, which the parser and mapper round-trip natively.
        // Members declare as `id: "Label"` (D2 rejects bare identifier
        // declarations inside containers; the string form declares the node
        // AND carries its display label). Edges that cross the container
        // boundary (one endpoint outside) emit at the outer scope.
        var edgesEmittedInsideSubgraph: Set<Int> = []
        var declaredNodes: Set<String> = []
        let edgeIndices = graph.edges.enumerated().map { (idx: $0.offset, edge: $0.element) }

        func emitEdge(_ edge: original_src_types.MermaidEdge, indent: String) {
            let src = nameRewrite[edge.source] ?? sanitizeID(edge.source)
            let tgt = nameRewrite[edge.target] ?? sanitizeID(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("\(indent)\(src) -> \(tgt): \(label)")
            } else {
                lines.append("\(indent)\(src) -> \(tgt)")
            }
        }

        func emitMemberDeclaration(_ nid: String, indent: String) {
            let canonical = nameRewrite[nid] ?? sanitizeID(nid)
            if let label = displayLabels[nid] {
                lines.append("\(indent)\(canonical): \"\(escapeLabel(label))\"")
            } else {
                lines.append("\(indent)\(canonical): \"\(canonical)\"")
            }
        }

        func containerHeader(_ sub: original_src_types.MermaidSubgraph) -> String {
            let canonical = sanitizeID(sub.id)
            if !sub.label.isEmpty && sub.label != sub.id {
                return "\(canonical): \"\(escapeLabel(sub.label))\""
            }
            return canonical
        }

        func emitContainer(_ sub: original_src_types.MermaidSubgraph, indent: String) {
            lines.append("\(indent)\(containerHeader(sub)) {")
            let inner = indent + "  "
            for nid in sub.nodeIds {
                emitMemberDeclaration(nid, indent: inner)
                declaredNodes.insert(nid)
            }
            for child in sub.children {
                emitContainer(child, indent: inner)
            }
            lines.append("\(indent)}")
        }

        for sub in graph.subgraphs {
            let memberSet = Set(sub.nodeIds)
            // Edges fully inside the subgraph go inside the block.
            let insideEdges = edgeIndices.filter { idx, edge in
                memberSet.contains(edge.source) && memberSet.contains(edge.target)
            }
            // A container with no inside edges still emits — member
            // declarations (and nested containers) keep isolated members and
            // nested composites from dropping.
            if insideEdges.isEmpty {
                emitContainer(sub, indent: "")
                continue
            }
            lines.append("\(containerHeader(sub)) {")
            for nid in sub.nodeIds {
                let canonical = nameRewrite[nid] ?? sanitizeID(nid)
                if let label = displayLabels[nid] {
                    lines.append("  \(canonical): \"\(escapeLabel(label))\"")
                }
                declaredNodes.insert(nid)
            }
            for child in sub.children {
                emitContainer(child, indent: "  ")
            }
            for (idx, edge) in insideEdges {
                emitEdge(edge, indent: "  ")
                edgesEmittedInsideSubgraph.insert(idx)
            }
            lines.append("}")
        }

        for (idx, edge) in edgeIndices where !edgesEmittedInsideSubgraph.contains(idx) {
            emitEdge(edge, indent: "")
        }

        // Isolated states — no edges, no container — still need a
        // declaration or they drop silently.
        var edgeReferenced: Set<String> = []
        for edge in graph.edges {
            edgeReferenced.insert(edge.source)
            edgeReferenced.insert(edge.target)
        }
        var emittedIsolated = false
        for entry in graph.nodesInOrder {
            let id = entry.id
            guard !declaredNodes.contains(id), !edgeReferenced.contains(id),
                  entry.node.shape != .stateStart, entry.node.shape != .stateEnd else { continue }
            emitMemberDeclaration(id, indent: "")
            emittedIsolated = true
        }
        _ = emittedIsolated

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func escapeLabel(_ text: String) -> String {
        D2Hygiene.escapeString(text)
    }

    static func sanitizeID(_ raw: String) -> String {
        D2Hygiene.mangleID(raw)
    }
}
