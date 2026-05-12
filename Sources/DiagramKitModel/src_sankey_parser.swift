import Foundation
import DiagramKitCommon

public enum SankeyParserError: Error, LocalizedError, _RecoverableDiagramError {
    case missingHeader
    case invalidHeader(String)
    case malformedRecord(line: Int, text: String)
    case unterminatedQuote(line: Int)
    case strayQuote(line: Int)
    case invalidValue(line: Int, raw: String)

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "Sankey diagram source is missing a 'sankey' or 'sankey-beta' header."
        case .invalidHeader(let found):
            return "Invalid Sankey header. Expected 'sankey' or 'sankey-beta', found '\(found)'."
        case .malformedRecord(let line, let text):
            return "Malformed Sankey record at line \(line): '\(text)' — expected exactly 3 CSV columns (source,target,value)."
        case .unterminatedQuote(let line):
            return "Unterminated double quote in Sankey source at line \(line)."
        case .strayQuote(let line):
            return "Stray double quote at unexpected position in Sankey source around line \(line)."
        case .invalidValue(let line, let raw):
            return "Invalid numeric value at line \(line): '\(raw)'."
        }
    }
}

public func parseSankeyDiagram(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> SankeyDiagram {
    try _withDiagramIssueReporting(operation: "parseSankeyDiagram") {
        let source = lines.joined(separator: "\n")
        let prepared = _prepareSankeyText(source)
        let preprocessedLines = _mermaidSourceLines(from: prepared, separatedBy: CharacterSet(charactersIn: "\n"))

        guard let firstNonComment = preprocessedLines.first(where: { !$0.isEmpty && !$0.hasPrefix("%%") }),
              firstNonComment.lowercased().hasPrefix("sankey") else {
            throw SankeyParserError.missingHeader
        }

        var sankeyConfig = SankeyDiagramConfig()
        if let fm = frontmatter, let sc = fm.sankeyConfig {
            sankeyConfig = sc
        }

        let headerLine = firstNonComment.lowercased().trimmingCharacters(in: .whitespaces)
        if headerLine != "sankey" && headerLine != "sankey-beta" {
            throw SankeyParserError.invalidHeader(firstNonComment.trimmingCharacters(in: .whitespaces))
        }

        let headerIndex = preprocessedLines.firstIndex(of: firstNonComment) ?? 0
        let csvLines = Array(preprocessedLines.dropFirst(headerIndex + 1))
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }

        let records = try _tokenizeSankeyCSV(csvLines)
        return try _buildSankeyDiagram(records: records, config: sankeyConfig, frontmatter: frontmatter)
    }
}

private func _prepareSankeyText(_ source: String) -> String {
    var text = source
    text = text.replacingOccurrences(of: "\r\n", with: "\n")
    text = text.replacingOccurrences(of: "\r", with: "\n")
    let rows = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let trimmedRows = rows.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \t")) }
    text = trimmedRows.joined(separator: "\n")
    while text.contains("\n\n\n") {
        text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return text
}

private func _parseFloatCompat(_ raw: String) -> Double {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return .nan }

    var index = text.startIndex
    if text[index] == "+" || text[index] == "-" {
        index = text.index(after: index)
    }

    guard index < text.endIndex else { return .nan }

    if text[index...].hasPrefix("Infinity") {
        return text.first == "-" ? -.infinity : .infinity
    }

    var integerDigits = 0
    while index < text.endIndex, _isSankeyDigit(text[index]) {
        integerDigits += 1
        index = text.index(after: index)
    }

    var fractionalDigits = 0
    if index < text.endIndex, text[index] == "." {
        index = text.index(after: index)
        while index < text.endIndex, _isSankeyDigit(text[index]) {
            fractionalDigits += 1
            index = text.index(after: index)
        }
    }

    guard integerDigits + fractionalDigits > 0 else { return .nan }

    var numberEnd = index
    if index < text.endIndex, text[index] == "e" || text[index] == "E" {
        var exponentIndex = text.index(after: index)
        if exponentIndex < text.endIndex,
           text[exponentIndex] == "+" || text[exponentIndex] == "-" {
            exponentIndex = text.index(after: exponentIndex)
        }

        var exponentDigits = 0
        while exponentIndex < text.endIndex, _isSankeyDigit(text[exponentIndex]) {
            exponentDigits += 1
            exponentIndex = text.index(after: exponentIndex)
        }

        if exponentDigits > 0 {
            numberEnd = exponentIndex
        }
    }

    return Double(text[..<numberEnd]) ?? .nan
}

private func _isSankeyDigit(_ ch: Character) -> Bool {
    ch >= "0" && ch <= "9"
}

private struct _SankeyRecord {
    let source: String
    let target: String
    let value: String
    let line: Int
}

private func _tokenizeSankeyCSV(_ lines: [String]) throws -> [_SankeyRecord] {
    var records: [_SankeyRecord] = []
    var lineNumber = 0

    for line in lines {
        lineNumber += 1
        let fields = try _tokenizeCSVLine(line, lineNumber: lineNumber)
        if fields.isEmpty { continue }
        guard fields.count == 3 else {
            throw SankeyParserError.malformedRecord(line: lineNumber, text: line)
        }
        records.append(_SankeyRecord(
            source: fields[0],
            target: fields[1],
            value: fields[2],
            line: lineNumber
        ))
    }
    return records
}

private func _tokenizeCSVLine(_ line: String, lineNumber: Int) throws -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuoted = false
    var i = line.startIndex

    while i < line.endIndex {
        let ch = line[i]

        if inQuoted {
            if ch == "\"" {
                let nextIdx = line.index(after: i)
                if nextIdx < line.endIndex && line[nextIdx] == "\"" {
                    current.append("\"")
                    i = line.index(after: nextIdx)
                } else {
                    inQuoted = false
                    i = line.index(after: i)
                }
            } else {
                current.append(ch)
                i = line.index(after: i)
            }
        } else {
            if ch == "\"" {
                if current.isEmpty {
                    inQuoted = true
                    i = line.index(after: i)
                } else {
                    throw SankeyParserError.strayQuote(line: lineNumber)
                }
            } else if ch == "," {
                fields.append(_trimField(current))
                current = ""
                i = line.index(after: i)
            } else {
                current.append(ch)
                i = line.index(after: i)
            }
        }
    }

    if inQuoted {
        throw SankeyParserError.unterminatedQuote(line: lineNumber)
    }
    fields.append(_trimField(current))
    return fields
}

private func _trimField(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespaces)
}

private func _buildSankeyDiagram(
    records: [_SankeyRecord],
    config: SankeyDiagramConfig,
    frontmatter: DiagramFrontmatter?
) throws -> SankeyDiagram {
    var nodeMap: [String: SankeyNode] = [:]
    var nodes: [SankeyNode] = []
    var links: [SankeyLink] = []

    for record in records {
        let sourceRaw = _processNodeId(record.source)
        let targetRaw = _processNodeId(record.target)
        let sourceID = _sanitizeSankeyText(sourceRaw)
        let targetID = _sanitizeSankeyText(targetRaw)
        let value = _parseFloatCompat(record.value)

        let sourceNode: SankeyNode
        if let existing = nodeMap[sourceID] {
            sourceNode = existing
        } else {
            sourceNode = SankeyNode(id: sourceID, rawID: sourceRaw)
            nodeMap[sourceID] = sourceNode
            nodes.append(sourceNode)
        }

        let targetNode: SankeyNode
        if let existing = nodeMap[targetID] {
            targetNode = existing
        } else {
            targetNode = SankeyNode(id: targetID, rawID: targetRaw)
            nodeMap[targetID] = targetNode
            nodes.append(targetNode)
        }

        let link = SankeyLink(source: sourceNode, target: targetNode, value: value)
        links.append(link)
    }

    return SankeyDiagram(
        nodes: nodes,
        links: links,
        config: config,
        diagramTitle: frontmatter?.diagramTitle,
        accTitle: frontmatter?.title,
        accDescr: nil
    )
}

private func _processNodeId(_ raw: String) -> String {
    raw
}

private func _sanitizeSankeyText(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    result = result.replacingOccurrences(of: "\\n", with: "")
    result = result.replacingOccurrences(of: "\\t", with: "\t")
    while let scriptRange = result.range(of: "<script", options: .caseInsensitive) {
        let searchStart = scriptRange.upperBound
        if let closeRange = result[searchStart...].range(of: ">") {
            result.removeSubrange(scriptRange.lowerBound..<closeRange.upperBound)
        } else {
            result.removeSubrange(scriptRange.lowerBound..<result.endIndex)
        }
    }
    result = result.replacingOccurrences(of: "</script>", with: "", options: .caseInsensitive)
    result = result.replacingOccurrences(of: "javascript:", with: "", options: .caseInsensitive)
    return result
}
