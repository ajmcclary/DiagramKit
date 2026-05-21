import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `D2Document` (already family-classified as `block`) to a
/// `BlockDiagram`. D2 containers become composite `BlockNode`s; node
/// definitions become leaf `BlockNode`s. Recovery markers restore
/// information that D2's native vocabulary cannot express:
///
/// - shape fallbacks (`lean_left`, `lean_right`, `trapezoid`,
///   `inv_trapezoid`, `rect_left_inv_arrow`, `block_arrow`)
/// - grid columns + per-cell width spans
/// - `blockArrow` direction sets
/// - `space` cell positions
/// - `BlockEdge` thickness / pattern / arrow attribute variants
/// - `classDef` table + per-node class apply
/// - per-node inline styles
/// - accessibility title + description
public struct D2BlockMapper {

    public init() {}

    public func map(
        _ doc: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (BlockDiagram, [DiagramDiagnostic]) {
        var diagram = BlockDiagram()
        var diagnostics: [DiagramDiagnostic] = []
        var containerStack: [String] = []

        for stmt in doc.statements {
            switch stmt {
            case .containerOpen(let open):
                let node = BlockNode(
                    id: open.id,
                    label: open.label ?? open.id,
                    type: .composite,
                    children: [],
                    columns: -1
                )
                diagram.blockDatabase[open.id] = node
                if let parent = containerStack.last {
                    diagram.blockDatabase[parent]?.children.append(open.id)
                } else {
                    diagram.rootChildren.append(open.id)
                }
                containerStack.append(open.id)

            case .containerClose:
                if !containerStack.isEmpty { containerStack.removeLast() }

            case .nodeDefinition(let nodeDef):
                // Skip `title:` which is the diagram-level metadata
                // emitted by D2BlockExporter, not a real block node.
                if nodeDef.id == "title" { continue }

                if var existing = diagram.blockDatabase[nodeDef.id] {
                    // Subsequent statement for the same id (e.g.
                    // `<id>.shape: …`) — merge in attributes without
                    // re-inserting in the parent's children.
                    if let shape = nodeDef.shape {
                        existing.type = Self.blockType(for: shape)
                    }
                    if let label = nodeDef.label, !label.isEmpty {
                        existing.label = label
                    }
                    diagram.blockDatabase[nodeDef.id] = existing
                    continue
                }

                let type = Self.blockType(for: nodeDef.shape)
                let node = BlockNode(
                    id: nodeDef.id,
                    label: nodeDef.label ?? nodeDef.id,
                    type: type
                )
                diagram.blockDatabase[nodeDef.id] = node
                if let parent = containerStack.last {
                    diagram.blockDatabase[parent]?.children.append(nodeDef.id)
                } else {
                    diagram.rootChildren.append(nodeDef.id)
                }

            case .edgeDefinition(let edgeDef):
                diagram.edges.append(BlockEdge(
                    id: "edge_\(diagram.edges.count)",
                    start: edgeDef.source,
                    end: edgeDef.target,
                    label: edgeDef.label
                ))

            case .direction:
                continue
            }
        }

        Self.applyMarkers(markers: markers, diagram: &diagram, diagnostics: &diagnostics)
        return (diagram, diagnostics)
    }

    // MARK: - Shape mapping

    /// Best-effort native-shape → `BlockNodeType` mapping. The
    /// `blockShapeFallback` marker overrides this on the second pass.
    private static func blockType(for shape: String?) -> BlockNodeType {
        switch shape {
        case nil, "rectangle":   return .square
        case "oval":              return .round
        case "circle":            return .circle
        case "diamond":           return .diamond
        case "hexagon":           return .hexagon
        case "stadium":           return .stadium
        case "package":           return .subroutine
        case "cylinder":          return .cylinder
        case "parallelogram":     return .leanRight
        default:                  return .square
        }
    }

    // MARK: - Marker application

    private static func applyMarkers(
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>],
        diagram: inout BlockDiagram,
        diagnostics: inout [DiagramDiagnostic]
    ) {
        // Pass 1: shape fallbacks first so that subsequent passes can
        // assume the canonical `BlockNodeType` is in place (matters
        // for `blockArrow` direction restoration).
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
                diagram.classes[className] = BlockClassDef(
                    id: className,
                    styles: styles
                )

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
