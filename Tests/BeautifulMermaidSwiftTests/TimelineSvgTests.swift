import XCTest
@testable import BeautifulMermaid

final class TimelineSvgTests: XCTestCase {

    private func renderSVG(_ source: String) throws -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        let positioned = layoutTimelineDiagram(diagram)
        return try renderTimelineSvg(positioned, DiagramColors(bg: "#ffffff", fg: "#000000"), "Inter", false)
    }

    private func rootId(in svg: String) -> String? {
        guard let idRange = svg.range(of: #"id="[^"]+""#, options: .regularExpression) else {
            return nil
        }
        let raw = String(svg[idRange])
        return raw
            .replacingOccurrences(of: #"id=""#, with: "")
            .replacingOccurrences(of: #"""#, with: "")
    }

    // MARK: - Root SVG element

    func test_rootSvgElement() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertTrue(svg.contains("viewBox"))
    }

    func test_rootSvgHasId() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("id=\"mermaid-0\""))
    }

    // MARK: - Accessibility

    func test_accTitleInSvg() throws {
        let svg = try renderSVG("timeline\n    accTitle: My Title\n    2020 : Event")
        XCTAssertTrue(svg.contains("<title>My Title</title>"))
    }

    func test_accDescrInSvg() throws {
        let svg = try renderSVG("timeline\n    accDescr: My Description\n    2020 : Event")
        XCTAssertTrue(svg.contains("<desc>My Description</desc>"))
    }

    // MARK: - Defs and markers

    func test_lrArrowheadMarker() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("mermaid-0-arrowhead"))
    }

    func test_tdArrowheadMarker() throws {
        let svg = try renderSVG("timeline TD\n    2020 : Event")
        XCTAssertTrue(svg.contains("id=\"mermaid-0-arrowhead\""))
    }

    // MARK: - Section nodes

    func test_sectionNodesHaveTimelineNodeClass() throws {
        let svg = try renderSVG("timeline\n    section Era 1\n    2020 : Event")
        XCTAssertTrue(svg.contains("timeline-node"))
        XCTAssertTrue(svg.contains("section-0"))
    }

    // MARK: - Task wrapper

    func test_taskWrapperClass() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("class=\"taskWrapper\""))
    }

    func test_taskNodeBkgClass() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("node-bkg"))
    }

    func test_taskNodeLineClass() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("node-line-0"))
    }

    // MARK: - Event wrapper

    func test_eventWrapperClass() throws {
        let source = """
        timeline
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("class=\"eventWrapper\""))
        XCTAssertTrue(svg.contains("brightness(120%)"))
    }

    // MARK: - Connector lines

    func test_connectorLineDasharray() throws {
        let source = """
        timeline
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("stroke-dasharray=\"5,5\""))
    }

    func test_lineWrapperGroup() throws {
        let source = """
        timeline
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("class=\"lineWrapper\""))
    }

    // MARK: - Activity line

    func test_activityLineWithMarkerEnd() throws {
        let source = """
        timeline
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("marker-end"))
    }

    // MARK: - Title

    func test_titleElement() throws {
        let source = """
        timeline
            title History
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("History"))
        XCTAssertTrue(svg.contains("font-weight=\"bold\""))
    }

    // MARK: - Theme colors

    func test_taskFillsUseScaleColor() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("fill=\"#0052CC\""))
    }

    func test_taskTextsUseScaleLabelColor() throws {
        let svg = try renderSVG("timeline\n    2020 : Event")
        XCTAssertTrue(svg.contains("fill=\"#ffffff\""))
    }

    // MARK: - Text placement

    func test_brTagsRenderAsSeparateTspans() throws {
        let source = """
        timeline
            section Age of<br>Industrialization
            1760 : James<br>Watt
        """
        let svg = try renderSVG(source)
        XCTAssertFalse(svg.contains("&lt;br&gt;"))
        XCTAssertTrue(svg.contains("<tspan"))
        XCTAssertTrue(svg.contains(">Age of</tspan>"))
        XCTAssertTrue(svg.contains(">Industrialization</tspan>"))
        XCTAssertTrue(svg.contains(">James</tspan>"))
        XCTAssertTrue(svg.contains(">Watt</tspan>"))
    }

    func test_longLabelsWrapIntoMultipleTspans() throws {
        let source = """
        timeline
            2020 : This is a deliberately long event label that should wrap into more than one rendered text line
        """
        let svg = try renderSVG(source)
        let tspanCount = svg.components(separatedBy: "<tspan").count - 1
        XCTAssertGreaterThanOrEqual(tspanCount, 2)
    }

    // MARK: - TD Layout in SVG

    func test_tdVerticalActivityLine() throws {
        let svg = try renderSVG("timeline TD\n    2020 : Event")
        let lineCount = svg.components(separatedBy: "<line").count
        XCTAssertGreaterThanOrEqual(lineCount, 4) // activity + connector
    }

    // MARK: - No sections

    func test_noSections_stillRenders() throws {
        let source = """
        timeline
            2020 : Event
        """
        let svg = try renderSVG(source)
        XCTAssertTrue(svg.contains("taskWrapper"))
        XCTAssertTrue(svg.contains("eventWrapper"))
    }

    // MARK: - Use Max Width

    func test_useMaxWidth_attribute() throws {
        let source = """
        timeline
            2020 : Event
        """
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        diagram.config.useMaxWidth = true
        let positioned = layoutTimelineDiagram(diagram)
        let svg = try renderTimelineSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"), "Inter", false)
        XCTAssertTrue(svg.contains("width=\"100%\""))
        XCTAssertTrue(svg.contains("preserveAspectRatio"))
    }

    func test_renderMermaidSVG_scopesIdsPerTimelineRender() throws {
        let source = "timeline\n    2020 : Event"
        let svg1 = try _renderMermaidSVG(source)
        let svg2 = try _renderMermaidSVG(source)
        let id1 = try XCTUnwrap(rootId(in: svg1))
        let id2 = try XCTUnwrap(rootId(in: svg2))
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(svg1.contains("id=\"\(id1)-arrowhead\""))
        XCTAssertTrue(svg1.contains("marker-end=\"url(#\(id1)-arrowhead)\""))
        XCTAssertTrue(svg2.contains("id=\"\(id2)-arrowhead\""))
        XCTAssertTrue(svg2.contains("marker-end=\"url(#\(id2)-arrowhead)\""))
    }
}
