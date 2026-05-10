//
//  EditorDiagnostic.swift
//  MermaidPlayground
//
//  Structured diagnostic model for inline editor error display.
//  Provides severity, message, and optional line/column for gutter markers.
//

import Foundation
import DiagramKitModel

// MARK: - EditorDiagnostic

/// A single diagnostic produced by parsing, config validation, or the runtime.
///
/// Line and column are 1-based. When both are nil, the diagnostic is shown
/// in the error panel but not as a gutter marker.
public struct EditorDiagnostic: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let severity: Severity
    public let message: String
    public let line: Int?
    public let column: Int?
    public let source: DiagnosticSource

    public init(
        id: UUID = UUID(),
        severity: Severity,
        message: String,
        line: Int? = nil,
        column: Int? = nil,
        source: DiagnosticSource = .parse
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
        self.source = source
    }

    // MARK: - Severity

    public enum Severity: String, Sendable, Equatable, CaseIterable {
        case error
        case warning
        case info
    }

    // MARK: - Source

    public enum DiagnosticSource: String, Sendable, Equatable, CaseIterable {
        /// From the diagram parser (syntax errors, invalid constructs).
        case parse
        /// From config JSON validation / sanitization.
        case config
        /// From the rendering runtime (layout failures, etc.).
        case runtime
    }
}

// MARK: - Extraction from parser errors

extension EditorDiagnostic {

    /// Extract structured diagnostics from a parse error.
    ///
    /// Attempts to cast the error to known DiagramKit error types that carry
    /// line/column information. Falls back to regex extraction from the
    /// localized description.
    ///
    /// - Parameters:
    ///   - error: The error thrown during parsing.
    ///   - source: The diagnostic source (default: `.parse`).
    /// - Returns: One or more diagnostics. When extraction fails, a single
    ///   diagnostic without line/column is returned.
    public static func from(
        error: Error,
        source: DiagnosticSource = .parse
    ) -> [EditorDiagnostic] {
        // ---- Try known DiagramKit error types ----

        // RadarParserError carries a public `line` property
        if let radar = error as? RadarParserError {
            return [EditorDiagnostic(
                severity: .error,
                message: extractMessage(from: radar),
                line: radar.line,
                column: nil,
                source: source
            )]
        }

        // SankeyParserError — line numbers embedded in errorDescription
        if let sankey = error as? SankeyParserError {
            return [extractFromSankey(sankey, source: source)]
        }

        // EventModelingParserError — line numbers in errorDescription
        if let em = error as? EventModelingParserError {
            return [extractFromEventModeling(em, source: source)]
        }

        // ---- Fallback: regex on localizedDescription ----

        let desc = error.localizedDescription
        let (line, column) = extractLineColumn(from: desc)

        return [EditorDiagnostic(
            severity: .error,
            message: desc,
            line: line,
            column: column,
            source: source
        )]
    }

    // MARK: - Private helpers

    private static func extractMessage(from radar: RadarParserError) -> String {
        // Use the errorDescription without the "Parse error on line X" prefix
        let full = radar.localizedDescription
        if let colonIdx = full.firstIndex(of: ":"), colonIdx != full.lastIndex(of: ":") {
            // Skip past "Parse error on line X, column ?:"
            let after = full[full.index(after: colonIdx)...]
            return after.trimmingCharacters(in: .whitespaces)
        }
        return full
    }

    private static func extractFromSankey(
        _ error: SankeyParserError,
        source: DiagnosticSource
    ) -> EditorDiagnostic {
        let desc = error.localizedDescription
        let (line, _) = extractLineColumn(from: desc)
        return EditorDiagnostic(
            severity: .error,
            message: desc,
            line: line,
            column: nil,
            source: source
        )
    }

    private static func extractFromEventModeling(
        _ error: EventModelingParserError,
        source: DiagnosticSource
    ) -> EditorDiagnostic {
        let desc = error.localizedDescription
        let (line, _) = extractLineColumn(from: desc)
        return EditorDiagnostic(
            severity: .error,
            message: desc,
            line: line,
            column: nil,
            source: source
        )
    }

    /// Best-effort line/column extraction from an error message string.
    ///
    /// Matches patterns like:
    /// - `"line 5"`, `"at line 12"`, `"around line 3"`
    /// - `"column 8"`, `"col 4"`
    private static func extractLineColumn(from message: String) -> (line: Int?, column: Int?) {
        var line: Int?
        var column: Int?

        // "at line N" (most common pattern in eventmodeling/sankey)
        if line == nil {
            line = _extractFirstInt(from: message, pattern: #"at line (\d+)"#)
        }

        // "line N" (generic fallback — also catches the "at line N" pattern above)
        if line == nil {
            line = _extractFirstInt(from: message, pattern: #"(?:^|\s)line (\d+)"#)
        }

        // "around line N"
        if line == nil {
            line = _extractFirstInt(from: message, pattern: #"around line (\d+)"#)
        }

        // "column N" or "col N"
        column = _extractFirstInt(from: message, pattern: #"col(?:umn)?\s*(\d+)"#)

        return (line, column)
    }

    /// Extract the first capture-group integer from a regex match.
    private static func _extractFirstInt(from message: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              match.numberOfRanges > 1
        else { return nil }

        let groupRange = match.range(at: 1)
        guard groupRange.location != NSNotFound,
              let range = Range(groupRange, in: message)
        else { return nil }

        return Int(message[range])
    }
}

// MARK: - Config warnings → diagnostics

extension EditorDiagnostic {

    /// Convert a config sanitizer warning to an editor diagnostic.
    ///
    /// Config warnings don't carry source line numbers (they audit the parsed
    /// JSON tree), so `line` and `column` are always nil.
    public static func from(
        warning: ConfigSanitizer.Warning
    ) -> EditorDiagnostic {
        let severity: Severity = switch warning.level {
        case .unsupported: .error
        case .caution: .warning
        case .info: .info
        }
        return EditorDiagnostic(
            severity: severity,
            message: warning.message,
            line: nil,
            column: nil,
            source: .config
        )
    }
}
