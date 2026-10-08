// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
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

    @Test("After one mutation, canUndo=true, undoActionName non-empty, canRedo=false")
    func afterMutation() async throws {
        let editor = try await makeEditor()
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        #expect(editor.canUndo == true)
        #expect(editor.undoActionName.isEmpty == false)
        #expect(editor.canRedo == false)
        #expect(editor.redoActionName == "")
    }

    @Test("Consumer-direct editor.undoManager.undo() flows through to canUndo/canRedo")
    func directUndoManagerCall() async throws {
        let editor = try await makeEditor()
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        // Bypass any future convenience wrapper and call the manager
        // directly. The NotificationCenter path is the only thing that
        // can tickle Observation here.
        editor.undoManager.undo()

        #expect(editor.canUndo == false)
        #expect(editor.canRedo == true)
        #expect(editor.redoActionName.isEmpty == false)
    }

    @Test("withObservationTracking { _ = editor.canUndo } fires after a mutation")
    func observationTrackingFires() async throws {
        let editor = try await makeEditor()

        await confirmation("canUndo observation handler fires") { handlerFired in
            withObservationTracking {
                _ = editor.canUndo
            } onChange: {
                handlerFired()
            }

            let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
            try? await editor.perform(.deleteElement(sel))
        }
    }

    @Test("Two editors' tickles are isolated (object:-scoped notification)")
    func multiEditorIsolation() async throws {
        let editorA = try await makeEditor(["A", "B"])
        let editorB = try await makeEditor(["X", "Y"])

        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editorA.perform(.deleteElement(sel))

        // A mutated → A.canUndo flipped.
        #expect(editorA.canUndo == true)
        // B untouched → no tickle leak.
        #expect(editorB.canUndo == false)
    }
}
#endif
