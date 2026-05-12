// Phase 8: Interactivity Primitives — Slice 8F
// DiagramStableElement conformances and lookup builder for C4 diagrams.
//
// Note: PositionedC4Relationship uses CGPoint for startPoint/endPoint
// (Apple-only). The conformance guards those with #if canImport(CoreGraphics)
// to match the existing conditional compilation in src_c4_types.swift.
// Full migration to DiagramPoint is deferred to Phase 10.

import DiagramKitCommon
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PositionedC4Shape conformance

extension PositionedC4Shape: DiagramStableElement {
    public var stableElementID: String { "c4-shape:\(alias)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

// MARK: - PositionedC4Boundary conformance

extension PositionedC4Boundary: DiagramStableElement {
    public var stableElementID: String { "c4-boundary:\(alias)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

// MARK: - PositionedC4Relationship conformance

extension PositionedC4Relationship: DiagramStableElement {
    /// Stable ID from from+to+label only. Duplicates disambiguated by the
    /// builder via source-order ordinal.
    public var stableElementID: String {
        let seed = [from, to, label].joined(separator: "→")
        return "c4-rel:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        #if canImport(CoreGraphics)
        let minX = Swift.min(Double(startPoint.x), Double(endPoint.x))
        let maxX = Swift.max(Double(startPoint.x), Double(endPoint.x))
        let minY = Swift.min(Double(startPoint.y), Double(endPoint.y))
        let maxY = Swift.max(Double(startPoint.y), Double(endPoint.y))
        let pad: Double = 8
        return DiagramRect(
            x: minX - pad, y: minY - pad,
            width: maxX - minX + pad * 2,
            height: maxY - minY + pad * 2
        )
        #else
        // Fallback: use label position + padding
        return DiagramRect(
            x: labelX - 8, y: labelY - 8,
            width: labelWidth + 16, height: labelHeight + 16
        )
        #endif
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}

// MARK: - C4 lookup builder

func _c4Lookup(_ diagram: PositionedC4Diagram) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []

    _disambiguateIDs(diagram.shapes, kind: .node, into: &elements)
    _disambiguateIDs(diagram.boundaries, kind: .boundary, into: &elements)
    _disambiguateIDs(diagram.relationships, kind: .edge, into: &elements)

    return DiagramBoundsLookup.build(diagramType: .c4, elements: elements)
}
