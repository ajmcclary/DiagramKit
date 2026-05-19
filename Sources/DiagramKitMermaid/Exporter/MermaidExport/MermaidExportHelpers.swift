import Foundation
import DiagramKitCommon

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
                diagnostics.append(.lossyTransform(
                    .labelNewlineEscape,
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
                diagnostics.append(.lossyTransform(
                    .labelNewlineEscape,
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
    ///
    /// Severity is `.warning`: this is a lossy operation that can collide
    /// distinct inputs into the same output (`foo bar` and `foo!bar` both
    /// become `foo_bar`) and changes a load-bearing identifier the caller
    /// referenced elsewhere. Structurizr's `uniqueSanitizedAlias` already
    /// uses `.warning` for the same operation; this aligns with that.
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
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "Identifier '\(raw)' sanitized to '\(result)'"
            ))
        }

        return (result, diagnostics)
    }

    /// Collision-aware variant of `sanitizeIdentifier`. Tracks every alias
    /// already emitted in the current export and appends a numeric suffix
    /// (`_2`, `_3`, …) to disambiguate collisions. Mirrors
    /// `StructurizrExporter.uniqueSanitizedAlias`. Use this when multiple
    /// inputs in the same diagram could sanitize to the same identifier
    /// (e.g. `foo bar` and `foo!bar` both → `foo_bar`).
    static func sanitizeIdentifier(
        _ raw: String,
        usedAliases: inout Set<String>
    ) -> (sanitized: String, diagnostics: [DiagramDiagnostic]) {
        var (base, diagnostics) = sanitizeIdentifier(raw)
        if !usedAliases.contains(base) {
            usedAliases.insert(base)
            return (base, diagnostics)
        }
        var counter = 2
        var candidate = "\(base)_\(counter)"
        while usedAliases.contains(candidate) {
            counter += 1
            candidate = "\(base)_\(counter)"
        }
        usedAliases.insert(candidate)
        diagnostics.append(.lossyTransform(
            .idSanitization,
            message: "Identifier '\(raw)' sanitized to '\(base)' collided with another alias; renamed to '\(candidate)'"
        ))
        return (candidate, diagnostics)
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
                diagnostics.append(.lossyTransform(
                    .labelNewlineEscape,
                    message: "Newline in quoted value replaced with space"
                ))
            default:
                inner.append(ch)
            }
        }
        return ("\"\(inner)\"", diagnostics)
    }

    // MARK: - Sectioned item emission

    /// Emit a sequence of items grouped under section transitions. The
    /// section name is read from each item; whenever it differs from the
    /// previous item's section, a `<sectionIndent><sectionKeyword> <name>`
    /// line is emitted. Empty section names (`""`) suppress the section
    /// header but still reset the tracked section.
    ///
    /// Used by journey and timeline (Wave 1) and slated for kanban and
    /// eventModeling.
    static func emitSectionedItems<Item>(
        _ items: [Item],
        sectionOf: (Item) -> String,
        sectionIndent: String,
        sectionKeyword: String = "section",
        emitItem: (Item) -> String
    ) -> [String] {
        var lines: [String] = []
        var currentSection: String? = nil
        for item in items {
            let section = sectionOf(item)
            if section != currentSection {
                if !section.isEmpty {
                    lines.append("\(sectionIndent)\(sectionKeyword) \(section)")
                }
                currentSection = section
            }
            lines.append(emitItem(item))
        }
        return lines
    }
}
