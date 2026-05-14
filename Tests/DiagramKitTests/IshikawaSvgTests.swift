import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Ishikawa SVG")
struct IshikawaSvgTests {

    @Test("SVG has correct root and viewBox attributes")
    func rootSvgAttributes() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("viewBox"))
        #expect(svg.contains("xmlns"))
    }

    @Test("SVG contains g.ishikawa group")
    func ishikawaGroup() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("class=\"ishikawa\""))
    }

    @Test("SVG contains marker definition")
    func markerDefinition() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("<marker"))
        #expect(svg.contains("ishikawa-arrow-test-id"))
        #expect(svg.contains("ishikawa-arrow"))
    }

    @Test("SVG contains head path and label")
    func headPathAndLabel() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-head"))
        #expect(svg.contains("ishikawa-head-label"))
        #expect(svg.contains("ishikawa-head-group"))
    }

    @Test("SVG contains spine line")
    func spineLine() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-spine"))
    }

    @Test("SVG contains branch lines with marker-start")
    func branchLinesWithMarkers() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A"),
                IshikawaNode(text: "Cause B")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-branch"))
        #expect(svg.contains("marker-start"))
    }

    @Test("SVG contains sub-branch lines for nested causes")
    func subBranchLines() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Sub A1")
                ])
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-sub-branch"))
    }

    @Test("SVG contains label box rect for top-level causes")
    func labelBoxRects() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-label-box"))
    }

    @Test("SVG contains cause label with correct class")
    func causeLabelClass() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-label cause"))
    }

    @Test("SVG contains sub-label with align class for even-depth")
    func subLabelAlignClass() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Sub A1")
                ])
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("ishikawa-label align"))
    }

    @Test("SVG contains tspan elements for multiline text")
    func tspanElements() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("<tspan"))
    }

    @Test("Head label tspan uses local x after group transform")
    func headLabelTspanUsesLocalX() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("class=\"ishikawa-head-label\""))
        #expect(svg.contains("<tspan x=\"0.0\" dy=\"0.0\">Problem</tspan>"))
    }

    @Test("SVG applies useMaxWidth sizing")
    func useMaxWidthSizing() throws {
        let config = IshikawaDiagramConfig(useMaxWidth: true)
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A")
            ]),
            config: config
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("width=\"100%\""))
        #expect(svg.contains("max-width:"))
    }

    @Test("SVG groups branch pairs and sub-branches with labels")
    func pairAndSubBranchGrouping() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "Problem", children: [
                IshikawaNode(text: "Cause A", children: [
                    IshikawaNode(text: "Sub A1")
                ]),
                IshikawaNode(text: "Cause B")
            ])
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("<g class=\"ishikawa-pair\">"))
        #expect(svg.contains("<g class=\"ishikawa-sub-group\"><line class=\"ishikawa-sub-branch\""))
    }

    @Test("SVG escapes XML special characters")
    func xmlEscaping() throws {
        let (positioned, _) = layoutIshikawaDiagram(IshikawaDiagram(
            root: IshikawaNode(text: "A < B & C > D")
        ))
        let svg = renderIshikawaSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#FFF", fg: "#000"), fontFamily: "Inter", transparent: false)
        #expect(svg.contains("&lt;"))
        #expect(svg.contains("&gt;"))
        #expect(svg.contains("&amp;"))
    }
}
