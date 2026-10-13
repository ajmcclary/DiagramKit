import Foundation

/// Shared constants for the comment-encoded recovery-marker grammar used by
/// the D2, DOT, PlantUML, and Structurizr importers and exporters.
///
/// Marker line grammar:
/// `<comment-prefix> diagramkit:<kind-kebab>=<args>`
/// where `<args>` is either a single string, comma-separated positional
/// fields, or `b64:<base64-of-utf8>` for free-form text.
public enum RecoveryMarkerSyntax {
    public static let sentinel = "diagramkit:"
    public static let base64Prefix = "b64:"

    /// Encodes one comma-separated marker field so the field grammar stays
    /// parseable: values containing the field separator (`,`), quote, or
    /// newline characters — or values that would be ambiguous with the
    /// encoding itself — travel as `b64:<base64-of-utf8>`. Clean values
    /// pass through unchanged so existing marker text stays stable.
    public static func encodeField(_ value: String) -> String {
        let needsEncoding = value.contains(",") || value.contains("\"")
            || value.contains("\n") || value.contains("\r")
            || value.hasPrefix(base64Prefix)
        if needsEncoding {
            return base64Prefix + Data(value.utf8).base64EncodedString()
        }
        return value
    }

    /// Inverse of `encodeField`. Values without the `b64:` prefix return
    /// unchanged; malformed base64 returns the input as-is (the caller's
    /// field validation still applies).
    public static func decodeField(_ value: String) -> String {
        guard value.hasPrefix(base64Prefix) else { return value }
        let encoded = String(value.dropFirst(base64Prefix.count))
        guard let data = Data(base64Encoded: encoded) else { return value }
        return String(data: data, encoding: .utf8) ?? value
    }
}
