import XCTest
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport

@available(*, deprecated, message: "Exercises the deprecated Mermaid compatibility surface.")
final class MermaidLegacyAPITests: XCTestCase {

    func testMermaidParserStillWorksThroughLoader() throws {
        let doc = try MermaidParser.parse("graph TD\nA-->B")
        XCTAssertEqual(doc.type, .flowchart)
    }

    func testDiagramEngineParseStillWorks() async throws {
        let doc = try await DiagramEngine.parse("graph TD\nA-->B")
        XCTAssertEqual(doc.type, .flowchart)
    }

    func testDiagramEngineRenderSVGStillWorks() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "graph TD\nA-->B",
            idPolicy: .stable
        )
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testStringParseDiagramStillWorks() async throws {
        let doc = try await "graph TD\nA-->B".parseDiagram()
        XCTAssertEqual(doc.type, .flowchart)
    }
}
