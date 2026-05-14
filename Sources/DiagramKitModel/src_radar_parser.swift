import Foundation
import DiagramKitCommon

public func parseRadarDiagram(
    source: String,
    frontmatter: DiagramFrontmatter? = nil
) throws -> (RadarDiagram, [DiagramDiagnostic]) {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?
    var axes: [RadarAxis] = []
    var rawCurves: [(name: String, label: String?, entries: [RadarRawEntry])] = []
    var showLegend: Bool?
    var ticks: Int?
    var maxValue: Double?
    var minValue: Double?
    var graticule: RadarGraticule?

    var i = 0
    var foundHeader = false

    while i < lines.count {
        let raw = lines[i]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            i += 1
            continue
        }

        if trimmed.hasPrefix("%%") {
            i += 1
            continue
        }

        if !foundHeader {
            let lower = trimmed.lowercased()
            let isRadar = _isRadarHeader(lower)

            if isRadar {
                foundHeader = true
                let remainder = _headerRemainder(trimmed)
                if remainder.lowercased() == "title" {
                    i += 1
                    continue
                }
                let parsedMeta = _parseTitleAccessibility(remainder, lineNumber: i + 1)
                if let t = parsedMeta.title { diagramTitle = t }
                if let at = parsedMeta.accTitle { accTitle = at }
                if let ad = parsedMeta.accDescr { accDescr = ad }
                i += 1
                continue
            } else {
                throw RadarParserError.invalidHeader("Expected 'radar-beta', 'radar-beta:', or 'radar-beta :' at line \(i + 1), found '\(trimmed)'", line: i + 1)
            }
        }

        let lower = trimmed.lowercased()

        if lower.hasPrefix("accdescr {") || lower == "accdescr{" {
            var descLines: [String] = []
            i += 1
            var braceDepth = 1
            while i < lines.count && braceDepth > 0 {
                let braceLine = lines[i].trimmingCharacters(in: .whitespaces)
                for ch in braceLine {
                    if ch == "{" { braceDepth += 1 }
                    if ch == "}" { braceDepth -= 1 }
                }
                if braceDepth > 0 {
                    descLines.append(lines[i])
                }
                i += 1
            }
            accDescr = descLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
            continue
        }

        if lower == "title", i + 1 < lines.count {
            diagramTitle = lines[i + 1].trimmingCharacters(in: .whitespaces)
            i += 2
            continue
        }

        let parsedMeta = _parseTitleAccessibility(trimmed, lineNumber: i + 1)
        if parsedMeta.title != nil || parsedMeta.accTitle != nil || parsedMeta.accDescr != nil {
            if let t = parsedMeta.title { diagramTitle = t }
            if let at = parsedMeta.accTitle { accTitle = at }
            if let ad = parsedMeta.accDescr { accDescr = ad }
            i += 1
            continue
        }

        if lower.hasPrefix("axis") {
            let axisContent = _parseKeywordValue(trimmed, keyword: "axis") ?? ""
            if axisContent.isEmpty {
                throw RadarParserError.emptyAxisDeclaration(line: i + 1)
            }
            let axisParts = _splitTopLevelCommas(axisContent)
            if axisParts.isEmpty || (axisParts.count == 1 && axisParts[0].isEmpty) {
                throw RadarParserError.emptyAxisDeclaration(line: i + 1)
            }
            for part in axisParts {
                let trimmedPart = part.trimmingCharacters(in: .whitespaces)
                if trimmedPart.isEmpty {
                    throw RadarParserError.emptyAxisDeclaration(line: i + 1)
                }
                let (name, label) = _parseIdAndLabel(trimmedPart)
                if name.isEmpty {
                    throw RadarParserError.emptyAxisDeclaration(line: i + 1)
                }
                axes.append(RadarAxis(name: name, label: label))
            }
            i += 1
            continue
        }

        if lower.hasPrefix("curve") {
            let curveLineIndex = i
            let curveContent = _parseKeywordValue(trimmed, keyword: "curve") ?? ""
            if curveContent.isEmpty {
                throw RadarParserError.emptyCurveDeclaration(line: i + 1)
            }
            let curveParts = _splitTopLevelCommas(curveContent)
            for part in curveParts {
                let trimmedPart = part.trimmingCharacters(in: .whitespaces)
                guard let braceIndex = trimmedPart.firstIndex(of: "{") else {
                    throw RadarParserError.curveWithoutEntries("Curve '\(trimmedPart)' missing entry block at line \(i + 1)", line: i + 1)
                }
                let nameAndLabel = String(trimmedPart[..<braceIndex]).trimmingCharacters(in: .whitespaces)
                var (curveName, curveLabel) = _parseIdAndLabel(nameAndLabel)
                let afterBrace = String(trimmedPart[trimmedPart.index(after: braceIndex)...])

                if curveName.isEmpty {
                    curveName = nameAndLabel
                }

                let entries: [RadarRawEntry]
                if afterBrace.trimmingCharacters(in: .whitespaces).contains("}") {
                    let closeContent = _collectUntilClosingBrace(afterBrace, lines: lines, lineIndex: &i)
                    entries = try _parseEntries(closeContent, lineNumber: i + 1, curveName: curveName)
                } else {
                    var braceLines: [String] = [afterBrace]
                    i += 1
                    var foundClosing = false
                    while i < lines.count {
                        let bline = lines[i]
                        braceLines.append(bline)
                        if bline.trimmingCharacters(in: .whitespaces).contains("}") {
                            foundClosing = true
                            i += 1
                            break
                        }
                        i += 1
                    }
                    if !foundClosing {
                        throw RadarParserError.curveWithoutEntries("Unclosed brace for curve '\(curveName)' at line \(i + 1)", line: i + 1)
                    }
                    let content = braceLines.joined(separator: "\n")
                    let innerContent = _collectUntilClosingBrace(content, lines: [], lineIndex: &i)
                    entries = try _parseEntries(innerContent, lineNumber: i + 1, curveName: curveName)
                }
                rawCurves.append((name: curveName, label: curveLabel, entries: entries))
            }
            if i == curveLineIndex {
                i += 1
            }
            continue
        }

        if lower.hasPrefix("ticks") {
            let val = _parseKeywordValue(trimmed, keyword: "ticks") ?? ""
            guard let n = Int(val) else {
                throw RadarParserError.invalidTicksValue("Invalid ticks value at line \(i + 1): '\(val)'", line: i + 1)
            }
            ticks = n
            i += 1
            continue
        }

        if lower.hasPrefix("showlegend") {
            let val = (_parseKeywordValue(trimmed, keyword: "showLegend") ?? _parseKeywordValue(trimmed, keyword: "showlegend"))?.lowercased() ?? ""
            showLegend = val == "true"
            i += 1
            continue
        }

        if lower.hasPrefix("max") {
            let val = _parseKeywordValue(trimmed, keyword: "max") ?? ""
            maxValue = Double(val)
            i += 1
            continue
        }

        if lower.hasPrefix("min") {
            let val = _parseKeywordValue(trimmed, keyword: "min") ?? ""
            minValue = Double(val)
            i += 1
            continue
        }

        if lower.hasPrefix("graticule") {
            let val = (_parseKeywordValue(trimmed, keyword: "graticule") ?? "").lowercased()
            switch val {
            case "circle": graticule = .circle
            case "polygon": graticule = .polygon
            default: throw RadarParserError.invalidGraticuleValue("Invalid graticule value at line \(i + 1): '\(val)'", line: i + 1)
            }
            i += 1
            continue
        }

        i += 1
    }

    if !foundHeader {
        throw RadarParserError.invalidHeader("No radar-beta header found.", line: 0)
    }

    var options = RadarOptions()
    if let sl = showLegend { options.showLegend = sl }
    if let t = ticks { options.ticks = t }
    if let mx = maxValue { options.max = mx }
    if let mn = minValue { options.min = mn }
    if let g = graticule { options.graticule = g }

    var diagram = RadarDiagram(
        axes: axes,
        curves: [],
        options: options,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr
    )

    if let fm = frontmatter {
        if let rc = fm.radarConfig { diagram.config = rc }
        if let rt = fm.radarTheme { diagram.theme = rt }
        if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle {
            diagram.diagramTitle = fmTitle
        }
    }

    var curves: [RadarCurve] = []
    for raw in rawCurves {
        let entries = try computeCurveEntries(raw.entries, axes: axes, curveName: raw.name)
        curves.append(RadarCurve(name: raw.name, label: raw.label, entries: entries))
    }
    diagram.curves = curves

    return (diagram, [])
}

// MARK: - Entry types

public enum RadarRawEntry {
    case numeric(Double)
    case detailed(axisId: String, value: Double)
}

// MARK: - computeCurveEntries

public func computeCurveEntries(_ entries: [RadarRawEntry], axes: [RadarAxis], curveName: String) throws -> [Double] {
    if entries.isEmpty { return [] }
    switch entries[0] {
    case .numeric:
        return entries.compactMap {
            if case .numeric(let v) = $0 { return v }
            return nil
        }
    case .detailed:
        if axes.isEmpty {
            throw RadarParserError.detailedEntriesWithoutDeclaredAxes(curveName, line: 0)
        }
        var entryMap: [String: Double] = [:]
        for entry in entries {
            if case .detailed(let axisId, let value) = entry {
                entryMap[axisId] = value
            }
        }
        return try axes.map { axis in
            guard let value = entryMap[axis.name] else {
                throw RadarParserError.missingEntryForDeclaredAxis(curveName, axis.label, line: 0)
            }
            return value
        }
    }
}

// MARK: - Parsing helpers

private func _splitTopLevelCommas(_ s: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var braceDepth = 0
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in s {
        if inQuote {
            current.append(ch)
            if isEscaped { isEscaped = false; continue }
            if ch == "\\" { isEscaped = true; continue }
            if ch == quoteChar { inQuote = false; quoteChar = nil }
            continue
        }
        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }
        if ch == "{" { braceDepth += 1; current.append(ch); continue }
        if ch == "}" { braceDepth -= 1; current.append(ch); continue }
        if ch == "," && braceDepth == 0 {
            parts.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    parts.append(current)
    return parts
}

private func _parseIdAndLabel(_ s: String) -> (name: String, label: String?) {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard let bracketStart = trimmed.firstIndex(where: { $0 == "[" || $0 == "\"" || $0 == "'" }) else {
        return (trimmed, nil)
    }
    if trimmed[bracketStart] == "[" {
        let name = String(trimmed[..<bracketStart]).trimmingCharacters(in: .whitespaces)
        let after = String(trimmed[trimmed.index(after: bracketStart)...])
        if let bracketEnd = _findClosingBracket(after) {
            let label = String(after[..<bracketEnd])
            let unquoted = _unquoteBracketLabel(label)
            return (name, unquoted)
        }
        return (name, nil)
    }
    return (trimmed, nil)
}

private func _findClosingBracket(_ s: String) -> String.Index? {
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false
    for idx in s.indices {
        let ch = s[idx]
        if inQuote {
            if isEscaped { isEscaped = false; continue }
            if ch == "\\" { isEscaped = true; continue }
            if ch == quoteChar { inQuote = false; quoteChar = nil }
            continue
        }
        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            continue
        }
        if ch == "]" {
            return idx
        }
    }
    return nil
}

private func _unquoteBracketLabel(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    if (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
        let start = t.index(after: t.startIndex)
        let end = t.index(before: t.endIndex)
        return String(t[start..<end])
    }
    return t
}

private func _collectUntilClosingBrace(_ s: String, lines: [String], lineIndex: inout Int) -> String {
    var depth = 1
    var result = ""
    for ch in s {
        if ch == "{" { depth += 1 }
        if ch == "}" {
            depth -= 1
            if depth == 0 { break }
        }
        result.append(ch)
    }
    return result
}

private func _parseEntries(_ content: String, lineNumber: Int, curveName: String) throws -> [RadarRawEntry] {
    let parts = _splitTopLevelCommas(content)
    let nonEmpty = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

    if nonEmpty.isEmpty {
        throw RadarParserError.curveWithoutEntries("Curve '\(curveName)' has no entries at line \(lineNumber)", line: lineNumber)
    }

    var entries: [RadarRawEntry] = []
    var mode: String?

    for part in nonEmpty {
        let tokens = part.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        if tokens.count == 1 {
            guard let val = Double(tokens[0]) else {
                throw RadarParserError.nonCommaSeparatedEntries("Invalid entry '\(part)' at line \(lineNumber)", line: lineNumber)
            }
            if mode == nil { mode = "numeric" }
            if mode != "numeric" {
                throw RadarParserError.mixedEntryModes("Mixed entry modes in curve '\(curveName)' at line \(lineNumber)", line: lineNumber)
            }
            entries.append(.numeric(val))
            continue
        }

        if mode == nil { mode = "detailed" }
        if mode != "detailed" {
            throw RadarParserError.mixedEntryModes("Mixed entry modes in curve '\(curveName)' at line \(lineNumber)", line: lineNumber)
        }

        let axisId: String
        let valueStr: String
        if tokens[0].hasSuffix(":") {
            axisId = String(tokens[0].dropLast())
            valueStr = tokens.count > 1 ? tokens[1] : ""
        } else if tokens.count >= 2 && tokens[1] == ":" {
            axisId = tokens[0]
            valueStr = tokens.count > 2 ? tokens[2] : ""
        } else if tokens.count >= 2 {
            axisId = tokens[0]
            valueStr = tokens[1]
        } else {
            throw RadarParserError.nonCommaSeparatedEntries("Invalid detailed entry '\(part)' at line \(lineNumber)", line: lineNumber)
        }

        guard let val = Double(valueStr) else {
            throw RadarParserError.nonCommaSeparatedEntries("Invalid entry value '\(part)' at line \(lineNumber)", line: lineNumber)
        }
        entries.append(.detailed(axisId: axisId, value: val))
    }

    return entries
}

private func _parseKeywordValue(_ line: String, keyword: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()
    let kwLower = keyword.lowercased()

    if lower == kwLower { return "" }
    guard lower.hasPrefix(kwLower) else { return nil }

    var after = String(trimmed.dropFirst(keyword.count))
    if after.hasPrefix(":") { after = String(after.dropFirst()) }
    if after.hasPrefix(" ") { after = String(after.dropFirst()) }
    return after.trimmingCharacters(in: .whitespaces)
}

private func _parseTitleAccessibility(_ line: String, lineNumber: Int) -> (title: String?, accTitle: String?, accDescr: String?) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()
    var title: String?
    var accTitle: String?
    var accDescr: String?

    if lower.hasPrefix("title ") || lower.hasPrefix("title:") {
        title = _trimMetadataMarkers(from: _parseKeywordValue(trimmed, keyword: "title") ?? "")
    }
    if let value = _metadataValue(in: trimmed, marker: "accTitle:", stoppingBefore: ["accDescr:"]) {
        accTitle = value
    }
    if let value = _metadataValue(in: trimmed, marker: "accDescr:", stoppingBefore: []) {
        accDescr = value
    }

    return (title, accTitle, accDescr)
}

private func _isRadarHeader(_ lowercasedLine: String) -> Bool {
    guard lowercasedLine.hasPrefix("radar-beta") else { return false }
    if lowercasedLine == "radar-beta" { return true }
    let remainder = lowercasedLine.dropFirst("radar-beta".count)
    guard let first = remainder.first else { return true }
    return first == ":" || first.isWhitespace
}

private func _headerRemainder(_ line: String) -> String {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()
    if lower == "radar-beta" { return "" }

    var remaining: String
    if lower.hasPrefix("radar-beta:") {
        remaining = String(trimmed.dropFirst("radar-beta:".count))
    } else if lower.hasPrefix("radar-beta") {
        remaining = String(trimmed.dropFirst("radar-beta".count))
        if remaining.hasPrefix(":") { remaining = String(remaining.dropFirst()) }
    } else {
        return ""
    }
    return remaining.trimmingCharacters(in: .whitespaces)
}

private func _metadataValue(
    in line: String,
    marker: String,
    stoppingBefore stopMarkers: [String]
) -> String? {
    guard let markerRange = line.range(of: marker, options: .caseInsensitive) else {
        return nil
    }
    var end = line.endIndex
    for stop in stopMarkers {
        if let range = line.range(
            of: stop,
            options: .caseInsensitive,
            range: markerRange.upperBound..<line.endIndex
        ), range.lowerBound < end {
            end = range.lowerBound
        }
    }
    let raw = String(line[markerRange.upperBound..<end])
    let value = raw.trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
}

private func _trimMetadataMarkers(from value: String) -> String {
    var end = value.endIndex
    for marker in ["accTitle:", "accDescr:"] {
        if let range = value.range(of: marker, options: .caseInsensitive), range.lowerBound < end {
            end = range.lowerBound
        }
    }
    return String(value[..<end]).trimmingCharacters(in: .whitespaces)
}
