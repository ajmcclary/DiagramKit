import Foundation

/// A non-fatal issue discovered during import or export.
/// Returned in `DiagramImportResult.diagnostics` and
/// `DiagramExportResult.diagnostics`.
public struct DiagramDiagnostic: Sendable, Hashable, CustomStringConvertible {
    /// Severity level.
    public enum Severity: Sendable, Hashable {
        case warning     // recoverable; import proceeds
        case info        // informational; nothing dropped
        case unsupported // feature dropped; import proceeds without it
    }

    public let severity: Severity
    /// Typed category — populated by the static factories on this type.
    /// `nil` when constructed via the public raw `init(severity:message:)`.
    public let category: DiagnosticCategory?
    public let message: String
    /// Optional source location hint (line number, span, etc.)
    public let location: SourceLocation?

    public struct SourceLocation: Sendable, Hashable {
        public let line: Int?
        public let column: Int?
        public init(line: Int? = nil, column: Int? = nil) {
            self.line = line
            self.column = column
        }
    }

    /// Back-compatible raw init. Use the `.lossyTransform` /
    /// `.featureDropped` / `.informational` factories for new code; see
    /// `docs/diagnostic-severity-discipline.md`. (Deprecation marker
    /// lands once the in-tree migration completes.)
    public init(severity: Severity,
                message: String,
                location: SourceLocation? = nil) {
        self.severity = severity
        self.category = nil
        self.message = message
        self.location = location
    }

    /// Internal designated init — factories route here.
    internal init(severity: Severity,
                  category: DiagnosticCategory?,
                  message: String,
                  location: SourceLocation? = nil) {
        self.severity = severity
        self.category = category
        self.message = message
        self.location = location
    }

    public var description: String {
        if let loc = location {
            let lineStr = loc.line.map { "line \($0)" } ?? "?"
            return "[\(severity)] \(message) (\(lineStr))"
        }
        return "[\(severity)] \(message)"
    }
}
