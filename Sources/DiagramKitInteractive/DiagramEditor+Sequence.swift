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

        // Each message moves as a unit with the items that belong to it:
        // the activation its own `+`/`-` shorthand created (`A->>+B` is
        // read as `activate B` then the message), and a `create` or
        // `destroy` directly before it, which the parser ties to the next
        // message. Every other item — notes, explicit activations, blocks —
        // keeps its place; only the units in the message slots are
        // reordered.
        var units: [[SequenceItem]] = []
        var layout: [SequenceItem?] = []   // nil marks a message slot
        for item in model.items {
            guard case .message(let msg) = item else {
                layout.append(item)
                continue
            }
            var unit = [item]
            if let last = layout.last, let previous = last, Self._isShorthandActivation(previous, of: msg) {
                layout.removeLast()
                unit.insert(previous, at: 0)
            }
            if let last = layout.last, let previous = last, Self._isLifecycleItem(previous, of: msg) {
                layout.removeLast()
                unit.insert(previous, at: 0)
            }
            units.append(unit)
            layout.append(nil)
        }

        guard from >= 0, from < units.count,
              to >= 0, to < units.count else {
            throw DiagramEditorError.elementNotFound(
                id: "message[\(from)]→[\(to)]",
                kind: "message"
            )
        }
        guard from != to else { return doc }

        let moved = units.remove(at: from)
        units.insert(moved, at: to)

        var newItems: [SequenceItem] = []
        var next = 0
        for entry in layout {
            if let entry {
                newItems.append(entry)
            } else {
                newItems += units[next]
                next += 1
            }
        }
        model.items = newItems

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
