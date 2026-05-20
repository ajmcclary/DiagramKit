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
        var ctx = MapContext()
        // Pre-pass: scan the full statement tree (including subgraph
        // contents) to register all start/end pseudo-states. This ensures
        // ensureNode picks the right shape regardless of declaration order.
        collectStartEnd(document.statements, into: &ctx.startIDs, endIDs: &ctx.endIDs)
        // Walk root statements; child subgraphs at root level append into
        // ctx.subgraphs directly.
        var rootIDs: [String] = []
        processStatements(document.statements, ctx: &ctx, collector: &rootIDs, atRoot: true)

        let nodesInOrder = ctx.nodeOrder.compactMap { id -> (id: String, node: original_src_types.MermaidNode)? in
            guard let n = ctx.nodesById[id] else { return nil }
            return (id: id, node: n)
        }
        let graph = original_src_types.MermaidGraph(
            direction: .TD,
            nodesInOrder: nodesInOrder,
            edges: ctx.edges,
            subgraphs: ctx.subgraphs
        )
        return (graph, ctx.diagnostics)
    }

    /// Mutable accumulator threaded through the recursive mapper. Holds the
    /// flat node/edge/subgraph state plus the pre-scanned pseudo-state sets.
    private struct MapContext {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        var startIDs: Set<String> = []
        var endIDs: Set<String> = []
        var diagnostics: [DiagramDiagnostic] = []
    }

    /// Walks `statements`, threading node ids into `collector` so cluster
    /// subgraphs can populate their `nodeIds`. When `atRoot` is true, the
    /// resulting cluster subgraphs append to `ctx.subgraphs` instead of
    /// nesting under a parent.
    private func processStatements(
        _ statements: [DOTStatement],
        ctx: inout MapContext,
        collector: inout [String],
        atRoot: Bool
    ) {
        for stmt in statements {
            switch stmt {
            case .nodeStatement(let node):
                ensureNode(node.id, ctx: &ctx)
                appendUnique(node.id, to: &collector)
            case .edgeStatement(let edge):
                ensureNode(edge.source, ctx: &ctx)
                ensureNode(edge.target, ctx: &ctx)
                let attrs = Dictionary(uniqueKeysWithValues: edge.attributes.map { ($0.key, $0.value) })
                ctx.edges.append(original_src_types.MermaidEdge(
                    source: edge.source,
                    target: edge.target,
                    label: attrs["label"],
                    style: .solid,
                    arrowHeadStart: .none,
                    arrowHeadEnd: edge.directed ? .arrow : .none
                ))
                appendUnique(edge.source, to: &collector)
                appendUnique(edge.target, to: &collector)
            case .subgraph(let sub):
                if let mapped = mapSubgraph(sub, ctx: &ctx) {
                    if atRoot {
                        ctx.subgraphs.append(mapped)
                    } else {
                        // Nested cluster — parent owns it as a child and
                        // also accounts for its node ids in its own list.
                        // Caller threads this via the returned collector
                        // in mapSubgraph; here we just expose ids.
                        for nid in mapped.nodeIds {
                            appendUnique(nid, to: &collector)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    private func mapSubgraph(
        _ sub: DOTSubgraph,
        ctx: inout MapContext
    ) -> original_src_types.MermaidSubgraph? {
        guard sub.isCluster else {
            // Non-cluster subgraphs flatten — their contents merge into the
            // current scope. Discard the returned collector.
            var flat: [String] = []
            processStatements(sub.statements, ctx: &ctx, collector: &flat, atRoot: false)
            return nil
        }
        let rawID = sub.id ?? ""
        let bareID = rawID.hasPrefix("cluster_") ? String(rawID.dropFirst("cluster_".count)) : rawID
        let label = sub.displayLabel(from: subgraphAttrs(sub.statements)) ?? bareID
        var localIDs: [String] = []
        // Children clusters land in `ctx.subgraphs` at root level; nested
        // ones get added to our `children` list below. Since DOT clusters
        // can't trivially distinguish "nested-cluster-as-child" from
        // "nested-cluster-as-sibling" without restructuring the recursion,
        // route nested clusters as children of this subgraph.
        var childClusters: [original_src_types.MermaidSubgraph] = []
        for stmt in sub.statements {
            switch stmt {
            case .nodeStatement(let node):
                ensureNode(node.id, ctx: &ctx)
                appendUnique(node.id, to: &localIDs)
            case .edgeStatement(let edge):
                ensureNode(edge.source, ctx: &ctx)
                ensureNode(edge.target, ctx: &ctx)
                let attrs = Dictionary(uniqueKeysWithValues: edge.attributes.map { ($0.key, $0.value) })
                ctx.edges.append(original_src_types.MermaidEdge(
                    source: edge.source,
                    target: edge.target,
                    label: attrs["label"],
                    style: .solid,
                    arrowHeadStart: .none,
                    arrowHeadEnd: edge.directed ? .arrow : .none
                ))
                appendUnique(edge.source, to: &localIDs)
                appendUnique(edge.target, to: &localIDs)
            case .subgraph(let nested):
                if let mapped = mapSubgraph(nested, ctx: &ctx) {
                    childClusters.append(mapped)
                    for nid in mapped.nodeIds {
                        appendUnique(nid, to: &localIDs)
                    }
                }
            default:
                break
            }
        }
        return original_src_types.MermaidSubgraph(
            id: bareID,
            label: label,
            nodeIds: localIDs,
            children: childClusters
        )
    }

    private func ensureNode(_ id: String, ctx: inout MapContext) {
        guard ctx.nodesById[id] == nil else { return }
        let shape: original_src_types.NodeShape
        if ctx.startIDs.contains(id) {
            shape = .stateStart
        } else if ctx.endIDs.contains(id) {
            shape = .stateEnd
        } else {
            shape = .state
        }
        ctx.nodesById[id] = original_src_types.MermaidNode(id: id, label: id, shape: shape)
        ctx.nodeOrder.append(id)
    }

    private func appendUnique(_ id: String, to list: inout [String]) {
        if !list.contains(id) { list.append(id) }
    }

    /// Walks the statement tree to register every start/end pseudo-state id
    /// before the main mapping pass runs.
    private func collectStartEnd(
        _ statements: [DOTStatement],
        into startIDs: inout Set<String>,
        endIDs: inout Set<String>
    ) {
        for stmt in statements {
            switch stmt {
            case .nodeStatement(let node):
                if DOTStateProbe.isStateStartNode(node) { startIDs.insert(node.id) }
                if DOTStateProbe.isStateEndNode(node) { endIDs.insert(node.id) }
            case .subgraph(let sub):
                collectStartEnd(sub.statements, into: &startIDs, endIDs: &endIDs)
            default:
                break
            }
        }
    }

    /// Extracts the inline `label="…";` from a subgraph's body statements.
    /// DOT lets a subgraph define its label via an attribute statement at
    /// the top of the block (`.attrStatement(.graph, [label="..."])`).
    private func subgraphAttrs(_ statements: [DOTStatement]) -> [DOTAttribute] {
        var attrs: [DOTAttribute] = []
        for stmt in statements {
            if case .attrStatement(let attrStmt) = stmt, attrStmt.target == .graph {
                attrs.append(contentsOf: attrStmt.attributes)
            }
        }
        return attrs
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

        var nameRewrite: [String: String] = [:]
        for entry in graph.nodesInOrder {
            let id = entry.id
            switch entry.node.shape {
            case .stateStart:
                nameRewrite[id] = "_start"
                lines.append("  _start [shape=point, style=filled, fillcolor=black];")
            case .stateEnd:
                nameRewrite[id] = "_end"
                lines.append("  _end [shape=doublecircle, style=filled, fillcolor=black];")
            default:
                break
            }
        }

        // Composite states surface as `subgraph cluster_<id> { … }` blocks.
        // Membership comes from MermaidSubgraph.nodeIds. Each member node
        // is declared inside the cluster body so re-import can recover the
        // parent relationship; nodes that the cluster references but
        // weren't yet declared get a bare declaration line.
        var declaredInCluster: Set<String> = []
        for sub in graph.subgraphs {
            lines.append("  subgraph cluster_\(DOTClassExport.sanitizeDOTID(sub.id)) {")
            lines.append("    label=\(DOTClassExport.quoted(sub.label));")
            for nid in sub.nodeIds {
                let canonical = nameRewrite[nid] ?? DOTClassExport.sanitizeDOTID(nid)
                lines.append("    \(canonical);")
                declaredInCluster.insert(nid)
            }
            lines.append("  }")
        }

        for edge in graph.edges {
            let src = nameRewrite[edge.source] ?? DOTClassExport.sanitizeDOTID(edge.source)
            let tgt = nameRewrite[edge.target] ?? DOTClassExport.sanitizeDOTID(edge.target)
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
