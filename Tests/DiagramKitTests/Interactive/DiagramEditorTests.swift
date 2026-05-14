// Phase 9: Interactive Model Tests — DiagramEditor initialization and selection

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

/// A mock exporter that returns deterministic source for any supported type.
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
        // Deterministic mock output based on node count
        let nodeCount: Int
        switch document.payload {
        case .flowchart(let m): nodeCount = m.nodesInOrder.count
        case .stateDiagram(let m): nodeCount = m.nodesInOrder.count
        default: nodeCount = 0
        }
        return DiagramExportResult(source: "mock-diagram-\(document.type.rawValue)-\(nodeCount)")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func makeFlowchartDocument(nodeIDs: [String]) -> DiagramDocument {
    let nodes = nodeIDs.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: nodes,
        edges: []
    )
    return DiagramDocument(payload: .flowchart(model))
}

// MARK: - DiagramEditorTests

@Suite @MainActor
struct DiagramEditorTests {

    @Test("Init with document, format, and registry")
    func initDocumentFormatRegistry() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        #expect(editor.document.type == .flowchart)
        #expect(editor.preferredExportFormat == .mermaid)
        #expect(editor.source == nil)
        #expect(editor.selection == nil)
        #expect(editor.lastExportDiagnostics.isEmpty)
        #expect(editor.undoManager.levelsOfUndo == 50)
    }

    @Test("syncSource() populates source after init")
    func syncSourcePopulatesSource() async throws {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        try await editor.syncSource()
        #expect(editor.source == "mock-diagram-flowchart-0")
        #expect(editor.lastExportDiagnostics.isEmpty)
    }

    @Test("syncSource() with unsupported format returns empty source with diagnostics")
    func syncSourceUnsupportedFormat() async throws {
        // Use a registry with an exporter that supports the format but not
        // the diagram type — this returns empty source + diagnostics rather
        // than throwing.
        let flowOnly = FlowchartOnlyExporter()
        let registry = ExporterRegistry.empty.registering(flowOnly)
        let doc = DiagramDocument(type: .sequenceDiagram)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: registry
        )
        try await editor.syncSource()
        // Exporter exists but doesn't support sequenceDiagram → empty source + diagnostic
        #expect(editor.source == "")
        #expect(!editor.lastExportDiagnostics.isEmpty)
        #expect(editor.lastExportDiagnostics.contains { $0.severity == .unsupported })
    }

    /// Exporter that supports only flowcharts
    private struct FlowchartOnlyExporter: DiagramExporter {
        let name: String = "FlowOnly"
        let formatID: DiagramFormatID = .mermaid
        let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

        func export(_ document: DiagramDocument) throws -> DiagramExportResult {
            guard supportedDiagramTypes.contains(document.type) else {
                return DiagramExportResult(
                    source: "",
                    diagnostics: [DiagramDiagnostic(severity: .unsupported, message: "flowchart only")]
                )
            }
            return DiagramExportResult(source: "mermaid-ok")
        }
    }

    @Test("Selection set and get")
    func selectionSetGet() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        #expect(editor.selection == nil)

        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        editor.selection = sel
        #expect(editor.selection == sel)
    }

    @Test("UndoManager is accessible and configured")
    func undoManagerAccessible() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        #expect(editor.undoManager.levelsOfUndo == 50)
    }

    @Test("maximumUndoDepth forwarding")
    func maximumUndoDepthForwarding() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        editor.maximumUndoDepth = 10
        #expect(editor.undoManager.levelsOfUndo == 10)
        #expect(editor.maximumUndoDepth == 10)
    }

    @Test("preferredExportFormat is immutable")
    func preferredExportFormatImmutable() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        // preferredExportFormat is `let` — verified by compilation
        #expect(editor.preferredExportFormat == .mermaid)
    }
}
