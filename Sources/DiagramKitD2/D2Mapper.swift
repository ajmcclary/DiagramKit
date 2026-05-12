import Foundation
import DiagramKitModel
import DiagramKitImport

/// Converts D2Document → ParsedGraphModel (MermaidGraph) plus diagnostics.
public struct D2Mapper {

    public init() {}

    public func map(_ document: D2Document) -> (graph: ParsedGraphModel, diagnostics: [DiagramDiagnostic]) {
        var nodesInOrder: [(id: String, node: original_src_types.MermaidNode)] = []
        var edges: [original_src_types.MermaidEdge] = []
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        var diagnostics: [DiagramDiagnostic] = []
        var anonymousCounter = 0
        var direction: original_src_types.Direction = .TD

        // Track current subgraph nesting
        var subgraphStack: [original_src_types.MermaidSubgraph] = []
        var pendingNodeIds: [String: [String]] = [:] // subgraph id → node ids found inside it

        for stmt in document.statements {
            switch stmt {
            case .nodeDefinition(let nodeDef):
                // Determine shape
                var shape: original_src_types.NodeShape = .rectangle
                if let d2Shape = nodeDef.shape {
                    if let mapped = mapD2Shape(d2Shape) {
                        shape = mapped
                    } else {
                        diagnostics.append(DiagramDiagnostic(
                            severity: .unsupported,
                            message: "\(d2Shape) shape not yet supported",
                            location: nil
                        ))
                    }
                }

                // Build properties
                var properties = original_src_types.NodeProperties()
                if let w = nodeDef.width { properties.w = w }
                if let h = nodeDef.height { properties.h = h }
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

                let node = original_src_types.MermaidNode(
                    id: nodeDef.id,
                    label: nodeDef.label ?? nodeDef.id,
                    shape: shape,
                    properties: (properties.w != nil || properties.h != nil) ? properties : nil
                )

                nodesInOrder.append((id: nodeDef.id, node: node))

                // If we're inside a subgraph, record this node
                if let current = subgraphStack.last {
                    pendingNodeIds[current.id, default: []].append(nodeDef.id)
                }

            case .edgeDefinition(let edgeDef):
                var source = edgeDef.source
                var target = edgeDef.target
                let sourceArrow: original_src_types.ArrowHeadType = edgeDef.sourceArrow ? .arrow : .none
                let targetArrow: original_src_types.ArrowHeadType = edgeDef.targetArrow ? .arrow : .none

                // Handle anonymous source (-- B or -> B without explicit source)
                if source.isEmpty {
                    anonymousCounter += 1
                    source = "__anonymous_\(anonymousCounter)"
                }
                if target.isEmpty {
                    anonymousCounter += 1
                    target = "__anonymous_\(anonymousCounter)"
                }

                let edge = original_src_types.MermaidEdge(
                    source: source,
                    target: target,
                    label: edgeDef.label,
                    style: .solid,
                    arrowHeadStart: sourceArrow,
                    arrowHeadEnd: targetArrow
                )

                edges.append(edge)

            case .containerOpen(let open):
                let subgraph = original_src_types.MermaidSubgraph(
                    id: open.id,
                    label: open.label ?? open.id,
                    nodeIds: []
                )
                subgraphStack.append(subgraph)

            case .containerClose:
                if let closed = subgraphStack.popLast() {
                    // Resolve nodeIds for this subgraph
                    let nodeIds = pendingNodeIds[closed.id] ?? []
                    closed.nodeIds = nodeIds

                    // If there's still a parent, add this as a child
                    if let parent = subgraphStack.last {
                        parent.children.append(closed)
                        // Also merge nodeIds to parent
                        pendingNodeIds[parent.id, default: []].append(contentsOf: nodeIds)
                    } else {
                        subgraphs.append(closed)
                    }
                    pendingNodeIds.removeValue(forKey: closed.id)
                }
            }
        }

        // Check for direction on root-level node definitions
        for stmt in document.statements {
            if case .nodeDefinition(let nd) = stmt, let dir = nd.direction {
                switch dir.lowercased() {
                case "right": direction = .LR
                case "down": direction = .TD
                case "up": direction = .BT
                case "left": direction = .RL
                default: break
                }
            }
        }

        let graph = original_src_types.MermaidGraph(
            direction: direction,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs
        )

        return (graph, diagnostics)
    }
}
