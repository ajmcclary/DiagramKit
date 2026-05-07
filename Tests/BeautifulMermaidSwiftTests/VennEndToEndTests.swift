import Testing
@testable import BeautifulMermaid

@Suite("Venn End-to-End")
struct VennEndToEndTests {

    @Test("Full pipeline parse → layout → SVG for Venn")
    func fullPipeline() throws {
        let source = """
        venn-beta
          title "Test"
          set A
          set B
          union A,B
        """
        let svg = try _renderMermaidSVG(source)
        #expect(svg.contains("venn-circle"))
        #expect(svg.contains("venn-set-0"))
        #expect(svg.contains("venn-title"))
        #expect(svg.contains("Test"))
    }

    @Test("Venn diagram type is in DiagramType.allCases")
    func vennInAllCases() {
        #expect(DiagramType.allCases.contains(.venn))
    }

    @Test("Venn payload is parsed through MermaidParser")
    func vennParseThroughParser() throws {
        let source = """
        venn-beta
          set A
          set B
          union A,B
        """
        let graph = try MermaidParser.parse(source)
        guard case .venn(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .venn payload")
            return
        }
        #expect(diagram.areas.count == 3)
        #expect(diagram.areas[0].sets == ["A"])
    }

    @Test("Venn frontmatter config is applied")
    func vennFrontmatterConfig() throws {
        let source = """
        ---
        config:
          venn:
            width: 1000
            height: 600
          theme: dark
        ---
        venn-beta
          set A
          set B
          union A,B
        """
        let graph = try MermaidParser.parse(source)
        guard case .venn(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .venn payload")
            return
        }
        #expect(diagram.config.width == 1000)
        #expect(diagram.config.height == 600)
    }

    @Test("Venn with theme variables from frontmatter")
    func vennThemeVariables() throws {
        let source = """
        ---
        config:
          themeVariables:
            venn1: "#ff6b6b"
            venn2: "#4ecdc4"
            vennSetTextColor: "#222222"
        ---
        venn-beta
          set Frontend
          set Backend
          union Frontend,Backend
        """
        let graph = try MermaidParser.parse(source)
        guard case .venn(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .venn payload")
            return
        }
        #expect(diagram.themeVariables?["venn1"] == "#ff6b6b")
        #expect(diagram.themeVariables?["venn2"] == "#4ecdc4")
        #expect(diagram.themeVariables?["vennSetTextColor"] == "#222222")
    }

    @Test("Venn SVG detectDiagramType returns venn")
    func detectDiagramType() {
        // Verify through the public pipeline that venn-beta is detected
        let svg = try? _renderMermaidSVG("venn-beta\n  set A\n  set B\n  union A,B")
        #expect(svg != nil)
        #expect(svg?.contains("venn-circle") == true)
    }

    @Test("Venn positioned content from layout")
    func vennLayoutEndToEnd() throws {
        let source = """
        venn-beta
          set A
          set B
          union A,B
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        guard case .venn(let data) = positioned.content else {
            #expect(Bool(false), "Expected .venn positioned content")
            return
        }
        #expect(data.areas.count == 3)
        #expect(data.width == 800)
    }
}
