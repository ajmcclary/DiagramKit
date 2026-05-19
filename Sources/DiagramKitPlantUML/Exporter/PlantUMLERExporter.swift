import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML Information Engineering ER syntax from `ErDiagram`.
/// Lossless — no diagnostics emitted.
enum PlantUMLERExport {

    static func emit(_ diagram: ErDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        for entity in diagram.entities {
            lines.append("entity \(entity.key) {")
            let pks = entity.attributes.filter { $0.keys.contains("PK") }
            let rest = entity.attributes.filter { !$0.keys.contains("PK") }
            for attr in pks {
                lines.append("  * \(formatAttribute(attr))")
            }
            if !pks.isEmpty && !rest.isEmpty {
                lines.append("  --")
            }
            for attr in rest {
                lines.append("  \(formatAttribute(attr))")
            }
            lines.append("}")
            lines.append("")
        }
        for rel in diagram.relationships {
            let arrow = arrowFor(
                left: rel.relSpec.cardB,
                right: rel.relSpec.cardA,
                identifying: rel.relSpec.relType == .identifying
            )
            if !rel.roleA.isEmpty {
                lines.append("\(rel.entity1) \(arrow) \(rel.entity2) : \(escape(rel.roleA))")
            } else {
                lines.append("\(rel.entity1) \(arrow) \(rel.entity2)")
            }
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: [])
    }

    private static func formatAttribute(_ attr: ErAttribute) -> String {
        if !attr.type.isEmpty {
            return "\(attr.name) : \(attr.type)"
        }
        return attr.name
    }

    private static func arrowFor(left: ErCardinality, right: ErCardinality, identifying: Bool) -> String {
        let leftSym: String
        switch left {
        case .onlyOne:    leftSym = "||"
        case .zeroOrOne:  leftSym = "|o"
        case .oneOrMore:  leftSym = "}|"
        case .zeroOrMore: leftSym = "}o"
        case .mdParent:   leftSym = "||"
        }
        let rightSym: String
        switch right {
        case .onlyOne:    rightSym = "||"
        case .zeroOrOne:  rightSym = "o|"
        case .oneOrMore:  rightSym = "|{"
        case .zeroOrMore: rightSym = "o{"
        case .mdParent:   rightSym = "||"
        }
        let mid = identifying ? "--" : ".."
        return "\(leftSym)\(mid)\(rightSym)"
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}
