// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
import CoreText

#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum TextAlignment {
    case left
    case center
    case right
}

public enum VerticalAlignment {
    case top
    case center
    case bottom
}

public final class LabelRenderer {

    public init() {}

    public func drawText(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        var x = point.x
        let y = point.y - size.height / 2

        switch alignment {
        case .left: break
        case .center: x = point.x - size.width / 2
        case .right: x = point.x - size.width
        }

        let rect = CGRect(x: x, y: y, width: size.width, height: size.height)
        drawAttributedString(attributedString, in: rect, context: context)
    }

    public func drawText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .left,
        verticalAlignment: VerticalAlignment = .center
    ) {
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        var x = rect.minX
        var y = rect.minY

        switch alignment {
        case .left: x = rect.minX
        case .center: x = rect.minX + (rect.width - size.width) / 2
        case .right: x = rect.maxX - size.width
        }

        switch verticalAlignment {
        case .top: y = rect.minY
        case .center: y = rect.minY + (rect.height - size.height) / 2
        case .bottom: y = rect.maxY - size.height
        }

        let drawRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        drawAttributedString(attributedString, in: drawRect, context: context)
    }

    // MARK: - Private Drawing

    private func drawAttributedString(
        _ attributedString: NSAttributedString,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        attributedString.draw(in: rect)
        #elseif canImport(AppKit)
        let centerY = rect.midY
        context.translateBy(x: 0, y: centerY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -centerY)

        // Always swap in our own `NSGraphicsContext(flipped: false)` so
        // `NSAttributedString.draw(in:)` does not compound a parent view's
        // flip flag with the local CTM unflip above. Previously the code
        // only installed a context when `current == nil` (the bitmap
        // path); on the AppKit NSView path the host view's flipped
        // context was reused, which combined with the local CTM unflip
        // to double-flip text and miscentre labels.
        let savedContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        attributedString.draw(in: rect)
        NSGraphicsContext.current = savedContext
        #endif

        context.restoreGState()
    }

    /// Draw multiline text (newline-separated) with each line individually positioned,
    /// matching the TS renderMultilineText vertical centering formula.
    /// Lines are centered on `rect.midY` using `lineHeight = fontSize * 1.3`.
    public func drawMultilineText(
        _ text: String,
        in rect: CGRect,
        context: CGContext,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center,
        lineSpacing: CGFloat = 4
    ) {
        guard !text.isEmpty else { return }

        let lines = text.components(separatedBy: "\n")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        // Match TS: lineHeight = fontSize * LINE_HEIGHT_RATIO (1.3)
        let fontSize = font.pointSize
        let lineHeight = fontSize * 1.3

        // Total block height and vertical start, centered on rect.midY
        let blockHeight = CGFloat(lines.count) * lineHeight
        let startY = rect.midY - blockHeight / 2

        for (i, line) in lines.enumerated() {
            guard !line.isEmpty else { continue }
            let attrStr = NSAttributedString(string: line, attributes: attributes)
            let size = attrStr.size()

            let y = startY + CGFloat(i) * lineHeight
            var x: CGFloat
            switch alignment {
            case .left:   x = rect.minX
            case .center: x = rect.midX - size.width / 2
            case .right:  x = rect.maxX - size.width
            }

            let lineRect = CGRect(x: x, y: y, width: size.width, height: size.height)
            drawAttributedString(attrStr, in: lineRect, context: context)
        }
    }

    // MARK: - Text Measurement

    public func measureText(_ text: String, font: BMFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSAttributedString(string: text, attributes: attributes).size()
    }

    /// Block extent for a newline-delimited multiline string. Width is the
    /// widest line's `NSAttributedString.size().width`; height is
    /// `lines.count * pointSize * 1.3` (matches `drawMultilineText`'s
    /// internal line-height). Blank lines contribute 0 to width but still
    /// bump the line count, mirroring the placement loop's row-index
    /// advance for skipped empty rows. `lineSpacing` is reserved for
    /// signature symmetry with `drawMultilineText` and is not consumed
    /// today; line-height already absorbs spacing.
    public func measureMultilineExtent(
        _ text: String,
        font: BMFont,
        lineSpacing: CGFloat = 4
    ) -> CGSize {
        let lines = text.components(separatedBy: "\n")
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let maxWidth = lines.reduce(CGFloat(0)) { acc, line in
            let w = NSAttributedString(string: line, attributes: attributes).size().width
            return max(acc, w)
        }
        let lineHeight = font.pointSize * 1.3
        return CGSize(width: maxWidth, height: CGFloat(lines.count) * lineHeight)
    }
}
#endif
