import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `block-beta` source from a `BlockDiagram`.
///
/// Walks the `blockDatabase` starting from `rootChildren`. For each
/// node, emits one line at the node's nesting depth (4-space indent
/// per level). Composite blocks open as `block:<id>["<label>"]` and
/// close with `end`. Leaf nodes emit as bare identifiers or with a
/// shape suffix matching `BlockNodeType`. `widthInColumns` becomes a
/// trailing `:<n>` span. `columns <n>` is emitted as the first child
/// line of any composite (including root) that carries a non-default
/// column count. Edges, `classDef`, and `class` lines are appended
/// after the structural tree.
///
/// Body-level title / accessibility metadata is NOT emitted: the
/// block parser does not recognize those keywords (they are
/// frontmatter-only, applied by
/// `MermaidExporter.prependingDocumentTitle`).
enum MermaidBlockExport {

    static func emit(_ model: BlockDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["block-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        // Root-level `columns N` if the root carries an explicit
        // (non-default) column count. Default is -1 (auto).
        if let root = model.blockDatabase["root"], let cols = root.columns, cols != -1 {
            lines.append("    columns \(cols)")
        }

        for childId in model.rootChildren {
            emitNode(id: childId, depth: 1, into: &lines, model: model)
        }

        // Edges after the structural tree.
        for edge in model.edges {
            let arrow = arrowToken(
                thickness: edge.thickness,
                pattern: edge.pattern,
                arrowTypeEnd: edge.arrowTypeEnd,
                arrowTypeStart: edge.arrowTypeStart
            )
            if let label = edge.label, !label.isEmpty {
                lines.append("    \(edge.start) -- \"\(escapeQuotedLabel(label))\" \(arrow) \(edge.end)")
            } else {
                lines.append("    \(edge.start) \(arrow) \(edge.end)")
            }
        }

        // classDefs in alphabetical order for stable output.
        for name in model.classes.keys.sorted() {
            guard let def = model.classes[name] else { continue }
            let joined = def.styles.joined(separator: ",")
            lines.append("    classDef \(name) \(joined)")
        }

        // class assignments: walk nodes and collect class memberships.
        for nid in model.blockDatabase.keys.sorted() {
            guard let node = model.blockDatabase[nid] else { continue }
            for cls in (node.classes ?? []).sorted() {
                lines.append("    class \(nid) \(cls)")
            }
        }

        // node-level `style <id> <styles>` for nodes whose styles
        // come from a direct `style` statement rather than a class.
        // Parser tokenizes commas as separate tokens; reverse that by
        // joining with empty separator so `["a", ",", "b"]` → "a,b".
        for nid in model.blockDatabase.keys.sorted() {
            guard let node = model.blockDatabase[nid] else { continue }
            if let styles = node.styles, !styles.isEmpty {
                lines.append("    style \(nid) \(styles.joined())")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitNode(
        id: String,
        depth: Int,
        into lines: inout [String],
        model: BlockDiagram
    ) {
        let indent = String(repeating: "    ", count: depth)
        guard let node = model.blockDatabase[id] else {
            lines.append("\(indent)\(id)")
            return
        }

        // Auto-generated space nodes — emit as bare `space` keyword.
        if node.type == .space {
            lines.append("\(indent)space")
            return
        }

        if node.type == .composite {
            let head: String
            if node.label.isEmpty {
                head = "block:\(node.id)"
            } else {
                head = "block:\(node.id)[\"\(escapeQuotedLabel(node.label))\"]"
            }
            let span = node.widthInColumns.map { ":\($0)" } ?? ""
            lines.append("\(indent)\(head)\(span)")
            if let cols = node.columns, cols != -1 {
                lines.append("\(indent)    columns \(cols)")
            }
            for childId in node.children {
                emitNode(id: childId, depth: depth + 1, into: &lines, model: model)
            }
            lines.append("\(indent)end")
            return
        }

        // Leaf node.
        let shape = shapeTokens(for: node.type)
        let labelPart: String
        if node.label.isEmpty || node.label == node.id {
            labelPart = ""
        } else if let s = shape {
            labelPart = "\(s.open)\"\(escapeQuotedLabel(node.label))\"\(s.close)"
        } else {
            labelPart = ""
        }
        let spanPart = node.widthInColumns.map { ":\($0)" } ?? ""
        lines.append("\(indent)\(node.id)\(labelPart)\(spanPart)")
    }

    private static func shapeTokens(for type: BlockNodeType) -> (open: String, close: String)? {
        switch type {
        case .square: return ("[", "]")
        case .round: return ("(", ")")
        case .circle: return ("((", "))")
        case .doublecircle: return ("(((", ")))")
        case .diamond: return ("{", "}")
        case .hexagon: return ("{{", "}}")
        case .stadium: return ("([", "])")
        case .subroutine: return ("[[", "]]")
        case .cylinder: return ("[(", ")]")
        case .leanRight: return ("[/", "/]")
        case .leanLeft: return ("[\\", "\\]")
        case .trapezoid: return ("[/", "\\]")
        case .invTrapezoid: return ("[\\", "/]")
        case .rectLeftInvArrow: return (">", "]")
        case .na, .columnSetting, .edge, .space, .composite, .classDef,
             .applyClass, .applyStyles, .blockArrow:
            return nil
        }
    }

    private static func arrowToken(
        thickness: String,
        pattern: String,
        arrowTypeEnd: String,
        arrowTypeStart: String
    ) -> String {
        let stem: String
        if pattern == "dotted" {
            stem = thickness == "thick" ? "=.=" : "-.-"
        } else {
            stem = thickness == "thick" ? "==" : "--"
        }
        let endMark: String
        switch arrowTypeEnd {
        case "arrow_point": endMark = ">"
        case "arrow_circle": endMark = "o"
        case "arrow_cross": endMark = "x"
        default: endMark = ""
        }
        let startMark: String
        switch arrowTypeStart {
        case "arrow_point": startMark = "<"
        case "arrow_circle": startMark = "o"
        case "arrow_cross": startMark = "x"
        default: startMark = "" // includes "arrow_open"
        }
        return "\(startMark)\(stem)\(endMark.isEmpty ? "-" : endMark)"
    }

    private static func escapeQuotedLabel(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
