// Phase 5 / Task 5.1 — FlowchartMutation.groupIntoSubgraph applier
// + snapshot-undo inverse + .invalidSubgraphSelection error.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

// MARK: - Fixtures (mirroring DiagramEditorFlowchartTests)

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
        let subgraphCount: Int
        switch document.payload {
        case .flowchart(let m): subgraphCount = m.subgraphs.count
        default:                subgraphCount = 0
        }
        return DiagramExportResult(source: "mock:flowchart-sub\(subgraphCount)")
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

private func nodeSelection(_ id: String) -> DiagramSelection {
    DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)")
}

// MARK: - Tests

@Suite @MainActor
struct FlowchartSubgraphMutationTests {

    @Test("groupIntoSubgraph wraps three nodes")
    func groupsThreeNodes() async throws {
        let doc = flowDoc(["A", "B", "C", "D"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.performFlowchart(
            .groupIntoSubgraph(
                selections: [nodeSelection("A"), nodeSelection("B"), nodeSelection("C")],
                title: "renderers"
            )
        )

        guard case .flowchart(let model) = editor.document.payload else {
            Issue.record("expected flowchart payload after group mutation")
            return
        }
        #expect(model.subgraphs.count == 1)
        let subgraph = model.subgraphs[0]
        #expect(subgraph.label == "renderers")
        #expect(Set(subgraph.nodeIds) == Set(["A", "B", "C"]))
        #expect(subgraph.id.hasPrefix("renderers_"))
        #expect(editor.canUndo)
    }

    @Test("undo removes the subgraph")
    func undoFlattens() async throws {
        let doc = flowDoc(["A", "B", "C"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.performFlowchart(
            .groupIntoSubgraph(
                selections: [nodeSelection("A"), nodeSelection("B")],
                title: "groupA"
            )
        )

        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            Issue.record("expected flowchart payload after undo")
            return
        }
        #expect(model.subgraphs.isEmpty)
    }

    @Test("empty selection raises invalidSubgraphSelection")
    func rejectsEmpty() async throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(
                .groupIntoSubgraph(selections: [], title: "anything")
            )
        }
    }

    @Test("non-node selection raises invalidSubgraphSelection")
    func rejectsNonNode() async throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        let edgeSel = DiagramSelection(diagramType: .flowchart, elementID: "edge:e1")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(
                .groupIntoSubgraph(selections: [edgeSel], title: "bad")
            )
        }
    }

    @Test("subgraphID is deterministic for the same inputs")
    func subgraphIDDeterministic() {
        let id1 = DiagramEditor.subgraphID(title: "renderers", members: ["A", "B", "C"])
        let id2 = DiagramEditor.subgraphID(title: "renderers", members: ["C", "B", "A"])
        let id3 = DiagramEditor.subgraphID(title: "renderers", members: ["A", "B", "D"])
        #expect(id1 == id2) // member order doesn't matter
        #expect(id1 != id3) // different members ⇒ different id
    }
}
