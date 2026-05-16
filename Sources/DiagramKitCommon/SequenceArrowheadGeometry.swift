import Foundation

/// Vertical placement of a half-style sequence arrowhead.
///
/// Lives in `DiagramKitCommon` (not `DiagramKitModel`) so the portable
/// `SequenceArrowheadGeometry` enum can reference it without dragging Model's
/// types into Common.
public enum SequenceArrowheadDirection: String, Sendable, Hashable {
    case top
    case bottom
}

/// Marker viewport for an SVG `<marker>` element drawn by the sequence renderer.
///
/// The legacy `_arrowMarkerDefs()` body used `Double` literals (`w: Double = 8`,
/// `h: Double = 5`) and Swift's default `Double` interpolation (e.g. `\(w)` →
/// `"8.0"`). The standard dimensions reproduce that emission byte-for-byte;
/// the `cross` dimensions reproduce the doubled viewport (`w * 2`, `h * 2`)
/// that the legacy code emitted only for the X-mark arrowhead.
public struct SequenceArrowheadMarkerDims: Sendable, Hashable {
    public var width: Double
    public var height: Double
    public var refX: Double
    public var refY: Double

    public init(width: Double, height: Double, refX: Double, refY: Double) {
        self.width = width
        self.height = height
        self.refX = refX
        self.refY = refY
    }

    public static let standard = SequenceArrowheadMarkerDims(width: 8, height: 5, refX: 8, refY: 2.5)
    public static let cross    = SequenceArrowheadMarkerDims(width: 16, height: 10, refX: 16, refY: 5)
}

/// Renderer-neutral geometry of a sequence arrowhead.
///
/// Both `DiagramKitModel`'s SVG renderer and `DiagramKitRenderingCG`'s CG
/// renderer consume this enum, eliminating the duplicated point lists that
/// previously lived in `_arrowMarkerDefs()` (SVG) and `_drawSequenceArrowHead`
/// /`_drawHalfArrowHead` (CG). Coordinates are expressed in the marker's
/// viewport for SVG, and scaled to the renderer's `arrowWidth`/`arrowHeight`
/// for CG (see the `draw(in:arrowWidth:arrowHeight:)` extension that lives in
/// `DiagramKitRenderingCG`).
public enum SequenceArrowheadGeometry: Sendable, Hashable {
    /// Closed filled triangle — default sync-message head.
    case filledTriangle
    /// Open V polyline — async open-arrow head.
    case openV
    /// X-mark (two crossed strokes) — cross arrowhead.
    case cross
    /// Quadratic curve forming an open arc — `solidPoint` / `dottedPoint`.
    case asyncArc
    /// Half-triangle, filled.
    case halfTriangle(direction: SequenceArrowheadDirection, reversed: Bool)
    /// Stick-style head: short vertical line + horizontal tick.
    case stick(direction: SequenceArrowheadDirection, reversed: Bool)
}

/// A single registry entry for an SVG `<marker>` definition.
///
/// `id` is stable: each value matches an existing `seq-arrow-*` marker ID so
/// existing corpus snapshots remain byte-identical after the refactor.
public struct SequenceArrowheadMarker: Sendable, Hashable {
    public let id: String
    public let geometry: SequenceArrowheadGeometry
    public let dims: SequenceArrowheadMarkerDims

    public init(id: String, geometry: SequenceArrowheadGeometry, dims: SequenceArrowheadMarkerDims) {
        self.id = id
        self.geometry = geometry
        self.dims = dims
    }
}

extension SequenceArrowheadGeometry {
    /// Inner SVG content for the geometry, indented to match the legacy
    /// `_arrowMarkerDefs()` emission (4-space indent on each child line).
    ///
    /// The cross geometry uses `dims.width / 2` and `dims.height / 2` so the
    /// inner line coordinates emit as `8.0` / `5.0` while the marker viewport
    /// stores the doubled values (`16`, `10`).
    public func svgInnerContent(dims: SequenceArrowheadMarkerDims) -> String {
        let w = dims.width
        let h = dims.height
        switch self {
        case .filledTriangle:
            return "    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" fill=\"var(--_arrow)\" />"

        case .openV:
            return "    <polyline points=\"0 0, \(w) \(h / 2), 0 \(h)\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1\" />"

        case .cross:
            let baseW = w / 2
            let baseH = h / 2
            return """
                <line x1="\(baseW)" y1="-\(baseH)" x2="0" y2="\(baseH)" stroke="var(--_arrow)" stroke-width="1.5" />
                <line x1="\(baseW)" y1="\(baseH)" x2="0" y2="-\(baseH)" stroke="var(--_arrow)" stroke-width="1.5" />
            """

        case .asyncArc:
            return "    <path d=\"M 1 \(h / 2) Q \(w / 2) -1, \(w - 1) \(h / 2)\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1\" />"

        case .halfTriangle(direction: .top, reversed: false):
            return "    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h / 2)\" fill=\"var(--_arrow)\" />"
        case .halfTriangle(direction: .bottom, reversed: false):
            return "    <polygon points=\"0 \(h / 2), \(w) \(h / 2), 0 \(h)\" fill=\"var(--_arrow)\" />"
        case .halfTriangle(direction: .top, reversed: true):
            return "    <polygon points=\"0 \(h / 2), \(w) 0, 0 0\" fill=\"var(--_arrow)\" />"
        case .halfTriangle(direction: .bottom, reversed: true):
            return "    <polygon points=\"0 \(h / 2), \(w) \(h), 0 \(h)\" fill=\"var(--_arrow)\" />"

        case .stick(direction: .top, reversed: false):
            return """
                <line x1="0" y1="0" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
                <line x1="\(w)" y1="0" x2="0" y2="0" stroke="var(--_arrow)" stroke-width="1.5" />
            """
        case .stick(direction: .bottom, reversed: false):
            return """
                <line x1="0" y1="\(h / 2)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
                <line x1="\(w)" y1="\(h / 2)" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
            """
        case .stick(direction: .top, reversed: true):
            return """
                <line x1="0" y1="0" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
                <line x1="\(w)" y1="\(h / 2)" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
            """
        case .stick(direction: .bottom, reversed: true):
            return """
                <line x1="0" y1="\(h / 2)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
                <line x1="\(w)" y1="0" x2="0" y2="0" stroke="var(--_arrow)" stroke-width="1.5" />
            """
        }
    }
}

extension SequenceArrowheadMarker {
    /// Full `<marker>...</marker>` block, indented to match the legacy
    /// `_arrowMarkerDefs()` emission so corpus snapshots stay byte-identical.
    public func svgMarkerBlock() -> String {
        let inner = geometry.svgInnerContent(dims: dims)
        return """
          <marker id="\(id)" markerWidth="\(dims.width)" markerHeight="\(dims.height)" refX="\(dims.refX)" refY="\(dims.refY)" orient="auto-start-reverse">
        \(inner)
          </marker>
        """
    }
}
