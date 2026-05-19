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
        var diagnostics: [DiagramDiagnostic] = []
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
                if !isSyntheticActivityID(node.id) {
                    diagnostics.append(.lossyTransform(
                        .idSanitization,
                        message: "PlantUML activity syntax has no explicit node-id form; '\(node.id)' becomes a synthetic id on re-parse"
                    ))
                }
            }
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private static func isSyntheticActivityID(_ id: String) -> Bool {
        guard id.hasPrefix("n_") else { return false }
        let tail = id.dropFirst(2)
        return !tail.isEmpty && tail.allSatisfy(\.isNumber)
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: ";", with: "\\;")
         .replacingOccurrences(of: "\n", with: " ")
    }
}
