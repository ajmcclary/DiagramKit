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

    private static func _rectSizing(_ textSize: CGSize, _ config: RenderConfig) -> CGSize {
        CGSize(
            width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
            height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
        )
    }

    private static func _defaultSpec(aliases: Set<String>) -> ShapeSpec {
        ShapeSpec(aliases: aliases, sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) })
    }

    // MARK: - Individual specs

    private static func _makeRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rect", "proc", "process", "rectangle", "entity", "state-fork"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) }
        )
    }

    private static func _makeRoundedSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rounded", "fr-rect", "rounded-rectangle"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 6) }
        )
    }

    private static func _makeDiamondSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["diamond", "diam", "decision", "rhombus"],
            sizeAdjustment: { textSize, config in
                let side = Swift.max(Swift.max(textSize.width + config.nodePaddingHorizontal * 2, textSize.height + config.nodePaddingVertical * 2), config.minimumNodeWidth) + config.nodePaddingDiamondExtra
                return CGSize(width: side, height: side)
            },
            path: { _, _ in .diamond }
        )
    }

    private static func _makeStadiumSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["stadium"], sizeAdjustment: _rectSizing, path: { _, _ in .stadium })
    }

    private static func _makeCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["circle", "circ"],
            sizeAdjustment: { textSize, config in
                let w = textSize.width + config.nodePaddingHorizontal * 2
                let h = textSize.height + config.nodePaddingVertical * 2
                let d = ceil(sqrt(w * w + h * h)) + 8
                return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
            },
            path: { _, _ in .ellipse }
        )
    }

    private static func _makeSubroutineSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["subroutine", "subproc", "sub-routine"],
            sizeAdjustment: _rectSizing,
            path: { _, config in .subroutine(inset: config.subroutineInset) },
            decorations: [
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.subroutineInset, y: rect.minY),
                        CGPoint(x: rect.minX + config.subroutineInset, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.maxX - config.subroutineInset, y: rect.minY),
                        CGPoint(x: rect.maxX - config.subroutineInset, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }

    private static func _makeDoubleCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["double-circle", "dbl-circ", "doublecircle"],
            sizeAdjustment: { textSize, config in
                let w = textSize.width + config.nodePaddingHorizontal * 2
                let h = textSize.height + config.nodePaddingVertical * 2
                let d = ceil(sqrt(w * w + h * h)) + 8 + 12
                return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
            },
            path: { _, config in .doubleCircle(gap: config.doubleCircleGap) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }

    private static func _makeHexagonSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["hexagon", "hex"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .hexagon }
        )
    }

    private static func _makeCylinderSpec() -> ShapeSpec {
        let sideLines: [ShapeDecoration] = [
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.minX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.minX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.maxX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.maxX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
        ]
        let capDecorations: [ShapeDecoration] = [
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.minY, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.maxY - h, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
        ]
        return ShapeSpec(
            aliases: ["cylinder", "cyl"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: sideLines + capDecorations
        )
    }

    private static func _makeAsymmetricSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["odd", "rect-left-inv-arrow", "asymmetric"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 12, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, config in .asymmetric(indent: config.asymmetricIndent) }
        )
    }

    private static func _makeTrapezoidSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["trapezoid", "trap-b"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .trapezoid(skew: 0.3) }
        )
    }

    private static func _makeParallelogramSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lean-right", "lean_right", "parallelogram"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .parallelogram(skew: 0.3) }
        )
    }

    private static func _makeTrapezoidAltSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["trapezoid-alt", "inv_trapezoid", "trap-t"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .trapezoidAlt(skew: 0.15) }
        )
    }

    private static func _makeParallelogramAltSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lean-left", "lean_left", "parallelogram-alt"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .parallelogramAlt(skew: 0.2) }
        )
    }

    // MARK: Phase 1 — specs migrated from _defaultSpec to explicit paths + decorations.

    private static func _makeBangSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["bang"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .ellipse },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX, y: rect.minY),
                        CGPoint(x: rect.midX, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeCloudSpec() -> ShapeSpec { ShapeSpec(aliases: ["cloud"], sizeAdjustment: _rectSizing, path: { _, _ in .cloud }) }
    private static func _makeDataStoreSpec() -> ShapeSpec {
        let sideLines: [ShapeDecoration] = [
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.minX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.minX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.maxX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.maxX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
        ]
        let capDecorations: [ShapeDecoration] = [
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.minY, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.maxY - h, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
        ]
        return ShapeSpec(
            aliases: ["data-store", "datastore"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: sideLines + capDecorations
        )
    }
    private static func _makeTextSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["text"], sizeAdjustment: { textSize, _ in CGSize(width: textSize.width + 4, height: textSize.height + 4) }, path: { _, _ in .rect(cornerRadius: 0) })
    }
    private static func _makeNotchedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["card", "notched-rectangle", "notch-rect"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .notchedRectangle(notchSize: 10) }
        )
    }
    private static func _makeLinedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-process", "lined-rectangle", "lin-rect", "lin-proc", "shaded-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 4, y: rect.minY),
                        CGPoint(x: rect.minX + 4, y: rect.maxY),
                    ]) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    private static func _makeSmallCircleSpec() -> ShapeSpec { ShapeSpec(aliases: ["start", "small-circle", "sm-circ"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .ellipse }) }
    private static func _makeFramedCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stop", "framed-circle", "fr-circ"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .ellipse },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .ellipse },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    private static func _makeForkSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["fork"], sizeAdjustment: { _, _ in CGSize(width: 70, height: 7) }, path: { _, _ in .rect(cornerRadius: 0) }, fillOverride: .foreground, strokeOverride: .none)
    }
    private static func _makeJoinSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["join"], sizeAdjustment: { _, _ in CGSize(width: 70, height: 7) }, path: { _, _ in .rect(cornerRadius: 0) }, fillOverride: .foreground, strokeOverride: .none)
    }
    private static func _makeHourglassSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["collate", "hourglass"], sizeAdjustment: _rectSizing, path: { _, _ in .hourglass })
    }
    private static func _makeBraceLSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["brace-l", "comment", "brace"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 2),
                        CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.3, y: rect.midY),
                        CGPoint(x: rect.minX + 2, y: rect.maxY - rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - 2),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeBraceRSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["brace-r"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + rect.width * 0.6, y: rect.minY + 2),
                        CGPoint(x: rect.maxX - 2, y: rect.minY + rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.7, y: rect.midY),
                        CGPoint(x: rect.maxX - 2, y: rect.maxY - rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.6, y: rect.maxY - 2),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeBracesSpec() -> ShapeSpec {
        let leftDecoration = ShapeDecoration(
            path: { rect, _ in .polyline(points: [
                CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 2),
                CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.3, y: rect.midY),
                CGPoint(x: rect.minX + 2, y: rect.maxY - rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - 2),
            ]) },
            stroke: ShapeDecoration.Stroke.mainStroke
        )
        let rightDecoration = ShapeDecoration(
            path: { rect, _ in .polyline(points: [
                CGPoint(x: rect.minX + rect.width * 0.6, y: rect.minY + 2),
                CGPoint(x: rect.maxX - 2, y: rect.minY + rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.7, y: rect.midY),
                CGPoint(x: rect.maxX - 2, y: rect.maxY - rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.6, y: rect.maxY - 2),
            ]) },
            stroke: ShapeDecoration.Stroke.mainStroke
        )
        return ShapeSpec(
            aliases: ["braces"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [leftDecoration, rightDecoration]
        )
    }
    private static func _makeLightningBoltSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["com-link", "bolt", "lightning-bolt"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 8, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 8, config.minimumNodeHeight))
        }, path: { _, _ in .lightningBolt })
    }
    private static func _makeDocumentSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["doc", "document"], sizeAdjustment: _rectSizing, path: { _, _ in .document })
    }
    private static func _makeDelaySpec() -> ShapeSpec {
        ShapeSpec(aliases: ["delay", "half-rounded-rectangle"], sizeAdjustment: _rectSizing, path: { _, _ in .stadium })
    }
    private static func _makeHorizontalCylinderSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["horizontal-cylinder", "h-cyl", "das"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 14, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, config in .horizontalCylinder(leftCapInset: config.cylinderEllipseRadius) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let w = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.minX, y: full.minY, width: w, height: full.height)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let w = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.maxX - w, y: full.minY, width: w, height: full.height)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.cylinderEllipseRadius, y: rect.minY),
                        CGPoint(x: rect.maxX - config.cylinderEllipseRadius, y: rect.minY),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.cylinderEllipseRadius, y: rect.maxY),
                        CGPoint(x: rect.maxX - config.cylinderEllipseRadius, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeLinedCylinderSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-cylinder", "lin-cyl", "disk"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX, y: rect.midY),
                        CGPoint(x: rect.maxX, y: rect.midY),
                    ]) },
                    stroke: .dashed(lengths: [3, 3])
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX, y: rect.minY + config.cylinderEllipseRadius),
                        CGPoint(x: rect.minX, y: rect.maxY - config.cylinderEllipseRadius),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.maxX, y: rect.minY + config.cylinderEllipseRadius),
                        CGPoint(x: rect.maxX, y: rect.maxY - config.cylinderEllipseRadius),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let h = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.minX, y: full.minY, width: full.width, height: h)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let h = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.minX, y: full.maxY - h, width: full.width, height: h)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }
    private static func _makeCurvedTrapezoidSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["curbed-trapezoid", "curv-trap", "display"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .curvedTrapezoid(skew: 0.15) }
        )
    }
    private static func _makeDividedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["divided-rectangle", "div-rect", "div-proc", "divided-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX, y: rect.midY),
                        CGPoint(x: rect.maxX, y: rect.midY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeTriangleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["triangle", "tri", "extract"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight))
        }, path: { _, _ in .triangle })
    }
    private static func _makeWindowPaneSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["internal-storage", "win-pane", "window-pane"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .rect(cornerRadius: 0) },
                    bounds: { full, _ in
                        let inset = full.width * 0.2
                        return CGRect(x: full.maxX - inset - 4, y: full.minY + 4,
                                      width: inset, height: full.height - 8)
                    },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeFilledCircleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["filled-circle", "f-circ", "junction"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .ellipse }, fillOverride: .foreground, strokeOverride: .none)
    }
    private static func _makeLinedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-document", "lin-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 8, y: rect.minY + rect.height * 0.3),
                        CGPoint(x: rect.maxX - 8, y: rect.minY + rect.height * 0.3),
                    ]) },
                    stroke: .thinStroke
                ),
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 8, y: rect.minY + rect.height * 0.3 + 6),
                        CGPoint(x: rect.maxX - 16, y: rect.minY + rect.height * 0.3 + 6),
                    ]) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    private static func _makeNotchedPentagonSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["loop-limit", "notch-pent", "notched-pentagon"],
            sizeAdjustment: { textSize, config in
                CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight))
            },
            path: { _, _ in .triangle }
        )
    }
    private static func _makeFlippedTriangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["manual-file", "flip-tri", "flipped-triangle"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .triangleDown }
        )
    }

    private static func _makeSlopedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["manual-input", "sl-rect", "sloped-rectangle"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .slopedRectangle(slope: 0.2) }
        )
    }
    private static func _makeStackedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stacked-document", "docs", "documents", "st-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .document },
                    bounds: { full, _ in full.offsetBy(dx: -4, dy: -4) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    private static func _makeStackedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stacked-rectangle", "st-rect", "procs", "processes"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .rect(cornerRadius: 0) },
                    bounds: { full, _ in full.offsetBy(dx: -4, dy: -4) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    private static func _makeFlagSpec() -> ShapeSpec { ShapeSpec(aliases: ["paper-tape", "flag"], sizeAdjustment: _rectSizing, path: { _, _ in .flag }) }
    private static func _makeBowTieRectangleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["bow-tie-rectangle", "bow-rect", "stored-data"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 12, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight))
        }, path: { _, _ in .bowTie(indent: 12) })
    }
    private static func _makeCrossedCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["crossed-circle", "cross-circ", "summary"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .crossedCircle },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX - rect.width * 0.25, y: rect.midY - rect.height * 0.25),
                        CGPoint(x: rect.midX + rect.width * 0.25, y: rect.midY + rect.height * 0.25),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX + rect.width * 0.25, y: rect.midY - rect.height * 0.25),
                        CGPoint(x: rect.midX - rect.width * 0.25, y: rect.midY + rect.height * 0.25),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    private static func _makeTaggedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["tagged-document", "tag-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polygon(vertices: [
                        CGPoint(x: rect.maxX - 10, y: rect.minY),
                        CGPoint(x: rect.maxX - 10, y: rect.minY + 10),
                        CGPoint(x: rect.maxX, y: rect.minY + 10),
                    ]) },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }
    private static func _makeTaggedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["tagged-rectangle", "tag-rect", "tag-proc", "tagged-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polygon(vertices: [
                        CGPoint(x: rect.maxX - 10, y: rect.minY),
                        CGPoint(x: rect.maxX - 10, y: rect.minY + 10),
                        CGPoint(x: rect.maxX, y: rect.minY + 10),
                    ]) },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }
    private static func _makeIconSquareSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-square"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeIconCircleSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-circle"], sizeAdjustment: _rectSizing, path: { _, _ in .ellipse }) }
    private static func _makeIconSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeIconRoundedSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-rounded"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 6) }) }
    private static func _makeImageSquareSpec() -> ShapeSpec { ShapeSpec(aliases: ["image-square"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeStateSpec() -> ShapeSpec { ShapeSpec(aliases: ["state"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeChoiceSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["choice", "state-choice"], sizeAdjustment: { textSize, config in
            let side = Swift.max(Swift.max(textSize.width + config.nodePaddingHorizontal * 2, textSize.height + config.nodePaddingVertical * 2), config.minimumNodeWidth) + 16
            return CGSize(width: side, height: side)
        }, path: { _, _ in .diamond })
    }
    private static func _makeNoteSpec() -> ShapeSpec { ShapeSpec(aliases: ["note"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeRectWithTitleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rect-with-title"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 4) },
            decorations: [
                ShapeDecoration(
                    path: { sub, _ in .rect(cornerRadius: 4) },
                    bounds: { full, _ in CGRect(x: full.minX, y: full.minY, width: full.width, height: 24) },
                    stroke: .none,
                    fill: .surface
                ),
                ShapeDecoration(
                    path: { _, _ in .polyline(points: [
                        CGPoint(x: 0, y: 24),
                        CGPoint(x: 100, y: 24),  // width overridden by bounds scaling
                    ]) },
                    stroke: .mainStroke,
                    fill: .none
                ),
            ]
        )
    }
    private static func _makeLabelRectSpec() -> ShapeSpec { ShapeSpec(aliases: ["label-rect"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeAnchorSpec() -> ShapeSpec { ShapeSpec(aliases: ["anchor"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeClassBoxSpec() -> ShapeSpec { ShapeSpec(aliases: ["class-box"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 4) }) }
    private static func _makeInvisibleSpec() -> ShapeSpec { ShapeSpec(aliases: ["invisible"], sizeAdjustment: { _, _ in .zero }, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeStateStartSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["state-start"],
            sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) },
            path: { _, _ in .ellipse },
            fillOverride: .foreground,
            strokeOverride: .none
        )
    }
    private static func _makeStateEndSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-end"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .doubleCircle(gap: 5) }) }
    private static func _makeStateDividerSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-divider"], sizeAdjustment: { textSize, _ in CGSize(width: Swift.max(textSize.width, 60), height: 12) }, path: { _, _ in .rect(cornerRadius: 0) }) }
    private static func _makeStateNoteSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-note"], sizeAdjustment: { textSize, _ in CGSize(width: Swift.max(textSize.width, 80), height: Swift.max(textSize.height, 40)) }, path: { _, _ in .rect(cornerRadius: 6) }) }
    private static func _makeRoundedWithTitleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rounded-with-title"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 8) },
            decorations: [
                ShapeDecoration(
                    path: { sub, _ in .rect(cornerRadius: 8) },
                    bounds: { full, _ in CGRect(x: full.minX, y: full.minY, width: full.width, height: 35) },
                    stroke: .none,
                    fill: .surface
                ),
                ShapeDecoration(
                    path: { _, _ in .polyline(points: [
                        CGPoint(x: 0, y: 35),
                        CGPoint(x: 100, y: 35),
                    ]) },
                    stroke: .mainStroke,
                    fill: .none
                ),
            ]
        )
    }
    private static func _makeEllipseSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["ellipse"], sizeAdjustment: { textSize, config in
            let w = textSize.width + config.nodePaddingHorizontal * 2
            let h = textSize.height + config.nodePaddingVertical * 2
            let d = ceil(sqrt(w * w + h * h)) + 8
            return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
        }, path: { _, _ in .ellipse })
    }
}
#endif