import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits Mermaid class diagram source from a `ClassDiagram`.
enum MermaidClassExport {

    static func emit(_ model: ClassDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("classDiagram")

        // Direction
        let dir = model.direction.uppercased()
        if dir != "TB" {
            lines.append("  direction \(dir)")
        }

        // Title / accessibility
        if let title = model.diagramTitle {
            let (q, _) = MermaidExportHelpers.quote(title)
            lines.append("  title: \(q)")
        }
        if let accTitle = model.accTitle {
            let (q, _) = MermaidExportHelpers.quote(accTitle)
            lines.append("  accTitle: \(q)")
        }
        if let accDescr = model.accDescription {
            lines.append("  accDescr {")
            for descLine in accDescr.split(separator: "\n") {
                lines.append("    \(descLine)")
            }
            lines.append("  }")
        }

        // Namespaces
        for ns in model.namespaces.sorted(by: { $0.id < $1.id }) {
            emitNamespace(ns, indent: 1, lines: &lines, diagnostics: &diagnostics)
        }

        // Classes
        for cls in model.classes {
            let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(cls.id)
            diagnostics.append(contentsOf: idDiags)

            // Annotations
            for annotation in cls.annotations {
                let (q, _) = MermaidExportHelpers.quote(annotation)
                lines.append("  <<\(q)>> \(sanitizedId)")
            }

            // Class declaration
            var classLine = ""
            if cls.type != nil {
                classLine = "  class \(sanitizedId)~\(cls.type!)~"
            } else if cls.label != cls.id && !cls.label.isEmpty {
                let (escapedLabel, ld) = MermaidExportHelpers.escapeBracketLabel(cls.label)
                diagnostics.append(contentsOf: ld)
                classLine = "  class \(sanitizedId)[\(escapedLabel)]"
            } else {
                classLine = "  class \(sanitizedId)"
            }

            // Style class
            let cssClasses = cls.cssClasses.trimmingCharacters(in: .whitespaces)
            if cssClasses != "default" && !cssClasses.isEmpty {
                let uniqueClasses = Set(cssClasses.split(separator: " ").map(String.init))
                    .filter { !$0.isEmpty }
                    .sorted()
                if !uniqueClasses.isEmpty {
                    classLine += "::: \(uniqueClasses.joined(separator: ","))"
                }
            }

            let hasMembers = !cls.attributes.isEmpty || !cls.methods.isEmpty
            if hasMembers {
                classLine += " {"
            }
            lines.append(classLine)

            // Members
            for attr in cls.attributes {
                let memberStr = formatMember(attr)
                lines.append("    \(memberStr)")
            }
            for method in cls.methods {
                let memberStr = formatMember(method)
                lines.append("    \(memberStr)")
            }

            if hasMembers {
                lines.append("  }")
            }
        }

        // Notes
        for note in model.notes {
            let (qText, nd) = MermaidExportHelpers.quote(note.text)
            diagnostics.append(contentsOf: nd)

            if let classId = note.class_ {
                let (sanitizedClassId, _) = MermaidExportHelpers.sanitizeIdentifier(classId)
                lines.append("  note for \(sanitizedClassId) \(qText)")
            } else {
                lines.append("  note \(qText)")
            }
        }

        // Relationships
        for rel in model.relationships {
            let (sanitized1, d1) = MermaidExportHelpers.sanitizeIdentifier(rel.id1)
            let (sanitized2, d2) = MermaidExportHelpers.sanitizeIdentifier(rel.id2)
            diagnostics.append(contentsOf: d1)
            diagnostics.append(contentsOf: d2)

            let arrow = classArrow(rel.relation)
            var relLine = "  \(sanitized1) \(arrow) \(sanitized2)"

            if !rel.relationTitle1.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.relationTitle1)
                relLine = "  \(sanitized1) \(q) \(arrow) \(sanitized2)"
            }
            if !rel.relationTitle2.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.relationTitle2)
                relLine += " \(q)"
            }

            if !rel.title.isEmpty {
                let (q, _) = MermaidExportHelpers.quote(rel.title)
                relLine += " : \(q)"
            }

            lines.append(relLine)
        }

        // Style classes (classDef)
        for styleClass in model.styleClasses {
            let joinedStyles = styleClass.styles.joined(separator: ",")
            lines.append("  classDef \(styleClass.id) \(joinedStyles)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Namespace emission

    private static func emitNamespace(
        _ ns: ClassNamespace,
        indent: Int,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let pad = String(repeating: "  ", count: indent)
        let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(ns.id)
        diagnostics.append(contentsOf: idDiags)

        if ns.label.isEmpty || ns.label == ns.id {
            lines.append("\(pad)namespace \(sanitizedId) {")
        } else {
            let (ql, _) = MermaidExportHelpers.quote(ns.label)
            lines.append("\(pad)namespace \(sanitizedId)[\(ql)] {")
        }

        for child in ns.children {
            emitNamespace(child, indent: indent + 1, lines: &lines, diagnostics: &diagnostics)
        }

        lines.append("\(pad)}")
    }

    // MARK: - Member formatting

    private static func formatMember(_ member: ClassMember) -> String {
        let vis = member.visibility
        if member.memberType == .method {
            let params = member.parameters
            let ret = member.returnType.isEmpty ? "" : " \(member.returnType)"
            return "\(vis)\(member.id)(\(params))\(ret)"
        } else {
            return "\(vis)\(member.id) \(member.returnType)"
        }
    }

    // MARK: - Arrow conversion

    private static func classArrow(_ endpoint: ClassRelationEndpoint) -> String {
        let t1 = endpoint.type1
        let t2 = endpoint.type2
        let line = endpoint.lineType

        var left = ""
        var right = ""

        switch t1 {
        case 0: left = "o"    // aggregation
        case 1: left = "<|"   // inheritance
        case 2: left = "*"    // composition
        case 3: left = "<"    // dependency
        case 4: left = "()"   // lollipop
        default: break
        }

        switch t2 {
        case 0: right = "o"
        case 1: right = "|>"
        case 2: right = "*"
        case 3: right = ">"
        case 4: right = "()"
        default: break
        }

        let mid = line == 1 ? ".." : "--"

        if t1 == -1 {
            // Right-pointing only
            return "\(mid)\(right)"
        } else if t2 == -1 {
            return "\(left)\(mid)"
        } else {
            return "\(left)\(mid)\(right)"
        }
    }
}
