// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

/// Value storage for all `RenderConfig` layout, font, spacing, and geometry constants.
///
/// `RenderTokens` is the source of truth for configurable values that were
/// previously stored directly on `RenderConfig`. It owns every constant —
/// node padding, font sizes/weights, stroke widths, arrow dimensions,
/// spacing, minimum sizes, shape-specific radii, edge-label layout, and
/// default font-family names.
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

    // MARK: - Node Padding

    public var nodePaddingHorizontal: CGFloat = 20
    public var nodePaddingVertical: CGFloat = 10
    public var nodePaddingDiamondExtra: CGFloat = 24

    public var nodePadding: CGSize {
        CGSize(width: nodePaddingHorizontal, height: nodePaddingVertical)
    }

    // MARK: - Font Sizes

    public var fontSizeNodeLabel: CGFloat = 13
    public var fontSizeEdgeLabel: CGFloat = 11
    public var fontSizeGroupHeader: CGFloat = 12

    // MARK: - Font Weights

    public var fontWeightNodeLabel: Int = 500
    public var fontWeightEdgeLabel: Int = 400
    public var fontWeightGroupHeader: Int = 600

    // MARK: - Stroke Widths

    public var strokeWidthOuterBox: CGFloat = 1.0
    public var strokeWidthInnerBox: CGFloat = 0.75
    public var strokeWidthConnector: CGFloat = 1.0

    // MARK: - Arrow Head

    public var arrowHeadWidth: CGFloat = 8.0
    public var arrowHeadHeight: CGFloat = 5.0

    // MARK: - Spacing

    public var groupHeaderContentPad: CGFloat = 12.0
    public var subgraphPadding: CGFloat = 24
    public var nodeSpacing: CGFloat = 28
    public var layerSpacing: CGFloat = 48
    public var graphPadding: CGFloat = 40

    // MARK: - Text Rendering

    public var textBaselineShiftEm: CGFloat = 0.35

    // MARK: - Minimum Sizes

    public var minimumNodeWidth: CGFloat = 60
    public var minimumNodeHeight: CGFloat = 36
    public var statePseudostateSize: CGFloat = 28

    // MARK: - Shape-specific

    public var cylinderEllipseRadius: CGFloat = 7
    public var subroutineInset: CGFloat = 8
    public var asymmetricIndent: CGFloat = 12
    public var doubleCircleGap: CGFloat = 5

    // MARK: - Edge Labels

    public var edgeLabelPadding: CGFloat = 8
    public var edgeLabelCornerRadius: CGFloat = 2
    public var edgeLabelBorderWidth: CGFloat = 1.0

    // MARK: - Font Families

    /// Default monospace font family name for deterministic rendering.
    ///
    /// Defaults to `"Noto Sans Mono"`, which is bundled in
    /// `Resources/Fonts/noto-sans-mono/` and registered at first render via
    /// `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()`. Set to
    /// `nil` to fall back to "Menlo" / system monospace.
    public var defaultFontFamily: String? = "Noto Sans Mono"

    /// Default proportional (non-monospace) font family name.
    ///
    /// Defaults to `"Noto Sans"`, which is bundled in
    /// `Resources/Fonts/noto-sans/` and registered at first render via
    /// `BeautifulMermaidFontRegistry.registerBundledFontsIfNeeded()`. Set to
    /// `nil` to fall back to the system font.
    public var defaultProportionalFontFamily: String? = "Noto Sans"

    // MARK: - Initialization

    public init() {}
}
#endif
