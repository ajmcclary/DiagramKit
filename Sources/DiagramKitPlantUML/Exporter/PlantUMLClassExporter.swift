import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML class diagram source from a `ClassDiagram`.
///
/// Pairs with `PlantUMLClassParser` — exports a subset of PlantUML
/// class syntax that the parser can re-import cleanly. Stereotypes,
/// generics, and packages are not emitted; styling is preserved as
/// raw declarations only where the model carries enough information.
enum PlantUMLClassExport {

    static func emit(_ model: ClassDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startuml")

        // Class declarations + members
        for node in model.classes {
            let header = headerLine(for: node)
            if node.attributes.isEmpty, node.methods.isEmpty {
                lines.append(header)
            } else {
                lines.append("\(header) {")
                for attr in node.attributes {
                    lines.append("  \(memberLine(attr))")
                }
                for method in node.methods {
                    lines.append("  \(memberLine(method))")
                }
                lines.append("}")
            }
        }

        // Relationships
        for rel in model.relationships {
            lines.append(relationshipLine(rel))
        }

        // Notes
        for note in model.notes {
            if let target = note.class_, !target.isEmpty {
                lines.append("note right of \(target) : \(escape(note.text))")
            } else {
                lines.append("note \"\(escape(note.text))\" as N\(note.index)")
            }
        }

        lines.append("@enduml")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func headerLine(for node: ClassNode) -> String {
        let kind = headerKind(for: node)
        let displayDiffers = !node.label.isEmpty && node.label != node.id
        if displayDiffers {
            return "\(kind) \"\(escape(node.label))\" as \(node.id)"
        }
        return "\(kind) \(node.id)"
    }

    private static func headerKind(for node: ClassNode) -> String {
        if node.annotations.contains("Interface") { return "interface" }
        if node.annotations.contains("Abstract") { return "abstract class" }
        if node.annotations.contains("Enumeration") { return "enum" }
        if node.annotations.contains("Annotation") { return "annotation" }
        return "class"
    }

    private static func memberLine(_ member: ClassMember) -> String {
        let vis = member.visibility.isEmpty ? "" : member.visibility
        switch member.memberType {
        case .attribute:
            if member.returnType.isEmpty {
                return "\(vis)\(member.id)"
            }
            return "\(vis)\(member.id): \(member.returnType)"
        case .method:
            let returnAnnotation = member.returnType.isEmpty ? "" : ": \(member.returnType)"
            return "\(vis)\(member.id)(\(member.parameters))\(returnAnnotation)"
        }
    }

    private static func relationshipLine(_ rel: ClassRelationship) -> String {
        let lineSegment = arrowSegment(for: rel.relation)
        let leftLabel = rel.relationTitle1.isEmpty ? "" : " \"\(escape(rel.relationTitle1))\""
        let rightLabel = rel.relationTitle2.isEmpty ? "" : " \"\(escape(rel.relationTitle2))\""
        let trailingLabel = rel.title.isEmpty ? "" : " : \(escape(rel.title))"
        return "\(rel.id1)\(leftLabel) \(lineSegment)\(rightLabel) \(rel.id2)\(trailingLabel)"
    }

    private static func arrowSegment(for endpoint: ClassRelationEndpoint) -> String {
        let lineChars: String = (endpoint.lineType == ClassLineType.dotted.rawValue) ? ".." : "--"
        let leftMarker = markerCharacters(forCode: endpoint.type1, side: .left)
        let rightMarker = markerCharacters(forCode: endpoint.type2, side: .right)
        return "\(leftMarker)\(lineChars)\(rightMarker)"
    }

    private enum ArrowSide { case left, right }

    private static func markerCharacters(forCode code: Int, side: ArrowSide) -> String {
        guard let type = ClassRelationType(rawValue: code) else { return "" }
        switch type {
        case .inheritance:
            return side == .left ? "<|" : "|>"
        case .composition:
            return "*"
        case .aggregation:
            return "o"
        case .dependency:
            return side == .left ? "<" : ">"
        case .none, .lollipop:
            return ""
        }
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
