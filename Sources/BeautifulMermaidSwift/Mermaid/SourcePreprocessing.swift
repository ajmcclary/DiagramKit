import Foundation

/// Result of preprocessing: the stripped diagram source and any parsed frontmatter.
typealias _PreprocessResult = (source: String, frontmatter: DiagramFrontmatter?)

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
/// Returns the stripped diagram source and any parsed DiagramFrontmatter.
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
    let frontmatter = _parseYamlFrontmatter(fmLines)
    return (stripped, frontmatter)
}

/// Extended YAML parser for Mermaid frontmatter.
/// Handles: title, class.*, config.class.*, config.flowchart.*
private func _parseYamlFrontmatter(_ lines: [String]) -> DiagramFrontmatter? {
    var frontmatter = DiagramFrontmatter()
    var flowchartConfig = original_src_types.FlowchartConfig()
    var hasFlowchartSection = false
    var classConfig = ClassConfig()
    var hasClassSection = false
    var hasAnyContent = false

    var currentPath: [String] = []
    // Track the last depth to know if we're going deeper or staying at same level
    var lastDepth = -1

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        let indent = line.prefix(while: { $0 == " " }).count
        let bare = trimmed

        // Remove the part after "#" (comment)
        let commentStripped: String
        if let hashIdx = bare.firstIndex(of: "#") {
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
        // Only remove the previous entry at this depth if we're at the SAME level (not child/parent)
        if currentPath.count == depth && depth > 0 && depth <= lastDepth {
            currentPath.removeLast()
        }
        currentPath.append(key)
        lastDepth = depth

        let fullPath = currentPath.joined(separator: ".")

        hasAnyContent = true

        // title at root level
        if fullPath == "title" && !value.isEmpty {
            frontmatter.title = value
            continue
        }

        // class.* config
        if fullPath.hasPrefix("class.") {
            hasClassSection = true
            let subKey = fullPath.replacingOccurrences(of: "class.", with: "")
            switch subKey {
            case "hideEmptyMembersBox":
                classConfig.hideEmptyMembersBox = (value.lowercased() == "true")
            case "hierarchicalNamespaces":
                classConfig.hierarchicalNamespaces = (value.lowercased() == "true")
            case "padding":
                classConfig.padding = Double(value)
            default: break
            }
            continue
        }

        // config.class.* (alternative nesting)
        if fullPath.hasPrefix("config.class.") {
            hasClassSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.class.", with: "")
            switch subKey {
            case "hideEmptyMembersBox":
                classConfig.hideEmptyMembersBox = (value.lowercased() == "true")
            case "hierarchicalNamespaces":
                classConfig.hierarchicalNamespaces = (value.lowercased() == "true")
            case "padding":
                classConfig.padding = Double(value)
            default: break
            }
            continue
        }

        // flowchart config (backward compatible)
        if fullPath.hasPrefix("config.flowchart.") || (fullPath == "flowchart" && value.isEmpty) {
            hasFlowchartSection = true
            if !value.isEmpty {
                let subKey = fullPath.replacingOccurrences(of: "config.flowchart.", with: "")
                switch subKey {
                case "curve": flowchartConfig.curve = value
                case "htmlLabels": flowchartConfig.htmlLabels = (value.lowercased() == "true")
                case "markdownAutoWrap": flowchartConfig.markdownAutoWrap = (value.lowercased() == "true")
                case "width": flowchartConfig.width = Int(value)
                case "inheritDir": flowchartConfig.inheritDir = (value.lowercased() == "true")
                default: break
                }
            }
            continue
        } else if fullPath == "flowchart" && !value.isEmpty {
            hasFlowchartSection = true
            flowchartConfig.curve = value.isEmpty ? nil : value
        }
    }

    if hasFlowchartSection { frontmatter.flowchartConfig = flowchartConfig }
    if hasClassSection { frontmatter.classConfig = classConfig }

    return hasAnyContent ? frontmatter : nil
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
