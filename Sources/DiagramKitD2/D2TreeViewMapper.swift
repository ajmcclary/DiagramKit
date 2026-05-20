import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `D2Document` to a `TreeViewDiagram`. Detection is
/// marker-only (`# diagramkit:family=treeView`); without the marker
/// the document keeps importing as a flowchart since a directed tree
/// alone is structurally indistinguishable from a flowchart-shaped
/// tree.
public struct D2TreeViewMapper {
    public init() {}

    public func map(
        _ doc: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var labels: [String: String] = [:]
        var children: [String: [String]] = [:]
        var allNodes: Set<String> = []
        var hasIncoming: Set<String> = []

        for stmt in doc.statements {
            switch stmt {
            case .nodeDefinition(let n):
                // Only set a label when the statement provides one to
                // avoid an `id.shape: …` follow-up clobbering an
                // earlier `id: "Label"` declaration.
                if let label = n.label {
                    labels[n.id] = label
                } else if labels[n.id] == nil {
                    labels[n.id] = n.id
                }
                allNodes.insert(n.id)
            case .edgeDefinition(let e):
                children[e.source, default: []].append(e.target)
                hasIncoming.insert(e.target)
                allNodes.insert(e.source); allNodes.insert(e.target)
            default: continue
            }
        }

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
