// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Owner ruling (2026-11-12 review, round 3): a gantt canvas resize changes
// only the resized task's own line; every other line, durations and
// `after` dependencies included, is saved byte for byte.

import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

let ganttEditFixtures: [(name: String, source: String)] = [
    ("forms", """
    gantt
        title Forms
        dateFormat YYYY-MM-DD
        %% durations, dates and dependencies
        section A
            Duration     :a1, 2024-01-01, 10d
            Dated        :a2, 2024-01-02, 2024-01-12
            After        :a3, after a1, 3d
            Implicit     :4d
            Weeks        :a5, 2024-02-01, 2w
            Until        :a6, 2024-01-03, until a5
        click a1 href "obsidian://open?vault=plan"
    """),
]

@MainActor
private func editor(_ source: String) throws -> DiagramEditor {
    DiagramEditor(
        document: try MermaidImporter().parse(source).document,
        preferredExportFormat: .mermaid,
        exportRegistry: DiagramPipeline.defaultExportRegistry,
        initialSource: source
    )
}

private func ganttInputs() throws -> [(name: String, source: String)] {
    let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
        guard let doc = try? MermaidImporter().parse(entry.source).document, doc.type == .gantt else { return nil }
        return (entry.id, entry.source)
    }
    return corpus + ganttEditFixtures
}

private func tasks(_ document: DiagramDocument) -> [GanttTask] {
    if case .gantt(let g) = document.payload { return g.tasks }
    return []
}

/// Nil when `saved` is `original` with only frontmatter/directive lines
/// for title or theme added or changed; otherwise what else changed.
func settingsOnlyChange(from original: String, to saved: String) -> String? {
    var remaining = saved.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var lost: [String] = []
    for line in original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
        if let i = remaining.firstIndex(of: line) {
            remaining.remove(at: i)
        } else {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !(t.hasPrefix("title:") || t.hasPrefix("theme:") || t.hasPrefix("%%{")) { lost.append(line) }
        }
    }
    let allowedNew = remaining.filter { line in
        let t = line.trimmingCharacters(in: .whitespaces)
        return !(t == "---" || t == "config:" || t.hasPrefix("title:") || t.hasPrefix("theme:") || t.hasPrefix("%%{") || t.isEmpty)
    }
    if !lost.isEmpty { return "lost lines \(lost)" }
    if !allowedNew.isEmpty { return "new lines \(allowedNew)" }
    // The body (everything from the header on) is unchanged and in place.
    let header = original.split(separator: "\n", omittingEmptySubsequences: false)
        .first { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("gantt") }
    if let header, let range = original.range(of: String(header)) {
        let body = original[range.lowerBound...]
        if !saved.hasSuffix(body) { return "the body moved or changed" }
    }
    return nil
}

@Suite("Gantt canvas edits change only the edited task's line") @MainActor
struct GanttEditFidelityTests {

    @Test("parse → export → parse keeps every corpus gantt, and the export is byte-stable")
    func exportRoundTrip() throws {
        var failures: [String] = []
        for (name, source) in try ganttInputs() {
            let original = try MermaidImporter().parse(source).document
            let exported = try MermaidExporter().export(original).source
            let back = try MermaidImporter().parse(exported).document
            let lossy = _modelFingerprint(back) != _modelFingerprint(original)
            // gantt-4: excludes change where an exported date-only bar ends.
            if lossy != (name == "gantt-4-excludes") {
                failures.append("[\(name)] \(_fingerprintDifference(_modelFingerprint(original), _modelFingerprint(back)))")
            }
            if try MermaidExporter().export(back).source != exported { failures.append("[\(name)] second export differs") }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test("resizing any task of any corpus gantt changes exactly that task's line, or is refused when the gantt has excludes")
    func singleResizeChangesOneLine() async throws {
        var failures: [String] = []
        var resized = 0
        for (name, source) in try ganttInputs() {
            let document = try MermaidImporter().parse(source).document
            guard case .gantt(let model) = document.payload else { continue }
            for task in model.tasks where !task.tags.contains(.milestone) {
                let edit = try editor(source)
                let newEnd = task.endTime.addingTimeInterval(86400)
                do {
                    try await edit.performGantt(.resizeTask(taskId: task.id, newEndTime: newEnd))
                } catch DiagramEditorError.exportWouldLoseContent(let details) {
                    if model.excludes.isEmpty { failures.append("[\(name)/\(task.id)] refused: \(details)") }
                    #expect(edit.source == source)
                    continue
                }
                if !model.excludes.isEmpty { failures.append("[\(name)/\(task.id)] applied despite excludes") }
                resized += 1
                let before = source.split(separator: "\n", omittingEmptySubsequences: false)
                let after = (edit.source ?? "").split(separator: "\n", omittingEmptySubsequences: false)
                let changed = zip(before, after).filter { $0 != $1 }
                if before.count != after.count || changed.count != 1 {
                    failures.append("[\(name)/\(task.id)] \(changed.count) lines changed:\n\(edit.source ?? "")")
                } else if !changed[0].0.contains(":") || changed[0].0.split(separator: ":")[0] != changed[0].1.split(separator: ":")[0] {
                    failures.append("[\(name)/\(task.id)] changed a line that is not the task's: \(changed[0])")
                }
                let reread = tasks(try MermaidImporter().parse(edit.source ?? "").document)
                if reread.first(where: { $0.id == task.id })?.endTime != newEnd {
                    failures.append("[\(name)/\(task.id)] does not end at the requested date")
                }
            }
        }
        #expect(resized >= 19)
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n\n"))")
    }

    @Test("a duration stays a duration, a date stays a date, after keeps after, and until falls back to a date on its own line")
    func formsKept() async throws {
        let source = ganttEditFixtures[0].source
        func resize(_ id: String, days: Double) async throws -> String {
            let edit = try editor(source)
            let task = try #require(tasks(edit.document).first { $0.id == id })
            try await edit.performGantt(.resizeTask(taskId: id, newEndTime: task.endTime.addingTimeInterval(days * 86400)))
            return try #require(edit.source)
        }
        #expect(try await resize("a1", days: 2).contains("Duration     :a1, 2024-01-01, 12d"))
        #expect(try await resize("a2", days: 1).contains("Dated        :a2, 2024-01-02, 2024-01-13"))
        #expect(try await resize("a3", days: -1).contains("After        :a3, after a1, 2d"))
        #expect(try await resize("a5", days: 7).contains("Weeks        :a5, 2024-02-01, 3w"))
        #expect(try await resize("a5", days: 1).contains("Weeks        :a5, 2024-02-01, 15d"))
        let until = try await resize("a6", days: 1)
        #expect(until.contains("Until        :a6, 2024-01-03, 2024-02-02"), "\(until)")
    }

    @Test("a dependent task moves with the task it follows, and its line is unchanged")
    func dependentMoves() async throws {
        let edit = try editor(ganttEditFixtures[0].source)
        let a1 = try #require(tasks(edit.document).first { $0.id == "a1" })
        try await edit.performGantt(.resizeTask(taskId: "a1", newEndTime: a1.endTime.addingTimeInterval(2 * 86400)))
        let saved = try #require(edit.source)
        #expect(saved.contains("After        :a3, after a1, 3d"))
        let a3 = try #require(tasks(edit.document).first { $0.id == "a3" })
        #expect(a3.startTime == a1.endTime.addingTimeInterval(2 * 86400))
    }

    @Test("a title change and a theme change on every corpus gantt change only those settings' lines")
    func titleAndThemeChangeOnlyTheirLines() async throws {
        var failures: [String] = []
        for (name, source) in try ganttInputs() {
            for edit in [DiagramMutation.setTitle("Renamed plan"), .setTheme("nord")] {
                let editor = try editor(source)
                try await editor.perform(edit)
                let saved = try #require(editor.source)
                if let problem = settingsOnlyChange(from: source, to: saved) {
                    failures.append("[\(name)] \(edit): \(problem)\n\(saved)")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n\n"))")
    }

    @Test("a gantt with excludes refuses a resize with the typed error and keeps its source")
    func excludesRefused() async throws {
        let source = "gantt\n    dateFormat YYYY-MM-DD\n    excludes weekends\n    section W\n        T :t1, 2024-01-01, 5d\n"
        let edit = try editor(source)
        let task = try #require(tasks(edit.document).first)
        do {
            try await edit.performGantt(.resizeTask(taskId: "t1", newEndTime: task.endTime.addingTimeInterval(86400)))
            Issue.record("resize applied")
        } catch DiagramEditorError.exportWouldLoseContent {
        }
        #expect(edit.source == source)
        #expect(!edit.canUndo)
    }
}
#endif
