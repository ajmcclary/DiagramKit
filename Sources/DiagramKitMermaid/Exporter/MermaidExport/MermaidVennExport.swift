import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `venn-beta` source from a `VennDiagram`.
///
/// Lossless: header → title → accessibility metadata → `set <name>`
/// lines for single-set areas → `union <a>,<b>[,…]["label"]` lines
/// for multi-set areas. Set member lists are sorted within each area
/// for canonical output.
enum MermaidVennExport {

    static func emit(_ model: VennDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["venn-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("  title \"\(escape(singleLine(title)))\"")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("  accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("  accDescr: \(singleLine(accDescr))")
        }

        for area in model.areas {
            let sets = area.sets.sorted()
            let labelSuffix: String
            if let l = area.label, !l.isEmpty {
                labelSuffix = "[\"\(escape(singleLine(l)))\"]"
            } else {
                labelSuffix = ""
            }
            let quotedSets = sets.map(quoteSetIfNeeded)
            if quotedSets.count == 1 {
                lines.append("  set \(quotedSets[0])\(labelSuffix)")
            } else {
                lines.append("  union \(quotedSets.joined(separator: ","))\(labelSuffix)")
            }
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

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Wrap a set identifier in double quotes when it contains a
    /// character (space, comma, bracket, quote) that would otherwise
    /// split the parser's identifier token.
    private static func quoteSetIfNeeded(_ name: String) -> String {
        let s = singleLine(name)
        if s.contains(" ") || s.contains(",") || s.contains("[") || s.contains("]") || s.contains("\"") {
            return "\"\(escape(s))\""
        }
        return s
    }
}
