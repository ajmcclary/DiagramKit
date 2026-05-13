import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits Mermaid erDiagram source from an `ErDiagram`.
enum MermaidERExport {

    static func emit(_ model: ErDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("erDiagram")

        // Title / accessibility
        if let title = model.diagramTitle {
            let (q, _) = MermaidExportHelpers.quote(title)
            lines.append("  title: \(q)")
        }
        if let accTitle = model.accTitle {
            let (q, _) = MermaidExportHelpers.quote(accTitle)
            lines.append("  accTitle: \(q)")
        }
        if let accDescr = model.accDescr {
            lines.append("  accDescr {")
            lines.append("    \(accDescr)")
            lines.append("  }")
        }

        // Direction
        if model.direction != .tb {
            lines.append("  direction \(model.direction.rawValue.uppercased())")
        }

        // Class definitions
        for (name, cls) in model.classes.sorted(by: { $0.key < $1.key }) {
            let styles = cls.styles.joined(separator: ",")
            lines.append("  classDef \(name) \(styles)")
        }

        // Entities
        for entity in model.entities {
            let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(entity.key)
            diagnostics.append(contentsOf: idDiags)

            // Alias / label
            if !entity.alias.isEmpty && entity.alias != entity.key {
                let (ql, _) = MermaidExportHelpers.quote(entity.alias)
                lines.append("  \(sanitizedId)[\(ql)]")
            }

            // Class assignment
            let cssClasses = entity.cssClasses.trimmingCharacters(in: .whitespaces)
            if cssClasses != "default" && !cssClasses.isEmpty {
                let uniqueClasses = Set(cssClasses.split(separator: " ").map(String.init))
                    .filter { !$0.isEmpty }
                    .sorted()
                if !uniqueClasses.isEmpty {
                    lines.append("  \(sanitizedId):::\(uniqueClasses.joined(separator: ","))")
                }
            }

            // Entity with attributes
            if !entity.attributes.isEmpty {
                lines.append("  \(sanitizedId) {")
                for attr in entity.attributes {
                    let attrType = attr.type
                    let attrName = attr.name
                    let keys = attr.keys.joined(separator: " ")
                    var attrLine = "    \(attrType) \(attrName)"
                    if !keys.isEmpty {
                        attrLine += " \(keys)"
                    }
                    if !attr.comment.isEmpty {
                        let (qc, _) = MermaidExportHelpers.quote(attr.comment)
                        attrLine += " \(qc)"
                    }
                    lines.append(attrLine)
                }
                lines.append("  }")
            }
        }

        // Relationships
        for rel in model.relationships {
            let (sanitized1, d1) = MermaidExportHelpers.sanitizeIdentifier(rel.entity1)
            let (sanitized2, d2) = MermaidExportHelpers.sanitizeIdentifier(rel.entity2)
            diagnostics.append(contentsOf: d1)
            diagnostics.append(contentsOf: d2)

            let card1 = erCardinalitySymbol(rel.relSpec.cardB)
            let card2 = erCardinalitySymbol(rel.relSpec.cardA)
            let identOp = rel.relSpec.relType == .identifying ? "--" : ".."

            var relLine = "  \(sanitized1) \(card1)\(identOp)\(card2) \(sanitized2)"

            if !rel.roleA.isEmpty {
                let (ql, _) = MermaidExportHelpers.quote(rel.roleA)
                relLine += " : \(ql)"
            }

            lines.append(relLine)
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Cardinality symbols

    private static func erCardinalitySymbol(_ card: ErCardinality) -> String {
        switch card {
        case .zeroOrOne: return "|o"
        case .zeroOrMore: return "}o"
        case .oneOrMore: return "}|"
        case .onlyOne: return "||"
        case .mdParent: return "|"
        }
    }
}
