// Phase 9: Interactive Model Tests — Source sync and format-ID-driven export

import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

// MARK: - Mock exporters

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
        let nodeCount: Int
        if case .flowchart(let m) = document.payload { nodeCount = m.nodesInOrder.count }
        else { nodeCount = 0 }
        return DiagramExportResult(source: "mermaid-\(nodeCount)")
    }
}

/// Exporter that includes document title in output
private struct TitleAwareExporter: DiagramExporter {
    let name: String = "TitleAware"
    let formatID: DiagramFormatID = .d2
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .sequenceDiagram, .classDiagram]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        guard supportedDiagramTypes.contains(document.type) else {
            return DiagramExportResult(
                source: "",
                diagnostics: [DiagramDiagnostic(severity: .unsupported, message: "unsupported")]
            )
        }
        let titleLine = document.title.map { "title: \($0)\n" } ?? ""
        let nodeCount: Int
        if case .flowchart(let m) = document.payload { nodeCount = m.nodesInOrder.count }
        else { nodeCount = 0 }
        return DiagramExportResult(source: "\(titleLine)nodes: \(nodeCount)")
    }
}

// MARK: - Shared fixtures

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "N\(id)", shape: .rectangle))
    }
    let model = original_src_types.MermaidGraph(direction: .TD, nodesInOrder: mNodes, edges: [])
    return DiagramDocument(payload: .flowchart(model))
}

// MARK: - DiagramEditorSourceSyncTests

@Suite @MainActor
struct DiagramEditorSourceSyncTests {

    @Test("Source reflects mutations through preferred format")
    func sourceReflectsMutation() throws {
        let doc = flowDoc(["A"])
        let registry = ExporterRegistry.empty.registering(FlowchartOnlyExporter())
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: registry
        )
        try editor.syncSource()
        #expect(editor.source == "mermaid-1")

        // Insert a node
        try editor.performFlowchart(.insertNode(id: "B", label: "NB"))

        // Source should reflect the new node count
        #expect(editor.source == "mermaid-2")
    }

    @Test("Source sync captures title changes")
    func sourceSyncCapturesTitle() throws {
        let doc = DiagramDocument(type: .flowchart)
        let registry = ExporterRegistry.empty.registering(TitleAwareExporter())
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .d2,
            exportRegistry: registry
        )

        try editor.perform(.setTitle("Hello"))
        #expect(editor.source == "title: Hello\nnodes: 0")

        try editor.perform(.setTitle(nil))
        #expect(editor.source == "nodes: 0")
    }

    @Test("Source sync captures title changes through the real Mermaid exporter")
    func sourceSyncCapturesTitleWithMermaidExporter() throws {
        let doc = flowDoc(["A"])
        let registry = ExporterRegistry.empty.registering(MermaidExporter())
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: registry
        )

        try editor.perform(.setTitle("Real Title"))

        guard let source = editor.source else {
            Issue.record("Expected exported source")
            return
        }
        #expect(source.hasPrefix("---\ntitle: Real Title\n---\n"))

        let reparsed = try MermaidImporter().parse(source).document
        #expect(reparsed.title == "Real Title")
    }

    @Test("syncSource after init populates source")
    func syncSourceAfterInit() throws {
        let doc = flowDoc(["X", "Y"])
        let registry = ExporterRegistry.empty.registering(FlowchartOnlyExporter())
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: registry
        )
        #expect(editor.source == nil)
        try editor.syncSource()
        #expect(editor.source == "mermaid-2")
    }

    @Test("Format mismatch returns empty source with diagnostic")
    func formatMismatchReturnsEmpty() throws {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let registry = ExporterRegistry.empty.registering(FlowchartOnlyExporter())
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: registry
        )
        try editor.syncSource()
        #expect(editor.source == "")
        #expect(!editor.lastExportDiagnostics.isEmpty)
        #expect(editor.lastExportDiagnostics.contains { $0.severity == .unsupported })
    }

    @Test("No registered exporter throws")
    func noRegisteredExporterThrows() {
        let doc = DiagramDocument(type: .flowchart)
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty
        )
        #expect(throws: (any Error).self) {
            try editor.syncSource()
        }
    }
}
