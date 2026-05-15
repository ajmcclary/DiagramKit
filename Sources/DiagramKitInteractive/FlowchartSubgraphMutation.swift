// Phase 5 / Task 5.1 — applier for FlowchartMutation.groupIntoSubgraph.
//
// Wraps the named nodes in a fresh `MermaidSubgraph` whose id is
// derived from a slug of the title and a stable hash of the sorted
// member ids, so the same call against the same nodes always
// produces the same subgraph id.
//
// The inverse ("flatten") is handled by DiagramEditor's snapshot-undo
// mechanism — registerUndo restores the prior document, source,
// diagnostics, and selection in a single hop.

import Foundation
import DiagramKitModel

extension DiagramEditor {

    func _groupIntoSubgraph(
        selections: [DiagramSelection],
        title: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        guard !selections.isEmpty else {
            throw DiagramEditorError.invalidSubgraphSelection(reason: "selection is empty")
        }
        guard case .flowchart(var model) = document.payload else {
            throw DiagramEditorError.notAFlowchart
        }

        // Each selection must be a flowchart node (elementID prefixed
        // with "node:") and must reference a known node id.
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

        let subgraphID = Self.subgraphID(title: title, members: nodeIDs)
        guard !model.subgraphs.contains(where: { $0.id == subgraphID }) else {
            throw DiagramEditorError.invalidSubgraphSelection(
                reason: "a subgraph with id '\(subgraphID)' already exists"
            )
        }

        let subgraph = original_src_types.MermaidSubgraph(
            id: subgraphID,
            label: title,
            nodeIds: nodeIDs
        )
        model.subgraphs.append(subgraph)

        var newDoc = document
        newDoc.payload = .flowchart(model)
        return newDoc
    }

    /// Deterministic id for a subgraph wrapping `members` titled `title`.
    /// Slug + 8-char hex hash keeps two calls with the same arguments
    /// idempotent and keeps two calls with different members distinct
    /// even when the title collides.
    static func subgraphID(title: String, members: [String]) -> String {
        let slug = slugify(title)
        let hashSeed = (members.sorted() + [title]).joined(separator: "|")
        var hasher = Hasher()
        hasher.combine(hashSeed)
        let raw = UInt(bitPattern: hasher.finalize())
        let hex = String(raw, radix: 16, uppercase: false)
        let suffix = String(hex.suffix(8))
        return "\(slug)_\(suffix)"
    }

    private static func slugify(_ input: String) -> String {
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ""
        for ch in trimmed {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else if ch == " " || ch == "_" || ch == "-" {
                out.append("_")
            }
            // drop everything else
        }
        if out.isEmpty {
            out = "subgraph"
        }
        return out
    }
}
