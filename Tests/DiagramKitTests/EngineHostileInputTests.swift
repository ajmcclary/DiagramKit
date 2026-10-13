import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Replays every hostile input from REVIEW.md Appendix A through the public
/// `DiagramEngine` APIs. Each input must terminate (no trap/hang) and either
/// produce output or throw a typed error.
@Suite("Engine hostile input regressions")
struct EngineHostileInputTests {

    // MARK: - SVG render path

    @Test("pie 1e20 value terminates")
    func pieHugeValueSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "pie\n\"A\" : 1e20")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("sequence autonumber huge value terminates")
    func sequenceHugeAutonumberSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "sequenceDiagram\nautonumber 99999999999999999999\nA->>B: m")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("gantt numberSectionStyles zero terminates")
    func ganttZeroSectionStylesSVG() async throws {
        let source = """
        ---
        config:
          gantt:
            numberSectionStyles: 0
        ---
        gantt\nsection A\ntask : 2024-01-01, 1d
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("treemap 1e20 leaf value terminates")
    func treemapHugeValueSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "treemap-beta\nA [100]\nB [1e20]")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("gitGraph huge diagramPadding terminates")
    func gitGraphHugePaddingSVG() async throws {
        let source = """
        ---
        config:
          gitGraph:
            diagramPadding: 1e300
        ---
        gitGraph\ncommit\ncommit
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("wardley unterminated accDescr opener terminates")
    func wardleyUnterminatedAccDescrSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "wardley-beta\naccDescr {\ncomponent A [0.5, 0.5]")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("kanban single quote card terminates")
    func kanbanSingleQuoteCardSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "kanban\n\"\"")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("eventmodeling when-after-then terminates")
    func eventModelingWhenAfterThenSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "eventmodeling\ngwt 01 given cmd A then evt Whenever")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("xychart huge y-axis range terminates")
    func xychartHugeYAxisSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "xychart-beta\ny-axis 100000000000000000 --> 100000000000000032")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("xychart title as last token terminates")
    func xychartTitleLastTokenSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "xychart-beta\ntitle")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("zenuml bare return annotation terminates")
    func zenumlBareReturnAnnotationSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "zenuml\n@return result;")
        if let svg { #expect(!svg.isEmpty) }
    }

    // MARK: - ASCII render path

    @Test("30-node graph TD chain terminates")
    func longGraphTDChainASCII() async throws {
        var lines = ["graph TD"]
        for i in 0..<30 {
            lines.append("n\(i) --> n\(i + 1)")
        }
        let result = try? await DiagramEngine.renderASCII(source: lines.joined(separator: "\n"))
        if let result { #expect(!result.text.isEmpty) }
    }

    @Test("pie 400-digit value terminates")
    func pie400DigitValueASCII() async throws {
        let big = String(repeating: "9", count: 400)
        let result = try? await DiagramEngine.renderASCII(source: "pie\n\"A\" : \(big)")
        if let result { #expect(!result.text.isEmpty) }
    }

    @Test("kanban duplicate card id terminates")
    func kanbanDuplicateCardIdASCII() async throws {
        let source = """
        kanban
          [Backlog]
          [todo] t1
          [Done]
          [done] t1
        """
        let result = try? await DiagramEngine.renderASCII(source: source)
        if let result { #expect(!result.text.isEmpty) }
    }

    // MARK: - Parser / importer path

    @Test("DOT duplicate node attribute terminates")
    func dotDuplicateAttributeImport() async throws {
        _ = try? await DiagramEngine.parseImportResult(
            source: "a [label=\"x\" label=\"y\"]",
            sourceFormat: .graphviz
        )
    }

    @Test("DOT numeric attribute terminates")
    func dotNumericAttributeImport() async throws {
        _ = try? await DiagramEngine.parseImportResult(
            source: "a [fontsize=12]",
            sourceFormat: .graphviz
        )
    }

    @Test("D2 dotted invalid key terminates")
    func d2DottedInvalidKeyImport() async throws {
        _ = try? await DiagramEngine.parseImportResult(
            source: ".: foo",
            sourceFormat: .d2
        )
    }

    @Test("D2 duplicate class shape key terminates")
    func d2DuplicateClassShapeKeyImport() async throws {
        let source = """
        A: {
          shape: class
          shape: class
        }
        B: {
          shape: class
        }
        """
        _ = try? await DiagramEngine.parseImportResult(
            source: source,
            sourceFormat: .d2
        )
    }

    @Test("flowchart no-space arrow terminates")
    func flowchartNoSpaceArrowSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "graph TD\nA-->B")
        if let svg { #expect(!svg.isEmpty) }
    }

    @Test("sequence keyword as actor name terminates")
    func sequenceKeywordActorNameSVG() async throws {
        let svg = try? await DiagramEngine.renderSVG(source: "sequenceDiagram\nparser->>Lexer: next()")
        if let svg { #expect(!svg.isEmpty) }
    }

    // MARK: - SVG attribute-injection hardening

    @Test("class diagram style breakout is sanitized")
    func classStyleBreakoutSVG() async throws {
        let source = """
        classDiagram
        class A
        style A fill:#fff;stroke-width:2\" onload=alert(1) x=\"1
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg {
            #expect(!svg.contains("onload=alert(1)"))
            #expect(!svg.contains("stroke-width:2\""))
        }
    }

    @Test("ER key badge text is escaped")
    func erKeyBadgeEscapeSVG() async throws {
        let source = """
        erDiagram
        A ||--o{ B : has
        A {
          string name
          PK <script>alert(1)</script>
        }
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg {
            #expect(!svg.contains("<script>alert(1)</script>"))
        }
    }

    @Test("sankey aria-label is escaped")
    func sankeyAriaLabelEscapeSVG() async throws {
        let source = """
        sankey-beta
        title \" onload=alert(1) x=\"
        A[100]
        B[20]
        A --> B : 20
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg {
            #expect(!svg.contains(" onload=alert(1) x="))
            #expect(svg.contains("aria-label="))
        }
    }

    @Test("gantt task id and class tokens are sanitized")
    func ganttTaskIdSanitizationSVG() async throws {
        let source = """
        gantt
        section A
        task\" onload=alert(1) x=\": 2024-01-01, 1d
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg {
            // The task name is rendered as escaped text content, which is safe.
            // The hardening target is the id/class attributes derived from it.
            #expect(!svg.contains("id=\"\""))
            #expect(!svg.contains("id=\"task\\\" onload"))
            #expect(!svg.contains("class=\"task\\\" onload"))
        }
    }

    @Test("ASCII HTML output escapes quotes")
    func asciiHtmlQuoteEscape() {
        let theme = AsciiTheme(fg: "#fff\" onload=alert(1) x=\"", border: "#aaa", line: "#888", arrow: "#555")
        let html = colorizeLine(["<script>alert(1)</script>"], [.text], theme, .html)
        #expect(!html.contains("<script>alert(1)</script>"))
        #expect(!html.contains("onload=alert(1)"))
    }

    @Test("pie theme color injection is rejected")
    func pieThemeColorInjectionSVG() async throws {
        let source = """
        ---
        theme:
          pie:
            pieStrokeColor: '#fff\" onload=alert(1) x=\"'
        ---
        pie
        "A" : 1
        """
        let svg = try? await DiagramEngine.renderSVG(source: source)
        if let svg {
            #expect(!svg.contains("onload=alert(1)"))
        }
    }

    @Test("sequence popup script is gated by interactive flag")
    func sequenceScriptGateSVG() async throws {
        let source = """
        sequenceDiagram
        link A: Example @ https://example.com
        A->>B: m
        """
        let nonInteractive = try? await DiagramEngine.renderSVG(source: source)
        #expect(nonInteractive != nil)
        #expect(nonInteractive?.contains("popupMenuToggle") == false)
        #expect(nonInteractive?.contains("<script") == false)
    }
}
