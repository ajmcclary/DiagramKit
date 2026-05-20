import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `DOTDocument` to a `MindmapDiagram`. Detection is
/// marker-only (`# diagramkit:family=mindmap`) since a directed tree
/// is structurally identical to a flowchart-shaped tree.
public struct DOTMindmapMapper {
    public init() {}

    public func map(
        _ doc: DOTDocument,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) -> (MindmapDiagram?, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var labels: [String: String] = [:]
        var shapes: [String: String] = [:]
        var styles: [String: String] = [:]
        var children: [String: [String]] = [:]
        var allNodes: Set<String> = []
        var hasIncoming: Set<String> = []

        func walk(_ statements: [DOTStatement]) {
            for stmt in statements {
                switch stmt {
                case .nodeStatement(let n):
                    let attr: (String) -> String? = { key in
                        n.attributes.first(where: { $0.key == key })?.value
                    }
                    labels[n.id] = attr("label") ?? n.id
                    if let s = attr("shape") { shapes[n.id] = s }
                    if let s = attr("style") { styles[n.id] = s }
                    allNodes.insert(n.id)
                case .edgeStatement(let e):
                    children[e.source, default: []].append(e.target)
                    hasIncoming.insert(e.target)
                    allNodes.insert(e.source); allNodes.insert(e.target)
                case .subgraph(let sub):
                    walk(sub.statements)
                default:
                    continue
                }
            }
        }
        walk(doc.statements)

        var rootMarker: String? = nil
        var iconMarkers: [String: String] = [:]
        for marker in markers {
            switch marker.kind {
            case .treeRoot(let id): rootMarker = id
            case .mindmapIcon(let id, let key): iconMarkers[id] = key
            default: continue
            }
        }
        let roots = allNodes.subtracting(hasIncoming)
        let rootID: String
        if let pinned = rootMarker, allNodes.contains(pinned) { rootID = pinned }
        else if roots.count == 1 { rootID = roots.first! }
        else {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "Mindmap requires a single root; found \(roots.count). Falling back to flowchart."
            ))
            return (nil, diagnostics)
        }

        var allBuilt: [MindmapNode] = []
        var nextID = 0
        func build(_ id: String, level: Int, isRoot: Bool) -> MindmapNode {
            let nodeType = Self.mindmapNodeType(
                dotShape: shapes[id],
                dotStyle: styles[id],
                iconKey: iconMarkers[id]
            )
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

    private static func mindmapNodeType(
        dotShape: String?,
        dotStyle: String?,
        iconKey: String?
    ) -> MindmapNodeType {
        if let key = iconKey {
            switch key {
            case "bang": return .bang
            case "cloud": return .cloud
            case "rounded-rect": return .roundedRect
            case "rect": return .rect
            case "circle": return .circle
            case "hexagon": return .hexagon
            default: break
            }
        }
        switch (dotShape, dotStyle) {
        case ("box", "rounded"): return .roundedRect
        case ("box", _):         return .rect
        case ("circle", _):      return .circle
        case ("hexagon", _):     return .hexagon
        case ("oval", "dashed"): return .cloud
        case ("oval", _):        return .default
        default:                 return .default
        }
    }
}
