import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport

@Suite struct MermaidLegacyAPITests {

    @Test("MermaidParser.parse still works through loader")
    func mermaidParserStillWorks() throws {
        let doc = try MermaidParser.parse("graph TD\nA-->B")
        #expect(doc.type == .flowchart)
    }

    @Test("DiagramEngine.parse still works")
    func diagramEngineParseStillWorks() async throws {
        let doc = try await DiagramEngine.parse("graph TD\nA-->B")
        #expect(doc.type == .flowchart)
    }

    @Test("DiagramEngine.renderSVG still works")
    func diagramEngineRenderSVGStillWorks() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "graph TD\nA-->B",
            idPolicy: .stable
        )
        #expect(svg.contains("<svg"))
    }

    @Test("String.parseDiagram still works")
    func stringParseDiagramStillWorks() async throws {
        let doc = try await "graph TD\nA-->B".parseDiagram()
        #expect(doc.type == .flowchart)
    }
}
