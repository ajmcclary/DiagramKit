import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Typed value tree produced by `PlantUMLJSONParser`. Preserves source
/// order of object keys (which `JSONSerialization` does not on its own
/// when decoding to `[String: Any]`). The parser re-walks the raw bytes
/// to recover insertion order.
public indirect enum PlantUMLJSONValue: Sendable, Equatable {
    case object([Pair])
    case array([PlantUMLJSONValue])
    case string(String)
    case number(String)  // preserved as text so 42 ≠ 42.0
    case bool(Bool)
    case null

    public struct Pair: Sendable, Equatable {
        public let key: String
        public let value: PlantUMLJSONValue

        public init(key: String, value: PlantUMLJSONValue) {
            self.key = key
            self.value = value
        }
    }

    public static func == (lhs: PlantUMLJSONValue, rhs: PlantUMLJSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let l), .bool(let r)): return l == r
        case (.string(let l), .string(let r)): return l == r
        case (.number(let l), .number(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.object(let l), .object(let r)): return l == r
        default: return false
        }
    }
}

/// Parses `@startjson` bodies with a hand-rolled lexer that preserves
/// object-key insertion order. Foundation's `JSONSerialization` would
/// lose key order when decoding to `[String: Any]`.
public struct PlantUMLJSONParser {

    public init() {}

    public func parse(_ body: String) throws -> PlantUMLJSONValue {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson body is empty")
        }
        var index = trimmed.startIndex
        let value = try parseValue(trimmed, index: &index)
        skipWhitespace(trimmed, index: &index)
        guard index == trimmed.endIndex else {
            throw DiagramError.malformedSource(
                message: "PlantUML @startjson: trailing data after value"
            )
        }
        return value
    }

    private func parseValue(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        skipWhitespace(s, index: &index)
        guard index < s.endIndex else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: unexpected end")
        }
        switch s[index] {
        case "{": return try parseObject(s, index: &index)
        case "[": return try parseArray(s, index: &index)
        case "\"": return .string(try parseString(s, index: &index))
        case "t", "f": return .bool(try parseBool(s, index: &index))
        case "n": return try parseNull(s, index: &index)
        case "-", "0"..."9": return .number(try parseNumber(s, index: &index))
        default:
            throw DiagramError.malformedSource(
                message: "PlantUML @startjson: unexpected character '\(s[index])'"
            )
        }
    }

    private func parseObject(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        index = s.index(after: index)  // consume '{'
        var pairs: [PlantUMLJSONValue.Pair] = []
        skipWhitespace(s, index: &index)
        if index < s.endIndex, s[index] == "}" {
            index = s.index(after: index)
            return .object(pairs)
        }
        while index < s.endIndex {
            skipWhitespace(s, index: &index)
            guard index < s.endIndex, s[index] == "\"" else {
                throw DiagramError.malformedSource(message: "PlantUML @startjson: expected string key")
            }
            let key = try parseString(s, index: &index)
            skipWhitespace(s, index: &index)
            guard index < s.endIndex, s[index] == ":" else {
                throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ':'")
            }
            index = s.index(after: index)
            let value = try parseValue(s, index: &index)
            pairs.append(PlantUMLJSONValue.Pair(key: key, value: value))
            skipWhitespace(s, index: &index)
            if index < s.endIndex, s[index] == "," {
                index = s.index(after: index)
                continue
            }
            if index < s.endIndex, s[index] == "}" {
                index = s.index(after: index)
                return .object(pairs)
            }
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ',' or '}'")
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated object")
    }

    private func parseArray(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        index = s.index(after: index)  // consume '['
        var elements: [PlantUMLJSONValue] = []
        skipWhitespace(s, index: &index)
        if index < s.endIndex, s[index] == "]" {
            index = s.index(after: index)
            return .array(elements)
        }
        while index < s.endIndex {
            elements.append(try parseValue(s, index: &index))
            skipWhitespace(s, index: &index)
            if index < s.endIndex, s[index] == "," {
                index = s.index(after: index)
                continue
            }
            if index < s.endIndex, s[index] == "]" {
                index = s.index(after: index)
                return .array(elements)
            }
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ',' or ']'")
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated array")
    }

    private func parseString(_ s: String, index: inout String.Index) throws -> String {
        guard index < s.endIndex, s[index] == "\"" else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected '\"'")
        }
        index = s.index(after: index)
        var out = ""
        while index < s.endIndex {
            let ch = s[index]
            if ch == "\"" {
                index = s.index(after: index)
                return out
            }
            if ch == "\\" {
                index = s.index(after: index)
                guard index < s.endIndex else { break }
                switch s[index] {
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": out.append("\r")
                case "b": out.append("\u{08}")
                case "f": out.append("\u{0C}")
                case "u":
                    let start = s.index(after: index)
                    guard let end = s.index(start, offsetBy: 4, limitedBy: s.endIndex) else {
                        throw DiagramError.malformedSource(message: "PlantUML @startjson: short \\u escape")
                    }
                    guard let cp = UInt32(s[start..<end], radix: 16),
                          let scalar = Unicode.Scalar(cp) else {
                        throw DiagramError.malformedSource(message: "PlantUML @startjson: bad \\u escape")
                    }
                    out.append(Character(scalar))
                    index = s.index(before: end)
                default: out.append(s[index])
                }
                index = s.index(after: index)
            } else {
                out.append(ch)
                index = s.index(after: index)
            }
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated string")
    }

    private func parseBool(_ s: String, index: inout String.Index) throws -> Bool {
        if s[index...].hasPrefix("true") {
            index = s.index(index, offsetBy: 4)
            return true
        }
        if s[index...].hasPrefix("false") {
            index = s.index(index, offsetBy: 5)
            return false
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: expected true/false")
    }

    private func parseNull(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        guard s[index...].hasPrefix("null") else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected null")
        }
        index = s.index(index, offsetBy: 4)
        return .null
    }

    private func parseNumber(_ s: String, index: inout String.Index) throws -> String {
        let start = index
        if s[index] == "-" { index = s.index(after: index) }
        while index < s.endIndex,
              "0"..."9" ~= s[index]
              || s[index] == "."
              || s[index] == "e"
              || s[index] == "E"
              || s[index] == "+"
              || s[index] == "-" {
            index = s.index(after: index)
        }
        let token = String(s[start..<index])
        guard !token.isEmpty, Double(token) != nil else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: invalid number '\(token)'")
        }
        return token
    }

    private func skipWhitespace(_ s: String, index: inout String.Index) {
        while index < s.endIndex, s[index].isWhitespace {
            index = s.index(after: index)
        }
    }
}
