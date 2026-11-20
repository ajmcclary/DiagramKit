import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Theme variables and string-valued diagram config keys can land in the
/// SVG `<style>` block, an inline `style="…"` attribute, or a presentation
/// attribute. A hostile value set through YAML frontmatter or the
/// `%%{init}%%` directive must never open a script element, close
/// `<style>` early, or add a CSS declaration (`;fill:url(…)`) or rule
/// (`} .x{…}`) to a style context; ordinary colours, lengths, font
/// weights and font families still reach the SVG.
///
/// Most families reject or escape such values at their renderer; the
/// architecture, packet, gitGraph, ER, quadrant, pie `fontFamily` and
/// timeline `taskFontFamily` bindings reject them at binding time.
@Suite("Theme value injection across families")
struct ThemeValueInjectionFamilyTests {

    private static let scriptPayload = "red}</style><script>alert(1)</script>"
    private static let declarationPayload = "red;fill:url(https://x.invalid/a)"
    private static let rulePayload = "red} .x{fill:url(https://x.invalid/a)}"

    /// `paths` are dotted keys below `config` (`themeVariables.pie.pie1`,
    /// `er.stroke`).
    private struct Family: Sendable, CustomTestStringConvertible {
        let name: String
        let body: String
        let paths: [String]
        var themes: [String?] = [nil]
        var testDescription: String { name }
    }

    private static func themeVars(_ keys: [String], _ namespace: String? = nil) -> [String] {
        keys.map { "themeVariables." + (namespace.map { "\($0)." } ?? "") + $0 }
    }

    private static let families: [Family] = [
        Family(name: "architecture", body: """
            architecture-beta
            group g(cloud)[G]
            service a(server)[A] in g
            service b(database)[B] in g
            a:R -- L:b
            """,
            paths: themeVars(["archEdgeColor", "archEdgeArrowColor", "archEdgeWidth",
                              "archGroupBorderColor", "archGroupBorderWidth"])),
        Family(name: "packet", body: "packet-beta\n0-15: \"Source\"\n16-31: \"Dest\"",
               paths: themeVars(["byteFontSize", "startByteColor", "endByteColor", "labelColor", "labelFontSize",
                                 "titleColor", "titleFontSize", "blockStrokeColor", "blockStrokeWidth", "blockFillColor"], "packet")),
        Family(name: "gitGraph", body: """
            gitGraph
            commit id: "a"
            branch dev
            commit id: "b" tag: "v1"
            checkout main
            merge dev
            """,
            paths: themeVars((0..<8).flatMap { ["git\($0)", "gitInv\($0)", "gitBranchLabel\($0)"] } + [
                "commitLabelColor", "commitLabelBackground", "commitLabelFontSize",
                "tagLabelColor", "tagLabelBackground", "tagLabelBorder", "tagLabelFontSize",
                "nodeBorder", "mainBkg", "strokeWidth", "gradientStart", "gradientStop",
                "dropShadow", "filterColor", "fontFamily", "textColor", "primaryColor",
                "secondaryColor", "tertiaryColor", "primaryTextColor", "labelTextColor",
                "lineColor", "noteFontWeight",
            ], "gitGraph"),
            themes: [nil, "redux", "neo"]),
        Family(name: "gitGraphBranch", body: "gitGraph\n  commit\n  branch dev\n  commit", paths: ["gitGraph.mainBranchName"]),
        Family(name: "timeline",
               body: "timeline\n    title T\n" + (0..<13).map { "    section S\($0)\n      \(2000 + $0) : E\($0)\n" }.joined(),
               paths: themeVars((0..<12).flatMap { ["cScale\($0)", "cScaleLabel\($0)", "cScaleInv\($0)"] }
                   + ["fontFamily", "mainBkg", "nodeBorder", "gradientStart", "gradientStop", "dropShadow"])
                   + ["timeline.taskFontFamily", "timeline.textPlacement"],
               themes: [nil, "neo", "redux"]),
        Family(name: "pie", body: "pie title P\n" + (1...12).map { "    \"S\($0)\": \($0 * 10)\n" }.joined(),
               paths: themeVars((1...12).map { "pie\($0)" } + [
                   "pieTitleTextSize", "pieTitleTextColor", "pieSectionTextSize", "pieSectionTextColor",
                   "pieLegendTextSize", "pieLegendTextColor", "pieStrokeColor", "pieStrokeWidth",
                   "pieOuterStrokeWidth", "pieOuterStrokeColor", "pieOpacity", "fontFamily",
               ], "pie") + themeVars(["pie1", "fontFamily"])),
        Family(name: "quadrant", body: """
            quadrantChart
              title T
              x-axis Low --> High
              y-axis Low --> High
              quadrant-1 A
              quadrant-2 B
              quadrant-3 C
              quadrant-4 D
              P1: [0.3, 0.6]
            """,
            paths: themeVars(["quadrant1Fill", "quadrant2Fill", "quadrant3Fill", "quadrant4Fill",
                              "quadrant1TextFill", "quadrant2TextFill", "quadrant3TextFill", "quadrant4TextFill",
                              "quadrantPointFill", "quadrantPointTextFill", "quadrantXAxisTextFill",
                              "quadrantYAxisTextFill", "quadrantInternalBorderStrokeFill",
                              "quadrantExternalBorderStrokeFill", "quadrantTitleFill"])
                + ["quadrantChart.xAxisPosition", "quadrantChart.yAxisPosition"]),
        Family(name: "xychart", body: """
            xychart-beta
                title "S"
                x-axis "XT" [A, B]
                y-axis "Y" 0 --> 10
                bar [1, 2]
                line [2, 3]
            """,
            paths: themeVars(["backgroundColor", "titleColor", "dataLabelColor", "xAxisLabelColor", "xAxisTitleColor",
                              "xAxisTickColor", "xAxisLineColor", "yAxisLabelColor", "yAxisTitleColor",
                              "yAxisTickColor", "yAxisLineColor", "plotColorPalette"], "xyChart")
                + ["xyChart.chartOrientation"]),
        Family(name: "venn", body: "venn-beta\n  title V\n" + ["A", "B", "C", "D", "E", "F", "G", "H"].map { "  set \($0)\n" }.joined() + "  union A,B",
               paths: themeVars((1...8).map { "venn\($0)" } + ["background", "mainBkg", "vennTitleTextColor"])),
        Family(name: "eventmodeling", body: "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded\ntf 04 rmo View\ntf 05 pcr Proc",
               paths: themeVars(["emUiFill", "emUiStroke", "emProcessorFill", "emProcessorStroke", "emReadModelFill",
                                 "emReadModelStroke", "emCommandFill", "emCommandStroke", "emEventFill", "emEventStroke",
                                 "emSwimlaneBackgroundOdd", "emSwimlaneBackgroundStroke", "emRelationStroke", "emArrowhead"])),
        Family(name: "er", body: "erDiagram\n  CUSTOMER ||--o{ ORDER : places\n  CUSTOMER {\n    int id\n  }",
               paths: ["er.stroke", "er.fill", "er.erEdgeLabelBackground", "er.layoutDirection"]),
        Family(name: "journey", body: "journey\n    title My day\n    section Work\n      Make tea: 5: Me\n      Do work: 1: Me, Cat",
               paths: ["messageAlign", "taskFontFamily", "textPlacement", "titleColor", "titleFontFamily",
                       "titleFontSize", "faceColor"].map { "journey.\($0)" }),
        Family(name: "sankey", body: "sankey\nA,B,10\nB,C,5",
               paths: ["linkColor", "prefix", "suffix", "nodeColors.A", "nodeAlignment", "labelStyle"].map { "sankey.\($0)" }),
        Family(name: "sequence", body: "sequenceDiagram\n  Alice->>Bob: Hello\n  Note right of Bob: hi",
               paths: ["actorFontFamily", "actorFontWeight", "messageFontFamily", "messageFontWeight",
                       "noteFontFamily", "noteFontWeight"].map { "sequence.\($0)" }),
        Family(name: "kanban", body: "kanban\n  Todo\n    id1[Doc]@{ ticket: MC-1, assigned: 'k' }",
               paths: ["kanban.ticketBaseUrl"]),
        Family(name: "gantt", body: "gantt\n    title G\n    dateFormat YYYY-MM-DD\n    section S\n        A :a1, 2014-01-01, 30d",
               paths: ["axisFormat", "tickInterval", "displayMode", "weekday"].map { "gantt.\($0)" }),
        Family(name: "flowchart", body: "graph TD\n  A --> B", paths: ["flowchart.curve", "look", "layout"]),
        Family(name: "state", body: "stateDiagram-v2\n  [*] --> A\n  A --> [*]",
               paths: ["state.defaultRenderer", "state.edgeLengthFactor"]),
        Family(name: "requirement", body: "requirementDiagram\nrequirement r {\nid: 1\n}", paths: ["requirement.look"]),
    ]

    // MARK: - Sources

    private static func yamlSource(_ body: String, path: String, value: String, theme: String?) -> String {
        let parts = path.split(separator: ".").map(String.init)
        var yaml = "---\nconfig:\n"
        if let theme { yaml += "  theme: \(theme)\n" }
        if parts.first == "themeVariables", parts.dropFirst().first == "gitGraph" {
            yaml += "  themeVariables:\n    useGradient: true\n"
            yaml += "    gitGraph:\n      \(parts[2]): '\(value)'\n"
            return yaml + "---\n" + body
        }
        for (depth, part) in parts.enumerated() {
            let indent = String(repeating: "  ", count: depth + 1)
            yaml += depth == parts.count - 1 ? "\(indent)\(part): '\(value)'\n" : "\(indent)\(part):\n"
        }
        return yaml + "---\n" + body
    }

    private static func initSource(_ body: String, path: String, value: String, theme: String?) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
        var json = "\"\(escaped)\""
        for part in path.split(separator: ".").reversed() { json = "{\"\(part)\": \(json)}" }
        if let theme { json = "{\"theme\": \"\(theme)\", " + json.dropFirst() }
        return "%%{init: \(json)}%%\n" + body
    }

    // MARK: - Checks

    /// Text inside `<style>` elements and `style="…"` attributes.
    private static func styleContexts(_ svg: String) -> [Substring] {
        var contexts: [Substring] = []
        var rest = Substring(svg)
        while let open = rest.range(of: "<style") {
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "</style>") else { contexts.append(after); break }
            contexts.append(after[..<close.lowerBound])
            rest = after[close.upperBound...]
        }
        rest = Substring(svg)
        while let open = rest.range(of: "style=\"") {
            let after = rest[open.upperBound...]
            let end = after.firstIndex(of: "\"") ?? after.endIndex
            contexts.append(after[..<end])
            rest = after[end...].dropFirst()
        }
        return contexts
    }

    private static func check(_ family: Family, _ check: (_ svg: String, _ context: String) -> Void) async throws {
        for theme in family.themes {
            for path in family.paths {
                for payload in [scriptPayload, declarationPayload, rulePayload] {
                    for (mode, source) in [
                        ("yaml", yamlSource(family.body, path: path, value: payload, theme: theme)),
                        ("init", initSource(family.body, path: path, value: payload, theme: theme)),
                    ] {
                        let svg: String
                        do {
                            svg = try await DiagramEngine.renderSVG(source: source)
                        } catch where mode == "init" {
                            // A directive none of whose keys a binding accepts
                            // stays in the source, and the timeline parser
                            // refuses it (as it does `{"timeline": {"bogus": 1}}`):
                            // no SVG, so nothing to inject into.
                            continue
                        }
                        check(svg,"\(family.name) \(mode) \(path) theme=\(theme ?? "default") payload=\(payload.prefix(12))")
                    }
                }
            }
        }
    }

    @Test("hostile values never open a script element or close <style> early", arguments: families)
    private func noScript(_ family: Family) async throws {
        try await Self.check(family) { svg, context in
            #expect(!svg.lowercased().contains("<script"), "\(context): script element in SVG")
            let opens = svg.components(separatedBy: "<style").count - 1
            let closes = svg.components(separatedBy: "</style>").count - 1
            #expect(opens == closes, "\(context): <style> closed early (\(opens) opens, \(closes) closes)")
        }
    }

    @Test("hostile values never add a CSS declaration or rule to a style context", arguments: families)
    private func noCSSInjection(_ family: Family) async throws {
        try await Self.check(family) { svg, context in
            let injected = Self.styleContexts(svg).filter { $0.contains("x.invalid") || $0.contains("red}") }
            #expect(injected.isEmpty, "\(context): \(injected.first?.prefix(160) ?? "")")
        }
    }

    /// The ER attribute-divider line used the entity stroke unescaped, so a
    /// `style` statement reached it as well as `config.er.stroke`.
    @Test("an ER style-statement stroke never opens a script element")
    func erStyleStatementStroke() async throws {
        for stroke in ["red\"/><script>alert(1)</script><x a=\"", Self.scriptPayload] {
            let source = "erDiagram\n  CUSTOMER {\n    int id\n  }\n  style CUSTOMER stroke:\(stroke)"
            let svg = try await DiagramEngine.renderSVG(source: source)
            #expect(!svg.lowercased().contains("<script"), "style stroke \(stroke)")
        }
        let svg = try await DiagramEngine.renderSVG(source: "erDiagram\n  CUSTOMER {\n    int id\n  }\n  style CUSTOMER stroke:#123456")
        #expect(svg.contains("stroke=\"#123456\""))
    }

    // MARK: - Legitimate values

    private struct Legit: Sendable, CustomTestStringConvertible {
        let family: String
        let path: String
        let value: String
        var theme: String? = nil
        /// Substring the SVG must contain (defaults to `value`).
        var expected: String? = nil
        var testDescription: String { "\(family) \(path)=\(value)" }
    }

    private static let legitimate: [Legit] = [
        Legit(family: "architecture", path: "themeVariables.archEdgeColor", value: "#ff0000", expected: "stroke: #ff0000"),
        Legit(family: "architecture", path: "themeVariables.archEdgeWidth", value: "12px", expected: "stroke-width: 12px"),
        Legit(family: "architecture", path: "themeVariables.archGroupBorderColor", value: "rgb(1, 2, 3)", expected: "stroke: rgb(1, 2, 3)"),
        Legit(family: "packet", path: "themeVariables.packet.labelColor", value: "#ff0000", expected: "fill: #ff0000"),
        Legit(family: "packet", path: "themeVariables.packet.byteFontSize", value: "12px", expected: "font-size: 12px"),
        Legit(family: "packet", path: "themeVariables.packet.blockStrokeWidth", value: "3px", expected: "stroke-width: 3px"),
        Legit(family: "gitGraph", path: "themeVariables.gitGraph.git0", value: "#ff0000", expected: "stroke: #ff0000"),
        Legit(family: "gitGraph", path: "themeVariables.gitGraph.commitLabelFontSize", value: "12px", expected: "font-size: 12px"),
        Legit(family: "gitGraph", path: "themeVariables.gitGraph.strokeWidth", value: "5px", expected: "stroke-width: 5px"),
        Legit(family: "gitGraph", path: "themeVariables.gitGraph.noteFontWeight", value: "bold", theme: "redux", expected: "font-weight:bold;"),
        Legit(family: "gitGraphBranch", path: "gitGraph.mainBranchName", value: "trunk"),
        Legit(family: "timeline", path: "themeVariables.cScale0", value: "#ff0000"),
        Legit(family: "timeline", path: "timeline.taskFontFamily", value: "\"Open Sans\", serif", expected: "Open Sans"),
        Legit(family: "pie", path: "themeVariables.pie.pie1", value: "#ff0000"),
        Legit(family: "pie", path: "themeVariables.pie.pieStrokeWidth", value: "3px"),
        Legit(family: "pie", path: "themeVariables.pie.fontFamily", value: "\"Open Sans\", sans-serif", expected: "font-family: &quot;Open Sans&quot;, sans-serif"),
        Legit(family: "pie", path: "themeVariables.pie.fontFamily", value: "trebuchet ms, verdana", expected: "font-family: trebuchet ms, verdana"),
        Legit(family: "quadrant", path: "themeVariables.quadrant1Fill", value: "#ff0000"),
        Legit(family: "quadrant", path: "themeVariables.quadrantInternalBorderStrokeFill", value: "#ff0000"),
        Legit(family: "quadrant", path: "themeVariables.quadrantExternalBorderStrokeFill", value: "rgb(1, 2, 3)"),
        Legit(family: "xychart", path: "themeVariables.xyChart.titleColor", value: "#ff0000"),
        Legit(family: "venn", path: "themeVariables.venn1", value: "#ff0000"),
        Legit(family: "eventmodeling", path: "themeVariables.emUiFill", value: "#ff0000"),
        Legit(family: "er", path: "er.stroke", value: "#ff0000", expected: "stroke=\"#ff0000\""),
        Legit(family: "er", path: "er.fill", value: "#00ff00", expected: "fill=\"#00ff00\""),
        Legit(family: "er", path: "er.erEdgeLabelBackground", value: "#0000ff", expected: "fill=\"#0000ff\""),
        Legit(family: "journey", path: "journey.titleColor", value: "#ff0000"),
        Legit(family: "sankey", path: "sankey.nodeColors.A", value: "#ff0000"),
    ]

    @Test("legitimate values still render", arguments: legitimate)
    private func legitimateValues(_ legit: Legit) async throws {
        let body = try #require(Self.families.first { $0.name == legit.family }?.body)
        let expected = legit.expected ?? legit.value
        let yamlSVG = try await DiagramEngine.renderSVG(source: Self.yamlSource(body, path: legit.path, value: legit.value, theme: legit.theme))
        #expect(yamlSVG.contains(expected), "yaml: missing \(expected)")
        let initSVG = try await DiagramEngine.renderSVG(source: Self.initSource(body, path: legit.path, value: legit.value, theme: legit.theme))
        #expect(initSVG.contains(expected), "init: missing \(expected)")
    }
}
