import Foundation
import DiagramKitModel
import DiagramKitImport

/// Converts D2Document → ParsedGraphModel (MermaidGraph) plus diagnostics.
public struct D2Mapper {

    public init() {}

    public func map(_ document: D2Document) -> (graph: ParsedGraphModel, diagnostics: [DiagramDiagnostic]) {
        var nodesById: [String: original_src_types.MermaidNode] = [:]
        var nodeOrder: [String] = []
        var edges: [original_src_types.MermaidEdge] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        var diagnostics: [DiagramDiagnostic] = []
        var anonymousCounter = 0
        var direction: original_src_types.Direction = .TD

        var subgraphStack: [(subgraph: original_src_types.MermaidSubgraph, nodeIds: [String])] = []

        func appendUnique(_ id: String, to ids: inout [String]) {
            guard !ids.contains(id) else { return }
            ids.append(id)
        }

        func recordInCurrentSubgraph(_ id: String) {
            guard !subgraphStack.isEmpty else { return }
            appendUnique(id, to: &subgraphStack[subgraphStack.count - 1].nodeIds)
        }

        func ensureNode(id: String) {
            guard nodesById[id] == nil else { return }
            nodesById[id] = original_src_types.MermaidNode(
                id: id,
                label: id,
                shape: .rectangle
            )
            nodeOrder.append(id)
        }

        func upsertNode(_ nodeDef: D2NodeDefinition) {
            guard !nodeDef.id.isEmpty else { return }
            ensureNode(id: nodeDef.id)

            var node = nodesById[nodeDef.id]!
            if let label = nodeDef.label {
                node.label = label
            }

            if let d2Shape = nodeDef.shape {
                if let mapped = mapD2Shape(d2Shape) {
                    node.shape = mapped
                } else {
                    diagnostics.append(DiagramDiagnostic(
                        severity: .unsupported,
                        message: "\(d2Shape) shape not yet supported",
                        location: nil
                    ))
                }
            }

            var properties = node.properties ?? original_src_types.NodeProperties()
            var hasProperties = node.properties != nil
            if let width = nodeDef.width {
                properties.w = width
                hasProperties = true
            }
            if let height = nodeDef.height {
                properties.h = height
                hasProperties = true
            }
            node.properties = hasProperties ? properties : nil

            if nodeDef.direction != nil {
                diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "node direction not yet supported",
                    location: nil
                ))
            }
            if nodeDef.icon != nil {
                diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "icon not yet supported",
                    location: nil
                ))
            }
            if nodeDef.tooltip != nil {
                diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "tooltips not yet supported",
                    location: nil
                ))
            }
            if nodeDef.link != nil {
                diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "links not yet supported",
                    location: nil
                ))
            }

            nodesById[nodeDef.id] = node
            recordInCurrentSubgraph(nodeDef.id)
        }

        func normalizeEndpoint(_ endpoint: String) -> String {
            let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty else { return trimmed }
            anonymousCounter += 1
            return "__anonymous_\(anonymousCounter)"
        }

        for stmt in document.statements {
            switch stmt {
            case .nodeDefinition(let nodeDef):
                upsertNode(nodeDef)

            case .edgeDefinition(let edgeDef):
                let source = normalizeEndpoint(edgeDef.source)
                let target = normalizeEndpoint(edgeDef.target)
                let sourceArrow: original_src_types.ArrowHeadType = edgeDef.sourceArrow ? .arrow : .none
                let targetArrow: original_src_types.ArrowHeadType = edgeDef.targetArrow ? .arrow : .none

                ensureNode(id: source)
                ensureNode(id: target)
                recordInCurrentSubgraph(source)
                recordInCurrentSubgraph(target)

                let edge = original_src_types.MermaidEdge(
                    source: source,
                    target: target,
                    label: edgeDef.label,
                    style: .solid,
                    arrowHeadStart: sourceArrow,
                    arrowHeadEnd: targetArrow
                )

                edges.append(edge)

            case .direction(let value):
                if let mapped = mapD2Direction(value) {
                    direction = mapped
                }

            case .containerOpen(let open):
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
                    let parentIndex = subgraphStack.count - 1
                    subgraphStack[parentIndex].subgraph.children.append(closed.subgraph)
                    for nodeId in closed.nodeIds {
                        appendUnique(nodeId, to: &subgraphStack[parentIndex].nodeIds)
                    }
                }
            }
        }

        let nodesInOrder = nodeOrder.compactMap { id -> (id: String, node: original_src_types.MermaidNode)? in
            guard let node = nodesById[id] else { return nil }
            return (id: id, node: node)
        }

        let graph = original_src_types.MermaidGraph(
            direction: direction,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs
        )

        return (graph, diagnostics)
    }

    private func mapD2Direction(_ value: String) -> original_src_types.Direction? {
        switch value.lowercased() {
        case "right": return .LR
        case "down": return .TD
        case "up": return .BT
        case "left": return .RL
        default: return nil
        }
    }
}
