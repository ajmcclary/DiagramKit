// Phase 9: Interactive Model — Slice 9F
// Flowchart-specific mutations.

import DiagramKitCommon
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

    /// Wrap the named nodes in a fresh `MermaidSubgraph` whose id is a
    /// deterministic slug of `title` plus a stable hash of the sorted
    /// member node ids. The inverse is registered as a snapshot
    /// restore through `DiagramEditor+Undo`, which functions as the
    /// "flatten" path for free.
    case groupIntoSubgraph(selections: [DiagramSelection], title: String)

    /// Change the style of an existing edge. Matches first on the
    /// edge's explicit `id` (the `eN@` Mermaid prefix syntax) if
    /// provided, then by source+target identity. Throws
    /// `.elementNotFound` if neither match locates the edge.
    case setEdgeStyle(edgeId: String?, source: String, target: String, to: FlowchartEdgeStyle)
}

/// Subset of `original_src_types.EdgeStyle` exposed through the
/// public mutation surface. Pinned here so consumers don't have to
/// import the `original_src_types` namespace just to set an edge
/// style.
public enum FlowchartEdgeStyle: String, Sendable, CaseIterable {
    case solid
    case dotted
    case thick
    case invisible

    var internalStyle: original_src_types.EdgeStyle {
        switch self {
        case .solid:     return .solid
        case .dotted:    return .dotted
        case .thick:     return .thick
        case .invisible: return .invisible
        }
    }
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
        case .groupIntoSubgraph:
            return "Group Into Subgraph"
        case .setEdgeStyle:
            return "Set Edge Style"
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
        case (.groupIntoSubgraph(let aSels, let aTitle), .groupIntoSubgraph(let bSels, let bTitle)):
            return aSels == bSels && aTitle == bTitle
        case (.setEdgeStyle(let aId, let aSrc, let aTgt, let aStyle),
              .setEdgeStyle(let bId, let bSrc, let bTgt, let bStyle)):
            return aId == bId && aSrc == bSrc && aTgt == bTgt && aStyle == bStyle
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
        case .groupIntoSubgraph(let sels, let title):
            hasher.combine(2)
            hasher.combine(sels)
            hasher.combine(title)
        case .setEdgeStyle(let id, let src, let tgt, let style):
            hasher.combine(3)
            hasher.combine(id)
            hasher.combine(src)
            hasher.combine(tgt)
            hasher.combine(style)
        }
    }
}

// MARK: - Flowchart mutation entry point

extension DiagramEditor {

    /// Perform a flowchart-specific mutation. Same serialization +
    /// atomicity contract as `perform`.
    ///
    /// - Parameter mutation: The flowchart mutation to apply.
    /// - Throws: `DiagramEditorError` if the document is not a flowchart,
    ///   the mutation cannot be applied, or source sync fails.
    public func performFlowchart(_ mutation: FlowchartMutation) async throws {
        _enterMutationChain()
        defer { _exitMutationChain() }

        await _awaitPendingMutation()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self._performFlowchartInner(mutation)
        }
        let generation = _setPendingMutation(task)
        defer { _clearPendingMutationIfCurrent(generation: generation) }

        try await task.value
    }

    /// Inner commit body. Always runs on `MainActor`. Atomic: a throw
    /// from the worker leaves state untouched.
    func _performFlowchartInner(_ mutation: FlowchartMutation) async throws {
        guard case .flowchart = document.payload else {
            throw DiagramEditorError.notAFlowchart
        }

        let (newDocument, mutationDiagnostics) = try _applyFlowchart(mutation, to: document)

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
        // Mutation-tier diagnostics (e.g. subgraph-title sanitization)
        // ride alongside export-tier diagnostics on the editor's
        // `lastExportDiagnostics` channel.
        _commitDiagnostics(mutationDiagnostics + exportResult.diagnostics)

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
    ) throws -> (DiagramDocument, [DiagramDiagnostic]) {
        switch mutation {
        case .insertNode(let id, let label, let type):
            return (try _insertFlowchartNode(id: id, label: label, type: type, into: document), [])
        case .insertEdge(let id, let from, let to, let label):
            return (try _insertFlowchartEdge(id: id, from: from, to: to, label: label, into: document), [])
        case .groupIntoSubgraph(let selections, let title):
            return try _groupIntoSubgraph(selections: selections, title: title, into: document)
        case .setEdgeStyle(let edgeId, let source, let target, let style):
            return (try _setFlowchartEdgeStyle(
                edgeId: edgeId, source: source, target: target,
                style: style.internalStyle, into: document
            ), [])
        }
    }

    func _setFlowchartEdgeStyle(
        edgeId: String?,
        source: String,
        target: String,
        style: original_src_types.EdgeStyle,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        // Prefer matching by edge id when one is provided; fall back
        // to source+target identity for edges parsed without an
        // explicit `eN@` prefix.
        let index = model.edges.firstIndex { edge in
            if let edgeId, let candidateId = edge.id, candidateId == edgeId {
                return true
            }
            return edgeId == nil && edge.source == source && edge.target == target
        }
        guard let index else {
            let descriptor = edgeId ?? "\(source)→\(target)"
            throw DiagramEditorError.elementNotFound(id: descriptor, kind: "edge")
        }
        model.edges[index].style = style
        doc.payload = .flowchart(model)
        return doc
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
