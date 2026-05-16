// FlowchartMutation.setEdgeStyle — apply, undo, error path.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        guard case .flowchart(let model) = document.payload else {
            return DiagramExportResult(source: "")
        }
        let edgeStyles = model.edges.map { $0.style.rawValue }.joined(separator: ",")
        return DiagramExportResult(source: "mock:edges=\(edgeStyles)")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func flowDocWithEdge() -> DiagramDocument {
    let nodes = ["A", "B"].map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: id, shape: .rectangle))
    }
    let edge = original_src_types.MermaidEdge(
        source: "A",
        target: "B",
        label: nil,
        style: .solid,
        id: "e1"
    )
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: nodes,
        edges: [edge]
    )
    return DiagramDocument(payload: .flowchart(model))
}

@Suite @MainActor
struct FlowchartEdgeStyleMutationTests {

    @Test("setEdgeStyle changes the style of a matching edge")
    func setsStyle() async throws {
        let editor = DiagramEditor(
            document: flowDocWithEdge(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performFlowchart(
            .setEdgeStyle(edgeId: "e1", source: "A", target: "B", to: .dotted)
        )
        guard case .flowchart(let model) = editor.document.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        #expect(model.edges.count == 1)
        #expect(model.edges[0].style == .dotted)
        #expect(editor.canUndo)
    }

    @Test("setEdgeStyle matches by source+target when edgeId is nil")
    func matchesBySourceTarget() async throws {
        let editor = DiagramEditor(
            document: flowDocWithEdge(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performFlowchart(
            .setEdgeStyle(edgeId: nil, source: "A", target: "B", to: .thick)
        )
        guard case .flowchart(let model) = editor.document.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        #expect(model.edges[0].style == .thick)
    }

    @Test("setEdgeStyle throws elementNotFound when no edge matches")
    func throwsWhenMissing() async throws {
        let editor = DiagramEditor(
            document: flowDocWithEdge(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(
                .setEdgeStyle(edgeId: nil, source: "C", target: "D", to: .dotted)
            )
        }
    }

    @Test("undo restores the prior edge style")
    func undoRestoresStyle() async throws {
        let editor = DiagramEditor(
            document: flowDocWithEdge(),
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performFlowchart(
            .setEdgeStyle(edgeId: "e1", source: "A", target: "B", to: .dotted)
        )
        editor.undoManager.undo()
        guard case .flowchart(let model) = editor.document.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        #expect(model.edges[0].style == .solid)
    }
}
