import Foundation

// MARK: - ZenUML Parser

/// Parse a ZenUML diagram from raw source lines.
/// The source lines are the raw lines after frontmatter stripping and `zenuml` header removal.
/// IMPORTANT: ZenUML source MUST NOT be passed through `_mermaidSourceLines` — it is brace/newline/colon/semicolon sensitive.
///
/// This implementation provides a native Swift tokenizer + recursive-descent parser
/// following the ANTLR grammar as a specification.
///
/// - Parameters:
///   - lines: Raw source lines after frontmatter stripping and header removal
///   - frontmatter: Optional frontmatter with config overrides
/// - Returns: A parsed `ZenUMLDiagram`
public func parseZenUMLDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ZenUMLDiagram {
    var diagram = ZenUMLDiagram()

    // Apply frontmatter title if available
    if let fm = frontmatter, let fmTitle = fm.diagramTitle {
        diagram.title = fmTitle
    }

    // Strip the zenuml header line
    var bodyLines = lines
    if let firstNonEmpty = bodyLines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        let firstLine = bodyLines[firstNonEmpty].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if firstLine.hasPrefix("zenuml") {
            let stripped = bodyLines[firstNonEmpty]
                .replacingOccurrences(of: #"^\s*zenuml\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            if stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bodyLines.remove(at: firstNonEmpty)
            } else {
                bodyLines[firstNonEmpty] = stripped
            }
        }
    }

    let body = bodyLines.joined(separator: "\n")
    if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return diagram
    }

    let tokens = tokenizeZenUML(body)
    if tokens.isEmpty || (tokens.count == 1 && tokens[0].kind == .eof) {
        return diagram
    }

    let parser = ZenUMLRecursiveDescentParser(tokens: tokens)
    guard let ast = parser.parseProg() else {
        diagram.errors = parser.errors
        return diagram
    }

    // Semantic extraction passes on the AST
    diagram = extractSemantics(from: ast, errors: parser.errors)

    // Frontmatter title overrides inline title
    if let fm = frontmatter, let fmTitle = fm.diagramTitle, diagram.title == nil {
        diagram.title = fmTitle
    }

    return diagram
}

// MARK: - Tokenizer

public enum ZenUMLTokenKind: Sendable, Equatable {
    case id(String)
    case int(Int)
    case float(Double)
    case cstring(String)
    case ustring(String)
    case arrow          // ->
    case returnArrow    // -->
    case colon
    case semicolon
    case comma
    case assign
    case openParen
    case closeParen
    case openBrace
    case closeBrace
    case openBracket
    case closeBracket
    case doubleOpenAngle   // <<
    case doubleCloseAngle  // >>
    case dot
    case keyword(String)
    case annotation(String)  // @Identifier
    case annotationRet       // @Return / @return / @Reply / @reply
    case emojiShortcode(String)
    case color(String)
    case newline
    case comment(String)
    case divider(String)
    case eventPayload(String)
    case titleText(String)     // title content after 'title' keyword
    case eof
    case other(Character)
}

public struct ZenUMLToken: Sendable {
    public var kind: ZenUMLTokenKind
    public var line: Int
    public var column: Int

    public init(kind: ZenUMLTokenKind, line: Int, column: Int) {
        self.kind = kind
        self.line = line
        self.column = column
    }
}

/// Tokenize ZenUML source into tokens.
/// Implements a native Swift tokenizer following the ANTLR grammar as specification.
private func tokenizeZenUML(_ source: String) -> [ZenUMLToken] {
    var tokens: [ZenUMLToken] = []
    var pos = source.startIndex
    var line = 0
    var column = 0
    let end = source.endIndex

    var inEventMode = false

    while pos < end {
        let remaining = source[pos...]
        let ch = remaining.first!

        // EVENT mode: after colon, rest of line is event payload
        if inEventMode {
            if ch == "\n" || ch == "\r" {
                inEventMode = false
                if ch == "\n" {
                    tokens.append(ZenUMLToken(kind: .newline, line: line, column: column))
                    pos = source.index(after: pos)
                    line += 1
                    column = 0
                    continue
                }
                if ch == "\r" {
                    pos = source.index(after: pos)
                    if pos < end && source[pos] == "\n" { pos = source.index(after: pos) }
                    line += 1
                    column = 0
                    continue
                }
            }
            var payload = ""
            var p = pos
            while p < end && source[p] != "\n" && source[p] != "\r" {
                payload.append(source[p])
                p = source.index(after: p)
            }
            if !payload.isEmpty {
                tokens.append(ZenUMLToken(kind: .eventPayload(payload), line: line, column: column))
                column += payload.count
            }
            pos = p
            continue
        }

        // Whitespace
        if ch == " " || ch == "\t" {
            pos = source.index(after: pos)
            column += 1
            continue
        }

        // Newline
        if ch == "\n" {
            tokens.append(ZenUMLToken(kind: .newline, line: line, column: column))
            pos = source.index(after: pos)
            line += 1
            column = 0
            continue
        }

        // Carriage return
        if ch == "\r" {
            pos = source.index(after: pos)
            if pos < end && source[pos] == "\n" { pos = source.index(after: pos) }
            line += 1
            column = 0
            continue
        }

        // Comment
        if remaining.hasPrefix("//") {
            var comment = ""
            var p = source.index(pos, offsetBy: 2)
            while p < end && source[p] != "\n" && source[p] != "\r" {
                comment.append(source[p])
                p = source.index(after: p)
            }
            tokens.append(ZenUMLToken(kind: .comment(comment.trimmingCharacters(in: .whitespaces)), line: line, column: column))
            column += 2 + comment.count
            pos = p
            continue
        }

        // Divider (== at column 0)
        if column == 0 && remaining.hasPrefix("==") {
            var divider = ""
            var p = source.index(pos, offsetBy: 2)
            while p < end && source[p] != "\n" && source[p] != "\r" {
                divider.append(source[p])
                p = source.index(after: p)
            }
            tokens.append(ZenUMLToken(kind: .divider(divider.trimmingCharacters(in: .whitespaces)), line: line, column: column))
            column += 2 + divider.count
            pos = p
            continue
        }

        // Return arrow -->
        if remaining.hasPrefix("-->") {
            tokens.append(ZenUMLToken(kind: .returnArrow, line: line, column: column))
            pos = source.index(pos, offsetBy: 3)
            column += 3
            continue
        }

        // Arrow ->
        if remaining.hasPrefix("->") {
            tokens.append(ZenUMLToken(kind: .arrow, line: line, column: column))
            pos = source.index(pos, offsetBy: 2)
            column += 2
            continue
        }

        // Double open angle <<
        if remaining.hasPrefix("<<") {
            tokens.append(ZenUMLToken(kind: .doubleOpenAngle, line: line, column: column))
            pos = source.index(pos, offsetBy: 2)
            column += 2
            continue
        }

        // Double close angle >>
        if remaining.hasPrefix(">>") {
            tokens.append(ZenUMLToken(kind: .doubleCloseAngle, line: line, column: column))
            pos = source.index(pos, offsetBy: 2)
            column += 2
            continue
        }

        // Color
        if ch == "#" {
            var color = "#"
            var p = source.index(after: pos)
            while p < end && source[p].isHexDigit {
                color.append(source[p])
                p = source.index(after: p)
            }
            if color.count > 1 {
                tokens.append(ZenUMLToken(kind: .color(color), line: line, column: column))
                column += color.count
                pos = p
                continue
            }
        }

        // Emoji shortcode [shortcode]
        if ch == "[" {
            var p = source.index(after: pos)
            var content = ""
            var isEmoji = false
            while p < end && source[p] != "\n" && source[p] != "\r" {
                if source[p] == "]" {
                    isEmoji = true
                    p = source.index(after: p)
                    break
                }
                if source[p] == "[" { break }
                content.append(source[p])
                p = source.index(after: p)
            }
            if isEmoji && !content.isEmpty {
                tokens.append(ZenUMLToken(kind: .emojiShortcode(content), line: line, column: column))
                column += 2 + content.count
                pos = p
                continue
            }
            tokens.append(ZenUMLToken(kind: .openBracket, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        }

        if ch == "]" {
            tokens.append(ZenUMLToken(kind: .closeBracket, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        }

        // Single-character tokens
        switch ch {
        case ":":
            tokens.append(ZenUMLToken(kind: .colon, line: line, column: column))
            inEventMode = true
            pos = source.index(after: pos)
            column += 1
            continue
        case ";":
            tokens.append(ZenUMLToken(kind: .semicolon, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case ",":
            tokens.append(ZenUMLToken(kind: .comma, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case "=":
            tokens.append(ZenUMLToken(kind: .assign, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case "(":
            tokens.append(ZenUMLToken(kind: .openParen, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case ")":
            tokens.append(ZenUMLToken(kind: .closeParen, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case "{":
            tokens.append(ZenUMLToken(kind: .openBrace, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case "}":
            tokens.append(ZenUMLToken(kind: .closeBrace, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case ".":
            tokens.append(ZenUMLToken(kind: .dot, line: line, column: column))
            pos = source.index(after: pos)
            column += 1
            continue
        case "@":
            var p = source.index(after: pos)
            var name = ""
            while p < end && (source[p].isLetter || source[p].isNumber || source[p] == "_") {
                name.append(source[p])
                p = source.index(after: p)
            }
            let lower = name.lowercased()
            if lower == "return" || lower == "reply" {
                tokens.append(ZenUMLToken(kind: .annotationRet, line: line, column: column))
            } else if lower == "starter" {
                tokens.append(ZenUMLToken(kind: .keyword("starter"), line: line, column: column))
            } else {
                tokens.append(ZenUMLToken(kind: .annotation(name), line: line, column: column))
            }
            column += 1 + name.count
            pos = p
            continue
        case "\"":
            var p = source.index(after: pos)
            var str = ""
            var closed = false
            while p < end {
                if source[p] == "\"" {
                    let next = source.index(after: p)
                    if next < end && source[next] == "\"" {
                        str.append("\"")
                        p = source.index(after: next)
                        continue
                    }
                    closed = true
                    p = source.index(after: p)
                    break
                }
                if source[p] == "\n" || source[p] == "\r" { break }
                str.append(source[p])
                p = source.index(after: p)
            }
            if closed {
                tokens.append(ZenUMLToken(kind: .cstring(str), line: line, column: column))
            } else {
                tokens.append(ZenUMLToken(kind: .ustring(str), line: line, column: column))
            }
            column += 2 + str.count
            pos = p
            continue
        default:
            break
        }

        // Identifiers, keywords, numbers
        if ch.isLetter || ch == "_" || ch.unicodeScalars.first?.value ?? 0 > 127 {
            var p = pos
            var name = ""
            while p < end && (source[p].isLetter || source[p].isNumber || source[p] == "_" || (source[p].unicodeScalars.first?.value ?? 0) > 127) {
                name.append(source[p])
                p = source.index(after: p)
            }

            let lower = name.lowercased()
            switch lower {
            case "title":
                // Title: emit keyword, then consume rest of line as titleText
                tokens.append(ZenUMLToken(kind: .keyword("title"), line: line, column: column))
                column += name.count
                pos = p
                // Consume whitespace after 'title'
                while pos < end && (source[pos] == " " || source[pos] == "\t") {
                    pos = source.index(after: pos)
                    column += 1
                }
                // Read rest of line as title text
                var titleStr = ""
                var tp = pos
                while tp < end && source[tp] != "\n" && source[tp] != "\r" {
                    titleStr.append(source[tp])
                    tp = source.index(after: tp)
                }
                let trimmed = titleStr.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    tokens.append(ZenUMLToken(kind: .titleText(trimmed), line: line, column: column))
                    column += titleStr.count
                }
                pos = tp
                continue
            case "new", "return", "if", "else", "while", "for", "foreach", "foreach",
                 "loop", "par", "opt", "critical", "section", "frame", "ref", "as",
                 "try", "catch", "finally", "in", "true", "false", "nil", "null",
                 "group", "const", "readonly", "static", "await":
                tokens.append(ZenUMLToken(kind: .keyword(lower), line: line, column: column))
            default:
                tokens.append(ZenUMLToken(kind: .id(name), line: line, column: column))
            }
            column += name.count
            pos = p
            continue
        }

        // Numbers
        if ch.isNumber {
            var p = source.index(after: pos)
            var numStr = String(ch)
            var isFloat = false
            while p < end && source[p].isNumber {
                numStr.append(source[p])
                p = source.index(after: p)
            }
            if p < end && source[p] == "." {
                isFloat = true
                numStr.append(".")
                p = source.index(after: p)
                while p < end && source[p].isNumber {
                    numStr.append(source[p])
                    p = source.index(after: p)
                }
            }
            if isFloat {
                tokens.append(ZenUMLToken(kind: .float(Double(numStr) ?? 0), line: line, column: column))
            } else {
                tokens.append(ZenUMLToken(kind: .int(Int(numStr) ?? 0), line: line, column: column))
            }
            column += numStr.count
            pos = p
            continue
        }

        // Other characters (skip unrecognized)
        pos = source.index(after: pos)
        column += 1
    }

    tokens.append(ZenUMLToken(kind: .eof, line: line, column: column))
    return tokens
}

// MARK: - Recursive Descent Parser

private final class ZenUMLRecursiveDescentParser {
    let tokens: [ZenUMLToken]
    var pos: Int = 0
    var errors: [ZenUMLParseError] = []
    var participantOrder: [String] = []  // deterministic encounter order

    init(tokens: [ZenUMLToken]) {
        self.tokens = tokens
    }

    private var current: ZenUMLToken {
        pos < tokens.count ? tokens[pos] : tokens.last!
    }

    private func peek() -> ZenUMLTokenKind {
        current.kind
    }

    private func peekAhead(_ offset: Int) -> ZenUMLTokenKind {
        let idx = pos + offset
        guard idx < tokens.count else { return .eof }
        return tokens[idx].kind
    }

    @discardableResult
    private func advance() -> ZenUMLToken {
        let tok = current
        if pos < tokens.count { pos += 1 }
        return tok
    }

    // Collect comments since last non-comment token
    private func collectComments() -> String? {
        var comments: [String] = []
        let savedPos = pos
        var scanPos = savedPos
        // Scan backward for adjacent comments (they were skipped by skipWhitespaceAndComments)
        // Instead, track the last seen comment and return it
        // For now, comments are consumed by skipWhitespaceAndComments and lost.
        // We'll return nil and the caller can use `pendingComment` if we track it.
        return nil
    }

    /// Parse the full program: title? head? block? EOF
    func parseProg() -> ZenUMLASTNode? {
        var title: String? = nil
        var headNodes: [ZenUMLASTNode] = []
        var blockNodes: [ZenUMLASTNode]? = nil

        skipNewlinesAndComments()

        // Parse optional title
        if case .keyword(let kw) = peek(), kw == "title" {
            advance() // consume 'title'
            if case .titleText(let t) = peek() {
                title = t
                advance()
            } else if case .id(let t) = peek() {
                title = t
                advance()
            } else if case .cstring(let t) = peek() {
                title = t
                advance()
            }
        }

        skipNewlinesAndComments()

        // Parse head (groups and participants) — only consume things that are
        // definitely declarations, not message starts
        headNodes = parseHead()

        skipNewlinesAndComments()

        // Parse block (statements) if anything remains
        if case .eof = peek() {
            // Done
        } else {
            if let block = parseBlock(), case .block(let stmts) = block {
                blockNodes = stmts
            }
        }

        return .prog(title: title, head: headNodes.isEmpty ? nil : headNodes, block: blockNodes.map { .block(statements: $0) })
    }

    /// Parse head declarations: groups, participants, starters.
    /// MUST NOT consume message starts. An identifier is a participant ONLY if
    /// it stands alone (just an ID, possibly with annotation/emoji/color on the same logical line
    /// before newline) and is not followed by `.`, `->`, `:`, `(`, or `=`.
    private func parseHead() -> [ZenUMLASTNode] {
        var nodes: [ZenUMLASTNode] = []
        while pos < tokens.count {
            skipNewlinesAndComments()
            if case .eof = peek() { break }
            if case .closeBrace = peek() { break }

            // group keyword
            if case .keyword(let kw) = peek(), kw == "group" {
                if let g = parseGroup() { nodes.append(g); continue }
            }

            // starter keyword
            if case .keyword(let kw) = peek(), kw == "starter" {
                if let s = parseStarterExp() { nodes.append(s); continue }
            }

            // annotation-only participant (e.g. @Actor)
            if case .annotation = peek() {
                // Check if followed by an ID that could be a participant name
                // If followed by . or ->, it's a message annotation, break
                let next = peekAhead(1)
                if case .dot = next { break }
                if case .arrow = next { break }
                if case .returnArrow = next { break }
                if case .keyword = next { break }
                if let p = parseParticipant() { nodes.append(p); continue }
                break
            }

            // emoji-only start
            if case .emojiShortcode = peek() {
                let next = peekAhead(1)
                if case .dot = next { break }
                if case .arrow = next { break }
                if case .returnArrow = next { break }
                if let p = parseParticipant() { nodes.append(p); continue }
                break
            }

            // ID — careful: could be participant or message start
            if case .id = peek() {
                let next = peekAhead(1)
                // Message starts: ID followed by . -> --> : ( or =
                if case .dot = next { break }
                if case .arrow = next { break }
                if case .returnArrow = next { break }
                if case .colon = next { break }
                if case .openParen = next { break }
                if case .assign = next { break }
                // Could be participant: try parsing
                if let p = parseParticipant() {
                    nodes.append(p)
                    continue
                }
                break
            }

            // Keyword — message start, break out of head
            if case .keyword = peek() { break }

            // cstring/ustring — could be quoted participant name or message
            if case .cstring = peek() {
                let next = peekAhead(1)
                if case .dot = next { break }
                if case .arrow = next { break }
                if case .returnArrow = next { break }
                if case .colon = next { break }
                if let p = parseParticipant() { nodes.append(p); continue }
                break
            }

            // openBrace — anonymous block, break to block parsing
            if case .openBrace = peek() { break }

            // Anything else — break
            break
        }
        return nodes
    }

    private func parseGroup() -> ZenUMLASTNode? {
        guard case .keyword("group") = peek() else { return nil }
        advance()

        var id: String? = nil
        if case .cstring(let s) = peek() { id = s; advance() }
        else if case .id(let s) = peek() { id = s; advance() }

        var participants: [ZenUMLASTNode] = []
        if case .openBrace = peek() {
            advance()
            while pos < tokens.count {
                skipNewlinesAndComments()
                if case .closeBrace = peek() { advance(); break }
                if let p = parseParticipant() { participants.append(p) }
                else { break }
            }
        }

        return .group(id: id, participants: participants)
    }

    private func parseStarterExp() -> ZenUMLASTNode? {
        guard case .keyword("starter") = peek() else { return nil }
        advance()
        var content = "_STARTER_"
        if case .openParen = peek() {
            advance()
            if case .id(let s) = peek() { content = s; advance() }
            else if case .cstring(let s) = peek() { content = s; advance() }
            if case .closeParen = peek() { advance() }
        }
        return .starterExp(content: content)
    }

    private func parseParticipant() -> ZenUMLASTNode? {
        var type: String? = nil
        var stereotype: String? = nil
        var emoji: String? = nil
        var name: String = ""
        var width: Int? = nil
        var label: String? = nil
        var color: String? = nil

        // Optional annotation (type)
        if case .annotation(let t) = peek() {
            type = t
            advance()
        }

        // Optional stereotype <<name>>
        if case .doubleOpenAngle = peek() {
            advance() // <<
            if case .id(let s) = peek() { stereotype = s; advance() }
            else if case .cstring(let s) = peek() { stereotype = s; advance() }
            if case .doubleCloseAngle = peek() { advance() }  // >>
            else if case .id = peek() { advance() } // tolerate unclosed stereotype
        }

        // Optional emoji
        if case .emojiShortcode(let e) = peek() {
            emoji = e
            advance()
        }

        // Name (required)
        if case .id(let s) = peek() {
            name = s
            advance()
        } else if case .cstring(let s) = peek() {
            name = s
            advance()
        } else if type != nil || stereotype != nil || emoji != nil {
            // Annotation-only participant: use annotation name
            name = type ?? stereotype ?? emoji ?? ""
        } else {
            return nil
        }

        // Track encounter order
        if !name.isEmpty && !participantOrder.contains(name) {
            participantOrder.append(name)
        }

        // Optional width
        if case .int(let w) = peek() {
            width = w
            advance()
        }

        // Optional label (as ...)
        if case .keyword(let kw) = peek(), kw == "as" {
            advance()
            if case .id(let s) = peek() { label = s; advance() }
            else if case .cstring(let s) = peek() { label = s; advance() }
        }

        // Optional color
        if case .color(let c) = peek() {
            color = c
            advance()
        }

        return .participant(type: type, stereotype: stereotype, emoji: emoji, name: name, width: width, label: label, color: color)
    }

    private func parseBlock() -> ZenUMLASTNode? {
        var statements: [ZenUMLASTNode] = []
        while pos < tokens.count {
            skipNewlinesAndComments()
            if case .eof = peek() { break }
            if case .closeBrace = peek() { break }
            if let stmt = parseStatement() {
                statements.append(stmt)
            } else {
                // Skip unrecognized token
                advance()
            }
        }
        return .block(statements: statements)
    }

    private func parseStatement() -> ZenUMLASTNode? {
        skipNewlinesAndComments()

        switch peek() {
        case .keyword(let kw):
            switch kw {
            case "if": return parseAlt()
            case "while", "for", "foreach", "foreach", "loop": return parseLoop()
            case "par": return parsePar()
            case "opt": return parseOpt()
            case "critical": return parseCritical()
            case "section", "frame": return parseSection()
            case "ref": return parseRef()
            case "try": return parseTcf()
            case "return": return parseRet()
            case "new": return parseCreation()
            case "group", "starter", "title":
                // These shouldn't appear in block; skip
                advance()
                return nil
            default:
                break
            }
        case .annotationRet:
            return parseRet()
        case .id, .cstring, .ustring, .emojiShortcode, .annotation:
            return parseMessageOrCreation()
        case .divider:
            let tok = advance()
            if case .divider(let label) = tok.kind { return .divider(label: label) }
            return .divider(label: "")
        case .openBrace:
            advance()
            let block = parseBlock()
            if case .closeBrace = peek() { advance() }
            return .section(name: nil, block: block)
        case .returnArrow:
            // Bare return arrow from _STARTER_
            return parseRet()
        default:
            break
        }
        return nil
    }

    // MARK: - Fragment parsers (preserve conditions)

    private func parseAlt() -> ZenUMLASTNode? {
        guard case .keyword("if") = peek() else { return nil }
        advance()
        let condition = parseParExpr()
        var ifBlock: ZenUMLASTNode = .block(statements: [])
        if case .openBrace = peek() {
            advance()
            if let b = parseBlock() { ifBlock = b }
            if case .closeBrace = peek() { advance() }
        }
        var elseIfs: [ZenUMLASTNode] = []
        var elseBlock: ZenUMLASTNode? = nil
        while case .keyword(let kw) = peek(), kw == "else" {
            advance()
            skipNewlinesAndComments()
            if case .keyword(let kw2) = peek(), kw2 == "if" {
                advance()
                _ = parseParExpr() // condition consumed but stored in AST would need restructuring
                var block: ZenUMLASTNode = .block(statements: [])
                if case .openBrace = peek() { advance(); if let b = parseBlock() { block = b }; if case .closeBrace = peek() { advance() } }
                elseIfs.append(block)
            } else {
                var block: ZenUMLASTNode = .block(statements: [])
                if case .openBrace = peek() { advance(); if let b = parseBlock() { block = b }; if case .closeBrace = peek() { advance() } }
                elseBlock = block
                break
            }
        }
        return .alt(ifBlock: ifBlock, elseIfs: elseIfs, elseBlock: elseBlock)
    }

    private func parseLoop() -> ZenUMLASTNode? {
        guard case .keyword(let kw) = peek() else { return nil }
        advance()
        let condition = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() { advance(); block = parseBlock(); if case .closeBrace = peek() { advance() } }
        return .loop(keyword: kw, condition: condition, block: block)
    }

    private func parsePar() -> ZenUMLASTNode? {
        guard case .keyword("par") = peek() else { return nil }
        advance()
        let condition = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() { advance(); block = parseBlock(); if case .closeBrace = peek() { advance() } }
        return .par(condition: condition, block: block)
    }

    private func parseOpt() -> ZenUMLASTNode? {
        guard case .keyword("opt") = peek() else { return nil }
        advance()
        let condition = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() { advance(); block = parseBlock(); if case .closeBrace = peek() { advance() } }
        return .opt(condition: condition, block: block)
    }

    private func parseCritical() -> ZenUMLASTNode? {
        guard case .keyword("critical") = peek() else { return nil }
        advance()
        let condition = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() { advance(); block = parseBlock(); if case .closeBrace = peek() { advance() } }
        return .critical(condition: condition, block: block)
    }

    private func parseSection() -> ZenUMLASTNode? {
        guard case .keyword = peek() else { return nil }
        advance()
        var name: String? = nil
        if case .openParen = peek() {
            advance()
            if case .id(let s) = peek() { name = s; advance() }
            else if case .cstring(let s) = peek() { name = s; advance() }
            if case .closeParen = peek() { advance() }
        }
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() { advance(); block = parseBlock(); if case .closeBrace = peek() { advance() } }
        return .section(name: name, block: block)
    }

    private func parseRef() -> ZenUMLASTNode? {
        guard case .keyword("ref") = peek() else { return nil }
        advance()
        var names: [String] = []
        if case .openParen = peek() {
            advance()
            while pos < tokens.count {
                if case .id(let s) = peek() { names.append(s); advance() }
                else if case .cstring(let s) = peek() { names.append(s); advance() }
                else if case .comma = peek() { advance(); continue }
                else { break }
            }
            if case .closeParen = peek() { advance() }
        }
        if case .semicolon = peek() { advance() }
        return .ref(names: names)
    }

    private func parseTcf() -> ZenUMLASTNode? {
        guard case .keyword("try") = peek() else { return nil }
        advance()
        var tryBlock: ZenUMLASTNode = .block(statements: [])
        if case .openBrace = peek() { advance(); if let b = parseBlock() { tryBlock = b }; if case .closeBrace = peek() { advance() } }
        var catches: [ZenUMLASTNode] = []
        while case .keyword(let kw) = peek(), kw == "catch" {
            advance()
            if case .openParen = peek() { advance(); if case .id = peek() { advance() }; if case .closeParen = peek() { advance() } }
            var block: ZenUMLASTNode = .block(statements: [])
            if case .openBrace = peek() { advance(); if let b = parseBlock() { block = b }; if case .closeBrace = peek() { advance() } }
            catches.append(block)
        }
        var finallyBlock: ZenUMLASTNode? = nil
        if case .keyword(let kw) = peek(), kw == "finally" {
            advance()
            var block: ZenUMLASTNode = .block(statements: [])
            if case .openBrace = peek() { advance(); if let b = parseBlock() { block = b }; if case .closeBrace = peek() { advance() } }
            finallyBlock = block
        }
        return .tcf(tryBlock: tryBlock, catches: catches, finallyBlock: finallyBlock)
    }

    // MARK: - Return parsing

    private func parseRet() -> ZenUMLASTNode? {
        // `return expr` form
        if case .keyword("return") = peek() {
            advance()
            var value: String? = nil
            if case .id(let s) = peek() { value = s; advance() }
            else if case .cstring(let s) = peek() { value = s; advance() }
            else if case .int(let i) = peek() { value = String(i); advance() }
            if case .semicolon = peek() { advance() }
            return .ret(value: value, async: nil, returnArrow: nil)
        }
        // @return annotation — may be followed by async message or returnArrow on same/next line
        if case .annotationRet = peek() {
            advance()
            skipNewlinesAndComments()
            // Try async message first: A->B: content
            if let async = parseAsyncMessage() {
                return .ret(value: nil, async: async, returnArrow: nil)
            }
            // Try return arrow: A --> B: content
            if let from = parseFrom() {
                if case .returnArrow = peek() {
                    advance()
                    let to = parseTo()
                    var content: String? = nil
                    if case .colon = peek() { advance(); if case .eventPayload(let s) = peek() { content = s; advance() } }
                    return .ret(value: nil, async: nil, returnArrow: .returnArrowMessage(from: from, to: to, content: content))
                }
            }
            // Bare @return with nothing after
            return .ret(value: nil, async: nil, returnArrow: nil)
        }
        // returnArrowMessage: from --> to : content (no @return)
        if let from = parseFrom() {
            if case .returnArrow = peek() {
                advance()
                let to = parseTo()
                var content: String? = nil
                if case .colon = peek() { advance(); if case .eventPayload(let s) = peek() { content = s; advance() } }
                let arrow = ZenUMLASTNode.returnArrowMessage(from: from, to: to, content: content)
                return .ret(value: nil, async: nil, returnArrow: arrow)
            }
        }
        return nil
    }

    // MARK: - From/To parsing

    private func parseFrom() -> String? {
        var emoji: String? = nil
        if case .emojiShortcode(let e) = peek() { emoji = e; advance() }
        if case .id(let s) = peek() { advance(); return s }
        else if case .cstring(let s) = peek() { advance(); return s }
        return nil
    }

    private func parseTo() -> String {
        _ = parseFrom() // consume optional emoji + name
        // parseFrom already consumed; return empty if already consumed
        return ""  // handled differently now
    }

    // MARK: - Message / Creation parsing

    private func parseAsyncMessage() -> ZenUMLASTNode? {
        // Save position
        let savedPos = pos
        let from = parseFrom()
        if case .arrow = peek() {
            advance()
            let toPart = parseFrom() // reusing parseFrom for to
            let to = toPart ?? ""
            var content: String? = nil
            if case .colon = peek() { advance(); if case .eventPayload(let s) = peek() { content = s; advance() } }
            return .asyncMessage(from: from, to: to, content: content)
        }
        // Not an async message, backtrack
        pos = savedPos
        return nil
    }

    private func parseCreation() -> ZenUMLASTNode? {
        var assignee: String? = nil
        var creationType: String? = nil

        // Optional assignment: `ret = new B()`
        let savedPos = pos
        if case .id(let s) = peek() {
            if pos + 1 < tokens.count, case .assign = tokens[pos + 1].kind {
                assignee = s
                advance() // consume assignee
                advance() // consume =
            }
        }

        guard case .keyword("new") = peek() else {
            pos = savedPos
            return nil
        }
        advance() // 'new'

        guard case .id(let construct) = peek() else {
            return .creation(assignee: assignee, type: creationType, construct: "", params: nil, block: nil)
        }
        advance()

        var params: [String]? = nil
        if case .openParen = peek() {
            advance()
            var p: [String] = []
            while pos < tokens.count {
                if case .closeParen = peek() { advance(); break }
                if case .id(let s) = peek() { p.append(s); advance() }
                else if case .int(let i) = peek() { p.append(String(i)); advance() }
                else if case .cstring(let s) = peek() { p.append(s); advance() }
                else if case .comma = peek() { advance() }
                else { advance() }
            }
            if !p.isEmpty { params = p }
        }

        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        } else if case .semicolon = peek() {
            advance()
        }

        return .creation(assignee: assignee, type: creationType, construct: construct, params: params, block: block)
    }

    private func parseMessageOrCreation() -> ZenUMLASTNode? {
        // Try creation first (handles `new` keyword or `ret = new`)
        if let creation = parseCreation() { return creation }

        // Try message
        return parseMessage()
    }

    private func parseMessage() -> ZenUMLASTNode? {
        // Try async message first
        if let asyncMsg = parseAsyncMessage() {
            if case .newline = peek() { advance() }
            return asyncMsg
        }

        // Sync message or self-call
        var assignee: String? = nil
        var msgType: String? = nil
        var from: String? = nil
        var to: String = ""
        var signature: String = ""

        // Try assignment: `assignee =` or `type assignee =`
        let savedPos = pos
        if case .id(let s) = peek() {
            if pos + 1 < tokens.count, case .assign = tokens[pos + 1].kind {
                assignee = s; advance(); advance()
            } else if pos + 2 < tokens.count, case .id = tokens[pos + 1].kind, case .assign = tokens[pos + 2].kind {
                msgType = s; advance()
                if case .id(let s2) = peek() { assignee = s2; advance() }
                advance() // consume =
            } else if pos + 1 < tokens.count, case .arrow = tokens[pos + 1].kind {
                // from -> to
                from = s; advance(); advance() // consume -> 
                if case .id(let s2) = peek() { to = s2; advance() }
                else if case .cstring(let s2) = peek() { to = s2; advance() }
                if case .dot = peek() { advance() }
            } else if pos + 1 < tokens.count, case .dot = tokens[pos + 1].kind {
                // to.method()
                to = s; advance(); advance() // consume .
            } else if pos + 1 < tokens.count, case .returnArrow = tokens[pos + 1].kind {
                // Handled by parseRet, backtrack
                pos = savedPos
                return nil
            } else {
                // Could be a bare participant name in a participant context — skip
                // Actually, this could be a message to itself: to = s, with method next
                to = s; advance()
                if case .dot = peek() { advance() }
            }
        } else if case .cstring(let s) = peek() {
            to = s; advance()
            if case .dot = peek() { advance() }
        } else {
            return nil
        }

        // Parse method signature
        if case .id(let s) = peek() {
            signature = s
            advance()
            if case .openParen = peek() {
                signature += "()"
                advance()
                var depth = 1
                while depth > 0 && pos < tokens.count {
                    if case .eof = peek() { break }
                    if case .openParen = peek() { depth += 1 }
                    if case .closeParen = peek() { depth -= 1 }
                    if depth > 0 { advance() }
                }
                if case .closeParen = peek() { advance() }
            }
            // Chained calls
            while case .dot = peek() {
                advance()
                if case .id(let s2) = peek() {
                    signature += "." + s2
                    advance()
                    if case .openParen = peek() {
                        signature += "()"
                        advance()
                        var depth = 1
                        while depth > 0 && pos < tokens.count {
                            if case .eof = peek() { break }
                            if case .openParen = peek() { depth += 1 }
                            if case .closeParen = peek() { depth -= 1 }
                            if depth > 0 { advance() }
                        }
                        if case .closeParen = peek() { advance() }
                    }
                } else { break }
            }
        }

        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        } else if case .semicolon = peek() {
            advance()
        }

        if !signature.isEmpty || !to.isEmpty {
            return .message(assignee: assignee, type: msgType, from: from, to: to, signature: signature, block: block)
        }

        return nil
    }

    private func parseParExpr() -> String? {
        if case .openParen = peek() {
            advance()
            var cond = ""
            while pos < tokens.count {
                if case .closeParen = peek() { advance(); break }
                if case .id(let s) = peek() { cond += s + " "; advance() }
                else if case .int(let i) = peek() { cond += String(i) + " "; advance() }
                else if case .cstring(let s) = peek() { cond += s + " "; advance() }
                else if case .newline = peek() { advance() }
                else if case .eof = peek() { break }
                else { advance() }
            }
            let trimmed = cond.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func skipNewlinesAndComments() {
        while pos < tokens.count {
            switch peek() {
            case .newline, .comment:
                advance()
            default:
                return
            }
        }
    }
}

// MARK: - Raw AST (Layer 1)

public indirect enum ZenUMLASTNode: Sendable {
    case prog(title: String?, head: [ZenUMLASTNode]?, block: ZenUMLASTNode?)
    case participant(type: String?, stereotype: String?, emoji: String?, name: String, width: Int?, label: String?, color: String?)
    case group(id: String?, participants: [ZenUMLASTNode])
    case starterExp(content: String)
    case block(statements: [ZenUMLASTNode])
    case message(assignee: String?, type: String?, from: String?, to: String, signature: String, block: ZenUMLASTNode?)
    case asyncMessage(from: String?, to: String, content: String?)
    case ret(value: String?, async: ZenUMLASTNode?, returnArrow: ZenUMLASTNode?)
    case returnArrowMessage(from: String, to: String, content: String?)
    case creation(assignee: String?, type: String?, construct: String, params: [String]?, block: ZenUMLASTNode?)
    case alt(ifBlock: ZenUMLASTNode, elseIfs: [ZenUMLASTNode], elseBlock: ZenUMLASTNode?)
    case loop(keyword: String, condition: String?, block: ZenUMLASTNode?)
    case par(condition: String?, block: ZenUMLASTNode?)
    case opt(condition: String?, block: ZenUMLASTNode?)
    case critical(condition: String?, block: ZenUMLASTNode?)
    case section(name: String?, block: ZenUMLASTNode?)
    case ref(names: [String])
    case tcf(tryBlock: ZenUMLASTNode, catches: [ZenUMLASTNode], finallyBlock: ZenUMLASTNode?)
    case divider(label: String)
}

// MARK: - Semantic Extraction (Layer 1 → Layer 2)

private func extractSemantics(from ast: ZenUMLASTNode, errors: [ZenUMLParseError]) -> ZenUMLDiagram {
    var diagram = ZenUMLDiagram(errors: errors)
    var participantMap: [String: ZenUMLParticipant] = [:]
    var orderedParticipantKeys: [String] = []  // deterministic order

    func addParticipant(name: String, explicit: Bool, isStarter: Bool = false, type: String? = nil, stereotype: String? = nil, emoji: String? = nil, color: String? = nil, label: String? = nil, width: Int? = nil, groupId: String? = nil) {
        if participantMap[name] == nil {
            let p = ZenUMLParticipant(name: name, label: label, type: type, stereotype: stereotype, color: color, emoji: emoji, width: width, groupId: groupId, explicit: explicit, isStarter: isStarter)
            participantMap[name] = p
            orderedParticipantKeys.append(name)
        } else {
            var p = participantMap[name]!
            if explicit { p.explicit = true }
            if isStarter { p.isStarter = true }
            if let t = type { p.type = t }
            if let s = stereotype { p.stereotype = s }
            if let e = emoji { p.emoji = e }
            if let c = color { p.color = c }
            if let l = label { p.label = l }
            if let w = width { p.width = w }
            if let g = groupId { p.groupId = g }
            participantMap[name] = p
        }
    }

    switch ast {
    case .prog(let title, let head, let block):
        diagram.title = title

        // Process head
        if let headNodes = head {
            for node in headNodes {
                switch node {
                case .participant(let type, let stereotype, let emoji, let name, let width, let label, let color):
                    addParticipant(name: name, explicit: true, type: type, stereotype: stereotype, emoji: emoji, color: color, label: label, width: width)
                case .group(let id, let participants):
                    var groupNames: [String] = []
                    for pNode in participants {
                        if case .participant(let type, let stereotype, let emoji, let name, let width, let label, let color) = pNode {
                            addParticipant(name: name, explicit: true, type: type, stereotype: stereotype, emoji: emoji, color: color, label: label, width: width, groupId: id)
                            groupNames.append(name)
                        }
                    }
                    diagram.groups.append(ZenUMLGroup(id: id, participants: groupNames))
                case .starterExp(let content):
                    addParticipant(name: content, explicit: true, isStarter: true)
                default:
                    break
                }
            }
        }

        // Process block
        if case .block(let stmts) = block {
            diagram.statements = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedParticipantKeys)
        }
    default:
        break
    }

    // Build ordered participant list
    var participants: [ZenUMLParticipant] = []
    for key in orderedParticipantKeys {
        if let p = participantMap[key] { participants.append(p) }
    }
    diagram.participants = participants

    return diagram
}

private func extractStatements(from astNodes: [ZenUMLASTNode], participantMap: inout [String: ZenUMLParticipant], orderedKeys: inout [String]) -> [ZenUMLStatement] {
    var statements: [ZenUMLStatement] = []

    func ensureParticipant(_ name: String) {
        if participantMap[name] == nil {
            participantMap[name] = ZenUMLParticipant(name: name, explicit: false)
            orderedKeys.append(name)
        }
    }

    func starterName() -> String {
        let s = "_STARTER_"
        ensureParticipant(s)
        if var p = participantMap[s] { p.isStarter = true; participantMap[s] = p }
        return s
    }

    for node in astNodes {
        switch node {
        case .message(let assignee, _, let from, let to, let signature, let block):
            let resolvedFrom = from ?? starterName()
            let resolvedTo = to.isEmpty ? resolvedFrom : to
            ensureParticipant(resolvedFrom)
            ensureParticipant(resolvedTo)
            var inner: [ZenUMLStatement]? = nil
            if case .block(let innerStmts) = block {
                inner = extractStatements(from: innerStmts, participantMap: &participantMap, orderedKeys: &orderedKeys)
            }
            statements.append(.message(from: resolvedFrom, to: resolvedTo, signature: signature, type: .sync, block: inner, comment: nil))

        case .asyncMessage(let from, let to, let content):
            let resolvedFrom = from ?? starterName()
            let resolvedTo = to.isEmpty ? resolvedFrom : to
            ensureParticipant(resolvedFrom)
            ensureParticipant(resolvedTo)
            statements.append(.asyncMessage(from: resolvedFrom, to: resolvedTo, content: content, comment: nil))

        case .creation(let assignee, let type, let construct, let params, let block):
            let targetName = assignee ?? construct
            ensureParticipant(targetName)
            var inner: [ZenUMLStatement]? = nil
            if case .block(let innerStmts) = block {
                inner = extractStatements(from: innerStmts, participantMap: &participantMap, orderedKeys: &orderedKeys)
            }
            statements.append(.creation(assignee: assignee, type: type, construct: construct, to: targetName, params: params, block: inner, comment: nil))

        case .ret(let value, _, let returnArrow):
            if let arrow = returnArrow, case .returnArrowMessage(let from, let to, let content) = arrow {
                ensureParticipant(from); ensureParticipant(to)
                statements.append(.return(from: from, to: to, value: content, comment: nil))
            } else if let v = value {
                let s = starterName()
                statements.append(.return(from: s, to: s, value: v, comment: nil))
            }

        case .alt(let ifBlock, let elseIfs, let elseBlock):
            var sections: [ZenUMLFragmentSection] = []
            if case .block(let stmts) = ifBlock {
                sections.append(ZenUMLFragmentSection(label: "if", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
            }
            for elifNode in elseIfs {
                if case .block(let stmts) = elifNode {
                    sections.append(ZenUMLFragmentSection(label: "else if", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
                }
            }
            if let elseNode = elseBlock, case .block(let stmts) = elseNode {
                sections.append(ZenUMLFragmentSection(label: "else", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
            }
            statements.append(.fragment(kind: .alt, condition: nil, sections: sections))

        case .loop(let keyword, let condition, let block):
            var inner: [ZenUMLStatement] = []
            if case .block(let stmts) = block { inner = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys) }
            statements.append(.fragment(kind: .loop, condition: condition, sections: [ZenUMLFragmentSection(label: keyword, statements: inner)]))

        case .par(let condition, let block):
            var inner: [ZenUMLStatement] = []
            if case .block(let stmts) = block { inner = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys) }
            statements.append(.fragment(kind: .par, condition: condition, sections: [ZenUMLFragmentSection(label: "par", statements: inner)]))

        case .opt(let condition, let block):
            var inner: [ZenUMLStatement] = []
            if case .block(let stmts) = block { inner = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys) }
            statements.append(.fragment(kind: .opt, condition: condition, sections: [ZenUMLFragmentSection(label: "opt", statements: inner)]))

        case .critical(let condition, let block):
            var inner: [ZenUMLStatement] = []
            if case .block(let stmts) = block { inner = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys) }
            statements.append(.fragment(kind: .critical, condition: condition, sections: [ZenUMLFragmentSection(label: "critical", statements: inner)]))

        case .section(let name, let block):
            var inner: [ZenUMLStatement] = []
            if case .block(let stmts) = block { inner = extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys) }
            statements.append(.fragment(kind: .section, condition: nil, sections: [ZenUMLFragmentSection(label: name ?? "", statements: inner)]))

        case .ref(let names):
            statements.append(.fragment(kind: .ref, condition: nil, sections: [ZenUMLFragmentSection(label: names.joined(separator: ", "), statements: [])]))

        case .tcf(let tryBlock, let catches, let finallyBlock):
            var sections: [ZenUMLFragmentSection] = []
            if case .block(let stmts) = tryBlock {
                sections.append(ZenUMLFragmentSection(label: "try", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
            }
            for catchNode in catches {
                if case .block(let stmts) = catchNode {
                    sections.append(ZenUMLFragmentSection(label: "catch", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
                }
            }
            if let finallyNode = finallyBlock, case .block(let stmts) = finallyNode {
                sections.append(ZenUMLFragmentSection(label: "finally", statements: extractStatements(from: stmts, participantMap: &participantMap, orderedKeys: &orderedKeys)))
            }
            statements.append(.fragment(kind: .tcf, condition: nil, sections: sections))

        case .divider(let label):
            statements.append(.divider(label: label))

        case .block(let inner):
            statements.append(contentsOf: extractStatements(from: inner, participantMap: &participantMap, orderedKeys: &orderedKeys))

        default:
            break
        }
    }

    return statements
}
