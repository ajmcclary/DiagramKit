import Foundation
import DiagramKitCommon

// MARK: - Packet Parser Error

public enum PacketParserError: Error, LocalizedError, _MermaidRecoverableError {
    case missingHeader
    case invalidHeader(String)
    case malformedBlock(String)
    case missingLabel(String)
    case unquotedLabel(String)
    case unterminatedString
    case invalidRange(Int, Int)
    case zeroBitField
    case notContiguous(expected: Int, found: Int)
    case maxPacketSizeExceeded

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "Missing packet header. Expected 'packet' or 'packet-beta'."
        case .invalidHeader(let header):
            return "Invalid packet header: \(header)"
        case .malformedBlock(let line):
            return "Malformed packet block: \(line)"
        case .missingLabel(let line):
            return "Missing label for packet block: \(line)"
        case .unquotedLabel(let line):
            return "Packet block label must be quoted: \(line)"
        case .unterminatedString:
            return "Unterminated string in packet diagram."
        case .invalidRange(let start, let end):
            return "Invalid range: end (\(end)) is less than start (\(start))."
        case .zeroBitField:
            return "Packet block has zero bits. Bit count must be positive."
        case .notContiguous(let expected, let found):
            return "Packet blocks must be contiguous. Expected start \(expected), found \(found)."
        case .maxPacketSizeExceeded:
            return "Packet diagram exceeds maximum row limit of 10,000."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingHeader:
            return "Add 'packet' or 'packet-beta' as the first line."
        case .invalidHeader:
            return "The header must be 'packet' or 'packet-beta'."
        case .malformedBlock:
            return "Use the format: start-end: \"Label\" or +count: \"Label\"."
        case .missingLabel:
            return "Add a quoted label after the colon."
        case .unquotedLabel:
            return "Wrap the label in double quotes: \"Label\"."
        case .unterminatedString:
            return "Close the string with a matching quote character."
        case .invalidRange:
            return "Ensure end is greater than or equal to start."
        case .zeroBitField:
            return "Use a positive bit count, e.g. +8: \"Label\"."
        case .notContiguous:
            return "Ensure blocks are adjacent with no gaps."
        case .maxPacketSizeExceeded:
            return "Reduce the number of rows or increase bitsPerRow."
        }
    }
}

// MARK: - Public entry point

func parsePacketDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> PacketDiagram {
    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?
    var rawBlocks: [RawPacketBlock] = []

    // Parse title and accessibility from frontmatter first
    if let fm = frontmatter {
        diagramTitle = fm.diagramTitle
    }

    var i = 0
    var foundHeader = false
    var inAccDescrMultiline = false
    var accDescrLines: [String] = []

    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip blank lines and comments
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            i += 1
            continue
        }

        // Handle multiline accDescr
        if inAccDescrMultiline {
            if trimmed == "}" {
                inAccDescrMultiline = false
                accDescr = accDescrLines.joined(separator: " ")
            } else {
                accDescrLines.append(trimmed)
            }
            i += 1
            continue
        }

        // Check for header
        if !foundHeader {
            let lower = trimmed.lowercased()
            if lower == "packet" || lower == "packet-beta" {
                foundHeader = true
                i += 1
                continue
            }
            throw PacketParserError.missingHeader
        }

        // Parse statements
        let lower = trimmed.lowercased()

        // title — keyword followed by space or tab
        if lower.hasPrefix("title"), _hasWhitespaceAfterKeyword(trimmed, len: 5) {
            let titleValue = _valueAfterKeyword(trimmed, len: 5)
            diagramTitle = _unquoteString(titleValue)
            i += 1
            continue
        }

        // accTitle — keyword followed by optional whitespace then colon
        if lower.hasPrefix("acctitle"), let value = _valueAfterColon(trimmed, keywordLen: 8) {
            accTitle = _unquoteString(value)
            i += 1
            continue
        }

        // accDescr (multiline with brace)
        if lower.hasPrefix("accdescr"), let braceContent = _valueInBraces(trimmed, keywordLen: 8) {
            accDescr = braceContent
            i += 1
            continue
        }

        // accDescr (multiline across lines)
        if lower.hasPrefix("accdescr"), _hasMultilineOpen(trimmed, len: 8) {
            inAccDescrMultiline = true
            accDescrLines = []
            i += 1
            continue
        }

        // accDescr — keyword followed by optional whitespace then colon
        if lower.hasPrefix("accdescr"), let value = _valueAfterColon(trimmed, keywordLen: 8) {
            accDescr = _unquoteString(value)
            i += 1
            continue
        }

        // accDescr — keyword followed by whitespace without colon (progressive enhancement)
        if lower.hasPrefix("accdescr"), _hasWhitespaceAfterKeyword(trimmed, len: 8) {
            let value = _valueAfterKeyword(trimmed, len: 9)
            accDescr = _unquoteString(value)
            i += 1
            continue
        }

        // Parse block
        let block = try _parsePacketBlockLine(trimmed)
        rawBlocks.append(block)
        i += 1
    }

    guard foundHeader else {
        throw PacketParserError.missingHeader
    }

    // Build config from frontmatter, clamped to schema minimums
    var config = frontmatter?.packetConfig ?? PacketDiagramConfig.default
    config = config.clampedToMinimums
    let theme = frontmatter?.packetTheme ?? PacketThemeConfig.default

    // Normalize blocks (contiguity, defaults, row splitting)
    let rows = try normalizePacketBlocks(rawBlocks, config: config)

    // Frontmatter title does not override source title
    if diagramTitle == nil, let fmTitle = frontmatter?.diagramTitle, frontmatter?.title != nil {
        diagramTitle = fmTitle
    }

    return PacketDiagram(
        rows: rows,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: config,
        theme: theme
    )
}

// MARK: - Block line parsing

private let blockPrefixPattern = try! NSRegularExpression(
    pattern: #"^\s*(\+)?\s*(\d+)(?:\s*-\s*(\d+))?\s*:\s*(.*)$"#,
    options: []
)

private func _parsePacketBlockLine(_ trimmed: String) throws -> RawPacketBlock {
    guard let match = blockPrefixPattern.firstMatch(
        in: trimmed,
        options: [],
        range: NSRange(trimmed.startIndex..., in: trimmed)
    ) else {
        throw PacketParserError.malformedBlock(trimmed)
    }

    let nsString = trimmed as NSString

    let isBitCount = match.range(at: 1).location != NSNotFound

    let startStr = nsString.substring(with: match.range(at: 2))
    guard let startVal = Int(startStr) else {
        throw PacketParserError.malformedBlock(trimmed)
    }

    let hasRange = match.range(at: 3).location != NSNotFound
    var endVal: Int?
    if hasRange {
        endVal = Int(nsString.substring(with: match.range(at: 3)))
    }

    let labelRaw = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

    // Parse the quoted label (support double and single quotes)
    // Check for missing label first
    if labelRaw.isEmpty {
        throw PacketParserError.malformedBlock(trimmed)
    }

    let label = try _parseQuotedLabel(labelRaw)

    if isBitCount {
        return RawPacketBlock(start: nil, end: nil, bits: startVal, label: label)
    } else if hasRange {
        return RawPacketBlock(start: startVal, end: endVal, bits: nil, label: label)
    } else {
        // Single-bit field
        return RawPacketBlock(start: startVal, end: nil, bits: nil, label: label)
    }
}

// MARK: - Quoted string parsing

private func _parseQuotedLabel(_ raw: String) throws -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)

    guard let firstChar = trimmed.first, firstChar == "\"" || firstChar == "'" else {
        throw PacketParserError.unquotedLabel(raw)
    }

    let quote = firstChar
    var result = ""
    var i = trimmed.index(after: trimmed.startIndex)
    var escaped = false

    while i < trimmed.endIndex {
        let ch = trimmed[i]
        if escaped {
            switch ch {
            case "n": result.append("\n")
            case "t": result.append("\t")
            case "r": result.append("\r")
            case "\\": result.append("\\")
            case "\"": result.append("\"")
            case "'": result.append("'")
            default: result.append(ch)
            }
            escaped = false
            i = trimmed.index(after: i)
            continue
        }
        if ch == "\\" {
            escaped = true
            i = trimmed.index(after: i)
            continue
        }
        if ch == quote {
            let afterQuote = trimmed.index(after: i)
            let remainder = String(trimmed[afterQuote...]).trimmingCharacters(in: .whitespaces)
            if remainder.isEmpty || remainder.hasPrefix("%%") {
                return result
            }
            throw PacketParserError.malformedBlock(raw)
        }
        result.append(ch)
        i = trimmed.index(after: i)
    }

    throw PacketParserError.unterminatedString
}

private func _unquoteString(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}

// MARK: - Whitespace-flexible keyword matchers

private func _hasWhitespaceAfterKeyword(_ s: String, len: Int) -> Bool {
    guard len < s.count else { return false }
    let ch = s[s.index(s.startIndex, offsetBy: len)]
    return ch == " " || ch == "\t"
}

private func _hasMultilineOpen(_ s: String, len: Int) -> Bool {
    var idx = s.index(s.startIndex, offsetBy: len)
    while idx < s.endIndex && (s[idx] == " " || s[idx] == "\t") {
        idx = s.index(after: idx)
    }
    return idx < s.endIndex && s[idx] == "{"
}

private func _valueInBraces(_ s: String, keywordLen: Int) -> String? {
    var idx = s.index(s.startIndex, offsetBy: keywordLen)
    while idx < s.endIndex && (s[idx] == " " || s[idx] == "\t") {
        idx = s.index(after: idx)
    }
    guard idx < s.endIndex, s[idx] == "{" else { return nil }
    idx = s.index(after: idx)
    let startIdx = idx
    while idx < s.endIndex && s[idx] != "}" {
        idx = s.index(after: idx)
    }
    guard idx < s.endIndex, s[idx] == "}" else { return nil }
    return String(s[startIdx..<idx]).trimmingCharacters(in: .whitespaces)
}

private func _valueAfterColon(_ s: String, keywordLen: Int) -> String? {
    var idx = s.index(s.startIndex, offsetBy: keywordLen)
    while idx < s.endIndex && (s[idx] == " " || s[idx] == "\t") {
        idx = s.index(after: idx)
    }
    guard idx < s.endIndex, s[idx] == ":" else { return nil }
    idx = s.index(after: idx)
    return String(s[idx...]).trimmingCharacters(in: .whitespaces)
}

private func _valueAfterKeyword(_ s: String, len: Int) -> String {
    let idx = s.index(s.startIndex, offsetBy: len)
    return String(s[idx...]).trimmingCharacters(in: .whitespaces)
}

// MARK: - Normalization

func normalizePacketBlocks(
    _ blocks: [RawPacketBlock],
    config: PacketDiagramConfig
) throws -> [PacketRow] {
    if blocks.isEmpty {
        return []
    }

    let maxRows = 10_000
    var rows: [PacketRow] = []
    var currentRow: PacketRow = []
    var lastBit = -1
    var currentRowStartBit = 0

    func pushCurrentRowIfNeeded() throws {
        if !currentRow.isEmpty {
            rows.append(currentRow)
            if rows.count > maxRows {
                throw PacketParserError.maxPacketSizeExceeded
            }
        }
        currentRow = []
    }

    for raw in blocks {
        // Compute start
        let start: Int
        if let s = raw.start {
            start = s
        } else {
            start = lastBit + 1
        }

        // Compute end and bits
        var end: Int
        var bits: Int
        if let b = raw.bits {
            // +count form
            bits = b
            end = start + bits - 1
        } else if let e = raw.end {
            // explicit range
            end = e
            bits = end - start + 1
        } else {
            // single bit
            end = start
            bits = 1
        }

        // Validation: for explicit ranges, check start > end first
        // For +count forms, check zero-bit first
        if raw.start != nil && raw.end == nil && raw.bits == nil {
            // Single-bit block: no range validation needed
        } else if raw.start != nil && raw.end != nil {
            // Explicit range: check range validity before bits
            if end < start {
                throw PacketParserError.invalidRange(start, end)
            }
            if bits <= 0 {
                throw PacketParserError.zeroBitField
            }
        } else {
            // +count form: check bits first
            if bits <= 0 {
                throw PacketParserError.zeroBitField
            }
            if end < start {
                throw PacketParserError.invalidRange(start, end)
            }
        }
        if start != lastBit + 1 {
            throw PacketParserError.notContiguous(expected: lastBit + 1, found: start)
        }
        lastBit = end

        // Row splitting
        let bitsPerRow = config.bitsPerRow
        var segmentStart = start
        let segmentEnd = end
        var segmentBits = bits

        while true {
            let rowBoundary = currentRowStartBit + bitsPerRow

            if segmentEnd + 1 <= rowBoundary {
                currentRow.append(PacketBlock(start: segmentStart, end: segmentEnd, bits: segmentBits, label: raw.label))

                if segmentEnd + 1 == rowBoundary {
                    try pushCurrentRowIfNeeded()
                    currentRowStartBit = segmentEnd + 1
                }
                break
            }

            let splitEnd = rowBoundary - 1
            // Mermaid stores split segment bit counts without the inclusive +1.
            // Keep that parser-visible metadata while layout uses start/end.
            let splitBits = splitEnd - segmentStart

            let firstBlock = PacketBlock(start: segmentStart, end: splitEnd, bits: splitBits, label: raw.label)
            currentRow.append(firstBlock)

            try pushCurrentRowIfNeeded()
            currentRowStartBit = splitEnd + 1
            segmentStart = currentRowStartBit
            segmentBits = segmentEnd - segmentStart
        }
    }

    // Push final non-empty row
    try pushCurrentRowIfNeeded()

    return rows
}
