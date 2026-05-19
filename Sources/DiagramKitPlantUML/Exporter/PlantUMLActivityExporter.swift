import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML activity syntax from a `ParsedGraphModel` payload.
/// Default idiom for the `.flowchart` payload in `PlantUMLExporter`.
enum PlantUMLActivityExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = model.accTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        for entry in model.nodesInOrder {
            let node = entry.node
            if node.shape == .stadium && node.label == "start" {
                lines.append("start")
            } else if node.shape == .stadium && node.label == "stop" {
                lines.append("stop")
            } else {
                lines.append(":\(escape(node.label));")
            }
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: [])
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: ";", with: "\\;")
         .replacingOccurrences(of: "\n", with: " ")
    }
}
