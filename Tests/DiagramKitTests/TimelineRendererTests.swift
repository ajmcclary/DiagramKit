import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class TimelineRendererTests: XCTestCase {

    private func parseAndLayout(_ source: String) throws -> (DiagramDocument, PositionedTimelineDiagram) {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        let positioned = layoutTimelineDiagram(diagram)
        let graph = DiagramDocument(payload: .timeline(diagram))
        return (graph, positioned)
    }

    // MARK: - Basic rendering

    func test_renderLR_hasWidth() throws {
        let (_, positioned) = try parseAndLayout("timeline\n    2020 : Event")
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    func test_renderTD_hasWidth() throws {
        let (_, positioned) = try parseAndLayout("timeline TD\n    2020 : Event")
        XCTAssertEqual(positioned.direction, .TD)
        XCTAssertGreaterThan(positioned.width, 0)
    }

    func test_renderWithSections_hasSections() throws {
        let (_, positioned) = try parseAndLayout("""
        timeline
            section Era 1
            2020 : Event A
            section Era 2
            2021 : Event B
        """)
        XCTAssertEqual(positioned.sections.count, 2)
        XCTAssertEqual(positioned.tasks.count, 2)
    }

    func test_renderWithMultipleEvents_hasEvents() throws {
        let (_, positioned) = try parseAndLayout("""
        timeline
            2020 : E1 : E2 : E3 : E4 : E5
        """)
        XCTAssertEqual(positioned.events.count, 5)
    }

    func test_renderWithTitle_hasTitle() throws {
        let (_, positioned) = try parseAndLayout("""
        timeline
            title History
            2020 : Event
        """)
        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "History")
    }

    func test_renderEmptyDiagram_minimal() throws {
        let diagram = TimelineDiagram.empty
        let positioned = layoutTimelineDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 0)
        XCTAssertGreaterThanOrEqual(positioned.width, 0)
    }

    // MARK: - Accessibility

    func test_renderPreservesAccessibility() throws {
        let source = """
        timeline
            accTitle: Accessible Timeline
            accDescr: A description
            2020 : Event
        """
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        XCTAssertEqual(diagram.accTitle, "Accessible Timeline")
        XCTAssertEqual(diagram.accDescr, "A description")
    }

    // MARK: - End-to-end via pipeline

    func test_endToEnd_parseLayoutRenderSVG() throws {
        let source = """
        timeline
            title History
            2020 : COVID-19
            2021 : Vaccines
        """
        let svg = try _renderDiagramSVG(source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("COVID-19"))
        XCTAssertTrue(svg.contains("Vaccines"))
    }
}
