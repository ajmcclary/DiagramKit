import Foundation

public enum MermaidParser {
    private static func _diagramLines(from source: String) -> [String] {
        _mermaidSourceLines(from: source, separatedBy: .newlines)
    }

    private static func _decodeXMLEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
    }

    public static func parse(_ source: String) throws -> MermaidGraph {
        try _withMermaidIssueReporting(operation: "MermaidParser.parse") {
            let decoded = _decodeXMLEntities(source)
            let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)
            let lines = _mermaidSourceLines(from: processed, separatedBy: .newlines)
            let firstLine = lines.first?.lowercased() ?? ""

            if firstLine.hasPrefix("journey") {
                let journeyLines = _mermaidSourceLines(from: processed)
                let parsed = try parseJourneyDiagram(journeyLines, frontmatter: frontmatter)
                return MermaidGraph(payload: .journey(parsed))
            }
            if firstLine.hasPrefix("sequencediagram") {
                let parsed = try parseSequenceDiagram(lines)
                return MermaidGraph(payload: .sequenceDiagram(parsed))
            }
            if firstLine.hasPrefix("classdiagram") {
                let parsed = try parseClassDiagram(lines, frontmatter: frontmatter)
                return MermaidGraph(payload: .classDiagram(parsed))
            }
            if firstLine.hasPrefix("erdiagram") {
                let parsed = try parseErDiagram(lines, frontmatter: frontmatter)
                return MermaidGraph(payload: .erDiagram(parsed))
            }
            if firstLine.hasPrefix("xychart") {
                var chart = try parseXYChart(lines)
                if let fm = frontmatter {
                    chart.config = fm.xyChartConfig
                    chart.theme = fm.xyChartTheme
                    if chart.titleText == nil, let fmTitle = fm.diagramTitle {
                        chart.diagramTitle = fmTitle
                    }
                }
                return MermaidGraph(payload: .xyChart(chart))
            }
            if firstLine.hasPrefix("pie") {
                var chart = try parsePieChart(lines, frontmatter: frontmatter)
                if let fm = frontmatter {
                    if let cfg = fm.pieConfig { chart.config = cfg }
                    if let theme = fm.pieTheme { chart.theme = theme }
                    if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle {
                        chart.diagramTitle = fmTitle
                    }
                }
                return MermaidGraph(payload: .pie(chart))
            }
            if firstLine.hasPrefix("gantt") {
                let ganttLines = _mermaidSourceLines(from: processed,
                    separatedBy: CharacterSet(charactersIn: "\n"))
                let parsed = try parseGanttDiagram(ganttLines, frontmatter: frontmatter)
                return MermaidGraph(payload: .gantt(parsed))
            }
            if firstLine.hasPrefix("quadrantchart") {
                var chart = try parseQuadrantChart(lines, frontmatter: frontmatter)
                if let fm = frontmatter {
                    if let cfg = fm.quadrantChartConfig { chart.config = cfg }
                    if let theme = fm.quadrantChartTheme { chart.theme = theme }
                    if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle {
                        chart.diagramTitle = fmTitle
                    }
                }
                if chart.titleText == nil, let dt = chart.diagramTitle {
                    chart.titleText = dt
                }
                return MermaidGraph(payload: .quadrantChart(chart))
            }

            // Flowchart + stateDiagram-v2 — pass frontmatter flowchart config
            let parsed = try parseMermaid(processed, config: frontmatter?.flowchartConfig)
            let parsedType: DiagramType = firstLine.hasPrefix("statediagram") ? .stateDiagram : .flowchart
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                return MermaidGraph(payload: parsedType == .stateDiagram ? .stateDiagram(model) : .flowchart(model))
            default:
                return parsed
            }
        }
    }
}
