//
//  Base64URL.swift
//  DiagramKitModel
//
//  URL-safe base64 encoding/decoding for state serialization.
//  Used by LiveEditorStateCodec in the playground and testable
//  from DiagramKitTests without playground dependencies.
//

import Foundation

// MARK: - Base64URL

/// URL-safe base64 encoding and decoding.
///
/// Uses the RFC 4648 §5 "base64url" alphabet:
/// - `+` → `-`
/// - `/` → `_`
/// - No `=` padding
public enum Base64URL {

    // MARK: - Errors

    public enum Error: Swift.Error, Sendable, Equatable {
        /// The input string is not valid base64 (even after restoring padding).
        case invalidBase64
    }

    // MARK: - Encode

    /// Encode `Data` to a base64url string (no padding).
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Decode

    /// Decode a base64url string to `Data`.
    ///
    /// - Parameter string: A base64url-encoded string (padding optional).
    /// - Throws: ``Error/invalidBase64`` if the string cannot be decoded.
    /// - Returns: The decoded data.
    public static func decode(_ string: String) throws -> Data {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Restore padding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw Error.invalidBase64
        }
        return data
    }
}
