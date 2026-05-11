// Apple-only — depends on RenderConfig (BMColor/BMFont). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Shape Specification

/// Describes a shape's geometry independent of any renderer.
///
/// `ShapeSpec` is the single source of truth for a shape's sizing rules,
/// minimum dimensions, and path generation. Layout, CG rendering, and SVG
/// rendering should all derive their per-shape behavior from the registry
/// rather than maintaining independent switch statements.
public struct ShapeSpec: Sendable {

    /// All string aliases that resolve to this shape (lowercased).
    public let aliases: Set<String>

    /// Minimum bounding-box dimensions for layout.
    public let minimumSize: CGSize

    /// Adjusts the text-measured size with shape-specific padding.
    public let sizeAdjustment: @Sendable (_ textSize: CGSize, _ config: RenderConfig) -> CGSize

    /// Generates a platform-independent path description for the shape
    /// within the given bounding rectangle.
    public let path: @Sendable (_ rect: CGRect, _ config: RenderConfig) -> ShapePath

    /// Optional clip outline. Used by `EdgeShapeClipper` when the visual
    /// outline differs from the geometric outline (e.g. cylinder, where
    /// the body is a rectangle but the visible cap arcs extend beyond
    /// it). When `nil`, callers fall back to `path`.
    public let clipPath: (@Sendable (_ rect: CGRect, _ config: RenderConfig) -> ShapePath)?

    /// Overrides the fill color for the primary path. When `nil` (default),
    /// the renderer uses the node's normal fill color (`nodeFillColor`).
    public let fillOverride: ShapeDecoration.Fill?

    /// Overrides the stroke style for the primary path. When `nil` (default),
    /// the renderer uses the node's normal stroke (`mainStroke`).
    public let strokeOverride: ShapeDecoration.Stroke?

    /// Decorations layered on top of the base `path`. Renderers iterate
    /// this list AFTER drawing the primary path (e.g. the inner rectangle
    /// of a subroutine, the inner ellipse of a doubleCircle, the cross of
    /// a crossedCircle). `[]` for shapes that need no decoration.
    public let decorations: [ShapeDecoration]

    public init(
        aliases: Set<String>,
        minimumSize: CGSize = CGSize(width: 60, height: 36),
        sizeAdjustment: @Sendable @escaping (_ textSize: CGSize, _ config: RenderConfig) -> CGSize,
        path: @Sendable @escaping (_ rect: CGRect, _ config: RenderConfig) -> ShapePath,
        clipPath: (@Sendable (_ rect: CGRect, _ config: RenderConfig) -> ShapePath)? = nil,
        fillOverride: ShapeDecoration.Fill? = nil,
        strokeOverride: ShapeDecoration.Stroke? = nil,
        decorations: [ShapeDecoration] = []
    ) {
        self.aliases = aliases
        self.minimumSize = minimumSize
        self.sizeAdjustment = sizeAdjustment
        self.path = path
        self.clipPath = clipPath
        self.fillOverride = fillOverride
        self.strokeOverride = strokeOverride
        self.decorations = decorations
    }
}

// MARK: - Shape Decoration

/// A secondary stroke/fill layered on top of a shape's primary `path`.
/// Used for cases where a shape's visible appearance is composed of
/// multiple drawing operations (inner rectangle of a subroutine, inner
/// ellipse of a doubleCircle, cross of a crossedCircle, etc.).
///
/// Most decorations are drawn within the same bounds as the main shape
/// (`bounds` defaults to identity). Position-dependent decorations such
/// as cylinder caps, offset copies, and inset panes use a custom
/// `bounds` closure to specify the sub-rectangle they occupy within the
/// full shape bounds.
public struct ShapeDecoration: Sendable {

    public enum Stroke: Sendable {
        case none
        case mainStroke
        case dashed(lengths: [CGFloat])
        case thinStroke
    }

    /// Controls how the decoration's path is filled.
    public enum Fill: Sendable {
        /// No fill — stroke only.
        case none
        /// Use the same fill color as the main shape.
        case inherit
        /// Use the theme's surface color (for title headers, inset panes).
        case surface
        /// Use the theme's foreground color (for state-start/end, fork/join, filled-circle).
        case foreground
    }

    /// Generates a platform-independent path description for the
    /// decoration within the rectangle produced by `bounds`.
    public let path: @Sendable (_ rect: CGRect, _ config: RenderConfig) -> ShapePath

    /// Maps the full shape bounds to the sub-rectangle where this
    /// decoration is drawn. Defaults to identity so same-bounds
    /// decorations (polyline strokes, centered ellipses, etc.)
    /// work without changes.
    public let bounds: @Sendable (_ fullBounds: CGRect, _ config: RenderConfig) -> CGRect

    public let stroke: Stroke
    public let fill: Fill

    @available(*, deprecated, message: "Use `fill` instead")
    public var fillsBackground: Bool { fill == .inherit }

    public init(
        path: @Sendable @escaping (_ rect: CGRect, _ config: RenderConfig) -> ShapePath,
        bounds: @Sendable @escaping (_ fullBounds: CGRect, _ config: RenderConfig) -> CGRect = { fullBounds, _ in fullBounds },
        stroke: Stroke = .mainStroke,
        fill: Fill = .none
    ) {
        self.path = path
        self.bounds = bounds
        self.stroke = stroke
        self.fill = fill
    }
}

// MARK: - Shape Path

/// Platform-independent description of a shape's outline.
///
/// CG renderers convert these to `CGPath`, SVG renderers to
/// SVG path-data strings.
public enum ShapePath: Sendable {
    case rect(cornerRadius: CGFloat)
    case ellipse
    case diamond
    case hexagon
    case cylinder(topCapInset: CGFloat)
    case trapezoid(skew: CGFloat)
    case parallelogram(skew: CGFloat)
    case stadium
    case subroutine(inset: CGFloat)
    case doubleCircle(gap: CGFloat)
    case asymmetric(indent: CGFloat)
    case crossedCircle
    case hourglass
    case lightningBolt
    case cloud
    case bowTie(indent: CGFloat)
    case triangle
    case flag
    case document
    case polygon(vertices: [CGPoint])

    // MARK: - Rect-family additions (audit follow-up #1)

    /// Rectangle with a triangular notch carved out of the top-right
    /// corner. Used by `card`, `notch-rect`, `notched-rectangle`.
    case notchedRectangle(notchSize: CGFloat)

    // MARK: - Cylinder-family additions (audit follow-up #2)

    /// Horizontal cylinder body (rectangle inset on the left and right
    /// edges by `leftCapInset`). Used by `horizontal-cylinder`, `h-cyl`,
    /// `das`. The visible cap ellipses on left/right are drawn by the
    /// renderer as separate decorations — same pattern as the existing
    /// vertical `.cylinder(topCapInset:)`.
    case horizontalCylinder(leftCapInset: CGFloat)

    // MARK: - Alt-skew additions (audit follow-up #3)

    /// Inverted trapezoid (wide top, narrow bottom). Mirrors
    /// `.trapezoid(skew:)` but with the inset applied to the bottom
    /// edge instead of the top. Used by `trapezoid-alt`,
    /// `inv_trapezoid`.
    case trapezoidAlt(skew: CGFloat)

    /// Parallelogram skewed left (mirror of `.parallelogram`). Used by
    /// `parallelogram-alt`, `lean_left`.
    case parallelogramAlt(skew: CGFloat)

    /// Triangle with apex pointing down (inverted from `.triangle`).
    /// Used by `flipped-triangle`, `manual-file`, `flip-tri`.
    case triangleDown

    /// Rectangle with the top edge slanted upward to the right by
    /// `slope` × bounds height. Used by `sloped-rectangle`,
    /// `manual-input`, `sl-rect`.
    case slopedRectangle(slope: CGFloat)

    // MARK: - Phase 1 additions (audit follow-up #4)

    /// Open polyline (stroke-only, no fill). Used for brace decorations
    /// and inline shape details that are pure stroke operations.
    /// Unlike `.polygon`, this path does NOT close.
    case polyline(points: [CGPoint])

    /// Curved trapezoid — a rectangle where the right edge curves
    /// inward like a display screen. Used by `curved-trapezoid`,
    /// `curv-trap`, `display`.
    case curvedTrapezoid(skew: CGFloat)
}

// MARK: - Shape Spec Registry

/// Registry mapping shape-name strings to `ShapeSpec` values.
///
/// Use `spec(for:)` to look up a shape by any of its aliases
/// (case-insensitive).
public enum ShapeSpecRegistry {

    public static func spec(for shapeName: String) -> ShapeSpec? {
        let key = shapeName.lowercased()
        return aliasIndex[key] ?? fallbackSpec
    }

    public static let all: [ShapeSpec] = _buildSpecs()
    public static var count: Int { all.count }

    // MARK: - Private

    private static let aliasIndex: [String: ShapeSpec] = {
        var index: [String: ShapeSpec] = [:]
        for spec in all {
            for alias in spec.aliases { index[alias] = spec }
        }
        return index
    }()

    private static let fallbackSpec: ShapeSpec = _makeRectangleSpec()

    private static func _buildSpecs() -> [ShapeSpec] {
        [
            _makeRectangleSpec(),
            _makeRoundedSpec(),
            _makeDiamondSpec(),
            _makeStadiumSpec(),
            _makeCircleSpec(),
            _makeSubroutineSpec(),
            _makeDoubleCircleSpec(),
            _makeHexagonSpec(),
            _makeCylinderSpec(),
            _makeAsymmetricSpec(),
            _makeTrapezoidSpec(),
            _makeTrapezoidAltSpec(),
            _makeParallelogramSpec(),
            _makeParallelogramAltSpec(),
            _makeBangSpec(),
            _makeCloudSpec(),
            _makeDataStoreSpec(),
            _makeTextSpec(),
            _makeNotchedRectangleSpec(),
            _makeLinedRectangleSpec(),
            _makeSmallCircleSpec(),
            _makeFramedCircleSpec(),
            _makeForkSpec(),
            _makeJoinSpec(),
            _makeHourglassSpec(),
            _makeBraceLSpec(),
            _makeBraceRSpec(),
            _makeBracesSpec(),
            _makeLightningBoltSpec(),
            _makeDocumentSpec(),
            _makeDelaySpec(),
            _makeHorizontalCylinderSpec(),
            _makeLinedCylinderSpec(),
            _makeCurvedTrapezoidSpec(),
            _makeDividedRectangleSpec(),
            _makeTriangleSpec(),
            _makeWindowPaneSpec(),
            _makeFilledCircleSpec(),
            _makeLinedDocumentSpec(),
            _makeNotchedPentagonSpec(),
            _makeFlippedTriangleSpec(),
            _makeSlopedRectangleSpec(),
            _makeStackedDocumentSpec(),
            _makeStackedRectangleSpec(),
            _makeFlagSpec(),
            _makeBowTieRectangleSpec(),
            _makeCrossedCircleSpec(),
            _makeTaggedDocumentSpec(),
            _makeTaggedRectangleSpec(),
            _makeIconSquareSpec(),
            _makeIconCircleSpec(),
            _makeIconSpec(),
            _makeIconRoundedSpec(),
            _makeImageSquareSpec(),
            _makeStateSpec(),
            _makeChoiceSpec(),
            _makeNoteSpec(),
            _makeRectWithTitleSpec(),
            _makeLabelRectSpec(),
            _makeAnchorSpec(),
            _makeClassBoxSpec(),
            _makeInvisibleSpec(),
            _makeStateStartSpec(),
            _makeStateEndSpec(),
            _makeStateDividerSpec(),
            _makeStateNoteSpec(),
            _makeRoundedWithTitleSpec(),
            _makeEllipseSpec(),
        ]
    }

    // MARK: - Rect sizing helper

    static func _rectSizing(_ textSize: CGSize, _ config: RenderConfig) -> CGSize {
        CGSize(
            width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
            height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
        )
    }

    static func _defaultSpec(aliases: Set<String>) -> ShapeSpec {
        ShapeSpec(aliases: aliases, sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) })
    }

}
#endif
