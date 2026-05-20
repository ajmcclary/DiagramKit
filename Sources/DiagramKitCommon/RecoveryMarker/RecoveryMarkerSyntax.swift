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
}
