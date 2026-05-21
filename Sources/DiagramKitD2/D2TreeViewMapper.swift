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

        // Branch order matters. Structural multi-root takes precedence over
        // the marker: forest exports emit a tree-root marker pinning the
        // first child as an ordering hint, NOT as a single-root assertion.
        // Honoring `roots.count > 1` first means forest round-trips
        // synthesize the canonical `/` container, and the pre-existing
        // marker-pinned-with-orphans silent-drop bug closes naturally.
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

        // Single-root paths below — byte-identical to pre-Wave-I behavior.
        if let pinned = rootMarker, allNodes.contains(pinned) {
            let root = build(pinned, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }
        if roots.count == 1 {
            let root = build(roots.first!, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }

        // roots.isEmpty: cycles or empty graph — fall back to flowchart.
        diagnostics.append(.featureDropped(
            .slotUnsupported,
            message: "TreeView requires at least one root; found 0. Falling back to flowchart."
        ))
        return (nil, diagnostics)
    }
}
