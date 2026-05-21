import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `DOTDocument` (already family-classified as `block`) to a
/// `BlockDiagram`. DOT clusters (`subgraph cluster_<id>`) become
/// composite `BlockNode`s with the `cluster_` prefix stripped from
/// the id. Top-level + cluster-internal node statements become leaf
/// `BlockNode`s. Recovery markers restore information that DOT's
/// vocabulary cannot express (grid columns / spans, block shape
/// kinds, blockArrow directions, space cells, edge attribute
/// variants, classDef/class apply, inline styles, acc title/descr).
public struct DOTBlockMapper {

    public init() {}

    public func map(
        _ doc: DOTDocument,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) -> (BlockDiagram, [DiagramDiagnostic]) {
        var diagram = BlockDiagram()
        var diagnostics: [DiagramDiagnostic] = []

        walk(
            statements: doc.statements,
            parentID: nil,
            diagram: &diagram
        )

        Self.applyMarkers(markers: markers, diagram: &diagram, diagnostics: &diagnostics)
        return (diagram, diagnostics)
    }

    // MARK: - Walk

    private func walk(
        statements: [DOTStatement],
        parentID: String?,
        diagram: inout BlockDiagram
    ) {
        for stmt in statements {
            switch stmt {
            case .nodeStatement(let n):
                // Skip ranks: rank=same subgraphs are flat and have no
                // node statements at this layer; node statements always
                // represent real diagram nodes.
                let shape = n.attributes.first(where: { $0.key == "shape" })?.value
                let label = n.attributes.first(where: { $0.key == "label" })?.value
                let type = Self.blockType(for: shape)
                diagram.blockDatabase[n.id] = BlockNode(
                    id: n.id,
                    label: label ?? n.id,
                    type: type
                )
                if let parent = parentID {
                    diagram.blockDatabase[parent]?.children.append(n.id)
                } else {
                    diagram.rootChildren.append(n.id)
                }

            case .edgeStatement(let e):
                diagram.edges.append(BlockEdge(
                    id: "edge_\(diagram.edges.count)",
                    start: e.source,
                    end: e.target,
                    label: e.label
                ))

            case .subgraph(let sub):
                if let rawID = sub.id, sub.isCluster {
                    // Strip the `cluster_` prefix; that's a DOT
                    // convention, not part of the diagram identity.
                    let id = String(rawID.dropFirst("cluster_".count))
                    // Lift any graph-attr label inside the subgraph.
                    let label = sub.statements.compactMap { stmt -> String? in
                        if case .graphAttr(let k, let v) = stmt, k == "label" {
                            return v
                        }
                        return nil
                    }.first ?? id
                    diagram.blockDatabase[id] = BlockNode(
                        id: id,
                        label: label,
                        type: .composite,
                        children: [],
                        columns: -1
                    )
                    if let parent = parentID {
                        diagram.blockDatabase[parent]?.children.append(id)
                    } else {
                        diagram.rootChildren.append(id)
                    }
                    walk(statements: sub.statements, parentID: id, diagram: &diagram)
                } else {
                    // Anonymous or rank=same subgraph — walk through
                    // its statements at the current level.
                    walk(statements: sub.statements, parentID: parentID, diagram: &diagram)
                }

            case .attrStatement, .graphAttr:
                continue
            }
        }
    }

    // MARK: - Shape mapping

    /// DOT-native-shape → `BlockNodeType` mapping. The
    /// `blockShapeFallback` marker overrides this on the second pass.
    private static func blockType(for shape: String?) -> BlockNodeType {
        switch shape {
        case nil, "box":          return .square
        case "ellipse":            return .round
        case "circle":             return .circle
        case "doublecircle":       return .doublecircle
        case "diamond":            return .diamond
        case "hexagon":            return .hexagon
        case "cylinder":           return .cylinder
        case "box3d":              return .subroutine
        case "parallelogram":      return .leanRight
        case "trapezium":          return .trapezoid
        case "invtrapezium":       return .invTrapezoid
        default:                   return .square
        }
    }

    // MARK: - Marker application

    private static func applyMarkers(
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>],
        diagram: inout BlockDiagram,
        diagnostics: inout [DiagramDiagnostic]
    ) {
        // Pass 1: shape fallbacks.
        for marker in markers {
            guard case .blockShapeFallback(let id, let raw) = marker.kind else { continue }
            guard let restored = BlockNodeType(rawValue: raw) else { continue }
            diagram.blockDatabase[id]?.type = restored
        }

        // Pass 2: everything else.
        for marker in markers {
            switch marker.kind {
            case .blockCols(let containerID, let n):
                diagram.blockDatabase[containerID]?.columns = n

            case .blockWidth(let id, let span):
                diagram.blockDatabase[id]?.widthInColumns = span

            case .blockArrowDir(let id, let csv):
                let dirs = csv.split(separator: ",")
                    .compactMap { BlockDirection(rawValue: String($0)) }
                diagram.blockDatabase[id]?.directions = dirs

            case .blockSpace(let parentID, let columnIndex):
                let spaceID = "space_\(parentID)_\(columnIndex)"
                diagram.blockDatabase[spaceID] = BlockNode(id: spaceID, type: .space)
                if parentID == "root" || parentID.isEmpty {
                    insertAt(&diagram.rootChildren, id: spaceID, at: columnIndex)
                } else if diagram.blockDatabase[parentID] != nil {
                    insertAt(&diagram.blockDatabase[parentID]!.children, id: spaceID, at: columnIndex)
                }

            case .blockEdgeAttrs(let idx, let thickness, let pattern, let arrowStart, let arrowEnd):
                guard idx >= 0, idx < diagram.edges.count else { continue }
                diagram.edges[idx].thickness = thickness
                diagram.edges[idx].pattern = pattern
                diagram.edges[idx].arrowTypeStart = arrowStart
                diagram.edges[idx].arrowTypeEnd = arrowEnd

            case .blockClassDef(let className, let stylesCsv):
                let styles = stylesCsv.split(separator: ";").map(String.init)
                diagram.classes[className] = BlockClassDef(id: className, styles: styles)

            case .blockClassApply(let nodeID, let className):
                if diagram.blockDatabase[nodeID] != nil {
                    var classes = diagram.blockDatabase[nodeID]?.classes ?? []
                    if !classes.contains(className) {
                        classes.append(className)
                    }
                    diagram.blockDatabase[nodeID]?.classes = classes
                }

            case .blockStyle(let nodeID, let stylesCsv):
                let styles = stylesCsv.split(separator: ";").map(String.init)
                diagram.blockDatabase[nodeID]?.styles = styles

            case .blockAccTitle(let text):
                diagram.accTitle = text

            case .blockAccDescr(let text):
                diagram.accDescr = text

            default:
                continue
            }
        }
    }

    private static func insertAt(_ children: inout [String], id: String, at index: Int) {
        if index <= 0 {
            children.insert(id, at: 0)
        } else if index >= children.count {
            children.append(id)
        } else {
            children.insert(id, at: index)
        }
    }
}
