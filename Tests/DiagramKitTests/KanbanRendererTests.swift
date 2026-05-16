import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import CoreGraphics

final class KanbanRendererTests: XCTestCase {

    private func rawLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func test_svgContainsSectionGroup() throws {
        let source = "kanban\n  Todo\n    [Task]"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("class=\"sections\""))
    }

    func test_svgContainsItemsGroup() throws {
        let source = "kanban\n  Todo\n    [Task]"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("class=\"items\""))
    }

    func test_svgSectionClassesStartAtOne() throws {
        let source = "kanban\n  S1\n  S2"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("section-1"))
        XCTAssertTrue(svg.contains("section-2"))
    }

    func test_svgHasValidSvgWrapper() throws {
        let source = "kanban\n  S"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.hasSuffix("</svg>"))
    }

    func test_svgIncludesCardRect() throws {
        let source = "kanban\n  S\n    card1"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("class=\"basic label-container __APA__\""))
    }

    func test_priorityStripeColors() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'High' }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("orange"))
        guard let cardRectRange = svg.range(of: "class=\"basic label-container __APA__\""),
              let stripeRange = svg.range(of: "<line"),
              let strokeRange = svg.range(of: "stroke=\"orange\"") else {
            XCTFail("Expected a visible priority line after the card background")
            return
        }
        XCTAssertLessThan(cardRectRange.lowerBound, stripeRange.lowerBound)
        XCTAssertLessThan(stripeRange.lowerBound, strokeRange.lowerBound)
    }

    func test_lowercasePriorityIsPreservedButNotRenderedAsVisibleStripe() throws {
        let source = "kanban\n  S\n    card1@{ priority: high }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.first(where: { !$0.isGroup })?.priority, "high")
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertFalse(svg.contains("orange"))
        XCTAssertFalse(svg.contains("stroke=\"orange\""))
    }

    func test_veryLowPriorityRendersLightblueStripe() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'Very Low' }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("lightblue"))
    }

    func test_mediumPriorityRendersNoStripe() throws {
        let source = "kanban\n  S\n    card1@{ priority: Medium }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        let cardArea = svg.range(of: "class=\"node\"").map { String(svg[$0.lowerBound..<svg.endIndex]) } ?? svg
        XCTAssertFalse(cardArea.contains("<line"))
    }

    func test_veryHighPriorityRendersRedStripe() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'Very High' }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("red"))
    }

    func test_ticketLinkWithBaseUrl() throws {
        var config = KanbanDiagramConfig()
        config.ticketBaseUrl = "https://jira.example.com/browse/#TICKET#"
        var frontmatter = DiagramFrontmatter()
        frontmatter.perDiagram.kanban.config = config
        let source = "kanban\n  S\n    card1@{ ticket: MC-1234 }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatter)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("xlink:href"))
        XCTAssertTrue(svg.contains("MC-1234"))
    }

    func test_svgSectionsAndCardsShareCenteredCoordinateSystem() throws {
        let source = "kanban\n  S\n    card1"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("viewBox=\"92 -308"))
        XCTAssertTrue(svg.contains("<rect x=\"100\" y=\"-300\" width=\"200\""))
        XCTAssertTrue(svg.contains("<rect class=\"basic label-container __APA__\" x=\"108\" y=\"-255\""))
    }

    func test_svgWrapsLongCardLabels() throws {
        let source = "kanban\n  S\n    card1[Wrap long text across multiple lines to test layout]"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)

        XCTAssertTrue(svg.contains("<tspan"))
        XCTAssertFalse(svg.contains(">Wrap long text across multiple lines to test layout</text>"))
    }

    func test_svgIncludesAccessibilityMetadata() throws {
        let source = """
        kanban
        accTitle: Release kanban
        accDescr: Tracks release tasks
          Todo
        """
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("<title>Release kanban</title>"))
        XCTAssertTrue(svg.contains("<desc>Tracks release tasks</desc>"))
    }

    func test_publicSVGPipelineRendersKanban() async throws {
        let source = """
        kanban
        accTitle: Release kanban
          Todo
            card1@{ priority: 'High' }
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("class=\"sections\""))
        XCTAssertTrue(svg.contains("class=\"items\""))
        XCTAssertTrue(svg.contains("<title>Release kanban</title>"))
        XCTAssertFalse(svg.contains("flowchart"))
    }

    func test_svgStyleBlockIsEmitted() throws {
        let source = "kanban\n  S1\n  S2"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("<style>"))
        XCTAssertTrue(svg.contains(".kanban-ticket-link"))
        XCTAssertTrue(svg.contains(".kanban-label"))
        XCTAssertTrue(svg.contains(".node rect"))
    }

    func test_styleBlockHasPerSectionColors() throws {
        let source = "kanban\n  S1\n  S2\n  S3"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains(".section-1 rect"))
        XCTAssertTrue(svg.contains(".section-2 rect"))
        XCTAssertTrue(svg.contains(".section-3 rect"))
    }

    func test_perSectionInlinedFillsAreDistinct() throws {
        let source = "kanban\n  A\n  B\n  C"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)

        var fills: [String] = []
        var searchStart = svg.startIndex
        while let rectRange = svg.range(of: "cluster section-", range: searchStart..<svg.endIndex) {
            guard let fillStart = svg.range(of: "fill=\"", range: rectRange.upperBound..<svg.endIndex) else { break }
            let afterQuote = svg.index(after: fillStart.upperBound)
            guard let fillEnd = svg.range(of: "\"", range: afterQuote..<svg.endIndex) else { break }
            fills.append(String(svg[afterQuote..<fillEnd.lowerBound]))
            searchStart = fillEnd.upperBound
        }

        XCTAssertEqual(fills.count, 3)
        XCTAssertNotEqual(fills[0], fills[1])
        XCTAssertNotEqual(fills[1], fills[2])
        XCTAssertNotEqual(fills[0], fills[2])
    }

    func test_useMaxWidthAffectsRootSvgSizing() throws {
        var config = KanbanDiagramConfig()
        config.useMaxWidth = true
        var frontmatter = DiagramFrontmatter()
        frontmatter.perDiagram.kanban.config = config
        let source = "kanban\n  S"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatter)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertTrue(svg.contains("width=\"100%\""))
        XCTAssertTrue(svg.contains("style=\"max-width:"))
    }

    func test_unsafeTicketBaseUrlDoesNotCreateLink() throws {
        var config = KanbanDiagramConfig()
        config.ticketBaseUrl = "javascript:alert('#TICKET#')"
        var frontmatter = DiagramFrontmatter()
        frontmatter.perDiagram.kanban.config = config
        let source = "kanban\n  S\n    card1@{ ticket: MC-1234 }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatter)
        let positioned = layoutKanbanDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = try renderKanbanSvg(positioned, diagramId: "test", colors, "Inter", false)
        XCTAssertFalse(svg.contains("xlink:href"))
        XCTAssertFalse(svg.localizedCaseInsensitiveContains("javascript:"))
        XCTAssertTrue(svg.contains("MC-1234"))
    }

    func test_fullPipelineMultiSectionEndToEnd() async throws {
        let source = """
        kanban
          Todo
            [Create Documentation]
          In Progress
            [Write Tests]
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.hasSuffix("</svg>"))
        XCTAssertTrue(svg.contains("class=\"sections\""))
        XCTAssertTrue(svg.contains("class=\"items\""))
        XCTAssertTrue(svg.contains("<style>"))
        XCTAssertTrue(svg.contains(".section-1"))
        XCTAssertTrue(svg.contains(".section-2"))
        XCTAssertFalse(svg.contains("flowchart"))
        XCTAssertFalse(svg.contains("statediagram"))
    }

    func test_coreGraphicsPriorityStripeIsVisible() throws {
        let source = "kanban\n  S\n    card1@{ priority: 'High' }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let graph = DiagramDocument(payload: .kanban(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .kanban(positioned)
        )

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        DiagramRenderer().render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        var orangePixels = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]
            if red > 220, green > 80, green < 180, blue < 40, alpha > 220 {
                orangePixels += 1
            }
        }
        XCTAssertGreaterThan(orangePixels, 10)
    }
}
