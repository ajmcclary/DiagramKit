import Foundation

/// Kind of arrowhead drawn at the end of a block diagram edge.
///
/// The block edge model carries the arrow type as a raw string
/// (`"arrow_point"`, `"arrow_circle"`, `"arrow_cross"`); both the CG renderer
/// (`DiagramRenderer+Block.swift`) and the SVG renderer
/// (`src_block_renderer.swift`) previously open-coded a three-way switch to
/// classify it. Routing through this enum gives them one mapping to maintain.
public enum BlockEdgeArrowheadKind: String, Sendable, Hashable, CaseIterable {
    case point
    case circle
    case cross
    case none

    /// Cases that produce a marker. Order matches the legacy `<defs>` block
    /// (point, circle, cross) so corpus SVG snapshots remain byte-identical.
    public static let drawable: [BlockEdgeArrowheadKind] = [.point, .circle, .cross]

    /// Decodes a `PositionedBlockEdge.arrowType*` raw string.
    public init(rawArrowType: String) {
        switch rawArrowType {
        case "arrow_point":  self = .point
        case "arrow_circle": self = .circle
        case "arrow_cross":  self = .cross
        default:             self = .none
        }
    }

    /// Full `<marker>...</marker>` block, byte-identical to the legacy
    /// inline `<defs>` emission in `renderBlockSvg`. Returns `nil` for
    /// `.none`. The `id` parameter accepts the diagram-scoped marker ID
    /// (built by the renderer's local `BlockMarkerIds` struct).
    public func svgMarkerBlock(id: String, lineColor: String) -> String? {
        switch self {
        case .point:
            return """
            <marker id="\(id)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <path d="M 0 0 L 10 5 L 0 10 z" fill="\(lineColor)"/>
            </marker>
            """
        case .circle:
            return """
            <marker id="\(id)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
              <circle cx="5" cy="5" r="4" fill="none" stroke="\(lineColor)" stroke-width="1"/>
            </marker>
            """
        case .cross:
            return """
            <marker id="\(id)" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 1 1 L 9 9 M 9 1 L 1 9" stroke="\(lineColor)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
            </marker>
            """
        case .none:
            return nil
        }
    }
}
