//
//  DiagramSyntaxHighlighter.swift
//  DiagramPlayground
//
//  Lightweight regex-based syntax highlighter for diagram source.
//  Tokenizes source on a background queue; applies colored temporary
//  attributes on the main thread. Supports Mermaid keywords and JSON
//  for config mode.
//

import Foundation
import DiagramKit
import DiagramKitModel
import DesignKitThemes

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Token model

/// A categorized token produced by the highlighter.
public struct HighlightToken: Equatable, Sendable {
    public let range: NSRange
    public let category: TokenCategory

    public init(range: NSRange, category: TokenCategory) {
        self.range = range
        self.category = category
    }
}

/// Semantic token categories for syntax coloring.
public enum TokenCategory: String, Sendable, Equatable, CaseIterable {
    /// First-line diagram type keyword (`flowchart`, `sequenceDiagram`, …)
    case diagramType
    /// Directive keywords (`title`, `subgraph`, `classDef`, …)
    case keyword
    /// Edge operators (`-->`, `==>`, `-.->`, …)
    case transition
    /// Double-quoted or backtick-quoted strings
    case string
    /// `%%` line comments
    case comment
    /// Integer and decimal literals
    case number
    /// Braces, brackets, colons, commas, `&`, `;`
    case delimiter
    /// `<<…>>` annotations
    case annotation
    /// Alphanumeric identifiers (fallback)
    case variable
}

// MARK: - Highlighter

/// Async, cancellable syntax highlighter for diagram and JSON source.
///
/// Tokenization runs off the main thread. Results are applied to the
/// text view via temporary attributes (macOS) or direct attributed text
/// mutations (iOS) back on the main thread.
@MainActor
public final class DiagramSyntaxHighlighter: Sendable {

    // MARK: - Mode

    public enum Mode: Sendable {
        /// Mermaid keyword/operator/string tokenization.
        case mermaid
        case d2
        case dot
        case structurizr
        case plantUML
        /// JSON key/value tokenization for the config tab.
        case json
        /// No tokenization — emits zero tokens so a previous mode's
        /// temporary attributes are stripped and the text renders in
        /// the theme's default foreground color. Use for non-Mermaid
        /// source formats (D2 / DOT / Structurizr / PlantUML) until
        /// dedicated tokenizers exist.
        case plain
    }

    public let mode: Mode

    // MARK: - Compiled patterns

    /// Concurrency Contract: construction-then-freeze. Every stored property is
    /// `let` and assigned once in `init()`; the only non-`Sendable` members are
    /// `NSRegularExpression` instances, which Foundation documents as safe to
    /// share read-only across threads. After init the value is effectively
    /// immutable, so off-main tokenization can read it without synchronization.
    private struct Patterns: @unchecked Sendable {
        // Diagram type keywords (first line only)
        let diagramTypePattern: NSRegularExpression

        // Mermaid keywords (standalone words)
        let keywords: Set<String>

        // Single precompiled alternation of all keywords (`\b(kw1|kw2|…)\b`).
        // Replaces compiling ~100 regexes and running ~100 full-document
        // scans on every rehighlight.
        let keywordPattern: NSRegularExpression

        // Transition / arrow operators
        let transitionPattern: NSRegularExpression

        // Double-quoted strings: "…" (with escaped quotes)
        let dqStringPattern: NSRegularExpression

        // Backtick-quoted strings: `…`
        let btStringPattern: NSRegularExpression

        // Line comments: %% to end of line
        let commentPattern: NSRegularExpression

        // Numbers: integer, decimal, hex
        let numberPattern: NSRegularExpression

        // Delimiters: { } [ ] ( ) : ; & ,
        let delimiterPattern: NSRegularExpression

        // Annotations: <<…>>
        let annotationPattern: NSRegularExpression

        // JSON specific: key before colon
        let jsonKeyPattern: NSRegularExpression

        let d2KeywordPattern: NSRegularExpression
        let dotKeywordPattern: NSRegularExpression
        let structurizrKeywordPattern: NSRegularExpression
        let plantUMLKeywordPattern: NSRegularExpression
        let genericCommentPattern: NSRegularExpression
        let genericTransitionPattern: NSRegularExpression

        init() {
            func keywordExpression(_ keywords: [String]) -> NSRegularExpression {
                let alternation = keywords
                    .sorted { $0.count > $1.count }
                    .map { NSRegularExpression.escapedPattern(for: $0) }
                    .joined(separator: "|")
                return try! NSRegularExpression(
                    pattern: #"\b(?:"# + alternation + #")\b"#,
                    options: [.caseInsensitive]
                )
            }

            // Diagram type keywords (first-line only)
            let dtPatterns = [
                "flowchart", "flowchart-v2", "flowchart-elk", "graph",
                "sequenceDiagram", "classDiagram", "classDiagram-v2",
                "stateDiagram", "stateDiagram-v2", "erDiagram",
                "gantt", "pie", "journey", "gitGraph",
                "requirementDiagram", "requirement",
                "sankey-beta", "sankey",
                "mindmap", "timeline",
                "C4Context", "C4Container", "C4Component", "C4Dynamic", "C4Deployment",
                "quadrantChart", "xychart-beta",
                "block-beta", "packet-beta", "kanban",
                "zenuml", "architecture", "info",
                "eventmodeling",
                "radar-beta", "treemap-beta", "treemap", "venn-beta",
                "ishikawa-beta", "ishikawa", "treeView-beta", "wardley-beta",
            ]
            let dtAlt = dtPatterns
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            diagramTypePattern = try! NSRegularExpression(
                pattern: #"^\s*(?:"# + dtAlt + #")\b"#,
                options: [.caseInsensitive]
            )

            // Mermaid keywords
            keywords = Set([
                "title", "accTitle", "accDescr", "accDescription",
                "direction", "TB", "TD", "BT", "RL", "LR",
                "subgraph", "end",
                "classDef", "class", "style", "linkStyle",
                "click", "call", "href", "callback",
                "_self", "_blank", "_parent", "_top",
                "interpolate",
                "section", "dateFormat", "axisFormat", "todayMarker",
                "excludes", "inclusiveEndDates",
                "participant", "actor", "as",
                "Note", "note", "left of", "right of", "over",
                "activate", "deactivate", "autonumber",
                "loop", "alt", "else", "opt", "par", "and", "rect",
                "state", "hide empty description",
                "commit", "branch", "merge", "checkout", "reset",
                "cherry-pick",
                "showInfo", "showData",
                "link", "links", "properties",
                "option", "NORMAL", "REVERSE", "HIGHLIGHT",
                "requirement", "functionalRequirement",
                "interfaceRequirement", "performanceRequirement",
                "physicalRequirement", "designConstraint",
                "element",
                // EventModeling keywords
                "rf", "resetframe", "tf", "timeframe",
                "data", "note", "gwt",
                "Person", "Person_Ext",
                "System", "System_Ext", "SystemDb", "SystemDb_Ext",
                "SystemQueue", "SystemQueue_Ext",
                "Container", "Container_Ext", "ContainerDb", "ContainerDb_Ext",
                "ContainerQueue", "ContainerQueue_Ext",
                "Component", "Component_Ext", "ComponentDb", "ComponentDb_Ext",
                "ComponentQueue", "ComponentQueue_Ext",
                "Boundary", "Enterprise_Boundary", "System_Boundary",
                "Container_Boundary",
                "Node", "Node_L", "Node_R", "Deployment_Node",
                "Rel", "BiRel",
                "Rel_Up", "Rel_Down", "Rel_Left", "Rel_Right", "Rel_Back",
                "RelIndex",
            ])

            // Longest-first so the alternation prefers multi-word keywords
            // (`left of`) over their prefixes (`left`). Case-sensitive to
            // match the previous per-keyword behavior.
            let kwAlt = keywords
                .sorted { $0.count > $1.count }
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            keywordPattern = try! NSRegularExpression(
                pattern: #"\b(?:"# + kwAlt + #")\b"#
            )

            transitionPattern = try! NSRegularExpression(
                pattern: #"--+\>|--+x|--+[)o]|==+\>|[ox]\-{2,}>|[ox]=+>|-\.-+>|-->>|->>|[ox]\-+|\-{3,}|={3,}|\.\-\.|\.\.\>"#
            )

            dqStringPattern = try! NSRegularExpression(
                pattern: #""(?:[^"\\]|\\.)*""#
            )

            btStringPattern = try! NSRegularExpression(
                pattern: #"`[^`]*`"#
            )

            commentPattern = try! NSRegularExpression(
                pattern: #"%%.*$"#,
                options: [.anchorsMatchLines]
            )

            numberPattern = try! NSRegularExpression(
                pattern: #"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#
            )

            delimiterPattern = try! NSRegularExpression(
                pattern: #"[{}()\[\]:;&,]"#
            )

            annotationPattern = try! NSRegularExpression(
                pattern: #"<<[^>]+>>"#
            )

            jsonKeyPattern = try! NSRegularExpression(
                pattern: #""(?:[^"\\]|\\.)*"\s*:"#
            )

            d2KeywordPattern = keywordExpression([
                "direction", "shape", "style", "class", "classes", "near",
                "label", "tooltip", "link", "icon", "width", "height",
            ])
            dotKeywordPattern = keywordExpression([
                "strict", "graph", "digraph", "subgraph", "node", "edge",
                "label", "color", "shape", "style", "rankdir", "fontname",
            ])
            structurizrKeywordPattern = keywordExpression([
                "workspace", "model", "views", "person", "softwareSystem",
                "container", "component", "deploymentEnvironment",
                "systemContext", "containerView", "dynamicView", "styles",
                "element", "relationship", "include", "description",
            ])
            plantUMLKeywordPattern = keywordExpression([
                "startuml", "enduml", "class", "interface", "enum", "actor",
                "participant", "state", "activity", "mindmap", "gantt",
                "title", "package", "note", "as", "skinparam",
            ])
            genericCommentPattern = try! NSRegularExpression(
                pattern: #"(?m)(?://|#|').*$"#
            )
            genericTransitionPattern = try! NSRegularExpression(
                pattern: #"<->|->|<-|--|=>|:"#
            )
        }
    }

    private nonisolated static let patterns = Patterns()

    // MARK: - Public API

    public init(mode: Mode = .mermaid) {
        self.mode = mode
    }

    public nonisolated static func shouldApplyHighlight(
        capturedSource: String,
        currentText: String
    ) -> Bool {
        capturedSource == currentText
    }

    /// Tokenize the source and apply highlighting to the text view.
    ///
    /// - Parameters:
    ///   - source: The full source text.
    ///   - textView: The NSTextView to highlight.
    ///   - visibleRect: The currently visible rect (unused in v1).
    ///   - theme: The current diagram theme for color derivation.
    #if canImport(AppKit)
    public func highlight(
        _ source: String,
        in textView: NSTextView,
        visibleRect: NSRect,
        theme: Theme
    ) async {
        let tokens = await tokenize(source)

        // The tokenize hop is async; if the user edited during it, the token
        // ranges are stale and would miscolor. Bail — a fresh highlight pass
        // for the current text is already scheduled. (iOS guards the same way.)
        guard Self.shouldApplyHighlight(
            capturedSource: source,
            currentText: textView.string
        ) else {
            return
        }

        let colors = Self.colorMap(for: theme).mapValues { NSColor($0.color) }

        // Clear previous temporary attributes (one whole-range removal).
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        textView.layoutManager?.removeTemporaryAttribute(
            .foregroundColor,
            forCharacterRange: fullRange
        )

        // Apply new attributes
        for token in tokens {
            guard let color = colors[token.category] else { continue }
            let clampedRange = Self._clamp(token.range, to: fullRange)
            guard clampedRange.length > 0 else { continue }

            textView.layoutManager?.addTemporaryAttributes(
                [.foregroundColor: color],
                forCharacterRange: clampedRange
            )
        }
    }
    #endif

    #if canImport(UIKit)
    public func highlight(
        _ source: String,
        in textView: UITextView,
        visibleRect: CGRect,
        theme: Theme
    ) async {
        let tokens = await tokenize(source)
        let colors = Self.colorMap(for: theme).mapValues { UIColor($0.color) }

        // Build attributed string with highlighted ranges
        let attributed = NSMutableAttributedString(string: source)
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(theme.colors.editorForeground.color),
            .font: textView.font ?? .monospacedSystemFont(ofSize: 13, weight: .regular),
        ]
        attributed.setAttributes(defaultAttrs, range: NSRange(location: 0, length: source.utf16.count))

        let fullRange = NSRange(location: 0, length: source.utf16.count)
        for token in tokens {
            guard let color = colors[token.category] else { continue }
            let clampedRange = Self._clamp(token.range, to: fullRange)
            guard clampedRange.length > 0 else { continue }
            attributed.addAttribute(.foregroundColor, value: color, range: clampedRange)
        }

        guard Self.shouldApplyHighlight(
            capturedSource: source,
            currentText: textView.text ?? ""
        ) else {
            return
        }
        let selection = textView.selectedRange
        textView.attributedText = attributed
        textView.selectedRange = Self._clampSelection(selection, to: fullRange)
    }
    #endif

    // MARK: - Tokenization

    /// Tokenize the source on a background thread.
    public func tokenize(_ source: String) async -> [HighlightToken] {
        switch mode {
        case .mermaid:
            return await Task.detached(priority: .utility) {
                Self._tokenizeMermaid(source)
            }.value
        case .d2:
            return await Self._tokenizeGeneric(source, keywords: Self.patterns.d2KeywordPattern)
        case .dot:
            return await Self._tokenizeGeneric(source, keywords: Self.patterns.dotKeywordPattern)
        case .structurizr:
            return await Self._tokenizeGeneric(source, keywords: Self.patterns.structurizrKeywordPattern)
        case .plantUML:
            return await Self._tokenizeGeneric(source, keywords: Self.patterns.plantUMLKeywordPattern)
        case .json:
            return await Task.detached(priority: .utility) {
                Self._tokenizeJSON(source)
            }.value
        case .plain:
            return []
        }
    }

    private nonisolated static func _tokenizeGeneric(
        _ source: String,
        keywords: NSRegularExpression
    ) async -> [HighlightToken] {
        await Task.detached(priority: .utility) {
            let sourceString = source as NSString
            var tokens: [HighlightToken] = []
            _addMatches(patterns.genericCommentPattern, in: sourceString, category: .comment, to: &tokens)
            _addMatches(patterns.dqStringPattern, in: sourceString, category: .string, to: &tokens)
            _addMatches(patterns.btStringPattern, in: sourceString, category: .string, to: &tokens)
            _addMatches(patterns.numberPattern, in: sourceString, category: .number, to: &tokens)
            _addMatches(patterns.delimiterPattern, in: sourceString, category: .delimiter, to: &tokens)
            _addMatches(patterns.genericTransitionPattern, in: sourceString, category: .transition, to: &tokens)
            _addMatches(keywords, in: sourceString, category: .keyword, to: &tokens)
            tokens = _suppressOverlaps(tokens)
            tokens.sort { $0.range.location < $1.range.location }
            return tokens
        }.value
    }

    // MARK: - Mermaid tokenizer

    private nonisolated static func _tokenizeMermaid(_ source: String) -> [HighlightToken] {
        let p = patterns
        let nsSource = source as NSString
        var tokens: [HighlightToken] = []

        // 1. Diagram type (first line only)
        if let firstLineEnd = source.firstIndex(of: "\n") {
            let firstLineRange = NSRange(source.startIndex..<firstLineEnd, in: source)
            if let match = p.diagramTypePattern.firstMatch(in: source, range: firstLineRange) {
                tokens.append(HighlightToken(range: match.range, category: .diagramType))
            }
        } else if let match = p.diagramTypePattern.firstMatch(in: source, range: NSRange(location: 0, length: source.utf16.count)) {
            tokens.append(HighlightToken(range: match.range, category: .diagramType))
        }

        // 2. Comments (%% to end of line)
        _addMatches(p.commentPattern, in: nsSource, category: .comment, to: &tokens)

        // 3. Strings (before keywords so strings containing keywords aren't broken)
        _addMatches(p.dqStringPattern, in: nsSource, category: .string, to: &tokens)
        _addMatches(p.btStringPattern, in: nsSource, category: .string, to: &tokens)

        // 4. Annotations <<…>>
        _addMatches(p.annotationPattern, in: nsSource, category: .annotation, to: &tokens)

        // 5. Transitions (before delimiters so `-->` isn't split)
        _addMatches(p.transitionPattern, in: nsSource, category: .transition, to: &tokens)

        // 6. Numbers
        _addMatches(p.numberPattern, in: nsSource, category: .number, to: &tokens)

        // 7. Delimiters
        _addMatches(p.delimiterPattern, in: nsSource, category: .delimiter, to: &tokens)

        // 8. Keywords (single precompiled word-boundary alternation)
        _addMatches(p.keywordPattern, in: nsSource, category: .keyword, to: &tokens)

        // Drop keyword/number/delimiter/transition tokens that fall inside a
        // comment or string, so they don't repaint over the enclosing color
        // when tokens are applied in location order.
        tokens = _suppressOverlaps(tokens)

        // Sort by location
        tokens.sort { $0.range.location < $1.range.location }

        return tokens
    }

    /// Remove non-protective tokens that intersect a comment / string /
    /// annotation span. Applied to Mermaid only — JSON deliberately overlays
    /// its `.keyword` (key) token on top of the `.string` span.
    private nonisolated static func _suppressOverlaps(_ tokens: [HighlightToken]) -> [HighlightToken] {
        let protective: Set<TokenCategory> = [.comment, .string, .annotation]
        let spans = tokens.filter { protective.contains($0.category) }
        guard !spans.isEmpty else { return tokens }
        return tokens.filter { token in
            if protective.contains(token.category) || token.category == .diagramType {
                return true
            }
            return !spans.contains { NSIntersectionRange($0.range, token.range).length > 0 }
        }
    }

    // MARK: - JSON tokenizer

    private nonisolated static func _tokenizeJSON(_ source: String) -> [HighlightToken] {
        let p = patterns
        let nsSource = source as NSString
        var tokens: [HighlightToken] = []

        // String values
        _addMatches(p.dqStringPattern, in: nsSource, category: .string, to: &tokens)

        // Numbers
        _addMatches(p.numberPattern, in: nsSource, category: .number, to: &tokens)

        // Delimiters
        _addMatches(p.delimiterPattern, in: nsSource, category: .delimiter, to: &tokens)

        // JSON keys (strings followed by colon) — overlay with keyword color
        p.jsonKeyPattern.enumerateMatches(in: source, range: NSRange(location: 0, length: source.utf16.count)) { match, _, _ in
            guard let match else { return }
            // The key is the string part before the colon
            let keyEnd = match.range.length - 1 // drop the colon
            let keyRange = NSRange(location: match.range.location, length: max(0, keyEnd))
            if keyRange.length > 0 {
                tokens.append(HighlightToken(range: keyRange, category: .keyword))
            }
        }

        tokens.sort { $0.range.location < $1.range.location }
        return tokens
    }

    // MARK: - Helpers

    private nonisolated static func _addMatches(
        _ regex: NSRegularExpression,
        in source: NSString,
        category: TokenCategory,
        to tokens: inout [HighlightToken]
    ) {
        regex.enumerateMatches(
            in: source as String,
            range: NSRange(location: 0, length: source.length)
        ) { match, _, _ in
            guard let match else { return }
            tokens.append(HighlightToken(range: match.range, category: category))
        }
    }

    private nonisolated static func _clamp(_ range: NSRange, to fullRange: NSRange) -> NSRange {
        let location = max(range.location, fullRange.location)
        let end = min(NSMaxRange(range), NSMaxRange(fullRange))
        guard location < end else { return NSRange(location: 0, length: 0) }
        return NSRange(location: location, length: end - location)
    }

    private nonisolated static func _clampSelection(_ range: NSRange, to fullRange: NSRange) -> NSRange {
        let maxLocation = NSMaxRange(fullRange)
        let location = min(max(range.location, fullRange.location), maxLocation)
        let maxLength = max(0, maxLocation - location)
        return NSRange(location: location, length: min(range.length, maxLength))
    }

    // MARK: - Color mapping

    public nonisolated static func colorMap(
        for theme: Theme
    ) -> [TokenCategory: Tokens.Color] {
        Dictionary(uniqueKeysWithValues: TokenCategory.allCases.map { category in
            let syntaxRole: String = switch category {
            case .diagramType: "type"
            case .keyword: "keyword"
            case .transition: "operator"
            case .string: "string"
            case .comment: "comment"
            case .number: "number"
            case .delimiter: "punctuation"
            case .annotation: "attribute"
            case .variable: "variable"
            }
            return (category, theme.resolveSyntaxColor(for: syntaxRole))
        })
    }
}
