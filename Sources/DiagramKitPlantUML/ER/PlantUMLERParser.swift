import Foundation

struct PlantUMLERParser {

    func parse(_ body: String) -> PlantUMLERAST {
        var ast = PlantUMLERAST()
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
            if trimmed.hasPrefix("entity ") {
                let (entity, consumed) = parseEntity(startingAt: index, in: lines)
                ast.entities.append(entity)
                index += consumed + 1
                continue
            }
            if let rel = parseRelationshipLine(trimmed) {
                ast.relationships.append(rel)
            }
            index += 1
        }
        return ast
    }

    private func parseEntity(startingAt start: Int, in lines: [String]) -> (PlantUMLERAST.Entity, Int) {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        let id = parseEntityID(header)
        var attrs: [PlantUMLERAST.Attribute] = []
        var consumed = 0
        var inPKSection = true
        var i = start + 1
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed == "}" {
                consumed = i - start
                break
            }
            if trimmed == "--" {
                inPKSection = false
                i += 1
                continue
            }
            if trimmed.isEmpty {
                i += 1
                continue
            }
            let attr = parseAttribute(trimmed, inPKSection: inPKSection)
            attrs.append(attr)
            i += 1
        }
        return (.init(id: id, attributes: attrs), consumed)
    }

    private func parseEntityID(_ header: String) -> String {
        let after = header.dropFirst("entity ".count)
        let token = after.split(separator: " ").first ?? Substring("")
        return String(token).replacingOccurrences(of: "{", with: "")
    }

    private func parseAttribute(_ line: String, inPKSection: Bool) -> PlantUMLERAST.Attribute {
        var s = line
        var isPK = inPKSection
        if s.hasPrefix("*") {
            isPK = true
            s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if let colon = s.firstIndex(of: ":") {
            let name = s[..<colon].trimmingCharacters(in: .whitespaces)
            let type = s[s.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return .init(name: name, type: type.isEmpty ? nil : type, isPrimaryKey: isPK)
        }
        return .init(name: s, type: nil, isPrimaryKey: isPK)
    }

    private func parseRelationshipLine(_ line: String) -> PlantUMLERAST.Relationship? {
        let pattern = #"([A-Za-z_][A-Za-z0-9_]*)\s+([|}o]+)(--|\.\.)([|{o]+)\s+([A-Za-z_][A-Za-z0-9_]*)(\s*:\s*(.+))?"#
        guard let nsre = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = nsre.firstMatch(in: line, range: range) else { return nil }

        func cap(_ i: Int) -> String? {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
            return String(line[range])
        }

        guard let left = cap(1),
              let leftSym = cap(2),
              let kind = cap(3),
              let rightSym = cap(4),
              let right = cap(5)
        else { return nil }

        let label = cap(7)?.trimmingCharacters(in: .whitespaces)

        return .init(
            left: left,
            right: right,
            leftCardinality: cardinalityFromLeft(leftSym),
            rightCardinality: cardinalityFromRight(rightSym),
            identifying: kind == "--",
            label: (label?.isEmpty ?? true) ? nil : label
        )
    }

    private func cardinalityFromLeft(_ sym: String) -> PlantUMLERAST.Relationship.Cardinality {
        switch sym {
        case "||": return .exactlyOne
        case "|o": return .zeroOrOne
        case "}|": return .oneOrMany
        case "}o": return .zeroOrMany
        default:   return .exactlyOne
        }
    }

    private func cardinalityFromRight(_ sym: String) -> PlantUMLERAST.Relationship.Cardinality {
        switch sym {
        case "||": return .exactlyOne
        case "o|": return .zeroOrOne
        case "|{": return .oneOrMany
        case "o{": return .zeroOrMany
        default:   return .exactlyOne
        }
    }
}
