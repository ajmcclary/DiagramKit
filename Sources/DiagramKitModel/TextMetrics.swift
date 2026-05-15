import Foundation

/// Text measurement for layout accuracy.
///
/// On Apple platforms, `TextMetrics` uses `CTLineGetBoundsWithOptions(.useOpticalBounds)`
/// for exact CoreText measurement. On Linux, it falls back to character-count
/// estimation — conservative enough for monospace layouts (ishikawa, treeView)
/// to produce valid geometry without CoreText linkage.
///
/// Previously these methods lived on `RenderConfig`. They are extracted
/// here as part of the A5 `RenderConfig` three-way split.
public struct TextMetrics: Sendable {
#if canImport(CoreText)
    public let fontResolver: DiagramFontResolver

    public init(fontResolver: DiagramFontResolver = .shared) {
        self.fontResolver = fontResolver
    }
#else
    public init() {}
#endif

    /// Shared instance.
    ///
    /// On Apple this uses `DiagramFontResolver.shared` for CoreText
    /// measurement. On Linux this is a no-state struct that drives the
    /// char-count fallback in `estimateTextWidth` / `estimateMonoTextWidth`.
    public static let shared = TextMetrics()

    /// Measure proportional text width. Uses CoreText on Apple,
    /// character-count estimation on Linux.
    public func estimateTextWidth(_ text: String, fontSize: CGFloat, fontWeight: Int) -> CGFloat {
        guard !text.isEmpty else { return 0 }
#if canImport(CoreText)
        let font = fontResolver.proportionalFont(size: fontSize, weight: fontWeight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return ceil(bounds.width)
#else
        // Conservative proportional estimate: ~0.55 * fontSize per character.
        return CGFloat(text.count) * fontSize * 0.55
#endif
    }

    /// Measure monospace text width.
    public func estimateMonoTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
#if canImport(CoreText)
        let font = fontResolver.defaultFont(size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        return ceil(bounds.width)
#else
        // Standard monospace advance: ~0.6 * fontSize per character.
        return CGFloat(text.count) * fontSize * 0.6
#endif
    }

    /// Measure multi-line monospace text width (max line width) and height.
    /// Used by ishikawa, treeView, and other Linux-portable layouts.
    public func measureMonospaceMultiline(_ lines: [String], fontSize: CGFloat) -> (maxWidth: CGFloat, totalHeight: CGFloat) {
        guard !lines.isEmpty else { return (0, 0) }
        var maxWidth: CGFloat = 0
        for line in lines {
            maxWidth = max(maxWidth, estimateMonoTextWidth(line, fontSize: fontSize))
        }
        let lineHeight = fontSize * 1.05
        let totalHeight = lineHeight * CGFloat(lines.count)
        return (maxWidth, totalHeight)
    }
}

#if canImport(CoreText)
import CoreText
#endif
