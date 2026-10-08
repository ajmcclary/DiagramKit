// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import DiagramKitCommon

/// Value storage for all `RenderConfig` layout, font, spacing, and geometry constants.
///
/// `RenderTokens` is the source of truth for configurable values that were
/// previously stored directly on `RenderConfig`. It owns every constant —
/// node padding, font sizes/weights, stroke widths, arrow dimensions,
/// spacing, minimum sizes, shape-specific radii, edge-label layout, and
/// default font-family names.
///
/// Defaults for any field that has a counterpart in `original_src_styles`
/// (the Linux-portable static-constant table that SVG renderers read
/// directly) are sourced from that table. Bumping a shared default — font
/// size, font weight, stroke width, node padding, arrow head dimensions,
/// `groupHeaderContentPad` — requires editing exactly one number in
/// `DiagramKitCommon/src_styles.swift`; both the CG path (through
/// `RenderConfig.tokens`) and the SVG path (directly off
/// `original_src_styles`) pick the change up together.
///
/// Font resolution and SVG font-family strings are handled by
/// `DiagramFontResolver`. Text measurement is handled by `TextMetrics`.
/// Both take a `RenderTokens` instance as the configuration input.
///
/// Per-diagram-family constants live in extensions:
/// - `RenderTokens+Sequence.swift`
/// - `RenderTokens+Class.swift`
/// - `RenderTokens+ER.swift`
public struct RenderTokens: Sendable {

    public static let shared = RenderTokens()

    // MARK: - Node Padding (sourced from `original_src_styles.NODE_PADDING`)

    public var nodePaddingHorizontal: CGFloat = CGFloat(original_src_styles.NODE_PADDING.horizontal)
    public var nodePaddingVertical: CGFloat = CGFloat(original_src_styles.NODE_PADDING.vertical)
    public var nodePaddingDiamondExtra: CGFloat = CGFloat(original_src_styles.NODE_PADDING.diamondExtra)

    public var nodePadding: CGSize {
        CGSize(width: nodePaddingHorizontal, height: nodePaddingVertical)
    }

    // MARK: - Font Sizes (sourced from `original_src_styles.FONT_SIZES`)

    public var fontSizeNodeLabel: CGFloat = CGFloat(original_src_styles.FONT_SIZES.nodeLabel)
    public var fontSizeEdgeLabel: CGFloat = CGFloat(original_src_styles.FONT_SIZES.edgeLabel)
    public var fontSizeGroupHeader: CGFloat = CGFloat(original_src_styles.FONT_SIZES.groupHeader)

    // MARK: - Font Weights (sourced from `original_src_styles.FONT_WEIGHTS`)

    public var fontWeightNodeLabel: Int = original_src_styles.FONT_WEIGHTS.nodeLabel
    public var fontWeightEdgeLabel: Int = original_src_styles.FONT_WEIGHTS.edgeLabel
    public var fontWeightGroupHeader: Int = original_src_styles.FONT_WEIGHTS.groupHeader

    // MARK: - Stroke Widths (sourced from `original_src_styles.STROKE_WIDTHS`)

    public var strokeWidthOuterBox: CGFloat = CGFloat(original_src_styles.STROKE_WIDTHS.outerBox)
    public var strokeWidthInnerBox: CGFloat = CGFloat(original_src_styles.STROKE_WIDTHS.innerBox)
    public var strokeWidthConnector: CGFloat = CGFloat(original_src_styles.STROKE_WIDTHS.connector)

    // MARK: - Arrow Head (sourced from `original_src_styles.ARROW_HEAD`)

    public var arrowHeadWidth: CGFloat = CGFloat(original_src_styles.ARROW_HEAD.width)
    public var arrowHeadHeight: CGFloat = CGFloat(original_src_styles.ARROW_HEAD.height)

    // MARK: - Spacing

    public var groupHeaderContentPad: CGFloat = CGFloat(original_src_styles.GROUP_HEADER_CONTENT_PAD)
    public var subgraphPadding: CGFloat = 24
    public var nodeSpacing: CGFloat = 28
    public var layerSpacing: CGFloat = 48
    public var graphPadding: CGFloat = 40

    // MARK: - Text Rendering

    public var textBaselineShiftEm: CGFloat = 0.35

    // MARK: - Minimum Sizes

    public var minimumNodeWidth: CGFloat = CGFloat(RenderMetricDefaults.minimumNodeWidth)
    public var minimumNodeHeight: CGFloat = CGFloat(RenderMetricDefaults.minimumNodeHeight)
    public var statePseudostateSize: CGFloat = CGFloat(RenderMetricDefaults.statePseudostateSize)

    // MARK: - Shape-specific

    public var cylinderEllipseRadius: CGFloat = CGFloat(RenderMetricDefaults.cylinderEllipseRadius)
    public var subroutineInset: CGFloat = CGFloat(RenderMetricDefaults.subroutineInset)
    public var asymmetricIndent: CGFloat = CGFloat(RenderMetricDefaults.asymmetricIndent)
    public var doubleCircleGap: CGFloat = CGFloat(RenderMetricDefaults.doubleCircleGap)

    // MARK: - Edge Labels

    public var edgeLabelPadding: CGFloat = 8
    public var edgeLabelCornerRadius: CGFloat = 2
    public var edgeLabelBorderWidth: CGFloat = 1.0

    // MARK: - Font Families

    /// Default monospace font family name for deterministic rendering.
    ///
    /// Defaults to `"Noto Sans Mono"`, which is bundled in
    /// `Resources/Fonts/noto-sans-mono/` and registered at first render via
    /// `DiagramFontRegistry.registerBundledFontsIfNeeded()`. Set to
    /// `nil` to fall back to "Menlo" / system monospace.
    public var defaultFontFamily: String? = "Noto Sans Mono"

    /// Default proportional (non-monospace) font family name.
    ///
    /// Defaults to `"Noto Sans"`, which is bundled in
    /// `Resources/Fonts/noto-sans/` and registered at first render via
    /// `DiagramFontRegistry.registerBundledFontsIfNeeded()`. Set to
    /// `nil` to fall back to the system font.
    public var defaultProportionalFontFamily: String? = "Noto Sans"

    /// EventModeling-specific font family, used as the secondary
    /// fallback when the bundled proportional family fails to register.
    /// Matches mermaid-js's reference SVG output, which uses Trebuchet
    /// MS for EventModeling diagrams. Resolved by
    /// `DiagramFontResolver.eventModelingFont(size:weight:)`.
    public var eventModelingFontFamily: String? = "Trebuchet MS"

    // MARK: - Initialization

    public init() {}
}
#endif
