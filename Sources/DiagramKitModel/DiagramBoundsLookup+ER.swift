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
        DiagramRect.bounding(points: points, paddedBy: 8.0)
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
