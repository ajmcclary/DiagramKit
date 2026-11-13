import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `kanban` source from a `KanbanDiagram`.
///
/// Lossless: each section emits as a column header at indent 4, with
/// its child nodes at indent 8. Metadata (`assigned`, `ticket`,
/// `priority`) is emitted as a sorted `@{ ... }` block on the line
/// following the node label.
enum MermaidKanbanExport {

    static func emit(_ model: KanbanDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["kanban"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            // The kanban parser does not accept the block accDescr
            // form; collapse newlines so re-parse stays in sync.
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        for section in model.sections {
            lines.append("    \(section.id)[\(escapeLabel(section.label, diagnostics: &diagnostics))]")
            let children = model.nodes.filter { $0.parentId == section.id }
            for node in children {
                let labelPart = "\(node.id)[\(escapeLabel(node.label, diagnostics: &diagnostics))]"
                let meta = formatMetadata(node)
                if meta.isEmpty {
                    lines.append("        \(labelPart)")
                } else {
                    // Metadata must ride the same line as the label;
                    // the parser treats a bare `id@{ ... }` line as
                    // a separate node declaration.
                    lines.append("        \(labelPart)@{ \(meta) }")
                }
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    /// The kanban parser has no backslash escapes (a `\"` came back with
    /// its backslash, one more per export); it reads node text between
    /// matching brackets, toggles quoting on `"`, and decodes entity codes
    /// afterwards. So `"` and anything else it would read as syntax go out
    /// as entity codes; brackets only when they are unbalanced, and an
    /// apostrophe only at either end (where it would be stripped as a quote).
    private static func escapeLabel(_ text: String, diagnostics: inout [DiagramDiagnostic]) -> String {
        var depth = 0
        var balanced = true
        for ch in text {
            if ch == "[" { depth += 1 }
            if ch == "]" { depth -= 1; if depth < 0 { balanced = false } }
        }
        if depth != 0 { balanced = false }
        let (escaped, diags) = MermaidExportHelpers.entityCodedText(
            text, alsoEncode: balanced ? [] : ["[", "]"], edgeApostrophes: true
        )
        diagnostics.append(contentsOf: diags)
        return escaped
    }

    /// Metadata keys are emitted in fixed alphabetical order so the
    /// round-trip is stable regardless of the order the parser
    /// populated `KanbanNode`.
    private static func formatMetadata(_ node: KanbanNode) -> String {
        var pairs: [(String, String)] = []
        if let assigned = node.assigned, !assigned.isEmpty {
            pairs.append(("assigned", assigned))
        }
        if let priority = node.priority, !priority.isEmpty {
            pairs.append(("priority", priority))
        }
        if let ticket = node.ticket, !ticket.isEmpty {
            pairs.append(("ticket", ticket))
        }
        return pairs.map { "\($0.0): '\($0.1)'" }.joined(separator: ", ")
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
