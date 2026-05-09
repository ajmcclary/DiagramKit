import Foundation

public enum MermaidParser {
    private static func _diagramLines(from source: String) -> [String] {
        _mermaidSourceLines(from: source, separatedBy: .newlines)
    }

    private static func _decodeXMLEntities(_ s: String) -> String {
        _HTMLEntities.decode(s)
    }

    private static func rawLineArray(_ source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    public static func parse(_ source: String) throws -> MermaidGraph {
        try _withMermaidIssueReporting(operation: "MermaidParser.parse") {
            let decoded = _decodeXMLEntities(source)
            let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

            // Delegate detection and parsing to the canonical diagram registry.
            let header = DiagramHeader.detect(from: processed)
            let descriptor = DiagramRegistry.detect(header)
            return try descriptor.parse(processed, frontmatter)
        }
    }
}
