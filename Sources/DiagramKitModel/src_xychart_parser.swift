// Ported from original/src/xychart/parser.ts + xychart.jison
import Foundation

// MARK: - Sanitization

private func _sanitizeText(_ text: String) -> String {
    var result = text.trimmingCharacters(in: .whitespaces)
    // Remove <script ... > style tags
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
    result = result.replacingOccurrences(of: "onerror=", with: "", options: .caseInsensitive)
    result = result.replacingOccurrences(of: "onload=", with: "", options: .caseInsensitive)
    return result
}

// MARK: - Token types

private enum TokenType: Equatable {
    case xyChart                  // xychart or xychart-beta
    case orientation(String)      // vertical or horizontal
    case titleKeyword
    case xAxisKeyword
    case yAxisKeyword
    case lineKeyword
    case barKeyword
    case accTitleKeyword
    case accDescrKeyword
    case accDescrMultilineStart
    case accDescrMultilineEnd
    case bracketOpen
    case bracketClose
    case arrowDelimiter
    case comma
    case number(Double)
    case string(String)
    case markdownString(String)
    case alphaNum(String)
    case colon
    case newline
    case semicolon
    case eof
    case braceOpen
    case braceClose
}

private struct Token {
    let type: TokenType
    let value: String
}

// MARK: - Lexer (tokenizer)

private func _tokenizeXYChart(_ input: String) throws -> [Token] {
    var tokens: [Token] = []
    let chars = Array(input)
    var i = 0
    let n = chars.count

    // Mermaid jison-style concordance: alphaNum tokens separated by whitespace concatenate.
    // We handle this by accumulating alphaNum tokens until a non-alphaNum token or newline.
    var accumulating: String = ""

    func flushAccumulator() {
        if !accumulating.isEmpty {
            tokens.append(Token(type: .alphaNum(accumulating), value: accumulating))
            accumulating = ""
        }
    }

    func isAlphaNumChar(_ ch: Character) -> Bool {
        if ch.isLetter || ch.isNumber { return true }
        switch ch {
        case "&", "=", "*", "#", "_", "-", "+", ".":
            return true
        default: return false
        }
    }

    while i < n {
        // Skip whitespace (but newlines handled separately)
        let wsStart = i
        while i < n && (chars[i] == " " || chars[i] == "\t" || chars[i] == "\r") {
            i += 1
        }
        if i > wsStart { flushAccumulator() }
        if i >= n { break }

        // Newline
        if chars[i] == "\n" {
            flushAccumulator()
            tokens.append(Token(type: .newline, value: "\n"))
            i += 1
            continue
        }

        // Semicolon
        if chars[i] == ";" {
            flushAccumulator()
            tokens.append(Token(type: .semicolon, value: ";"))
            i += 1
            continue
        }

        // Comment %% (skip to end of line)
        if i + 1 < n && chars[i] == "%" && chars[i + 1] == "%" {
            flushAccumulator()
            while i < n && chars[i] != "\n" { i += 1 }
            continue
        }

        // Comma
        if chars[i] == "," {
            flushAccumulator()
            tokens.append(Token(type: .comma, value: ","))
            i += 1
            continue
        }

        // Colon
        if chars[i] == ":" {
            flushAccumulator()
            tokens.append(Token(type: .colon, value: ":"))
            i += 1
            continue
        }

        // Brace
        if chars[i] == "{" {
            flushAccumulator()
            tokens.append(Token(type: .braceOpen, value: "{"))
            i += 1
            continue
        }
        if chars[i] == "}" {
            flushAccumulator()
            tokens.append(Token(type: .braceClose, value: "}"))
            i += 1
            continue
        }

        // Arrow delimiter -->
        if i + 2 < n && chars[i] == "-" && chars[i + 1] == "-" && chars[i + 2] == ">" {
            flushAccumulator()
            tokens.append(Token(type: .arrowDelimiter, value: "-->"))
            i += 3
            continue
        }

        // Bracket
        if chars[i] == "[" {
            flushAccumulator()
            tokens.append(Token(type: .bracketOpen, value: "["))
            i += 1
            continue
        }
        if chars[i] == "]" {
            flushAccumulator()
            tokens.append(Token(type: .bracketClose, value: "]"))
            i += 1
            continue
        }

        // Markdown string: "`...`"
        if chars[i] == "\"" && i + 1 < n && chars[i + 1] == "`" {
            flushAccumulator()
            var str = ""
            i += 2
            while i < n {
                if i + 1 < n && chars[i] == "`" && chars[i + 1] == "\"" {
                    i += 2
                    break
                }
                str.append(chars[i])
                i += 1
            }
            tokens.append(Token(type: .markdownString(str), value: str))
            continue
        }

        // Quoted string
        if chars[i] == "\"" {
            flushAccumulator()
            var str = ""
            i += 1
            while i < n && chars[i] != "\"" {
                if chars[i] == "\\" && i + 1 < n {
                    i += 1
                    str.append(chars[i])
                } else {
                    str.append(chars[i])
                }
                i += 1
            }
            if i < n { i += 1 }
            tokens.append(Token(type: .string(str), value: str))
            continue
        }

        // Number: [+-]?(?:\d+(?:\.\d+)?|\.\d+)
        // But if we're inside an alphaNum token, treat signs/numbers/dots as alphaNum continuation
        if !accumulating.isEmpty {
            accumulating.append(chars[i])
            i += 1
            continue
        }
        if chars[i].isNumber || chars[i] == "+" || chars[i] == "-" || chars[i] == "." {
            var numStr = ""
            var hasSign = false
            var invalidNumberTail = false

            if chars[i] == "+" || chars[i] == "-" {
                numStr.append(chars[i])
                hasSign = true
                i += 1
            }

            // Check if this could be a number (digit or leading dot)
            let isNumberStart = i < n && (chars[i].isNumber || chars[i] == ".")

            if hasSign && !isNumberStart {
                // Just a +/- sign, not part of a number; append to accumulator
                i -= 1
                accumulating.append(chars[i])
                i += 1
                continue
            }

            if !hasSign && !isNumberStart {
                // Just a dot, might be alphaNum
                i += 1 // skip the dot we haven't consumed yet
                accumulating.append(".")
                continue
            }

            if hasSign {
                // i is at position after sign
                if i < n && chars[i] == "." {
                    numStr.append(".")
                    i += 1
                    while i < n && chars[i].isNumber {
                        numStr.append(chars[i])
                        i += 1
                    }
                } else {
                    while i < n && chars[i].isNumber {
                        numStr.append(chars[i])
                        i += 1
                    }
                    if i < n && chars[i] == "." {
                        numStr.append(".")
                        i += 1
                        while i < n && chars[i].isNumber {
                            numStr.append(chars[i])
                            i += 1
                        }
                    }
                }
            } else {
                // No sign
                if i < n && chars[i] == "." {
                    // Leading dot: check if followed by digit
                    if i + 1 < n && chars[i + 1].isNumber {
                        numStr.append(".")
                        i += 1
                        while i < n && chars[i].isNumber {
                            numStr.append(chars[i])
                            i += 1
                        }
                    } else {
                        // Just a dot char, not a number
                        i += 1
                        accumulating.append(".")
                        continue
                    }
                } else {
                    while i < n && chars[i].isNumber {
                        numStr.append(chars[i])
                        i += 1
                    }
                    if i < n && chars[i] == "." {
                        numStr.append(".")
                        i += 1
                        while i < n && chars[i].isNumber {
                            numStr.append(chars[i])
                            i += 1
                        }
                    }
                }
            }

            if i < n {
                let startsArrow = i + 2 < n && chars[i] == "-" && chars[i + 1] == "-" && chars[i + 2] == ">"
                if isAlphaNumChar(chars[i]) && !startsArrow {
                    invalidNumberTail = true
                    while i < n {
                        let ch = chars[i]
                        let arrow = i + 2 < n && ch == "-" && chars[i + 1] == "-" && chars[i + 2] == ">"
                        if arrow || ch == "," || ch == "]" || ch == "[" || ch == "\n" || ch == ";" || ch == " " || ch == "\t" || ch == "\r" {
                            break
                        }
                        numStr.append(ch)
                        i += 1
                    }
                }
            }

            if !invalidNumberTail, let d = Double(numStr) {
                flushAccumulator()
                tokens.append(Token(type: .number(d), value: numStr))
            } else {
                // Not a valid number
                flushAccumulator()
                tokens.append(Token(type: .alphaNum(numStr), value: numStr))
            }
            continue
        }

        // alphaNum characters: letters, &, =, *, #, _
        if isAlphaNumChar(chars[i]) {
            if chars[i] == "-" {
                // Check if this is an arrow delimiter
                if i + 2 < n && chars[i + 1] == "-" && chars[i + 2] == ">" {
                    flushAccumulator()
                    tokens.append(Token(type: .arrowDelimiter, value: "-->"))
                    i += 3
                    continue
                }
            }
            accumulating.append(chars[i])
            i += 1
            continue
        }

        // Skip unknown characters
        i += 1
    }

    flushAccumulator()
    tokens.append(Token(type: .eof, value: ""))

    // Phase 2: keyword matching on alphaNum tokens
    var resolved: [Token] = []
    var ti = 0
    while ti < tokens.count {
        let tok = tokens[ti]
        if case .alphaNum(let s) = tok.type {
            let lower = s.lowercased()
            if lower == "xychart" || lower == "xychart-beta" {
                resolved.append(Token(type: .xyChart, value: s))
            } else if lower == "vertical" {
                resolved.append(Token(type: .orientation("vertical"), value: s))
            } else if lower == "horizontal" {
                resolved.append(Token(type: .orientation("horizontal"), value: s))
            } else if lower == "title" {
                resolved.append(Token(type: .titleKeyword, value: s))
            } else if lower == "x-axis" {
                resolved.append(Token(type: .xAxisKeyword, value: s))
            } else if lower == "y-axis" {
                resolved.append(Token(type: .yAxisKeyword, value: s))
            } else if lower == "line" {
                resolved.append(Token(type: .lineKeyword, value: s))
            } else if lower == "bar" {
                resolved.append(Token(type: .barKeyword, value: s))
            } else if lower == "acctitle" {
                resolved.append(Token(type: .accTitleKeyword, value: s))
            } else if lower == "accdescr" {
                // Check for multiline: accDescr {
                if ti + 1 < tokens.count, case .braceOpen = tokens[ti + 1].type {
                    resolved.append(Token(type: .accDescrMultilineStart, value: s))
                    ti += 1 // skip braceOpen
                    resolved.append(tokens[ti]) // re-add braceOpen as marker
                } else {
                    resolved.append(Token(type: .accDescrKeyword, value: s))
                }
            } else {
                resolved.append(tok)
            }
        } else {
            resolved.append(tok)
        }
        ti += 1
    }

    return resolved
}

// MARK: - Parser

private class XYChartTokenParser {
    var tokens: [Token]
    var pos: Int = 0
    var chart: XYChart

    init(tokens: [Token]) {
        self.tokens = tokens
        self.chart = XYChart()
    }

    func current() -> Token {
        guard pos < tokens.count else { return Token(type: .eof, value: "") }
        return tokens[pos]
    }

    func peek() -> TokenType {
        return current().type
    }

    func advance() -> Token {
        let tok = current()
        if case .eof = tok.type {} else { pos += 1 }
        return tok
    }

    func advanceIf(_ type: TokenType) -> Bool {
        if peek() == type {
            _ = advance()
            return true
        }
        return false
    }

    func matchesWord(_ type: TokenType) -> Bool {
        guard pos < tokens.count else { return false }
        return tokens[pos].type == type
    }

    // MARK: - Parsing

    func parse() throws -> XYChart {
        // Skip leading newlines/semicolons
        while peek() == .newline || peek() == .semicolon { _ = advance() }

        // Parse header
        if peek() == .xyChart {
            _ = advance()

            // Optional orientation
            if case .orientation(let orient) = peek() {
                _ = advance()
                if orient == "horizontal" {
                    chart.horizontal = true
                    chart.explicitHorizontal = true
                } else {
                    chart.horizontal = false
                    chart.explicitVertical = true
                }
            } else {
                // Check next token is not an invalid orientation word
                if case .alphaNum(let s) = peek() {
                    let lower = s.lowercased()
                    if lower == "vertical" || lower == "horizontal" {
                        // already handled
                    } else {
                        throw XYChartParserError.invalidOrientation("Unexpected token '\(s)' after xychart")
                    }
                }
            }
        } else {
            throw XYChartParserError.invalidHeader("Expected 'xychart' or 'xychart-beta'")
        }

        // Skip newlines after header
        while peek() == .newline || peek() == .semicolon { _ = advance() }

        // Parse statements
        while pos < tokens.count {
            let tok = peek()
            switch tok {
            case .eof: return finalizedChart()
            case .newline, .semicolon:
                _ = advance()
                continue
            case .titleKeyword:
                try parseTitle()
            case .xAxisKeyword:
                try parseXAxis()
            case .yAxisKeyword:
                try parseYAxis()
            case .lineKeyword:
                try parseLineOrBar(isLine: true)
            case .barKeyword:
                try parseLineOrBar(isLine: false)
            case .accTitleKeyword:
                try parseAccTitle()
            case .accDescrKeyword:
                try parseAccDescr()
            case .accDescrMultilineStart:
                try parseAccDescrMultiline()
            default:
                // Skip unknown tokens until newline/eof
                while pos < tokens.count {
                    let t = peek()
                    if t == .newline || t == .semicolon || t == .eof { break }
                    _ = advance()
                }
            }
        }

        return finalizedChart()
    }

    private func finalizedChart() -> XYChart {
        var finalized = chart
        if !finalized.series.isEmpty {
            let allValues = finalized.series.flatMap(\.data)
            let dataCount = finalized.series.map(\.data.count).max() ?? 0

            if !finalized.xAxis.hasSetAxis && finalized.xAxis.categories == nil && finalized.xAxis.range == nil {
                finalized.xAxis.kind = .linear
                finalized.xAxis.range = (min: 1, max: Double(max(dataCount, 1)))
            }

            if finalized.yAxis.range == nil, let minVal = allValues.min(), let maxVal = allValues.max() {
                finalized.yAxis.kind = .linear
                finalized.yAxis.range = (min: minVal, max: maxVal)
            }
        }

        if finalized.yAxis.range == nil {
            finalized.yAxis.range = (min: 0, max: 100)
        }

        return finalized
    }

    // MARK: - Title

    func parseTitle() throws {
        _ = advance() // consume titleKeyword

        // Read the title text
        guard pos < tokens.count else { return }

        let tok = advance()
        switch tok.type {
        case .string(let s):
            let sanitized = _sanitizeText(s)
            chart.titleText = XYText(text: sanitized)
            chart.title = sanitized
        case .markdownString(let s):
            let sanitized = _sanitizeText(s)
            chart.titleText = XYText(text: sanitized, kind: .markdown)
            chart.title = sanitized
        case .alphaNum(let s):
            let sanitized = _sanitizeText(s)
            chart.titleText = XYText(text: sanitized)
            chart.title = sanitized
        default:
            // Put back if not a text token
            pos -= 1
        }
    }

    // MARK: - X-Axis

    func parseXAxis() throws {
        _ = advance() // consume xAxisKeyword

        // Optional title text
        var titleText: XYText? = nil
        if case .string = peek() {
            let tok = advance()
            if case .string(let s) = tok.type {
                titleText = XYText(text: _sanitizeText(s))
            }
        } else if case .markdownString = peek() {
            let tok = advance()
            if case .markdownString(let s) = tok.type {
                titleText = XYText(text: _sanitizeText(s), kind: .markdown)
            }
        } else if case .alphaNum = peek() {
            let tok = advance()
            if case .alphaNum(let s) = tok.type {
                // If the next token is arrow or bracket, this alphaNum is not a title
                // but part of the data (put it back). Otherwise it's a title.
                if peek() == .arrowDelimiter || peek() == .bracketOpen {
                    pos -= 1 // put it back for data parsing
                } else {
                    titleText = XYText(text: _sanitizeText(s))
                }
            }
        }

        // Now parse data (title has been extracted or determined to be absent)
        if case .number(let minVal) = peek() {
            _ = advance()
            guard peek() == .arrowDelimiter else {
                throw XYChartParserError.invalidOrientation("Expected '-->' in x-axis range")
            }
            _ = advance()
            guard case .number(let maxVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "x-axis range max")
            }
            _ = advance()
            chart.xAxis.kind = .linear
            chart.xAxis.hasSetAxis = true
            chart.xAxis.range = (min: minVal, max: maxVal)
            if let tt = titleText {
                chart.xAxis.titleText = tt
                chart.xAxis.title = tt.text
            }
        } else if peek() == .arrowDelimiter {
            _ = advance()
            guard case .number(let minVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "x-axis range min")
            }
            _ = advance()
            guard peek() == .arrowDelimiter else {
                throw XYChartParserError.invalidOrientation("Expected '-->' in x-axis range")
            }
            _ = advance()
            guard case .number(let maxVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "x-axis range max")
            }
            _ = advance()
            chart.xAxis.kind = .linear
            chart.xAxis.hasSetAxis = true
            chart.xAxis.range = (min: minVal, max: maxVal)
            if let tt = titleText {
                chart.xAxis.titleText = tt
                chart.xAxis.title = tt.text
            }
        } else if peek() == .bracketOpen {
            // Categories (band)
            try parseXAxisBand(titleText: titleText)
        } else if case .alphaNum(let s) = peek() {
            throw XYChartParserError.nonNumericData(s, "x-axis")
        } else {
            // Title-only X-axis
            if let tt = titleText {
                chart.xAxis.titleText = tt
                chart.xAxis.title = tt.text
                chart.xAxis.hasSetAxis = true
                chart.xAxis.kind = .band
            }
        }
    }

    func parseXAxisBand(titleText: XYText?) throws {
        _ = advance() // consume bracketOpen

        var categoryTexts: [XYText] = []
        var currentText = ""
        var currentKind = XYTextType.text
        var hasCurrentText = false

        func appendText(_ text: String, kind: XYTextType = .text) {
            currentText += text
            if kind == .markdown { currentKind = .markdown }
            hasCurrentText = true
        }

        func commitCategory() throws {
            guard hasCurrentText else {
                throw XYChartParserError.malformedComma("Missing category text in x-axis categories")
            }
            categoryTexts.append(XYText(text: _sanitizeText(currentText), kind: currentKind))
            currentText = ""
            currentKind = .text
            hasCurrentText = false
        }

        while pos < tokens.count {
            let tok = peek()
            if tok == .bracketClose {
                _ = advance()
                if hasCurrentText {
                    try commitCategory()
                } else if categoryTexts.isEmpty {
                    throw XYChartParserError.emptyData("Empty x-axis categories")
                } else {
                    throw XYChartParserError.malformedComma("Trailing comma in x-axis categories")
                }
                break
            } else if tok == .bracketOpen {
                _ = advance()
                throw XYChartParserError.unbalancedBrackets("Nested bracket in x-axis categories")
            } else if case .string(let s) = tok {
                _ = advance()
                appendText(s)
            } else if case .markdownString(let s) = tok {
                _ = advance()
                appendText(s, kind: .markdown)
            } else if case .alphaNum(let s) = tok {
                _ = advance()
                appendText(s)
            } else if case .number(let d) = tok {
                _ = advance()
                appendText(_formatNumber(d))
            } else if tok == .comma {
                _ = advance()
                try commitCategory()
            } else if tok == .arrowDelimiter {
                throw XYChartParserError.invalidOrientation("Unexpected arrow in x-axis category data")
            } else if tok == .newline || tok == .semicolon || tok == .eof {
                throw XYChartParserError.unbalancedBrackets("Unterminated bracket in x-axis categories")
            } else {
                // Try to extract text from any token type (handles keyword tokens, etc.)
                let val = _tokenText(tokens[pos])
                _ = advance()
                if !val.isEmpty {
                    appendText(val)
                }
            }
        }

        chart.xAxis.kind = .band
        chart.xAxis.hasSetAxis = true
        chart.xAxis.categoryTexts = categoryTexts
        chart.xAxis.categories = categoryTexts.map(\.text)
        if let tt = titleText {
            chart.xAxis.titleText = tt
            chart.xAxis.title = tt.text
        }
    }

    // MARK: - Y-Axis

    func parseYAxis() throws {
        _ = advance() // consume yAxisKeyword

        // Optional title text
        var titleText: XYText? = nil
        var consumedTitle = false
        if case .string = peek() {
            let tok = advance()
            if case .string(let s) = tok.type {
                titleText = XYText(text: _sanitizeText(s))
                consumedTitle = true
            }
        } else if case .markdownString = peek() {
            let tok = advance()
            if case .markdownString(let s) = tok.type {
                titleText = XYText(text: _sanitizeText(s), kind: .markdown)
                consumedTitle = true
            }
        }

        if !consumedTitle, case .alphaNum = peek() {
            let tok = advance()
            if case .alphaNum(let s) = tok.type {
                // Check if next token indicates data rather than a title
                if peek() == .arrowDelimiter || peek() == .bracketOpen {
                    pos -= 1 // put it back for data parsing
                } else {
                    titleText = XYText(text: _sanitizeText(s))
                }
            }
        }

        // Parse data
        if case .number(let minVal) = peek() {
            _ = advance()
            guard peek() == .arrowDelimiter else {
                throw XYChartParserError.invalidOrientation("Expected '-->' in y-axis range")
            }
            _ = advance()
            guard case .number(let maxVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "y-axis range max")
            }
            _ = advance()
            chart.yAxis.kind = .linear
            chart.yAxis.hasSetAxis = true
            chart.yAxis.range = (min: minVal, max: maxVal)
            if let tt = titleText {
                chart.yAxis.titleText = tt
                chart.yAxis.title = tt.text
            }
        } else if peek() == .arrowDelimiter {
            _ = advance() // consume arrow
            guard case .number(let minVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "y-axis range min")
            }
            _ = advance()
            guard peek() == .arrowDelimiter else {
                throw XYChartParserError.invalidOrientation("Expected '-->' in y-axis range")
            }
            _ = advance()
            guard case .number(let maxVal) = peek() else {
                throw XYChartParserError.nonNumericData(tokens[pos].value, "y-axis range max")
            }
            _ = advance()
            chart.yAxis.kind = .linear
            chart.yAxis.hasSetAxis = true
            chart.yAxis.range = (min: minVal, max: maxVal)
            if let tt = titleText {
                chart.yAxis.titleText = tt
                chart.yAxis.title = tt.text
            }
        } else if peek() == .bracketOpen {
            // Y-axis categories are invalid in Mermaid
            _ = advance()
            var catStr = ""
            while pos < tokens.count, peek() != .bracketClose, peek() != .eof, peek() != .newline {
                catStr += tokens[pos].value
                _ = advance()
            }
            if peek() == .bracketClose { _ = advance() }
            throw XYChartParserError.categoricalYAxis("Y-axis does not support category data: [\(catStr)]")
        } else if case .alphaNum(let s) = peek() {
            throw XYChartParserError.nonNumericData(s, "y-axis")
        } else {
            // Title-only y-axis
            if let tt = titleText {
                chart.yAxis.titleText = tt
                chart.yAxis.title = tt.text
                chart.yAxis.hasSetAxis = true
                chart.yAxis.kind = .linear
            }
        }
    }

    // MARK: - Line / Bar data

    func parseLineOrBar(isLine: Bool) throws {
        _ = advance() // consume lineKeyword or barKeyword

        // Optional series title
        var seriesText: XYText = XYText(text: "")
        if case .string(let s) = peek() {
            _ = advance()
            seriesText = XYText(text: _sanitizeText(s))
        } else if case .markdownString(let s) = peek() {
            _ = advance()
            seriesText = XYText(text: _sanitizeText(s), kind: .markdown)
        } else if case .alphaNum = peek() {
            // Check if next is bracket open (no title) or arrow (no data?)
            let tok = advance()
            if case .alphaNum(let s) = tok.type {
                if peek() == .bracketOpen {
                    seriesText = XYText(text: s.trimmingCharacters(in: .whitespaces))
                } else {
                    // No brackets found - missing data
                    throw XYChartParserError.missingData("Missing bracket data for \(isLine ? "line" : "bar") series")
                }
            }
        }

        // Expect bracket open
        guard peek() == .bracketOpen else {
            throw XYChartParserError.missingData("Expected '[' for \(isLine ? "line" : "bar") series data")
        }
        _ = advance()

        // Parse data values
        var values: [Double] = []
        var expectingValue = true
        var bracketDepth = 1
        var hasData = false

        while pos < tokens.count {
            let tok = peek()
            if tok == .bracketClose {
                bracketDepth -= 1
                _ = advance()
                if bracketDepth == 0 {
                    if !hasData {
                        throw XYChartParserError.emptyData("Empty data for \(isLine ? "line" : "bar") series")
                    }
                    if expectingValue {
                        throw XYChartParserError.malformedComma("Trailing comma in \(isLine ? "line" : "bar") data")
                    }
                    break
                }
            } else if tok == .bracketOpen {
                bracketDepth += 1
                _ = advance()
                throw XYChartParserError.unbalancedBrackets("Nested bracket in \(isLine ? "line" : "bar") series data")
            } else if case .number(let d) = tok {
                _ = advance()
                guard expectingValue else {
                    throw XYChartParserError.malformedComma("Missing comma in \(isLine ? "line" : "bar") data")
                }
                values.append(d)
                hasData = true
                expectingValue = false
            } else if tok == .comma {
                _ = advance()
                if expectingValue {
                    throw XYChartParserError.malformedComma("Double comma or unexpected comma in \(isLine ? "line" : "bar") data")
                }
                expectingValue = true
            } else if case .alphaNum(let s) = tok {
                _ = advance()
                if expectingValue {
                    throw XYChartParserError.nonNumericData(s, "\(isLine ? "line" : "bar") series data")
                } else {
                    throw XYChartParserError.malformedComma("Missing comma in \(isLine ? "line" : "bar") data")
                }
            } else if tok == .newline || tok == .semicolon || tok == .eof {
                throw XYChartParserError.unbalancedBrackets("Unterminated bracket in \(isLine ? "line" : "bar") series data")
            } else {
                _ = advance()
            }
        }

        if bracketDepth != 0 {
            throw XYChartParserError.unbalancedBrackets("Unbalanced brackets in \(isLine ? "line" : "bar") series data")
        }

        if !hasData {
            throw XYChartParserError.emptyData("Empty data for \(isLine ? "line" : "bar") series")
        }

        chart.series.append(XYChartSeries(
            type: isLine ? .line : .bar,
            title: seriesText,
            data: values
        ))
    }

    // MARK: - Accessibility

    func parseAccTitle() throws {
        _ = advance() // consume accTitleKeyword
        if peek() == .colon { _ = advance() }

        var txt = ""
        while pos < tokens.count {
            let tok = peek()
            if tok == .newline || tok == .semicolon || tok == .eof { break }
            let val = _tokenText(tokens[pos])
            if !val.isEmpty {
                txt += (txt.isEmpty ? "" : " ") + val
            }
            _ = advance()
        }
        chart.accTitle = txt.trimmingCharacters(in: .whitespaces)
    }

    func parseAccDescr() throws {
        _ = advance() // consume accDescrKeyword
        if peek() == .colon { _ = advance() }

        var txt = ""
        while pos < tokens.count {
            let tok = peek()
            if tok == .newline || tok == .semicolon || tok == .eof { break }
            let val = _tokenText(tokens[pos])
            if !val.isEmpty {
                txt += (txt.isEmpty ? "" : " ") + val
            }
            _ = advance()
        }
        chart.accDescr = txt.trimmingCharacters(in: .whitespaces)
    }

    func parseAccDescrMultiline() throws {
        _ = advance() // consume accDescrMultilineStart
        if peek() == .braceOpen { _ = advance() }

        var txt = ""
        while pos < tokens.count {
            if peek() == .braceClose {
                _ = advance()
                break
            }
            if peek() == .newline {
                txt += "\n"
                _ = advance()
            } else {
                let val = _tokenText(tokens[pos])
                txt += val
                _ = advance()
            }
        }
        chart.accDescr = txt.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Formatting helpers

private func _tokenText(_ token: Token) -> String {
    switch token.type {
    case .string(let s): return s
    case .markdownString(let s): return s
    case .alphaNum(let s): return s
    case .number(let d): return _formatNumber(d)
    case .orientation(let s): return s
    case .titleKeyword, .xAxisKeyword, .yAxisKeyword, .lineKeyword, .barKeyword,
         .accTitleKeyword, .accDescrKeyword, .accDescrMultilineStart:
        return token.value
    default: return ""
    }
}

private func _formatNumber(_ d: Double) -> String {
    if d == d.rounded() && abs(d) < 1e15 { return String(Int(d)) }
    return String(format: "%g", d)
}

// MARK: - Public API

public func parseXYChart(_ lines: [String]) throws -> XYChart {
    let source = lines.joined(separator: "\n")
    let tokens = try _tokenizeXYChart(source)
    let parser = XYChartTokenParser(tokens: tokens)
    let chart = try parser.parse()

    // No plot data guard
    if chart.series.isEmpty {
        throw XYChartParserError.noPlotData
    }

    return chart
}

public func parseXYChart(_ source: String) throws -> XYChart {
    let tokens = try _tokenizeXYChart(source)
    let parser = XYChartTokenParser(tokens: tokens)
    let chart = try parser.parse()

    if chart.series.isEmpty {
        throw XYChartParserError.noPlotData
    }

    return chart
}
