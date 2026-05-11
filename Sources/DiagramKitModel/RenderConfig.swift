// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
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

    // MARK: - Font Resolution
    //
    // NOTE: These methods will move to `DiagramFontResolver` in Phase 2
    // of the A5 `RenderConfig` split. They remain here for backward
    // compatibility during the migration.

    /// Maps a CSS-style numeric weight (100..900) to a `BMFont.Weight`.
    public static func bmWeight(forCSS weight: Int) -> BMFont.Weight {
        switch weight {
        case ..<150:    return .ultraLight
        case 150..<250: return .thin
        case 250..<350: return .light
        case 350..<450: return .regular
        case 450..<550: return .medium
        case 550..<650: return .semibold
        case 650..<750: return .bold
        case 750..<850: return .heavy
        default:        return .black
        }
    }

    /// Resolves a monospace font, preferring `defaultFontFamily` when set.
    public func defaultFont(size: CGFloat, weight: Int = 400) -> BMFont {
        if let family = tokens.defaultFontFamily {
            if weight >= 550 {
                let boldCandidates = ["\(family)-Bold", "\(family) Bold"]
                for name in boldCandidates {
                    if let f = BMFont(name: name, size: size) { return f }
                }
            }
            if let named = BMFont(name: family, size: size) {
                return named
            }
        }
        return BMFont.monospacedSystemFont(ofSize: size, weight: Self.bmWeight(forCSS: weight))
    }

    /// Resolves a proportional (non-monospace) font for the given size and weight.
    public func proportionalFont(size: CGFloat, weight: Int = 400) -> BMFont {
        if let family = tokens.defaultProportionalFontFamily {
            let suffix: String?
            switch weight {
            case ..<350:    suffix = nil
            case 350..<450: suffix = nil
            case 450..<650: suffix = nil
            case 650..<850: suffix = "Bold"
            default:        suffix = "Bold"
            }
            if let s = suffix {
                let candidates = ["\(family)-\(s)", "\(family) \(s)"]
                for name in candidates {
                    if let f = BMFont(name: name, size: size) { return f }
                }
            }
            if let named = BMFont(name: family, size: size) {
                return named
            }
        }
        return BMFont.systemFont(ofSize: size, weight: Self.bmWeight(forCSS: weight))
    }

    // MARK: - Font Helpers

    public func fontWeight(from weight: Int) -> BMFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }

    /// Resolve the node-label font, honoring `defaultProportionalFontFamily`
    /// when no explicit `family` is provided.
    public func nodeLabelFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeNodeLabel) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeNodeLabel, weight: tokens.fontWeightNodeLabel)
    }

    /// Resolve the edge-label font.
    public func edgeLabelFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeEdgeLabel) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeEdgeLabel, weight: tokens.fontWeightEdgeLabel)
    }

    /// Resolve the group-header font.
    public func groupHeaderFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeGroupHeader) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeGroupHeader, weight: tokens.fontWeightGroupHeader)
    }

    // MARK: - Text Measurement
    //
    // NOTE: These methods will move to `TextMetrics` in Phase 3 of the A5
    // `RenderConfig` split. They remain here for backward compatibility.

    /// Measure text width using CoreText for accurate, deterministic results.
    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = proportionalFont(size: fontSize, weight: fontWeight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return ceil(bounds.width)
    }

    /// Measure monospace text width using CoreText.
    public func estimateMonoTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = defaultFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return ceil(bounds.width)
    }
}
#endif
