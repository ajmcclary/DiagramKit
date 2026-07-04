// Visual editor plan 3 — subgraph forest mutations.
// MermaidSubgraph is a reference type; these tests deliberately pin
// undo integrity (deep-copy correctness) for every mutation.

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

/// Flowchart with nodes A,B,C and one subgraph g1 [Group One] holding [A, B].
private func groupedDoc() -> DiagramDocument {
    let nodes = ["A", "B", "C"].map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    let sub = original_src_types.MermaidSubgraph(id: "g1", label: "Group One", nodeIds: ["A", "B"])
    let model = original_src_types.MermaidGraph(
        direction: .TD, nodesInOrder: nodes,
        edges: [original_src_types.MermaidEdge(source: "A", target: "C", style: .solid)],
        subgraphs: [sub]
    )
    return DiagramDocument(payload: .flowchart(model))
}

@MainActor
private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@MainActor
private func subgraphs(_ editor: DiagramEditor) -> [original_src_types.MermaidSubgraph] {
    guard case .flowchart(let model) = editor.document.payload else { return [] }
    return model.subgraphs
}

private func node(_ sel: String) -> DiagramSelection {
    DiagramSelection(diagramType: .flowchart, elementID: "node:\(sel)")
}

@Suite @MainActor
struct FlowchartSubgraphOpsTests {

    // MARK: - insertSubgraph

    @Test("insertSubgraph adds an empty subgraph with the title as label")
    func insertEmpty() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Fresh Group"))
        let subs = subgraphs(editor)
        #expect(subs.count == 2)
        let fresh = subs.first { $0.label == "Fresh Group" }
        #expect(fresh != nil)
        #expect(fresh?.nodeIds.isEmpty == true)
    }

    @Test("two insertSubgraph calls with the same title mint distinct ids")
    func insertTwiceSameTitle() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Twin"))
        try await editor.performFlowchart(.insertSubgraph(title: "Twin"))
        let ids = subgraphs(editor).map(\.id)
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3)
    }

    @Test("insertSubgraph undo removes the subgraph")
    func insertUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Ephemeral"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).count == 1)
    }

    @Test("empty subgraph source renders without crashing")
    func emptySubgraphRenders() async throws {
        let source = "graph TD\n  subgraph empty_1 [Empty]\n  end\n  A[Solo]\n"
        let svg = try await source.renderDiagramSVG()
        #expect(svg.contains("<svg"))
    }
}
