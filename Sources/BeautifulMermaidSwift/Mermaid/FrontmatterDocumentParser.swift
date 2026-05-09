import Foundation

/// Parses YAML-like frontmatter from Mermaid diagram sources.
/// Extracts key-value pairs from `---` delimited blocks and delegates
/// binding to `FrontmatterBinding` implementations.
public enum FrontmatterDocumentParser {

    /// Parse YAML-like frontmatter lines into a `DiagramFrontmatter`.
    /// Delegates to `_parseYamlFrontmatter` which handles global keys inline
    /// and dispatches diagram-specific config through `FrontmatterBinding`.
    public static func parse(_ lines: [String]) -> DiagramFrontmatter? {
        _parseYamlFrontmatter(lines)
    }

    /// Parse YAML-like frontmatter lines and return flattened key-value
    /// pairs suitable for `FrontmatterBinding.apply(path:value:)`.
    /// Each pair has a dot-separated path (e.g. `"config.sequence.diagramMarginX"`)
    /// and a `FrontmatterValue`.
    public static func flatten(_ lines: [String]) -> [(path: String, value: FrontmatterValue)] {
        var result: [(String, FrontmatterValue)] = []
        var currentPath: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let indent = line.prefix(while: { $0 == " " }).count
            let depth = indent / 2
            // Pop back to the correct nesting depth
            while currentPath.count > depth { currentPath.removeLast() }

            // Split on first colon only
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            var key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let valuePart = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes from keys (e.g. "Electricity grid" → Electricity grid)
            if (key.hasPrefix("\"") && key.hasSuffix("\"") && key.count >= 2) ||
               (key.hasPrefix("'") && key.hasSuffix("'") && key.count >= 2) {
                key = String(key.dropFirst().dropLast())
            }

            // Push the key onto the path regardless of whether there's a value
            currentPath.append(key)

            // If there's no value, this is a nesting key — don't emit an entry
            guard !valuePart.isEmpty else { continue }

            let unquoted: String
            if valuePart.hasPrefix("\"") && valuePart.hasSuffix("\"") && valuePart.count >= 2 {
                unquoted = String(valuePart.dropFirst().dropLast())
            } else if valuePart.hasPrefix("'") && valuePart.hasSuffix("'") && valuePart.count >= 2 {
                unquoted = String(valuePart.dropFirst().dropLast())
            } else {
                unquoted = valuePart
            }
            let fullPath = currentPath.joined(separator: ".")
            result.append((fullPath, FrontmatterValue(raw: unquoted)))
        }
        return result
    }
}
