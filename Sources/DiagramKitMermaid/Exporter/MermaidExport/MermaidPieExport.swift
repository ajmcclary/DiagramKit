import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `pie` source from a `PieChart`.
///
/// Lossless: header → optional `showData` → optional title → optional
/// accessibility metadata → quoted section labels with numeric values.
enum MermaidPieExport {

    static func emit(_ model: PieChart) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        var header = "pie"
        if model.showData {
            header += " showData"
        }
        if let title = model.diagramTitle, !title.isEmpty {
            header += " title \(singleLine(title))"
        }
        lines.append(header)

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

        for section in model.sections {
            let (quoted, qDiags) = MermaidExportHelpers.quote(section.label)
            diagnostics.append(contentsOf: qDiags)
            lines.append("    \(quoted) : \(formatNumber(section.value))")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
}
