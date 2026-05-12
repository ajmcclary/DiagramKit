import Foundation

/// A non-fatal issue discovered during import.
/// Returned in `DiagramImportResult.diagnostics`.
public struct DiagramDiagnostic: Sendable, Hashable, CustomStringConvertible {
    /// Severity level.
    public enum Severity: Sendable, Hashable {
        case warning     // recoverable; import proceeds
        case info        // informational; nothing dropped
        case unsupported // feature dropped; import proceeds without it
    }

    public let severity: Severity
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

    public init(severity: Severity, message: String, location: SourceLocation? = nil) {
        self.severity = severity
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
