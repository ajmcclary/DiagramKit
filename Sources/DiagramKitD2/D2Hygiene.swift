import Foundation

/// Shared identifier/string hygiene for the D2 format target. The per-file
/// `sanitize` / `escape` / `singleLine` helpers in the D2 exporters all
/// delegate here so there is exactly one implementation per transform.
///
/// `mangleID` substitutes unsafe characters (`space`, `-`, `.` → `_`, drops
/// everything else, guards a leading digit). It does NOT handle collisions —
/// collision-aware emission with `.idSanitization` diagnostics lives in
/// `D2SequenceExport.sanitizeID` and the Mermaid `MermaidExportHelpers`
/// precedent; emitters that can collide should build on a used-id set.
enum D2Hygiene {

    /// Rewrites `raw` into a D2-safe bare identifier.
    static func mangleID(_ raw: String, emptyPlaceholder: String = "node") -> String {
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default:
                break
            }
        }
        return out.isEmpty ? emptyPlaceholder : out
    }

    /// Escapes a value for emission inside a D2 double-quoted string:
    /// backslash and quote are escaped, newlines become `\n`, CR is dropped.
    static func escapeString(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Collapses a multi-line value onto one line.
    static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}
