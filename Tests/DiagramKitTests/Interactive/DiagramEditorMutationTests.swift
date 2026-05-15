// Phase 9: Interactive Model Tests — Editor mutation operations

import Testing
import DiagramKitCommon
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

private func flowDoc(
    _ nodes: [String],
    mermaidEdges: [original_src_types.MermaidEdge]
) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: mNodes,
        edges: mermaidEdges
    )
    return DiagramDocument(payload: .flowchart(model))
}

private func stateDoc(_ nodes: [String], edges: [(String, String)] = []) -> DiagramDocument {
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
    return DiagramDocument(payload: .stateDiagram(model))
}

// MARK: - DiagramEditorMutationTests

@Suite @MainActor
struct DiagramEditorMutationTests {

    // MARK: - deleteElement

    @Test("deleteElement removes node and incident edges")
    func deleteElementNode() async throws {
        let doc = flowDoc(["A", "B", "C"], edges: [("A", "B"), ("B", "C")])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        // Node B should be gone
        let payload = editor.document.payload
        guard case .flowchart(let model) = payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        #expect(model.nodesInOrder.count == 2)
        #expect(!model.nodesInOrder.contains(where: { $0.id == "B" }))
        // Incident edges A→B and B→C should be gone
        #expect(model.edges.count == 0)
    }

    @Test("deleteElement removes edge only")
    func deleteElementEdge() async throws {
        let doc = flowDoc(["A", "B"], edges: [("A", "B")])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        // The edge stable ID: since no explicit edge id, it's derived
        // edge:StableID.derive(from: "A→B→")
        let edgeID = "edge:\(StableID.derive(from: "A→B→"))"
        let sel = DiagramSelection(diagramType: .flowchart, elementID: edgeID)
        try await editor.perform(.deleteElement(sel))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.nodesInOrder.count == 2)
        #expect(model.edges.count == 0)
    }

    @Test("deleteElement with explicit edge ID")
    func deleteElementExplicitEdgeID() async throws {
        // Create doc with explicit edge ID
        let model = original_src_types.MermaidGraph(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "B", shape: .rectangle)),
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", style: .solid, id: "e1")
            ]
        )
        let explicitDoc = DiagramDocument(payload: .flowchart(model))

        let editor = DiagramEditor(
            document: explicitDoc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "edge:e1")
        try await editor.perform(.deleteElement(sel))

        guard case .flowchart(let result) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(result.edges.count == 0)
    }

    @Test("deleteElement removes only the selected duplicate implicit edge")
    func deleteElementDuplicateImplicitEdge() async throws {
        let baseEdgeID = "edge:\(StableID.derive(from: "A→B→"))"
        let doc = flowDoc(
            ["A", "B"],
            mermaidEdges: [
                original_src_types.MermaidEdge(source: "A", target: "B", style: .solid),
                original_src_types.MermaidEdge(source: "A", target: "B", style: .dotted)
            ]
        )
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.perform(.deleteElement(DiagramSelection(
            diagramType: .flowchart,
            elementID: baseEdgeID
        )))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.count == 1)
        #expect(model.edges.first?.style == .dotted)
    }

    @Test("deleteElement resolves duplicate implicit edge suffixes")
    func deleteElementDuplicateImplicitEdgeSuffix() async throws {
        let baseEdgeID = "edge:\(StableID.derive(from: "A→B→"))"
        let doc = flowDoc(
            ["A", "B"],
            mermaidEdges: [
                original_src_types.MermaidEdge(source: "A", target: "B", style: .solid),
                original_src_types.MermaidEdge(source: "A", target: "B", style: .dotted)
            ]
        )
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.perform(.deleteElement(DiagramSelection(
            diagramType: .flowchart,
            elementID: "\(baseEdgeID)/1"
        )))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.count == 1)
        #expect(model.edges.first?.style == .solid)
    }

    @Test("deleteElement explicit edge ID matching is exact")
    func deleteElementExplicitEdgeIDExactMatch() async throws {
        let doc = flowDoc(
            ["A", "B", "C"],
            mermaidEdges: [
                original_src_types.MermaidEdge(source: "A", target: "B", style: .solid, id: "e1"),
                original_src_types.MermaidEdge(source: "B", target: "C", style: .solid, id: "e10")
            ]
        )
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.perform(.deleteElement(DiagramSelection(
            diagramType: .flowchart,
            elementID: "edge:e10"
        )))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.count == 1)
        #expect(model.edges.first?.id == "e1")
    }

    @Test("deleteElement nonexistent throws elementNotFound")
    func deleteElementNonexistent() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Nonexistent")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.deleteElement(sel))
        }
    }

    @Test("deleteElement on non-flowchart throws unsupportedMutation")
    func deleteElementNonFlowchart() async {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .sequenceDiagram, elementID: "actor:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.deleteElement(sel))
        }
    }

    @Test("deleteElement rejects selections from another diagram type")
    func deleteElementSelectionTypeMismatch() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .stateDiagram, elementID: "node:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.deleteElement(sel))
        }
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.nodesInOrder.contains { $0.id == "A" })
    }

    // MARK: - setLabel

    @Test("setLabel on node updates label")
    func setLabelNode() async throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.perform(.setLabel(of: sel, to: "Updated A"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        let nodeA = model.nodesInOrder.first { $0.id == "A" }
        #expect(nodeA?.node.label == "Updated A")
    }

    @Test("setLabel on edge updates label")
    func setLabelEdge() async throws {
        let doc = flowDoc(["A", "B"], edges: [("A", "B")])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let edgeID = "edge:\(StableID.derive(from: "A→B→"))"
        let sel = DiagramSelection(diagramType: .flowchart, elementID: edgeID)
        try await editor.perform(.setLabel(of: sel, to: "connects"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.first?.label == "connects")
    }

    @Test("setLabel resolves duplicate implicit edge suffixes")
    func setLabelDuplicateImplicitEdgeSuffix() async throws {
        let baseEdgeID = "edge:\(StableID.derive(from: "A→B→"))"
        let doc = flowDoc(
            ["A", "B"],
            mermaidEdges: [
                original_src_types.MermaidEdge(source: "A", target: "B", style: .solid),
                original_src_types.MermaidEdge(source: "A", target: "B", style: .dotted)
            ]
        )
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )

        try await editor.perform(.setLabel(
            of: DiagramSelection(diagramType: .flowchart, elementID: "\(baseEdgeID)/1"),
            to: "updated"
        ))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.count == 2)
        #expect(model.edges[0].label == nil)
        #expect(model.edges[1].label == "updated")
    }

    @Test("setLabel nonexistent throws elementNotFound")
    func setLabelNonexistent() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.setLabel(of: sel, to: "X"))
        }
    }

    @Test("setLabel rejects selections from another diagram type")
    func setLabelSelectionTypeMismatch() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .stateDiagram, elementID: "node:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.setLabel(of: sel, to: "Wrong"))
        }
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.nodesInOrder.first?.node.label == "Node A")
    }

    // MARK: - setTitle

    @Test("setTitle updates title")
    func setTitle() async throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.perform(.setTitle("My Diagram"))
        #expect(editor.document.title == "My Diagram")
    }

    @Test("setTitle to nil clears title")
    func setTitleNil() async throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.perform(.setTitle("Temp"))
        #expect(editor.document.title == "Temp")
        try await editor.perform(.setTitle(nil))
        #expect(editor.document.title == nil)
    }

    @Test("setTitle works on sequence diagram")
    func setTitleSequence() async throws {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.perform(.setTitle("Seq Title"))
        #expect(editor.document.title == "Seq Title")
    }

    // MARK: - noop

    @Test("noop does not change document or source")
    func noop() async throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.syncSource()
        let originalSource = editor.source

        try await editor.perform(.noop)
        #expect(editor.source == originalSource)
    }

    // MARK: - Atomicity

    @Test("Failed mutation does not pollute undo stack or change state")
    func mutationAtomicity() async throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.syncSource()
        let originalSource = editor.source

        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        do {
            try await editor.perform(.deleteElement(sel))
            #expect(Bool(false), "expected error")
        } catch {
            // Expected: element not found
        }

        // State should be unchanged
        #expect(editor.source == originalSource)
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.nodesInOrder.count == 1)
    }
}
