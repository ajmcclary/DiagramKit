//
//  LiveEditorStateCodec.swift
//  DiagramPlayground
//
//  Serializes LiveEditorState to/from a URL-safe base64-encoded
//  JSON string suitable for sharing via clipboard, URL query params,
//  or paste-and-restore workflows.
//

import Foundation
import DiagramKitModel

// MARK: - LiveEditorStateCodec

/// Encodes and decodes ``LiveEditorState`` for sharing.
///
/// App-local format: JSON + base64url.
/// pako:/deflate interop with mermaid.live URLs is deferred to Phase 4.1.
public enum LiveEditorStateCodec {

    // MARK: - Errors

    public enum CodecError: Swift.Error, Sendable, Equatable, LocalizedError {
        /// The input string is not valid base64url.
        case invalidBase64
        /// The decoded data is not valid JSON.
        case invalidJSON(String)
        /// The JSON is valid but doesn't decode to LiveEditorState.
        case invalidState(String)

        public var errorDescription: String? {
            switch self {
            case .invalidBase64:
                return "The share string is not valid base64."
            case .invalidJSON(let detail):
                return "The share string does not contain valid JSON: \(detail)"
            case .invalidState(let detail):
                return "The JSON does not represent a valid editor state: \(detail)"
            }
        }
    }

    // MARK: - Encode

    /// Encode a ``LiveEditorState`` to a shareable base64url string.
    ///
    /// - Parameter state: The state to serialize.
    /// - Returns: A base64url-encoded JSON string, or `""` on encoding failure.
    public static func encode(_ state: LiveEditorState) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(state) else { return "" }
        return Base64URL.encode(data)
    }

    // MARK: - Decode

    /// Decode a shareable base64url string back into a ``LiveEditorState``.
    ///
    /// - Parameter string: A base64url-encoded JSON string produced by ``encode(_:)``.
    /// - Throws: ``CodecError`` if the string is malformed or doesn't represent valid state.
    /// - Returns: The restored state.
    public static func decode(_ string: String) throws -> LiveEditorState {
        let data: Data
        do {
            data = try Base64URL.decode(string)
        } catch {
            throw CodecError.invalidBase64
        }

        let decoder = JSONDecoder()
        let state: LiveEditorState
        do {
            state = try decoder.decode(LiveEditorState.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw CodecError.invalidJSON(context.debugDescription)
        } catch let DecodingError.keyNotFound(key, context) {
            throw CodecError.invalidState("Missing key '\(key.stringValue)': \(context.debugDescription)")
        } catch {
            throw CodecError.invalidJSON(error.localizedDescription)
        }

        return state
    }
}
