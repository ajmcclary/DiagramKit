import Foundation

// Source text the parsed model does not hold, kept so an exporter can write
// it back exactly (owner rulings for the canvas editor, which saves the
// exporter's output as the document):
//
// - the preamble — frontmatter and `%%{init}%%` directives before the
//   diagram header — byte for byte, unless the edit itself changes the
//   title, theme or layout, in which case only that key is changed in place;
// - full-line `%%` comments, each at the statement it preceded or at the end
//   of its block;
// - `click`, `link` and `links` lines, exactly as written.
//
// The Mermaid importer records these; `_applyMermaidSourceAnnotations`
// writes them into an export.

/// Where a full-line comment sat in the source.
public enum DiagramSourceCommentAnchor: Sendable, Equatable, Hashable {
    /// Before the next statement: its whitespace-free text, and its leading
    /// key (`A`, `subgraph S1`, `click A`) for when the text was re-spelled.
    case before(statement: String, key: String)
    /// Last line of the block whose header has this leading key.
    case endOfBlock(headerKey: String)
    /// After the last statement.
    case endOfDocument
}

public struct DiagramSourceComment: Sendable, Equatable, Hashable {
    /// The comment line exactly as written, indentation included.
    public var line: String
    public var anchor: DiagramSourceCommentAnchor

    public init(line: String, anchor: DiagramSourceCommentAnchor) {
        self.line = line
        self.anchor = anchor
    }
}

public struct DiagramSourceAnnotations: Sendable, Equatable, Hashable {
    /// Everything before the diagram header, exactly as written (frontmatter
    /// fences included), each line ending in `\n`. Empty when there was none.
    public var preamble: String
    /// The title, theme and layout the preamble set, as the importer read
    /// them; an export rewrites the preamble only where the document now
    /// differs from these.
    public var preambleTitle: String?
    public var preambleTheme: String?
    public var preambleLayout: String?
    /// Full-line comments (and `%%{…}%%` directives) after the header.
    public var comments: [DiagramSourceComment]
    /// `click` / `link` / `links` lines exactly as written, by statement
    /// key, in source order (a later line for the same key overrides an
    /// earlier one in the model, but both stay in the text).
    public var verbatimStatements: [String: [String]]

    public init(
        preamble: String = "",
        preambleTitle: String? = nil,
        preambleTheme: String? = nil,
        preambleLayout: String? = nil,
        comments: [DiagramSourceComment] = [],
        verbatimStatements: [String: [String]] = [:]
    ) {
        self.preamble = preamble
        self.preambleTitle = preambleTitle
        self.preambleTheme = preambleTheme
        self.preambleLayout = preambleLayout
        self.comments = comments
        self.verbatimStatements = verbatimStatements
    }

    public var isEmpty: Bool { preamble.isEmpty && comments.isEmpty && verbatimStatements.isEmpty }
}

// MARK: - Statement keys

/// Keywords whose statement is named by the keyword and the next token.
private let _twoTokenKeywords: Set<String> = [
    "subgraph", "state", "class", "classDef", "style", "click", "link", "links", "linkStyle",
    "note", "participant", "actor", "section", "loop", "alt", "opt", "par", "rect", "box",
    "critical", "break", "direction", "namespace", "activate", "deactivate", "create", "destroy",
]

/// Keywords that open a block closed by `end`.
private let _endBlockKeywords: Set<String> = ["subgraph", "loop", "alt", "opt", "par", "critical", "break", "rect", "box"]

private func _leadingToken(_ text: Substring) -> (token: String, rest: Substring) {
    let trimmed = text.drop(while: { $0 == " " || $0 == "\t" })
    if trimmed.hasPrefix("[*]") { return ("[*]", trimmed.dropFirst(3)) }
    let stops: Set<Character> = [" ", "\t", "[", "]", "(", ")", "{", "}", "<", ">", "|", ":", ";", "\"", "@", "&", ",", "=", "~"]
    var end = trimmed.startIndex
    while end < trimmed.endIndex {
        let ch = trimmed[end]
        if stops.contains(ch) { break }
        if ch == "-" || ch == "." {
            let next = trimmed.index(after: end)
            if next < trimmed.endIndex, "->.".contains(trimmed[next]) { break }
        }
        end = trimmed.index(after: end)
    }
    return (String(trimmed[..<end]), trimmed[end...])
}

/// The statement's leading key: its first token, or keyword plus name.
public func _sourceStatementKey(_ line: String) -> String {
    let (first, rest) = _leadingToken(Substring(line))
    guard _twoTokenKeywords.contains(first) else { return first }
    let (second, _) = _leadingToken(rest)
    return second.isEmpty ? first : "\(first) \(second)"
}

/// The statement with all whitespace removed (two spellings that differ
/// only in spacing match).
public func _sourceStatementText(_ line: String) -> String {
    String(line.filter { !$0.isWhitespace })
}

/// Key under which a `click` / `link` / `links` line is kept verbatim, or
/// nil for any other line. A `link` line is keyed by actor and label, since
/// one actor may have several.
public func _verbatimStatementKey(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let (first, rest) = _leadingToken(Substring(trimmed))
    switch first {
    case "click", "links":
        let key = _sourceStatementKey(trimmed)
        return key == first ? nil : key
    case "link":
        let head = rest.split(separator: "@", maxSplits: 1).first.map(String.init) ?? String(rest)
        let collapsed = head.replacingOccurrences(of: "\"", with: "")
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
            .replacingOccurrences(of: " :", with: ":")
        return collapsed.isEmpty ? nil : "link \(collapsed)"
    default:
        return nil
    }
}

private func _isBlockOpener(_ trimmed: String) -> Bool {
    if trimmed.hasSuffix("{") { return true }
    let (first, _) = _leadingToken(Substring(trimmed))
    return _endBlockKeywords.contains(first)
}

private func _isBlockCloser(_ trimmed: String) -> Bool {
    trimmed == "end" || trimmed.hasPrefix("}")
}

private func _isCommentLine(_ trimmed: String) -> Bool {
    trimmed.hasPrefix("%%")
}

// MARK: - Collection

/// Annotations for `source` (line endings already normalised), or nil when
/// it has nothing the model does not hold.
public func _collectMermaidSourceAnnotations(
    _ source: String,
    title: String?,
    theme: String?,
    layout: String?
) -> DiagramSourceAnnotations? {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var index = 0

    // Preamble: blank lines, one frontmatter block, comments and directives
    // (a multi-line `%%{` directive runs to its `}%%`) before the header.
    var sawFrontmatter = false
    while index < lines.count {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { index += 1; continue }
        if trimmed == "---", !sawFrontmatter {
            sawFrontmatter = true
            var close = index + 1
            while close < lines.count, lines[close].trimmingCharacters(in: .whitespaces) != "---" { close += 1 }
            guard close < lines.count else { break }
            index = close + 1
            continue
        }
        if trimmed.hasPrefix("%%{"), !trimmed.hasSuffix("}%%") {
            var close = index
            while close < lines.count, !lines[close].trimmingCharacters(in: .whitespaces).hasSuffix("}%%") { close += 1 }
            index = min(close + 1, lines.count)
            continue
        }
        if _isCommentLine(trimmed) { index += 1; continue }
        break
    }
    let headerIndex = index
    let preamble = lines[..<headerIndex].map { $0 + "\n" }.joined()

    var comments: [DiagramSourceComment] = []
    var verbatim: [String: [String]] = [:]
    var blockStack: [String] = []
    var pending: [String] = []

    func flush(_ anchor: DiagramSourceCommentAnchor) {
        comments += pending.map { DiagramSourceComment(line: $0, anchor: anchor) }
        pending = []
    }

    var i = headerIndex + 1
    while i < lines.count {
        let raw = lines[i]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { i += 1; continue }
        if _isCommentLine(trimmed) {
            // A multi-line directive is kept as one comment.
            if trimmed.hasPrefix("%%{"), !trimmed.hasSuffix("}%%") {
                var block = [raw]
                var j = i + 1
                while j < lines.count {
                    block.append(lines[j])
                    if lines[j].trimmingCharacters(in: .whitespaces).hasSuffix("}%%") { break }
                    j += 1
                }
                pending.append(block.joined(separator: "\n"))
                i = j + 1
                continue
            }
            pending.append(raw)
            i += 1
            continue
        }
        if _isBlockCloser(trimmed) {
            if let header = blockStack.popLast() {
                flush(.endOfBlock(headerKey: header))
            }
        } else {
            flush(.before(statement: _sourceStatementText(trimmed), key: _sourceStatementKey(trimmed)))
            if let key = _verbatimStatementKey(trimmed) {
                verbatim[key, default: []].append(raw)
            }
            if _isBlockOpener(trimmed) {
                blockStack.append(_sourceStatementKey(trimmed))
            }
        }
        i += 1
    }
    if let open = blockStack.last {
        flush(.endOfBlock(headerKey: open))
    }
    flush(.endOfDocument)

    let annotations = DiagramSourceAnnotations(
        preamble: preamble,
        preambleTitle: title,
        preambleTheme: theme,
        preambleLayout: layout,
        comments: comments,
        verbatimStatements: verbatim
    )
    return annotations.isEmpty ? nil : annotations
}

// MARK: - Application

/// `body` (an exporter's output, header first) with the annotations written
/// back: verbatim `click`/`link` lines substituted, comments inserted at
/// their anchors, and the preamble prepended — with only the title, theme or
/// layout key changed in place when the document's value differs from the
/// one the preamble set.
public func _applyMermaidSourceAnnotations(
    _ body: String,
    _ annotations: DiagramSourceAnnotations,
    title: String?,
    theme: String?,
    layout: String?
) -> String {
    var lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    if lines.last == "" { lines.removeLast() }

    var substituted: [String] = []
    for line in lines {
        if let key = _verbatimStatementKey(line), let originals = annotations.verbatimStatements[key], !originals.isEmpty {
            substituted += originals
        } else {
            substituted.append(line)
        }
    }
    lines = substituted

    // Insertion points are computed against the exporter's lines, then
    // applied bottom-up so earlier insertions do not shift later ones.
    var insertions: [Int: [String]] = [:]
    let texts = lines.map { _sourceStatementText($0) }
    let keys = lines.map { _sourceStatementKey($0) }
    func closingIndex(forHeader header: String) -> Int? {
        guard let start = lines.indices.first(where: {
            keys[$0] == header && _isBlockOpener(lines[$0].trimmingCharacters(in: .whitespaces))
        }) else { return nil }
        var depth = 1
        var k = start + 1
        while k < lines.count {
            let trimmed = lines[k].trimmingCharacters(in: .whitespaces)
            if _isBlockCloser(trimmed) {
                depth -= 1
                if depth == 0 { return k }
            } else if _isBlockOpener(trimmed) {
                depth += 1
            }
            k += 1
        }
        return nil
    }
    for comment in annotations.comments {
        let target: Int
        switch comment.anchor {
        case .before(let statement, let key):
            target = texts.firstIndex(of: statement)
                ?? keys.firstIndex(of: key)
                ?? lines.count
        case .endOfBlock(let header):
            target = closingIndex(forHeader: header) ?? lines.count
        case .endOfDocument:
            target = lines.count
        }
        insertions[target, default: []].append(comment.line)
    }
    for target in insertions.keys.sorted(by: >) {
        lines.insert(contentsOf: insertions[target] ?? [], at: min(target, lines.count))
    }

    var preamble = annotations.preamble
    if title != annotations.preambleTitle {
        preamble = _settingPreambleKey(preamble, path: ["title"], jsonKey: nil, value: title)
    }
    if theme != annotations.preambleTheme {
        preamble = _settingPreambleKey(preamble, path: ["config", "theme"], jsonKey: "theme", value: theme)
    }
    if layout != annotations.preambleLayout {
        preamble = _settingPreambleKey(preamble, path: ["config", "layout"], jsonKey: "layout", value: layout)
    }
    return preamble + lines.joined(separator: "\n") + "\n"
}

// MARK: - In-place preamble edits

/// `preamble` with one setting changed and every other byte kept: the YAML
/// key at `path` (one or two levels) is replaced, inserted or removed;
/// failing a frontmatter block, a `%%{init}%%` directive that names
/// `jsonKey` has that value replaced; failing both, a frontmatter block is
/// added.
public func _settingPreambleKey(_ preamble: String, path: [String], jsonKey: String?, value: String?) -> String {
    var lines = preamble.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    if lines.last == "" { lines.removeLast() }
    let open = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "---" }
    let close = open.flatMap { o in lines[(o + 1)...].firstIndex { $0.trimmingCharacters(in: .whitespaces) == "---" } }

    func indent(_ line: String) -> Int { line.prefix(while: { $0 == " " || $0 == "\t" }).count }
    func keyOf(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let colon = trimmed.firstIndex(of: ":"), !trimmed.hasPrefix("#"), !trimmed.hasPrefix("-") else { return nil }
        return String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
    }
    func scalar(_ v: String) -> String { _yamlScalar(v) }

    if let open, let close {
        let body = (open + 1)..<close
        if path.count == 1 {
            if let at = body.first(where: { indent(lines[$0]) == 0 && keyOf(lines[$0]) == path[0] }) {
                if let value { lines[at] = "\(path[0]): \(scalar(value))" } else { lines.remove(at: at) }
            } else if let value {
                lines.insert("\(path[0]): \(scalar(value))", at: open + 1)
            }
        } else if let parent = body.first(where: { indent(lines[$0]) == 0 && keyOf(lines[$0]) == path[0] }) {
            var end = parent + 1
            while end < close, lines[end].trimmingCharacters(in: .whitespaces).isEmpty || indent(lines[end]) > 0 { end += 1 }
            let children = (parent + 1)..<end
            let childIndent = children.map { indent(lines[$0]) }.filter { $0 > 0 }.min() ?? 2
            let pad = String(repeating: " ", count: childIndent)
            if let at = children.first(where: { indent(lines[$0]) == childIndent && keyOf(lines[$0]) == path[1] }) {
                if let value { lines[at] = "\(pad)\(path[1]): \(scalar(value))" } else { lines.remove(at: at) }
            } else if let value {
                lines.insert("\(pad)\(path[1]): \(scalar(value))", at: parent + 1)
            }
        } else if let value {
            lines.insert(contentsOf: ["\(path[0]):", "  \(path[1]): \(scalar(value))"], at: close)
        }
        return lines.map { $0 + "\n" }.joined()
    }

    if let jsonKey, let value,
       let regex = try? NSRegularExpression(pattern: #"(["']\#(jsonKey)["']\s*:\s*["'])[^"']*(["'])"#),
       let lineIndex = lines.firstIndex(where: { $0.contains("%%{") && regex.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }) {
        let line = lines[lineIndex]
        let escaped = NSRegularExpression.escapedTemplate(for: value.replacingOccurrences(of: "\"", with: ""))
        lines[lineIndex] = regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "$1\(escaped)$2")
        return lines.map { $0 + "\n" }.joined()
    }

    guard let value else { return preamble }
    var block = ["---"]
    if path.count == 1 {
        block.append("\(path[0]): \(scalar(value))")
    } else {
        block += ["\(path[0]):", "  \(path[1]): \(scalar(value))"]
    }
    block.append("---")
    return block.map { $0 + "\n" }.joined() + preamble
}

/// `value` as a YAML scalar: plain when that is unambiguous, double-quoted
/// otherwise. `FrontmatterDocumentParser.flatten` and other YAML readers
/// read either form back as `value`.
public func _yamlScalar(_ value: String) -> String {
    let flat = value.replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
    let indicators: Set<Character> = ["\"", "'", "#", "&", "*", "!", "|", ">", "%", "@", "{", "}", "[", "]", ",", "?", ":", "`"]
    let plain = !flat.isEmpty
        && flat == flat.trimmingCharacters(in: .whitespaces)
        && !(flat.first.map { indicators.contains($0) } ?? true)
        && !(flat.first == "-" && !(flat.dropFirst().first?.isNumber ?? false))
        && !flat.contains(": ") && !flat.contains(" #") && !flat.contains("\t") && !flat.hasSuffix(":")
    if plain { return flat }
    let escaped = flat.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}
