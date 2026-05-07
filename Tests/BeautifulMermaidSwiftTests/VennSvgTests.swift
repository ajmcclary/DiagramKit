import Testing
@testable import BeautifulMermaid

@Suite("Venn SVG")
struct VennSvgTests {

    @Test("SVG has correct root attributes")
    func rootSvgAttributes() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("viewBox=\"0 0 800 450\""))
        #expect(svg.contains("id=\"test-id\""))
    }

    @Test("SVG contains title element when present")
    func titleRendering() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 48 * (800.0 / 1600.0),
            title: PositionedVennTitle(text: "My Venn", x: 400, y: 16, fontSize: 16, fillColor: "#333"),
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: "My Venn",
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("venn-title"))
        #expect(svg.contains("My Venn"))
    }

    @Test("SVG contains venn-circle and venn-set-N classes")
    func circleClasses() throws {
        let area = PositionedVennArea(
            setsKey: "A", sets: ["A"], label: nil, size: 10,
            circles: [VennCircle(center: VennPoint(x: 400, y: 225), radius: 50)],
            pathSpec: nil, textPoint: VennPoint(x: 400, y: 225),
            fillColor: "#ff6b6b", fillOpacity: 0.1, strokeColor: "#ff6b6b",
            strokeWidth: 2.5, textColor: "#333", textFontSize: 24,
            colorClass: "venn-set-0"
        )
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [area], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("venn-circle"))
        #expect(svg.contains("venn-set-0"))
        #expect(svg.contains("<circle"))
        #expect(svg.contains("fill-opacity"))
        #expect(svg.contains("stroke-opacity"))
    }

    @Test("SVG contains intersection path for union areas")
    func intersectionPath() throws {
        let area = PositionedVennArea(
            setsKey: "A|B", sets: ["A", "B"], label: "AB", size: 2.5,
            circles: [],
            pathSpec: "M 380 225 A 50 50 0 0 0 420 225 A 50 50 0 0 1 380 225 Z",
            textPoint: VennPoint(x: 400, y: 225),
            fillColor: "transparent", fillOpacity: 0.0, strokeColor: "#ff6b6b",
            strokeWidth: 2.5, textColor: "#333", textFontSize: 24,
            colorClass: "venn-set-2"
        )
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [area], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("venn-intersection"))
        #expect(svg.contains("<path"))
    }

    @Test("SVG contains text nodes with foreignObject")
    func textNodeForeignObject() throws {
        let node = PositionedVennTextNode(
            areaKey: "A", id: "T1", label: "Text One",
            x: 380, y: 210, width: 40, height: 30,
            textColor: "#333"
        )
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [node],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("venn-text-nodes"))
        #expect(svg.contains("venn-text-node-fo"))
        #expect(svg.contains("foreignObject"))
        #expect(svg.contains("Text One"))
    }

    @Test("SVG contains useMaxWidth style when enabled")
    func useMaxWidthEnabled() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: VennDiagramConfig(useMaxWidth: true)
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("max-width: 100%"))
    }

    @Test("SVG does not contain max-width style when disabled")
    func useMaxWidthDisabled() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: VennDiagramConfig(useMaxWidth: false)
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(!svg.contains("max-width: 100%"))
    }

    @Test("SVG contains background rect when not transparent")
    func backgroundRect() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFFFFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("<rect width=\"100%\" height=\"100%\" fill=\"#FFFFFF\""))
    }

    @Test("SVG skips background rect when transparent")
    func transparentBackground() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", true)
        #expect(!svg.contains("<rect width=\"100%\""))
    }

    @Test("SVG contains title element for accessibility")
    func accessibilityTitle() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: "accessibility title", accDescr: nil, diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("<title>accessibility title</title>"))
    }

    @Test("SVG contains desc element for accessibility")
    func accessibilityDescr() throws {
        let positioned = PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [],
            accTitle: nil, accDescr: "accessibility description", diagramTitle: nil,
            config: .default
        )
        let svg = renderVennSvg(positioned, diagramId: "test-id", DiagramColors(bg: "#FFF", fg: "#000"), "Inter", false)
        #expect(svg.contains("<desc>accessibility description</desc>"))
    }
}
