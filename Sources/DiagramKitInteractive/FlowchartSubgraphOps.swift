// Visual editor plan 3 — subgraph forest mutations.
//
// CONCURRENCY / UNDO NOTE: `MermaidSubgraph` is a mutable final class.
// Undo snapshots hold references to the same instances, so every
// mutation here deep-copies the forest first (`_copySubgraphForest`)
// and mutates only the copies. Mutating a subgraph in place would
// silently corrupt every snapshot on the undo stack.

import DiagramKitCommon
import DiagramKitModel

extension DiagramEditor {

    // MARK: - Forest helpers

    static func _copySubgraphForest(
        _ subs: [original_src_types.MermaidSubgraph]
    ) -> [original_src_types.MermaidSubgraph] {
        subs.map { sub in
            original_src_types.MermaidSubgraph(
                id: sub.id,
                label: sub.label,
                nodeIds: sub.nodeIds,
                children: _copySubgraphForest(sub.children),
                direction: sub.direction,
                shape: sub.shape,
                altBkg: sub.altBkg
            )
        }
    }

    static func _findSubgraph(
        _ id: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> original_src_types.MermaidSubgraph? {
        for sub in subs {
            if sub.id == id { return sub }
            if let hit = _findSubgraph(id, in: sub.children) { return hit }
        }
        return nil
    }

    // MARK: - insertSubgraph

    func _insertSubgraph(
        title: String,
        into document: DiagramDocument
    ) throws -> (DiagramDocument, [DiagramDiagnostic]) {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        var (id, diagnostics) = Self.subgraphID(title: title, members: [])
        var salt = 1
        while Self._findSubgraph(id, in: model.subgraphs) != nil {
            (id, _) = Self.subgraphID(title: title, members: ["salt:\(salt)"])
            salt += 1
        }
        var forest = Self._copySubgraphForest(model.subgraphs)
        forest.append(original_src_types.MermaidSubgraph(id: id, label: title, nodeIds: []))
        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return (doc, diagnostics)
    }
}
