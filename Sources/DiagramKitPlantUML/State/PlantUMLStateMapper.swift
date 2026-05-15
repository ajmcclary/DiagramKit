import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Converts `PlantUMLStateAST` → `ParsedGraphModel` for the
/// `DiagramPayload.stateDiagram` payload.
///
/// `[*]` pseudostates are rewritten to `<parent>_start` / `<parent>_end`
/// with `.stateStart` / `.stateEnd` shapes, mirroring the Mermaid
/// state parser convention so downstream layouts treat them
/// identically.
public struct PlantUMLStateMapper {

    public init() {}

    public func map(_ ast: PlantUMLStateAST) -> (graph: ParsedGraphModel, diagnostics: [DiagramDiagnostic]) {
        var context = MappingContext()
        let rootSubgraphs = walkBlock(ast, parentID: "root", context: &context)

        var graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: context.nodesInOrder,
            edges: context.edges,
            subgraphs: rootSubgraphs
        )
        graph.accTitle = nil
        graph.accDescr = nil

        for line in ast.unsupportedLines {
            context.diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "PlantUML state line not yet supported: \(line)"
            ))
        }

        return (graph, context.diagnostics)
    }

    // MARK: - Mapping context

    private struct MappingContext {
        var nodesInOrder: [(id: String, node: original_src_types.MermaidNode)] = []
        var nodesIndex: [String: Int] = [:]
        var edges: [original_src_types.MermaidEdge] = []
        var diagnostics: [DiagramDiagnostic] = []
        var startCount = 0
        var endCount = 0

        mutating func upsertNode(id: String, label: String, shape: original_src_types.NodeShape) {
            if let existing = nodesIndex[id] {
                // Preserve the existing label if a later occurrence is unlabeled.
                if !label.isEmpty {
                    var node = nodesInOrder[existing].node
                    node.label = label
                    if node.shape == .rectangle || node.shape == .rounded {
                        node.shape = shape
                    }
                    nodesInOrder[existing] = (id: id, node: node)
                }
                return
            }
            let node = original_src_types.MermaidNode(id: id, label: label, shape: shape)
            nodesIndex[id] = nodesInOrder.count
            nodesInOrder.append((id: id, node: node))
        }
    }

    // MARK: - Recursive walk

    private func walkBlock(
        _ ast: PlantUMLStateAST,
        parentID: String,
        context: inout MappingContext
    ) -> [original_src_types.MermaidSubgraph] {
        var subgraphs: [original_src_types.MermaidSubgraph] = []

        // First pass: ensure declared state nodes exist (with labels).
        for decl in ast.states {
            if decl.children == nil {
                context.upsertNode(id: decl.id, label: decl.label, shape: .rounded)
            }
        }

        // Composite states: emit as subgraphs, recurse for nested nodes.
        for decl in ast.states where decl.children != nil {
            // The composite itself isn't a node; it becomes a subgraph.
            let childContextStart = context.nodesInOrder.count
            let nested = walkBlock(
                decl.children!,
                parentID: decl.id,
                context: &context
            )
            let nestedIds = context.nodesInOrder[childContextStart...].map(\.id)
            let subgraph = original_src_types.MermaidSubgraph(
                id: decl.id,
                label: decl.label.isEmpty ? decl.id : decl.label,
                nodeIds: Array(nestedIds),
                children: nested
            )
            subgraphs.append(subgraph)
        }

        // Transitions: rewrite `[*]` → `<parent>_start` / `<parent>_end`.
        for transition in ast.transitions {
            let source = resolveEndpoint(
                transition.source,
                isSource: true,
                parentID: parentID,
                context: &context
            )
            let target = resolveEndpoint(
                transition.target,
                isSource: false,
                parentID: parentID,
                context: &context
            )
            context.edges.append(original_src_types.MermaidEdge(
                source: source,
                target: target,
                label: transition.label,
                style: .solid,
                arrowHeadStart: .none,
                arrowHeadEnd: .arrow
            ))
        }

        return subgraphs
    }

    private func resolveEndpoint(
        _ raw: String,
        isSource: Bool,
        parentID: String,
        context: inout MappingContext
    ) -> String {
        if raw == "[*]" {
            if isSource {
                context.startCount += 1
                let id = "\(parentID)_start"
                context.upsertNode(id: id, label: "", shape: .stateStart)
                return id
            } else {
                context.endCount += 1
                let id = "\(parentID)_end"
                context.upsertNode(id: id, label: "", shape: .stateEnd)
                return id
            }
        }
        // Ensure the node is present even if no explicit `state Name` declared it.
        if context.nodesIndex[raw] == nil {
            context.upsertNode(id: raw, label: "", shape: .rounded)
        }
        return raw
    }
}
