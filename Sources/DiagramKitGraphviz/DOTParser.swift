import Foundation
import DiagramKitModel
import DiagramKitImport

/// Recursive-descent parser for the narrow DOT subset.
///
/// Consumes `[DOTToken]` from `DOTLexer`, returns `(DOTDocument, [DiagramDiagnostic])`.
///
/// Grammar subset:
/// ```
/// document      := header "{" statement* "}"
/// header        := "strict"? ("graph" | "digraph") ID?
/// statement     := node_stmt ";"
///                | edge_stmt ";"
///                | attr_stmt ";"
///                | subgraph
///                | graph_attr_stmt ";"
/// node_stmt     := ID attr_list?
/// edge_stmt     := ID ("->" | "--") ID attr_list?
///                | edge_stmt ("->" | "--") ID   // chained: A -> B -> C
/// attr_stmt     := ("graph" | "node" | "edge") attr_list
/// graph_attr_stmt := ID "=" ID
/// attr_list     := "[" a_list? "]"
/// a_list        := ID "=" ID ("," ID "=" ID)*
/// ```
public struct DOTParser {

    public init() {}

    // MARK: - Parse state

    private struct State {
        var tokens: [DOTToken]
        var pos: Int = 0
        var diagnostics: [DiagramDiagnostic] = []

        /// Buffer for extra statements produced by chained edge parsing.
        /// These are prepended to the statement list after the current
        /// parseDocument loop completes.
        var pendingStatements: [DOTStatement] = []

        func peek() -> DOTToken? {
            pos < tokens.count ? tokens[pos] : nil
        }

        func peekAhead(_ n: Int) -> DOTToken? {
            let idx = pos + n
            return idx < tokens.count ? tokens[idx] : nil
        }

        mutating func advance() -> DOTToken? {
            guard pos < tokens.count else { return nil }
            let token = tokens[pos]
            pos += 1
            return token
        }

        mutating func expect(_ token: DOTToken) throws {
            let got = advance()
            guard got == token else {
                throw DiagramError.notYetImplemented(
                    "Expected \(token), got \(String(describing: got))"
                )
            }
        }

        func identifier(at: Int) -> String? {
            guard at < tokens.count else { return nil }
            switch tokens[at] {
            case .identifier(let s): return s
            case .string(let s): return s
            default: return nil
            }
        }

        func peekIdentifier() -> String? {
            identifier(at: pos)
        }

        mutating func consumeIdentifier() -> String? {
            guard pos < tokens.count else { return nil }
            switch tokens[pos] {
            case .identifier(let s):
                pos += 1
                return s
            case .string(let s):
                pos += 1
                return s
            default:
                return nil
            }
        }

        mutating func consumeIf(_ token: DOTToken) -> Bool {
            guard pos < tokens.count, tokens[pos] == token else { return false }
            pos += 1
            return true
        }
    }

    // MARK: - Public entry point

    public func parse(_ tokens: [DOTToken]) throws -> (document: DOTDocument, diagnostics: [DiagramDiagnostic]) {
        var state = State(tokens: tokens)
        let document = try parseDocument(&state)
        return (document, state.diagnostics)
    }

    // MARK: - document

    private func parseDocument(_ s: inout State) throws -> DOTDocument {
        let (kind, strict, id) = try parseHeader(&s)

        try s.expect(.openBrace)

        var statements: [DOTStatement] = []
        while let token = s.peek() {
            if token == .closeBrace { break }
            if token == .semicolon {
                _ = s.advance()
                continue
            }
            if let stmt = try parseStatement(&s) {
                statements.append(stmt)
            }
            // Consume optional semicolons
            _ = s.consumeIf(.semicolon)
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.notYetImplemented("Unbalanced braces: missing '}'")
        }
        _ = s.advance() // consume '}'

        // Flush any pending statements from chained edge parsing
        statements.append(contentsOf: s.pendingStatements)

        return DOTDocument(kind: kind, strict: strict, id: id, statements: statements)
    }

    // MARK: - header

    private func parseHeader(_ s: inout State) throws -> (kind: DOTGraphKind, strict: Bool, id: String?) {
        var strict = false

        if s.peekIdentifier()?.lowercased() == "strict" {
            strict = true
            _ = s.advance()
        }

        guard let keyword = s.peekIdentifier()?.lowercased() else {
            throw DiagramError.notYetImplemented("Expected 'graph' or 'digraph' at start of DOT document")
        }

        let kind: DOTGraphKind
        switch keyword {
        case "graph":
            kind = .graph
            _ = s.advance()
        case "digraph":
            kind = .digraph
            _ = s.advance()
        default:
            throw DiagramError.notYetImplemented("Expected 'graph' or 'digraph', got '\(keyword)'")
        }

        // Optional graph ID — consume if present and next token is '{'
        let id: String?
        if let peekedID = s.peekIdentifier(), case .openBrace = s.peekAhead(1) {
            id = peekedID
            _ = s.advance()
        } else if let peekedID = s.peekIdentifier(), s.peekAhead(1) == nil {
            // Single identifier — consume it
            id = peekedID
            _ = s.advance()
        } else {
            id = nil
        }

        return (kind, strict, id)
    }

    // MARK: - statement

    private func parseStatement(_ s: inout State) throws -> DOTStatement? {
        guard let token = s.peek() else { return nil }

        switch token {
        case .identifier(let word):
            let lower = word.lowercased()
            switch lower {
            case "subgraph":
                // May be followed by an ID, or '{' directly
                return try parseSubgraph(&s)
            case "node":
                // attr_stmt: node [attr_list]
                return try parseAttrStatement(target: .node, &s)
            case "edge":
                // attr_stmt: edge [attr_list]
                return try parseAttrStatement(target: .edge, &s)
            case "graph":
                // Could be attr_stmt: graph [attr_list]
                // or graph_attr_stmt: graph=value
                // Peek ahead to distinguish
                if case .openBracket = s.peekAhead(1) {
                    return try parseAttrStatement(target: .graph, &s)
                }
                // Otherwise treat as graph_attr_stmt
                fallthrough
            default:
                // Check for edge (ID followed by -> or --)
                if let edgeToken = s.peekAhead(1), edgeToken == .directedEdge || edgeToken == .undirectedEdge {
                    return try parseEdgeStatement(&s)
                }
                // Check for graph_attr_stmt: ID = ID
                if case .equals = s.peekAhead(1) {
                    return try parseGraphAttrStatement(&s)
                }
                // Otherwise node statement
                return try parseNodeStatement(&s)
            }

        case .openBrace:
            // Anonymous subgraph: `{ stmts }`
            _ = s.advance()
            var statements: [DOTStatement] = []
            while let t = s.peek(), t != .closeBrace {
                if t == .semicolon { _ = s.advance(); continue }
                if let stmt = try parseStatement(&s) {
                    statements.append(stmt)
                }
                _ = s.consumeIf(.semicolon)
            }
            guard s.peek() == .closeBrace else {
                throw DiagramError.notYetImplemented("Unbalanced braces in anonymous subgraph")
            }
            _ = s.advance()
            return .subgraph(DOTSubgraph(id: nil, statements: statements))

        case .closeBrace:
            return nil

        case .semicolon:
            _ = s.advance()
            return nil

        default:
            // Skip unrecognized token
            s.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "Skipping unexpected token in DOT source",
                location: nil
            ))
            _ = s.advance()
            return nil
        }
    }

    // MARK: - node_stmt

    private func parseNodeStatement(_ s: inout State) throws -> DOTStatement {
        guard let id = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected node identifier")
        }

        var attributes: [DOTAttribute] = []
        if s.peek() == .openBracket {
            attributes = try parseAttrList(&s)
        }

        let nodeStmt = DOTNodeStatement(id: id, attributes: attributes)
        return .nodeStatement(nodeStmt)
    }

    // MARK: - edge_stmt

    private func parseEdgeStatement(_ s: inout State) throws -> DOTStatement {
        // First endpoint
        guard let firstId = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected edge source identifier")
        }

        // Edge operator
        guard let edgeOp = s.advance() else {
            throw DiagramError.notYetImplemented("Expected edge operator '->' or '--'")
        }

        let directed: Bool
        switch edgeOp {
        case .directedEdge: directed = true
        case .undirectedEdge: directed = false
        default:
            throw DiagramError.notYetImplemented("Expected '->' or '--'")
        }

        // Second endpoint
        guard let secondId = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected edge target identifier")
        }

        // Check for chained edges: `A -> B -> C`
        // If the next token is an edge operator, this is a chain.
        // Consume the full chain, emit the first edge now, and buffer
        // subsequent edges in pendingStatements for later flush.
        if let nextToken = s.peek(), nextToken == .directedEdge || nextToken == .undirectedEdge {
            var prevID = secondId
            while let nextToken = s.peek(), nextToken == .directedEdge || nextToken == .undirectedEdge {
                let chainedDirected = (s.advance()! == .directedEdge)
                guard let nextId = s.consumeIdentifier() else {
                    throw DiagramError.notYetImplemented("Expected identifier in chained edge")
                }
                // Buffer this edge segment (prevID -> nextId)
                s.pendingStatements.append(
                    .edgeStatement(DOTEdgeStatement(
                        source: prevID,
                        target: nextId,
                        directed: chainedDirected,
                        attributes: []
                    ))
                )
                prevID = nextId
            }

            // Optional attribute list at end of chain — applies to the LAST buffered edge
            if s.peek() == .openBracket {
                let attrs = try parseAttrList(&s)
                if let lastIdx = s.pendingStatements.indices.last,
                   case .edgeStatement(var lastEdge) = s.pendingStatements[lastIdx] {
                    lastEdge.attributes = attrs
                    s.pendingStatements[lastIdx] = .edgeStatement(lastEdge)
                }
            }
        } else {
            // Single edge — optional attribute list
            var attrs: [DOTAttribute] = []
            if s.peek() == .openBracket {
                attrs = try parseAttrList(&s)
            }
            let edgeStmt = DOTEdgeStatement(
                source: firstId,
                target: secondId,
                directed: directed,
                attributes: attrs
            )
            return .edgeStatement(edgeStmt)
        }

        // Return the first edge segment
        let firstEdge = DOTEdgeStatement(
            source: firstId,
            target: secondId,
            directed: directed,
            attributes: []
        )
        return .edgeStatement(firstEdge)
    }

    // MARK: - attr_stmt

    private func parseAttrStatement(target: DOTAttrTarget, _ s: inout State) throws -> DOTStatement {
        _ = s.advance() // consume "graph", "node", or "edge"

        guard s.peek() == .openBracket else {
            throw DiagramError.notYetImplemented("Expected '[' after '\(target)' attribute target")
        }

        let attributes = try parseAttrList(&s)

        let stmt = DOTAttrStatement(target: target, attributes: attributes)
        return .attrStatement(stmt)
    }

    // MARK: - graph_attr_stmt

    private func parseGraphAttrStatement(_ s: inout State) throws -> DOTStatement {
        guard let key = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected graph attribute key")
        }

        guard s.peek() == .equals else {
            throw DiagramError.notYetImplemented("Expected '=' after graph attribute key")
        }
        _ = s.advance() // consume '='

        guard let value = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected value after '=' in graph attribute")
        }

        return .graphAttr(key, value)
    }

    // MARK: - subgraph

    private func parseSubgraph(_ s: inout State) throws -> DOTStatement {
        _ = s.advance() // consume "subgraph"

        // Optional subgraph ID — consume if present and next token is '{'
        let id: String?
        if let peekedID = s.peekIdentifier(), case .openBrace = s.peekAhead(1) {
            id = peekedID
            _ = s.advance()
        } else {
            id = nil
        }

        guard s.peek() == .openBrace else {
            throw DiagramError.notYetImplemented("Expected '{' after 'subgraph'")
        }
        _ = s.advance() // consume '{'

        var statements: [DOTStatement] = []
        while let token = s.peek(), token != .closeBrace {
            if token == .semicolon { _ = s.advance(); continue }
            if let stmt = try parseStatement(&s) {
                statements.append(stmt)
            }
            _ = s.consumeIf(.semicolon)
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.notYetImplemented("Unbalanced braces in subgraph")
        }
        _ = s.advance() // consume '}'

        return .subgraph(DOTSubgraph(id: id, statements: statements))
    }

    // MARK: - attr_list

    private func parseAttrList(_ s: inout State) throws -> [DOTAttribute] {
        guard s.peek() == .openBracket else { return [] }
        _ = s.advance() // consume '['

        var attributes: [DOTAttribute] = []

        // Parse comma-separated key=value pairs
        while let token = s.peek(), token != .closeBracket {
            if token == .comma || token == .semicolon {
                _ = s.advance()
                continue
            }

            guard let key = s.consumeIdentifier() else {
                break
            }

            guard s.peek() == .equals else {
                s.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "Expected '=' after attribute key '\(key)'",
                    location: nil
                ))
                continue
            }
            _ = s.advance() // consume '='

            // Value can be identifier, string, or number
            let value: String
            if let ident = s.consumeIdentifier() {
                value = ident
            } else {
                value = ""
            }

            attributes.append(DOTAttribute(key: key, value: value))

            // Skip optional comma
            _ = s.consumeIf(.comma)
        }

        // Consume optional comma before ']'
        _ = s.consumeIf(.comma)

        guard s.peek() == .closeBracket else {
            throw DiagramError.notYetImplemented("Unterminated attribute list: expected ']'")
        }
        _ = s.advance() // consume ']'

        return attributes
    }
}
