// Phase 8: Interactivity Primitives — Slice 8D
// DiagramStableElement conformances and lookup builder for class diagrams.

import DiagramKitCommon
import Foundation

// MARK: - PositionedClassNode conformance

extension PositionedClassNode: DiagramStableElement {
    public var stableElementID: String { "class:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

// MARK: - PositionedClassRelationship conformance

extension PositionedClassRelationship: DiagramStableElement {
    /// Stable ID from from+to+title only (source-model fields).
    /// Duplicates disambiguated by the builder via source-order ordinal.
    public var stableElementID: String {
        let seed = [from, to, title ?? ""].joined(separator: "→")
        return "rel:\(StableID.derive(from: seed))"
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
    public var stableElementLabel: String? { title }
}

// MARK: - PositionedClassNamespace conformance

extension PositionedClassNamespace: DiagramStableElement {
    public var stableElementID: String { "namespace:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }

    func allNamespaceElements() -> [any DiagramStableElement] {
        var result: [any DiagramStableElement] = [self]
        for child in children {
            result.append(contentsOf: child.allNamespaceElements())
        }
        return result
    }
}

// MARK: - PositionedClassNote conformance

extension PositionedClassNote: DiagramStableElement {
    public var stableElementID: String { "class-note:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}

// MARK: - Class lookup builder

func _classLookup(
    classes: [PositionedClassNode],
    relationships: [PositionedClassRelationship],
    namespaces: [PositionedClassNamespace],
    notes: [PositionedClassNote]
) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []

    _disambiguateIDs(classes, kind: .node, into: &elements)
    _disambiguateIDs(relationships, kind: .edge, into: &elements)
    for ns in namespaces {
        for el in ns.allNamespaceElements() {
            elements.append((el, .group))
        }
    }
    _disambiguateIDs(notes, kind: .note, into: &elements)

    return DiagramBoundsLookup.build(diagramType: .classDiagram, elements: elements)
}
