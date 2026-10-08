// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
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
import DiagramKitCommon
import DiagramKitModel

extension DiagramEditor {

    func _groupIntoSubgraph(
        selections: [DiagramSelection],
        title: String,
        into document: DiagramDocument
    ) throws -> (DiagramDocument, [DiagramDiagnostic]) {
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

        let (subgraphID, diagnostics) = Self.subgraphID(title: title, members: nodeIDs)
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
        return (newDoc, diagnostics)
    }

    /// Deterministic id for a subgraph wrapping `members` titled `title`.
    /// Slug + 8-char hex hash keeps two calls with the same arguments
    /// idempotent and keeps two calls with different members distinct
    /// even when the title collides.
    ///
    /// Returns the resolved id alongside any diagnostics produced
    /// while sanitizing `title` into the slug component. Callers should
    /// surface those diagnostics so the user sees what their title
    /// became.
    static func subgraphID(
        title: String,
        members: [String]
    ) -> (id: String, diagnostics: [DiagramDiagnostic]) {
        let (slug, slugDiagnostics) = slugify(title)
        let hashSeed = (members.sorted() + [title]).joined(separator: "|")
        var hasher = Hasher()
        hasher.combine(hashSeed)
        let raw = UInt(bitPattern: hasher.finalize())
        let hex = String(raw, radix: 16, uppercase: false)
        let suffix = String(hex.suffix(8))
        return ("\(slug)_\(suffix)", slugDiagnostics)
    }

    private static func slugify(_ input: String) -> (slug: String, diagnostics: [DiagramDiagnostic]) {
        let trimmed = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var out = ""
        var droppedAny = false
        for ch in trimmed {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
            } else if ch == " " || ch == "_" || ch == "-" {
                out.append("_")
            } else {
                // drop non-alphanumeric / non-whitespace characters
                droppedAny = true
            }
        }
        let emptied: Bool
        if out.isEmpty {
            out = "subgraph"
            emptied = true
        } else {
            emptied = false
        }

        // Only emit a diagnostic when the slug observably differs from
        // the user's input (ignoring whitespace + case). A pure
        // lowercase + whitespace→underscore mapping is round-trip
        // recoverable and not worth surfacing.
        var diagnostics: [DiagramDiagnostic] = []
        if droppedAny || emptied {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "Subgraph title '\(input)' sanitized to id slug '\(out)'"
            ))
        }
        return (out, diagnostics)
    }
}
#endif
