//
//  LineNumberRuler.swift
//  DiagramPlayground
//
//  Platform-specific line number ruler with current-line highlight
//  and diagnostic gutter markers.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DesignKitThemes

#if canImport(AppKit)
import AppKit

// MARK: - macOS NSRulerView

/// A vertical ruler view that draws line numbers, current-line highlight,
/// and diagnostic gutter markers next to an NSTextView.
@MainActor
final class LineNumberRulerView: NSRulerView {

    // MARK: - Configuration

    var theme: Theme = .lcarsDark {
        didSet { needsDisplay = true }
    }

    /// Line-numbered diagnostics for gutter markers (1-based).
    var diagnostics: [EditorDiagnostic] = [] {
        didSet { needsDisplay = true }
    }

    /// The 1-based line number of the insertion point (0 = no selection).
    var currentLine: Int = 0 {
        didSet {
            if currentLine != oldValue { needsDisplay = true }
        }
    }

    // MARK: - Metrics

    private let font = NSFont.monospacedDigitSystemFont(
        ofSize: Tokens.Typography.Size.captionMD,
        weight: .regular
    )
    private let diagnosticDotRadius: CGFloat = 3.5

    private var lineNumberAttributes: [NSAttributedString.Key: Any] {
        [.font: font as Any,
         .foregroundColor: NSColor(theme.colors.value("editor.line_number").color)]
    }

    private var currentLineAttributes: [NSAttributedString.Key: Any] {
        [.font: font as Any,
         .foregroundColor: NSColor(theme.colors.value("editor.active_line_number").color)]
    }

    // MARK: - Init

    init(scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.clientView = scrollView.documentView
        self.ruleThickness = 44
        self.reservedThicknessForMarkers = 0
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let content = textView.string as NSString

        // Background
        NSColor(theme.colors.editorGutterBackground.color).setFill()
        bounds.fill()

        let visibleRect = self.convert(rect, from: scrollView?.contentView)
        let context = NSGraphicsContext.current
        context?.shouldAntialias = true

        // Draw each visible line
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        // Track the line number incrementally across visible fragments — the
        // first fragment costs one O(charIndex) scan, subsequent fragments
        // only count newlines since the previous fragment. Avoids the old
        // O(visibleLines × documentLength) prefix rescans.
        var runningLine: Int?
        var lastCharLocation = 0

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let charRange = layoutManager.characterRange(forGlyphRange: effectiveRange, actualGlyphRange: nil)

            let lineNumber: Int
            if let running = runningLine {
                lineNumber = running + _newlineCount(in: content, from: lastCharLocation, to: charRange.location)
            } else {
                lineNumber = _lineNumber(for: charRange.location, in: content)
            }
            runningLine = lineNumber
            lastCharLocation = charRange.location
            let isCurrent = lineNumber == currentLine
            let y = lineRect.minY
            let rulerWidth = bounds.width

            // Current line highlight
            if isCurrent {
                let highlightRect = NSRect(
                    x: 0, y: y,
                    width: rulerWidth,
                    height: lineRect.height
                )
                NSColor(theme.colors.value("editor.active_line.background").color).setFill()
                highlightRect.fill()
            }

            // Diagnostic dot
            if let diagnostic = diagnostics.first(where: { $0.line == lineNumber }) {
                let dotColor = _colorForSeverity(diagnostic.severity)
                let dotRect = NSRect(
                    x: rulerWidth - 16,
                    y: y + (lineRect.height - diagnosticDotRadius * 2) / 2,
                    width: diagnosticDotRadius * 2,
                    height: diagnosticDotRadius * 2
                )
                let dotPath = NSBezierPath(ovalIn: dotRect)
                dotColor.setFill()
                dotPath.fill()
            }

            // Line number
            let numberText = "\(lineNumber)" as NSString
            let attrs = isCurrent ? currentLineAttributes : lineNumberAttributes
            let size = numberText.size(withAttributes: attrs)
            let numberX: CGFloat = rulerWidth - 34 - size.width
            let numberY = y + (lineRect.height - size.height) / 2

            numberText.draw(
                at: NSPoint(x: numberX, y: numberY),
                withAttributes: attrs
            )

            glyphIndex = NSMaxRange(effectiveRange)
        }
    }

    // MARK: - Helpers

    private func _lineCount(in string: NSString) -> Int {
        var count = 1
        for i in 0..<string.length {
            if string.character(at: i) == 0x0A { // '\n'
                count += 1
            }
        }
        return count
    }

    private func _lineNumber(for charIndex: Int, in string: NSString) -> Int {
        guard charIndex < string.length else { return _lineCount(in: string) }
        var count = 1
        for i in 0..<charIndex where string.character(at: i) == 0x0A { count += 1 }
        return count
    }

    /// Count newlines in `[from, to)` — used to advance the running line
    /// number between consecutive visible fragments.
    private func _newlineCount(in string: NSString, from: Int, to: Int) -> Int {
        guard from < to else { return 0 }
        var count = 0
        for i in from..<min(to, string.length) where string.character(at: i) == 0x0A { count += 1 }
        return count
    }

    private func _colorForSeverity(_ severity: EditorDiagnostic.Severity) -> NSColor {
        switch severity {
        case .error: return NSColor(theme.colors.error.color)
        case .warning: return NSColor(theme.colors.warning.color)
        case .info: return NSColor(theme.colors.info.color)
        }
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - iOS UIView

/// A vertical ruler view for iOS that draws line numbers and gutter markers.
@MainActor
final class LineNumberRulerView: UIView {

    var theme: Theme = .lcarsDark {
        didSet { setNeedsDisplay() }
    }

    var diagnostics: [EditorDiagnostic] = [] {
        didSet { setNeedsDisplay() }
    }

    var currentLine: Int = 0 {
        didSet {
            if currentLine != oldValue { setNeedsDisplay() }
        }
    }

    /// Weak reference to the paired text view for layout queries.
    weak var textView: UITextView?

    private let font = UIFont.monospacedDigitSystemFont(
        ofSize: Tokens.Typography.Size.captionMD,
        weight: .regular
    )
    private let diagnosticDotRadius: CGFloat = 3.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let textView else { return }
        let content = textView.text as NSString? ?? "" as NSString
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer

        // Background
        UIColor(theme.colors.editorGutterBackground.color).setFill()
        UIRectFill(rect)

        // The ruler is a static sibling view (not scrolled with the text), so
        // line-fragment Y positions (in text-container space) must be shifted
        // by the scroll offset and the container inset to land on screen.
        let offsetY = textView.contentOffset.y
        let insetTop = textView.textContainerInset.top

        // Visible region expressed in text-container coordinates.
        let visibleContainerRect = CGRect(
            x: 0,
            y: offsetY - insetTop,
            width: textView.bounds.width,
            height: textView.bounds.height
        )
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleContainerRect, in: textContainer)

        var runningLine: Int?
        var lastCharLocation = 0
        var glyphIndex = glyphRange.location

        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let charRange = layoutManager.characterRange(forGlyphRange: effectiveRange, actualGlyphRange: nil)
            let lineNumber: Int
            if let running = runningLine {
                lineNumber = running + _newlineCount(in: content, from: lastCharLocation, to: charRange.location)
            } else {
                lineNumber = _lineNumber(for: charRange.location, in: content)
            }
            runningLine = lineNumber
            lastCharLocation = charRange.location
            let isCurrent = lineNumber == currentLine

            // Convert the fragment's container-space Y to on-screen ruler Y.
            let y = lineRect.minY + insetTop - offsetY
            let rulerWidth = bounds.width

            // Current line highlight
            if isCurrent {
                let highlightRect = CGRect(x: 0, y: y, width: rulerWidth, height: lineRect.height)
                UIColor(theme.colors.value("editor.active_line.background").color).setFill()
                UIRectFill(highlightRect)
            }

            // Diagnostic dot
            if let diagnostic = diagnostics.first(where: { $0.line == lineNumber }) {
                let dotColor = _uiColorForSeverity(diagnostic.severity)
                let dotRect = CGRect(
                    x: rulerWidth - 14,
                    y: y + (lineRect.height - diagnosticDotRadius * 2) / 2,
                    width: diagnosticDotRadius * 2,
                    height: diagnosticDotRadius * 2
                )
                dotColor.setFill()
                let dotPath = UIBezierPath(ovalIn: dotRect)
                dotPath.fill()
            }

            // Line number text
            let numberText = "\(lineNumber)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isCurrent
                    ? UIColor(theme.colors.value("editor.active_line_number").color)
                    : UIColor(theme.colors.value("editor.line_number").color)
            ]
            let size = numberText.size(withAttributes: attrs)
            let numberX = rulerWidth - 30 - size.width
            let numberY = y + (lineRect.height - size.height) / 2

            numberText.draw(at: CGPoint(x: numberX, y: numberY), withAttributes: attrs)

            glyphIndex = NSMaxRange(effectiveRange)
        }
    }

    // MARK: - Helpers

    private func _lineNumber(for charIndex: Int, in string: NSString) -> Int {
        guard charIndex < string.length else { return _lineCount(in: string) }
        var count = 1
        for i in 0..<charIndex where string.character(at: i) == 0x0A { count += 1 }
        return count
    }

    /// Count newlines in `[from, to)` — advances the running line number
    /// between consecutive visible fragments.
    private func _newlineCount(in string: NSString, from: Int, to: Int) -> Int {
        guard from < to else { return 0 }
        var count = 0
        for i in from..<min(to, string.length) where string.character(at: i) == 0x0A { count += 1 }
        return count
    }

    private func _lineCount(in string: NSString) -> Int {
        var count = 1
        for i in 0..<string.length {
            if string.character(at: i) == 0x0A { count += 1 }
        }
        return count
    }

    private func _uiColorForSeverity(_ severity: EditorDiagnostic.Severity) -> UIColor {
        switch severity {
        case .error: return UIColor(theme.colors.error.color)
        case .warning: return UIColor(theme.colors.warning.color)
        case .info: return UIColor(theme.colors.info.color)
        }
    }
}
#endif
