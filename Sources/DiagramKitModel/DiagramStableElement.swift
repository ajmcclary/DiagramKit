// Phase 8: Interactivity Primitives — Slice 8A
// Protocol for positioned elements with stable identity and bounds.

import DiagramKitCommon

// MARK: - DiagramStableElement

/// A positioned diagram element with a stable, source-derived identifier
/// and a bounding rectangle suitable for spatial lookup.
///
/// Conforming types guarantee that `stableElementID` is deterministic
/// from source text — same source → same ID — and survives re-layouts
/// with different `LayoutConfig`.
public protocol DiagramStableElement: Sendable {
    /// A stable, source-derived identifier for this element.
    /// Must be deterministic: same source text → same ID.
    /// Must survive re-layouts with different `LayoutConfig`.
    var stableElementID: String { get }

    /// The bounding rectangle of this element in diagram coordinates.
    var stableElementBounds: DiagramRect { get }

    /// A human-readable label for display, or nil.
    var stableElementLabel: String? { get }
}
