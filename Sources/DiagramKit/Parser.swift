import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport

@available(*, deprecated, message: "Use MermaidImporter instead.")
public enum MermaidParser {

    static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            // Delegate to MermaidImporter — exactly one import path.
            let importer = MermaidImporter()
            return try importer.parse(source).document
        }
    }
}
