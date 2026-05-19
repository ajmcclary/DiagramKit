import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `D2Document` describes an ER diagram.
///
/// A D2 document is treated as an ER diagram when at least one container has
/// a `shape: sql_table` inner statement. Class diagrams (containers with
/// `shape: class`) take precedence.
enum D2ERProbe {

    static func detectsERDiagram(_ document: D2Document) -> Bool {
        if D2ClassProbe.detectsClassDiagram(document) { return false }
        var depth = 0
        var currentDepthIsERTable = false
        var sawER = false
        for stmt in document.statements {
            switch stmt {
            case .containerOpen:
                depth += 1
                currentDepthIsERTable = false
            case .containerClose:
                if currentDepthIsERTable { sawER = true }
                depth -= 1
                currentDepthIsERTable = false
            case .nodeDefinition(let def):
                if depth > 0 && def.id == "shape" && (def.label?.lowercased() == "sql_table") {
                    currentDepthIsERTable = true
                }
            default:
                break
            }
        }
        return sawER
    }
}

/// Builds an `ErDiagram` from a `D2Document` whose containers carry
/// `shape: sql_table` markers. Cardinality is not encoded by D2; relationships
/// receive default `.zeroOrMore` cardinality on both sides.
struct D2ERMapper {

    func map(_ document: D2Document) -> (ErDiagram, [DiagramDiagnostic]) {
        var entities: [ErEntity] = []
        var relationships: [ErRelationship] = []
        let diagnostics: [DiagramDiagnostic] = []

        var stack: [PartialEntity] = []

        for stmt in document.statements {
            switch stmt {
            case .containerOpen(let open):
                stack.append(PartialEntity(key: open.id, label: open.label ?? open.id))
            case .containerClose:
                guard !stack.isEmpty else { break }
                let partial = stack.removeLast()
                if partial.isTable {
                    entities.append(partial.makeEntity())
                }
            case .nodeDefinition(let def):
                if !stack.isEmpty {
                    let topIdx = stack.count - 1
                    if def.id == "shape" && def.label?.lowercased() == "sql_table" {
                        stack[topIdx].isTable = true
                        continue
                    }
                    if stack[topIdx].isTable {
                        stack[topIdx].appendAttribute(name: def.id, type: def.label ?? "")
                    }
                }
            case .edgeDefinition(let edge):
                let source = edge.source.split(separator: ".").first.map(String.init) ?? edge.source
                let target = edge.target.split(separator: ".").first.map(String.init) ?? edge.target
                let relSpec = ErRelSpec(
                    cardA: .zeroOrMore,
                    cardB: .zeroOrMore,
                    relType: .nonIdentifying
                )
                relationships.append(ErRelationship(
                    entity1: source,
                    entity2: target,
                    entityAId: "entity-\(source)-0",
                    entityBId: "entity-\(target)-0",
                    roleA: edge.label ?? "",
                    relSpec: relSpec
                ))
            default:
                break
            }
        }

        return (ErDiagram(entities: entities, relationships: relationships), diagnostics)
    }
}

private struct PartialEntity {
    var key: String
    var label: String
    var isTable: Bool = false
    var attributes: [ErAttribute] = []

    mutating func appendAttribute(name: String, type: String) {
        attributes.append(ErAttribute(type: type, name: name))
    }

    func makeEntity() -> ErEntity {
        ErEntity(
            key: key,
            label: label,
            attributes: attributes
        )
    }
}

/// Emits D2 source for the `.erDiagram` payload using D2's `shape: sql_table`
/// block form. Cardinality is dropped on each side of each relationship with a
/// paired `.cardinalityDrop` diagnostic.
enum D2ERExport {

    static func emit(_ diagram: ErDiagram, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        if let title = title, !title.isEmpty {
            lines.append("# title: \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        for entity in diagram.entities {
            lines.append("\(D2ERExport.sanitizeID(entity.key)): {")
            lines.append("  shape: sql_table")
            for attr in entity.attributes {
                let type = attr.type.isEmpty ? "" : ": \(attr.type)"
                lines.append("  \(attr.name)\(type)")
            }
            lines.append("}")
            lines.append("")
        }

        for rel in diagram.relationships {
            let relID = "\(rel.entity1)_\(rel.entity2)"
            diagnostics.append(.lossyTransform(
                .cardinalityDrop,
                message: "D2 has no native ER cardinality syntax; dropping source cardinality '\(rel.cardinality2)' on \(rel.entity1)→\(rel.entity2)"
            ))
            diagnostics.append(.lossyTransform(
                .cardinalityDrop,
                message: "D2 has no native ER cardinality syntax; dropping target cardinality '\(rel.cardinality1)' on \(rel.entity1)→\(rel.entity2)"
            ))
            let src = sanitizeID(rel.entity1)
            let tgt = sanitizeID(rel.entity2)
            if !rel.label.isEmpty {
                lines.append("\(src) -> \(tgt): \(rel.label)")
            } else {
                lines.append("\(src) -> \(tgt)")
            }
            _ = relID
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    static func sanitizeID(_ raw: String) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { result.append("_") }
                result.append(ch)
            case " ", "-", ".":
                result.append("_")
            default: break
            }
        }
        return result.isEmpty ? "node" : result
    }
}
