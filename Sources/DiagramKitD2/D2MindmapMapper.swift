import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `D2Document` to a `MindmapDiagram`. Detection is
/// marker-only (`# diagramkit:family=mindmap`) since a directed tree
/// is also a valid flowchart shape; without a marker the document
/// keeps importing as a flowchart.
///
/// `D2MindmapMapper.map` returns `nil` for the mindmap when the
/// document has zero or multiple roots and no `tree-root` marker —
/// the importer falls back to flowchart in that case.
public struct D2MindmapMapper {
    public init() {}

    public func map(
        _ doc: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (MindmapDiagram?, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var labels: [String: String] = [:]
        var shapes: [String: String] = [:]
        var children: [String: [String]] = [:]
        var allNodes: Set<String> = []
        var hasIncoming: Set<String> = []

        for stmt in doc.statements {
            switch stmt {
            case .nodeDefinition(let nodeDef):
                // Only set a label when the statement actually provides
                // one — D2 sources commonly use a separate `id.shape: …`
                // statement that has no label and would otherwise
                // overwrite a previous `id: "Label"` declaration.
                if let label = nodeDef.label {
                    labels[nodeDef.id] = label
                } else if labels[nodeDef.id] == nil {
                    labels[nodeDef.id] = nodeDef.id
                }
                if let s = nodeDef.shape { shapes[nodeDef.id] = s }
                allNodes.insert(nodeDef.id)
            case .edgeDefinition(let edgeDef):
                children[edgeDef.source, default: []].append(edgeDef.target)
                hasIncoming.insert(edgeDef.target)
                allNodes.insert(edgeDef.source)
                allNodes.insert(edgeDef.target)
            default:
                continue
            }
        }

        var rootMarker: String? = nil
        var iconMarkers: [String: String] = [:]
        for marker in markers {
            switch marker.kind {
            case .treeRoot(let id):
                rootMarker = id
            case .mindmapIcon(let id, let key):
                iconMarkers[id] = key
            default:
                continue
            }
        }
        let roots = allNodes.subtracting(hasIncoming)
        let rootID: String
        if let pinned = rootMarker, allNodes.contains(pinned) {
            rootID = pinned
        } else if roots.count == 1 {
            rootID = roots.first!
        } else {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "Mindmap requires a single root; found \(roots.count). Falling back to flowchart."
            ))
            return (nil, diagnostics)
        }

        var allBuilt: [MindmapNode] = []
        var nextID = 0
        func build(_ id: String, level: Int, isRoot: Bool) -> MindmapNode {
            let nodeType = Self.mindmapNodeType(d2Shape: shapes[id], iconKey: iconMarkers[id])
            let assigned = nextID; nextID += 1
            let kids = (children[id] ?? []).map { build($0, level: level + 1, isRoot: false) }
            let node = MindmapNode(
                id: assigned,
                nodeId: id,
                level: level,
                descr: labels[id] ?? id,
                type: nodeType,
                children: kids,
                isRoot: isRoot
            )
            allBuilt.append(node)
            return node
        }
        let root = build(rootID, level: 0, isRoot: true)

        return (MindmapDiagram(root: root, nodes: allBuilt), diagnostics)
    }

    private static func mindmapNodeType(d2Shape: String?, iconKey: String?) -> MindmapNodeType {
        if let key = iconKey {
            switch key {
            case "bang":         return .bang
            case "cloud":        return .cloud
            case "rounded-rect": return .roundedRect
            case "rect":         return .rect
            case "circle":       return .circle
            case "hexagon":      return .hexagon
            case "no-border", "default": return .default
            default: break
            }
        }
        switch d2Shape {
        case "rectangle": return .rect
        case "circle":    return .circle
        case "cloud":     return .cloud
        case "hexagon":   return .hexagon
        default:          return .default
        }
    }
}
