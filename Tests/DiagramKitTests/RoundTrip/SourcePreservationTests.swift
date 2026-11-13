import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitModel

// Owner rulings for canvas edits, which save the Mermaid exporter's output:
// (1) frontmatter and %%{init}%% directives come back byte for byte unless
// the edit changes configuration, and then only that key changes; (2) click
// and link lines come back exactly; (3) full-line %% comments survive at the
// statement they preceded or the end of their block.

let complexFrontmatter = """
---
title: Pipeline
config:
  gitGraph:
    mainBranchName: trunk
  themeCSS: >
    .node rect { fill: red; }
    .edgePath { stroke: blue; }
  dompurifyConfig:
    ADD_TAGS:
      - foreignObject
      - use
  flowchart: { curve: basis, htmlLabels: false }
  theme: forest
---
%%{init: {"list": [1, 2, 3], "nothing": null, "themeVariables": {"primaryColor": "#ffcc00"}}}%%
%%{initialize: {"logLevel": 1}}%%

"""

private func export(_ source: String) throws -> String {
    try MermaidExporter().export(MermaidImporter().parse(source).document).source
}

@Suite("Source text the model does not hold survives export")
struct SourcePreservationTests {

    @Test("frontmatter and init directives are written back byte for byte", arguments: [
        complexFrontmatter + "flowchart TD\n  A --> B\n",
        complexFrontmatter + "stateDiagram-v2\n  [*] --> S\n",
        complexFrontmatter + "sequenceDiagram\n  A->>B: hi\n",
        complexFrontmatter + "pie\n  \"a\": 1\n",
    ])
    func preambleVerbatim(_ source: String) throws {
        let out = try export(source)
        #expect(out.hasPrefix(complexFrontmatter), "\(out)")
    }

    @Test("changing the theme edits only the theme line")
    func themeEditedInPlace() throws {
        var document = try MermaidImporter().parse(complexFrontmatter + "flowchart TD\n  A --> B\n").document
        document.frontmatter?.theme = "dark"
        let out = try MermaidExporter().export(document).source
        let expected = complexFrontmatter.replacingOccurrences(of: "  theme: forest\n", with: "  theme: dark\n")
        #expect(out.hasPrefix(expected), "\(out)")
    }

    @Test("changing the title edits only the title line; a new theme is added under config")
    func titleAndNewTheme() throws {
        var document = try MermaidImporter().parse("---\ntitle: Old\nconfig:\n  look: handDrawn\n---\nflowchart TD\n  A\n").document
        document.title = "New: title"
        document.frontmatter = DiagramDocumentFrontmatter(theme: "dark")
        let out = try MermaidExporter().export(document).source
        #expect(out.hasPrefix("---\ntitle: \"New: title\"\nconfig:\n  theme: dark\n  look: handDrawn\n---\n"), "\(out)")
    }

    @Test("a theme set only by an init directive is edited inside the directive")
    func themeInInitDirective() throws {
        var document = try MermaidImporter().parse("%%{init: {\"theme\": \"forest\", \"flowchart\": {\"curve\": \"basis\"}}}%%\nflowchart TD\n  A\n").document
        document.frontmatter?.theme = "dark"
        let out = try MermaidExporter().export(document).source
        #expect(out.hasPrefix("%%{init: {\"theme\": \"dark\", \"flowchart\": {\"curve\": \"basis\"}}}%%\n"), "\(out)")
    }

    @Test("full-line comments stay with the statement they precede or the end of their block")
    func commentsKeepTheirPlace() throws {
        let source = """
        flowchart TD
          %% the ingest side
          A[Ingest] --> B[Parse]
          subgraph S [Storage]
            %% primary store
            C[(DB)]
            %% end of storage
          end
          B --> C
          %% trailing note
        """
        let lines = try export(source).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        func index(_ text: String) throws -> Int { try #require(lines.firstIndex(of: text), "\(text) missing in \(lines)") }
        #expect(try index("%% the ingest side") + 1 == index("A[Ingest]"))
        #expect(try index("%% primary store") + 1 == index("C[(DB)]"))
        let storageEnd = try #require(lines[try index("C[(DB)]")...].firstIndex(of: "end"))
        #expect(try index("%% end of storage") + 1 == storageEnd)
        #expect(lines.last == "%% trailing note")
    }

    @Test("click and link lines come back exactly as written")
    func verbatimLinks() throws {
        let flow = "flowchart TD\n  A --> B\n  click A href   \"obsidian://open?vault=notes&file=Plan\"   \"Open note\" _blank\n"
        #expect(try export(flow).contains("  click A href   \"obsidian://open?vault=notes&file=Plan\"   \"Open note\" _blank\n"))
        let seq = "sequenceDiagram\n  participant Alice\n  link Alice: Dashboard @ https://example.com/a?b=c\n  Alice->>Alice: hi\n"
        #expect(try export(seq).contains("  link Alice: Dashboard @ https://example.com/a?b=c\n"))
    }

    @Test("export with annotations is stable on a second pass", arguments: [
        complexFrontmatter + "flowchart TD\n  %% c\n  A --> B\n  click A href \"vscode://x\"\n",
    ])
    func stable(_ source: String) throws {
        let first = try export(source)
        #expect(try export(first) == first)
    }
}
