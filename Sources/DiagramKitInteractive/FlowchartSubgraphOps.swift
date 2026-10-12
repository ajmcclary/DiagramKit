// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
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
    ) -> [original_src_types.MermaidSubgraph] {
        subs.map { sub in
            var mutated = sub
            mutated.nodeIds.removeAll { ids.contains($0) }
            mutated.children = _removeNodeIDs(ids, from: sub.children)
            return mutated
        }
    }

    static func _appendNodeIDs(
        _ ids: [String],
        toSubgraphID target: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> [original_src_types.MermaidSubgraph] {
        subs.map { sub in
            var mutated = sub
            if sub.id == target {
                mutated.nodeIds.append(contentsOf: ids)
            }
            mutated.children = _appendNodeIDs(ids, toSubgraphID: target, in: sub.children)
            return mutated
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
        var nextForest = Self._removeNodeIDs(Set(nodeIDs), from: forest)
        if let target {
            nextForest = Self._appendNodeIDs(nodeIDs, toSubgraphID: target, in: nextForest)
        }
        model.subgraphs = nextForest
        doc.payload = .flowchart(model)
        return doc
    }

    // MARK: - ungroupSubgraph

    /// Recursively ungroup the subgraph with `id`.
    ///
    /// - Root-level target: removed and replaced by its children; its own
    ///   `nodeIds` lose group membership (they remain in `nodesInOrder`).
    /// - Nested target: removed and replaced by its children inside its parent,
    ///   and its `nodeIds` are appended to the parent’s `nodeIds`.
    static func _ungroupSubgraph(
        id: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> [original_src_types.MermaidSubgraph] {
        var result: [original_src_types.MermaidSubgraph] = []
        for sub in subs {
            if sub.id == id {
                // Root-level: promote children; member nodes become ungrouped.
                result.append(contentsOf: sub.children)
            } else if let promoted = Self._replaceSubgraphWithChildren(id: id, in: sub.children) {
                var mutated = sub
                mutated.children = promoted.children
                mutated.nodeIds.append(contentsOf: promoted.nodeIds)
                result.append(mutated)
            } else {
                var mutated = sub
                mutated.children = _ungroupSubgraph(id: id, in: sub.children)
                result.append(mutated)
            }
        }
        return result
    }

    /// If `id` is a direct child of `subs`, replace it with its children and
    /// return the new child list plus the removed subgraph’s `nodeIds`.
    /// Otherwise recurse; when found deeper, apply the promotion to the
    /// ancestor and return the updated subtree.
    static func _replaceSubgraphWithChildren(
        id: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> (children: [original_src_types.MermaidSubgraph], nodeIds: [String])? {
        if let idx = subs.firstIndex(where: { $0.id == id }) {
            let sub = subs[idx]
            var newChildren = subs
            newChildren.remove(at: idx)
            newChildren.insert(contentsOf: sub.children, at: idx)
            return (newChildren, sub.nodeIds)
        }

        var result: [original_src_types.MermaidSubgraph] = []
        var found: Bool = false
        for sub in subs {
            if found {
                var mutated = sub
                mutated.children = _ungroupSubgraph(id: id, in: sub.children)
                result.append(mutated)
            } else if let promoted = Self._replaceSubgraphWithChildren(id: id, in: sub.children) {
                var mutated = sub
                mutated.children = promoted.children
                mutated.nodeIds.append(contentsOf: promoted.nodeIds)
                result.append(mutated)
                found = true
            } else {
                result.append(sub)
            }
        }
        return found ? (result, []) : nil
    }

    func _ungroupSubgraph(
        id: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        let forest = Self._copySubgraphForest(model.subgraphs)
        let present = forest.contains { $0.id == id } || forest.contains {
            Self._findSubgraph(id, in: $0.children) != nil
        }
        guard present else {
            throw DiagramEditorError.elementNotFound(id: id, kind: "subgraph")
        }
        model.subgraphs = Self._ungroupSubgraph(id: id, in: forest)
        doc.payload = .flowchart(model)
        return doc
    }

    // MARK: - renameSubgraph

    static func _renameSubgraph(
        id: String,
        to title: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> [original_src_types.MermaidSubgraph] {
        subs.map { sub in
            var mutated = sub
            if sub.id == id {
                mutated.label = title
            }
            mutated.children = _renameSubgraph(id: id, to: title, in: sub.children)
            return mutated
        }
    }

    func _renameSubgraph(
        id: String,
        title: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        let forest = Self._copySubgraphForest(model.subgraphs)
        guard Self._findSubgraph(id, in: forest) != nil else {
            throw DiagramEditorError.elementNotFound(id: id, kind: "subgraph")
        }
        model.subgraphs = Self._renameSubgraph(id: id, to: title, in: forest)
        doc.payload = .flowchart(model)
        return doc
    }

    // MARK: - Group deletion support

    /// Remove and return the subgraph with `id` from a (copied)
    /// forest, searching recursively. Returns nil when absent.
    static func _extractSubgraph(
        _ id: String,
        from subs: [original_src_types.MermaidSubgraph]
    ) -> (forest: [original_src_types.MermaidSubgraph], extracted: original_src_types.MermaidSubgraph?) {
        var result: [original_src_types.MermaidSubgraph] = []
        var extracted: original_src_types.MermaidSubgraph?
        for sub in subs {
            if extracted != nil {
                var mutated = sub
                mutated.children = Self._extractSubgraph(id, from: sub.children).forest
                result.append(mutated)
            } else if sub.id == id {
                extracted = sub
            } else {
                let (children, childExtracted) = Self._extractSubgraph(id, from: sub.children)
                var mutated = sub
                mutated.children = children
                result.append(mutated)
                extracted = childExtracted
            }
        }
        return (result, extracted)
    }

    /// All node ids transitively contained in `sub` (its own plus
    /// every descendant subgraph's).
    static func _allMemberNodeIDs(in sub: original_src_types.MermaidSubgraph) -> Set<String> {
        var ids = Set(sub.nodeIds)
        for child in sub.children {
            ids.formUnion(_allMemberNodeIDs(in: child))
        }
        return ids
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
#endif
