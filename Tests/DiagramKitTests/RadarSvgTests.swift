import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Radar SVG Renderer")
struct RadarSvgTests {

    private func makePositioned() -> PositionedRadarDiagram {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C")]
        diagram.curves = [RadarCurve(name: "c1", entries: [1, 2, 3])]
        diagram.diagramTitle = "Test Radar"
        diagram.accTitle = "AT"
        diagram.accDescr = "AD"
        return layoutRadarDiagram(diagram)
    }

    @Test("SVG contains root svg tag with viewBox")
    func svgRootViewBox() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.contains("viewBox"))
        #expect(svg.contains("</svg>"))
    }

    @Test("SVG viewBox matches total dimensions")
    func svgViewBoxDimensions() {
        let pos = makePositioned()
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("0 0"))
        #expect(svg.contains("\(Int(pos.width)) \(Int(pos.height))") || svg.contains("\(Int(pos.width)).0 \(Int(pos.height)).0"))
    }

    @Test("SVG contains center transform group")
    func svgCenterTransform() {
        let pos = makePositioned()
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("transform=\"translate("))
        #expect(svg.contains(String(Int(pos.centerX))))
        #expect(svg.contains(String(Int(pos.centerY))))
    }

    @Test("SVG contains title text with radarTitle class")
    func svgTitleText() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarTitle"))
        #expect(svg.contains("Test Radar"))
    }

    @Test("SVG contains graticule circles")
    func svgGraticuleCircles() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarGraticule"))
        #expect(svg.contains("<circle"))
    }

    @Test("SVG polygon graticule")
    func svgPolygonGraticule() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B")]
        diagram.options.graticule = .polygon
        let pos = layoutRadarDiagram(diagram)
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarGraticule"))
        #expect(svg.contains("<polygon"))
        #expect(svg.contains("points="))
    }

    @Test("SVG contains axis lines")
    func svgAxisLines() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        let lineCount = svg.components(separatedBy: #"<line class="radarAxisLine""#).count - 1
        #expect(lineCount == 3)
    }

    @Test("SVG contains axis labels")
    func svgAxisLabels() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarAxisLabel"))
    }

    @Test("SVG contains curve path with class")
    func svgCurvePath() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarCurve-0"))
        #expect(svg.contains("<path"))
    }

    @Test("SVG multi-curve class names")
    func svgMultiCurveClasses() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [1]), RadarCurve(name: "c2", entries: [2])]
        let pos = layoutRadarDiagram(diagram)
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarCurve-0"))
        #expect(svg.contains("radarCurve-1"))
    }

    @Test("SVG contains legend elements")
    func svgLegend() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("radarLegendBox-0"))
        #expect(svg.contains("radarLegendText"))
        #expect(svg.contains("c1"))
    }

    @Test("SVG legend suppressed when showLegend false")
    func svgLegendSuppressed() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        diagram.options.showLegend = false
        let pos = layoutRadarDiagram(diagram)
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(!svg.contains("radarLegendBox"))
        #expect(!svg.contains("radarLegendText"))
    }

    @Test("SVG contains accessibility title and desc")
    func svgAccessibility() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("<title>AT</title>"))
        #expect(svg.contains("<desc>AD</desc>"))
    }

    @Test("SVG contains style block")
    func svgStyleBlock() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("<style>"))
        #expect(svg.contains(".radarTitle"))
        #expect(svg.contains(".radarAxisLine"))
        #expect(svg.contains(".radarGraticule"))
        #expect(svg.contains(".radarCurve-0"))
        #expect(svg.contains(".radarLegendBox-0"))
    }

    @Test("SVG transparent background")
    func svgTransparent() {
        let svg = renderRadarSvg(makePositioned(), colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: true)
        #expect(svg.contains("background-color: none"))
    }

    @Test("SVG useMaxWidth configuration")
    func svgUseMaxWidth() {
        var config = RadarDiagramConfig.default
        config.useMaxWidth = true
        var diagram = RadarDiagram(config: config)
        diagram.axes = [RadarAxis(name: "A")]
        let pos = layoutRadarDiagram(diagram)
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("max-width"))
        #expect(svg.contains("100%"))
    }

    @Test("SVG XML-escapes special characters")
    func svgXMLEscaping() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A", label: "A & B")]
        diagram.diagramTitle = "Test <Radar>"
        diagram.accTitle = "AT \"quoted\""
        let pos = layoutRadarDiagram(diagram)
        let svg = renderRadarSvg(pos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.contains("A &amp; B"))
        #expect(svg.contains("Test &lt;Radar&gt;"))
        #expect(svg.contains("AT &quot;quoted&quot;"))
    }

    @Test("SVG with empty diagram")
    func svgEmptyDiagram() {
        let emptyPos = RadarDiagram().positioned()
        let svg = renderRadarSvg(emptyPos, colors: DiagramColors(bg: "#FFF", fg: "#000"), transparent: false)
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.contains("</svg>"))
    }
}

private extension RadarDiagram {
    func positioned() -> PositionedRadarDiagram {
        layoutRadarDiagram(self)
    }
}
