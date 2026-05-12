import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport

@Suite struct MermaidImporterTests {

    @Test("MermaidImporter parses flowchart source")
    func parsesFlowchart() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("graph TD\nA[Start] --> B[End]")
        #expect(result.document.type == .flowchart)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("MermaidImporter parses sequence diagram source")
    func parsesSequence() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("sequenceDiagram\nAlice->>Bob: Hello")
        #expect(result.document.type == .sequenceDiagram)
    }

    @Test("MermaidImporter supportedDiagramTypes covers all cases")
    func coversAllDiagramTypes() {
        let importer = MermaidImporter()
        #expect(importer.supportedDiagramTypes.count == DiagramType.allCases.count)
    }

    @Test("MermaidImporter returns empty diagnostics for clean parse")
    func cleanParseHasNoDiagnostics() throws {
        let importer = MermaidImporter()
        let result = try importer.parse("graph TD\nA-->B")
        #expect(result.diagnostics.isEmpty)
    }
}
