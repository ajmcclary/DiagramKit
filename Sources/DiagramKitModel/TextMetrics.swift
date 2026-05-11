// Apple-only — depends on CoreText and BMFont.
// Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText

/// Text measurement using CoreText for accurate, deterministic results.
///
/// `TextMetrics` uses `CTLineGetBoundsWithOptions(.useOpticalBounds)` which
/// matches the measurement used by `NSAttributedString.size()` in
/// `LabelRenderer`, ensuring consistent text placement between layout
/// and CG drawing.
///
/// Previously these methods lived on `RenderConfig`. They are extracted
/// here as part of the A5 `RenderConfig` three-way split.
public struct TextMetrics: Sendable {
    public let fontResolver: DiagramFontResolver

    public init(fontResolver: DiagramFontResolver = .shared) {
        self.fontResolver = fontResolver
    }

    /// Shared instance using the default font resolver.
    public static let shared = TextMetrics()

    /// Measure text width using CoreText for accurate, deterministic results.
    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = fontResolver.proportionalFont(size: fontSize, weight: fontWeight)
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
        let font = fontResolver.defaultFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return ceil(bounds.width)
    }
}
#endif
