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

    struct MappingContext {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        var diagnostics: [DiagramDiagnostic] = []
        var explicitNodeLabels: Set<String> = []
        var explicitNodeShapes: Set<String> = []

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
            context.diagnostics.append(.featureDropped(
                .slotUnsupported,
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
                upsertNode(
                    nodeStmt.id,
                    explicitAttributes: nodeStmt.attributes,
                    defaultAttributes: context.defaultNodeAttrs,
                    context: &context
                )

            case .edgeStatement(let edgeStmt):
                mapEdge(edgeStmt, context: &context)

            case .attrStatement(let attrStmt):
                switch attrStmt.target {
                case .node:
                    context.defaultNodeAttrs = attrStmt.attributes
                    emitUnsupportedNodeDefaults(attrStmt.attributes, context: &context)
                case .edge:
                    context.defaultEdgeAttrs = attrStmt.attributes
                    context.diagnostics.append(.featureDropped(
                        .slotUnsupported,
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

    private func upsertNode(
        _ id: String,
        explicitAttributes: [DOTAttribute],
        defaultAttributes: [DOTAttribute],
        context: inout MappingContext
    ) {
        guard !id.isEmpty else { return }

        let effectiveAttributes = defaultAttributes + explicitAttributes
        var label = attributeValue("label", in: effectiveAttributes) ?? id
        // HTML-like labels (e.g. `<<TABLE>…</TABLE>>`) are valid Graphviz
        // syntax but not yet rendered by DiagramKit. Detect and surface a
        // diagnostic; render the node with its identifier as the label so
        // the diagram is still usable.
        if _isHTMLLabel(label) {
            context.diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "HTML-like label on node '\(id)' is not yet supported; falling back to the node identifier as the rendered label",
                location: nil
            ))
            label = id
        }
        let shape = mapNodeShape(attributes: effectiveAttributes, context: &context)

        if var existing = context.nodesById[id] {
            if let explicitLabel = attributeValue("label", in: explicitAttributes) {
                if context.explicitNodeLabels.contains(id), explicitLabel != existing.label {
                    context.diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "Duplicate node '\(id)' with different label; keeping first label '\(existing.label)'",
                        location: nil
                    ))
                } else {
                    existing.label = explicitLabel
                    context.explicitNodeLabels.insert(id)
                }
            }

            if let explicitShapeAttr = explicitAttributes.first(where: { $0.key.lowercased() == "shape" }) {
                let explicitShape = mapNodeShape(attributes: [explicitShapeAttr], context: &context)
                if context.explicitNodeShapes.contains(id), explicitShape != existing.shape {
                    context.diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "Duplicate node '\(id)' with different shape; keeping first shape",
                        location: nil
                    ))
                } else {
                    existing.shape = explicitShape
                    context.explicitNodeShapes.insert(id)
                }
            }

            context.nodesById[id] = existing
            recordNodeInCurrentSubgraph(id: id, context: &context)
            emitUnsupportedNodeAttrs(explicitAttributes, context: &context)
            return
        }

        let node = original_src_types.MermaidNode(
            id: id,
            label: label,
            shape: shape
        )
        context.nodesById[id] = node
        context.nodeOrder.append(id)

        if attributeValue("label", in: explicitAttributes) != nil {
            context.explicitNodeLabels.insert(id)
        }
        if explicitAttributes.contains(where: { $0.key.lowercased() == "shape" }) {
            context.explicitNodeShapes.insert(id)
        }

        recordNodeInCurrentSubgraph(id: id, context: &context)

        // Emit diagnostics for unsupported node attributes
        emitUnsupportedNodeAttrs(explicitAttributes, context: &context)
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
        if context.nodesById[id] != nil {
            recordNodeInCurrentSubgraph(id: id, context: &context)
            return
        }

        let label = attributeValue("label", in: context.defaultNodeAttrs) ?? id
        let shape = mapNodeShape(attributes: context.defaultNodeAttrs, context: &context)
        let node = original_src_types.MermaidNode(
            id: id,
            label: label,
            shape: shape
        )
        context.nodesById[id] = node
        context.nodeOrder.append(id)

        recordNodeInCurrentSubgraph(id: id, context: &context)
    }

    private func recordNodeInCurrentSubgraph(id: String, context: inout MappingContext) {
        if !context.subgraphStack.isEmpty {
            let idx = context.subgraphStack.count - 1
            if !context.subgraphStack[idx].nodeIds.contains(id) {
                context.subgraphStack[idx].nodeIds.append(id)
            }
        }
    }

    // MARK: - Shape mapping

    private func mapNodeShape(attributes: [DOTAttribute], context: inout MappingContext) -> original_src_types.NodeShape {
        guard let shapeAttr = attributes.first(where: { $0.key.lowercased() == "shape" }) else {
            return .rectangle
        }

        let shape = shapeAttr.value.lowercased()
        switch shape {
        case "box", "rect", "rectangle", "square": return .rectangle
        case "ellipse", "oval": return .ellipse
        case "circle": return .circle
        case "diamond": return .diamond
        case "cylinder": return .cylinder
        case "hexagon": return .hexagon
        case "house", "invhouse": return .notchedPentagon
        case "trapezium", "trapezoid": return .trapezoid
        case "invtrapezium": return .trapezoidAlt
        case "parallelogram": return .parallelogram
        case "note": return .stateNote
        case "tab", "folder": return .roundedWithTitle
        case "component": return .dividedRectangle
        case "triangle": return .triangle
        case "invtriangle": return .flippedTriangle
        case "doublecircle": return .doublecircle
        case "plaintext", "none": return .text
        case "record", "mrecord":
            context.diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "Graphviz '\(shape)' shape is not yet supported; rendered as rectangle",
                location: nil
            ))
            return .rectangle
        default:
            context.diagnostics.append(.featureDropped(
                .slotUnsupported,
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

    private func attributeValue(_ name: String, in attributes: [DOTAttribute]) -> String? {
        attributes.first { $0.key.lowercased() == name }?.value
    }

    /// True if `value` is a Graphviz HTML-like label — i.e. begins with `<`
    /// and ends with `>` (with internal markup). The DOT parser stores
    /// HTML-like labels with the angle-brackets preserved.
    private func _isHTMLLabel(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 else {
            return false
        }
        return true
    }

}
