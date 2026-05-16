import Foundation
import DiagramKitCommon

/// Registry of every SVG `<marker>` the sequence renderer emits, plus the
/// classification logic that maps a `SequenceArrowStyle` to its marker ID.
///
/// The CG renderer reaches into the same catalog (via `marker(for:)`) so the
/// two renderers agree on which geometry corresponds to which arrow type.
public enum SequenceArrowheadCatalog {
    /// All marker definitions, in the order `_arrowMarkerDefs()` historically
    /// emitted them. Order is kept stable so corpus SVG snapshots remain
    /// byte-identical after the refactor.
    public static let allMarkers: [SequenceArrowheadMarker] = [
        .init(id: "seq-arrow-filled",            geometry: .filledTriangle,                                       dims: .standard),
        .init(id: "seq-arrow-open",              geometry: .openV,                                                dims: .standard),
        .init(id: "seq-arrow-cross",             geometry: .cross,                                                dims: .cross),
        .init(id: "seq-arrow-async",             geometry: .asyncArc,                                             dims: .standard),
        .init(id: "seq-arrow-half-top",          geometry: .halfTriangle(direction: .top, reversed: false),       dims: .standard),
        .init(id: "seq-arrow-half-bottom",       geometry: .halfTriangle(direction: .bottom, reversed: false),    dims: .standard),
        .init(id: "seq-arrow-stick-top",         geometry: .stick(direction: .top, reversed: false),              dims: .standard),
        .init(id: "seq-arrow-stick-bottom",      geometry: .stick(direction: .bottom, reversed: false),           dims: .standard),
        .init(id: "seq-arrow-half-top-rev",      geometry: .halfTriangle(direction: .top, reversed: true),        dims: .standard),
        .init(id: "seq-arrow-half-bottom-rev",   geometry: .halfTriangle(direction: .bottom, reversed: true),     dims: .standard),
        .init(id: "seq-arrow-stick-top-rev",     geometry: .stick(direction: .top, reversed: true),               dims: .standard),
        .init(id: "seq-arrow-stick-bottom-rev",  geometry: .stick(direction: .bottom, reversed: true),            dims: .standard),
        .init(id: "seq-arrow-half-top-rev-dot",     geometry: .halfTriangle(direction: .top, reversed: true),     dims: .standard),
        .init(id: "seq-arrow-half-bottom-rev-dot",  geometry: .halfTriangle(direction: .bottom, reversed: true),  dims: .standard),
        .init(id: "seq-arrow-stick-top-rev-dot",    geometry: .stick(direction: .top, reversed: true),            dims: .standard),
        .init(id: "seq-arrow-stick-bottom-rev-dot", geometry: .stick(direction: .bottom, reversed: true),         dims: .standard),
    ]

    private static let markersByID: [String: SequenceArrowheadMarker] = {
        Dictionary(uniqueKeysWithValues: allMarkers.map { ($0.id, $0) })
    }()

    /// Marker ID for a classified arrow style, or `nil` if the style draws
    /// no arrowhead. Mirrors the legacy `_markerId(for:)` composition exactly,
    /// including its idiosyncratic handling of dotted non-reversed half/stick
    /// arrows (whose composed ID has no corresponding `<marker>` entry).
    public static func markerID(for style: SequenceArrowStyle) -> String? {
        if style.isCross { return "seq-arrow-cross" }
        if style.isOpenArrow { return "seq-arrow-async" }
        if !style.hasArrowEnd { return nil }
        if style.isHalfArrow {
            let suffix = style.isReversed ? "-rev" : ""
            let dotSuffix = style.isDotted ? "-dot" : ""
            let dir = style.halfArrowDirection == .top ? "top" : "bottom"
            let kind = style.halfArrowStyle == .stick ? "stick" : "half"
            return "seq-arrow-\(kind)-\(dir)\(suffix)\(dotSuffix)"
        }
        return "seq-arrow-filled"
    }

    /// Catalog entry for a classified arrow style. Returns `nil` when the
    /// composed marker ID has no defined `<marker>` (matches legacy behavior
    /// — the SVG renderer emits a `url(#…)` reference either way; the CG
    /// renderer falls back to a filled triangle in that case).
    public static func marker(for style: SequenceArrowStyle) -> SequenceArrowheadMarker? {
        guard let id = markerID(for: style) else { return nil }
        return markersByID[id]
    }

    /// Renderer-neutral geometry for a classified arrow style. Returns `nil`
    /// when the style has no arrowhead (`!hasArrowEnd`). Unlike `marker(for:)`,
    /// this is independent of whether the composed marker ID is registered in
    /// `allMarkers` — the CG renderer uses this to draw the half/stick variants
    /// whose IDs the SVG `<defs>` list doesn't explicitly enumerate.
    public static func geometry(for style: SequenceArrowStyle) -> SequenceArrowheadGeometry? {
        if style.isCross { return .cross }
        if style.isOpenArrow { return .asyncArc }
        if !style.hasArrowEnd { return nil }
        if style.isHalfArrow {
            let direction: SequenceArrowheadDirection = (style.halfArrowDirection == .top) ? .top : .bottom
            if style.halfArrowStyle == .stick {
                return .stick(direction: direction, reversed: style.isReversed)
            }
            return .halfTriangle(direction: direction, reversed: style.isReversed)
        }
        return .filledTriangle
    }
}
