//
//  JSONValue.swift
//  MermaidPlayground
//
//  Recursive, permissive JSON value type that preserves unknown keys
//  through decode → inspect → encode round-trips. Used by LiveEditorConfig
//  to parse user-supplied config JSON without failing on unrecognized fields.
//

import Foundation

// MARK: - JSONValue

/// A recursive enum representing any valid JSON value.
///
/// Unlike decoding into a fixed `Decodable` struct, `JSONValue` accepts
/// every key in an object and preserves it for later inspection. Unknown
/// Mermaid config keys survive serialization, save, and history restore.
public indirect enum JSONValue: Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            let context = DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Cannot decode JSON value"
            )
            throw DecodingError.dataCorrupted(context)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }
}

// MARK: - Convenience accessors

extension JSONValue {
    /// Unwrap the underlying string if this is `.string`.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Unwrap the underlying number if this is `.number`.
    public var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    /// Unwrap the underlying bool if this is `.bool`.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// Unwrap the underlying dictionary if this is `.object`.
    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Unwrap the underlying array if this is `.array`.
    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// Recursively look up a key path (e.g. `["flowchart", "padding"]`).
    public subscript(keyPath: [String]) -> JSONValue? {
        var current = self
        for key in keyPath {
            guard case .object(let dict) = current, let next = dict[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    /// Returns a flat dictionary of all leaf key paths → JSONValue.
    public func flattened(prefix: [String] = []) -> [([String], JSONValue)] {
        switch self {
        case .object(let dict):
            return dict.flatMap { key, value in
                value.flattened(prefix: prefix + [key])
            }
        default:
            return [(prefix, self)]
        }
    }
}

// MARK: - Debug description

extension JSONValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        case .null: return "null"
        case .object(let dict):
            let entries = dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return "{\(entries)}"
        case .array(let items):
            let entries = items.map { "\($0)" }.joined(separator: ", ")
            return "[\(entries)]"
        }
    }
}
