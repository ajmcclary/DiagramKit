import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `journey` source from a `JourneyDiagram`.
///
/// Lossless: title → accessibility metadata → tasks grouped under
/// their `section` field with section transitions emitted as
/// `section <name>` lines. Empty section (`""`) emits raw tasks
/// without a `section` header.
enum MermaidJourneyExport {

    static func emit(_ model: JourneyDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["journey"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            if accDescr.contains("\n") {
                lines.append("    accDescr: {")
                for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("        \(sub)")
                }
                lines.append("    }")
            } else {
                lines.append("    accDescr: \(accDescr)")
            }
        }

        var currentSection: String? = nil
        for task in model.tasks {
            if task.section != currentSection {
                if !task.section.isEmpty {
                    lines.append("    section \(singleLine(task.section))")
                }
                currentSection = task.section
            }
            let people = task.people.joined(separator: ",")
            lines.append("      \(singleLine(task.task)): \(task.score): \(people)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
