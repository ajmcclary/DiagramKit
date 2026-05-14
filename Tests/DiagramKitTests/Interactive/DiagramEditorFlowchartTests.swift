// Phase 9: Interactive Model Tests — Flowchart-specific mutations

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

// MARK: - Shared fixtures (duplicated from mutation tests for file independence)

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

// MARK: - DiagramEditorFlowchartTests

@Suite @MainActor
struct DiagramEditorFlowchartTests {

    @Test("insertNode adds node to flowchart")
    func insertNode() async throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performFlowchart(.insertNode(id: "B", label: "Node B"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.nodesInOrder.count == 2)
        #expect(model.nodesInOrder.contains(where: { $0.id == "B" }))
        #expect(model.nodesInOrder.first(where: { $0.id == "B" })?.node.label == "Node B")
    }

    @Test("insertNode with explicit type")
    func insertNodeWithType() async throws {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.performFlowchart(.insertNode(id: "D", label: "Decision", type: "diamond"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        let node = model.nodesInOrder.first(where: { $0.id == "D" })
        #expect(node?.node.shape == .diamond)
    }

    @Test("insertNode duplicate ID throws")
    func insertNodeDuplicate() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertNode(id: "A", label: "Duplicate"))
        }
    }

    @Test("insertNode on non-flowchart throws notAFlowchart")
    func insertNodeNonFlowchart() async {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertNode(id: "X", label: "X"))
        }
    }

    @Test("insertEdge creates edge between existing nodes")
    func insertEdge() async throws {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let from = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let to = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.performFlowchart(.insertEdge(id: "e1", from: from, to: to, label: "connects"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.count == 1)
        #expect(model.edges.first?.source == "A")
        #expect(model.edges.first?.target == "B")
        #expect(model.edges.first?.label == "connects")
    }

    @Test("insertEdge rejects endpoint selections from another diagram type")
    func insertEdgeSelectionTypeMismatch() async {
        let doc = flowDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let from = DiagramSelection(diagramType: .stateDiagram, elementID: "node:A")
        let to = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertEdge(id: "e1", from: from, to: to))
        }

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false))
            return
        }
        #expect(model.edges.isEmpty)
    }

    @Test("insertEdge with nonexistent source throws")
    func insertEdgeNonexistentSource() async {
        let doc = flowDoc(["B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let from = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        let to = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertEdge(id: "e", from: from, to: to))
        }
    }

    @Test("insertEdge with nonexistent target throws")
    func insertEdgeNonexistentTarget() async {
        let doc = flowDoc(["A"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let from = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let to = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertEdge(id: "e", from: from, to: to))
        }
    }

    @Test("insertEdge on non-flowchart throws notAFlowchart")
    func insertEdgeNonFlowchart() async {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .sequenceDiagram, elementID: "actor:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.insertEdge(id: "e", from: sel, to: sel))
        }
    }
}
