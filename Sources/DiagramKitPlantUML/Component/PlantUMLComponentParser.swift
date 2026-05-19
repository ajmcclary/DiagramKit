import Foundation

struct PlantUMLComponentParser {

    func parse(_ body: String) -> PlantUMLComponentAST {
        var ast = PlantUMLComponentAST()
        var declared: [String: PlantUMLComponentAST.Component.Kind] = [:]
        var order: [String] = []
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("'") { continue }
            if trimmed.hasPrefix("title ") {
                ast.title = String(trimmed.dropFirst("title ".count))
                continue
            }
            if trimmed.hasPrefix("interface ") {
                let id = String(trimmed.dropFirst("interface ".count)).trimmingCharacters(in: .whitespaces)
                if !id.isEmpty, declared[id] == nil {
                    declared[id] = .interface
                    order.append(id)
                }
                continue
            }
            if trimmed.hasPrefix("component ") {
                let id = String(trimmed.dropFirst("component ".count)).trimmingCharacters(in: .whitespaces)
                if !id.isEmpty, declared[id] == nil {
                    declared[id] = .component
                    order.append(id)
                }
                continue
            }
            for token in extractBracketIDs(trimmed) {
                if declared[token] == nil {
                    declared[token] = .component
                    order.append(token)
                }
            }
            if let edge = parseEdge(trimmed) {
                if declared[edge.source] == nil {
                    declared[edge.source] = .component
                    order.append(edge.source)
                }
                if declared[edge.target] == nil {
                    declared[edge.target] = .component
                    order.append(edge.target)
                }
                ast.edges.append(edge)
            }
        }

        for id in order {
            ast.components.append(.init(id: id, label: id, kind: declared[id] ?? .component))
        }
        return ast
    }

    private func extractBracketIDs(_ line: String) -> [String] {
        var results: [String] = []
        var i = line.startIndex
        while i < line.endIndex {
            if line[i] == "[" {
                let after = line.index(after: i)
                if let close = line[after...].firstIndex(of: "]") {
                    let inner = String(line[after..<close]).trimmingCharacters(in: .whitespaces)
                    if !inner.isEmpty {
                        results.append(inner)
                    }
                    i = line.index(after: close)
                    continue
                }
            }
            i = line.index(after: i)
        }
        return results
    }

    private func parseEdge(_ line: String) -> PlantUMLComponentAST.Edge? {
        guard let r = line.range(of: "-->")
                ?? line.range(of: "->")
        else { return nil }
        let leftRaw = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        let restRaw = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        let (rightRaw, label) = splitLabel(restRaw)
        let left = stripBrackets(leftRaw)
        let right = stripBrackets(rightRaw)
        if left.isEmpty || right.isEmpty { return nil }
        return .init(source: left, target: right, label: label)
    }

    private func splitLabel(_ s: String) -> (String, String?) {
        guard let colon = s.firstIndex(of: ":") else { return (s, nil) }
        let head = String(s[..<colon]).trimmingCharacters(in: .whitespaces)
        let tail = String(s[s.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        return (head, tail.isEmpty ? nil : tail)
    }

    private func stripBrackets(_ s: String) -> String {
        var out = s
        if out.hasPrefix("[") { out.removeFirst() }
        if out.hasSuffix("]") { out.removeLast() }
        return out.trimmingCharacters(in: .whitespaces)
    }
}
