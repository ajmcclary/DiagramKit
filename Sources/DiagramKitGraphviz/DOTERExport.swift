import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Detects whether a `DOTDocument` describes an ER diagram.
///
/// A DOT document is treated as an ER diagram when at least one node has
/// `shape=record` with a class-record-style label that does NOT contain
/// visibility markers (those mark class records). A record without visibility
/// markers is the ER form.
enum DOTERProbe {

    static func detectsERDiagram(_ document: DOTDocument) -> Bool {
        var sawRecord = false
        for stmt in document.statements {
            if case .nodeStatement(let node) = stmt {
                let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
                guard attrs["shape"] == "record" else { continue }
                guard let label = attrs["label"], label.hasPrefix("{") else { continue }
                if DOTClassProbe.labelLooksLikeClassRecord(label) {
                    return false
                }
                sawRecord = true
            }
        }
        return sawRecord
    }

    static func isERRecordNode(_ node: DOTNodeStatement) -> Bool {
        let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
        guard attrs["shape"] == "record" else { return false }
        guard let label = attrs["label"], label.hasPrefix("{") else { return false }
        return !DOTClassProbe.labelLooksLikeClassRecord(label)
    }
}

/// Builds an `ErDiagram` from a `DOTDocument` whose record-shaped nodes carry
/// ER-style labels (`{Header|attr|attr}` without visibility markers).
struct DOTERMapper {

    func map(_ document: DOTDocument) -> (ErDiagram, [DiagramDiagnostic]) {
        var entities: [ErEntity] = []
        var relationships: [ErRelationship] = []
        let diagnostics: [DiagramDiagnostic] = []

        let erNodes = document.statements.compactMap { stmt -> DOTNodeStatement? in
            if case .nodeStatement(let n) = stmt, DOTERProbe.isERRecordNode(n) {
                return n
            }
            return nil
        }
        let erNodeIDs = Set(erNodes.map { $0.id })

        for node in erNodes {
            let attrs = Dictionary(uniqueKeysWithValues: node.attributes.map { ($0.key, $0.value) })
            guard let label = attrs["label"] else { continue }
            let parsed = DOTClassProbe.parseRecordLabel(label)
            var attributes: [ErAttribute] = []
            for row in parsed.attributes {
                let cleaned = row.trimmingCharacters(in: .whitespaces)
                let parts = cleaned.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    attributes.append(ErAttribute(type: parts[1], name: parts[0]))
                } else if !cleaned.isEmpty {
                    attributes.append(ErAttribute(type: "", name: cleaned))
                }
            }
            let displayLabel = parsed.header.isEmpty ? node.id : parsed.header
            entities.append(ErEntity(
                key: node.id,
                label: displayLabel,
                attributes: attributes
            ))
        }

        for stmt in document.statements {
            if case .edgeStatement(let edge) = stmt {
                guard erNodeIDs.contains(edge.source), erNodeIDs.contains(edge.target) else { continue }
                let attrs = Dictionary(uniqueKeysWithValues: edge.attributes.map { ($0.key, $0.value) })
                // DOT's UML-ish ER convention encodes cardinality on the
                // arrowtail/arrowhead attributes (`tee`/`crow`/`odot`/etc.).
                // When present, lift them into ErRelSpec.cardA/.cardB so the
                // cardinality survives import; the typed enum drops the
                // arrow attrs implicitly.
                let cardA = Self.cardinalityFromArrowToken(attrs["arrowtail"]) ?? .zeroOrMore
                let cardB = Self.cardinalityFromArrowToken(attrs["arrowhead"]) ?? .zeroOrMore
                let relSpec = ErRelSpec(
                    cardA: cardA,
                    cardB: cardB,
                    relType: .nonIdentifying
                )
                relationships.append(ErRelationship(
                    entity1: edge.source,
                    entity2: edge.target,
                    entityAId: "entity-\(edge.source)-0",
                    entityBId: "entity-\(edge.target)-0",
                    roleA: attrs["label"] ?? "",
                    relSpec: relSpec
                ))
            }
        }

        return (ErDiagram(entities: entities, relationships: relationships), diagnostics)
    }

    /// Maps DOT crow's-foot arrow tokens to `ErCardinality`. Returns nil for
    /// any token outside the closed mapping so callers fall back to default
    /// cardinality.
    static func cardinalityFromArrowToken(_ raw: String?) -> ErCardinality? {
        switch raw?.lowercased() {
        case "tee":      return .onlyOne     // |  (single bar)
        case "odot":     return .zeroOrOne   // ○ (open dot)
        case "crow":     return .oneOrMore   // crow's foot
        case "crowodot": return .zeroOrMore  // crow's foot + open dot
        default:         return nil
        }
    }
}

/// Emits DOT source for the `.erDiagram` payload using DOT's record-shape
/// form. Cardinality is dropped on each side of each relationship with a
/// paired `.cardinalityDrop` diagnostic.
enum DOTERExport {

    static func emit(_ diagram: ErDiagram, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        let graphName = title.flatMap { DOTClassExport.sanitizeDOTID($0) } ?? "ERDiagram"
        lines.append("digraph \(graphName) {")
        if let title = title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(DOTClassExport.quoted(DOTClassExport.singleLineTitle(title)));")
        }

        for entity in diagram.entities {
            let header = entity.label.isEmpty ? entity.key : entity.label
            let attrRows = entity.attributes.map { attr -> String in
                if attr.type.isEmpty {
                    return attr.name
                }
                return "\(attr.name): \(attr.type)"
            }
            let attrsSection = attrRows.joined(separator: "\\n") + (attrRows.isEmpty ? "" : "\\n")
            let labelBody = "{\(header)|\(attrsSection)}"
            lines.append("  \(DOTClassExport.sanitizeDOTID(entity.key)) [shape=record, label=\(DOTClassExport.quoted(labelBody))];")
        }

        for rel in diagram.relationships {
            let relID = "\(rel.entity1)_\(rel.entity2)"
            let src = DOTClassExport.sanitizeDOTID(rel.entity1)
            let tgt = DOTClassExport.sanitizeDOTID(rel.entity2)
            if !rel.label.isEmpty {
                lines.append("  \(src) -> \(tgt) [label=\(DOTClassExport.quoted(rel.label))];")
            } else {
                lines.append("  \(src) -> \(tgt);")
            }
            lines.append("  " + DOTRecoveryMarker.emitERCardinality(
                relationshipId: relID,
                source: rel.relSpec.cardA.rawValue,
                target: rel.relSpec.cardB.rawValue
            ))
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }
}
