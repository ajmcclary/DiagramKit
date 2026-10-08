// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// SequenceMutation.moveMessage — apply, undo, error path.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.sequenceDiagram]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        guard case .sequenceDiagram(let model) = document.payload else {
            return DiagramExportResult(source: "")
        }
        let labels = model.messages.map(\.label).joined(separator: ",")
        return DiagramExportResult(source: "mock:msgs=\(labels)")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func sequenceDocWithThreeMessages() -> DiagramDocument {
    let items: [SequenceItem] = [
        .actor(SequenceActor(id: "A", label: "A", type: .participant, isExplicit: true)),
        .actor(SequenceActor(id: "B", label: "B", type: .participant, isExplicit: true)),
        .message(SequenceMessage(from: "A", to: "B", label: "M1")),
        .message(SequenceMessage(from: "B", to: "A", label: "M2")),
        .message(SequenceMessage(from: "A", to: "B", label: "M3")),
    ]
    return DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: items)))
}

@Suite @MainActor
struct SequenceMutationTests {

    @Test("moveMessage reorders the messages array")
    func reordersMessages() async throws {
        let editor = DiagramEditor(
            document: sequenceDocWithThreeMessages(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performSequence(.moveMessage(at: 0, to: 2))
        guard case .sequenceDiagram(let model) = editor.document.payload else {
            Issue.record("expected sequence payload")
            return
        }
        #expect(model.messages.map(\.label) == ["M2", "M3", "M1"])
        #expect(editor.canUndo)
    }

    @Test("moveMessage at==to is a no-op")
    func noOpAtSamePosition() async throws {
        let editor = DiagramEditor(
            document: sequenceDocWithThreeMessages(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performSequence(.moveMessage(at: 1, to: 1))
        guard case .sequenceDiagram(let model) = editor.document.payload else {
            Issue.record("expected sequence payload")
            return
        }
        #expect(model.messages.map(\.label) == ["M1", "M2", "M3"])
    }

    @Test("moveMessage throws when source index is out of range")
    func throwsOutOfRange() async throws {
        let editor = DiagramEditor(
            document: sequenceDocWithThreeMessages(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performSequence(.moveMessage(at: 99, to: 0))
        }
    }

    @Test("performSequence rejects non-sequence documents")
    func rejectsNonSequenceDocuments() async throws {
        let flowDoc = DiagramDocument(payload: .flowchart(
            original_src_types.MermaidGraph(direction: .TD, nodesInOrder: [], edges: [])
        ))
        let editor = DiagramEditor(
            document: flowDoc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performSequence(.moveMessage(at: 0, to: 1))
        }
    }

    @Test("undo restores the original ordering")
    func undoRestoresOrder() async throws {
        let editor = DiagramEditor(
            document: sequenceDocWithThreeMessages(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performSequence(.moveMessage(at: 0, to: 2))
        editor.undoManager.undo()
        guard case .sequenceDiagram(let model) = editor.document.payload else {
            Issue.record("expected sequence payload")
            return
        }
        #expect(model.messages.map(\.label) == ["M1", "M2", "M3"])
    }
}
#endif
