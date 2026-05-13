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

    struct State {
        var tokens: [DOTToken]
        var pos: Int = 0
        var diagnostics: [DiagramDiagnostic] = []

        /// Buffer for extra statements produced by chained edge parsing.
        /// The active parse loop flushes these immediately after the current
        /// statement so nested chains stay in their local statement list.
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
                throw DiagramError.malformedSource(message:
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

    struct Endpoint {
        var id: String
        var usedPortSyntax: Bool
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
                flushPendingStatements(to: &statements, state: &s)
            }
            // Consume optional semicolons
            _ = s.consumeIf(.semicolon)
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.malformedSource(message:"Unbalanced braces: missing '}'")
        }
        _ = s.advance() // consume '}'

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
            throw DiagramError.malformedSource(message:"Expected 'graph' or 'digraph' at start of DOT document")
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
            throw DiagramError.malformedSource(message:"Expected 'graph' or 'digraph', got '\(keyword)'")
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
                if edgeOperatorIndex(afterEndpointAt: s.pos, in: s) != nil {
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
                    flushPendingStatements(to: &statements, state: &s)
                }
                _ = s.consumeIf(.semicolon)
            }
            guard s.peek() == .closeBrace else {
                throw DiagramError.malformedSource(message:"Unbalanced braces in anonymous subgraph")
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
            throw DiagramError.malformedSource(message:"Expected node identifier")
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
        let firstEndpoint = try parseEndpoint(&s, role: "edge source")

        // Edge operator
        guard let edgeOp = s.advance() else {
            throw DiagramError.malformedSource(message:"Expected edge operator '->' or '--'")
        }

        let directed: Bool
        switch edgeOp {
        case .directedEdge: directed = true
        case .undirectedEdge: directed = false
        default:
            throw DiagramError.malformedSource(message:"Expected '->' or '--'")
        }

        if s.peekIdentifier()?.lowercased() == "subgraph" {
            emitPortDiagnosticIfNeeded(firstEndpoint, state: &s)
            s.diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "edges to subgraphs not yet supported; preserving subgraph contents without the edge",
                location: nil
            ))
            let subgraphStatement = try parseSubgraph(&s)
            s.pendingStatements.append(subgraphStatement)
            return .nodeStatement(DOTNodeStatement(id: firstEndpoint.id))
        }

        // Second endpoint
        let secondEndpoint = try parseEndpoint(&s, role: "edge target")
        emitPortDiagnosticIfNeeded(firstEndpoint, state: &s)
        emitPortDiagnosticIfNeeded(secondEndpoint, state: &s)

        // Check for chained edges: `A -> B -> C`
        // If the next token is an edge operator, this is a chain.
        // Consume the full chain, emit the first edge now, and buffer
        // subsequent edges in pendingStatements for later flush.
        if let nextToken = s.peek(), nextToken == .directedEdge || nextToken == .undirectedEdge {
            var prevID = secondEndpoint.id
            while let nextToken = s.peek(), nextToken == .directedEdge || nextToken == .undirectedEdge {
                let chainedDirected = (s.advance()! == .directedEdge)
                let nextEndpoint = try parseEndpoint(&s, role: "chained edge target")
                emitPortDiagnosticIfNeeded(nextEndpoint, state: &s)
                // Buffer this edge segment (prevID -> nextId)
                s.pendingStatements.append(
                    .edgeStatement(DOTEdgeStatement(
                        source: prevID,
                        target: nextEndpoint.id,
                        directed: chainedDirected,
                        attributes: []
                    ))
                )
                prevID = nextEndpoint.id
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
                source: firstEndpoint.id,
                target: secondEndpoint.id,
                directed: directed,
                attributes: attrs
            )
            return .edgeStatement(edgeStmt)
        }

        // Return the first edge segment
        let firstEdge = DOTEdgeStatement(
            source: firstEndpoint.id,
            target: secondEndpoint.id,
            directed: directed,
            attributes: []
        )
        return .edgeStatement(firstEdge)
    }

    // MARK: - attr_stmt

    private func parseAttrStatement(target: DOTAttrTarget, _ s: inout State) throws -> DOTStatement {
        _ = s.advance() // consume "graph", "node", or "edge"

        guard s.peek() == .openBracket else {
            throw DiagramError.malformedSource(message:"Expected '[' after '\(target)' attribute target")
        }

        let attributes = try parseAttrList(&s)

        let stmt = DOTAttrStatement(target: target, attributes: attributes)
        return .attrStatement(stmt)
    }

    // MARK: - graph_attr_stmt

    private func parseGraphAttrStatement(_ s: inout State) throws -> DOTStatement {
        guard let key = s.consumeIdentifier() else {
            throw DiagramError.malformedSource(message:"Expected graph attribute key")
        }

        guard s.peek() == .equals else {
            throw DiagramError.malformedSource(message:"Expected '=' after graph attribute key")
        }
        _ = s.advance() // consume '='

        guard let value = s.consumeIdentifier() else {
            throw DiagramError.malformedSource(message:"Expected value after '=' in graph attribute")
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
            throw DiagramError.malformedSource(message:"Expected '{' after 'subgraph'")
        }
        _ = s.advance() // consume '{'

        var statements: [DOTStatement] = []
        while let token = s.peek(), token != .closeBrace {
            if token == .semicolon { _ = s.advance(); continue }
            if let stmt = try parseStatement(&s) {
                statements.append(stmt)
                flushPendingStatements(to: &statements, state: &s)
            }
            _ = s.consumeIf(.semicolon)
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.malformedSource(message:"Unbalanced braces in subgraph")
        }
        _ = s.advance() // consume '}'

        return .subgraph(DOTSubgraph(id: id, statements: statements))
    }

}
