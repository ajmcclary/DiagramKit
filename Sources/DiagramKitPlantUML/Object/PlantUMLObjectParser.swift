import Foundation

struct PlantUMLObjectParser {

    func parse(_ body: String) -> PlantUMLObjectAST {
        var ast = PlantUMLObjectAST()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("'") {
                index += 1
                continue
            }
            if trimmed.hasPrefix("title ") {
                ast.title = String(trimmed.dropFirst("title ".count))
                index += 1
                continue
            }
            if trimmed.hasPrefix("object ") {
                let (decl, consumed) = parseObject(startingAt: index, in: lines)
                ast.objects.append(decl)
                index += consumed + 1
                continue
            }
            if let rel = parseRelationship(trimmed) {
                ast.relationships.append(rel)
            }
            index += 1
        }
        return ast
    }

    private func parseObject(startingAt start: Int, in lines: [String]) -> (PlantUMLObjectAST.ObjectDecl, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let after = header.dropFirst("object ".count).trimmingCharacters(in: .whitespaces)
        let id = parseObjectID(after)
        var attrs: [String] = []
        var consumed = 0
        if !after.contains("{") {
            return (.init(id: id, label: id, attributes: []), 0)
        }
        var i = start + 1
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed == "}" {
                consumed = i - start
                break
            }
            if !trimmed.isEmpty {
                attrs.append(trimmed)
            }
            i += 1
        }
        return (.init(id: id, label: id, attributes: attrs), consumed)
    }

    private func parseObjectID(_ s: String) -> String {
        let token = s.split(separator: " ").first ?? Substring("")
        return String(token).replacingOccurrences(of: "{", with: "")
    }

    private func parseRelationship(_ line: String) -> PlantUMLObjectAST.Relationship? {
        let arrows: [(String, PlantUMLObjectAST.Relationship.Arrow)] = [
            ("*--", .composition),
            ("--*", .composition),
            ("o--", .aggregation),
            ("--o", .aggregation),
            ("..>", .dependency),
            ("-->", .association),
            ("->", .association),
        ]
        for (marker, arrow) in arrows {
            if let r = line.range(of: marker) {
                let left = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if left.isEmpty || rest.isEmpty { continue }
                if let colon = rest.firstIndex(of: ":") {
                    let right = String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
                    let label = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    return .init(left: left, right: right, arrow: arrow, label: label.isEmpty ? nil : label)
                }
                let right = rest
                return .init(left: left, right: right, arrow: arrow, label: nil)
            }
        }
        return nil
    }
}
