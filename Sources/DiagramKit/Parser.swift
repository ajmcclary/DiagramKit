import Foundation
import DiagramKitModel
import DiagramKitCommon

public enum MermaidParser {

    private static func _decodeXMLEntities(_ s: String) -> String {
        _HTMLEntities.decode(s)
    }

    static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            let decoded = _decodeXMLEntities(source)
            let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

            // Delegate detection and parsing to the canonical diagram registry.
            let header = DiagramHeader.detect(from: processed)
            let descriptor = DiagramRegistry.detect(header)
            return try descriptor.parse(processed, frontmatter)
        }
    }
}
