// Phase 9: Interactive Model — Slice 9F
// Flowchart-specific mutations.

import DiagramKitModel
import DiagramKitExport

// MARK: - FlowchartMutation

/// Flowchart-specific mutations.
///
/// These require the document to be a flowchart. `performFlowchart(_:)`
/// validates this before applying.
public enum FlowchartMutation: Sendable {
    /// Insert a new node. `id` must not collide with an existing node.
    case insertNode(id: String, label: String, type: String? = nil)

    /// Insert a directed edge between two existing nodes.
    /// `from` and `to` must be `DiagramSelection` values whose
    /// `elementID` corresponds to existing flowchart nodes.
    case insertEdge(
        id: String,
        from: DiagramSelection,
        to: DiagramSelection,
        label: String? = nil
    )
}

// MARK: - Undo action names

extension FlowchartMutation {
    /// Human-readable name for the undo/redo menu.
    public var undoActionName: String {
        switch self {
        case .insertNode:
            return "Insert Node"
        case .insertEdge:
            return "Insert Edge"
        }
    }
}

// MARK: - Equatable & Hashable

extension FlowchartMutation: Equatable, Hashable {
    public static func == (lhs: FlowchartMutation, rhs: FlowchartMutation) -> Bool {
        switch (lhs, rhs) {
        case (.insertNode(let aId, let aLabel, let aType), .insertNode(let bId, let bLabel, let bType)):
            return aId == bId && aLabel == bLabel && aType == bType
        case (.insertEdge(let aId, let aFrom, let aTo, let aLabel),
              .insertEdge(let bId, let bFrom, let bTo, let bLabel)):
            return aId == bId && aFrom == bFrom && aTo == bTo && aLabel == bLabel
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .insertNode(let id, let label, let type):
            hasher.combine(0)
            hasher.combine(id)
            hasher.combine(label)
            hasher.combine(type)
        case .insertEdge(let id, let from, let to, let label):
            hasher.combine(1)
            hasher.combine(id)
            hasher.combine(from)
            hasher.combine(to)
            hasher.combine(label)
        }
    }
}

// MARK: - Flowchart mutation entry point

extension DiagramEditor {

    /// Perform a flowchart-specific mutation.
    ///
    /// - Parameter mutation: The flowchart mutation to apply.
    /// - Throws: `DiagramEditorError` if the document is not a flowchart,
    ///   the mutation cannot be applied, or source sync fails.
    public func performFlowchart(_ mutation: FlowchartMutation) throws {
        // Validate document type
        guard case .flowchart = document.payload else {
            throw DiagramEditorError.notAFlowchart
        }

        let newDocument = try _applyFlowchart(mutation, to: document)

        let exportResult: DiagramExportResult
        do {
            exportResult = try _export(newDocument)
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

    // MARK: - Flowchart mutation application

    func _applyFlowchart(
        _ mutation: FlowchartMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .insertNode(let id, let label, let type):
            return try _insertFlowchartNode(id: id, label: label, type: type, into: document)
        case .insertEdge(let id, let from, let to, let label):
            return try _insertFlowchartEdge(id: id, from: from, to: to, label: label, into: document)
        }
    }

    // MARK: - Flowchart insertion implementations

    func _insertFlowchartNode(
        id: String, label: String, type: String?, into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        guard !model.nodesInOrder.contains(where: { $0.id == id }) else {
            throw DiagramEditorError.duplicateNodeID(id: id)
        }
        let shape = original_src_types.NodeShape.resolve(alias: type ?? "rectangle") ?? .rectangle
        let node = original_src_types.MermaidNode(
            id: id,
            label: label,
            shape: shape
        )
        model.nodesInOrder.append((id: id, node: node))
        doc.payload = .flowchart(model)
        return doc
    }

    func _insertFlowchartEdge(
        id: String,
        from: DiagramSelection,
        to: DiagramSelection,
        label: String?,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(let model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        try _validateSelection(from, matches: document)
        try _validateSelection(to, matches: document)

        // Extract node IDs from selections
        let fromID: String
        if from.elementID.hasPrefix("node:") {
            fromID = String(from.elementID.dropFirst(5))
        } else {
            throw DiagramEditorError.elementNotFound(id: from.elementID, kind: "source node")
        }

        let toID: String
        if to.elementID.hasPrefix("node:") {
            toID = String(to.elementID.dropFirst(5))
        } else {
            throw DiagramEditorError.elementNotFound(id: to.elementID, kind: "target node")
        }

        // Verify both endpoints exist
        guard model.nodesInOrder.contains(where: { $0.id == fromID }) else {
            throw DiagramEditorError.elementNotFound(id: fromID, kind: "node")
        }
        guard model.nodesInOrder.contains(where: { $0.id == toID }) else {
            throw DiagramEditorError.elementNotFound(id: toID, kind: "node")
        }

        let edge = original_src_types.MermaidEdge(
            source: fromID,
            target: toID,
            label: label,
            style: .solid,
            id: id.isEmpty ? nil : id
        )

        var updatedModel = model
        updatedModel.edges.append(edge)
        doc.payload = .flowchart(updatedModel)
        return doc
    }
}
