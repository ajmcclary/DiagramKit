// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Gantt-diagram structural mutations.
//
// Mirrors DiagramEditor+Sequence: a typed enum + `performGantt(_:)`
// entry point that hops to the worker, applies the mutation, re-exports
// through MermaidExporter (which gained `.gantt` support alongside this
// file), and commits document + source + undo registration atomically.

import Foundation
import DiagramKitModel
import DiagramKitExport

// MARK: - GanttMutation

/// Gantt-diagram-specific mutations.
///
/// These require the document to be a gantt diagram. `performGantt(_:)`
/// validates this before applying.
public enum GanttMutation: Sendable {

    /// Set the end time of the task identified by `taskId`. Throws
    /// `.elementNotFound` if no task with that id exists. The new end
    /// time is treated as the absolute end of the bar — the canvas
    /// converts week deltas into a target `Date` before calling this.
    case resizeTask(taskId: String, newEndTime: Date)
}

// MARK: - Undo action names

extension GanttMutation {
    public var undoActionName: String {
        switch self {
        case .resizeTask:
            return "Resize Task"
        }
    }
}

// MARK: - Equatable & Hashable

extension GanttMutation: Equatable, Hashable {
    public static func == (lhs: GanttMutation, rhs: GanttMutation) -> Bool {
        switch (lhs, rhs) {
        case (.resizeTask(let aId, let aEnd), .resizeTask(let bId, let bEnd)):
            return aId == bId && aEnd == bEnd
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .resizeTask(let id, let end):
            hasher.combine(0)
            hasher.combine(id)
            hasher.combine(end)
        }
    }
}

// MARK: - Editor entry point

extension DiagramEditor {

    /// Perform a gantt-diagram-specific mutation. Same serialization +
    /// atomicity contract as `perform` / `performFlowchart` /
    /// `performSequence`.
    public func performGantt(_ mutation: GanttMutation) async throws {
        _enterMutationChain()
        defer { _exitMutationChain() }

        await _awaitPendingMutation()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try await self._performGanttInner(mutation)
        }
        let generation = _setPendingMutation(task)
        defer { _clearPendingMutationIfCurrent(generation: generation) }

        try await task.value
    }

    func _performGanttInner(_ mutation: GanttMutation) async throws {
        guard case .gantt = document.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "performGantt",
                diagramType: document.type.rawValue
            )
        }

        let newDocument = try _applyGantt(mutation, to: document)
        try await _commitMutation(
            newDocument: newDocument,
            actionName: mutation.undoActionName
        )
    }

    // MARK: - Mutation application

    func _applyGantt(
        _ mutation: GanttMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .resizeTask(let taskId, let newEndTime):
            return try _resizeGanttTask(id: taskId, to: newEndTime, in: document)
        }
    }

    func _resizeGanttTask(
        id taskId: String, to newEndTime: Date, in document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .gantt(var model) = doc.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "resizeTask",
                diagramType: doc.type.rawValue
            )
        }

        guard let index = model.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw DiagramEditorError.elementNotFound(id: taskId, kind: "task")
        }

        var task = model.tasks[index]
        task.endTime = newEndTime
        // Keep `renderEndTime` in sync so the canvas's bar geometry
        // matches the committed end. `_checkTaskDates` only writes
        // this when excludes are set; if the user resizes past an
        // excluded day the next re-parse will recompute it.
        task.renderEndTime = newEndTime
        model.tasks[index] = task

        doc.payload = .gantt(model)
        return doc
    }
}
#endif
