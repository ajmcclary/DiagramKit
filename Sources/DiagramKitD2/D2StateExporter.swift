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

        func ensureNode(_ id: String) {
            guard nodesById[id] == nil else { return }
            let shape: original_src_types.NodeShape
            if id == "_start" {
                shape = .stateStart
            } else if id == "_end" {
                shape = .stateEnd
            } else {
                shape = .state
            }
            nodesById[id] = original_src_types.MermaidNode(id: id, label: id, shape: shape)
            nodeOrder.append(id)
        }

        func appendUnique(_ id: String, to list: inout [String]) {
            if !list.contains(id) { list.append(id) }
        }

        func recordInCurrentSubgraph(_ id: String) {
            guard !subgraphStack.isEmpty else { return }
            let idx = subgraphStack.count - 1
            appendUnique(id, to: &subgraphStack[idx].nodeIds)
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
                let closed = subgraphStack.removeLast()
                closed.subgraph.nodeIds = closed.nodeIds
                if subgraphStack.isEmpty {
                    subgraphs.append(closed.subgraph)
                } else {
                    let parentIdx = subgraphStack.count - 1
                    subgraphStack[parentIdx].subgraph.children.append(closed.subgraph)
                    // The nested subgraph's contents also belong to the
                    // outer container's nodeIds for layout purposes.
                    for nodeId in closed.nodeIds {
                        appendUnique(nodeId, to: &subgraphStack[parentIdx].nodeIds)
                    }
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
                ensureNode(def.id)
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
        }

        if !lines.isEmpty {
            lines.append("")
        }

        for edge in graph.edges {
            let src = nameRewrite[edge.source] ?? sanitizeID(edge.source)
            let tgt = nameRewrite[edge.target] ?? sanitizeID(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("\(src) -> \(tgt): \(label)")
            } else {
                lines.append("\(src) -> \(tgt)")
            }
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    static func sanitizeID(_ raw: String) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { result.append("_") }
                result.append(ch)
            case " ", "-", ".":
                result.append("_")
            default: break
            }
        }
        return result.isEmpty ? "node" : result
    }
}
