import Foundation
import Testing
import DiagramKit
import DiagramKitModel

// Owner ruling: click and link lines are always kept in the model; the
// scheme check runs only where a link is rendered.

@Suite("Links are kept in the model and checked at output")
struct LinkPreservationTests {

    @Test("custom-scheme click links stay in the model and the SVG")
    func customSchemes() throws {
        let source = """
        flowchart TD
          A --> B
          click A href "obsidian://open?vault=notes&file=Plan" "Open note"
          click B href "vscode://file/Users/me/x.swift:12"
        """
        guard case .flowchart(let g) = try DiagramPipeline.parse(source).payload else { Issue.record("not a flowchart"); return }
        #expect(g.nodeInteractions.count == 2)
        let svg = try DiagramPipeline.renderSVG(source: source)
        #expect(svg.contains("obsidian://open?vault=notes&amp;file=Plan"))
        #expect(svg.contains("vscode://file/Users/me/x.swift:12"))
    }

    @Test("a javascript click link is kept in the model but never rendered")
    func javascriptKeptButNotRendered() throws {
        let source = "flowchart TD\n  A --> B\n  click A href \"java\tscript:alert(1)\"\n"
        guard case .flowchart(let g) = try DiagramPipeline.parse(source).payload else { Issue.record("not a flowchart"); return }
        #expect(g.nodeInteractions["A"] != nil)
        let svg = try DiagramPipeline.renderSVG(source: source)
        #expect(!svg.lowercased().contains("script:"))
    }

    @Test("sequence links with quotes keep their URL")
    func sequenceQuotedLink() throws {
        let source = "sequenceDiagram\n  participant Alice\n  link Alice: \"Dashboard\" @ \"https://example.com\"\n  Alice->>Alice: hi\n"
        guard case .sequenceDiagram(let model) = try DiagramPipeline.parse(source).payload else { Issue.record("not a sequence"); return }
        #expect(model.actors.first?.links["Dashboard"] == "https://example.com")
    }
}
