import Foundation

/// Shared identifier/string hygiene for the PlantUML format target. The
/// per-file `escape` / `quoted` helpers in the PlantUML exporters all
/// delegate here so there is exactly one implementation per transform.
/// PlantUML is line-oriented (`@startuml`/`@enduml`), so every variant
/// collapses embedded newlines — the variants differ in how CR bytes and
/// quote/backslash characters are treated per emission context.
enum PlantUMLHygiene {

    /// Newlines become a single space; CR bytes pass through untouched.
    /// Used by the component/object/deployment/use-case/ER emitters,
    /// whose text is single-line by construction.
    static func collapseNewlines(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    /// CR, LF, and CRLF all become a single space.
    static func collapseAllNewlines(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Escapes a value for emission inside a PlantUML double-quoted
    /// string: backslash and quote are escaped, all newline variants
    /// collapse to a space.
    static func escapeQuotedBody(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// `escapeQuotedBody` wrapped in double quotes.
    static func quoted(_ s: String) -> String {
        "\"\(escapeQuotedBody(s))\""
    }

    /// Activity-label text: the `;` statement terminator is escaped and
    /// newlines collapse to spaces.
    static func escapeActivityText(_ s: String) -> String {
        s.replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Sequence free text (after `:` / block headers): all newline
    /// variants become the literal two-character `\n` escape — PlantUML
    /// renders `\"` literally in free text, so quotes are left alone.
    static func escapeSequenceFreeText(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Sequence title/note/group/box/else labels: backslash and quote are
    /// escaped and all newline variants become the literal `\n` escape.
    static func escapeSequenceString(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
