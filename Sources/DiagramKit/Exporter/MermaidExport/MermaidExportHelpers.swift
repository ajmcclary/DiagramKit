import Foundation
import DiagramKitImport

/// Shared escape and sanitization helpers for Mermaid source emission.
enum MermaidExportHelpers {

    // MARK: - Bracket labels: `[label]`

    /// Escape content for Mermaid bracket labels (`[label]`).
    /// Escapes `]`, `[`, `"`, backslash. Newlines → spaces (diagnostic).
    static func escapeBracketLabel(_ text: String) -> (escaped: String, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var result = ""
        for ch in text {
            switch ch {
            case "]": result.append("\\]")
            case "[": result.append("\\[")
            case "\"": result.append("\\\"")
            case "\\": result.append("\\\\")
            case "\n", "\r":
                if result.last != " " { result.append(" ") }
                diagnostics.append(DiagramDiagnostic(
                    severity: .info,
                    message: "Newline in bracket label replaced with space"
                ))
            default:
                result.append(ch)
            }
        }
        return (result, diagnostics)
    }

    // MARK: - Edge labels: `-->|label|`

    /// Escape content for Mermaid edge labels (`-->|label|`).
    /// Escapes `|`, `"`, backslash.
    static func escapeEdgeLabel(_ text: String) -> (escaped: String, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var result = ""
        for ch in text {
            switch ch {
            case "|": result.append("#124;")
            case "\"": result.append("\\\"")
            case "\\": result.append("\\\\")
            case "\n", "\r":
                if result.last != " " { result.append(" ") }
                diagnostics.append(DiagramDiagnostic(
                    severity: .info,
                    message: "Newline in edge label replaced with space"
                ))
            default:
                result.append(ch)
            }
        }
        return (result, diagnostics)
    }

    // MARK: - Identifiers

    /// Sanitize a Mermaid identifier (node ID, participant alias).
    /// Spaces → underscores, strips leading digits, removes non-`[a-zA-Z0-9_-]`.
    static func sanitizeIdentifier(_ raw: String) -> (sanitized: String, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var result = ""
        var needsDiagnostic = false

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for (i, ch) in trimmed.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_", "-":
                if i == 0, ch.isNumber {
                    result.append("_")
                    needsDiagnostic = true
                }
                result.append(ch)
            case " ", "\t":
                if result.last != "_" { result.append("_") }
                needsDiagnostic = true
            default:
                // Drop non-alphanumeric characters
                needsDiagnostic = true
            }
        }

        if result.isEmpty {
            result = "node"
            needsDiagnostic = true
        }

        if needsDiagnostic {
            diagnostics.append(DiagramDiagnostic(
                severity: .info,
                message: "Identifier '\(raw)' sanitized to '\(result)'"
            ))
        }

        return (result, diagnostics)
    }

    // MARK: - Quoted values: `"text"`

    /// Quote and escape text for Mermaid quoted values (`"text"`).
    /// Escapes `"`, backslash, newlines.
    static func quote(_ text: String) -> (quoted: String, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var inner = ""
        for ch in text {
            switch ch {
            case "\"": inner.append("\\\"")
            case "\\": inner.append("\\\\")
            case "\n", "\r":
                inner.append(" ")
                diagnostics.append(DiagramDiagnostic(
                    severity: .info,
                    message: "Newline in quoted value replaced with space"
                ))
            default:
                inner.append(ch)
            }
        }
        return ("\"\(inner)\"", diagnostics)
    }
}
