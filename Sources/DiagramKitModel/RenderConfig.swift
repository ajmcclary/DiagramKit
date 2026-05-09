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

public struct RenderConfig: Sendable {

    public static let shared = RenderConfig()

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

    // MARK: - Sequence Diagram Constants

    public var sequenceLoopH: CGFloat = 20
    public var sequenceTabHeight: CGFloat = 18
    public var sequenceFoldSize: CGFloat = 6

    // MARK: - Class Diagram Constants

    public var classPadding: CGFloat = 40
    public var classBoxPadX: CGFloat = 8
    public var classHeaderBaseHeight: CGFloat = 32
    public var classAnnotationHeight: CGFloat = 16
    public var classMemberRowHeight: CGFloat = 20
    public var classSectionPadY: CGFloat = 8
    public var classEmptySectionHeight: CGFloat = 8
    public var classMinWidth: CGFloat = 120
    public var classMemberFontSize: CGFloat = 11
    public var classMemberFontWeight: Int = 400
    public var classNodeSpacing: CGFloat = 40
    public var classLayerSpacing: CGFloat = 60

    // MARK: - ER Diagram Constants

    public var erPadding: CGFloat = 40
    public var erBoxPadX: CGFloat = 14
    public var erHeaderHeight: CGFloat = 34
    public var erRowHeight: CGFloat = 22
    public var erMinWidth: CGFloat = 140
    public var erAttrFontSize: CGFloat = 11

    // MARK: - Font Resolution

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

    /// Maps a CSS-style numeric weight (100..900) to a `BMFont.Weight`.
    ///
    /// The previous implementation —
    /// `BMFont.Weight(CGFloat(weight) / 1000.0 * CGFloat(BMFont.Weight.regular.rawValue))`
    /// — was mathematically broken: `BMFont.Weight.regular.rawValue` is `0.0`,
    /// so the expression always evaluated to `0.0` (= regular weight)
    /// regardless of input. Bold/heavy weights silently degraded to regular.
    /// This switch-based mapping matches the documented CSS → Apple weight
    /// correspondence.
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
        if let family = defaultFontFamily {
            // Try a weight-suffixed variant first (e.g. "NotoSansMono-Bold"),
            // then the regular family. CTFontManager will return the closest
            // match available among registered fonts.
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
        if let family = defaultProportionalFontFamily {
            // Try weight-suffixed variant first.
            let suffix: String?
            switch weight {
            case ..<350:    suffix = nil // Regular catches Light too
            case 350..<450: suffix = nil
            case 450..<650: suffix = nil // Medium → Regular (no Medium in bundled Noto Sans)
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

    // MARK: - Initialization

    public init() {}

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

    public func nodeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeNodeLabel) ?? BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeNodeLabel, weight: fontWeight(from: fontWeightNodeLabel))
    }

    public func edgeLabelFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeEdgeLabel) ?? BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
        }
        return BMFont.systemFont(ofSize: fontSizeEdgeLabel, weight: fontWeight(from: fontWeightEdgeLabel))
    }

    public func groupHeaderFont(family: String? = nil) -> BMFont {
        if let family = family {
            return BMFont(name: family, size: fontSizeGroupHeader) ?? BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
        }
        return BMFont.systemFont(ofSize: fontSizeGroupHeader, weight: fontWeight(from: fontWeightGroupHeader))
    }

    /// Measure text width using CoreText for accurate, deterministic results.
    ///
    /// Uses `CTLineGetBoundsWithOptions(.useOpticalBounds)` which matches the
    /// measurement used by `NSAttributedString.size()` in `LabelRenderer`,
    /// ensuring consistent text placement between layout and CG drawing.
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
    ///
    /// Previously used a crude `charCount * fontSize * 0.6` approximation.
    /// Now uses actual CoreText measurement for accurate results with
    /// non-ASCII and fullwidth characters.
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
