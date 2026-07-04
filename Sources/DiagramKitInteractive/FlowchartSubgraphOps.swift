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

    // MARK: - moveToSubgraph

    static func _removeNodeIDs(
        _ ids: Set<String>,
        from subs: [original_src_types.MermaidSubgraph]
    ) {
        for sub in subs {
            sub.nodeIds.removeAll { ids.contains($0) }
            _removeNodeIDs(ids, from: sub.children)
        }
    }

    func _moveToSubgraph(
        selections: [DiagramSelection],
        target: String?,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        guard !selections.isEmpty else {
            throw DiagramEditorError.invalidSubgraphSelection(reason: "selection is empty")
        }
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        var nodeIDs: [String] = []
        for sel in selections {
            try _validateSelection(sel, matches: document)
            guard sel.elementID.hasPrefix("node:") else {
                throw DiagramEditorError.invalidSubgraphSelection(
                    reason: "selection '\(sel.elementID)' is not a node"
                )
            }
            let id = String(sel.elementID.dropFirst(5))
            guard model.nodesInOrder.contains(where: { $0.id == id }) else {
                throw DiagramEditorError.elementNotFound(id: id, kind: "node")
            }
            nodeIDs.append(id)
        }

        let forest = Self._copySubgraphForest(model.subgraphs)
        if let target, Self._findSubgraph(target, in: forest) == nil {
            throw DiagramEditorError.elementNotFound(id: target, kind: "subgraph")
        }
        Self._removeNodeIDs(Set(nodeIDs), from: forest)
        if let target, let destination = Self._findSubgraph(target, in: forest) {
            destination.nodeIds.append(contentsOf: nodeIDs)
        }
        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return doc
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
