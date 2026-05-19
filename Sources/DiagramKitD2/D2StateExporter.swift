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
        var depthInContainer = 0

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

        for stmt in document.statements {
            switch stmt {
            case .containerOpen(let open):
                depthInContainer += 1
                ensureNode(open.id)
            case .containerClose:
                depthInContainer = max(0, depthInContainer - 1)
            case .nodeDefinition(let def):
                if depthInContainer > 0 {
                    if def.id.lowercased().hasPrefix("entry") || def.id.lowercased().hasPrefix("exit") {
                        let phase: StateActionPhaseLabel = def.id.lowercased().hasPrefix("entry") ? .entry : .exit
                        let outerStateID = nodeOrder.last ?? "unknown"
                        diagnostics.append(.lossyTransform(
                            .stateActionDrop,
                            message: "D2 has no native state \(phase.rawValue) action slot; dropping '\(def.id): \(def.label ?? "")' on state '\(outerStateID)'"
                        ))
                    }
                    continue
                }
                ensureNode(def.id)
            case .edgeDefinition(let edge):
                ensureNode(edge.source)
                ensureNode(edge.target)
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
            edges: edges
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
