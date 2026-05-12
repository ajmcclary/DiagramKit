import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport

public enum MermaidParser {

    static func parse(_ source: String) throws -> DiagramDocument {
        try _withDiagramIssueReporting(operation: "MermaidParser.parse") {
            // Delegate to MermaidImporter — exactly one import path.
            let importer = MermaidImporter()
            return try importer.parse(source).document
        }
    }
}
