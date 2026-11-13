import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitCommon
import DiagramKitTestSupport

// A standalone `.svg` is parsed as XML by browsers and most tools, and an
// exported SVG must not carry script. These tests parse the SVG of every
// corpus diagram, and of inputs that put markup into every family's text,
// style and theme positions, with `XMLParser`, and look for script
// elements, event-handler attributes and `javascript:` URLs.

/// Problems `XMLParser` finds in `svg`: a parse error, or active content.
func svgProblems(_ svg: String) -> [String] {
    final class Scan: NSObject, XMLParserDelegate {
        var hits: [String] = []
        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            let lower = name.lowercased()
            if ["script", "iframe", "object", "embed"].contains(lower) || lower.hasSuffix(":script") {
                hits.append("element <\(name)>")
            }
            for (key, value) in attributes {
                if key.lowercased().hasPrefix("on") { hits.append("attribute \(key) on <\(name)>") }
                let squeezed = value.unicodeScalars
                    .filter { $0.value > 0x20 }
                    .map(String.init).joined().lowercased()
                if squeezed.contains("javascript:") { hits.append("javascript: URL in \(key) on <\(name)>") }
            }
        }
    }
    let parser = XMLParser(data: Data(svg.utf8))
    let scan = Scan()
    parser.delegate = scan
    var problems = scan.hits
    if !parser.parse() {
        let lines = svg.split(separator: "\n", omittingEmptySubsequences: false)
        let lineIndex = parser.lineNumber - 1
        var context = ""
        if lines.indices.contains(lineIndex) {
            let line = Array(lines[lineIndex])
            let column = max(0, parser.columnNumber - 1)
            let lower = max(0, column - 60), upper = min(line.count, column + 30)
            if lower < upper { context = String(line[lower..<upper]) }
        }
        problems.insert("XML error at \(parser.lineNumber):\(parser.columnNumber) …\(context)…", at: 0)
    }
    problems.append(contentsOf: scan.hits.filter { !problems.contains($0) })
    return problems
}

/// One markup payload per family position the review found unescaped, plus
/// the corpus-shaped inputs that put `<` or `"` into ids and styles.
let hostileSVGInputs: [(name: String, source: String)] = [
    ("block-id", "block\n  a x\" onload=\"alert(1)"),
    ("block-style", "block-beta\n  a\n  style a fill:<b>,stroke:\"x\""),
    ("venn-style", "venn-beta\n  set A[\"Alpha\"]\n  set B[\"Beta\"]\n  union A,B[\"AB\"]\n  style A color:red\" onload=\"alert(1)"),
    ("venn-style-lt", "venn-beta\n  set A[\"Alpha\"]\n  set B[\"Beta\"]\n  style A fill:<b>"),
    ("quadrant-theme", "---\nconfig:\n  themeVariables:\n    quadrant1Fill: red\" onload=\"alert(1)\n---\nquadrantChart\n  title T\n  A: [0.3, 0.6]\n"),
    ("pie-style", "---\nconfig:\n  themeVariables:\n    pieOuterStrokeWidth: \"2px}</style><script>alert(1)</script><style>\"\n---\npie\n  \"A\": 1\n  \"B\": 2\n"),
    ("radar-style", "---\nconfig:\n  themeVariables:\n    cScale0: \"red}</style><script>alert(1)</script><style>\"\n---\nradar-beta\n  axis A,B,C\n  curve c{1,2,3}\n"),
    ("treeview-style", "---\nconfig:\n  themeVariables:\n    treeView:\n      labelColor: \"red}</style><script>alert(1)</script><style>\"\n---\ntreeView-beta\n  root\n    child\n"),
    ("flowchart-href-tab", "flowchart TD\n  A --> B\n  click A href \"java\tscript:alert(1)\""),
    ("flowchart-label-markup", "flowchart TD\n  A[\"<script>alert(1)</script> & \\\" '\"] --> B"),
    ("sequence-markup", "sequenceDiagram\n  Alice->>Bob: <script>alert(1)</script> \"quoted\" & 'single'"),
    ("gantt-markup", "gantt\n  dateFormat YYYY-MM-DD\n  section <b>S\"</b>\n  Task \"<i>\" :t1, 2024-01-01, 3d"),
    ("timeline-markup", "timeline\n  title <b>\"T\"</b>\n  2024 : <i>event \"one\"</i> & two"),
    ("sankey-markup", "sankey-beta\n\"<b>A\"\"</b>\",B,5\n"),
    ("treemap-markup", "treemap-beta\n\"<b>Root\\\"</b>\"\n    \"Leaf <i>\": 10\n"),
    ("kanban-markup", "kanban\n  todo[<b>To \"do\"</b>]\n    t1[R&D <i>x</i>]"),
    ("kanban-ticket-url-tab", "---\nconfig:\n  kanban:\n    ticketBaseUrl: \"java\tscript:alert(1)//#TICKET#\"\n---\nkanban\n  todo[Todo]\n    t1[Card]@{ ticket: 'A-1' }"),
    ("gantt-href-tab", "gantt\n  dateFormat YYYY-MM-DD\n  Task :t1, 2024-01-01, 3d\n  click t1 href \"java\tscript:alert(1)\""),
    ("sequence-link-tab", "sequenceDiagram\n  participant A\n  link A: Docs @ java\tscript:alert(1)\n  A->>A: hi"),
    ("gitgraph-reverse-id", "gitGraph\n   commit id:\"x<script>alert(1)</script>\" type:REVERSE tag:\"<b>t</b>\"\n   commit id:\"y onload=z\" type:HIGHLIGHT"),
    ("journey-markup", "journey\n  title <b>\"J\"</b>\n  section S\n    Task <i>\"x\"</i>: 5: Me"),
]

private func corpusInputs() throws -> [(name: String, source: String, format: DiagramFormatID?)] {
    var inputs: [(String, String, DiagramFormatID?)] = []
    for entry in try DiagramCorpus.load() {
        inputs.append((entry.id, entry.source, nil))
        for (format, source) in (entry.sources ?? [:]).sorted(by: { $0.key < $1.key }) where format != "mermaid" {
            inputs.append(("\(entry.id)-\(format)", source, DiagramFormatID(rawValue: format)))
        }
    }
    return inputs
}

@Suite("SVG output is well-formed XML without active content")
struct SVGWellFormednessTests {

    @Test("javascript, data and vbscript never become link targets; other schemes do", arguments: [
        ("https://example.com", true), ("HTTP://x", true), ("mailto:a@b.c", true), ("#frag", true),
        ("docs/page.html", true), ("./a:b", true), ("?q=a:b", true),
        ("obsidian://open?vault=notes&file=Plan", true), ("vscode://file/x.swift:12", true), ("file:///tmp/x", true),
        ("javascript:alert(1)", false), ("java\tscript:alert(1)", false), ("java\nscript:alert(1)", false),
        (" javascript:alert(1)", false), ("JaVaScRiPt:alert(1)", false), ("data:text/html,x", false),
        ("vbscript:x", false), ("\u{0}javascript:x", false), ("", false),
    ])
    func linkAllowlist(url: String, safe: Bool) {
        #expect(_isSafeLinkURL(url) == safe)
    }

    @Test("every corpus diagram renders to SVG that XML-parses")
    func corpusSVGParses() async throws {
        let failures: [String] = try await DiagramEngine._runOnWorker {
            var failures: [String] = []
            for (name, source, format) in try corpusInputs() {
                let svg: String
                do {
                    svg = try DiagramPipeline.renderSVG(source: source, idPolicy: .stable, sourceFormat: format)
                } catch {
                    // A corpus entry that stops rendering is a failure here,
                    // not a skip.
                    failures.append("[\(name)] threw \(error)")
                    continue
                }
                let problems = svgProblems(svg)
                if !problems.isEmpty { failures.append("[\(name)] \(problems.prefix(3).joined(separator: "; "))") }
            }
            return failures
        }
        #expect(failures.isEmpty, "\(failures.count) corpus SVGs fail:\n\(failures.joined(separator: "\n"))")
    }

    @Test("markup in labels, styles and theme values cannot inject script or break the XML")
    func hostileInputs() async throws {
        let failures: [String] = try await DiagramEngine._runOnWorker {
            var failures: [String] = []
            for (name, source) in hostileSVGInputs {
                let svg: String
                do {
                    svg = try DiagramPipeline.renderSVG(source: source, idPolicy: .stable)
                } catch {
                    continue // a typed rejection is fine
                }
                let problems = svgProblems(svg)
                if !problems.isEmpty { failures.append("[\(name)] \(problems.prefix(3).joined(separator: "; "))") }
            }
            return failures
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
