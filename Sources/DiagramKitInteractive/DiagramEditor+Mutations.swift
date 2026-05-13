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
    /// Derives the new document from the mutation, exports it through
    /// `preferredExportFormat`, and only then commits state and registers
    /// an undo action. If derivation or export throws, no state changes.
    ///
    /// - Parameter mutation: The mutation to apply.
    /// - Throws: `DiagramEditorError` if the mutation cannot be applied
    ///   or source sync fails.
    public func perform(_ mutation: DiagramMutation) throws {
        // 1. Derive new document
        let newDocument = try _apply(mutation, to: document)

        // 2. Export to validate source round-trip
        let exportResult: DiagramExportResult
        do {
            exportResult = try _export(newDocument)
        } catch {
            throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
        }

        // 3. Commit: capture old state → swap → register undo
        let oldDocument = document
        let oldSource = source
        let oldDiagnostics = lastExportDiagnostics

        _commitDocument(newDocument)
        _commitSource(exportResult.source)
        _commitDiagnostics(exportResult.diagnostics)

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics
            )
        }
        undoManager.setActionName(mutation.undoActionName)
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

    // MARK: - Core mutation implementations

    func _deleteElement(
        _ selection: DiagramSelection, from document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        let id = selection.elementID
        switch doc.payload {
        case .flowchart(var model):
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                model.nodesInOrder.removeAll { $0.id == nodeID }
                model.edges.removeAll { $0.source == nodeID || $0.target == nodeID }
            } else if id.hasPrefix("edge:") {
                let edgeID = String(id.dropFirst(5))
                let matched = model.edges.contains { edge in
                    _edgeMatches(selectionElementID: id, candidateElementID: edge.id, edge: edge)
                }
                guard matched else {
                    throw DiagramEditorError.elementNotFound(id: edgeID, kind: "edge")
                }
                model.edges.removeAll { edge in
                    _edgeMatches(selectionElementID: id, candidateElementID: edge.id, edge: edge)
                }
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
            doc.payload = .flowchart(model)
        case .stateDiagram(var model):
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                model.nodesInOrder.removeAll { $0.id == nodeID }
                model.edges.removeAll { $0.source == nodeID || $0.target == nodeID }
            } else if id.hasPrefix("edge:") {
                let edgeID = String(id.dropFirst(5))
                let matched = model.edges.contains { edge in
                    _edgeMatches(selectionElementID: id, candidateElementID: edge.id, edge: edge)
                }
                guard matched else {
                    throw DiagramEditorError.elementNotFound(id: edgeID, kind: "edge")
                }
                model.edges.removeAll { edge in
                    _edgeMatches(selectionElementID: id, candidateElementID: edge.id, edge: edge)
                }
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
            doc.payload = .stateDiagram(model)
        default:
            throw DiagramEditorError.unsupportedMutation(
                mutation: "deleteElement",
                diagramType: String(describing: doc.type)
            )
        }
        return doc
    }

    func _setLabel(
        of selection: DiagramSelection, to label: String, in document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        let id = selection.elementID
        switch doc.payload {
        case .flowchart(var model):
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                model.nodesInOrder = model.nodesInOrder.map { entry in
                    if entry.id == nodeID {
                        var node = entry.node
                        node.label = label
                        return (id: entry.id, node: node)
                    }
                    return entry
                }
            } else if id.hasPrefix("edge:") {
                let matched = _findEdge(in: model, selectionElementID: id)
                guard let index = matched else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                model.edges[index].label = label
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
            doc.payload = .flowchart(model)
        case .stateDiagram(var model):
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                model.nodesInOrder = model.nodesInOrder.map { entry in
                    if entry.id == nodeID {
                        var node = entry.node
                        node.label = label
                        return (id: entry.id, node: node)
                    }
                    return entry
                }
            } else if id.hasPrefix("edge:") {
                let matched = _findEdge(in: model, selectionElementID: id)
                guard let index = matched else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                model.edges[index].label = label
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
            doc.payload = .stateDiagram(model)
        default:
            throw DiagramEditorError.unsupportedMutation(
                mutation: "setLabel",
                diagramType: String(describing: doc.type)
            )
        }
        return doc
    }

    func _setTitle(_ title: String?, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        doc.title = title
        return doc
    }

    // MARK: - Edge matching helpers

    /// Returns true if the edge matches the given selection element ID.
    func _edgeMatches(
        selectionElementID: String,
        candidateElementID: String?,
        edge: original_src_types.MermaidEdge
    ) -> Bool {
        // Exact match on the full stable ID
        let guaranteed = _guaranteedEdgeID(for: edge)
        if guaranteed == selectionElementID { return true }
        // Also check by prefix for disambiguation suffixes
        if let cid = candidateElementID, selectionElementID.hasPrefix("edge:\(cid)") { return true }
        return false
    }

    /// Find the index of an edge matching the selection element ID.
    func _findEdge(
        in model: original_src_types.MermaidGraph,
        selectionElementID: String
    ) -> Int? {
        model.edges.firstIndex { edge in
            _edgeMatches(
                selectionElementID: selectionElementID,
                candidateElementID: edge.id,
                edge: edge
            )
        }
    }

    /// Compute the guaranteed stable edge ID (matches PositionedEdge.stableElementID).
    func _guaranteedEdgeID(for edge: original_src_types.MermaidEdge) -> String {
        if let edgeId = edge.id, !edgeId.isEmpty { return "edge:\(edgeId)" }
        let seed = [edge.source, edge.target, edge.label ?? ""].joined(separator: "→")
        return "edge:\(StableID.derive(from: seed))"
    }
}
