import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `DOTDocument` to a `TreeViewDiagram`. Detection is
/// marker-only.
public struct DOTTreeViewMapper {
    public init() {}

    public func map(
        _ doc: DOTDocument,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var labels: [String: String] = [:]
        var children: [String: [String]] = [:]
        var allNodes: Set<String> = []
        var hasIncoming: Set<String> = []

        func walk(_ statements: [DOTStatement]) {
            for stmt in statements {
                switch stmt {
                case .nodeStatement(let n):
                    let label = n.attributes.first(where: { $0.key == "label" })?.value
                    if let label {
                        labels[n.id] = label
                    } else if labels[n.id] == nil {
                        labels[n.id] = n.id
                    }
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
        for marker in markers {
            if case .treeRoot(let id) = marker.kind { rootMarker = id }
        }
        let roots = allNodes.subtracting(hasIncoming)
        let rootID: String
        if let pinned = rootMarker, allNodes.contains(pinned) { rootID = pinned }
        else if roots.count == 1 { rootID = roots.first! }
        else {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "TreeView requires a single root; found \(roots.count). Falling back to flowchart."
            ))
            return (nil, diagnostics)
        }

        var allBuilt: [TreeViewNode] = []
        var nextID = 0
        func build(_ id: String, level: Int) -> TreeViewNode {
            let kidIDs = children[id] ?? []
            let assigned = nextID; nextID += 1
            let kids = kidIDs.map { build($0, level: level + 1) }
            let node = TreeViewNode(
                id: assigned,
                level: level,
                name: labels[id] ?? id,
                nodeType: kids.isEmpty ? .file : .directory,
                children: kids
            )
            allBuilt.append(node)
            return node
        }
        let root = build(rootID, level: 0)
        return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
    }
}
