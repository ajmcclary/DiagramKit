import XCTest
@testable import BeautifulMermaid

final class JourneyRendererTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func positionedFromSource(_ source: String, config: JourneyDiagramConfig? = nil) throws -> PositionedJourneyDiagram {
        let diagram = try parseJourneyDiagram(lines(source))
        let merged = JourneyDiagram(
            title: diagram.title,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            sections: diagram.sections,
            tasks: diagram.tasks,
            actors: diagram.actors,
            config: config ?? .default
        )
        return layoutJourneyDiagram(merged, config: merged.config)
    }

    private func basicDiagramSource() -> String {
        """
        journey
            title Test
            section Go
            Do thing: 5: Me
        """
    }

    private let defaultColors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")

    // MARK: - Basic SVG output

    func test_basicSvgOutput() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func test_accessibilityTitle() throws {
        let source = """
        journey
            accTitle: Test Journey
            section Go
            Do thing: 5: Me
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<title>Test Journey</title>"))
    }

    func test_accessibilityDesc() throws {
        let source = """
        journey
            accDescr: A description
            section Go
            Do thing: 5: Me
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<desc>A description</desc>"))
    }

    func test_arrowheadMarker() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("-arrowhead"))
        XCTAssertTrue(svg.contains("<marker"))
    }

    func test_taskLineIDs() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("id=\"mermaid-0-task0\""))
    }

    func test_scoreFaces() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("class=\"face\""))
        XCTAssertTrue(svg.contains("class=\"mouth\""))
    }

    func test_actorCirclesWithTitle() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<title>Me</title>"))
    }

    func test_sectionClasses() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("journey-section"))
        XCTAssertTrue(svg.contains("section-type-0"))
    }

    func test_taskClasses() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("class=\"task"))
        XCTAssertTrue(svg.contains("task-type-0"))
    }

    func test_textPlacement_fo_default() throws {
        let source = """
        journey
            section Go
            Do thing: 5: Me
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        // Default is "fo" = foreignObject
        XCTAssertTrue(svg.contains("<foreignObject"))
    }

    func test_textPlacement_tspan() throws {
        let source = """
        journey
            section Go
            Do thing: 5: Me
        """
        var config = JourneyDiagramConfig()
        config.textPlacement = "tspan"
        let positioned = try positionedFromSource(source, config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<tspan"))
    }

    func test_titleStyling() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        // Title should have font-weight bold and font-family
        XCTAssertTrue(svg.contains("font-weight=\"bold\""))
        XCTAssertTrue(svg.contains("trebuchet ms"))
    }

    func test_useMaxWidth_true() throws {
        var config = JourneyDiagramConfig()
        config.useMaxWidth = true
        let positioned = try positionedFromSource(basicDiagramSource(), config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("width=\"100%\""))
        XCTAssertTrue(svg.contains("max-width"))
    }

    func test_useMaxWidth_false() throws {
        var config = JourneyDiagramConfig()
        config.useMaxWidth = false
        let positioned = try positionedFromSource(basicDiagramSource(), config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("width=\""))
        XCTAssertFalse(svg.contains("max-width"))
    }

    func test_svgRootHasSingleMergedStyleAttribute() throws {
        var config = JourneyDiagramConfig()
        config.useMaxWidth = true
        let positioned = try positionedFromSource(basicDiagramSource(), config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        let root = String(svg.prefix { $0 != ">" })
        let styleAttributeCount = root.components(separatedBy: " style=\"").count - 1
        XCTAssertEqual(styleAttributeCount, 1)
        XCTAssertTrue(root.contains("max-width"))
        XCTAssertTrue(root.contains("--bg:"))
    }

    func test_svgLegendRendersWrappedActorLines() throws {
        let source = """
        journey
            section Go
            Do thing: 5: SupercalifragilisticActorName
        """
        var config = JourneyDiagramConfig()
        config.maxLabelWidth = 40
        let positioned = try positionedFromSource(source, config: config)
        let actor = try XCTUnwrap(positioned.actors.first)
        XCTAssertGreaterThan(actor.lines.count, 1)

        let svg = try renderJourneySvg(positioned, defaultColors)
        let legendTextCount = svg.components(separatedBy: "<text class=\"legend\"").count - 1
        XCTAssertEqual(legendTextCount, actor.lines.count)
        for line in actor.lines {
            XCTAssertTrue(svg.contains(">\(line)</text>"), "Expected wrapped legend line \(line) in SVG")
        }
    }

    func test_scoreFace_smile() throws {
        let source = """
        journey
            section Go
            Happy: 5: Me
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        // Score 5 = smile arc (clockwise from pi/2 to 3pi/2)
        XCTAssertTrue(svg.contains("class=\"mouth\""))
    }
}
