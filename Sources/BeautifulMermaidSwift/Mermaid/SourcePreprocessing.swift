import Foundation

func _preprocessMermaidSource(_ source: String) -> String {
    _stripMermaidFrontMatter(source)
}

func _mermaidSourceLines(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    _preprocessMermaidSource(source)
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
}

private func _stripMermaidFrontMatter(_ source: String) -> String {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    guard let startIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
          lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    else {
        return source
    }

    guard let endIndex = lines[(startIndex + 1)...].firstIndex(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    }) else {
        return source
    }

    return lines[(endIndex + 1)...].joined(separator: "\n")
}
