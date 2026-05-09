import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    // MARK: - Phase A: activity line stroke, actor dot radius

    func test_activityLineStrokeWidthIs4() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("stroke-width=\"4\""))
    }

    func test_svgActorDotRadiusIs7() throws {
        let source = """
        journey
            section Go
            Do thing: 5: Alice
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        // Actor dots on task rects should have r="7"
        XCTAssertTrue(svg.contains("r=\"7\""))
    }

    func test_svgActorDotsAreCenteredAcrossTaskTop() throws {
        let source = """
        journey
            section Go
            Do work: 5: Alice, Bob
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains(#"<circle class="actor-0" cx="216" cy="160" r="7""#))
        XCTAssertTrue(svg.contains(#"<circle class="actor-1" cx="234" cy="160" r="7""#))
        XCTAssertFalse(svg.contains(#"<circle class="actor-0" cx="160" cy="160" r="7""#))
    }

    func test_svgTaskGuideStartsBelowTaskRectangle() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains(#"x1="225" y1="210" x2="225" y2="450""#))
        XCTAssertTrue(svg.contains(#"<line x1="150" y1="220""#))
    }

    // MARK: - Phase B: text placement modes

    func test_oldModeDoesNotSplitBr() throws {
        let source = """
        journey
            section Go<br>Home
            Do thing: 5: Me
        """
        var config = JourneyDiagramConfig()
        config.textPlacement = "old"
        let positioned = try positionedFromSource(source, config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        // "old" mode should render raw text without <br> splitting
        // <br> tags are XML-escaped in the output
        XCTAssertFalse(svg.contains("<tspan"))
        XCTAssertTrue(svg.contains("Go&lt;br&gt;Home"))
    }

    func test_foModeRendersRawTextInSingleDiv() throws {
        let source = """
        journey
            section Test
            Do thing<br>multi: 5: Me
        """
        let positioned = try positionedFromSource(source)
        let svg = try renderJourneySvg(positioned, defaultColors)
        // Default "fo" mode: <br> text appears raw in foreignObject (XML-escaped)
        XCTAssertTrue(svg.contains("<foreignObject"))
        XCTAssertTrue(svg.contains("Do thing&lt;br&gt;multi"))
    }

    func test_tspanModeSplitsBrIntoTspans() throws {
        let source = """
        journey
            section Test
            Do thing<br>multi: 5: Me
        """
        var config = JourneyDiagramConfig()
        config.textPlacement = "tspan"
        let positioned = try positionedFromSource(source, config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("<tspan"))
        XCTAssertTrue(svg.contains(">Do thing</tspan>"))
        XCTAssertTrue(svg.contains(">multi</tspan>"))
    }

    // MARK: - Phase C: CSS block and faceColor

    func test_cssBlockContainsTaskTypeClasses() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains(".task-type-0"))
        XCTAssertTrue(svg.contains(".section-type-0"))
    }

    func test_cssBlockContainsActorClasses() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains(".actor-0"))
    }

    func test_cssBlockContainsFaceClass() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains(".face {"))
    }

    func test_faceColorFromConfigApplied() throws {
        var config = JourneyDiagramConfig()
        config.faceColor = "#FFE4B5"
        let positioned = try positionedFromSource(basicDiagramSource(), config: config)
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("fill=\"#FFE4B5\""))
    }

    func test_faceColorDefaultWheat() throws {
        let positioned = try positionedFromSource(basicDiagramSource())
        let svg = try renderJourneySvg(positioned, defaultColors)
        XCTAssertTrue(svg.contains("fill=\"#FFF8DC\""))
    }

    // MARK: - Phase E: multi-diagram ID scoping

    func test_twoConsecutiveRendersProduceUniqueTaskIDs() throws {
        let source = """
        journey
            section Go
            TaskA: 5: Me
            TaskB: 3: Me
        """
        let positioned1 = try positionedFromSource(source)
        let positioned2 = try positionedFromSource(source)
        let svg1 = try renderJourneySvg(positioned1, defaultColors, diagramId: "diagram-a")
        let svg2 = try renderJourneySvg(positioned2, defaultColors, diagramId: "diagram-b")
        XCTAssertTrue(svg1.contains("id=\"diagram-a-task0\""))
        XCTAssertTrue(svg2.contains("id=\"diagram-b-task0\""))
        XCTAssertFalse(svg1.contains("diagram-b-task"))
        XCTAssertFalse(svg2.contains("diagram-a-task"))
    }

    func test_publicRenderSVGUsesStableJourneyIds() async throws {
        let source = basicDiagramSource()
        let svg1 = try await MermaidRenderer.renderSVG(source: source)
        let svg2 = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertEqual(svg1, svg2)
        XCTAssertTrue(svg1.contains(#"id="mermaid-0""#))
        XCTAssertTrue(svg1.contains(#"id="mermaid-0-task0""#))
    }
}
