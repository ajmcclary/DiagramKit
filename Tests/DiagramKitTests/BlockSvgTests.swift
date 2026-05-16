import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class BlockSvgTests: XCTestCase {

    private func rootId(in svg: String) -> String? {
        guard let idRange = svg.range(of: #"id="[^"]+""#, options: .regularExpression) else {
            return nil
        }
        return String(svg[idRange])
            .replacingOccurrences(of: #"id=""#, with: "")
            .replacingOccurrences(of: #"""#, with: "")
    }

    func testSVGContainsBlockClass() throws {
        let source = """
        block
          a b c
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("class=\"block\""))
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox"))
    }

    func testSVGContainsMarkers() throws {
        let source = """
        block
          A B
          A --> B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("id=\"mermaid-0-block-point\""))
        XCTAssertTrue(svg.contains("id=\"mermaid-0-block-circle\""))
        XCTAssertTrue(svg.contains("id=\"mermaid-0-block-cross\""))
    }

    func testSVGRendersNodeShapes() throws {
        let source = """
        block
          A["Square"] B("Round") C((\"Circle\"))
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("A"))
        XCTAssertTrue(svg.contains("B"))
        XCTAssertTrue(svg.contains("Circle"))
    }

    func testSVGContainsEdgePath() throws {
        let source = """
        block
          A B
          A --- B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("edgePath"))
        XCTAssertTrue(svg.contains("path"))
    }

    func testSVGPlainEdgesDoNotRenderArrowMarkers() throws {
        let source = """
        block
          A B
          A --- B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertFalse(svg.contains("marker-end=\"url(#mermaid-0-block-point)\""))
        XCTAssertFalse(svg.contains("marker-start=\"url(#mermaid-0-block-point)\""))
    }

    func testSVGBidirectionalEdgesRenderStartAndEndMarkers() throws {
        let source = """
        block
          A B
          A <--> B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("marker-start=\"url(#mermaid-0-block-point)\""))
        XCTAssertTrue(svg.contains("marker-end=\"url(#mermaid-0-block-point)\""))
    }

    func testSVGAppliesClassDefStylesToClassedNodes() throws {
        let source = """
        block
          classDef blue fill:#6cf,stroke:#333,color:#111
          A["Styled"]
          class A blue
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("class=\"node blue flowchart-label\""))
        XCTAssertTrue(svg.contains("fill=\"#6cf\""))
        XCTAssertTrue(svg.contains("stroke=\"#333\""))
        XCTAssertTrue(svg.contains("fill=\"#111\"") || svg.contains("fill=\"#000\"") == false)
    }

    func testSVGCompositeBlock() throws {
        let source = """
        block
          block:group["Group"]
            a b
          end
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("cluster"))
        XCTAssertTrue(svg.contains("Group"))
    }

    func testSVGRenderBlockArrow() throws {
        let source = """
        block
          A arrow<["Arrow"]>(right) B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertTrue(svg.contains("block_arrow") || svg.contains("polygon") || svg.contains("path"))
    }

    func testSVGBlockArrowGroupIsClosedAndPositioned() throws {
        let source = """
        block
          columns 3
          A arrow<["Arrow"]>(right) B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        let arrow = positioned.blocks.first { $0.type == .blockArrow }
        XCTAssertNotNil(arrow)

        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)
        XCTAssertEqual(svg.ranges(of: "<g ").count, svg.ranges(of: "</g>").count)
        if let arrow {
            let arrowGroupStart = svg.range(of: "id=\"\(arrow.domId ?? "block-\(arrow.id)")\"")
            XCTAssertNotNil(arrowGroupStart)
            if let arrowGroupStart {
                let arrowTail = String(svg[arrowGroupStart.lowerBound...])
                XCTAssertTrue(arrowTail.contains("transform=\"translate(\(arrow.x) \(arrow.y))\""))
            }
        }
    }

    func testSVGIncludesAccessibilityMetadata() throws {
        let positioned = PositionedBlockDiagram(
            blocks: [],
            edges: [],
            width: 10,
            height: 10,
            bounds: BlockBounds(x: 0, y: 0, width: 10, height: 10),
            accTitle: "Accessible <Block>",
            accDescr: "Description & details"
        )
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: true)
        XCTAssertTrue(svg.contains("<title>Accessible &lt;Block&gt;</title>"))
        XCTAssertTrue(svg.contains("<desc>Description &amp; details</desc>"))
    }

    func testSVGRenderThroughPublicPipeline() async throws {
        let svg = try await DiagramEngine.renderSVG(source: "block\n  a b c")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("class=\"block\""))
        XCTAssertTrue(svg.contains("flowchart-label"))
        XCTAssertTrue(svg.contains("flowchart-link"))
    }

    func testRenderMermaidSVGScopesMarkerIdsPerBlockRender() throws {
        let source = """
        block
          A B
          A --> B
        """
        let svg1 = try DiagramPipeline.renderSVG(source: source)
        let svg2 = try DiagramPipeline.renderSVG(source: source)
        let id1 = try XCTUnwrap(rootId(in: svg1))
        let id2 = try XCTUnwrap(rootId(in: svg2))
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(svg1.contains("id=\"\(id1)-block-point\""))
        XCTAssertTrue(svg1.contains("marker-end=\"url(#\(id1)-block-point)\""))
        XCTAssertTrue(svg2.contains("id=\"\(id2)-block-point\""))
        XCTAssertTrue(svg2.contains("marker-end=\"url(#\(id2)-block-point)\""))
    }

    // Critical 2: SVG `.round` shape must produce visibly rounded corners that
    // match the CG path's 6 pt rounded rectangle. Since the block SVG renderer
    // now routes through `ShapeSpecRegistry` + `SVGPathSerializer` (audit D2),
    // `.round` resolves to the `"rounded"` ShapeSpec and serializes as a
    // `<path>` with `Q` (quadratic) curve commands at each corner.
    func testRoundBlockNodeEmitsRoundedRectInSVG() throws {
        let source = """
        block
          A("rounded")
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        XCTAssertEqual(diagram.blockDatabase["A"]?.type, .round, "Parser should classify A(\"...\") as .round")

        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)

        XCTAssertTrue(svg.contains("<path "), "Expected `.round` to emit a <path> element. Got:\n\(svg)")
        XCTAssertTrue(svg.contains(" Q "), "Expected `.round` <path> to use Q curve commands for rounded corners. Got:\n\(svg)")
    }

    func testSquareBlockNodeEmitsPlainRectInSVG() throws {
        let source = """
        block
          A["square"]
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        XCTAssertEqual(diagram.blockDatabase["A"]?.type, .square)

        let positioned = try layoutBlockDiagram(diagram)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderBlockSvg(positioned, colors: colors, fontFamily: "Inter", transparent: false)

        XCTAssertFalse(svg.contains(" rx=\""), "Expected `.square` SVG rect to omit rx; got:\n\(svg)")
    }
}
