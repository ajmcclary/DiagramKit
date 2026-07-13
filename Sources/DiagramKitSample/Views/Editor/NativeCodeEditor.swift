//
//  NativeCodeEditor.swift
//  DiagramPlayground
//
//  Native NSTextView/UITextView wrapper replacing SwiftUI TextEditor.
//  Provides line numbers, cursor/scroll preservation, theme-aware
//  styling, and syntax highlighting integration.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DesignKitThemes

#if canImport(AppKit)
import AppKit

// MARK: - macOS NativeCodeEditor

struct NativeCodeEditor: NSViewRepresentable {
    let store: LiveEditorStore
    let mode: EditorMode
    let theme: Theme
    var diagnostics: [EditorDiagnostic] = []
    var highlighter: DiagramSyntaxHighlighter? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, mode: mode, theme: theme)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(
            ofSize: Tokens.Typography.Size.bodySM,
            weight: .regular
        )
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        // Line number ruler
        let ruler = LineNumberRulerView(scrollView: scrollView)
        ruler.theme = theme
        ruler.diagnostics = diagnostics
        scrollView.verticalRulerView = ruler
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.lineNumberRuler = ruler

        // Set initial text
        let initialText = context.coordinator.currentText(from: store)
        textView.string = initialText

        scrollView.documentView = textView
        applyTheme(to: textView, scrollView: scrollView, theme: theme)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        coordinator.theme = theme

        // Update mode if changed
        if coordinator.mode != mode {
            coordinator.mode = mode
            // Reload text for new mode
            let newText = coordinator.currentText(from: store)
            coordinator.applyExternalUpdate(newText, to: textView)
        }

        // Update theme
        applyTheme(to: textView, scrollView: scrollView, theme: theme)

        // Update ruler
        if let ruler = scrollView.verticalRulerView as? LineNumberRulerView {
            ruler.theme = theme
            ruler.diagnostics = diagnostics
        }

        // Check for external source changes
        let expectedText = coordinator.currentText(from: store)
        if textView.string != expectedText && !coordinator.isUserTyping {
            coordinator.applyExternalUpdate(expectedText, to: textView)
        }

        // Update highlighter reference and paint the first pass — makeNSView
        // sets `.string` directly and never kicks a highlight, so without this
        // a freshly loaded document renders uncolored until the first keystroke.
        coordinator.highlighter = highlighter
        coordinator.highlightIfNeeded(textView)
    }

    private func applyTheme(to textView: NSTextView, scrollView: NSScrollView, theme: Theme) {
        let colors = theme.colors
        textView.backgroundColor = NSColor(colors.editorBackground.color)
        textView.textColor = NSColor(colors.editorForeground.color)
        textView.insertionPointColor = NSColor(colors.accent.color)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(
                colors.value("editor.document_highlight.read_background").color
            )
        ]
        scrollView.backgroundColor = NSColor(colors.editorBackground.color)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let store: LiveEditorStore
        var mode: EditorMode
        var theme: Theme
        weak var textView: NSTextView?
        weak var lineNumberRuler: LineNumberRulerView?
        var highlighter: DiagramSyntaxHighlighter?

        /// Whether the user is actively typing (suppresses external updates).
        fileprivate(set) var isUserTyping = false
        private var debounceTask: Task<Void, Never>?
        private var didInitialHighlight = false

        init(store: LiveEditorStore, mode: EditorMode, theme: Theme) {
            self.store = store
            self.mode = mode
            self.theme = theme
            super.init()
        }

        func currentText(from store: LiveEditorStore) -> String {
            switch mode {
            case .code: return store.state.source
            case .config: return store.state.configJSON
            }
        }

        /// Paint the first highlight pass once a highlighter is available.
        func highlightIfNeeded(_ textView: NSTextView) {
            guard !didInitialHighlight, highlighter != nil else { return }
            didInitialHighlight = true
            scheduleHighlight(for: textView)
        }

        /// Apply an external source change while preserving cursor/scroll.
        func applyExternalUpdate(_ newText: String, to textView: NSTextView) {
            guard textView.string != newText else { return }

            let oldSelected = textView.selectedRange()
            let oldVisible = textView.visibleRect
            let oldLine = currentLineNumber(in: textView)

            textView.string = newText

            // An external re-seed is a new editing baseline. Setting `.string`
            // directly bypasses the undo machinery, so drop actions recorded
            // against the previous buffer — otherwise a later Cmd-Z reverses
            // an edit against an inconsistent range (or raises NSRangeException).
            textView.undoManager?.removeAllActions()

            // Restore cursor at same line if possible
            let newLineCount = _lineCount(in: newText as NSString)
            let targetLine = min(oldLine, newLineCount)
            if let newRange = _characterRange(forLine: targetLine, in: newText as NSString) {
                textView.setSelectedRange(NSRange(location: newRange.location, length: 0))
            } else {
                textView.setSelectedRange(_clampRange(oldSelected, toLength: newText.utf16.count))
            }

            // Restore scroll
            if oldVisible.origin.y < textView.bounds.height {
                textView.scrollToVisible(oldVisible)
            }

            updateRulerLine(textView)
            scheduleHighlight(for: textView)
        }

        /// Clamp both the location and length of a selection so it can never
        /// exceed the new text — `NSTextView.setSelectedRange` raises an
        /// exception on an over-long range (UIKit clamps, AppKit doesn't).
        private func _clampRange(_ range: NSRange, toLength length: Int) -> NSRange {
            let location = min(max(range.location, 0), length)
            let maxLength = max(0, length - location)
            return NSRange(location: location, length: min(range.length, maxLength))
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let newValue = textView.string
            let modeAtEdit = mode
            isUserTyping = true

            debounceTask?.cancel()
            debounceTask = Task { [weak self, weak textView] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                await MainActor.run {
                    self.isUserTyping = false
                    switch modeAtEdit {
                    case .code:
                        self.store.setSource(newValue, origin: .user)
                    case .config:
                        self.store.setConfigJSON(newValue)
                    }
                    if let textView {
                        self.scheduleHighlight(for: textView)
                    }
                }
            }

            updateRulerLine(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            updateRulerLine(textView)
        }

        // MARK: - Helpers

        private func updateRulerLine(_ textView: NSTextView) {
            let line = currentLineNumber(in: textView)
            lineNumberRuler?.currentLine = line
        }

        private func currentLineNumber(in textView: NSTextView) -> Int {
            let selected = textView.selectedRange()
            let content = textView.string as NSString
            return _lineNumber(for: selected.location, in: content)
        }

        private func scheduleHighlight(for textView: NSTextView) {
            guard let highlighter else { return }
            let hl = highlighter
            Task { [weak self, weak textView] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, let textView else { return }
                guard self?.isUserTyping == false else { return }
                let source = textView.string
                let visible = textView.visibleRect
                guard let theme = self?.theme else { return }
                await hl.highlight(source, in: textView, visibleRect: visible, theme: theme)
            }
        }

        private func _lineCount(in string: NSString) -> Int {
            var count = 1
            for i in 0..<string.length {
                if string.character(at: i) == 0x0A { count += 1 }
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

        private func _characterRange(forLine targetLine: Int, in string: NSString) -> NSRange? {
            guard targetLine >= 1 else { return nil }
            var line = 1
            for i in 0..<string.length {
                if line == targetLine {
                    // Find end of this line
                    var end = i
                    while end < string.length && string.character(at: end) != 0x0A {
                        end += 1
                    }
                    return NSRange(location: i, length: end - i)
                }
                if string.character(at: i) == 0x0A {
                    line += 1
                }
            }
            if line == targetLine {
                return NSRange(location: string.length, length: 0)
            }
            return nil
        }
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - iOS NativeCodeEditor

struct NativeCodeEditor: UIViewRepresentable {
    let store: LiveEditorStore
    let mode: EditorMode
    let theme: Theme
    var diagnostics: [EditorDiagnostic] = []
    var highlighter: DiagramSyntaxHighlighter? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, mode: mode, theme: theme)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let ruler = LineNumberRulerView(frame: .zero)
        ruler.theme = theme
        ruler.diagnostics = diagnostics
        ruler.translatesAutoresizingMaskIntoConstraints = false

        let textView = UITextView()
        textView.isEditable = true
        textView.isSelectable = true
        let baseFont = UIFont.monospacedSystemFont(
            ofSize: Tokens.Typography.Size.bodyLG,
            weight: .regular
        )
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        textView.adjustsFontForContentSizeCategory = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.delegate = context.coordinator
        textView.translatesAutoresizingMaskIntoConstraints = false

        ruler.textView = textView

        container.addSubview(ruler)
        container.addSubview(textView)

        NSLayoutConstraint.activate([
            ruler.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            ruler.topAnchor.constraint(equalTo: container.topAnchor),
            ruler.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ruler.widthAnchor.constraint(equalToConstant: 44),

            textView.leadingAnchor.constraint(equalTo: ruler.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.textView = textView
        context.coordinator.lineNumberRuler = ruler

        let initialText = context.coordinator.currentText(from: store)
        textView.text = initialText

        applyTheme(to: textView, ruler: ruler, theme: theme)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let textView = container.subviews.compactMap({ $0 as? UITextView }).first,
              let ruler = container.subviews.compactMap({ $0 as? LineNumberRulerView }).first
        else { return }
        let coordinator = context.coordinator
        coordinator.theme = theme

        if coordinator.mode != mode {
            coordinator.mode = mode
            let newText = coordinator.currentText(from: store)
            coordinator.applyExternalUpdate(newText, to: textView)
        }

        applyTheme(to: textView, ruler: ruler, theme: theme)
        ruler.diagnostics = diagnostics

        let expectedText = coordinator.currentText(from: store)
        if textView.text != expectedText && !coordinator.isUserTyping {
            coordinator.applyExternalUpdate(expectedText, to: textView)
        }

        coordinator.highlighter = highlighter
        coordinator.highlightIfNeeded(textView)
    }

    private func applyTheme(to textView: UITextView, ruler: LineNumberRulerView, theme: Theme) {
        let colors = theme.colors
        textView.backgroundColor = UIColor(colors.editorBackground.color)
        textView.textColor = UIColor(colors.editorForeground.color)
        textView.tintColor = UIColor(colors.accent.color)
        ruler.theme = theme
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        let store: LiveEditorStore
        var mode: EditorMode
        var theme: Theme
        weak var textView: UITextView?
        weak var lineNumberRuler: LineNumberRulerView?
        var highlighter: DiagramSyntaxHighlighter?

        fileprivate(set) var isUserTyping = false
        private var debounceTask: Task<Void, Never>?
        private var didInitialHighlight = false

        init(store: LiveEditorStore, mode: EditorMode, theme: Theme) {
            self.store = store
            self.mode = mode
            self.theme = theme
            super.init()
        }

        func currentText(from store: LiveEditorStore) -> String {
            switch mode {
            case .code: return store.state.source
            case .config: return store.state.configJSON
            }
        }

        /// Paint the first highlight pass once a highlighter is available.
        func highlightIfNeeded(_ textView: UITextView) {
            guard !didInitialHighlight, highlighter != nil else { return }
            didInitialHighlight = true
            scheduleHighlight(for: textView)
        }

        func applyExternalUpdate(_ newText: String, to textView: UITextView) {
            guard textView.text != newText else { return }

            let oldSelected = textView.selectedRange
            let oldLine = _currentLine(in: textView)

            textView.text = newText

            // New editing baseline — clear undo actions recorded against the
            // old buffer (see the macOS note).
            textView.undoManager?.removeAllActions()

            let newLineCount = _lineCount(in: newText as NSString)
            let targetLine = min(oldLine, newLineCount)
            if let newRange = _characterRange(forLine: targetLine, in: newText as NSString) {
                // Collapse to a caret at the line start — matching macOS —
                // rather than leaving the whole line selected (which would let
                // the next keystroke replace the line).
                textView.selectedRange = NSRange(location: newRange.location, length: 0)
            } else {
                textView.selectedRange = _clampRange(oldSelected, toLength: newText.utf16.count)
            }

            lineNumberRuler?.currentLine = _currentLine(in: textView)
            scheduleHighlight(for: textView)
        }

        /// Clamp a selection to the new text length (UITextView clamps for us,
        /// but keep parity with the macOS path and avoid surprises).
        private func _clampRange(_ range: NSRange, toLength length: Int) -> NSRange {
            let location = min(max(range.location, 0), length)
            let maxLength = max(0, length - location)
            return NSRange(location: location, length: min(range.length, maxLength))
        }

        // MARK: - UIScrollViewDelegate

        /// The iOS ruler is a static sibling view, so it must be told to
        /// repaint whenever the text scrolls (macOS's NSRulerView is wired to
        /// the scroll view and repaints automatically).
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            lineNumberRuler?.setNeedsDisplay()
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            let newValue = textView.text ?? ""
            let modeAtEdit = mode
            isUserTyping = true

            debounceTask?.cancel()
            debounceTask = Task { [weak self, weak textView] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { return }
                await MainActor.run {
                    self.isUserTyping = false
                    switch modeAtEdit {
                    case .code:
                        self.store.setSource(newValue, origin: .user)
                    case .config:
                        self.store.setConfigJSON(newValue)
                    }
                    if let textView {
                        self.scheduleHighlight(for: textView)
                    }
                }
            }

            lineNumberRuler?.currentLine = _currentLine(in: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            lineNumberRuler?.currentLine = _currentLine(in: textView)
        }

        // MARK: - Helpers

        private func _currentLine(in textView: UITextView) -> Int {
            let selected = textView.selectedRange
            let content = textView.text as NSString? ?? "" as NSString
            return _lineNumber(for: selected.location, in: content)
        }

        private func scheduleHighlight(for textView: UITextView) {
            guard let highlighter else { return }
            let hl = highlighter
            Task { [weak self, weak textView] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, let textView else { return }
                guard self?.isUserTyping == false else { return }
                let source = textView.text ?? ""
                let visible = textView.bounds
                guard let theme = self?.theme else { return }
                await hl.highlight(source, in: textView, visibleRect: visible, theme: theme)
            }
        }

        private func _lineCount(in string: NSString) -> Int {
            var count = 1
            for i in 0..<string.length {
                if string.character(at: i) == 0x0A { count += 1 }
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

        private func _characterRange(forLine targetLine: Int, in string: NSString) -> NSRange? {
            guard targetLine >= 1 else { return nil }
            var line = 1
            for i in 0..<string.length {
                if line == targetLine {
                    var end = i
                    while end < string.length && string.character(at: end) != 0x0A {
                        end += 1
                    }
                    return NSRange(location: i, length: end - i)
                }
                if string.character(at: i) == 0x0A {
                    line += 1
                }
            }
            if line == targetLine {
                return NSRange(location: string.length, length: 0)
            }
            return nil
        }
    }
}
#endif
