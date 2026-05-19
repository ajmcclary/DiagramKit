import Foundation

struct PlantUMLUseCaseParser {

    func parse(_ body: String) -> PlantUMLUseCaseAST {
        var ast = PlantUMLUseCaseAST()
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("'") { continue }
            if trimmed.hasPrefix("title ") {
                ast.title = String(trimmed.dropFirst("title ".count))
                continue
            }
            if trimmed.hasPrefix(":") && trimmed.contains(":") && !trimmed.hasSuffix(";") {
                if let node = parseActorAlias(trimmed) {
                    ast.nodes.append(node)
                    continue
                }
            }
            if trimmed.hasPrefix("actor ") {
                ast.nodes.append(parseBareKeyword(trimmed, kind: .actor, prefix: "actor "))
                continue
            }
            if trimmed.hasPrefix("(") && trimmed.contains(")") {
                if let node = parseUseCaseParen(trimmed) {
                    ast.nodes.append(node)
                    continue
                }
            }
            if trimmed.hasPrefix("usecase ") {
                ast.nodes.append(parseBareKeyword(trimmed, kind: .useCase, prefix: "usecase "))
                continue
            }
            if let edge = parseEdge(trimmed) {
                ast.edges.append(edge)
            }
        }
        return ast
    }

    private func parseActorAlias(_ line: String) -> PlantUMLUseCaseAST.Node? {
        let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { return nil }
        let display = parts[1].trimmingCharacters(in: .whitespaces)
        var alias = display
        if parts.count >= 3 {
            let rest = parts[2].trimmingCharacters(in: .whitespaces)
            if rest.hasPrefix("as ") {
                alias = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }
        return .init(id: alias, display: display, kind: .actor)
    }

    private func parseUseCaseParen(_ line: String) -> PlantUMLUseCaseAST.Node? {
        guard let openParen = line.firstIndex(of: "("),
              let closeParen = line.firstIndex(of: ")")
        else { return nil }
        let display = String(line[line.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)
        var alias = display
        let rest = String(line[line.index(after: closeParen)...]).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix("as ") {
            alias = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        return .init(id: alias, display: display, kind: .useCase)
    }

    private func parseBareKeyword(_ line: String, kind: PlantUMLUseCaseAST.Node.Kind, prefix: String) -> PlantUMLUseCaseAST.Node {
        let id = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return .init(id: id, display: id, kind: kind)
    }

    private func parseEdge(_ line: String) -> PlantUMLUseCaseAST.Edge? {
        guard let arrowRange = line.range(of: "-->")
                ?? line.range(of: "->")
        else { return nil }
        let source = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rest = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        if let colon = rest.firstIndex(of: ":") {
            let target = String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
            let label = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return .init(source: source, target: target, label: label)
        }
        return .init(source: source, target: rest, label: nil)
    }
}
