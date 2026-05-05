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
            let decoded = _preprocessMermaidSource(_decodeXMLEntities(source))
            let lines = _diagramLines(from: decoded)
            let firstLine = lines.first?.lowercased() ?? ""

            if firstLine.hasPrefix("sequencediagram") {
                let parsed = try parseSequenceDiagram(lines)
                return MermaidGraph(payload: .sequenceDiagram(parsed))
            }
            if firstLine.hasPrefix("classdiagram") {
                let parsed = try parseClassDiagram(lines)
                return MermaidGraph(payload: .classDiagram(parsed))
            }
            if firstLine.hasPrefix("erdiagram") {
                let parsed = try parseErDiagram(lines)
                return MermaidGraph(payload: .erDiagram(parsed))
            }
            if firstLine.hasPrefix("xychart") {
                let chart = parseXYChart(lines)
                return MermaidGraph(payload: .xyChart(chart))
            }

            // Flowchart + stateDiagram-v2 share the same parser entry in the original TS.
            let parsed = try parseMermaid(decoded)
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
