// Phase 10 follow-up — sequence-diagram structural mutations.
// Pattern mirrors DiagramEditor+Flowchart: a typed enum + a
// `performSequence(_:)` entry point that hops to the worker, applies
// the mutation, re-exports through MermaidExporter (which already
// supports sequence diagrams), and commits document + source + undo
// registration atomically.

import DiagramKitModel
import DiagramKitExport

// MARK: - SequenceMutation

/// Sequence-diagram-specific mutations.
///
/// These require the document to be a sequence diagram.
/// `performSequence(_:)` validates this before applying.
public enum SequenceMutation: Sendable {

    /// Reorder the message at `messageIndex` to a new index in the
    /// document's `messages` array. Indices refer to the
    /// filtered message-only view (`SequenceDiagram.messages`),
    /// matching the order the SequenceEditCanvas presents.
    ///
    /// Other timeline items (notes, activations, blocks) move with
    /// the surrounding messages — only the relative order of
    /// `.message` items changes.
    case moveMessage(at: Int, to: Int)
}

// MARK: - Undo action names

extension SequenceMutation {
    public var undoActionName: String {
        switch self {
        case .moveMessage:
            return "Move Message"
        }
    }
}

// MARK: - Equatable & Hashable

extension SequenceMutation: Equatable, Hashable {
    public static func == (lhs: SequenceMutation, rhs: SequenceMutation) -> Bool {
        switch (lhs, rhs) {
        case (.moveMessage(let aFrom, let aTo), .moveMessage(let bFrom, let bTo)):
            return aFrom == bFrom && aTo == bTo
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .moveMessage(let from, let to):
            hasher.combine(0)
            hasher.combine(from)
            hasher.combine(to)
        }
    }
}

// MARK: - Editor entry point

extension DiagramEditor {

    /// Perform a sequence-diagram-specific mutation. Same
    /// serialization + atomicity contract as `perform` /
    /// `performFlowchart`.
    public func performSequence(_ mutation: SequenceMutation) async throws {
        _enterMutationChain()
        defer { _exitMutationChain() }

        await _awaitPendingMutation()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self._performSequenceInner(mutation)
        }
        let generation = _setPendingMutation(task)
        defer { _clearPendingMutationIfCurrent(generation: generation) }

        try await task.value
    }

    func _performSequenceInner(_ mutation: SequenceMutation) async throws {
        guard case .sequenceDiagram = document.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "performSequence",
                diagramType: document.type.rawValue
            )
        }

        let newDocument = try _applySequence(mutation, to: document)

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

    // MARK: - Mutation application

    func _applySequence(
        _ mutation: SequenceMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .moveMessage(let from, let to):
            return try _moveSequenceMessage(from: from, to: to, into: document)
        }
    }

    func _moveSequenceMessage(
        from: Int, to: Int, into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .sequenceDiagram(var model) = doc.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "moveMessage",
                diagramType: doc.type.rawValue
            )
        }

        // Extract the message-only timeline (ordered) and remember
        // each message's slot index in the full items list. The slot
        // positions stay fixed — only the messages in those slots get
        // reordered, so surrounding notes/activations don't drift.
        var messageList: [SequenceMessage] = []
        var messageSlots: [Int] = []
        for (index, item) in model.items.enumerated() {
            if case .message(let msg) = item {
                messageList.append(msg)
                messageSlots.append(index)
            }
        }

        guard from >= 0, from < messageList.count,
              to >= 0, to < messageList.count else {
            throw DiagramEditorError.elementNotFound(
                id: "message[\(from)]→[\(to)]",
                kind: "message"
            )
        }
        guard from != to else { return doc }

        let moved = messageList.remove(at: from)
        messageList.insert(moved, at: to)

        var newItems = model.items
        for (i, slot) in messageSlots.enumerated() {
            newItems[slot] = .message(messageList[i])
        }
        model.items = newItems

        doc.payload = .sequenceDiagram(model)
        return doc
    }
}
