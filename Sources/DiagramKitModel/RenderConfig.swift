// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Public configuration facade for DiagramKit rendering.
///
/// `RenderConfig` owns a `RenderTokens` instance (the source of truth for
/// all layout, font, and geometry constants) and exposes its properties
/// through computed property forwarding. Font resolution and text
/// measurement methods remain on this type during the A5 migration and
/// will move to `DiagramFontResolver` / `TextMetrics` in follow-up phases.
///
/// Per-diagram-family constants (Sequence, Class, ER) are forwarded from
/// `RenderTokens` via extensions in `RenderConfig+Sequence.swift`,
/// `RenderConfig+Class.swift`, and `RenderConfig+ER.swift`.
public struct RenderConfig: Sendable {

    public static let shared = RenderConfig()

    // MARK: - Token storage

    /// The source of truth for all configurable constants.
    public var tokens = RenderTokens()

    // MARK: - Node Padding (forwarded)

    public var nodePaddingHorizontal: CGFloat {
        get { tokens.nodePaddingHorizontal }
        set { tokens.nodePaddingHorizontal = newValue }
    }
    public var nodePaddingVertical: CGFloat {
        get { tokens.nodePaddingVertical }
        set { tokens.nodePaddingVertical = newValue }
    }
    public var nodePaddingDiamondExtra: CGFloat {
        get { tokens.nodePaddingDiamondExtra }
        set { tokens.nodePaddingDiamondExtra = newValue }
    }
    public var nodePadding: CGSize { tokens.nodePadding }

    // MARK: - Font Sizes (forwarded)

    public var fontSizeNodeLabel: CGFloat {
        get { tokens.fontSizeNodeLabel }
        set { tokens.fontSizeNodeLabel = newValue }
    }
    public var fontSizeEdgeLabel: CGFloat {
        get { tokens.fontSizeEdgeLabel }
        set { tokens.fontSizeEdgeLabel = newValue }
    }
    public var fontSizeGroupHeader: CGFloat {
        get { tokens.fontSizeGroupHeader }
        set { tokens.fontSizeGroupHeader = newValue }
    }

    // MARK: - Font Weights (forwarded)

    public var fontWeightNodeLabel: Int {
        get { tokens.fontWeightNodeLabel }
        set { tokens.fontWeightNodeLabel = newValue }
    }
    public var fontWeightEdgeLabel: Int {
        get { tokens.fontWeightEdgeLabel }
        set { tokens.fontWeightEdgeLabel = newValue }
    }
    public var fontWeightGroupHeader: Int {
        get { tokens.fontWeightGroupHeader }
        set { tokens.fontWeightGroupHeader = newValue }
    }

    // MARK: - Stroke Widths (forwarded)

    public var strokeWidthOuterBox: CGFloat {
        get { tokens.strokeWidthOuterBox }
        set { tokens.strokeWidthOuterBox = newValue }
    }
    public var strokeWidthInnerBox: CGFloat {
        get { tokens.strokeWidthInnerBox }
        set { tokens.strokeWidthInnerBox = newValue }
    }
    public var strokeWidthConnector: CGFloat {
        get { tokens.strokeWidthConnector }
        set { tokens.strokeWidthConnector = newValue }
    }

    // MARK: - Arrow Head (forwarded)

    public var arrowHeadWidth: CGFloat {
        get { tokens.arrowHeadWidth }
        set { tokens.arrowHeadWidth = newValue }
    }
    public var arrowHeadHeight: CGFloat {
        get { tokens.arrowHeadHeight }
        set { tokens.arrowHeadHeight = newValue }
    }

    // MARK: - Spacing (forwarded)

    public var groupHeaderContentPad: CGFloat {
        get { tokens.groupHeaderContentPad }
        set { tokens.groupHeaderContentPad = newValue }
    }
    public var subgraphPadding: CGFloat {
        get { tokens.subgraphPadding }
        set { tokens.subgraphPadding = newValue }
    }
    public var nodeSpacing: CGFloat {
        get { tokens.nodeSpacing }
        set { tokens.nodeSpacing = newValue }
    }
    public var layerSpacing: CGFloat {
        get { tokens.layerSpacing }
        set { tokens.layerSpacing = newValue }
    }
    public var graphPadding: CGFloat {
        get { tokens.graphPadding }
        set { tokens.graphPadding = newValue }
    }

    // MARK: - Text Rendering (forwarded)

    public var textBaselineShiftEm: CGFloat {
        get { tokens.textBaselineShiftEm }
        set { tokens.textBaselineShiftEm = newValue }
    }

    // MARK: - Minimum Sizes (forwarded)

    public var minimumNodeWidth: CGFloat {
        get { tokens.minimumNodeWidth }
        set { tokens.minimumNodeWidth = newValue }
    }
    public var minimumNodeHeight: CGFloat {
        get { tokens.minimumNodeHeight }
        set { tokens.minimumNodeHeight = newValue }
    }
    public var statePseudostateSize: CGFloat {
        get { tokens.statePseudostateSize }
        set { tokens.statePseudostateSize = newValue }
    }

    // MARK: - Shape-specific (forwarded)

    public var cylinderEllipseRadius: CGFloat {
        get { tokens.cylinderEllipseRadius }
        set { tokens.cylinderEllipseRadius = newValue }
    }
    public var subroutineInset: CGFloat {
        get { tokens.subroutineInset }
        set { tokens.subroutineInset = newValue }
    }
    public var asymmetricIndent: CGFloat {
        get { tokens.asymmetricIndent }
        set { tokens.asymmetricIndent = newValue }
    }
    public var doubleCircleGap: CGFloat {
        get { tokens.doubleCircleGap }
        set { tokens.doubleCircleGap = newValue }
    }

    // MARK: - Edge Labels (forwarded)

    public var edgeLabelPadding: CGFloat {
        get { tokens.edgeLabelPadding }
        set { tokens.edgeLabelPadding = newValue }
    }
    public var edgeLabelCornerRadius: CGFloat {
        get { tokens.edgeLabelCornerRadius }
        set { tokens.edgeLabelCornerRadius = newValue }
    }
    public var edgeLabelBorderWidth: CGFloat {
        get { tokens.edgeLabelBorderWidth }
        set { tokens.edgeLabelBorderWidth = newValue }
    }

    // MARK: - Font Families (forwarded)

    public var defaultFontFamily: String? {
        get { tokens.defaultFontFamily }
        set { tokens.defaultFontFamily = newValue }
    }
    public var defaultProportionalFontFamily: String? {
        get { tokens.defaultProportionalFontFamily }
        set { tokens.defaultProportionalFontFamily = newValue }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Decomposed type accessors

    /// Font resolver backed by the token storage.
    /// Prefer `self.fontResolver.nodeLabelFont()` over `self.nodeLabelFont()`
    /// in new code. The instance methods below remain for backward compatibility.
    public var fontResolver: DiagramFontResolver {
        DiagramFontResolver(tokens: tokens)
    }

    /// Text measurement backed by the font resolver.
    /// Prefer `self.textMetrics.estimateTextWidth(...)` over
    /// `self.estimateTextWidth(...)` in new code.
    public var textMetrics: TextMetrics {
        TextMetrics(fontResolver: fontResolver)
    }

    // MARK: - Font Resolution (deprecated wrappers)
    //
    // These instance methods forward to `DiagramFontResolver` and
    // `TextMetrics`. New code should reach those types directly via
    // `self.fontResolver` and `self.textMetrics` so the determinism
    // guarantees of the lock-protected font factories aren't bypassed.

    /// Maps a CSS-style numeric weight (100..900) to a `BMFont.Weight`.
    public static func bmWeight(forCSS weight: Int) -> BMFont.Weight {
        DiagramFontResolver.bmWeight(forCSS: weight)
    }

    @available(*, deprecated, message: "Use config.fontResolver.defaultFont(size:weight:)")
    public func defaultFont(size: CGFloat, weight: Int = 400) -> BMFont {
        fontResolver.defaultFont(size: size, weight: weight)
    }

    @available(*, deprecated, message: "Use config.fontResolver.proportionalFont(size:weight:)")
    public func proportionalFont(size: CGFloat, weight: Int = 400) -> BMFont {
        fontResolver.proportionalFont(size: size, weight: weight)
    }

    // MARK: - Font Helpers (deprecated wrappers)

    @available(*, deprecated, message: "Use DiagramFontResolver.fontWeight(from:)")
    public func fontWeight(from weight: Int) -> BMFont.Weight {
        DiagramFontResolver.fontWeight(from: weight)
    }

    @available(*, deprecated, message: "Use config.fontResolver.nodeLabelFont(family:)")
    public func nodeLabelFont(family: String? = nil) -> BMFont {
        fontResolver.nodeLabelFont(family: family)
    }

    @available(*, deprecated, message: "Use config.fontResolver.edgeLabelFont(family:)")
    public func edgeLabelFont(family: String? = nil) -> BMFont {
        fontResolver.edgeLabelFont(family: family)
    }

    @available(*, deprecated, message: "Use config.fontResolver.groupHeaderFont(family:)")
    public func groupHeaderFont(family: String? = nil) -> BMFont {
        fontResolver.groupHeaderFont(family: family)
    }

    // MARK: - Text Measurement (deprecated wrappers)

    @available(*, deprecated, message: "Use config.textMetrics.estimateTextWidth(_:fontSize:fontWeight:)")
    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        textMetrics.estimateTextWidth(text, fontSize: fontSize, fontWeight: fontWeight)
    }

    @available(*, deprecated, message: "Use config.textMetrics.estimateMonoTextWidth(_:fontSize:)")
    public func estimateMonoTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        textMetrics.estimateMonoTextWidth(text, fontSize: fontSize)
    }
}
#endif
