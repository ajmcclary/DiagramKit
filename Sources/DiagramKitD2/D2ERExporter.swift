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
                // Try to recognize a `{lo..hi}` cardinality marker in the
                // edge label. When recognized, the label is consumed; when
                // not, the original label survives as the relationship's
                // roleA text (preserving D2's free-form label semantics).
                let parsed = Self.parseCardinalityLabel(edge.label)
                let cardA: ErCardinality = parsed?.cardA ?? .zeroOrMore
                let cardB: ErCardinality = parsed?.cardB ?? .zeroOrMore
                let label: String = parsed == nil ? (edge.label ?? "") : ""
                let relSpec = ErRelSpec(
                    cardA: cardA,
                    cardB: cardB,
                    relType: .nonIdentifying
                )
                relationships.append(ErRelationship(
                    entity1: source,
                    entity2: target,
                    entityAId: "entity-\(source)-0",
                    entityBId: "entity-\(target)-0",
                    roleA: label,
                    relSpec: relSpec
                ))
            default:
                break
            }
        }

        return (ErDiagram(entities: entities, relationships: relationships), diagnostics)
    }

    /// Parses a D2 edge label like `"{1..N}"`, `"{0..1}"`, `"{0..N}"`, `"{1..1}"`
    /// into a `(cardA, cardB)` pair. Returns nil for any label that does
    /// not match the closed grammar; conservative recognition avoids
    /// consuming user-authored free-form labels.
    ///
    /// Mapping:
    /// - `{0..1}` → (zeroOrOne, zeroOrOne)
    /// - `{0..N}` / `{0..n}` / `{0..*}` → (zeroOrOne, zeroOrMore)
    /// - `{1..1}` → (onlyOne, onlyOne)
    /// - `{1..N}` / `{1..n}` / `{1..*}` → (onlyOne, oneOrMore)
    static func parseCardinalityLabel(_ raw: String?) -> (cardA: ErCardinality, cardB: ErCardinality)? {
        guard let raw = raw else { return nil }
        var s = raw.trimmingCharacters(in: .whitespaces)
        // Strip wrapping quotes if present.
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        }
        s = s.trimmingCharacters(in: .whitespaces)
        guard s.hasPrefix("{") && s.hasSuffix("}") && s.count >= 5 else { return nil }
        let inner = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        let parts = inner.components(separatedBy: "..")
        guard parts.count == 2 else { return nil }
        let lo = parts[0].trimmingCharacters(in: .whitespaces)
        let hi = parts[1].trimmingCharacters(in: .whitespaces)
        switch (lo, hi.lowercased()) {
        case ("0", "1"): return (.zeroOrOne, .zeroOrOne)
        case ("0", "n"), ("0", "*"): return (.zeroOrOne, .zeroOrMore)
        case ("1", "1"): return (.onlyOne, .onlyOne)
        case ("1", "n"), ("1", "*"): return (.onlyOne, .oneOrMore)
        default: return nil
        }
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
        let diagnostics: [DiagramDiagnostic] = []

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
            let src = sanitizeID(rel.entity1)
            let tgt = sanitizeID(rel.entity2)
            if !rel.label.isEmpty {
                lines.append("\(src) -> \(tgt): \(rel.label)")
            } else {
                lines.append("\(src) -> \(tgt)")
            }
            lines.append(D2RecoveryMarker.emitERCardinality(
                relationshipId: relID,
                source: rel.relSpec.cardA.rawValue,
                target: rel.relSpec.cardB.rawValue
            ))
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
