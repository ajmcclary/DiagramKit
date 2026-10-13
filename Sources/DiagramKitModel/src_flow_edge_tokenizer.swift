// Edge syntax tokenizer for flowchart links.
import Foundation
import DiagramKitCommon

struct _ParsedEdgeOp {
    var edgeId: String?
    var arrowHeadStart: original_src_types.ArrowHeadType
    var arrowHeadEnd: original_src_types.ArrowHeadType
    var style: original_src_types.EdgeStyle
    var label: String?
    var minlen: Int?
    var consumedLength: Int

    init(arrowHeadStart: original_src_types.ArrowHeadType = original_src_types.ArrowHeadType.none,
         arrowHeadEnd: original_src_types.ArrowHeadType = original_src_types.ArrowHeadType.arrow,
         style: original_src_types.EdgeStyle = original_src_types.EdgeStyle.solid,
         consumedLength: Int = 0) {
        self.arrowHeadStart = arrowHeadStart
        self.arrowHeadEnd = arrowHeadEnd
        self.style = style
        self.consumedLength = consumedLength
    }
}

/// Scan the text for an edge operator and return parsed tokens.
/// Matches Mermaid edge syntax including edge IDs, bidirectional markers,
/// circle/cross arrowheads, text-embedded labels, pipe-delimited labels
/// (`-->|text|`, `--|text|-->`), minimum-length links, and invisible links.
func _scanEdgeOp(_ text: String) -> _ParsedEdgeOp? {
    guard var op = _scanEdgeOpBody(text) else { return nil }
    _scanPipeDelimitedLabel(text, into: &op)
    return op
}

/// Core operator scan (everything before the `|label|` suffix handling).
private func _scanEdgeOpBody(_ text: String) -> _ParsedEdgeOp? {
    let chars = Array(text)
    guard !chars.isEmpty else { return nil }
    var i = 0
    var op = _ParsedEdgeOp()

    // 1. Edge ID prefix: e{digits}@
    if chars[i] == "e" {
        var j = i + 1
        while j < chars.count, chars[j].isNumber { j += 1 }
        if j > i + 1, j < chars.count, chars[j] == "@" {
            op.edgeId = String(chars[i..<j])
            i = j + 1
        }
    }

    // 2. Bidirectional start marker (<)
    if i < chars.count, chars[i] == "<" {
        op.arrowHeadStart = .arrow
        i += 1
    }

    // 3. Arrowhead start variant: [ox] before body
    if i < chars.count {
        if chars[i] == "o" {
            op.arrowHeadStart = .circle
            i += 1
        } else if chars[i] == "x" {
            op.arrowHeadStart = .cross
            i += 1
        }
    }

    // 4. Body: determine style and optional arrow end
    guard i < chars.count else { return nil }

    let startCh = chars[i]

    // --- Invisible link: ~~~
    if startCh == "~", _matchSeq(chars, i, "~~~") {
        op.style = .invisible
        op.arrowHeadEnd = .none
        op.consumedLength = i + 3
        return op
    }

    // --- Dotted: -.->, -..->, -.-, -..-, " -. label .->"
    if startCh == "-", i + 1 < chars.count, chars[i + 1] == "." {
        i += 2  // consume "-."
        op.style = .dotted

        // Check for text-embedded label: "-. " (dash-dot-space)
        if i < chars.count, chars[i] == " " {
            while i < chars.count, chars[i] == " " { i += 1 }
            if let (label, closeLen, closeArrowEnd) = _scanTextEmbeddedLabel(chars, i) {
                op.label = label
                i += closeLen
                op.arrowHeadEnd = closeArrowEnd
                op.consumedLength = i
                return op
            }
            i -= 1  // rewind one char for the space; let normal parsing handle it
        }

        // Check for -..-> or -..-
        if i < chars.count, chars[i] == "." {
            var extraChars = 0
            while i < chars.count, chars[i] == "." { extraChars += 1; i += 1 }
            op.minlen = extraChars > 0 ? extraChars : nil
        }

        // Check for arrow end: -> or -
        if i < chars.count, chars[i] == "-" {
            i += 1
            if i < chars.count, chars[i] == ">" {
                op.arrowHeadEnd = .arrow
                i += 1
            } else {
                op.arrowHeadEnd = .none
            }
        }
        op.consumedLength = i
        return op
    }

    // --- Thick: ==>, ===, " == label ==>"
    if startCh == "=", i + 1 < chars.count, chars[i + 1] == "=" {
        i += 2  // consume "=="
        op.style = .thick

        // Check for text-embedded label: "== " (equals-equals-space)
        if i < chars.count, chars[i] == " " {
            while i < chars.count, chars[i] == " " { i += 1 }
            if let (label, closeLen, closeArrowEnd) = _scanTextEmbeddedLabel(chars, i) {
                op.label = label
                i += closeLen
                op.arrowHeadEnd = closeArrowEnd
                op.consumedLength = i
                return op
            }
            i -= 1  // rewind one char for the space; let normal parsing handle it
        }

        // Count extra equals for minlen
        var extraEquals = 0
        while i < chars.count, chars[i] == "=" { extraEquals += 1; i += 1 }

        // Check for arrow: >
        if i < chars.count, chars[i] == ">" {
            op.arrowHeadEnd = .arrow
            i += 1
        } else {
            op.arrowHeadEnd = .none
        }
        if extraEquals > 0 { op.minlen = extraEquals }
        op.consumedLength = i
        return op
    }

    // --- Solid: ----, ---, -- labeled, -->, --o, --x
    if startCh == "-" {
        // Check for text-embedded label: "-- " (dash-dash-space)
        if _matchSeq(chars, i, "-- ") {
            i += 2  // consume "--"
            // Skip space
            while i < chars.count, chars[i] == " " { i += 1 }
            // Find the closing arrow pattern
            if let (label, closeLen, closeArrowEnd) = _scanTextEmbeddedLabel(chars, i) {
                op.label = label
                i += closeLen
                op.arrowHeadEnd = closeArrowEnd
                op.consumedLength = i
                return op
            }
            // Fall through to normal solid parsing
        }

        i += 1  // consume first "-"
        var dashCount = 1
        while i < chars.count, chars[i] == "-" { dashCount += 1; i += 1 }

        if dashCount >= 2 {
            op.minlen = dashCount - 2  // 2 dashes = normal, 3+ = minlen
            // Check for arrowhead end variant: o, x, >
            if i < chars.count {
                switch chars[i] {
                case ">":
                    op.arrowHeadEnd = .arrow
                    i += 1
                case "o":
                    op.arrowHeadEnd = .circle
                    i += 1
                case "x":
                    op.arrowHeadEnd = .cross
                    i += 1
                default: break
                }
            } else {
                op.arrowHeadEnd = .none
            }
            op.consumedLength = i
            return op
        }
        // Single dash not a valid edge
        return nil
    }

    return nil
}

/// Scan a pipe-delimited edge label (`|text|`) that directly follows an edge
/// operator, e.g. `A -->|label| B`, `A ---|label| B`, `A <-->|label| B`, plus
/// the split-operator form `A --|label|--> B` where the closing arrow comes
/// after the label. The structurally-similar dotted/thick splits
/// (`-.|label|.->`, `==|label|==>`) are handled by the same closing-operator
/// scan. Runs after `_scanEdgeOpBody`, which stops with `consumedLength` at
/// the opening `|` for these forms.
///
/// When the operator body stopped at the pipe mid-operator (e.g. `---` in
/// `A ---|label| B`) and no closing arrow follows the label, the edge is the
/// Mermaid open-link form, so `arrowHeadEnd` is cleared to `.none` — the
/// default `.arrow` fallback only applies to the unlabeled operator paths,
/// whose behavior this function deliberately leaves untouched. Operators that
/// already consumed an explicit end arrowhead (`-->|label|`, `-.->|label|`,
/// `==>|label|`, `--o|label|`, `--x|label|`) are returned unmodified.
private func _scanPipeDelimitedLabel(_ text: String, into op: inout _ParsedEdgeOp) {
    let chars = Array(text)
    var i = op.consumedLength
    guard i < chars.count, chars[i] == "|" else { return }
    let endWasExplicit = i > 0 && (chars[i - 1] == ">" || chars[i - 1] == "o" || chars[i - 1] == "x")

    var close = i + 1
    while close < chars.count, chars[close] != "|" { close += 1 }
    guard close < chars.count else { return }

    let rawLabel = String(chars[(i + 1)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = original_src_multiline_utils.normalizeBrTags(rawLabel)
    if !normalized.isEmpty {
        op.label = normalized
    }
    i = close + 1

    if !endWasExplicit {
        if let (arrowEnd, closeLength) = _scanClosingArrow(chars, i) {
            op.arrowHeadEnd = arrowEnd
            i += closeLength
        } else {
            op.arrowHeadEnd = .none
        }
    }
    op.consumedLength = i
}

/// Match a closing arrow operator after a pipe label: the `-->` in
/// `--|label|-->`, the `.->` in `-.|label|.->`, the `==>` in `==|label|==>`,
/// or their open-link (`---`, `.-`, `===`) and circle/cross variants.
private func _scanClosingArrow(_ chars: [Character], _ start: Int) -> (arrowEnd: original_src_types.ArrowHeadType, length: Int)? {
    let candidates: [(String, original_src_types.ArrowHeadType)] = [
        ("-->", .arrow),
        ("--o", .circle),
        ("--x", .cross),
        (".->", .arrow),
        ("==>", .arrow),
        ("---", .none),
        (".-", .none),
        ("===", .none),
    ]
    for (pattern, arrowEnd) in candidates where _matchSeq(chars, start, pattern) {
        return (arrowEnd, pattern.count)
    }
    return nil
}

/// Match a specific sequence of characters at a position.
private func _matchSeq(_ chars: [Character], _ start: Int, _ pattern: String) -> Bool {
    let patChars = Array(pattern)
    guard start + patChars.count <= chars.count else { return false }
    for (offset, ch) in patChars.enumerated() {
        if chars[start + offset] != ch { return false }
    }
    return true
}

/// Scan a text-embedded label of the form "-- text -->" or "-. text .->" or "== text ==>".
/// Returns (label text, chars consumed, arrow end type) or nil.
private func _scanTextEmbeddedLabel(_ chars: [Character], _ start: Int) -> (String, Int, original_src_types.ArrowHeadType)? {
    let remaining = String(chars[start...])
    let patterns: [(String, original_src_types.ArrowHeadType)] = [
        ("-->", .arrow),
        (".->", .arrow),
        ("==>", .arrow),
        ("---", .none),
        ("-.-", .none),
        ("===", .none),
    ]
    var best: (range: Range<String.Index>, arrowEnd: original_src_types.ArrowHeadType)?
    for (pattern, arrowEnd) in patterns {
        if let range = remaining.range(of: pattern) {
            if let current = best, range.lowerBound >= current.range.lowerBound {
                continue
            }
            best = (range, arrowEnd)
        }
    }
    guard let best else { return nil }
    let labelText = String(remaining[..<best.range.lowerBound]).trimmingCharacters(in: .whitespaces)
    let consumed = start + remaining.distance(from: remaining.startIndex, to: best.range.upperBound)
    return (labelText, consumed - start, best.arrowEnd)
}
