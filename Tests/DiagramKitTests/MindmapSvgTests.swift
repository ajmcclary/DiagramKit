// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class MindmapSvgTests: XCTestCase {

    private func renderSvg(_ source: String) throws -> String {
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseMindmap(rawLines, frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        return renderMindmapSvg(positioned, diagramId: "test-id", colors, "Inter", false)
    }

    func test_svgRootElement() throws {
        let svg = try renderSvg("mindmap\n  root")
        XCTAssertTrue(svg.contains("class=\"mindmapDiagram\""))
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func test_svgContainsDefs() throws {
        let svg = try renderSvg("mindmap\n  root\n    A")
        XCTAssertTrue(svg.contains("<defs>"))
        XCTAssertTrue(svg.contains("linearGradient"))
    }

    func test_rootNodeHasRootClass() throws {
        let svg = try renderSvg("mindmap\n  root\n    A")
        XCTAssertTrue(svg.contains("section-root"))
        XCTAssertTrue(svg.contains("section--1"))
    }

    func test_childNodeHasSectionClass() throws {
        let svg = try renderSvg("mindmap\n  root\n    A")
        XCTAssertTrue(svg.contains("section-0"))
    }

    func test_edgeHasEdgeClass() throws {
        let svg = try renderSvg("mindmap\n  root\n    A")
        XCTAssertTrue(svg.contains("class=\"edge"))
        XCTAssertTrue(svg.contains("edge-depth-"))
    }

    func test_circleNodeUsesCircleElement() throws {
        let svg = try renderSvg("mindmap\n  root((circle))")
        XCTAssertTrue(svg.contains("<circle"))
    }

    func test_rectNodeUsesRectElement() throws {
        let svg = try renderSvg("mindmap\n  root[rect]")
        XCTAssertTrue(svg.contains("<rect"))
    }

    func test_defaultNodeUsesPath() throws {
        let svg = try renderSvg("mindmap\n  root\n    default")
        XCTAssertTrue(svg.contains("<path"))
    }

    func test_hexagonNodeUsesPolygon() throws {
        let svg = try renderSvg("mindmap\n  root{{hex}}")
        XCTAssertTrue(svg.contains("<polygon"))
    }

    func test_cloudNodeUsesPath() throws {
        let svg = try renderSvg("mindmap\n  root)cloud(")
        XCTAssertTrue(svg.contains("class=\"node-bkg cloud\""))
    }

    func test_bangNodeUsesPath() throws {
        let svg = try renderSvg("mindmap\n  root))bang((")
        XCTAssertTrue(svg.contains("class=\"node-bkg bang\""))
    }

    func test_iconRendersForeignObject() throws {
        let source = "mindmap\n  root\n    A\n    ::icon(fa fa-book)"
        let svg = try renderSvg(source)
        XCTAssertTrue(svg.contains("<foreignObject"))
    }

    func test_labelsHaveMindmapNodeLabelClass() throws {
        let svg = try renderSvg("mindmap\n  root")
        XCTAssertTrue(svg.contains("mindmap-node-label"))
    }

    func test_brTagsRenderAsSeparateTextLines() throws {
        let svg = try renderSvg("mindmap\n  root[A<br/>B]")
        XCTAssertTrue(svg.contains(">A</text>"))
        XCTAssertTrue(svg.contains(">B</text>"))
        XCTAssertFalse(svg.contains("A&lt;br/&gt;B"))
    }

    func test_decorationAttributesAreEscaped() throws {
        let source = "mindmap\n  root\n    A\n    :::bad\" onclick=\"evil\n    ::icon(fa fa-book\" onload=\"evil)"
        let svg = try renderSvg(source)
        XCTAssertFalse(svg.contains("onclick=\"evil"))
        XCTAssertFalse(svg.contains("onload=\"evil"))
        XCTAssertTrue(svg.contains("bad"))
        XCTAssertTrue(svg.contains("fa-book"))
    }

    func test_accessibilityTitlePresent() throws {
        let (diagram, _) = try parseMindmap(["mindmap", "accTitle: Test Title", "  root"], frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderMindmapSvg(positioned, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("<title>"))
        XCTAssertTrue(svg.contains("Test Title"))
    }

    func test_accessibilityDescrPresent() throws {
        let (diagram, _) = try parseMindmap(["mindmap", "accDescr: Test Desc", "  root"], frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderMindmapSvg(positioned, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("<desc>"))
        XCTAssertTrue(svg.contains("Test Desc"))
    }

    func test_markdownBoldRendersAsBoldTspan() throws {
        let svg = try renderSvg("mindmap\n  root[\"`**bold** text`\"]")
        XCTAssertTrue(svg.contains("font-weight=\"bold\""))
        XCTAssertTrue(svg.contains("bold"))
        XCTAssertTrue(svg.contains("<tspan"))
    }

    func test_markdownItalicRendersAsItalicTspan() throws {
        let svg = try renderSvg("mindmap\n  root[\"`*italic* text`\"]")
        XCTAssertTrue(svg.contains("font-style=\"italic\""))
        XCTAssertTrue(svg.contains("italic"))
        XCTAssertTrue(svg.contains("<tspan"))
    }

    func test_markdownPlainTextNoTspan() throws {
        let svg = try renderSvg("mindmap\n  root[plain text]")
        XCTAssertFalse(svg.contains("<tspan"))
        XCTAssertTrue(svg.contains("plain text"))
    }

    func test_markdownNeoLookDataAttribute() throws {
        var (diagram, _) = try parseMindmap(["mindmap", "  root", "    A"], frontmatter: nil)
        diagram.config.look = "neo"
        let positioned = try layoutMindmap(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderMindmapSvg(positioned, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("data-look=\"neo\""))
    }

    func test_iconContainerCssPresent() throws {
        let svg = try renderSvg("mindmap\n  root\n    A\n    ::icon(fa fa-book)")
        XCTAssertTrue(svg.contains("icon-container"))
    }

    func test_gradientNeoStrokeRule() throws {
        let (diagram, _) = try parseMindmap(["mindmap", "  root", "    A"], frontmatter: nil)
        var configured = diagram
        configured.config.look = "neo"
        configured.theme.useGradient = true
        let positioned = try layoutMindmap(configured)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderMindmapSvg(positioned, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("stroke: url(#mindmap-test-id-gradient)"))
    }
}
#endif
