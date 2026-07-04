// Visual editor plan 1 — setNodeShape mutation.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram]
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock")
    }
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    return DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(direction: .TD, nodesInOrder: mNodes, edges: [])
    ))
}

@MainActor
private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@Suite @MainActor
struct FlowchartNodeShapeMutationTests {

    @Test("setNodeShape changes an existing node's shape")
    func changesShape() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .diamond)
    }

    @Test("setNodeShape accepts v11 aliases")
    func v11Alias() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "docs"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .stackedDocument)
    }

    @Test("unknown alias throws unknownShapeAlias and leaves state untouched")
    func unknownAlias() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "not-a-shape"))
        }
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .rectangle)
    }

    @Test("missing node throws elementNotFound")
    func missingNode() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        }
    }

    @Test("edge selection throws unknownElementKind")
    func edgeSelection() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "edge:A->B")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        }
    }

    @Test("undo restores the previous shape")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .rectangle)
    }
}
