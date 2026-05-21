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

        // Branch order matters. See D2TreeViewMapper for rationale; this
        // is the parallel implementation for DOT.
        if roots.count > 1 {
            var orderedRoots = roots.sorted()
            if let pinned = rootMarker,
               roots.contains(pinned),
               let idx = orderedRoots.firstIndex(of: pinned) {
                orderedRoots.remove(at: idx)
                orderedRoots.insert(pinned, at: 0)
            }
            let synthChildren = orderedRoots.map { build($0, level: 0) }
            let syntheticRoot = TreeViewNode(
                id: nextID, level: -1, name: "/", nodeType: .directory,
                children: synthChildren
            )
            nextID += 1
            allBuilt.append(syntheticRoot)
            return (TreeViewDiagram(root: syntheticRoot, nodes: allBuilt), diagnostics)
        }

        if let pinned = rootMarker, allNodes.contains(pinned) {
            let root = build(pinned, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }
        if roots.count == 1 {
            let root = build(roots.first!, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }

        diagnostics.append(.featureDropped(
            .slotUnsupported,
            message: "TreeView requires at least one root; found 0. Falling back to flowchart."
        ))
        return (nil, diagnostics)
    }
}
