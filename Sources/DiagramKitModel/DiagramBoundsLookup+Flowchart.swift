// Phase 8: Interactivity Primitives — Slice 8B
// DiagramStableElement conformances and lookup builder for flowchart + state diagrams.

import DiagramKitCommon
import Foundation

// MARK: - PositionedNode conformance

extension PositionedNode: DiagramStableElement {
    public var stableElementID: String { "node:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

// MARK: - PositionedEdge conformance

extension PositionedEdge {
    /// Guaranteed stable edge identifier.
    /// Uses `edgeId` when present; falls back to a deterministic synthetic
    /// ID derived purely from source model fields (no layout geometry).
    /// The lookup builder passes a source-order ordinal to disambiguate
    /// repeated edges with identical source+target+label; that ordinal is
    /// appended by the builder, not this property.
    public var guaranteedEdgeID: String {
        if let edgeId, !edgeId.isEmpty { return "edge:\(edgeId)" }
        let seed = [source, target, label ?? ""].joined(separator: "→")
        return "edge:\(StableID.derive(from: seed))"
    }
}

extension PositionedEdge: DiagramStableElement {
    public var stableElementID: String { guaranteedEdgeID }
    public var stableElementBounds: DiagramRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        let pad = 8.0 // hit-target padding
        return DiagramRect(
            x: minX - pad, y: minY - pad,
            width: maxX - minX + pad * 2,
            height: maxY - minY + pad * 2
        )
    }
    public var stableElementLabel: String? { label }
}

// MARK: - PositionedGroup conformance

extension PositionedGroup: DiagramStableElement {
    public var stableElementID: String { "group:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }

    /// All elements in this group hierarchy (self + children).
    func allGroupElements() -> [any DiagramStableElement] {
        var result: [any DiagramStableElement] = [self]
        for child in children {
            result.append(contentsOf: child.allGroupElements())
        }
        return result
    }
}

// MARK: - Flowchart lookup builder

func _flowchartLookup(
    diagramType: DiagramType,
    nodes: [PositionedNode],
    edges: [PositionedEdge],
    groups: [PositionedGroup]
) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []

    _disambiguateIDs(nodes, kind: .node, into: &elements)
    _disambiguateIDs(edges, kind: .edge, into: &elements)
    for group in groups {
        for el in group.allGroupElements() {
            elements.append((el, .group))
        }
    }
    return DiagramBoundsLookup.build(diagramType: diagramType, elements: elements)
}
