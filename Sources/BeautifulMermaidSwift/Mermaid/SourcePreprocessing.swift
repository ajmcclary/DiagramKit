import Foundation

/// Result of preprocessing: the stripped diagram source and any parsed frontmatter.
typealias _PreprocessResult = (source: String, config: original_src_types.FlowchartConfig?)

func _preprocessMermaidSource(_ source: String) -> _PreprocessResult {
    _parseFrontMatterAndStripped(source)
}

func _mermaidSourceLines(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    let processed = _preprocessMermaidSource(source)
    let joined = _joinMultiLineBlocks(processed.source)
    return joined
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
}

/// Parse YAML-like frontmatter from a source string.
/// Returns the stripped diagram source and any parsed FlowchartConfig.
func _parseFrontMatterAndStripped(_ source: String) -> _PreprocessResult {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    guard let startIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
          lines[startIdx].trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    else {
        return (source, nil)
    }

    guard let endIdx = lines[(startIdx + 1)...].firstIndex(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    }) else {
        return (source, nil)
    }

    let fmLines = Array(lines[(startIdx + 1)..<endIdx])
    let stripped = lines[(endIdx + 1)...].joined(separator: "\n")
    let config = _parseYamlFlowchartConfig(fmLines)
    return (stripped, config)
}

/// Minimal YAML parser for Mermaid frontmatter.
/// Handles: title, config.flowchart.curve, config.flowchart.htmlLabels, etc.
private func _parseYamlFlowchartConfig(_ lines: [String]) -> original_src_types.FlowchartConfig? {
    var config = original_src_types.FlowchartConfig()
    var currentPath: [String] = []
    var hasFlowchartSection = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        // Simple key: value parsing
        let indent = line.prefix(while: { $0 == " " }).count
        let bare = trimmed

        // Remove the part after "#" (comment)
        let commentStripped: String
        if let hashIdx = bare.firstIndex(of: "#") {
            // Don't strip if # is inside quotes
            if let quoteIdx = bare.firstIndex(of: "\""), quoteIdx < hashIdx,
               let closeIdx = bare[bare.index(after: quoteIdx)...].firstIndex(of: "\""), closeIdx > hashIdx {
                commentStripped = bare
            } else {
                commentStripped = String(bare[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
        } else {
            commentStripped = bare
        }

        guard let colonIdx = commentStripped.firstIndex(of: ":") else { continue }
        let key = String(commentStripped[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(commentStripped[commentStripped.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        let value = _unquote(rawValue)

        // Track nesting level
        let depth = indent / 2
        while currentPath.count > depth { currentPath.removeLast() }
        if currentPath.count == depth {
            if !currentPath.isEmpty { currentPath.removeLast() }
        }
        currentPath.append(key)

        let fullPath = currentPath.joined(separator: ".")

        if fullPath.hasPrefix("config.flowchart.") || (fullPath == "flowchart" && value.isEmpty) {
            hasFlowchartSection = true
            if !value.isEmpty {
                let subKey = fullPath.replacingOccurrences(of: "config.flowchart.", with: "")
                switch subKey {
                case "curve": config.curve = value
                case "htmlLabels": config.htmlLabels = (value.lowercased() == "true")
                case "markdownAutoWrap": config.markdownAutoWrap = (value.lowercased() == "true")
                case "width": config.width = Int(value)
                case "inheritDir": config.inheritDir = (value.lowercased() == "true")
                default: break
                }
            }
        } else if fullPath == "flowchart", !value.isEmpty {
            hasFlowchartSection = true
            config.curve = value.isEmpty ? nil : value
        }
    }

    return hasFlowchartSection ? config : nil
}

/// Strip surrounding quotes from a string.
private func _unquote(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}
