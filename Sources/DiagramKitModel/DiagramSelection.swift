// Phase 8: Interactivity Primitives — Slice 8A
// Stable element reference that survives re-layouts.

// MARK: - DiagramSelection

/// A stable reference to a diagram element that survives re-layouts.
///
/// Consumers treat `elementID` as an opaque string. Use
/// `DiagramBoundsLookup.bounds(of:)` to recover geometry, and
/// `DiagramBoundsLookup.label(for:)` for a human-readable label.
public struct DiagramSelection: Sendable, Hashable, CustomStringConvertible {
    /// The diagram family this element belongs to.
    public var diagramType: DiagramType

    /// Opaque stable element identifier.
    /// Derived from source text; same source → same ID.
    public var elementID: String

    public init(diagramType: DiagramType, elementID: String) {
        self.diagramType = diagramType
        self.elementID = elementID
    }

    public var description: String {
        "\(diagramType.rawValue)::\(elementID)"
    }
}
