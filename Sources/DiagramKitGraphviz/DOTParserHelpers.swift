import Foundation
import DiagramKitModel
import DiagramKitImport

extension DOTParser {

    // MARK: - Statement helpers

    func flushPendingStatements(to statements: inout [DOTStatement], state: inout State) {
        guard !state.pendingStatements.isEmpty else { return }
        statements.append(contentsOf: state.pendingStatements)
        state.pendingStatements.removeAll()
    }

    func edgeOperatorIndex(afterEndpointAt index: Int, in state: State) -> Int? {
        guard state.identifier(at: index) != nil else { return nil }

        var opIndex = index + 1
        while opIndex < state.tokens.count, state.tokens[opIndex] == .colon {
            opIndex += 1
            guard state.identifier(at: opIndex) != nil else { return nil }
            opIndex += 1
        }

        guard opIndex < state.tokens.count else { return nil }
        let token = state.tokens[opIndex]
        return token == .directedEdge || token == .undirectedEdge ? opIndex : nil
    }

    // MARK: - Endpoint helpers

    func parseEndpoint(_ state: inout State, role: String) throws -> Endpoint {
        guard let id = state.consumeIdentifier() else {
            throw DiagramError.malformedSource(message: "Expected \(role) identifier")
        }

        var usedPortSyntax = false
        while state.consumeIf(.colon) {
            usedPortSyntax = true
            if state.consumeIdentifier() == nil {
                state.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "DOT port syntax is incomplete; using node id '\(id)'",
                    location: nil
                ))
                break
            }
        }

        return Endpoint(id: id, usedPortSyntax: usedPortSyntax)
    }

    func emitPortDiagnosticIfNeeded(_ endpoint: Endpoint, state: inout State) {
        guard endpoint.usedPortSyntax else { return }
        state.diagnostics.append(DiagramDiagnostic(
            severity: .unsupported,
            message: "DOT port syntax not yet supported; using node id '\(endpoint.id)' without port",
            location: nil
        ))
    }

    // MARK: - attr_list

    func parseAttrList(_ state: inout State) throws -> [DOTAttribute] {
        guard state.peek() == .openBracket else { return [] }
        _ = state.advance() // consume '['

        var attributes: [DOTAttribute] = []

        while let token = state.peek(), token != .closeBracket {
            if token == .comma || token == .semicolon {
                _ = state.advance()
                continue
            }

            guard let key = state.consumeIdentifier() else {
                break
            }

            guard state.peek() == .equals else {
                state.diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "Expected '=' after attribute key '\(key)'",
                    location: nil
                ))
                continue
            }
            _ = state.advance() // consume '='

            let value = state.consumeIdentifier() ?? ""
            attributes.append(DOTAttribute(key: key, value: value))

            _ = state.consumeIf(.comma)
        }

        _ = state.consumeIf(.comma)

        guard state.peek() == .closeBracket else {
            throw DiagramError.malformedSource(message: "Unterminated attribute list: expected ']'")
        }
        _ = state.advance() // consume ']'

        return attributes
    }
}
