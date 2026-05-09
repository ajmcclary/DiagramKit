import Foundation

/// Parses YAML-like frontmatter from Mermaid diagram sources.
/// Extracts key-value pairs from `---` delimited blocks and delegates
/// binding to `FrontmatterBinding` implementations.
public enum FrontmatterDocumentParser {

    /// Parse YAML-like frontmatter lines into a `DiagramFrontmatter`.
    /// Currently delegates to the existing `_StackSafeYamlFrontmatterParser`
    /// in SourcePreprocessing.swift; future work will extract that logic here.
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
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            // Remove quotes if present
            let unquoted: String
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                unquoted = String(value.dropFirst().dropLast())
            } else if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
                unquoted = String(value.dropFirst().dropLast())
            } else {
                unquoted = value
            }
            currentPath.append(key)
            let fullPath = currentPath.joined(separator: ".")
            result.append((fullPath, FrontmatterValue(raw: unquoted)))
        }
        return result
    }
}
