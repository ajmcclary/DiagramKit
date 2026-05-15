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
        _commitDiagnostics(exportResult.diagnostics)
        selection = _selectionAfterMutation(previousSelection: oldSelection, in: newDocument)

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics,
                selection: oldSelection
            )
        }
        undoManager.setActionName(mutation.undoActionName)
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
