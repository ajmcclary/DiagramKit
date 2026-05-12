import Foundation
import DiagramKitModel
import DiagramKitImport

/// Converts `DOTDocument` → `ParsedGraphModel` plus diagnostics.
///
/// Follows the `D2Mapper` pattern: ordered node table with merge
/// and edge-endpoint synthesis. Default attribute scoping respects
/// DOT semantics — defaults set inside a subgraph reset on exit.
public struct DOTMapper {

    public init() {}

    // MARK: - Entry point

    public func map(_ document: DOTDocument) -> (graph: ParsedGraphModel, diagnostics: [DiagramDiagnostic]) {
        var context = MappingContext()
        let graph = walk(document, context: &context)
        return (graph, context.diagnostics)
    }

    // MARK: - Mapping context

    private struct MappingContext {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Default attributes scoped to current nesting level
        var defaultNodeAttrs: [DOTAttribute] = []
        var defaultEdgeAttrs: [DOTAttribute] = []

        // Subgraph stack for tracking which subgraph owns nodes
        var subgraphStack: [(subgraph: original_src_types.MermaidSubgraph, nodeIds: [String])] = []
    }

    // MARK: - Walk

    private func walk(_ document: DOTDocument, context: inout MappingContext) -> ParsedGraphModel {
        // Extract direction from graph-level attributes
        var direction = original_src_types.Direction.TD

        // Process graph-level attributes and statements
        for stmt in document.statements {
            switch stmt {
            case .attrStatement(let attrStmt) where attrStmt.target == .graph:
                // graph [rankdir=LR] form
                if let dirValue = attrStmt.attributes.first(where: { $0.key == "rankdir" })?.value {
                    direction = mapRankdir(dirValue)
                }
                // Emit diagnostics for unsupported graph attributes
                emitUnsupportedGraphAttrs(attrStmt.attributes, context: &context)
            case .graphAttr(let key, let value):
                if key.lowercased() == "rankdir" {
                    direction = mapRankdir(value)
                } else {
                    emitUnsupportedGraphAttr(key: key, value: value, context: &context)
                }
            default:
                break
            }
        }

        // Walk statements to build nodes, edges, subgraphs
        walkStatements(document.statements, context: &context)

        let nodesInOrder = context.nodeOrder.compactMap { id -> (id: String, node: original_src_types.MermaidNode)? in
            guard let node = context.nodesById[id] else { return nil }
            return (id: id, node: node)
        }

        // Emit strict diagnostic
        if document.strict {
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "strict mode not yet supported; duplicate edges preserved",
                location: nil
            ))
        }

        return original_src_types.MermaidGraph(
            direction: direction,
            nodesInOrder: nodesInOrder,
            edges: context.edges,
            subgraphs: context.subgraphs
        )
    }

    private func walkStatements(_ statements: [DOTStatement], context: inout MappingContext) {
        // Snapshot defaults for scoping
        let savedNodeDefaults = context.defaultNodeAttrs
        let savedEdgeDefaults = context.defaultEdgeAttrs

        defer {
            context.defaultNodeAttrs = savedNodeDefaults
            context.defaultEdgeAttrs = savedEdgeDefaults
        }

        for stmt in statements {
            switch stmt {
            case .nodeStatement(let nodeStmt):
                let effectiveAttrs = context.defaultNodeAttrs + nodeStmt.attributes
                upsertNode(nodeStmt.id, attributes: effectiveAttrs, context: &context)

            case .edgeStatement(let edgeStmt):
                mapEdge(edgeStmt, context: &context)

            case .attrStatement(let attrStmt):
                switch attrStmt.target {
                case .node:
                    context.defaultNodeAttrs = attrStmt.attributes
                    emitUnsupportedNodeDefaults(attrStmt.attributes, context: &context)
                case .edge:
                    context.defaultEdgeAttrs = attrStmt.attributes
                    context.diagnostics.append(DiagramDiagnostic(
                        severity: .unsupported,
                        message: "default edge attributes not yet supported",
                        location: nil
                    ))
                case .graph:
                    emitUnsupportedGraphAttrs(attrStmt.attributes, context: &context)
                }

            case .subgraph(let sub):
                if sub.isCluster {
                    // Push subgraph context
                    let sg = original_src_types.MermaidSubgraph(
                        id: sub.id ?? "cluster_unnamed",
                        label: sub.displayLabel(from: extractSubgraphAttrs(sub.statements)) ?? sub.id ?? "Subgraph",
                        nodeIds: []
                    )
                    context.subgraphStack.append((subgraph: sg, nodeIds: []))
                    walkStatements(sub.statements, context: &context)
                    let closed = context.subgraphStack.removeLast()
                    closed.subgraph.nodeIds = closed.nodeIds

                    if context.subgraphStack.isEmpty {
                        context.subgraphs.append(closed.subgraph)
                    } else {
                        let parentIdx = context.subgraphStack.count - 1
                        context.subgraphStack[parentIdx].subgraph.children.append(closed.subgraph)
                        for nodeId in closed.nodeIds {
                            if !context.subgraphStack[parentIdx].nodeIds.contains(nodeId) {
                                context.subgraphStack[parentIdx].nodeIds.append(nodeId)
                            }
                        }
                    }
                } else {
                    // Anonymous subgraph: inline nodes/edges into parent scope
                    walkStatements(sub.statements, context: &context)
                }

            case .graphAttr(let key, let value):
                if key.lowercased() == "label" && !context.subgraphStack.isEmpty {
                    // This is a subgraph label
                } else if key.lowercased() != "rankdir" {
                    emitUnsupportedGraphAttr(key: key, value: value, context: &context)
                }
            }
        }
    }

    // MARK: - Node upsert

    private func upsertNode(_ id: String, attributes: [DOTAttribute], context: inout MappingContext) {
        guard !id.isEmpty else { return }

        let label = attributes.first(where: { $0.key == "label" })?.value ?? id
        let shape = mapNodeShape(attributes: attributes, context: &context)

        if let existing = context.nodesById[id] {
            // Merge: keep existing label unless new one is explicitly set
            let hasExplicitLabel = attributes.contains(where: { $0.key == "label" })
            if hasExplicitLabel {
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "Duplicate node '\(id)' with different label; keeping first label '\(existing.label)'",
                    location: nil
                ))
            }
            // For shape: keep existing shape unless explicit
            let hasExplicitShape = attributes.contains(where: { $0.key == "shape" })
            if hasExplicitShape && shape != existing.shape {
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "Duplicate node '\(id)' with different shape; keeping first shape",
                    location: nil
                ))
            }
            return
        }

        let node = original_src_types.MermaidNode(
            id: id,
            label: label,
            shape: shape
        )
        context.nodesById[id] = node
        context.nodeOrder.append(id)

        // Track in current subgraph
        if !context.subgraphStack.isEmpty {
            let idx = context.subgraphStack.count - 1
            if !context.subgraphStack[idx].nodeIds.contains(id) {
                context.subgraphStack[idx].nodeIds.append(id)
            }
        }

        // Emit diagnostics for unsupported node attributes
        emitUnsupportedNodeAttrs(attributes, context: &context)
    }

    // MARK: - Edge mapping

    private func mapEdge(_ edge: DOTEdgeStatement, context: inout MappingContext) {
        let source = edge.source
        let target = edge.target

        // Synthesize endpoints if missing
        ensureNode(id: source, context: &context)
        ensureNode(id: target, context: &context)

        let arrowEnd: original_src_types.ArrowHeadType = edge.directed ? .arrow : .none

        let mermaidEdge = original_src_types.MermaidEdge(
            source: source,
            target: target,
            label: edge.label,
            style: .solid,
            arrowHeadStart: .none,
            arrowHeadEnd: arrowEnd
        )

        context.edges.append(mermaidEdge)

        // Emit diagnostics for unsupported edge attributes
        emitUnsupportedEdgeAttrs(edge.attributes, context: &context)
    }

    private func ensureNode(id: String, context: inout MappingContext) {
        guard context.nodesById[id] == nil else { return }
        let node = original_src_types.MermaidNode(
            id: id,
            label: id,
            shape: .rectangle
        )
        context.nodesById[id] = node
        context.nodeOrder.append(id)

        if !context.subgraphStack.isEmpty {
            let idx = context.subgraphStack.count - 1
            if !context.subgraphStack[idx].nodeIds.contains(id) {
                context.subgraphStack[idx].nodeIds.append(id)
            }
        }
    }

    // MARK: - Shape mapping

    private func mapNodeShape(attributes: [DOTAttribute], context: inout MappingContext) -> original_src_types.NodeShape {
        guard let shapeAttr = attributes.first(where: { $0.key == "shape" }) else {
            return .rectangle
        }

        let shape = shapeAttr.value.lowercased()
        switch shape {
        case "box", "rect", "rectangle": return .rectangle
        case "ellipse", "oval": return .ellipse
        case "circle": return .circle
        case "diamond": return .diamond
        case "cylinder": return .cylinder
        case "hexagon": return .hexagon
        case "plaintext", "none": return .text
        default:
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "\(shapeAttr.value) shape not yet supported; rendered as rectangle",
                location: nil
            ))
            return .rectangle
        }
    }

    // MARK: - Direction mapping

    private func mapRankdir(_ value: String) -> original_src_types.Direction {
        switch value.lowercased() {
        case "lr": return .LR
        case "tb", "td": return .TD
        case "bt": return .BT
        case "rl": return .RL
        default: return .TD
        }
    }

    // MARK: - Subgraph helpers

    private func extractSubgraphAttrs(_ statements: [DOTStatement]) -> [DOTAttribute] {
        for stmt in statements {
            switch stmt {
            case .attrStatement(let attrStmt) where attrStmt.target == .graph:
                return attrStmt.attributes
            case .graphAttr(let key, let value):
                return [DOTAttribute(key: key, value: value)]
            default:
                continue
            }
        }
        return []
    }

    // MARK: - Diagnostic emitters

    private func emitUnsupportedNodeAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "label", "shape", "id":
                continue // supported
            case "style":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "node style not yet supported",
                    location: nil
                ))
            case "color", "fillcolor", "fontcolor", "bgcolor", "pencolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            case "fontname", "fontsize":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "font attributes not yet supported",
                    location: nil
                ))
            case "penwidth":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "line/arrow attributes not yet supported",
                    location: nil
                ))
            case "url", "href", "target", "tooltip":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "hyperlink attributes not yet supported",
                    location: nil
                ))
            case "image", "imagescale", "imagepos":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "image attributes not yet supported",
                    location: nil
                ))
            default:
                // Unknown attribute — emit generic unsupported
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized node attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    private func emitUnsupportedEdgeAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "label":
                continue // supported
            case "color", "fillcolor", "fontcolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            case "style":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge style not yet supported",
                    location: nil
                ))
            case "fontname", "fontsize":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "font attributes not yet supported",
                    location: nil
                ))
            case "penwidth", "arrowsize", "arrowhead":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "line/arrow attributes not yet supported",
                    location: nil
                ))
            case "constraint", "weight":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge weight/constraint not yet supported",
                    location: nil
                ))
            default:
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized edge attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    private func emitUnsupportedGraphAttrs(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "rankdir", "label":
                continue // supported
            case "rank":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "rank constraints not yet supported",
                    location: nil
                ))
            case "splines", "overlap", "sep", "pad", "margin", "nodesep", "ranksep":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "layout engine attributes not yet supported",
                    location: nil
                ))
            case "bgcolor", "pencolor", "labelloc", "labeljust":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "graph appearance attributes not yet supported",
                    location: nil
                ))
            case "compound", "lhead", "ltail":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "compound edge attributes not yet supported",
                    location: nil
                ))
            case "concentrate":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "edge concentration not yet supported",
                    location: nil
                ))
            case "center", "resolution", "page", "viewport", "ratio", "size":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "graph layout attributes not yet supported",
                    location: nil
                ))
            default:
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "unrecognized graph attribute '\(attr.key)' not yet supported",
                    location: nil
                ))
            }
        }
    }

    private func emitUnsupportedNodeDefaults(_ attributes: [DOTAttribute], context: inout MappingContext) {
        for attr in attributes {
            let key = attr.key.lowercased()
            switch key {
            case "shape", "label":
                continue // supported
            case "style":
                if attr.value.lowercased() != "solid" {
                    context.diagnostics.append(DiagramDiagnostic(
                        severity: .unsupported,
                        message: "node style not yet supported",
                        location: nil
                    ))
                }
            case "color", "fillcolor", "fontcolor", "bgcolor", "pencolor":
                context.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "color attributes not yet supported",
                    location: nil
                ))
            default:
                break
            }
        }
    }

    private func emitUnsupportedGraphAttr(key: String, value: String, context: inout MappingContext) {
        let lower = key.lowercased()
        switch lower {
        case "rankdir", "label":
            return // handled
        case "rank":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "rank constraints not yet supported",
                location: nil
            ))
        case "splines", "overlap", "sep", "pad", "margin", "nodesep", "ranksep":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "layout engine attributes not yet supported",
                location: nil
            ))
        case "concentrate":
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "edge concentration not yet supported",
                location: nil
            ))
        default:
            context.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "unrecognized graph attribute '\(key)' not yet supported",
                location: nil
            ))
        }
    }
}
