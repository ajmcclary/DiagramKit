import Foundation
import DiagramKitCommon

// MARK: - Error types

public enum QuadrantChartParserError: Error, LocalizedError {
    case invalidHeader(String)
    case invalidStatement(String)
    case invalidStyleName(String)
    case invalidStyleValue(style: String, value: String, expected: String)
    case invalidPointCoordinate(String, Double)
    case missingPointCoordinate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let found):
            return "Invalid quadrant chart header. Expected 'quadrantChart', found '\(found)'."
        case .invalidStatement(let line):
            return "Invalid quadrant chart statement: \"\(line)\"."
        case .invalidStyleName(let name):
            return "style named \(name) is not supported."
        case .invalidStyleValue(let style, let value, let expected):
            return "value for \(style) \(value) is invalid, please use a valid \(expected)"
        case .invalidPointCoordinate(let label, let value):
            return "Invalid coordinate value \(value) for point \"\(label)\". Must be 0, 1, or 0 with decimal digits (e.g. 0.5)."
        case .missingPointCoordinate(let label):
            return "Missing coordinate for point \"\(label)\"."
        }
    }
}

// MARK: - Coordinate validation (matches Jison lexer token shapes)

private let pointCoordinatePattern = try! NSRegularExpression(pattern: #"^(1|0(\.\d+)?)$"#)
private let hexCodePattern = try! NSRegularExpression(pattern: #"^#?([\dA-Fa-f]{6}|[\dA-Fa-f]{3})$"#)
private let pixelsPattern = try! NSRegularExpression(pattern: #"^\d+px$"#)
private let intPattern = try! NSRegularExpression(pattern: #"^\d+$"#)

private func isValidPointCoordinate(_ s: String) -> Bool {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    return pointCoordinatePattern.firstMatch(in: s, range: range) != nil
}

private func isValidHexCode(_ s: String) -> Bool {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    return hexCodePattern.firstMatch(in: s, range: range) != nil
}

private func isValidPixels(_ s: String) -> Bool {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    return pixelsPattern.firstMatch(in: s, range: range) != nil
}

private func isValidInt(_ s: String) -> Bool {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    return intPattern.firstMatch(in: s, range: range) != nil
}

// MARK: - Style parsing (port of parseStyles from quadrantDb.ts)

private func parseStyles(_ styles: [String]) throws -> QuadrantPointStyles {
    var stylesObject = QuadrantPointStyles()

    for style in styles {
        let parts = style.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: ":")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else {
            throw QuadrantChartParserError.invalidStatement(style)
        }
        let key = parts[0]
        let value = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

        switch key {
        case "radius":
            guard isValidInt(value) else {
                throw QuadrantChartParserError.invalidStyleValue(style: key, value: value, expected: "number")
            }
            stylesObject.radius = Int(value)
        case "color":
            guard isValidHexCode(value) else {
                throw QuadrantChartParserError.invalidStyleValue(style: key, value: value, expected: "hex code")
            }
            stylesObject.color = value
        case "stroke-color":
            guard isValidHexCode(value) else {
                throw QuadrantChartParserError.invalidStyleValue(style: key, value: value, expected: "hex code")
            }
            stylesObject.strokeColor = value
        case "stroke-width":
            guard isValidPixels(value) else {
                throw QuadrantChartParserError.invalidStyleValue(style: key, value: value, expected: "number of pixels (eg. 10px)")
            }
            stylesObject.strokeWidth = value
        default:
            throw QuadrantChartParserError.invalidStyleName(key)
        }
    }

    return stylesObject
}

// MARK: - Title / Accessibility matching

private let accTitlePattern = try! NSRegularExpression(pattern: #"^accTitle\s*:\s*(.+)$"#, options: .caseInsensitive)
private let accDescrPattern = try! NSRegularExpression(pattern: #"^accDescr\s*:\s*(.+)$"#, options: .caseInsensitive)
private let accDescrOpenPattern = try! NSRegularExpression(pattern: #"^accDescr\s*\{\s*(.*)$"#, options: .caseInsensitive)
private let titlePattern = try! NSRegularExpression(pattern: #"^title\s+(.+)$"#, options: .caseInsensitive)

private func firstMatch(in s: String, pattern: NSRegularExpression) -> String? {
    let range = NSRange(s.startIndex..<s.endIndex, in: s)
    guard let match = pattern.firstMatch(in: s, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: s)
    else { return nil }
    return String(s[captureRange]).trimmingCharacters(in: .whitespaces)
}

// MARK: - Text tokenization (matching Jison alphaNumToken and text rules)

private func tokenizeText(_ raw: String) -> String {
    _stripQuotes(raw.trimmingCharacters(in: .whitespaces))
}

private func sanitizeText(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\n", with: "")
        .replacingOccurrences(of: "\\t", with: "\t")
}

private func stripQuadrantInlineComment(_ line: String) -> String {
    var quote: Character?
    var escaped = false
    var index = line.startIndex

    while index < line.endIndex {
        let ch = line[index]

        if let currentQuote = quote {
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == currentQuote {
                quote = nil
            }
            index = line.index(after: index)
            continue
        }

        if ch == "\"" || ch == "'" {
            quote = ch
            index = line.index(after: index)
            continue
        }

        if ch == "%" {
            let next = line.index(after: index)
            if next < line.endIndex && line[next] == "%" {
                let afterCommentMarker = line.index(after: next)
                if afterCommentMarker >= line.endIndex || line[afterCommentMarker] != "{" {
                    return String(line[..<index]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        index = line.index(after: index)
    }

    return line.trimmingCharacters(in: .whitespaces)
}

private func firstUnquotedIndex(
    of target: Character,
    in string: String,
    startingAt start: String.Index? = nil
) -> String.Index? {
    var quote: Character?
    var escaped = false
    var index = start ?? string.startIndex

    while index < string.endIndex {
        let ch = string[index]

        if let currentQuote = quote {
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == currentQuote {
                quote = nil
            }
            index = string.index(after: index)
            continue
        }

        if ch == "\"" || ch == "'" {
            quote = ch
        } else if ch == target {
            return index
        }

        index = string.index(after: index)
    }

    return nil
}

private func lastUnquotedIndex(of target: Character, in string: String) -> String.Index? {
    var quote: Character?
    var escaped = false
    var result: String.Index?
    var index = string.startIndex

    while index < string.endIndex {
        let ch = string[index]

        if let currentQuote = quote {
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == currentQuote {
                quote = nil
            }
            index = string.index(after: index)
            continue
        }

        if ch == "\"" || ch == "'" {
            quote = ch
        } else if ch == target {
            result = index
        }

        index = string.index(after: index)
    }

    return result
}

private func firstUnquotedClassMarker(in string: String) -> Range<String.Index>? {
    var quote: Character?
    var escaped = false
    var index = string.startIndex

    while index < string.endIndex {
        let ch = string[index]

        if let currentQuote = quote {
            if escaped {
                escaped = false
            } else if ch == "\\" {
                escaped = true
            } else if ch == currentQuote {
                quote = nil
            }
            index = string.index(after: index)
            continue
        }

        if ch == "\"" || ch == "'" {
            quote = ch
        } else if string[index...].hasPrefix(":::") {
            let markerEnd = string.index(index, offsetBy: 3)
            return index..<markerEnd
        }

        index = string.index(after: index)
    }

    return nil
}

private func stripAccDescrClosingBrace(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.hasSuffix("}") {
        return String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
    }
    return trimmed
}

// MARK: - Axis parsing helpers

private enum AxisStatement {
    case xAxis(left: String, right: String?)
    case yAxis(bottom: String, top: String?)
}

private func parseAxisStatement(_ line: String) throws -> AxisStatement? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()

    if lower.hasPrefix("x-axis") {
        let rest = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        let parts = rest.components(separatedBy: "-->")
        if parts.count == 2 {
            let left = tokenizeText(parts[0])
            let right = tokenizeText(parts[1])
            if right.isEmpty {
                return .xAxis(left: left + " ⟶ ", right: nil)
            }
            return .xAxis(left: left, right: right)
        } else {
            let left = tokenizeText(rest)
            return .xAxis(left: left, right: nil)
        }
    }

    if lower.hasPrefix("y-axis") {
        let rest = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        let parts = rest.components(separatedBy: "-->")
        if parts.count == 2 {
            let bottom = tokenizeText(parts[0])
            let top = tokenizeText(parts[1])
            if top.isEmpty {
                return .yAxis(bottom: bottom + " ⟶ ", top: nil)
            }
            return .yAxis(bottom: bottom, top: top)
        } else {
            let bottom = tokenizeText(rest)
            return .yAxis(bottom: bottom, top: nil)
        }
    }

    return nil
}

// MARK: - Quadrant label parsing

private func parseQuadrantDetail(_ line: String) -> (quadrant: Int, text: String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()

    if lower.hasPrefix("quadrant-1") {
        let text = tokenizeText(String(trimmed.dropFirst(10)))
        return (1, text)
    }
    if lower.hasPrefix("quadrant-2") {
        let text = tokenizeText(String(trimmed.dropFirst(10)))
        return (2, text)
    }
    if lower.hasPrefix("quadrant-3") {
        let text = tokenizeText(String(trimmed.dropFirst(10)))
        return (3, text)
    }
    if lower.hasPrefix("quadrant-4") {
        let text = tokenizeText(String(trimmed.dropFirst(10)))
        return (4, text)
    }

    return nil
}

// MARK: - Point parsing

private struct ParsedPoint {
    var text: String
    var className: String?
    var x: Double
    var y: Double
    var styles: [String]
}

private func parsePointLine(_ line: String) throws -> ParsedPoint? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard let openBracket = firstUnquotedIndex(of: "[", in: trimmed),
          let closeBracket = firstUnquotedIndex(of: "]", in: trimmed, startingAt: trimmed.index(after: openBracket))
    else {
        return nil
    }

    let beforeBracket = String(trimmed[..<openBracket]).trimmingCharacters(in: .whitespaces)

    guard let labelSeparator = lastUnquotedIndex(of: ":", in: beforeBracket) else {
        return nil
    }

    var pointText = String(beforeBracket[..<labelSeparator]).trimmingCharacters(in: .whitespaces)
    var className: String? = nil

    if let classMarker = firstUnquotedClassMarker(in: pointText) {
        let rawClassName = String(pointText[classMarker.upperBound...]).trimmingCharacters(in: .whitespaces)
        if firstUnquotedClassMarker(in: rawClassName) != nil {
            throw QuadrantChartParserError.invalidStatement(trimmed)
        }
        pointText = String(pointText[..<classMarker.lowerBound]).trimmingCharacters(in: .whitespaces)
        className = rawClassName
    }

    guard !pointText.isEmpty else {
        throw QuadrantChartParserError.missingPointCoordinate(trimmed)
    }

    let stripped = _stripQuotes(pointText)
    if stripped != pointText {
        pointText = stripped
    }

    let innerStr = String(trimmed[trimmed.index(after: openBracket)..<closeBracket])
    let coordinates = innerStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
    guard coordinates.count == 2 else {
        throw QuadrantChartParserError.missingPointCoordinate(pointText)
    }

    let xStr = coordinates[0]
    let yStr = coordinates[1]

    guard isValidPointCoordinate(xStr) else {
        throw QuadrantChartParserError.invalidPointCoordinate(pointText, Double(xStr) ?? -1)
    }
    guard isValidPointCoordinate(yStr) else {
        throw QuadrantChartParserError.invalidPointCoordinate(pointText, Double(yStr) ?? -1)
    }

    let x = Double(xStr)!
    let y = Double(yStr)!

    let afterBracket = String(trimmed[trimmed.index(after: closeBracket)...]).trimmingCharacters(in: CharacterSet.whitespaces)
    var styles: [String] = []
    if !afterBracket.isEmpty {
        styles = afterBracket.components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }.filter { !$0.isEmpty }
    }

    return ParsedPoint(text: pointText, className: className, x: x, y: y, styles: styles)
}

// MARK: - ClassDef parsing

private func parseClassDefLine(_ line: String) throws -> (className: String, styles: QuadrantPointStyles)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()

    guard lower.hasPrefix("classdef") else { return nil }

    let rest = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
    let parts = rest.components(separatedBy: .whitespaces)

    guard parts.count >= 1 else {
        throw QuadrantChartParserError.invalidStatement(trimmed)
    }

    let className = parts[0]
    let styleStr = parts.dropFirst().joined(separator: " ")
    let styleParts = styleStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

    guard !styleParts.isEmpty else {
        throw QuadrantChartParserError.invalidStatement(trimmed)
    }

    let styles = try parseStyles(styleParts)
    return (className, styles)
}

// MARK: - Quote stripping

private func _stripQuotes(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("\"`") && trimmed.hasSuffix("`\"") && trimmed.count >= 4 {
        return String(trimmed.dropFirst(2).dropLast(2))
    }
    if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
        return String(trimmed.dropFirst().dropLast())
    }
    if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2 {
        return String(trimmed.dropFirst().dropLast())
    }
    return trimmed
}

// MARK: - Public API

public func parseQuadrantChart(_ source: String) throws -> (QuadrantChart, [DiagramDiagnostic]) {
    let lines = _mermaidSourceLines(from: source)
    return try parseQuadrantChart(lines, frontmatter: nil)
}

public func parseQuadrantChart(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (QuadrantChart, [DiagramDiagnostic]) {
    var chart = QuadrantChart()

    guard !lines.isEmpty else {
        throw QuadrantChartParserError.invalidHeader("")
    }

    var lineIndex = 0
    var headerFound = false

    while lineIndex < lines.count {
        let rawLine = lines[lineIndex]
        let rawTrimmed = rawLine.trimmingCharacters(in: .whitespaces)
        lineIndex += 1

        if rawTrimmed.isEmpty || (rawTrimmed.hasPrefix("%%") && !rawTrimmed.hasPrefix("%%{")) {
            continue
        }

        let trimmed = stripQuadrantInlineComment(rawTrimmed)
        if trimmed.isEmpty {
            continue
        }

        if !headerFound {
            guard trimmed.lowercased().hasPrefix("quadrantchart") else {
                throw QuadrantChartParserError.invalidHeader(trimmed)
            }
            headerFound = true
            let afterHeader = String(trimmed.dropFirst(13)).trimmingCharacters(in: .whitespaces)
            if !afterHeader.isEmpty {
                try _parseInlineHeaderContent(afterHeader, chart: &chart)
            }
            continue
        }

        if let accDescrOpenContent = firstMatch(in: trimmed, pattern: accDescrOpenPattern) {
            var accLines: [String] = []
            let content = stripAccDescrClosingBrace(accDescrOpenContent)
            if trimmed.hasSuffix("}") {
                chart.accDescr = content.isEmpty ? nil : content
                continue
            }
            if !content.isEmpty {
                accLines = [content]
            }

            var didClose = false
            while lineIndex < lines.count {
                let innerLine = lines[lineIndex]
                let innerTrimmed = innerLine.trimmingCharacters(in: .whitespaces)
                lineIndex += 1

                if innerTrimmed.hasSuffix("}") {
                    let beforeBrace = String(innerTrimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                    if !beforeBrace.isEmpty {
                        accLines.append(beforeBrace)
                    }
                    didClose = true
                    break
                }
                accLines.append(innerTrimmed)
            }

            guard didClose else {
                throw QuadrantChartParserError.invalidStatement("Unclosed accDescr block")
            }
            chart.accDescr = accLines.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            continue
        }

        if let accTitleMatch = firstMatch(in: trimmed, pattern: accTitlePattern) {
            chart.accTitle = accTitleMatch
            continue
        }

        if let accDescrMatch = firstMatch(in: trimmed, pattern: accDescrPattern) {
            chart.accDescr = accDescrMatch
            continue
        }

        if let titleMatch = firstMatch(in: trimmed, pattern: titlePattern) {
            let titleText = titleMatch
            chart.titleText = titleText
            chart.diagramTitle = titleText
            continue
        }

        if let axis = try parseAxisStatement(trimmed) {
            switch axis {
            case .xAxis(let left, let right):
                chart.xAxisLeftText = sanitizeText(left)
                chart.xAxisRightText = right.map { sanitizeText($0) }
            case .yAxis(let bottom, let top):
                chart.yAxisBottomText = sanitizeText(bottom)
                chart.yAxisTopText = top.map { sanitizeText($0) }
            }
            continue
        }

        if let quad = parseQuadrantDetail(trimmed) {
            let text = sanitizeText(quad.text)
            switch quad.quadrant {
            case 1: chart.quadrant1Text = text
            case 2: chart.quadrant2Text = text
            case 3: chart.quadrant3Text = text
            case 4: chart.quadrant4Text = text
            default: break
            }
            continue
        }

        if let classDef = try parseClassDefLine(trimmed) {
            chart.classes[classDef.className] = classDef.styles
            continue
        }

        if let point = try parsePointLine(trimmed) {
            let styles = try parseStyles(point.styles)
            let qp = QuadrantPoint(
                text: sanitizeText(point.text),
                x: point.x,
                y: point.y,
                className: point.className,
                radius: styles.radius,
                color: styles.color,
                strokeColor: styles.strokeColor,
                strokeWidth: styles.strokeWidth
            )
            chart.points.insert(qp, at: 0)
            continue
        }

        throw QuadrantChartParserError.invalidStatement(trimmed)
    }

    guard headerFound else {
        throw QuadrantChartParserError.invalidHeader("")
    }

    return (chart, [])
}

private func _parseInlineHeaderContent(_ content: String, chart: inout QuadrantChart) throws {
    if let titleMatch = firstMatch(in: content, pattern: titlePattern) {
        chart.titleText = titleMatch
        chart.diagramTitle = titleMatch
    } else if let accTitleMatch = firstMatch(in: content, pattern: accTitlePattern) {
        chart.accTitle = accTitleMatch
    } else if let accDescrMatch = firstMatch(in: content, pattern: accDescrPattern) {
        chart.accDescr = accDescrMatch
    } else {
        throw QuadrantChartParserError.invalidStatement(content)
    }
}
