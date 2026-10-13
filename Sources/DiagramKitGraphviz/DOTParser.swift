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
            case .htmlString(let s): return s
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
            case .htmlString(let s):
                // Graphviz HTML-like labels — outer angles preserved so
                // DOTMapper can dispatch via _isHTMLLabel.
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
            s.diagnostics.append(.featureDropped(
                .slotUnsupported,
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
        // First endpoint (a single id or a bare braced node set `{ B C }`)
        var sources = try parseEndpointList(&s, role: "edge source")
        let firstSourceID = sources.first?.id ?? ""

        // Edge operator
        guard let edgeOp = s.advance() else {
            throw DiagramError.malformedSource(message:"Expected edge operator '->' or '--'")
        }

        // Chain of (sources, directed, targets) segments. Graphviz semantics:
        // `A -> { B C } -> D` declares the cross product of each adjacent
        // endpoint-list pair, and a trailing attribute list applies to ALL
        // segments of the statement.
        var segments: [(sources: [Endpoint], directed: Bool, targets: [Endpoint])] = []

        var directed: Bool
        switch edgeOp {
        case .directedEdge: directed = true
        case .undirectedEdge: directed = false
        default:
            throw DiagramError.malformedSource(message:"Expected '->' or '--'")
        }

        while true {
            if s.peekIdentifier()?.lowercased() == "subgraph" {
                emitPortDiagnosticsIfNeeded(sources, state: &s)
                s.diagnostics.append(.featureDropped(
                    .slotUnsupported,
                    message: "edges to subgraphs not yet supported; preserving subgraph contents without the edge",
                    location: nil
                ))
                let subgraphStatement = try parseSubgraph(&s)
                s.pendingStatements.append(subgraphStatement)
                // The subgraph target produces no edges; keep the source
                // visible as a bare node so it still lands in the document.
                if segments.isEmpty {
                    return .nodeStatement(DOTNodeStatement(id: firstSourceID))
                }
                break
            }

            let targets = try parseEndpointList(&s, role: "edge target")
            segments.append((sources: sources, directed: directed, targets: targets))

            if let nextToken = s.peek(), nextToken == .directedEdge || nextToken == .undirectedEdge {
                sources = targets
                directed = (s.advance() == .directedEdge)
                continue
            }
            break
        }

        // Optional trailing attribute list — Graphviz applies it to every
        // edge in the statement.
        var attrs: [DOTAttribute] = []
        if s.peek() == .openBracket {
            attrs = try parseAttrList(&s)
        }

        emitPortDiagnosticsIfNeeded(sources, state: &s)

        // Expand each segment into its cross product of edges.
        var edges: [DOTEdgeStatement] = []
        for segment in segments {
            for src in segment.sources {
                for tgt in segment.targets {
                    edges.append(DOTEdgeStatement(
                        source: src.id,
                        target: tgt.id,
                        directed: segment.directed,
                        attributes: attrs
                    ))
                }
            }
        }

        guard !edges.isEmpty else {
            return .nodeStatement(DOTNodeStatement(id: firstSourceID))
        }

        // Emit the first edge now; buffer the rest for the statement loop to
        // flush into the current scope.
        for extra in edges.dropFirst() {
            s.pendingStatements.append(.edgeStatement(extra))
        }
        return .edgeStatement(edges[0])
    }

    /// Parses one endpoint position: a single ID (with optional port syntax)
    /// or a bare braced node set `{ B C }` (Graphviz: one edge per contained
    /// node id). Returns the endpoints the position stands for.
    private func parseEndpointList(_ s: inout State, role: String) throws -> [Endpoint] {
        if s.peek() == .openBrace {
            _ = s.advance() // consume '{'
            var ids: [Endpoint] = []
            while let token = s.peek(), token != .closeBrace {
                if token == .semicolon || token == .comma {
                    _ = s.advance()
                    continue
                }
                if token == .openBrace {
                    // Nested brace set — parse so the braces stay balanced,
                    // but bare node sets don't nest in Graphviz.
                    s.diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "Nested braces inside an edge endpoint set are not supported",
                        location: nil
                    ))
                    _ = s.advance()
                    continue
                }
                guard let id = s.consumeIdentifier() else {
                    s.diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "Skipping unsupported token inside braced edge endpoint set",
                        location: nil
                    ))
                    _ = s.advance()
                    continue
                }
                ids.append(Endpoint(id: id, usedPortSyntax: false))
            }
            guard s.peek() == .closeBrace else {
                throw DiagramError.malformedSource(message: "Unbalanced braces in edge endpoint set")
            }
            _ = s.advance() // consume '}'
            if ids.isEmpty {
                s.diagnostics.append(.featureDropped(
                    .slotUnsupported,
                    message: "Braced edge endpoint set contains no node ids; no edges produced",
                    location: nil
                ))
            }
            return ids
        }

        return [try parseEndpoint(&s, role: role)]
    }

    private func emitPortDiagnosticsIfNeeded(_ endpoints: [Endpoint], state: inout State) {
        for endpoint in endpoints {
            emitPortDiagnosticIfNeeded(endpoint, state: &state)
        }
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
