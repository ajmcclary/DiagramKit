//
//  LineNumberRuler.swift
//  MermaidPlayground
//
//  Platform-specific line number ruler with current-line highlight
//  and diagnostic gutter markers.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

#if canImport(AppKit)
import AppKit

// MARK: - macOS NSRulerView

/// A vertical ruler view that draws line numbers, current-line highlight,
/// and diagnostic gutter markers next to an NSTextView.
@MainActor
final class LineNumberRulerView: NSRulerView {

    // MARK: - Configuration

    var theme: DiagramTheme = .default {
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

    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let diagnosticDotRadius: CGFloat = 3.5

    private var lineNumberAttributes: [NSAttributedString.Key: Any] {
        [.font: font as Any,
         .foregroundColor: theme.effectiveMuted()]
    }

    private var currentLineAttributes: [NSAttributedString.Key: Any] {
        [.font: font as Any,
         .foregroundColor: theme.foreground]
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
        theme.background.setFill()
        bounds.fill()

        let visibleRect = self.convert(rect, from: scrollView?.contentView)
        let context = NSGraphicsContext.current
        context?.shouldAntialias = true

        // Draw each visible line
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let charRange = layoutManager.characterRange(forGlyphRange: effectiveRange, actualGlyphRange: nil)

            let lineNumber = _lineNumber(for: charRange.location, in: content)
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
                theme.foreground.withAlphaComponent(0.06).setFill()
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
        let prefix = string.substring(to: charIndex)
        var count = 1
        for ch in prefix.utf16 {
            if ch == 0x0A { count += 1 }
        }
        return count
    }

    private func _colorForSeverity(_ severity: EditorDiagnostic.Severity) -> NSColor {
        switch severity {
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
    }
}

#elseif canImport(UIKit) && !targetEnvironment(macCatalyst)
import UIKit

// MARK: - iOS UIView

/// A vertical ruler view for iOS that draws line numbers and gutter markers.
@MainActor
final class LineNumberRulerView: UIView {

    var theme: DiagramTheme = .default {
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

    private let font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
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
        theme.background.setFill()
        UIRectFill(rect)

        let visibleRect = textView.convert(textView.bounds, to: self)

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        var glyphIndex = glyphRange.location

        while glyphIndex < NSMaxRange(glyphRange) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            let charRange = layoutManager.characterRange(forGlyphRange: effectiveRange, actualGlyphRange: nil)
            let lineNumber = _lineNumber(for: charRange.location, in: content)
            let isCurrent = lineNumber == currentLine

            let y = lineRect.minY
            let rulerWidth = bounds.width

            // Current line highlight
            if isCurrent {
                let highlightRect = CGRect(x: 0, y: y, width: rulerWidth, height: lineRect.height)
                theme.foreground.withAlphaComponent(0.06).setFill()
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
                    ? theme.foreground
                    : theme.effectiveMuted()
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
        let prefix = string.substring(to: charIndex)
        var count = 1
        for ch in prefix.utf16 {
            if ch == 0x0A { count += 1 }
        }
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
        case .error: return .systemRed
        case .warning: return .systemOrange
        case .info: return .systemBlue
        }
    }
}
#endif
