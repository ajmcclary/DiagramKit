import Foundation

// MARK: - ZenUML Parser

/// Parse a ZenUML diagram from raw source lines.
/// The source lines are the raw lines after frontmatter stripping and `zenuml` header removal.
/// IMPORTANT: ZenUML source MUST NOT be passed through `_mermaidSourceLines` — it is brace/newline/colon/semicolon sensitive.
///
/// This implementation provides a skeleton parser that handles basic ZenUML syntax.
/// Full grammar parity with the ANTLR-based ZenUML parser is the long-term goal.
///
/// - Parameters:
///   - lines: Raw source lines after frontmatter stripping and header removal
///   - frontmatter: Optional frontmatter with config overrides
/// - Returns: A parsed `ZenUMLDiagram`
public func parseZenUMLDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ZenUMLDiagram {
    var diagram = ZenUMLDiagram()

    // Apply frontmatter if available
    if let fm = frontmatter {
        if diagram.title == nil, let fmTitle = fm.diagramTitle {
            diagram.title = fmTitle
        }
    }

    // Find the header line and strip it
    var bodyLines = lines
    if let firstNonEmpty = bodyLines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        let firstLine = bodyLines[firstNonEmpty].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if firstLine.hasPrefix("zenuml") {
            // Strip the zenuml header prefix but keep the rest of the line
            let stripped = bodyLines[firstNonEmpty]
                .replacingOccurrences(of: #"^\s*zenuml\s*"#, with: "", options: [.regularExpression, .caseInsensitive])
            if stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bodyLines.remove(at: firstNonEmpty)
            } else {
                bodyLines[firstNonEmpty] = stripped
            }
        }
    }

    // Parse the body using the tokenizer + recursive-descent parser
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

    // Apply frontmatter title override
    if let fm = frontmatter {
        if diagram.title == nil, let fmTitle = fm.diagramTitle {
            diagram.title = fmTitle
        }
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
/// This implements a native Swift tokenizer following the ANTLR grammar as specification.
private func tokenizeZenUML(_ source: String) -> [ZenUMLToken] {
    var tokens: [ZenUMLToken] = []
    var pos = source.startIndex
    var line = 0
    var column = 0
    let end = source.endIndex

    // Mode tracking
    var inEventMode = false
    var inTitleMode = false

    while pos < end {
        let remaining = source[pos...]
        let ch = remaining.first!

        // Handle mode-specific parsing
        if inEventMode {
            if ch == "\n" {
                inEventMode = false
                tokens.append(ZenUMLToken(kind: .newline, line: line, column: column))
                pos = source.index(after: pos)
                line += 1
                column = 0
                continue
            }
            // Read event payload until newline
            var payload = ""
            var p = pos
            while p < end && source[p] != "\n" && source[p] != "\r" {
                payload.append(source[p])
                p = source.index(after: p)
            }
            tokens.append(ZenUMLToken(kind: .eventPayload(payload), line: line, column: column))
            column += payload.count
            pos = p
            continue
        }

        if inTitleMode {
            if ch == "\n" {
                inTitleMode = false
                tokens.append(ZenUMLToken(kind: .newline, line: line, column: column))
                pos = source.index(after: pos)
                line += 1
                column = 0
                continue
            }
            var titleContent = ""
            var p = pos
            while p < end && source[p] != "\n" && source[p] != "\r" {
                titleContent.append(source[p])
                p = source.index(after: p)
            }
            // title content gets absorbed, we don't emit it as tokens for now
            column += titleContent.count
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
            if pos < end && source[pos] == "\n" {
                pos = source.index(after: pos)
            }
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
            // We parse this as part of stereotype handling inline
            pos = source.index(pos, offsetBy: 2)
            column += 2
            continue
        }

        // Double close angle >>
        if remaining.hasPrefix(">>") {
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
            // Look ahead to see if this is an emoji shortcode
            var p = source.index(after: pos)
            var content = ""
            var isEmoji = false
            while p < end && source[p] != "\n" && source[p] != "\r" {
                if source[p] == "]" {
                    isEmoji = true
                    p = source.index(after: p)
                    break
                }
                if source[p] == "[" {
                    break
                }
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

        // Basic single-character tokens
        switch ch {
        case ":":
            tokens.append(ZenUMLToken(kind: .colon, line: line, column: column))
            inEventMode = true  // Enter EVENT mode after colon
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
            // Check for == (equality)
            var p = source.index(after: pos)
            if p < end && source[p] == "=" {
                // Emit as assign for now, divider is handled above at column 0
                tokens.append(ZenUMLToken(kind: .assign, line: line, column: column))
                pos = p
                pos = source.index(after: pos)
                column += 2
                continue
            }
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
            // Annotation: @Identifier or @Return/@return/@Reply/@reply
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
            // String literal
            var p = source.index(after: pos)
            var str = ""
            var closed = false
            while p < end {
                if source[p] == "\"" {
                    // Check for escaped ""
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
                if source[p] == "\n" || source[p] == "\r" {
                    break
                }
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

            // Check keywords
            let lower = name.lowercased()
            switch lower {
            case "title":
                // Check if title should enter TITLE_MODE (must be at beginning)
                if column == 0 || (tokens.allSatisfy({ t in
                    if case .newline = t.kind { return true }
                    if case .comment = t.kind { return true }
                    return false
                })) {
                    inTitleMode = true
                }
                tokens.append(ZenUMLToken(kind: .keyword("title"), line: line, column: column))
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

        // Other characters
        tokens.append(ZenUMLToken(kind: .other(ch), line: line, column: column))
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

    init(tokens: [ZenUMLToken]) {
        self.tokens = tokens
    }

    private var current: ZenUMLToken {
        pos < tokens.count ? tokens[pos] : tokens.last!
    }

    private func peek() -> ZenUMLTokenKind {
        current.kind
    }

    @discardableResult
    private func advance() -> ZenUMLToken {
        let tok = current
        if pos < tokens.count { pos += 1 }
        return tok
    }

    private func match(_ kind: ZenUMLTokenKind) -> Bool {
        // Simple structural matching
        switch (peek(), kind) {
        case (.colon, .colon), (.semicolon, .semicolon), (.comma, .comma),
             (.assign, .assign), (.dot, .dot),
             (.openParen, .openParen), (.closeParen, .closeParen),
             (.openBrace, .openBrace), (.closeBrace, .closeBrace),
             (.openBracket, .openBracket), (.closeBracket, .closeBracket),
             (.arrow, .arrow), (.returnArrow, .returnArrow),
             (.newline, .newline), (.eof, .eof):
            return true
        case (.keyword, .keyword):
            return true
        case (.id, .id), (.int, .int), (.float, .float),
             (.cstring, .cstring), (.ustring, .ustring):
            return true
        case (.annotation, .annotation), (.annotationRet, .annotationRet):
            return true
        case (.emojiShortcode, .emojiShortcode), (.color, .color):
            return true
        case (.divider, .divider), (.eventPayload, .eventPayload):
            return true
        case (.comment, .comment):
            return true
        default:
            return false
        }
    }

    @discardableResult
    private func expect(_ kind: ZenUMLTokenKind) -> ZenUMLToken? {
        if match(kind) {
            return advance()
        }
        let tok = current
        errors.append(ZenUMLParseError(
            line: tok.line,
            column: tok.column,
            message: "Expected token kind but found \(tok.kind)"
        ))
        return nil
    }

    /// Parse the full program: title? head? block? EOF
    func parseProg() -> ZenUMLASTNode? {
        var title: String? = nil
        var headStatements: [ZenUMLASTNode] = []
        var blockStatements: [ZenUMLASTNode]? = nil

        // Skip leading newlines and comments
        skipWhitespaceAndComments()

        // Parse optional title
        if case .keyword(let kw) = peek(), kw == "title" {
            advance() // consume 'title'
            // Title content is in TITLE_MODE; we look at the next raw token or parse the rest of the line
            title = parseTitleContent()
        }

        skipWhitespaceAndComments()

        // Parse head (groups and participants) until we hit a non-head construct
        headStatements = parseHead()

        skipWhitespaceAndComments()

        // Parse block if present
        if case .eof = peek() {
            // Done
        } else {
            let blockResult = parseBlock()
            if case .block(let stmts) = blockResult {
                blockStatements = stmts
            }
        }

        return .prog(title: title, head: headStatements.isEmpty ? nil : headStatements, block: blockStatements.map { .block(statements: $0) })
    }

    private func parseTitleContent() -> String? {
        var content = ""
        while case .eof = peek() {} // placeholder
        loop: while pos < tokens.count {
            switch peek() {
            case .newline, .eof:
                break loop
            case .keyword(let kw):
                // keywords might terminate title
                if kw == "title" { break loop }
                content += kw + " "
                advance()
            case .id(let s):
                content += s + " "
                advance()
            case .cstring(let s):
                content += s + " "
                advance()
            default:
                advance()
            }
        }
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseHead() -> [ZenUMLASTNode] {
        var nodes: [ZenUMLASTNode] = []
        while pos < tokens.count {
            skipWhitespaceAndComments()
            if case .eof = peek() { break }
            if case .closeBrace = peek() { break }

            // Try to parse participant or group
            if case .keyword(let kw) = peek(), kw == "group" {
                if let g = parseGroup() { nodes.append(g) }
            } else if case .annotation = peek() {
                if let p = parseParticipant() { nodes.append(p) }
            } else if case .id = peek() {
                if let p = parseParticipant() { nodes.append(p) }
            } else if case .keyword(let kw) = peek(), kw == "starter" {
                if let s = parseStarterExp() { nodes.append(s) }
            } else if case .emojiShortcode = peek() {
                if let p = parseParticipant() { nodes.append(p) }
            } else if case .keyword = peek() {
                // A keyword might start a statement — break out of head
                break
            } else if case .openBrace = peek() {
                break
            } else {
                break
            }
        }
        return nodes
    }

    private func parseGroup() -> ZenUMLASTNode? {
        guard case .keyword("group") = peek() else { return nil }
        advance() // 'group'

        var id: String? = nil
        if case .cstring(let s) = peek() {
            id = s
            advance()
        } else if case .id(let s) = peek() {
            id = s
            advance()
        }

        var participants: [ZenUMLASTNode] = []
        if case .openBrace = peek() {
            advance()
            while pos < tokens.count {
                skipWhitespaceAndComments()
                if case .closeBrace = peek() {
                    advance()
                    break
                }
                if let p = parseParticipant() {
                    participants.append(p)
                } else {
                    break
                }
            }
        }

        return .group(id: id, participants: participants)
    }

    private func parseStarterExp() -> ZenUMLASTNode? {
        guard case .keyword("starter") = peek() else { return nil }
        advance() // 'starter'
        var content = "starter"
        if case .openParen = peek() {
            advance()
            if case .id(let s) = peek() {
                content = s
                advance()
            }
            if case .closeParen = peek() {
                advance()
            }
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

        // Optional stereotype <<...>>
        // (handled inline in tokenizer as << and >> for now, skip if present)

        // Optional emoji
        if case .emojiShortcode(let e) = peek() {
            emoji = e
            advance()
        }

        // Name
        if case .id(let s) = peek() {
            name = s
            advance()
        } else if case .cstring(let s) = peek() {
            name = s
            advance()
        } else {
            return nil
        }

        // Optional width
        if case .int(let w) = peek() {
            width = w
            advance()
        }

        // Optional label (as ...)
        if case .keyword(let kw) = peek(), kw == "as" {
            advance()
            if case .id(let s) = peek() {
                label = s
                advance()
            } else if case .cstring(let s) = peek() {
                label = s
                advance()
            }
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
            skipWhitespaceAndComments()
            if case .eof = peek() { break }
            if case .closeBrace = peek() { break }
            if let stmt = parseStatement() {
                statements.append(stmt)
            } else {
                break
            }
        }
        return .block(statements: statements)
    }

    private func parseStatement() -> ZenUMLASTNode? {
        skipWhitespaceAndComments()

        switch peek() {
        case .keyword(let kw):
            switch kw {
            case "if":
                return parseAlt()
            case "while", "for", "foreach", "foreach", "loop":
                return parseLoop()
            case "par":
                return parsePar()
            case "opt":
                return parseOpt()
            case "critical":
                return parseCritical()
            case "section", "frame":
                return parseSection()
            case "ref":
                return parseRef()
            case "try":
                return parseTcf()
            case "return":
                return parseRet()
            case "new":
                return parseCreation()
            default:
                break
            }
        case .annotationRet:
            return parseRet()
        case .id, .cstring, .ustring, .emojiShortcode, .annotation:
            // Could be message, creation, or async message
            return parseMessageOrCreation()
        case .divider:
            let tok = advance()
            if case .divider(let label) = tok.kind {
                return .divider(label: label)
            }
            return .divider(label: "")
        case .openBrace:
            // Anonymous block (section tolerance)
            advance()
            let block = parseBlock()
            if case .closeBrace = peek() { advance() }
            return .section(name: nil, block: block)
        default:
            break
        }
        return nil
    }

    private func parseAlt() -> ZenUMLASTNode? {
        guard case .keyword("if") = peek() else { return nil }
        advance()

        // Condition
        _ = parseParExpr()

        // if block
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
            if case .keyword(let kw2) = peek(), kw2 == "if" {
                advance()
                _ = parseParExpr()
                var block: ZenUMLASTNode = .block(statements: [])
                if case .openBrace = peek() {
                    advance()
                    if let b = parseBlock() { block = b }
                    if case .closeBrace = peek() { advance() }
                }
                elseIfs.append(block)
            } else {
                var block: ZenUMLASTNode = .block(statements: [])
                if case .openBrace = peek() {
                    advance()
                    if let b = parseBlock() { block = b }
                    if case .closeBrace = peek() { advance() }
                }
                elseBlock = block
                break
            }
        }

        return .alt(ifBlock: ifBlock, elseIfs: elseIfs, elseBlock: elseBlock)
    }

    private func parseLoop() -> ZenUMLASTNode? {
        guard case .keyword(let kw) = peek() else { return nil }
        advance()
        _ = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        }
        return .loop(keyword: kw, condition: nil, block: block)
    }

    private func parsePar() -> ZenUMLASTNode? {
        guard case .keyword("par") = peek() else { return nil }
        advance()
        _ = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        }
        return .par(condition: nil, block: block)
    }

    private func parseOpt() -> ZenUMLASTNode? {
        guard case .keyword("opt") = peek() else { return nil }
        advance()
        _ = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        }
        return .opt(condition: nil, block: block)
    }

    private func parseCritical() -> ZenUMLASTNode? {
        guard case .keyword("critical") = peek() else { return nil }
        advance()
        _ = parseParExpr()
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        }
        return .critical(condition: nil, block: block)
    }

    private func parseSection() -> ZenUMLASTNode? {
        guard case .keyword = peek() else { return nil }
        advance()
        var name: String? = nil
        if case .openParen = peek() {
            advance()
            if case .id(let s) = peek() {
                name = s
                advance()
            } else if case .cstring(let s) = peek() {
                name = s
                advance()
            }
            if case .closeParen = peek() { advance() }
        }
        var block: ZenUMLASTNode? = nil
        if case .openBrace = peek() {
            advance()
            block = parseBlock()
            if case .closeBrace = peek() { advance() }
        }
        return .section(name: name, block: block)
    }

    private func parseRef() -> ZenUMLASTNode? {
        guard case .keyword("ref") = peek() else { return nil }
        advance()
        var names: [String] = []
        if case .openParen = peek() {
            advance()
            while pos < tokens.count {
                if case .id(let s) = peek() {
                    names.append(s)
                    advance()
                } else if case .cstring(let s) = peek() {
                    names.append(s)
                    advance()
                } else {
                    break
                }
                if case .comma = peek() { advance() }
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
        if case .openBrace = peek() {
            advance()
            if let b = parseBlock() { tryBlock = b }
            if case .closeBrace = peek() { advance() }
        }

        var catches: [ZenUMLASTNode] = []
        while case .keyword(let kw) = peek(), kw == "catch" {
            advance()
            // Optional exception variable
            if case .openParen = peek() {
                advance()
                if case .id = peek() { advance() }
                if case .closeParen = peek() { advance() }
            }
            var block: ZenUMLASTNode = .block(statements: [])
            if case .openBrace = peek() {
                advance()
                if let b = parseBlock() { block = b }
                if case .closeBrace = peek() { advance() }
            }
            catches.append(block)
        }

        var finallyBlock: ZenUMLASTNode? = nil
        if case .keyword(let kw) = peek(), kw == "finally" {
            advance()
            var block: ZenUMLASTNode = .block(statements: [])
            if case .openBrace = peek() {
                advance()
                if let b = parseBlock() { block = b }
                if case .closeBrace = peek() { advance() }
            }
            finallyBlock = block
        }

        return .tcf(tryBlock: tryBlock, catches: catches, finallyBlock: finallyBlock)
    }

    private func parseRet() -> ZenUMLASTNode? {
        if case .keyword("return") = peek() {
            advance()
            var value: String? = nil
            if case .id(let s) = peek() {
                value = s
                advance()
            } else if case .cstring(let s) = peek() {
                value = s
                advance()
            }
            if case .semicolon = peek() { advance() }
            return .ret(value: value, async: nil, returnArrow: nil)
        }
        if case .annotationRet = peek() {
            advance()
            if let async = parseAsyncMessage() {
                return .ret(value: nil, async: async, returnArrow: nil)
            }
            return .ret(value: nil, async: nil, returnArrow: nil)
        }
        // returnAsyncMessage: from RETURN_ARROW to COL content?
        if let from = parseFrom() {
            if case .returnArrow = peek() {
                advance()
                let to = parseTo()
                var content: String? = nil
                if case .colon = peek() {
                    advance()
                    if case .eventPayload(let s) = peek() {
                        content = s
                        advance()
                    }
                }
                let arrow = ZenUMLASTNode.returnArrowMessage(from: from, to: to, content: content)
                return .ret(value: nil, async: nil, returnArrow: arrow)
            }
        }
        return nil
    }

    private func parseFrom() -> String? {
        var emoji: String? = nil
        if case .emojiShortcode(let e) = peek() {
            emoji = e
            advance()
        }
        if case .id(let s) = peek() {
            advance()
            return s
        } else if case .cstring(let s) = peek() {
            advance()
            return s
        }
        return nil
    }

    private func parseTo() -> String {
        var emoji: String? = nil
        if case .emojiShortcode(let e) = peek() {
            emoji = e
            advance()
        }
        if case .id(let s) = peek() {
            advance()
            return s
        } else if case .cstring(let s) = peek() {
            advance()
            return s
        }
        return ""
    }

    private func parseAsyncMessage() -> ZenUMLASTNode? {
        let from = parseFrom()
        if case .arrow = peek() {
            advance()
            let to = parseTo()
            var content: String? = nil
            if case .colon = peek() {
                advance()
                if case .eventPayload(let s) = peek() {
                    content = s
                    advance()
                }
            }
            return .asyncMessage(from: from, to: to, content: content)
        }
        return nil
    }

    private func parseCreation() -> ZenUMLASTNode? {
        var assignee: String? = nil
        var type: String? = nil

        // Optional assignment
        if case .id(let s) = peek() {
            // Look ahead for assign
            if pos + 1 < tokens.count {
                let next = tokens[pos + 1]
                if case .assign = next.kind {
                    assignee = s
                    advance() // consume assignee
                    advance() // consume =
                }
            }
        }

        guard case .keyword("new") = peek() else {
            if assignee != nil { return nil }
            // Might be a message, not a creation
            return nil
        }
        advance() // 'new'

        guard case .id(let construct) = peek() else {
            return .creation(assignee: assignee, type: type, construct: "", params: nil, block: nil)
        }
        advance()

        var params: [String]? = nil
        if case .openParen = peek() {
            advance()
            var p: [String] = []
            while pos < tokens.count {
                if case .closeParen = peek() { advance(); break }
                if case .id(let s) = peek() {
                    p.append(s)
                    advance()
                } else if case .int(let i) = peek() {
                    p.append(String(i))
                    advance()
                } else if case .cstring(let s) = peek() {
                    p.append(s)
                    advance()
                } else {
                    advance()
                }
                if case .comma = peek() { advance() }
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

        return .creation(assignee: assignee, type: type, construct: construct, params: params, block: block)
    }

    private func parseMessageOrCreation() -> ZenUMLASTNode? {
        // Check for creation first
        if case .keyword("new") = peek() {
            return parseCreation()
        }

        // Save position for backtracking
        let savedPos = pos

        // Try creation with assignment
        if let creation = parseCreation() {
            return creation
        }
        pos = savedPos

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
        // Parse messageBody
        var assignee: String? = nil
        var type: String? = nil
        var from: String? = nil
        var to: String = ""
        var signature: String = ""

        // Try assignment
        let savedPos = pos
        if case .id(let s) = peek() {
            if pos + 1 < tokens.count, case .assign = tokens[pos + 1].kind {
                assignee = s
                advance()
                advance()
            } else if pos + 1 < tokens.count, case .id = tokens[pos + 1].kind {
                // type assignee =
                type = s
                advance()
                if case .id(let s2) = peek() {
                    assignee = s2
                    advance()
                }
                if case .assign = peek() { advance() }
            }
        }

        // Parse fromTo
        if case .id(let s) = peek() {
            // Check if followed by arrow
            if pos + 1 < tokens.count, case .arrow = tokens[pos + 1].kind {
                from = s
                advance()
                advance() // ->
                if case .id(let s2) = peek() {
                    to = s2
                    advance()
                }
                if case .dot = peek() { advance() }
            } else {
                // Could be to or func
                to = s
                advance()
                if case .dot = peek() { advance() }
            }
        } else if case .cstring(let s) = peek() {
            to = s
            advance()
            if case .dot = peek() { advance() }
        }

        // Parse func
        if case .id(let s) = peek() {
            signature = s
            advance()

            // Method invocation
            if case .openParen = peek() {
                signature += "()"
                advance()
                // Skip parameters
                var depth = 1
                while depth > 0 && pos < tokens.count {
                    if case .openParen = peek() { depth += 1 }
                    if case .closeParen = peek() { depth -= 1 }
                    if depth > 0 { advance() }
                }
                if case .closeParen = peek() { advance() }
            }

            // Chained calls via dot
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
                            if case .openParen = peek() { depth += 1 }
                            if case .closeParen = peek() { depth -= 1 }
                            if depth > 0 { advance() }
                        }
                        if case .closeParen = peek() { advance() }
                    }
                } else {
                    break
                }
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
            return .message(assignee: assignee, type: type, from: from, to: to, signature: signature, block: block)
        }

        return nil
    }

    private func parseParExpr() -> String? {
        if case .openParen = peek() {
            advance()
            var cond = ""
            while pos < tokens.count {
                if case .closeParen = peek() { advance(); break }
                if case .id(let s) = peek() {
                    cond += s + " "
                    advance()
                } else if case .int(let i) = peek() {
                    cond += String(i) + " "
                    advance()
                } else if case .cstring(let s) = peek() {
                    cond += s + " "
                    advance()
                } else if case .newline = peek() {
                    advance()
                } else if case .eof = peek() {
                    break
                } else {
                    advance()
                }
            }
            let trimmed = cond.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func skipWhitespaceAndComments() {
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
    case title(content: String?)
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

    // Collect participants from head
    var participantMap: [String: ZenUMLParticipant] = [:]

    // Walk the AST to collect participants and statements
    switch ast {
    case .prog(let title, let head, let block):
        diagram.title = title

        // Process head for groups and participants
        if let headNodes = head {
            for node in headNodes {
                switch node {
                case .participant(let type, let stereotype, let emoji, let name, let width, let label, let color):
                    let p = ZenUMLParticipant(
                        name: name,
                        label: label,
                        type: type,
                        stereotype: stereotype,
                        color: color,
                        emoji: emoji,
                        width: width,
                        explicit: true
                    )
                    participantMap[name] = p
                case .group(let id, let participants):
                    var groupParticipantNames: [String] = []
                    for pNode in participants {
                        if case .participant(let type, let stereotype, let emoji, let name, let width, let label, let color) = pNode {
                            let p = ZenUMLParticipant(
                                name: name,
                                label: label,
                                type: type,
                                stereotype: stereotype,
                                color: color,
                                emoji: emoji,
                                width: width,
                                groupId: id,
                                explicit: true
                            )
                            participantMap[name] = p
                            groupParticipantNames.append(name)
                        }
                    }
                    diagram.groups.append(ZenUMLGroup(id: id, participants: groupParticipantNames))
                case .starterExp(let content):
                    // Starter participant
                    if participantMap[content] == nil {
                        participantMap[content] = ZenUMLParticipant(name: content, isStarter: true)
                    } else {
                        participantMap[content]?.isStarter = true
                    }
                default:
                    break
                }
            }
        }

        // Process block for statements and implicit participants
        if case .block(let stmts) = block {
            diagram.statements = extractStatements(from: stmts, participantMap: &participantMap)
        }
    default:
        break
    }

    // Set participants in order (explicit first, then implicit)
    var orderedParticipants: [ZenUMLParticipant] = []
    // Explicit first
    for (name, p) in participantMap where p.explicit {
        orderedParticipants.append(p)
    }
    // Implicit
    for (name, p) in participantMap where !p.explicit {
        orderedParticipants.append(p)
    }
    // Starter
    if let starter = participantMap.values.first(where: { $0.isStarter }) {
        if !orderedParticipants.contains(where: { $0.name == starter.name }) {
            orderedParticipants.insert(starter, at: 0)
        }
    }

    diagram.participants = orderedParticipants

    return diagram
}

private func extractStatements(from astNodes: [ZenUMLASTNode], participantMap: inout [String: ZenUMLParticipant]) -> [ZenUMLStatement] {
    var statements: [ZenUMLStatement] = []

    for node in astNodes {
        switch node {
        case .message(let assignee, _, let from, let to, let signature, let block):
            let resolvedFrom = from ?? findImplicitOrigin(participantMap: &participantMap)
            let resolvedTo = to.isEmpty ? resolvedFrom : to

            // Register implicit participants
            if participantMap[resolvedFrom] == nil {
                participantMap[resolvedFrom] = ZenUMLParticipant(name: resolvedFrom, explicit: false)
            }
            if participantMap[resolvedTo] == nil {
                participantMap[resolvedTo] = ZenUMLParticipant(name: resolvedTo, explicit: false)
            }

            var innerStatements: [ZenUMLStatement]? = nil
            if case .block(let innerStmts) = block {
                innerStatements = extractStatements(from: innerStmts, participantMap: &participantMap)
            }

            let stmt = ZenUMLStatement.message(
                from: resolvedFrom,
                to: resolvedTo,
                signature: signature,
                type: .sync,
                block: innerStatements,
                comment: nil
            )
            statements.append(stmt)

        case .asyncMessage(let from, let to, let content):
            let resolvedFrom = from ?? findImplicitOrigin(participantMap: &participantMap)
            let resolvedTo = to.isEmpty ? resolvedFrom : to

            if participantMap[resolvedFrom] == nil {
                participantMap[resolvedFrom] = ZenUMLParticipant(name: resolvedFrom, explicit: false)
            }
            if participantMap[resolvedTo] == nil {
                participantMap[resolvedTo] = ZenUMLParticipant(name: resolvedTo, explicit: false)
            }

            statements.append(.asyncMessage(from: resolvedFrom, to: resolvedTo, content: content, comment: nil))

        case .creation(let assignee, let type, let construct, let params, let block):
            let resolvedFrom = findImplicitOrigin(participantMap: &participantMap)
            let targetName = assignee ?? construct

            if participantMap[targetName] == nil {
                participantMap[targetName] = ZenUMLParticipant(name: targetName, explicit: false)
            }

            var innerStatements: [ZenUMLStatement]? = nil
            if case .block(let innerStmts) = block {
                innerStatements = extractStatements(from: innerStmts, participantMap: &participantMap)
            }

            statements.append(.creation(
                assignee: assignee,
                type: type,
                construct: construct,
                to: targetName,
                params: params,
                block: innerStatements,
                comment: nil
            ))

        case .ret(let value, _, let returnArrow):
            if let arrow = returnArrow, case .returnArrowMessage(let from, let to, let content) = arrow {
                statements.append(.return(from: from, to: to, value: content, comment: nil))
            } else if let v = value {
                statements.append(.return(from: "", to: "", value: v, comment: nil))
            }

        case .alt(let ifBlock, let elseIfs, let elseBlock):
            var sections: [ZenUMLFragmentSection] = []

            if case .block(let stmts) = ifBlock {
                sections.append(ZenUMLFragmentSection(
                    label: "if",
                    statements: extractStatements(from: stmts, participantMap: &participantMap)
                ))
            }

            for (i, elifNode) in elseIfs.enumerated() {
                if case .block(let stmts) = elifNode {
                    sections.append(ZenUMLFragmentSection(
                        label: "else if \(i + 1)",
                        statements: extractStatements(from: stmts, participantMap: &participantMap)
                    ))
                }
            }

            if let elseNode = elseBlock, case .block(let stmts) = elseNode {
                sections.append(ZenUMLFragmentSection(
                    label: "else",
                    statements: extractStatements(from: stmts, participantMap: &participantMap)
                ))
            }

            statements.append(.fragment(kind: .alt, condition: nil, sections: sections))

        case .loop(let keyword, let condition, let block):
            var innerStmts: [ZenUMLStatement] = []
            if case .block(let stmts) = block {
                innerStmts = extractStatements(from: stmts, participantMap: &participantMap)
            }
            statements.append(.fragment(kind: .loop, condition: condition, sections: [
                ZenUMLFragmentSection(label: keyword, statements: innerStmts)
            ]))

        case .par(let condition, let block):
            var innerStmts: [ZenUMLStatement] = []
            if case .block(let stmts) = block {
                innerStmts = extractStatements(from: stmts, participantMap: &participantMap)
            }
            statements.append(.fragment(kind: .par, condition: condition, sections: [
                ZenUMLFragmentSection(label: "par", statements: innerStmts)
            ]))

        case .opt(let condition, let block):
            var innerStmts: [ZenUMLStatement] = []
            if case .block(let stmts) = block {
                innerStmts = extractStatements(from: stmts, participantMap: &participantMap)
            }
            statements.append(.fragment(kind: .opt, condition: condition, sections: [
                ZenUMLFragmentSection(label: "opt", statements: innerStmts)
            ]))

        case .critical(let condition, let block):
            var innerStmts: [ZenUMLStatement] = []
            if case .block(let stmts) = block {
                innerStmts = extractStatements(from: stmts, participantMap: &participantMap)
            }
            statements.append(.fragment(kind: .critical, condition: condition, sections: [
                ZenUMLFragmentSection(label: "critical", statements: innerStmts)
            ]))

        case .section(let name, let block):
            var innerStmts: [ZenUMLStatement] = []
            if case .block(let stmts) = block {
                innerStmts = extractStatements(from: stmts, participantMap: &participantMap)
            }
            statements.append(.fragment(kind: .section, condition: nil, sections: [
                ZenUMLFragmentSection(label: name ?? "", statements: innerStmts)
            ]))

        case .ref(let names):
            statements.append(.fragment(kind: .ref, condition: nil, sections: [
                ZenUMLFragmentSection(label: names.joined(separator: ", "), statements: [])
            ]))

        case .tcf(let tryBlock, let catches, let finallyBlock):
            var sections: [ZenUMLFragmentSection] = []

            if case .block(let stmts) = tryBlock {
                sections.append(ZenUMLFragmentSection(
                    label: "try",
                    statements: extractStatements(from: stmts, participantMap: &participantMap)
                ))
            }

            for catchNode in catches {
                if case .block(let stmts) = catchNode {
                    sections.append(ZenUMLFragmentSection(
                        label: "catch",
                        statements: extractStatements(from: stmts, participantMap: &participantMap)
                    ))
                }
            }

            if let finallyNode = finallyBlock, case .block(let stmts) = finallyNode {
                sections.append(ZenUMLFragmentSection(
                    label: "finally",
                    statements: extractStatements(from: stmts, participantMap: &participantMap)
                ))
            }

            statements.append(.fragment(kind: .tcf, condition: nil, sections: sections))

        case .divider(let label):
            statements.append(.divider(label: label))

        case .block(let inner):
            statements.append(contentsOf: extractStatements(from: inner, participantMap: &participantMap))

        default:
            break
        }
    }

    return statements
}

/// Find the implicit origin participant (last active participant in scope)
private func findImplicitOrigin(participantMap: inout [String: ZenUMLParticipant]) -> String {
    let starterName = "_STARTER_"
    if participantMap[starterName] == nil {
        participantMap[starterName] = ZenUMLParticipant(name: starterName, explicit: true, isStarter: true)
    }
    return starterName
}
