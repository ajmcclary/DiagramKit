import XCTest
@testable import BeautifulMermaid

final class SankeyRendererTests: XCTestCase {

    func testParseDetectsSankeyType() async throws {
        let graph = try await MermaidRenderer.parse("sankey\nA,B,10")
        XCTAssertEqual(graph.type, .sankey)
        switch graph.payload {
        case .sankey(let diagram):
            XCTAssertEqual(diagram.links.count, 1)
        default:
            XCTFail("Expected sankey payload")
        }
    }

    func testParseDetectsSankeyBetaType() async throws {
        let graph = try await MermaidRenderer.parse("sankey-beta\nA,B,10")
        XCTAssertEqual(graph.type, .sankey)
    }

    func testLayoutProducesSankeyContent() async throws {
        let positioned = try await MermaidRenderer.layout("sankey\nA,B,10")
        switch positioned.content {
        case .sankey(let diagram):
            XCTAssertEqual(diagram.nodes.count, 2)
            XCTAssertEqual(diagram.links.count, 1)
        default:
            XCTFail("Expected sankey positioned content")
        }
    }

    func testRenderSvgProducesOutput() async throws {
        let svg = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithEnergyCsv() async throws {
        let source = """
        sankey
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Heating and cooling - homes,113.726
        Electricity grid,H2 conversion,27.14
        Electricity grid,Industry,342.165
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertFalse(svg.isEmpty)
    }

    func testRenderSvgWithFrontmatter() async throws {
        let source = """
        ---
        config:
          sankey:
            showValues: false
            labelStyle: outlined
        ---
        sankey
        A,B,10
        B,C,20
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithCustomColors() async throws {
        let source = """
        ---
        config:
          sankey:
            nodeColors:
              A: "#4e79a7"
              B: "#e15759"
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("#4e79a7") || svg.contains("#e15759"))
    }

    func testRenderSvgWithQuotedNodeColorKey() async throws {
        let source = """
        ---
        config:
          sankey:
            nodeColors:
              "Electricity grid": "#123456"
        ---
        sankey
        Electricity grid,Industry,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains(##"fill="#123456""##))
    }

    func testRenderSvgScopesIdsAcrossSankeyRenders() async throws {
        let first = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")
        let second = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")

        let firstIDs = Set(Self.svgIDs(in: first).filter { $0.contains("node-") || $0.contains("linearGradient-") })
        let secondIDs = Set(Self.svgIDs(in: second).filter { $0.contains("node-") || $0.contains("linearGradient-") })

        XCTAssertFalse(firstIDs.isEmpty)
        XCTAssertFalse(secondIDs.isEmpty)
        XCTAssertTrue(firstIDs.isDisjoint(with: secondIDs), "Sankey node/gradient ids should be scoped per render")
    }

    func testAsciiDetectionReturnsSankey() {
        let detected = original_src_ascii_index.detectDiagramType("sankey\nA,B,10")
        XCTAssertEqual(detected, "sankey")
    }

    func testDiagramTypeAllCasesIncludesSankey() {
        XCTAssertTrue(DiagramType.allCases.contains(.sankey), "DiagramType.allCases should include .sankey")
    }

    func testPositionedGraphSankeyAccessor() async throws {
        let positioned = try await MermaidRenderer.layout("sankey\nA,B,10")
        XCTAssertNotNil(positioned.sankeyData)
    }

    func testRenderSvgWithLinkColorSource() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: source
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithLinkColorTarget() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: target
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithFixedLinkColor() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: "#ff0000"
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    private static func svgIDs(in svg: String) -> [String] {
        let pattern = #"id="([^"]+)""#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        return regex.matches(in: svg, range: range).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: svg) else { return nil }
            return String(svg[idRange])
        }
    }
}
