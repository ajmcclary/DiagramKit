// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 1 — setNodeStyle mutation through StyleClassManager.

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

private func flowDoc(
    _ nodes: [String],
    nodeStyles: [String: [String: String]] = [:]
) -> DiagramDocument {
    let mNodes = nodes.map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    return DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(
            direction: .TD, nodesInOrder: mNodes, edges: [], nodeStyles: nodeStyles
        )
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

private let greenSpec = NodeStyleSpec(fill: "#e8f5e9", stroke: "#2e7d32")

@Suite @MainActor
struct FlowchartNodeStyleMutationTests {

    @Test("setNodeStyle creates classDef and assignment")
    func createsClass() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.classDefs["vs1"] == greenSpec.classDefProperties)
        #expect(model.classAssignments["A"] == ["vs1"])
    }

    @Test("inline-style migration surfaces the info diagnostic on the editor")
    func migrationDiagnosticSurfaces() async throws {
        let editor = makeEditor(flowDoc(["A"], nodeStyles: ["A": ["fill": "#ff0000"]]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        #expect(editor.lastExportDiagnostics.contains { $0.category == .styleClassMigration })
    }

    @Test("missing node throws elementNotFound")
    func missingNode() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        }
    }

    @Test("undo restores previous classDefs and assignments")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.classDefs.isEmpty)
        #expect(model.classAssignments.isEmpty)
    }
}
#endif
