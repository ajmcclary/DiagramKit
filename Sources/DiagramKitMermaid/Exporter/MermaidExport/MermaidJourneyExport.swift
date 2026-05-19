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
            // The journey parser does not accept the block accDescr
            // form; collapse newlines so re-parse stays in sync.
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        let taskLines = MermaidExportHelpers.emitSectionedItems(
            model.tasks,
            sectionOf: { singleLine($0.section) },
            sectionIndent: "    ",
            emitItem: { task in
                let people = task.people.joined(separator: ",")
                return "      \(singleLine(task.task)): \(task.score): \(people)"
            }
        )
        lines.append(contentsOf: taskLines)

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
