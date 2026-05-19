import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `timeline` source from a `TimelineDiagram`.
///
/// Lossless: title → accessibility metadata → tasks grouped under
/// their section field, with each task's events joined inline by
/// ` : ` separators. Section transitions use the shared
/// `MermaidExportHelpers.emitSectionedItems` helper introduced when
/// timeline became the second caller of the pattern.
enum MermaidTimelineExport {

    static func emit(_ model: TimelineDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["timeline"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
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

        let taskLines = MermaidExportHelpers.emitSectionedItems(
            model.tasks,
            sectionOf: { singleLine($0.section) },
            sectionIndent: "    ",
            emitItem: { task in
                let eventStrings = task.events.map { singleLine($0.text) }
                let head = "    \(singleLine(task.text))"
                if eventStrings.isEmpty {
                    return head
                }
                return "\(head) : \(eventStrings.joined(separator: " : "))"
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
