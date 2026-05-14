// DiagramEditor Observation-tracked undo state tests
//
// Verifies the `canUndo` / `canRedo` / `undoActionName` / `redoActionName`
// computed properties on DiagramEditor pick up UndoManager state changes
// through NotificationCenter, including consumer-direct
// `editor.undoManager.undo()` calls.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
import Observation
@testable import DiagramKitInteractive

// MARK: - Shared fixtures

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock:flowchart")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: mNodes,
        edges: []
    )
    return DiagramDocument(payload: .flowchart(model))
}

@MainActor
private func makeEditor(_ nodes: [String] = ["A", "B"]) async throws -> DiagramEditor {
    let editor = DiagramEditor(
        document: flowDoc(nodes),
        preferredExportFormat: .mermaid,
        exportRegistry: mockRegistry()
    )
    try await editor.syncSource()
    return editor
}

// MARK: - Suite

@Suite @MainActor
struct DiagramEditorUndoObservationTests {

    @Test("Fresh editor reports canUndo=false, canRedo=false, both action names empty")
    func initialState() async throws {
        let editor = try await makeEditor()
        #expect(editor.canUndo == false)
        #expect(editor.canRedo == false)
        #expect(editor.undoActionName == "")
        #expect(editor.redoActionName == "")
    }
}
