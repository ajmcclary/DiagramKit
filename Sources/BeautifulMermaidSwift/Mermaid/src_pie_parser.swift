import Foundation

// MARK: - Error types

public enum PieChartParserError: Error, LocalizedError {
    case invalidHeader(String)
    case negativeValue(String, Double)
    case invalidValue(String, String)
    case missingLabel(String)
    case invalidStatement(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let found):
            return "Invalid pie chart header. Expected 'pie', found '\(found)'."
        case .negativeValue(let label, let value):
            return "\"\(label)\" has invalid value: \(value). Negative values are not allowed in pie charts. All slice values must be >= 0."
        case .invalidValue(let label, let rawValue):
            return "Invalid value \"\(rawValue)\" for section \"\(label)\"."
        case .missingLabel(let line):
            return "Missing label for pie section: \"\(line)\"."
        case .invalidStatement(let line):
            return "Invalid pie chart statement: \"\(line)\"."
        }
    }
}

// MARK: - NUMBER_PIE validation regex

private let floatPiePattern = try! NSRegularExpression(pattern: #"^-?[0-9]+\.[0-9]+$"#)
private let intPiePattern = try! NSRegularExpression(pattern: #"^-?(0|[1-9][0-9]*)$"#)

private func isValidPieNumber(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
    return floatPiePattern.firstMatch(in: trimmed, range: range) != nil
        || intPiePattern.firstMatch(in: trimmed, range: range) != nil
}

// MARK: - Label unescaping

private func unescapePieLabel(_ raw: String) -> String {
    var result = ""
    var i = raw.startIndex
    while i < raw.endIndex {
        if raw[i] == "\\" {
            let next = raw.index(after: i)
            if next < raw.endIndex {
                let ch = raw[next]
                if ch == "\"" || ch == "'" || ch == "\\" {
                    result.append(ch)
                    i = raw.index(after: next)
                    continue
                }
            }
        }
        result.append(raw[i])
        i = raw.index(after: i)
    }
    return result
}

// MARK: - Title / Accessibility matching

private let accTitlePattern = try! NSRegularExpression(pattern: #"^[\t ]*accTitle[\t ]*:[\t ]*(.+)$"#)
private let accDescrPattern = try! NSRegularExpression(pattern: #"^[\t ]*accDescr[\t ]*:[\t ]*(.+)$"#)
private let accDescrOpenPattern = try! NSRegularExpression(pattern: #"^[\t ]*accDescr[\t ]*\{[\t ]*(.*)$"#)
private let accDescrClosePattern = try! NSRegularExpression(pattern: #"^[\t ]*\}([\t ]*)$"#)
private let titlePattern = try! NSRegularExpression(pattern: #"^[\t ]*title[\t ]+(.+)$"#)

private func firstMatch(in s: String, pattern: NSRegularExpression) -> String? {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    guard let match = pattern.firstMatch(in: s, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: s)
    else { return nil }
    return String(s[captureRange]).trimmingCharacters(in: .whitespaces)
}

private func matchLine(_ line: String, pattern: NSRegularExpression) -> Bool {
    let range = NSRange(line.startIndex..<line.endIndex, in: line)
    return pattern.firstMatch(in: line, range: range) != nil
}

// MARK: - Parse a section line: "Label" : value or 'Label' : value

private enum SectionLineResult {
    case section(label: String, value: String)
    case notASection
}

private func parseSectionLine(_ line: String) throws -> SectionLineResult {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return .notASection }

    let chars = Array(trimmed)
    guard chars.count > 0 else { return .notASection }

    let firstChar = chars[0]
    guard firstChar == "\"" || firstChar == "'" else {
        return .notASection
    }
    let quoteChar = firstChar

    var labelEnd = -1
    var i = 1
    while i < chars.count {
        if chars[i] == "\\" {
            i += 2
            continue
        }
        if chars[i] == quoteChar {
            labelEnd = i
            break
        }
        i += 1
    }

    guard labelEnd > 0 else {
        throw PieChartParserError.missingLabel(trimmed)
    }

    let labelContent = String(chars[1..<labelEnd])
    let label = unescapePieLabel(labelContent)

    let afterLabel = chars[(labelEnd + 1)...]
    guard let colonIdx = afterLabel.firstIndex(of: ":") else {
        throw PieChartParserError.missingLabel(trimmed)
    }

    let valueStr = String(afterLabel[afterLabel.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
    guard !valueStr.isEmpty else {
        throw PieChartParserError.invalidValue(label, "")
    }

    return .section(label: label, value: valueStr)
}

// MARK: - Public API

public func parsePieChart(_ source: String) throws -> PieChart {
    let lines = _mermaidSourceLines(from: source)
    return try parsePieChart(lines, frontmatter: nil)
}

public func parsePieChart(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> PieChart {
    var chart = PieChart()

    guard !lines.isEmpty else {
        throw PieChartParserError.invalidHeader("")
    }

    var lineIndex = 0

    // Step 1: Parse header line
    var headerLine = lines[lineIndex]
    while headerLine.isEmpty || headerLine.hasPrefix("%%") {
        lineIndex += 1
        guard lineIndex < lines.count else {
            throw PieChartParserError.invalidHeader("")
        }
        headerLine = lines[lineIndex]
    }

    let trimmed = headerLine.trimmingCharacters(in: .whitespaces)
    guard trimmed.lowercased().hasPrefix("pie") else {
        throw PieChartParserError.invalidHeader(trimmed)
    }

    // Step 2: Extract optional showData
    var remainder = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    if remainder.lowercased().hasPrefix("showdata") {
        chart.showData = true
        remainder = String(remainder.dropFirst(8)).trimmingCharacters(in: .whitespaces)
    } else {
        chart.showData = false
    }

    // Step 3: Parse TitleAndAccessibilities on the header line remainder
    var nextLineIndex = lineIndex + 1
    if !remainder.isEmpty {
        if let titleMatch = firstMatch(in: remainder, pattern: titlePattern) {
            chart.diagramTitle = titleMatch
        } else if remainder.lowercased().hasPrefix("title") {
            throw PieChartParserError.invalidStatement(remainder)
        }
        if let accTitleMatch = firstMatch(in: remainder, pattern: accTitlePattern) {
            chart.accTitle = accTitleMatch
        } else if remainder.lowercased().hasPrefix("acctitle") {
            throw PieChartParserError.invalidStatement(remainder)
        }
        if let accDescrMatch = firstMatch(in: remainder, pattern: accDescrPattern) {
            chart.accDescr = accDescrMatch
        } else if let accDescrOpenMatch = firstMatch(in: remainder, pattern: accDescrOpenPattern) {
            if remainder.hasSuffix("}") {
                let stripped = String(accDescrOpenMatch.dropLast()).trimmingCharacters(in: .whitespaces)
                chart.accDescr = stripped.isEmpty ? nil : stripped
            } else {
                lineIndex = nextLineIndex
                var accLines: [String] = [accDescrOpenMatch]
                var didCloseBlock = false
                while lineIndex < lines.count {
                    let l = lines[lineIndex]
                    let trimmedL = l.trimmingCharacters(in: .whitespaces)
                    // Close marker: line is exactly "}" or ends with "}"
                    if trimmedL == "}" || trimmedL.hasSuffix("}") {
                        // Include any content before the "}" on this line
                        let beforeBrace = trimmedL.hasSuffix("}") ? String(trimmedL.dropLast()).trimmingCharacters(in: .whitespaces) : ""
                        if !beforeBrace.isEmpty {
                            accLines.append(beforeBrace)
                        }
                        lineIndex += 1
                        didCloseBlock = true
                        break
                    }
                    accLines.append(l)
                    lineIndex += 1
                }
                guard didCloseBlock else {
                    throw PieChartParserError.invalidStatement(remainder)
                }
                chart.accDescr = accLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                nextLineIndex = lineIndex
            }
        } else if remainder.lowercased().hasPrefix("accdescr") {
            throw PieChartParserError.invalidStatement(remainder)
        } else if chart.diagramTitle == nil && chart.accTitle == nil && chart.accDescr == nil {
            throw PieChartParserError.invalidStatement(remainder)
        }
    }

    lineIndex = nextLineIndex

    // Step 4-5: Parse subsequent lines
    var usedLabels = Set<String>()
    var inAccDescrBlock = false
    var accDescrBlockLines: [String] = []

    while lineIndex < lines.count {
        let rawLine = lines[lineIndex]
        let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
        lineIndex += 1

        // Skip blank lines and comments
        if trimmedLine.isEmpty || trimmedLine.hasPrefix("%%") {
            continue
        }

        // AccDescr multiline block open
        if !inAccDescrBlock, firstMatch(in: trimmedLine, pattern: accDescrOpenPattern) != nil {
            inAccDescrBlock = true
            let openContent = firstMatch(in: trimmedLine, pattern: accDescrOpenPattern) ?? ""
            if trimmedLine.hasSuffix("}") {
                let stripped = String(openContent.dropLast()).trimmingCharacters(in: .whitespaces)
                chart.accDescr = stripped.isEmpty ? nil : stripped
            } else {
                accDescrBlockLines = [openContent]
            }
            continue
        }

        // AccDescr multiline block close
        if inAccDescrBlock {
            // Close marker: line ends with "}" after trimming
            if trimmedLine.hasSuffix("}") {
                let beforeBrace = String(trimmedLine.dropLast()).trimmingCharacters(in: .whitespaces)
                if !beforeBrace.isEmpty {
                    accDescrBlockLines.append(beforeBrace)
                }
                chart.accDescr = accDescrBlockLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
                inAccDescrBlock = false
                accDescrBlockLines = []
            } else {
                accDescrBlockLines.append(trimmedLine)
            }
            continue
        }

        // Single-line accTitle
        if let accTitleMatch = firstMatch(in: trimmedLine, pattern: accTitlePattern) {
            chart.accTitle = accTitleMatch
            continue
        }

        // Single-line accDescr
        if let accDescrMatch = firstMatch(in: trimmedLine, pattern: accDescrPattern) {
            chart.accDescr = accDescrMatch
            continue
        }

        // Title
        if let titleMatch = firstMatch(in: trimmedLine, pattern: titlePattern) {
            chart.diagramTitle = titleMatch
            continue
        }

        // Section line
        let sectionResult = try parseSectionLine(trimmedLine)
        switch sectionResult {
        case .section(let label, let valueStr):
            guard isValidPieNumber(valueStr) else {
                throw PieChartParserError.invalidValue(label, valueStr)
            }
            guard let value = Double(valueStr) else {
                throw PieChartParserError.invalidValue(label, valueStr)
            }
            guard value >= 0 else {
                throw PieChartParserError.negativeValue(label, value)
            }
            if !usedLabels.contains(label) {
                usedLabels.insert(label)
                chart.sections.append(PieSection(label: label, value: value))
            }
        case .notASection:
            throw PieChartParserError.invalidStatement(trimmedLine)
        }
    }

    // Apply frontmatter overrides
    if let fm = frontmatter {
        if let cfg = fm.pieConfig { chart.config = cfg }
        if let theme = fm.pieTheme { chart.theme = theme }
        if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle {
            chart.diagramTitle = fmTitle
        }
    }

    return chart
}
