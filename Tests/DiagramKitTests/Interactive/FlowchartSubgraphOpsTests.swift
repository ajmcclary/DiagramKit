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

    // MARK: - moveToSubgraph

    @Test("moveToSubgraph adds a root node to the target subgraph")
    func moveIntoGroup() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("C")], target: "g1"))
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B", "C"])
    }

    @Test("moveToSubgraph with nil target moves a member to root")
    func moveToRoot() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: nil))
        #expect(subgraphs(editor).first?.nodeIds == ["B"])
    }

    @Test("moveToSubgraph between groups removes from the old group")
    func moveBetweenGroups() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Second"))
        let secondID = subgraphs(editor).first { $0.label == "Second" }!.id
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: secondID))
        let subs = subgraphs(editor)
        #expect(subs.first { $0.id == "g1" }?.nodeIds == ["B"])
        #expect(subs.first { $0.id == secondID }?.nodeIds == ["A"])
    }

    @Test("moveToSubgraph unknown target throws elementNotFound")
    func moveUnknownTarget() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.moveToSubgraph(selections: [node("C")], target: "nope"))
        }
    }

    @Test("moveToSubgraph undo restores previous membership (deep-copy pin)")
    func moveUndoRestoresMembership() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: nil))
        editor.undoManager.undo()
        // Fails if the mutation edited the shared MermaidSubgraph
        // instance instead of a deep copy.
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B"])
    }

    // MARK: - ungroupSubgraph

    @Test("ungroupSubgraph removes the group, keeps nodes and edges")
    func ungroupRoot() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.ungroupSubgraph(id: "g1"))
        #expect(subgraphs(editor).isEmpty)
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.count == 3)
        #expect(model.edges.count == 1)
    }

    @Test("ungroup nested subgraph promotes members and children to parent")
    func ungroupNested() async throws {
        let inner = original_src_types.MermaidSubgraph(id: "inner", label: "Inner", nodeIds: ["B"])
        let outer = original_src_types.MermaidSubgraph(
            id: "outer", label: "Outer", nodeIds: ["A"], children: [inner]
        )
        let nodes = ["A", "B"].map {
            (id: $0, node: original_src_types.MermaidNode(id: $0, label: $0, shape: .rectangle))
        }
        let model = original_src_types.MermaidGraph(
            direction: .TD, nodesInOrder: nodes, edges: [], subgraphs: [outer]
        )
        let editor = makeEditor(DiagramDocument(payload: .flowchart(model)))

        try await editor.performFlowchart(.ungroupSubgraph(id: "inner"))

        let subs = subgraphs(editor)
        #expect(subs.count == 1)
        #expect(subs.first?.id == "outer")
        #expect(Set(subs.first?.nodeIds ?? []) == Set(["A", "B"]))
        #expect(subs.first?.children.isEmpty == true)
    }

    @Test("ungroup unknown id throws")
    func ungroupUnknown() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.ungroupSubgraph(id: "nope"))
        }
    }

    @Test("ungroup undo restores the group (deep-copy pin)")
    func ungroupUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.ungroupSubgraph(id: "g1"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).count == 1)
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B"])
    }

    // MARK: - renameSubgraph

    @Test("renameSubgraph changes the label and keeps the id")
    func rename() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.renameSubgraph(id: "g1", title: "Renamed"))
        #expect(subgraphs(editor).first?.label == "Renamed")
        #expect(subgraphs(editor).first?.id == "g1")
    }

    @Test("rename unknown id throws")
    func renameUnknown() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.renameSubgraph(id: "nope", title: "X"))
        }
    }

    @Test("rename undo restores the old label (deep-copy pin)")
    func renameUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.renameSubgraph(id: "g1", title: "Renamed"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).first?.label == "Group One")
    }
}
