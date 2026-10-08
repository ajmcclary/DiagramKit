// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model — Slice 9E
// Core mutation implementations (derivation only — no state change).

import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

// MARK: - Mutation application (derivation only)

extension DiagramEditor {

    // MARK: - Public mutation entry points

    /// Perform a core mutation on the document.
    ///
    /// Derives the new document, exports it on a fresh worker thread,
    /// and commits state + undo atomically. Concurrent calls serialize:
    /// each caller awaits the previous mutation's task before starting
    /// its own, so commits land in registration order and each gets its
    /// own undo entry.
    ///
    /// - Parameter mutation: The mutation to apply.
    /// - Throws: `DiagramEditorError` if the mutation cannot be applied
    ///   or source sync fails.
    public func perform(_ mutation: DiagramMutation) async throws {
        _enterMutationChain()
        defer { _exitMutationChain() }

        await _awaitPendingMutation()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self._performInner(mutation)
        }
        let generation = _setPendingMutation(task)
        defer { _clearPendingMutationIfCurrent(generation: generation) }

        try await task.value
    }

    /// Inner commit body. Always runs on `MainActor`. Atomic: a throw
    /// from the worker leaves state untouched.
    func _performInner(_ mutation: DiagramMutation) async throws {
        let newDocument = try _apply(mutation, to: document)
        try await _commitMutation(
            newDocument: newDocument,
            actionName: mutation.undoActionName,
            updateSelection: { [self] previous, document in
                _selectionAfterMutation(previousSelection: previous, in: document)
            }
        )
    }

    /// Shared transaction: exports `newDocument`, snapshots the current
    /// state, commits the new document/source/diagnostics (optionally
    /// updating selection), and registers an undo entry. Atomic — a
    /// throw from `_exportAsync` propagates with no state change. The
    /// family-specific `_performXInner` methods all funnel here so the
    /// commit sequence, diagnostic layering, and undo registration stay
    /// in one place.
    func _commitMutation(
        newDocument: DiagramDocument,
        mutationDiagnostics: [DiagramDiagnostic] = [],
        actionName: String,
        updateSelection: ((_ previous: DiagramSelection?, _ in: DiagramDocument) -> DiagramSelection?)? = nil
    ) async throws {
        let exportResult: DiagramExportResult
        do {
            exportResult = try await _exportAsync(newDocument)
        } catch {
            throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
        }

        let oldDocument = document
        let oldSource = source
        let oldDiagnostics = lastExportDiagnostics
        let oldSelection = selection

        _commitDocument(newDocument)
        _commitSource(exportResult.source)
        _commitDiagnostics(mutationDiagnostics + exportResult.diagnostics)
        if let updateSelection {
            selection = updateSelection(oldSelection, newDocument)
        }

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics,
                selection: oldSelection
            )
        }
        undoManager.setActionName(actionName)
    }

    private func _selectionAfterMutation(
        previousSelection: DiagramSelection?,
        in document: DiagramDocument
    ) -> DiagramSelection? {
        guard let previousSelection else { return nil }
        guard previousSelection.diagramType == document.type else { return nil }
        return _selectionExists(previousSelection, in: document) ? previousSelection : nil
    }

    private func _selectionExists(
        _ selection: DiagramSelection,
        in document: DiagramDocument
    ) -> Bool {
        switch document.payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            let id = selection.elementID
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                return graph.nodesInOrder.contains { $0.id == nodeID }
            }
            if id.hasPrefix("edge:") {
                return _findEdge(in: graph, selectionElementID: id) != nil
            }
            return false
        default:
            return true
        }
    }

    // MARK: - Internal derivation methods

    func _apply(
        _ mutation: DiagramMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .deleteElement(let selection):
            return try _deleteElement(selection, from: document)
        case .setLabel(let selection, let label):
            return try _setLabel(of: selection, to: label, in: document)
        case .setTitle(let title):
            return _setTitle(title, in: document)
        case .noop:
            return document
        case .setTheme(let name):
            return try _setTheme(name, in: document)
        case .setLayoutPreset(let preset):
            return _setLayoutPreset(preset, in: document)
        }
    }

    // MARK: - Flow-graph payload helper

    /// Apply `body` to the `MermaidGraph` inside a `.flowchart` or
    /// `.stateDiagram` payload. Throws `.unsupportedMutation` for any
    /// other payload. The body's throws propagate unchanged.
    private func _withFlowGraphPayload(
        in document: inout DiagramDocument,
        mutation: String,
        body: (inout original_src_types.MermaidGraph) throws -> Void
    ) throws {
        switch document.payload {
        case .flowchart(var graph):
            try body(&graph)
            document.payload = .flowchart(graph)
        case .stateDiagram(var graph):
            try body(&graph)
            document.payload = .stateDiagram(graph)
        default:
            throw DiagramEditorError.unsupportedMutation(
                mutation: mutation,
                diagramType: String(describing: document.type)
            )
        }
    }

    // MARK: - Core mutation implementations

    func _deleteElement(
        _ selection: DiagramSelection, from document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        let id = selection.elementID
        try _withFlowGraphPayload(in: &doc, mutation: "deleteElement") { graph in
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard graph.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                graph.nodesInOrder.removeAll { $0.id == nodeID }
                graph.edges.removeAll { $0.source == nodeID || $0.target == nodeID }
            } else if id.hasPrefix("edge:") {
                guard let index = _findEdge(in: graph, selectionElementID: id) else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                graph.edges.remove(at: index)
            } else if id.hasPrefix("group:") {
                let groupID = String(id.dropFirst(6))
                var forest = Self._copySubgraphForest(graph.subgraphs)
                guard let removed = Self._extractSubgraph(groupID, from: &forest) else {
                    throw DiagramEditorError.elementNotFound(id: groupID, kind: "subgraph")
                }
                let memberIDs = Self._allMemberNodeIDs(in: removed)
                graph.subgraphs = forest
                graph.nodesInOrder.removeAll { memberIDs.contains($0.id) }
                graph.edges.removeAll {
                    memberIDs.contains($0.source) || memberIDs.contains($0.target)
                }
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
        }
        return doc
    }

    func _setLabel(
        of selection: DiagramSelection, to label: String, in document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        let id = selection.elementID
        try _withFlowGraphPayload(in: &doc, mutation: "setLabel") { graph in
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard graph.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                graph.nodesInOrder = graph.nodesInOrder.map { entry in
                    if entry.id == nodeID {
                        var node = entry.node
                        node.label = label
                        return (id: entry.id, node: node)
                    }
                    return entry
                }
            } else if id.hasPrefix("edge:") {
                guard let index = _findEdge(in: graph, selectionElementID: id) else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                graph.edges[index].label = label
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
        }
        return doc
    }

    func _setTitle(_ title: String?, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        doc.title = title
        return doc
    }

    func _setTheme(_ name: String?, in document: DiagramDocument) throws -> DiagramDocument {
        if let name, DiagramTheme.theme(named: name) == nil {
            throw DiagramEditorError.unknownThemeName(name: name)
        }
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.theme = name
        doc.frontmatter = fm.isEmpty ? nil : fm
        return doc
    }

    func _setLayoutPreset(_ preset: LayoutPreset, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.layout = preset == .adaptive ? LayoutPreset.adaptive.rawValue : nil
        doc.frontmatter = fm.isEmpty ? nil : fm
        return doc
    }

    // MARK: - Edge matching helpers

    /// Find the index of an edge matching the selection element ID.
    func _findEdge(
        in model: original_src_types.MermaidGraph,
        selectionElementID: String
    ) -> Int? {
        var counts: [String: Int] = [:]
        for (index, edge) in model.edges.enumerated() {
            let base = _guaranteedEdgeID(for: edge)
            let count = counts[base, default: 0]
            counts[base] = count + 1

            let stableID = count > 0 ? "\(base)/\(count)" : base
            if stableID == selectionElementID {
                return index
            }
        }
        return nil
    }

    /// Compute the guaranteed stable edge ID (matches PositionedEdge.stableElementID).
    /// Delegates to the single source-of-truth helper in DiagramKitModel so
    /// the bounds-lookup and editor paths cannot drift.
    func _guaranteedEdgeID(for edge: original_src_types.MermaidEdge) -> String {
        _guaranteedDiagramEdgeID(
            id: edge.id,
            source: edge.source,
            target: edge.target,
            label: edge.label
        )
    }

    func _validateSelection(
        _ selection: DiagramSelection,
        matches document: DiagramDocument
    ) throws {
        guard selection.diagramType == document.type else {
            throw DiagramEditorError.selectionTypeMismatch(
                selection: selection.diagramType,
                document: document.type
            )
        }
    }
}
#endif
