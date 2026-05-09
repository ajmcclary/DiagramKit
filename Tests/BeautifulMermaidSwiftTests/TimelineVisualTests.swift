import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class TimelineVisualTests: XCTestCase {

    private func parseLayoutRenderSVG(_ source: String) throws -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        let positioned = layoutTimelineDiagram(diagram)
        return try renderTimelineSvg(positioned, DiagramColors(bg: "#ffffff", fg: "#000000"), "Inter", false)
    }

    // MARK: - Basic structures

    func test_basicNoSectionTimeline_structure() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            title History of Social Media Platform
            2002 : LinkedIn
            2004 : Facebook : Google
            2005 : YouTube
            2006 : Twitter
        """)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("mermaid-0-arrowhead"))
        XCTAssertTrue(svg.contains("taskWrapper"))
        XCTAssertTrue(svg.contains("eventWrapper"))
        XCTAssertTrue(svg.contains("lineWrapper"))
        XCTAssertTrue(svg.contains("History of Social Media Platform"))
        XCTAssertEqual(svg.components(separatedBy: "taskWrapper").count, 5) // 4 tasks + 1 around
    }

    func test_sectionedTimeline_structure() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            section Age of Industrialization
            1760 : James Watt
            1780 : Steam Engine
            section Age of Computing
            1940 : ENIAC
            1970 : Microprocessor
        """)
        XCTAssertTrue(svg.contains("timeline-node section-0"))
        XCTAssertTrue(svg.contains("timeline-node section-1"))
    }

    func test_continuationEvents_structure() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            section Era
            2020 : Event A
                : Event B
                : Event C
            2021 : Event D
        """)
        XCTAssertTrue(svg.contains("Event A"))
        XCTAssertTrue(svg.contains("Event B"))
        XCTAssertTrue(svg.contains("Event C"))
        XCTAssertTrue(svg.contains("Event D"))
    }

    func test_brTagsInNodes() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            section Age of<br>Industrialization
            1760 : James<br>Watt
                : Steam<br>Engine
        """)
        XCTAssertFalse(svg.contains("&lt;br&gt;"))
        XCTAssertTrue(svg.contains(">Age of</tspan>"))
        XCTAssertTrue(svg.contains(">Industrialization</tspan>"))
        XCTAssertTrue(svg.contains(">James</tspan>"))
        XCTAssertTrue(svg.contains(">Steam</tspan>"))
    }

    func test_tdVerticalTimeline_structure() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline TD
            section 2023
            2023 Q1 : Feature A
            2023 Q2 : Feature B
            section 2024
            2024 Q1 : Feature C
        """)
        XCTAssertTrue(svg.contains("mermaid-0-arrowhead"))
        XCTAssertTrue(svg.contains("taskWrapper"))
        XCTAssertTrue(svg.contains("marker-end"))
    }

    func test_disableMulticolor() throws {
        let lines = "timeline\n    2020 : A\n    2021 : B".split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        diagram.config.disableMulticolor = true
        let positioned = layoutTimelineDiagram(diagram)
        let svg = try renderTimelineSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"), "Inter", false)
        let taskLines = svg.split(separator: "\n").filter { $0.contains("<g class=\"taskWrapper\"") }
        XCTAssertEqual(taskLines.count, 2)
    }

    func test_manyEvents_structure() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            2020 : E1 : E2 : E3 : E4 : E5
        """)
        XCTAssertEqual(svg.components(separatedBy: "eventWrapper").count, 6) // 5 events + 1 around
        let connectorsWithMarker = svg.components(separatedBy: "<line").filter { $0.contains("stroke-dasharray") && $0.contains("marker-end") }
        XCTAssertEqual(connectorsWithMarker.count, 5)
    }

    func test_accessibilityElements() throws {
        let svg = try parseLayoutRenderSVG("""
        timeline
            accTitle: Accessible Timeline
            accDescr: A description of the timeline
            title History
            2020 : Event
        """)
        XCTAssertTrue(svg.contains("<title>Accessible Timeline</title>"))
        XCTAssertTrue(svg.contains("<desc>A description of the timeline</desc>"))
        XCTAssertTrue(svg.contains("History"))
    }

    func test_neoLook_structure() throws {
        let lines = "timeline\n    section Era 1\n    2020 : Event".split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        diagram.look = "neo"
        diagram.themeName = "default"
        diagram.theme.useGradient = true
        let positioned = layoutTimelineDiagram(diagram)
        let svg = try renderTimelineSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"), "Inter", false)
        XCTAssertTrue(svg.contains("data-look=\"neo\""))
        XCTAssertTrue(svg.contains("linearGradient"))
    }

    func test_neoRedux_structure() throws {
        let lines = "timeline\n    2020 : Event A : Event B".split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        diagram.look = "neo"
        diagram.themeName = "redux"
        diagram.theme.useGradient = false
        let positioned = layoutTimelineDiagram(diagram)
        let svg = try renderTimelineSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"), "Inter", false)
        XCTAssertTrue(svg.contains("drop-shadow"))
        XCTAssertTrue(svg.contains("rx=\"0\""))
        XCTAssertFalse(svg.contains("node-line-0"))
    }
}
