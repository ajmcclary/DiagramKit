import Testing
import Foundation
@testable import BeautifulMermaid

@Suite("Radar End-to-End")
struct RadarEndToEndTests {

    @Test("MermaidParser.parse routes radar-beta sources to RadarDiagram")
    func parserRoutesRadarSource() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .radar)
        switch graph.payload {
        case .radar(let diagram):
            #expect(diagram.axes.count == 3)
            #expect(diagram.curves.count == 1)
            #expect(diagram.curves[0].entries == [1, 2, 3])
        default:
            #expect(Bool(false), "Expected radar payload")
        }
    }

    @Test("renderMermaidSVG produces valid SVG for radar")
    func renderMermaidSVGForRadar() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}"
        let svg = try _renderMermaidSVG(source)
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.contains("radarGraticule"))
        #expect(svg.contains("radarAxisLine"))
        #expect(svg.contains("radarCurve-0"))
    }

    @Test("MermaidParser.parse handles radar-beta: header variant")
    func parserHandlesRadarColon() throws {
        let source = "radar-beta:\n  axis A\n  curve c1{1}"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .radar)
    }

    @Test("MermaidParser.parse handles radar-beta : header variant")
    func parserHandlesRadarSpaceColon() throws {
        let source = "radar-beta :\n  axis A\n  curve c1{1}"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .radar)
    }

    @Test("GraphLayout.layout handles radar type")
    func layoutHandlesRadar() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
        if case .radar(let data) = positioned.content {
            #expect(data.axisLines.count == 3)
            #expect(data.curves.count == 1)
        } else {
            #expect(Bool(false), "Expected radar positioned content")
        }
    }

    @Test("renderMermaidSVG with showLegend false suppresses legend")
    func renderMermaidSVGNoLegend() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}\n  showLegend false"
        let svg = try _renderMermaidSVG(source)
        #expect(!svg.contains("radarLegendBox"))
    }

    @Test("renderMermaidSVG with polygon graticule")
    func renderMermaidSVGPolygon() throws {
        let source = "radar-beta\n  axis A,B,C,D\n  curve c1{1,2,3,4}\n  graticule polygon"
        let svg = try _renderMermaidSVG(source)
        #expect(svg.contains("<polygon"))
    }

    @Test("renderMermaidSVG includes title and accessibility")
    func renderMermaidSVGWithMetadata() throws {
        let source = "radar-beta\n  title Radar Chart\n  accTitle: Radar Title\n  accDescr: Radar Description\n  axis A\n  curve c1{1}"
        let svg = try _renderMermaidSVG(source)
        #expect(svg.contains("Radar Chart"))
        #expect(svg.contains("<title>Radar Title</title>"))
    }

    @Test("ASCII dispatch returns notYetImplemented for radar")
    func asciiReturnsNotYetImplemented() throws {
        let source = "radar-beta\n  axis A\n  curve c1{1}"
        do {
            _ = try original_src_ascii_index.renderMermaidASCII(source)
            #expect(Bool(false), "Expected notYetImplemented error")
        } catch BeautifulMermaidError.notYetImplemented(let msg) {
            #expect(msg.contains("Radar Chart"))
        }
    }

    @Test("Detailed entries with frontmatter radarConfig")
    func detailedEntriesWithFrontmatter() throws {
        let fm = DiagramFrontmatter(radarConfig: RadarDiagramConfig(width: 800, height: 400))
        let source = "radar-beta\n  axis A,B,C\n  curve c1{C: 3, A: 1, B: 2}"
        let diagram = try parseRadarDiagram(source: source, frontmatter: fm)
        #expect(diagram.config.width == 800)
        #expect(diagram.config.height == 400)
        #expect(diagram.curves.count == 1)
        #expect(diagram.curves[0].entries == [1, 2, 3])
    }

    @Test("Empty radar diagram produces valid SVG")
    func emptyRadarSVG() throws {
        let source = "radar-beta"
        let svg = try _renderMermaidSVG(source)
        #expect(svg.hasPrefix("<svg "))
        #expect(svg.contains("radarGraticule"))
    }

    @Test("Multiple curves with options")
    func multipleCurvesWithOptions() throws {
        let source = """
        radar-beta
          axis A,B,C,D,E
          curve c1{1,2,3,4,5}
          curve c2{5,4,3,2,1}
          ticks 10
          min 0
          max 10
        """
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .radar)
        switch graph.payload {
        case .radar(let diagram):
            #expect(diagram.curves.count == 2)
            #expect(diagram.options.ticks == 10)
            #expect(diagram.options.max == 10)
            #expect(diagram.options.min == 0)
        default:
            #expect(Bool(false))
        }
    }

    @Test("Labeled axes render in SVG")
    func labeledAxesRender() throws {
        let source = #"radar-beta\n  axis A["Axis A"], B["Axis B"]\n  curve c1{1,2}"#
        let unescaped = source.replacingOccurrences(of: "\\n", with: "\n")
        let svg = try _renderMermaidSVG(unescaped)
        #expect(svg.contains("Axis A"))
        #expect(svg.contains("Axis B"))
    }
}
