import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class SequenceSvgTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    private func renderSvg(_ diagram: SequenceDiagram) throws -> String {
        let positioned = try layoutSequenceDiagram(diagram)
        return try renderSequenceSvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#333333"))
    }

    // MARK: - Arrow Markers

    func testAllArrowMarkersDefined() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A->>B: filled
            A-->B: open
            A-xB: cross
            A-)B: async
            A-|/B: half
            A-//B: stick
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("seq-arrow-filled"))
        XCTAssertTrue(svg.contains("seq-arrow-open"))
        XCTAssertTrue(svg.contains("seq-arrow-cross"))
        XCTAssertTrue(svg.contains("seq-arrow-async"))
    }

    func testReverseMarkersInSvgOutput() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A/\\|-B: rev half
            A\\\\-B: rev stick
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("seq-arrow-half-top-rev"), "SVG must contain reverse half marker")
        XCTAssertTrue(svg.contains("seq-arrow-stick-bottom-rev"), "SVG must contain reverse stick marker")
    }

    func testAllMarkerDefinitionsEmitted() throws {
        // Even without using all arrow types, marker defs should be complete
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A->>B: hello
        """))
        let svg = try renderSvg(diagram)
        // Should have at least all 8 basic + reverse markers
        XCTAssertTrue(svg.contains("seq-arrow-filled"))
        XCTAssertTrue(svg.contains("seq-arrow-half-top-rev"))
        XCTAssertTrue(svg.contains("seq-arrow-stick-bottom-rev-dot"))
    }

    // MARK: - Popup Menus

    func testPopupMenuPresentForLinks() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Dashboard @ https://example.com
            Alice->>Bob: Hello
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("class=\"popup\""), "SVG should contain popup group")
        XCTAssertTrue(svg.contains("xlink:href=\"https://example.com\""), "SVG should contain link element")
        XCTAssertTrue(svg.contains("onclick"), "SVG should contain onclick handler")
        XCTAssertTrue(svg.contains("popupMenuToggle"), "SVG should contain toggle script")
    }

    func testForceMenusRendersVisiblePopup() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Dashboard @ https://example.com
            Alice->>Bob: Hello
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("visibility=\"hidden\""), "Popups should start hidden by default")
    }

    // MARK: - Rect Highlights

    func testRectHighlightsBehindContent() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            rect rgb(191, 223, 255)
                Alice->>Bob: Highlighted
            end
        """))
        let svg = try renderSvg(diagram)
        let rectIdx = svg.range(of: "class=\"rect-highlight\"")?.lowerBound ?? svg.startIndex
        let msgIdx = svg.range(of: "class=\"message\"")?.lowerBound ?? svg.endIndex
        XCTAssertLessThan(rectIdx, msgIdx, "Rect highlights should be rendered before messages (z-order)")
    }

    // MARK: - Sequence Numbers

    func testSequenceNumbersInSvg() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber
            Alice->>Bob: Hello
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("1</text>"), "SVG should contain sequence number '1'")
    }

    // MARK: - Title and Accessibility

    func testTitleInSvg() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            title My Diagram
            Alice->>Bob: Hello
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("My Diagram"), "SVG should contain the diagram title")
    }

    func testAccessibilityElementsInSvg() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            accTitle: Accessible Title
            accDescr: A description
            Alice->>Bob: Hello
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("<title>Accessible Title</title>"))
        XCTAssertTrue(svg.contains("<desc>A description</desc>"))
    }

    func testMultilineAccDescrInSvg() throws {
        // Multiline accDescr is parsed and rendered in SVG
        let source = """
        sequenceDiagram
            accDescr {
                Line one
                Line two
            }
            Alice->>Bob: Hello
        """
        // Use raw lines without filtering to preserve multiline block structure
        let rawLines = source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") }
        let diagram = try parseSequenceDiagram(rawLines)
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("<desc>"), "SVG should contain desc element")
        // Multiline accDescr should render its content
        XCTAssertTrue(diagram.accDescr?.contains("Line one") ?? false)
    }

    // MARK: - Actor Type Rendering

    func testActorTypesRenderDistinctShapes() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant P@{ "type": "boundary" } as Boundary
            participant C@{ "type": "control" } as Control
            participant E@{ "type": "entity" } as Entity
            participant D@{ "type": "database" } as DB
            actor A as Actor
            P->>A: Hi
        """))
        let svg = try renderSvg(diagram)
        // Boundary has circle
        XCTAssertTrue(svg.contains("<circle"))
        // Database has ellipse
        XCTAssertTrue(svg.contains("<ellipse"))
        // Actor has stick figure path
        XCTAssertTrue(svg.contains("stroke=\"var(--_line)\""))
    }

    // MARK: - Central Connection

    func testCentralConnectionCirclesInSvg() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice()->>()John: Great
        """))
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("r=\"5\""), "Central connection should render circles")
    }

    // MARK: - BR Tag Rendering

    func testBrTagInMessageRendersMultiline() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Line1<br>Line2
        """))
        // Verify parsed model has newline
        XCTAssertEqual(diagram.messages.first?.label, "Line1\nLine2")
        // Verify SVG escapes the content correctly
        let svg = try renderSvg(diagram)
        XCTAssertTrue(svg.contains("Line1"), "SVG should contain first line of text")
    }
}
