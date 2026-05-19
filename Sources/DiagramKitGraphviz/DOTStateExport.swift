import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `DOTDocument` describes a state diagram.
///
/// A DOT document is treated as a state diagram when at least one node has
/// `shape=point` or `shape=doublecircle` (the canonical Graphviz state-machine
/// pseudo-state representations) AND no node carries a class-record label.
enum DOTStateProbe {

    static func detectsStateDiagram(_ document: DOTDocument) -> Bool {
        if DOTClassProbe.detectsClassDiagram(document) { return false }
        for stmt in document.statements {
            if case .nodeStatement(let node) = stmt {
                let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
                let shape = attrs["shape"]
                if shape == "point" || shape == "doublecircle" { return true }
            }
        }
        return false
    }

    static func isStateStartNode(_ node: DOTNodeStatement) -> Bool {
        let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
        return attrs["shape"] == "point"
    }

    static func isStateEndNode(_ node: DOTNodeStatement) -> Bool {
        let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
        return attrs["shape"] == "doublecircle"
    }
}

/// Builds a `ParsedGraphModel` from a `DOTDocument` representing a state
/// machine.
struct DOTStateMapper {

    func map(_ document: DOTDocument) -> (ParsedGraphModel, [DiagramDiagnostic]) {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var startIDs: Set<String> = []
        var endIDs: Set<String> = []
        let diagnostics: [DiagramDiagnostic] = []

        for stmt in document.statements {
            if case .nodeStatement(let node) = stmt {
                if DOTStateProbe.isStateStartNode(node) { startIDs.insert(node.id) }
                if DOTStateProbe.isStateEndNode(node) { endIDs.insert(node.id) }
            }
        }

        func ensureNode(_ id: String) {
            guard nodesById[id] == nil else { return }
            let shape: original_src_types.NodeShape
            if startIDs.contains(id) {
                shape = .stateStart
            } else if endIDs.contains(id) {
                shape = .stateEnd
            } else {
                shape = .state
            }
            nodesById[id] = original_src_types.MermaidNode(id: id, label: id, shape: shape)
            nodeOrder.append(id)
        }

        for stmt in document.statements {
            switch stmt {
            case .nodeStatement(let node):
                ensureNode(node.id)
            case .edgeStatement(let edge):
                ensureNode(edge.source)
                ensureNode(edge.target)
                let attrs = Dictionary(uniqueKeysWithValues: edge.attributes.map { ($0.key, $0.value) })
                edges.append(original_src_types.MermaidEdge(
                    source: edge.source,
                    target: edge.target,
                    label: attrs["label"],
                    style: .solid,
                    arrowHeadStart: .none,
                    arrowHeadEnd: edge.directed ? .arrow : .none
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

/// Emits DOT source for the `.stateDiagram` payload.
enum DOTStateExport {

    static func emit(_ graph: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        let graphName = title.flatMap { DOTClassExport.sanitizeDOTID($0) } ?? "StateMachine"
        lines.append("digraph \(graphName) {")
        if let title = title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(DOTClassExport.quoted(DOTClassExport.singleLineTitle(title)));")
        }

        for entry in graph.nodesInOrder {
            let id = entry.id
            let sanitizedId = DOTClassExport.sanitizeDOTID(id)
            switch entry.node.shape {
            case .stateStart:
                lines.append("  \(sanitizedId) [shape=point, style=filled, fillcolor=black];")
            case .stateEnd:
                lines.append("  \(sanitizedId) [shape=doublecircle, style=filled, fillcolor=black];")
            default:
                break
            }
        }

        for edge in graph.edges {
            let src = DOTClassExport.sanitizeDOTID(edge.source)
            let tgt = DOTClassExport.sanitizeDOTID(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("  \(src) -> \(tgt) [label=\(DOTClassExport.quoted(label))];")
            } else {
                lines.append("  \(src) -> \(tgt);")
            }
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }
}
