import Foundation
import DiagramKitCommon

// MARK: - Public parse entry point

public func parseIshikawaDiagram(_ rawLines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (IshikawaDiagram, [DiagramDiagnostic]) {
    guard !rawLines.isEmpty else {
        throw IshikawaParserError.emptySource
    }

    let lines = _stripIshikawaBOM(rawLines)

    var diagram = IshikawaDiagram()
    if let fm = frontmatter {
        if let cfg = fm.perDiagram.ishikawa.config { diagram.config = cfg }
        if let theme = fm.shared.theme { diagram.themeName = theme }
        if let look = fm.shared.look { diagram.look = look }
        if let title = fm.shared.diagramTitle { diagram.diagramTitle = title }
    }

    let (root, dbTitle) = try _parseIshikawaTokens(_tokenizeIshikawa(lines))

    if let r = root {
        diagram.root = r
        diagram.diagramTitle = diagram.diagramTitle ?? dbTitle
    }

    return (diagram, [])
}

// MARK: - DB-level parser

private struct _StackEntry {
    let level: Int
    let nodeIndex: Int
}

private func _parseIshikawaTokens(_ tokens: [IshikawaToken]) throws -> (IshikawaNode?, String?) {
    var nodeTexts: [String] = []
    var childIndices: [[Int]] = []
    var stack: [_StackEntry] = []
    var baseLevel: Int?
    var diagramTitle: String?

    var pos = 0
    pos = _consumeIshikawaSpaceLines(tokens, pos: pos)

    guard pos < tokens.count, case .ishikawa = tokens[pos] else {
        throw IshikawaParserError.missingHeader
    }
    pos += 1

    if pos < tokens.count, case .nl = tokens[pos] {
        pos += 1
    }

    while pos < tokens.count {
        let token = tokens[pos]

        switch token {
        case .nl, .eof:
            pos += 1
            continue
        case .spaceLine:
            pos += 1
            continue
        case .spaceList(let rawLevel):
            pos += 1
            if pos < tokens.count, case .text(let label) = tokens[pos] {
                pos += 1
                let sanitized = _ishikawaSanitizeText(label)
                _addNodeIdx(&nodeTexts, &childIndices, &stack, rawLevel: rawLevel, text: sanitized, baseLevel: &baseLevel, diagramTitle: &diagramTitle)
            } else {
                pos += 1
            }
        case .text(let label):
            pos += 1
            let sanitized = _ishikawaSanitizeText(label)
            _addNodeIdx(&nodeTexts, &childIndices, &stack, rawLevel: 0, text: sanitized, baseLevel: &baseLevel, diagramTitle: &diagramTitle)
        case .ishikawa:
            pos += 1
            continue
        case .space:
            pos += 1
            continue
        }
    }

    guard !nodeTexts.isEmpty else { throw IshikawaParserError.missingRoot }

    let root = _buildIshikawaTree(nodeIndex: 0, nodeTexts: nodeTexts, childIndices: childIndices)
    return (root, diagramTitle)
}

private func _addNodeIdx(
    _ nodeTexts: inout [String],
    _ childIndices: inout [[Int]],
    _ stack: inout [_StackEntry],
    rawLevel: Int,
    text: String,
    baseLevel: inout Int?,
    diagramTitle: inout String?
) {
    if nodeTexts.isEmpty {
        nodeTexts.append(text)
        childIndices.append([])
        stack = [_StackEntry(level: 0, nodeIndex: 0)]
        diagramTitle = diagramTitle ?? text
        return
    }

    baseLevel = baseLevel ?? rawLevel
    let level = max(1, rawLevel - baseLevel! + 1)

    while stack.count > 1 && stack.last!.level >= level {
        stack.removeLast()
    }

    let parentIdx = stack.last!.nodeIndex
    let nodeIndex = nodeTexts.count
    nodeTexts.append(text)
    childIndices.append([])
    childIndices[parentIdx].append(nodeIndex)

    stack.append(_StackEntry(level: level, nodeIndex: nodeIndex))
}

private func _buildIshikawaTree(nodeIndex: Int, nodeTexts: [String], childIndices: [[Int]]) -> IshikawaNode {
    var node = IshikawaNode(text: nodeTexts[nodeIndex])
    node.children = childIndices[nodeIndex].map { childIdx in
        _buildIshikawaTree(nodeIndex: childIdx, nodeTexts: nodeTexts, childIndices: childIndices)
    }
    return node
}

// MARK: - Text sanitization

public func _ishikawaSanitizeText(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\n", with: "")
        .replacingOccurrences(of: "\\t", with: "\t")
}

// MARK: - Detector

public func _isIshikawaDiagramHeader(_ source: String) -> Bool {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let firstLine = normalized
        .split(separator: "\n", omittingEmptySubsequences: false)
        .first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && !trimmed.hasPrefix("%%")
        }?.trimmingCharacters(in: .whitespaces) ?? ""
    return firstLine.range(of: #"^ishikawa(-beta)?\b"#, options: [.regularExpression, .caseInsensitive]) != nil
}

// MARK: - Tokenizer

private enum IshikawaToken: Equatable {
    case ishikawa
    case spaceLine
    case spaceList(Int)
    case text(String)
    case nl
    case eof
    case space
}

private func _stripIshikawaBOM(_ lines: [String]) -> [String] {
    guard let first = lines.first, first.hasPrefix("\u{FEFF}") else {
        return lines
    }
    var cleaned = lines
    cleaned[0] = String(first.dropFirst())
    return cleaned
}

private func _tokenizeIshikawa(_ lines: [String]) -> [IshikawaToken] {
    var tokens: [IshikawaToken] = []

    for lineIndex in 0..<lines.count {
        let line = lines[lineIndex]

        if lineIndex > 0 {
            tokens.append(.nl)
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            tokens.append(.spaceLine)
            continue
        }

        if trimmed.hasPrefix("%%") {
            tokens.append(.spaceLine)
            continue
        }

        let ishikawaHeaderRegex = try! NSRegularExpression(pattern: #"^ishikawa(-beta)?\b"#, options: .caseInsensitive)
        let firstWord = trimmed.split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? trimmed
        let range = NSRange(firstWord.startIndex..., in: firstWord)
        if ishikawaHeaderRegex.firstMatch(in: firstWord, range: range) != nil {
            tokens.append(.ishikawa)
            if let fwRange = trimmed.range(of: firstWord) {
                let remainderStart = fwRange.upperBound
                if remainderStart < trimmed.endIndex {
                    let remainder = String(trimmed[remainderStart...]).trimmingCharacters(in: .whitespaces)
                    if !remainder.isEmpty {
                        tokens.append(.spaceList(1))
                        tokens.append(.text(remainder))
                    }
                }
            }
            continue
        }

        let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        if leadingSpaces > 0 {
            tokens.append(.spaceList(leadingSpaces))
        }
        tokens.append(.text(trimmed))
    }

    tokens.append(.eof)
    return tokens
}

private func _consumeIshikawaSpaceLines(_ tokens: [IshikawaToken], pos: Int) -> Int {
    var i = pos
    while i < tokens.count {
        switch tokens[i] {
        case .spaceLine, .nl:
            i += 1
        default:
            return i
        }
    }
    return i
}
