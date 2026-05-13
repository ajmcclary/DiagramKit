// Phase 9: Interactive Model Tests — Undo/redo and atomicity

import Testing
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

// MARK: - Shared fixtures

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram, .sequenceDiagram]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        guard supportedDiagramTypes.contains(document.type) else {
            return DiagramExportResult(
                source: "",
                diagnostics: [DiagramDiagnostic(severity: .unsupported, message: "unsupported")]
            )
        }
        let nodeCount: Int
        switch document.payload {
        case .flowchart(let m): nodeCount = m.nodesInOrder.count
        case .stateDiagram(let m): nodeCount = m.nodesInOrder.count
        default: nodeCount = 0
        }
        return DiagramExportResult(source: "mock:\(document.type.rawValue)-n\(nodeCount)")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func flowDoc(_ nodes: [String], edges: [(String, String)] = []) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let mEdges = edges.map { (src, tgt) in
        original_src_types.MermaidEdge(source: src, target: tgt, style: .solid)
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: mNodes,
        edges: mEdges
    )
    return DiagramDocument(payload: .flowchart(model))
}

// MARK: - DiagramEditorUndoTests

@Suite @MainActor
struct DiagramEditorUndoTests {

    @Test("Single mutation undo restores previous document and source")
    func singleUndoRestores() throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try editor.syncSource()
        let originalSource = editor.source

        // Perform a mutation
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try editor.perform(.deleteElement(sel))

        // Verify mutation applied
        guard case .flowchart(let afterDelete) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(afterDelete.nodesInOrder.count == 1)

        // Undo
        editor.undoManager.undo()

        // Verify restored
        guard case .flowchart(let afterUndo) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(afterUndo.nodesInOrder.count == 2)
        #expect(afterUndo.nodesInOrder.contains(where: { $0.id == "B" }))
        #expect(editor.source == originalSource)
    }

    @Test("Single mutation redo reapplies mutation")
    func singleRedoReapplies() throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try editor.perform(.deleteElement(sel))

        // Undo
        editor.undoManager.undo()
        guard case .flowchart(let afterUndo) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(afterUndo.nodesInOrder.count == 2)

        // Redo
        editor.undoManager.redo()
        guard case .flowchart(let afterRedo) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(afterRedo.nodesInOrder.count == 1)
    }

    @Test("Undo after multiple sequential mutations restores to initial state")
    func sequentialMutationsUndo() throws {
        let doc = flowDoc(["A", "B", "C"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        // Apply two sequential mutations (same implicit group)
        try editor.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:B")))
        try editor.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Changed"))

        // Without explicit grouping, UndoManager groups sequential
        // mutations with the same target into one undo step.
        editor.undoManager.undo()

        // After undo, everything should be restored
        guard case .flowchart(let afterUndo) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(afterUndo.nodesInOrder.count == 3)
        #expect(afterUndo.nodesInOrder.contains(where: { $0.id == "B" }))
        #expect(afterUndo.nodesInOrder.first(where: { $0.id == "A" })?.node.label == "Node A")
    }

    @Test("Undo grouping: beginUndoGrouping/endUndoGrouping → one undo step")
    func undoGrouping() throws {
        let doc = flowDoc(["A", "B", "C"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        editor.beginUndoGrouping()
        try editor.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:B")))
        try editor.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:C")))
        editor.endUndoGrouping()

        // Both mutations should be grouped as one undo step
        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        // Both nodes should be restored
        #expect(model.nodesInOrder.count == 3)
    }

    @Test("Redo after undo reapplies mutation")
    func redoAfterUndo() throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try editor.perform(.setTitle("New Title"))

        #expect(editor.document.title == "New Title")
        editor.undoManager.undo()
        #expect(editor.document.title == nil)

        editor.undoManager.redo()
        #expect(editor.document.title == "New Title")
    }

    @Test("Undo action name matches mutation")
    func undoActionName() throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try editor.perform(.setTitle("T"))
        #expect(editor.undoManager.undoActionName == "Set Title")
    }

    @Test("Failed mutation does not pollute undo stack")
    func failedMutationCleanUndo() throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        // First, a successful mutation
        try editor.perform(.setTitle("Before"))
        #expect(editor.document.title == "Before")

        // Then, a failed mutation
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        do {
            try editor.perform(.deleteElement(sel))
            #expect(Bool(false), "expected error")
        } catch {
            // Expected
        }

        // Undo should undo the successful mutation only
        editor.undoManager.undo()
        #expect(editor.document.title == nil)
    }

    @Test("Depth limiting forwards to UndoManager")
    func depthLimitingForwarded() throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        editor.maximumUndoDepth = 10
        #expect(editor.undoManager.levelsOfUndo == 10)

        editor.maximumUndoDepth = 3
        #expect(editor.undoManager.levelsOfUndo == 3)
    }

    @Test("Multiple mutations can be undone at least once")
    func multipleMutationCanUndo() throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        // Apply several mutations
        try editor.perform(.setTitle("T1"))
        try editor.perform(.setTitle("T2"))
        try editor.perform(.setTitle("T3"))

        #expect(editor.document.title == "T3")
        #expect(editor.undoManager.canUndo)

        editor.undoManager.undo()

        // After undo, title should be nil (all grouped mutations undone)
        #expect(editor.document.title == nil)
        #expect(!editor.undoManager.canUndo)
    }
}
