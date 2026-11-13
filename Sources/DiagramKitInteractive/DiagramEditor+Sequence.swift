// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
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
        try await _enqueueChainedMutation { editor in
            try await editor._performSequenceInner(mutation)
        }
    }

    func _performSequenceInner(_ mutation: SequenceMutation) async throws {
        guard case .sequenceDiagram = document.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "performSequence",
                diagramType: document.type.rawValue
            )
        }

        let newDocument = try _applySequence(mutation, to: document)
        try await _commitMutation(
            newDocument: newDocument,
            actionName: mutation.undoActionName
        )
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

        // The dragged message moves as one unit with the items that belong
        // to it (the activation its own `+`/`-` shorthand made, and a
        // `create`/`destroy` directly before it, which the parser ties to
        // the next message). Every other item keeps its place, so no other
        // message changes block or branch. The unit lands directly before
        // the target message when moved up, directly after it when moved
        // down, which puts it in the target's block.
        var items = model.items
        var messageIndices: [Int] = []
        for (index, item) in items.enumerated() {
            if case .message = item { messageIndices.append(index) }
        }
        guard from >= 0, from < messageIndices.count,
              to >= 0, to < messageIndices.count else {
            throw DiagramEditorError.elementNotFound(
                id: "message[\(from)]→[\(to)]",
                kind: "message"
            )
        }
        guard from != to else { return doc }

        func unitStart(_ messageIndex: Int) -> Int {
            guard case .message(let msg) = items[messageIndex] else { return messageIndex }
            var start = messageIndex
            if start > 0, Self._isShorthandActivation(items[start - 1], of: msg) { start -= 1 }
            if start > 0, Self._isLifecycleItem(items[start - 1], of: msg) { start -= 1 }
            return start
        }
        let movedEnd = messageIndices[from]
        let movedStart = unitStart(movedEnd)
        let unit = Array(items[movedStart...movedEnd])
        let target = messageIndices[to]
        let targetStart = unitStart(target)
        items.removeSubrange(movedStart...movedEnd)
        let removed = unit.count
        let insertAt: Int
        if from > to {
            insertAt = targetStart                // target is before the unit
        } else {
            insertAt = target - removed + 1       // target was after the unit
        }
        items.insert(contentsOf: unit, at: insertAt)

        // A note's anchor is the last message before it, as the parser
        // records it.
        var lastMessage: Int?
        for index in items.indices {
            switch items[index] {
            case .message:
                lastMessage = index
            case .note(var note):
                note.afterItemIndex = max(0, lastMessage ?? (index - 1))
                items[index] = .note(note)
            default:
                break
            }
        }
        model.items = items

        doc.payload = .sequenceDiagram(model)
        return doc
    }

    /// Whether `item` is a `create` or `destroy` the parser ties to
    /// `message`, the next message after it.
    nonisolated static func _isLifecycleItem(_ item: SequenceItem, of message: SequenceMessage) -> Bool {
        switch item {
        case .createParticipant(let actor): return message.to == actor.id
        case .destroyParticipant(let id): return message.from == id || message.to == id
        default: return false
        }
    }

    /// Whether `item`, directly before `message`, is the activation item
    /// the parser makes for that message's `+` or `-` shorthand.
    nonisolated static func _isShorthandActivation(_ item: SequenceItem, of message: SequenceMessage) -> Bool {
        switch item {
        case .activationStart(let id): return message.activate && id == message.to
        case .activationEnd(let id): return message.deactivate && !message.activate && id == message.from
        default: return false
        }
    }
}
#endif
