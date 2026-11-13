// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Gantt-diagram structural mutations.
//
// Mirrors DiagramEditor+Sequence: a typed enum + `performGantt(_:)`
// entry point that hops to the worker, applies the mutation, re-exports
// through MermaidExporter (which gained `.gantt` support alongside this
// file), and commits document + source + undo registration atomically.

import Foundation
import DiagramKitCommon
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
        try await _enqueueChainedMutation { editor in
            try await editor._performGanttInner(mutation)
        }
    }

    func _performGanttInner(_ mutation: GanttMutation) async throws {
        guard case .gantt = document.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: "performGantt",
                diagramType: document.type.rawValue
            )
        }

        // With a parser at hand (the default registry's read-back), a
        // resize edits the task's own line in the source and re-reads the
        // text, so every other line (durations, `after` dependencies,
        // comments) stays as written and dependent tasks move as they would
        // in Mermaid. Without one, the model is edited and exported.
        if case .resizeTask(let taskId, let newEndTime) = mutation,
           preferredExportFormat == .mermaid,
           let readBack = exportRegistry.readBack {
            let base: String
            if let source {
                base = DiagramSourceNormalizer.normalizedLineEndings(source)
            } else {
                base = try await _exportAsync(document).source
            }
            let current = document
            let (edited, newDocument, line) = try await Self._runOnWorker {
                try Self._resizeGanttTaskInSource(
                    base, document: current, taskId: taskId, newEndTime: newEndTime, readBack: readBack
                )
            }
            try await _commitMutation(
                newDocument: newDocument,
                savedSource: edited,
                scope: .singleLine(line),
                actionName: mutation.undoActionName
            )
            return
        }

        let newDocument = try _applyGantt(mutation, to: document)
        try await _commitMutation(
            newDocument: newDocument,
            actionName: mutation.undoActionName
        )
    }

    // MARK: - Source-level resize

    /// `source` with only the line of task `taskId` changed so the task
    /// ends at `newEndTime`, and the document that text reads as. The end
    /// keeps its form where the new end can be written in it (a duration
    /// stays a duration in its unit, or in days, hours, minutes or seconds
    /// when it is not a whole number of that unit; a date stays a date);
    /// otherwise, for that line only, it becomes a date in the gantt's
    /// `dateFormat`. Throws `exportWouldLoseContent` when the gantt uses
    /// `excludes` (the written dates would not say where the bar ends) or
    /// when no spelling reads back as the requested end.
    nonisolated static func _resizeGanttTaskInSource(
        _ source: String,
        document: DiagramDocument,
        taskId: String,
        newEndTime: Date,
        readBack: @Sendable (String, DiagramFormatID) throws -> DiagramDocument
    ) throws -> (source: String, document: DiagramDocument, line: Int) {
        guard case .gantt(let model) = document.payload else {
            throw DiagramEditorError.unsupportedMutation(mutation: "resizeTask", diagramType: document.type.rawValue)
        }
        guard let index = model.tasks.firstIndex(where: { $0.id == taskId }) else {
            throw DiagramEditorError.elementNotFound(id: taskId, kind: "task")
        }
        let task = model.tasks[index]
        func refuse(_ why: String) -> DiagramEditorError {
            .exportWouldLoseContent(details: "task \u{201C}\(task.task)\u{201D} cannot be resized on the canvas: \(why)")
        }
        if !model.excludes.isEmpty {
            throw refuse("the chart excludes days, so the dates a resize would write would not show where the bar ends")
        }

        // The task's line, found in one pass: task lines follow the model's
        // task order, so each task is the next line after the previous
        // task's whose text before the colon is the task's name. The
        // re-read below proves the choice; if it fails, the line is found
        // with the parser by bisecting on prefixes (the prefix property
        // "already holds the task" is monotonic), O(log n) parses.
        var lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let preambleLines = (_collectMermaidSourceAnnotations(
            source, title: document.title, theme: document.frontmatter?.theme, layout: document.frontmatter?.layout
        )?.preamble ?? "").split(separator: "\n", omittingEmptySubsequences: true).count
        var greedy: Int?
        var cursor = min(preambleLines, lines.count)
        while cursor < lines.count, !lines[cursor].trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("gantt") { cursor += 1 }
        cursor += 1
        for k in 0...index {
            var found: Int?
            while cursor < lines.count {
                let line = lines[cursor]
                cursor += 1
                if let colon = line.firstIndex(of: ":"),
                   line[..<colon].trimmingCharacters(in: .whitespaces) == model.tasks[k].task {
                    found = cursor - 1
                    break
                }
            }
            guard let found else { break }
            if k == index { greedy = found }
        }
        func bisected() -> Int? {
            var low = 0, high = lines.count - 1, answer: Int?
            while low <= high {
                let mid = (low + high) / 2
                let prefix = lines[...mid].joined(separator: "\n") + "\n"
                let count: Int
                if let doc = try? readBack(prefix, .mermaid), case .gantt(let partial) = doc.payload {
                    count = partial.tasks.count
                } else {
                    count = -1
                }
                if count > index {
                    answer = mid
                    high = mid - 1
                } else if count >= 0 {
                    low = mid + 1
                } else {
                    return nil
                }
            }
            return answer
        }
        let original = lines
        var tried: Set<Int> = []
        for attempt in 0..<2 {
            guard let lineIndex = attempt == 0 ? greedy : bisected(), tried.insert(lineIndex).inserted else { continue }
            lines = original
            if let result = try Self._rewriteGanttEnd(
                lines: &lines, lineIndex: lineIndex, task: task, index: index, model: model,
                taskId: taskId, newEndTime: newEndTime, readBack: readBack
            ) {
                return result
            }
        }
        throw refuse("no way of writing its end in this chart gives the date you dragged to")
    }

    /// The edit of `lines[lineIndex]` that makes task `index` end at
    /// `newEndTime` when the text is re-read, or nil.
    nonisolated static func _rewriteGanttEnd(
        lines: inout [String], lineIndex: Int, task: GanttTask, index: Int, model: GanttDiagram,
        taskId: String, newEndTime: Date,
        readBack: @Sendable (String, DiagramFormatID) throws -> DiagramDocument
    ) throws -> (source: String, document: DiagramDocument, line: Int)? {
        guard lines.indices.contains(lineIndex),
              let colon = lines[lineIndex].firstIndex(of: ":"),
              lines[lineIndex][..<colon].trimmingCharacters(in: .whitespaces) == task.task else {
            return nil
        }

        // The end is the last comma-separated field after the colon.
        let line = lines[lineIndex]
        let dataStart = line.index(after: colon)
        let lastComma = line[dataStart...].lastIndex(of: ",")
        let fieldStart = lastComma.map { line.index(after: $0) } ?? dataStart
        let field = String(line[fieldStart...])
        let leading = String(field.prefix(while: { $0 == " " || $0 == "\t" }))
        let trailing = String(field.reversed().prefix(while: { $0 == " " || $0 == "\t" }).reversed())
        let token = field.trimmingCharacters(in: .whitespaces)

        var candidates: [String] = []
        if let duration = Self._ganttDuration(token) {
            let seconds = newEndTime.timeIntervalSince(task.startTime)
            let units: [(String, Double)] = [("ms", 0.001), ("s", 1), ("m", 60), ("h", 3600), ("d", 86400), ("w", 604_800)]
            let preferred = units.first { $0.0 == duration.unit }.map { [$0] } ?? []
            for (unit, size) in preferred + units.reversed() where seconds >= 0 {
                let value = seconds / size
                if value.rounded() == value, value < 1e12 {
                    candidates.append("\(Int(value))\(unit)")
                    break
                }
            }
        }
        let writtenEnd = model.inclusiveEndDates
            ? (_ganttCalendar.date(byAdding: .day, value: -1, to: newEndTime) ?? newEndTime)
            : newEndTime
        if let date = _ganttFormatDate(writtenEnd, dateFormat: model.dateFormat) {
            candidates.append(date)
        }

        for candidate in candidates {
            lines[lineIndex] = String(line[..<fieldStart]) + leading + candidate + trailing
            let edited = lines.joined(separator: "\n")
            guard let back = try? readBack(edited, .mermaid),
                  case .gantt(let reread) = back.payload,
                  reread.tasks.count == model.tasks.count,
                  reread.tasks[index].id == taskId,
                  reread.tasks[index].startTime == task.startTime,
                  reread.tasks[index].endTime == newEndTime else { continue }
            return (edited, back, lineIndex)
        }
        return nil
    }

    /// The value and unit of a gantt duration (`10d`, `1.5h`), or nil.
    nonisolated static func _ganttDuration(_ token: String) -> (value: Double, unit: String)? {
        guard let match = token.range(of: #"^\d+(?:\.\d+)?(ms|[Mdhmswy])$"#, options: .regularExpression), match == token.startIndex..<token.endIndex else {
            return nil
        }
        let unit = token.hasSuffix("ms") ? "ms" : String(token.last!)
        let number = token.dropLast(unit.count)
        return Double(number).map { ($0, unit) }
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
