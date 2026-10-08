// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// GanttMutation.resizeTask — apply, undo, error path.

import Testing
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockGanttExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.gantt]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        guard case .gantt(let model) = document.payload else {
            return DiagramExportResult(source: "")
        }
        let summary = model.tasks.map { "\($0.id)=\(Int($0.endTime.timeIntervalSince1970))" }.joined(separator: ",")
        return DiagramExportResult(source: "mock:tasks=\(summary)")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockGanttExporter())
}

private func ganttDocWithTwoTasks() -> DiagramDocument {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let end = start.addingTimeInterval(86400 * 5)
    let model = GanttDiagram(
        sections: [GanttSection(name: "S", index: 0)],
        tasks: [
            GanttTask(id: "t1", task: "First", section: "S", startTime: start, endTime: end),
            GanttTask(id: "t2", task: "Second", section: "S", startTime: end, endTime: end.addingTimeInterval(86400 * 5))
        ]
    )
    return DiagramDocument(payload: .gantt(model))
}

@Suite @MainActor
struct GanttMutationTests {

    @Test("resizeTask updates the task's end time")
    func resizesEndTime() async throws {
        let editor = DiagramEditor(
            document: ganttDocWithTwoTasks(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let newEnd = Date(timeIntervalSince1970: 1_800_000_000)
        try await editor.performGantt(.resizeTask(taskId: "t1", newEndTime: newEnd))

        guard case .gantt(let model) = editor.document.payload else {
            Issue.record("expected gantt payload")
            return
        }
        #expect(model.tasks.first(where: { $0.id == "t1" })?.endTime == newEnd)
        #expect(model.tasks.first(where: { $0.id == "t1" })?.renderEndTime == newEnd)
        #expect(editor.canUndo)
    }

    @Test("resizeTask throws when the task id is unknown")
    func throwsOnUnknownId() async throws {
        let editor = DiagramEditor(
            document: ganttDocWithTwoTasks(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performGantt(
                .resizeTask(taskId: "nope", newEndTime: Date())
            )
        }
    }

    @Test("performGantt rejects non-gantt documents")
    func rejectsNonGanttDocuments() async throws {
        let flowDoc = DiagramDocument(payload: .flowchart(
            original_src_types.MermaidGraph(direction: .TD, nodesInOrder: [], edges: [])
        ))
        let editor = DiagramEditor(
            document: flowDoc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performGantt(
                .resizeTask(taskId: "t1", newEndTime: Date())
            )
        }
    }

    @Test("undo restores the original end time")
    func undoRestoresEndTime() async throws {
        let editor = DiagramEditor(
            document: ganttDocWithTwoTasks(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let originalEnd: Date = {
            guard case .gantt(let model) = editor.document.payload else {
                fatalError("expected gantt")
            }
            return model.tasks.first(where: { $0.id == "t1" })!.endTime
        }()

        try await editor.performGantt(
            .resizeTask(taskId: "t1", newEndTime: Date(timeIntervalSince1970: 1_800_000_000))
        )
        editor.undoManager.undo()

        guard case .gantt(let restored) = editor.document.payload else {
            Issue.record("expected gantt payload")
            return
        }
        #expect(restored.tasks.first(where: { $0.id == "t1" })?.endTime == originalEnd)
    }
}
#endif
