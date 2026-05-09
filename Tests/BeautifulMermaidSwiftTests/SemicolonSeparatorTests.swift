import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class SemicolonSeparatorTests: XCTestCase {

    // MARK: - Semicolon-separated diagrams render without error

    func testFlowchartWithSemicolonSeparator() async throws {
        let svg = try await renderMermaidSVG("graph LR; A --> B")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
        XCTAssertFalse(svg.contains("Syntax error"), "Should not contain syntax error")
    }

    func testFlowchartTDWithMultipleSemicolons() async throws {
        let svg = try await renderMermaidSVG("graph TD; A --> B; B --> C")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    func testSequenceDiagramWithSemicolon() async throws {
        let svg = try await renderMermaidSVG("sequenceDiagram; Alice ->> Bob: hi")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    func testErDiagramWithSemicolon() async throws {
        let svg = try await renderMermaidSVG("erDiagram; CUSTOMER ||--o{ ORDER : places")
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
    }

    // MARK: - Newline-separated diagrams still work (regression check)

    func testFlowchartWithNewlines() async throws {
        let svg = try await renderMermaidSVG("""
            graph LR
                A --> B
                B --> C
            """)
        XCTAssertTrue(svg.contains("<svg"), "Newline-separated diagram should still work")
    }

    func testSequenceDiagramWithNewlines() async throws {
        let svg = try await renderMermaidSVG("""
            sequenceDiagram
                Alice ->> Bob: hello
            """)
        XCTAssertTrue(svg.contains("<svg"), "Newline-separated sequence diagram should still work")
    }
}
