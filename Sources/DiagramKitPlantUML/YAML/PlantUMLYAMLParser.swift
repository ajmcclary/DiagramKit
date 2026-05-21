import Foundation
import DiagramKitCommon
import DiagramKitModel

public indirect enum PlantUMLYAMLValue: Sendable, Equatable {
    case mapping([Pair])
    case sequence([PlantUMLYAMLValue])
    case scalar(String)  // raw token (quoted strings keep their quotes)

    public struct Pair: Sendable, Equatable {
        public let key: String
        public let value: PlantUMLYAMLValue

        public init(key: String, value: PlantUMLYAMLValue) {
            self.key = key
            self.value = value
        }
    }

    public static func == (lhs: PlantUMLYAMLValue, rhs: PlantUMLYAMLValue) -> Bool {
        switch (lhs, rhs) {
        case (.scalar(let l), .scalar(let r)): return l == r
        case (.sequence(let l), .sequence(let r)): return l == r
        case (.mapping(let l), .mapping(let r)): return l == r
        default: return false
        }
    }
}

public struct PlantUMLYAMLParseResult: Sendable {
    public let value: PlantUMLYAMLValue
    public let unsupportedFeatures: [String]

    public init(value: PlantUMLYAMLValue, unsupportedFeatures: [String]) {
        self.value = value
        self.unsupportedFeatures = unsupportedFeatures
    }
}

/// Minimal YAML subset parser. Supports block mappings, block sequences,
/// plain + quoted scalars, line comments. Unsupported features are
/// detected and reported via `unsupportedFeatures`; the parser then
/// continues with a best-effort recovery (skips the offending lines).
public struct PlantUMLYAMLParser {

    public init() {}

    public func parse(_ body: String) throws -> PlantUMLYAMLParseResult {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DiagramError.malformedSource(message: "PlantUML @startyaml body is empty")
        }

        var unsupported: [String] = []
        let rawLines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        for raw in rawLines {
            let line = String(raw)
            // Strip inline comments before feature-detection so a literal
            // `#` inside a comment line doesn't get scanned for tokens.
            let stripped = stripInlineComment(line)
            let stripTrim = stripped.trimmingCharacters(in: .whitespaces)
            if stripTrim == "---" {
                // Any explicit doc-separator line means multi-document.
                unsupported.append("YAML feature: multi-document streams")
                continue
            }
            if stripped.contains("&") {
                unsupported.append("YAML feature: anchor (&name)")
            }
            if stripped.contains(" *") || stripped.contains(":*") {
                unsupported.append("YAML feature: alias (*name)")
            }
            if stripped.contains("!!") || stripped.range(of: #"!\w"#, options: .regularExpression) != nil {
                unsupported.append("YAML feature: tag (!!t / !Tag)")
            }
            if stripped.contains("{") || stripped.contains("[") {
                unsupported.append("YAML feature: flow style ({…}, […])")
            }
            if stripTrim.hasSuffix("|") || stripTrim.hasSuffix(">") {
                unsupported.append("YAML feature: block scalar (|, >)")
            }
        }

        // Build the working subset: drop doc separators, drop lines that
        // are entirely comments, drop lines containing unsupported
        // tokens. Each surviving line keeps its original indentation so
        // the indent scanner can compute depth.
        var workingLines: [String] = []
        var docCutoff = false
        for raw in rawLines {
            let line = String(raw)
            let trimAll = line.trimmingCharacters(in: .whitespaces)
            if trimAll.isEmpty { continue }
            if trimAll.hasPrefix("#") { continue }  // comment-only line
            if trimAll == "---" {
                if docCutoff { break }
                docCutoff = true
                continue
            }
            if line.contains("&") || line.contains("!!") || line.contains("{") || line.contains("[") {
                continue
            }
            // Drop inline comments while preserving indentation.
            workingLines.append(stripInlineComment(line))
        }

        var index = 0
        let value = try parseBlock(lines: workingLines, indent: 0, index: &index)

        let unique = Array(Set(unsupported)).sorted()
        return PlantUMLYAMLParseResult(value: value, unsupportedFeatures: unique)
    }

    private func parseBlock(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(lines[index])
            if lineIndent < baseIndent {
                return .mapping([])
            }
            if trimmed.hasPrefix("- ") || trimmed == "-" {
                return try parseSequence(lines: lines, indent: lineIndent, index: &index)
            }
            return try parseMapping(lines: lines, indent: lineIndent, index: &index)
        }
        return .mapping([])
    }

    private func parseMapping(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        var pairs: [PlantUMLYAMLValue.Pair] = []
        while index < lines.count {
            let line = lines[index]
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(line)
            if lineIndent < baseIndent { return .mapping(pairs) }
            if lineIndent > baseIndent {
                index += 1
                continue
            }
            guard let colonRange = stripped.range(of: ":") else {
                throw DiagramError.malformedSource(
                    message: "PlantUML @startyaml: expected 'key: value' at line \(index + 1)"
                )
            }
            let key = String(stripped[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let valuePart = String(stripped[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            index += 1
            if valuePart.isEmpty {
                let child = try parseBlock(lines: lines, indent: baseIndent + 1, index: &index)
                pairs.append(.init(key: key, value: child))
            } else {
                pairs.append(.init(key: key, value: .scalar(valuePart)))
            }
        }
        return .mapping(pairs)
    }

    private func parseSequence(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        var elements: [PlantUMLYAMLValue] = []
        while index < lines.count {
            let line = lines[index]
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(line)
            if lineIndent < baseIndent { return .sequence(elements) }
            if lineIndent > baseIndent {
                index += 1
                continue
            }
            guard stripped.hasPrefix("- ") || stripped == "-" else {
                return .sequence(elements)
            }
            let rest = stripped == "-" ? "" : String(stripped.dropFirst(2))
            index += 1
            if rest.isEmpty {
                let child = try parseBlock(lines: lines, indent: baseIndent + 1, index: &index)
                elements.append(child)
            } else {
                elements.append(.scalar(rest))
            }
        }
        return .sequence(elements)
    }

    /// Strip an inline `# comment` while leaving content (including
    /// quoted strings that may contain `#`) intact. Naive: cuts at the
    /// first un-quoted `#`.
    private func stripInlineComment(_ line: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var out = ""
        var index = line.startIndex
        while index < line.endIndex {
            let ch = line[index]
            if ch == "'" && !inDoubleQuote { inSingleQuote.toggle() }
            else if ch == "\"" && !inSingleQuote { inDoubleQuote.toggle() }
            else if ch == "#" && !inSingleQuote && !inDoubleQuote {
                break
            }
            out.append(ch)
            index = line.index(after: index)
        }
        // Trim trailing whitespace that the cut may have exposed.
        return String(out.reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }

    private func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 2 }  // treat tab as 2 spaces
            else { break }
        }
        return count
    }
}
