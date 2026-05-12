// Phase 8: Interactivity Primitives — Slice 8E
// DiagramStableElement conformances and lookup builder for ER diagrams.

import DiagramKitCommon
import Foundation

// MARK: - PositionedErEntity conformance

extension PositionedErEntity: DiagramStableElement {
    public var stableElementID: String { "entity:\(nodeId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? id : label }
}

// MARK: - PositionedErRelationship conformance

extension PositionedErRelationship: DiagramStableElement {
    /// Stable ID from entity1+entity2+label only. Duplicates disambiguated
    /// by the builder via source-order ordinal.
    public var stableElementID: String {
        let seed = [entity1, entity2, label].joined(separator: "↔")
        return "er-rel:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        let pad = 8.0
        return DiagramRect(
            x: minX - pad, y: minY - pad,
            width: maxX - minX + pad * 2,
            height: maxY - minY + pad * 2
        )
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}

// MARK: - ER lookup builder

func _erLookup(
    entities: [PositionedErEntity],
    relationships: [PositionedErRelationship]
) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []

    _disambiguateIDs(entities, kind: .node, into: &elements)
    _disambiguateIDs(relationships, kind: .edge, into: &elements)

    return DiagramBoundsLookup.build(diagramType: .erDiagram, elements: elements)
}
