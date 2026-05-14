import Foundation
import DiagramKitCommon

// MARK: - Error types

public enum WardleyMapParserError: Error, LocalizedError {
    case invalidHeader(String)
    case emptySource
    case missingCoordinate(String)
    case invalidCoordinate(String, Double)
    case invalidStatement(String)
    case pipelineExpectedOpenBrace(String)
    case pipelineExpectedCloseBrace(String)
    case evolveMissingComponent(String)
    case evolveMissingTarget(String)
    case annotationMissingNumber(String)
    case annotationMissingText(String)
    case invalidSize(String)
    case invalidEvolutionStage(String)
    case invalidDecorator(String)
    case invalidLink(String)
    case duplicateAnnotationNumber(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let line):
            return "Wardley Map must start with 'wardley-beta'. Unexpected: '\(line)'"
        case .emptySource:
            return "Wardley Map source is empty."
        case .missingCoordinate(let context):
            return "Missing coordinate for \(context)."
        case .invalidCoordinate(let context, let value):
            return "Invalid coordinate for \(context): \(value). Must be 0-1 (decimal) or 0-100."
        case .invalidStatement(let line):
            return "Invalid Wardley Map statement: '\(line)'"
        case .pipelineExpectedOpenBrace(let name):
            return "Pipeline '\(name)' expected '{' on the same or next line."
        case .pipelineExpectedCloseBrace(let name):
            return "Pipeline '\(name)' expected '}' to close block."
        case .evolveMissingComponent(let line):
            return "Evolve statement missing component name: '\(line)'"
        case .evolveMissingTarget(let line):
            return "Evolve statement missing target evolution value: '\(line)'"
        case .annotationMissingNumber(let line):
            return "Annotation statement missing number: '\(line)'"
        case .annotationMissingText(let line):
            return "Annotation statement missing quoted text: '\(line)'"
        case .invalidSize(let line):
            return "Invalid size directive: '\(line)'"
        case .invalidEvolutionStage(let line):
            return "Invalid evolution stage definition: '\(line)'"
        case .invalidDecorator(let decorator):
            return "Invalid decorator: '\(decorator)'. Must be build, buy, outsource, or market."
        case .invalidLink(let line):
            return "Invalid link statement: '\(line)'"
        case .duplicateAnnotationNumber(let number):
            return "Duplicate annotation number: \(number)."
        }
    }
}

// MARK: - Parsing helpers

private func normalizeCoordinate(_ value: Double, context: String) throws -> Double {
    let normalized = value <= 1 ? value * 100 : value
    if normalized < 0 || normalized > 100 {
        throw WardleyMapParserError.invalidCoordinate(context, value)
    }
    return normalized
}

private func parseCoordinatePair(_ text: String, context: String) throws -> (Double, Double) {
    let cleaned = text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
    let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 2,
          let first = Double(parts[0]),
          let second = Double(parts[1]) else {
        throw WardleyMapParserError.missingCoordinate(context)
    }
    let x = try normalizeCoordinate(second, context: "\(context) evolution")
    let y = try normalizeCoordinate(first, context: "\(context) visibility")
    return (x, y)
}

private func parseSingleCoordinate(_ text: String, context: String) throws -> Double {
    let cleaned = text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
    guard let value = Double(cleaned) else {
        throw WardleyMapParserError.missingCoordinate(context)
    }
    return try normalizeCoordinate(value, context: context)
}

private func parseCoordinateValue(_ text: String, context: String) throws -> (Double, Double) {
    let cleaned = text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").trimmingCharacters(in: .whitespaces)
    let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 2,
          let first = Double(parts[0]),
          let second = Double(parts[1]) else {
        throw WardleyMapParserError.missingCoordinate(context)
    }
    // OWM swap: first=visibility (maps to y), second=evolution (maps to x)
    let x = try normalizeCoordinate(second, context: "\(context) evolution")
    let y = try normalizeCoordinate(first, context: "\(context) visibility")
    return (x, y)
}

private func stripQuotes(_ s: String) -> String {
    var str = s.trimmingCharacters(in: .whitespaces)
    if str.hasPrefix("\"") && str.hasSuffix("\"") {
        str.removeFirst()
        str.removeLast()
    }
    return str
}

// MARK: - Name tokenization (handles hyphenated names)

private enum WardleyNameToken {
    case keyword(String)
    case name(String, stopsBeforeArrow: Bool)
}

private func tokenizeNameWithHyphens(_ text: String) -> [WardleyNameToken] {
    let lower = text.lowercased()
    let keywords = ["component", "anchor", "pipeline", "evolve", "note", "annotations", "annotation", "accelerator", "deaccelerator", "size", "evolution"]
    if keywords.contains(lower) {
        return [.keyword(lower)]
    }

    let chars = Array(text)
    var result: [WardleyNameToken] = []
    var current: [Character] = []
    var i = 0

    while i < chars.count {
        let ch = chars[i]
        if ch == "-" && i + 1 < chars.count && chars[i + 1] == ">" {
            if !current.isEmpty {
                let name = String(current).trimmingCharacters(in: .whitespaces)
                result.append(.name(name, stopsBeforeArrow: true))
                current = []
            }
            _ = String(chars[i...]) // Reserved for future use
            break
        } else {
            current.append(ch)
            i += 1
        }
    }

    if !current.isEmpty {
        let name = String(current).trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            result.append(.name(name, stopsBeforeArrow: false))
        }
    }

    return result.isEmpty ? [.name(text, stopsBeforeArrow: false)] : result
}

// MARK: - Quote-aware prefix scanning

private func hasPrefixOutsideQuotes(_ line: String, prefix: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()
    return lower.hasPrefix(prefix.lowercased())
}

// MARK: - Arrow detection in a line

private struct LinkArrowInfo {
    var arrow: String
    var isDashed: Bool
    var flow: WardleyFlowDirection?
    var label: String?
    let portAtEnd: String?
    var semicolonLabel: String?
}

private func detectArrowInLine(_ line: String) -> LinkArrowInfo? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    var arrow = ""
    var isDashed = false
    var flow: WardleyFlowDirection?
    var label: String?
    let portAtEnd: String? = nil
    var semicolonLabel: String?

    // Check for labeled flow arrows: +'...'>  +'...'<  +'...'<>
    if let range = trimmed.range(of: "+'", options: .literal) {
        let remainder = trimmed[range.lowerBound...]
        let remainderStr = String(remainder)
        for (pattern, dir, bidirectional) in [("+'", nil as WardleyFlowDirection?, true),
                                                ("+'", nil as WardleyFlowDirection?, true),
                                                ("+'", nil as WardleyFlowDirection?, true)] {
            _ = (pattern, dir, bidirectional)
        }
        // Match +'<label>'<> +'<label>'> +'<label>'<
        if let match = try? regexMatch(remainderStr, pattern: #"^\+'([^']*)'(<>|>|<)"#) {
            let labelText = match.count > 0 ? match[0] : ""
            let arrowType = match.count > 1 ? match[1] : ""
            arrow = "+'\(labelText)'\(arrowType)"
            if !labelText.isEmpty { label = labelText }
            if arrowType == "<>" { flow = .bidirectional }
            else if arrowType == ">" { flow = .forward }
            else if arrowType == "<" { flow = .backward }
        }
    }

    // Check for port-based links: +<> +> +<
    if arrow.isEmpty {
        if trimmed.contains("+<>") { arrow = "+<>"; flow = .bidirectional }
        else if trimmed.contains("+>") { arrow = "+>"; flow = .forward }
        else if trimmed.contains("+<") { arrow = "+<"; flow = .backward }
    }

    // Check for dashed: -.-> or -.->  or  -.-> precedes other arrows
    if arrow.isEmpty {
        if trimmed.contains("-.-") && trimmed.contains(">") { isDashed = true; arrow = "-.->" }
        else if trimmed.contains("-.->") { isDashed = true; arrow = "-.->" }
    } else if trimmed.contains("-.-") && arrow.isEmpty {
        isDashed = true
    }

    // Basic arrow: ->
    if arrow.isEmpty && trimmed.contains("->") {
        arrow = "->"
    }

    // Check for semicolon label
    if let scIdx = trimmed.range(of: ";") {
        let afterSemi = String(trimmed[scIdx.upperBound...]).trimmingCharacters(in: .whitespaces)
        if !afterSemi.isEmpty {
            semicolonLabel = afterSemi
        }
    }

    if arrow.isEmpty && semicolonLabel == nil {
        return nil
    }
    if arrow.isEmpty && semicolonLabel != nil {
        arrow = "->"
    }

    // Also check dashed for -. patterns with ->
    if arrow.isEmpty && trimmed.contains("-.") {
        isDashed = true
        arrow = "-.->"
    }

    return LinkArrowInfo(arrow: arrow, isDashed: isDashed, flow: flow, label: label, portAtEnd: portAtEnd, semicolonLabel: semicolonLabel)
}

private func regexMatch(_ text: String, pattern: String) throws -> [String] {
    let regex = try NSRegularExpression(pattern: pattern)
    let nsRange = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange) else {
        throw NSError(domain: "regex", code: 0)
    }
    var groups: [String] = []
    for i in 1..<match.numberOfRanges {
        let range = match.range(at: i)
        if range.location != NSNotFound, let r = Range(range, in: text) {
            groups.append(String(text[r]))
        } else {
            groups.append("")
        }
    }
    return groups
}

// MARK: - Split line at arrow for link parsing

private func splitLinkLine(_ line: String, arrow: String) -> (String, String)? {
    // Need to find the arrow pattern while respecting that hyphens in names
    // should not be confused with the arrow

    // For labeled arrows like +'text'>, find exact position
    if let range = line.range(of: arrow) {
        let source = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        var target = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        // Remove semicolon label from target
        if let scIdx = target.firstIndex(of: ";") {
            target = String(target[..<scIdx]).trimmingCharacters(in: .whitespaces)
        }
        // Remove port at end of target
        if target.hasSuffix("+<>") { target = String(target.dropLast(3)).trimmingCharacters(in: .whitespaces) }
        else if target.hasSuffix("+>") || target.hasSuffix("+<") { target = String(target.dropLast(2)).trimmingCharacters(in: .whitespaces) }
        guard !source.isEmpty, !target.isEmpty else { return nil }
        return (source, target)
    }
    return nil
}

// MARK: - Main parser

public func parseWardleyMap(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (WardleyMapDiagram, [DiagramDiagnostic]) {
    var diagram = WardleyMapDiagram()

    guard !lines.isEmpty else {
        throw WardleyMapParserError.emptySource
    }

    var headerFound = false
    var currentPipeline: (parent: String, componentLines: [(component: String, evolution: Double, labelOffsetX: Double?, labelOffsetY: Double?)])? = nil
    var inPipeline = false
    var skipLines = 0
    var i = 0

    // Parse lines, handling pipeline blocks
    var parsedLines: [(index: Int, line: String)] = []
    var i2 = 0
    while i2 < lines.count {
        let rawLine = lines[i2]
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            i2 += 1
            continue
        }
        parsedLines.append((index: i2, line: rawLine))
        i2 += 1
    }

    for entry in parsedLines {
        let rawLine = entry.line
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            continue
        }

        // Handle header
        if !headerFound {
            let lower = trimmed.lowercased()
            if lower.hasPrefix("wardley-beta") {
                headerFound = true
                continue
            } else if lower.hasPrefix("wardley-beta") {
                headerFound = true
                continue
            } else {
                throw WardleyMapParserError.invalidHeader(trimmed)
            }
        }

        // Parse accessibility multiline block (accDescr { }) - handle specially as it spans lines
        if trimmed.lowercased().hasPrefix("accdescr") && trimmed.contains("{") {
            let parts = parseAccDescrMultiline(from: Array(lines[entry.index...]))
            diagram.accDescr = parts.text
            if parts.consumed > 0 {
                skipLines = parts.consumed - 1
            }
            i += 1
            continue
        }

        // Skip lines already consumed by multiline
        if skipLines > 0 {
            skipLines -= 1
            i += 1
            continue
        }

        if i >= lines.count { break }

        // Handle pipeline block
        if inPipeline {
            if trimmed == "}" {
                // Close pipeline
                if let pipeline = currentPipeline {
                    let parentNode = diagram.nodes.first(where: { $0.id == pipeline.parent })
                    let parentY = parentNode?.y ?? 0

                    // Mark parent
                    if var parent = diagram.nodes.first(where: { $0.id == pipeline.parent }) {
                        parent.isPipelineParent = true
                        if let idx = diagram.nodes.firstIndex(where: { $0.id == pipeline.parent }) {
                            diagram.nodes[idx].isPipelineParent = true
                        }
                    }

                    var componentIds: [String] = []
                    for comp in pipeline.componentLines {
                        let componentId = "\(pipeline.parent)_\(trimmingQuotes(comp.component))"
                        let name = trimmingQuotes(comp.component)
                        let node = WardleyNode(
                            id: componentId,
                            label: name,
                            x: comp.evolution,
                            y: parentY,
                            className: .pipelineComponent,
                            labelOffsetX: comp.labelOffsetX,
                            labelOffsetY: comp.labelOffsetY,
                            inPipeline: true
                        )
                        diagram.nodes.append(node)
                        componentIds.append(componentId)
                    }
                    diagram.pipelines.append(WardleyPipeline(nodeId: pipeline.parent, componentIds: componentIds))
                }
                currentPipeline = nil
                inPipeline = false
                i += 1
                continue
            }

            if trimmed.hasPrefix("component") {
                let rest = String(trimmed.dropFirst("component".count)).trimmingCharacters(in: .whitespaces)

                // Parse: name [evolution] label [offsetX, offsetY]
                // Similar to top-level component but with single coordinate

                // Extract name (up to [)
                let (compName, compRest) = extractNameAndRest(rest)
                guard let coordMatch = compRest.range(of: #"\[(\d+\.?\d*)\]"#, options: .regularExpression) else {
                    throw WardleyMapParserError.missingCoordinate("pipeline component '\(compName)'")
                }
                let coordStr = String(compRest[coordMatch])
                let evolution = try parseSingleCoordinate(coordStr, context: "pipeline component '\(compName)' evolution")

                let afterCoord = String(compRest[coordMatch.upperBound...]).trimmingCharacters(in: .whitespaces)
                var labelOffsetX: Double? = nil
                var labelOffsetY: Double? = nil

                if afterCoord.lowercased().hasPrefix("label") {
                    let labelInfo = parseLabelOffsets(afterCoord)
                    labelOffsetX = labelInfo.x
                    labelOffsetY = labelInfo.y
                }

                currentPipeline?.componentLines.append((component: compName, evolution: evolution, labelOffsetX: labelOffsetX, labelOffsetY: labelOffsetY))
                i += 1
                continue
            }
        }

        // Handle pipeline start
        if trimmed.lowercased().hasPrefix("pipeline") {
            let rest = String(trimmed.dropFirst("pipeline".count)).trimmingCharacters(in: .whitespaces)

            if rest.hasSuffix("{") {
                let parentName = trimmingQuotes(String(rest.dropLast()).trimmingCharacters(in: .whitespaces))
                currentPipeline = (parent: parentName, componentLines: [])
                inPipeline = true
                i += 1
                continue
            } else if rest.contains("{") {
                let parts = rest.split(separator: "{", maxSplits: 1)
                let parentName = trimmingQuotes(parts[0].trimmingCharacters(in: .whitespaces))
                currentPipeline = (parent: parentName, componentLines: [])
                inPipeline = true
                i += 1
                continue
            } else {
                // { might be on the next line
                let parentName = trimmingQuotes(rest)
                // Look ahead for {
                var found = false
                for j in (entry.index + 1)..<lines.count {
                    let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if nextLine.isEmpty { continue }
                    if nextLine == "{" {
                        currentPipeline = (parent: parentName, componentLines: [])
                        inPipeline = true
                        found = true
                        i = j + 1
                        break
                    }
                }
                if !found {
                    throw WardleyMapParserError.pipelineExpectedOpenBrace(parentName)
                }
                continue
            }
        }

        // Parse title
        if hasPrefixOutsideQuotes(trimmed, prefix: "title ") {
            let titleText = String(trimmed.dropFirst("title ".count)).trimmingCharacters(in: .whitespaces)
            diagram.diagramTitle = titleText
            i += 1
            continue
        }

        // Parse accTitle
        if let accTitle = parseAccTitleFromLine(trimmed) {
            diagram.accTitle = accTitle
            i += 1
            continue
        }

        // Parse accDescr single-line
        if let accDescr = parseAccDescrFromLine(trimmed) {
            diagram.accDescr = accDescr
            i += 1
            continue
        }

        // Parse size
        if hasPrefixOutsideQuotes(trimmed, prefix: "size ") {
            let rest = String(trimmed.dropFirst("size ".count)).trimmingCharacters(in: .whitespaces)
            let cleaned = rest.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) else {
                throw WardleyMapParserError.invalidSize(trimmed)
            }
            diagram.size = WardleySize(width: w, height: h)
            i += 1
            continue
        }

        // Parse evolution
        if hasPrefixOutsideQuotes(trimmed, prefix: "evolution ") {
            let rest = String(trimmed.dropFirst("evolution ".count)).trimmingCharacters(in: .whitespaces)
            let (stages, boundaries) = try parseEvolutionStages(rest)
            diagram.axes.stages = stages
            diagram.axes.stageBoundaries = boundaries
            i += 1
            continue
        }

        // Parse anchor
        if hasPrefixOutsideQuotes(trimmed, prefix: "anchor ") {
            let rest = String(trimmed.dropFirst("anchor ".count)).trimmingCharacters(in: .whitespaces)
            let (namePart, coordPart) = extractNameAndRest(rest)
            let name = trimmingQuotes(namePart)
            let (x, y) = try parseCoordinatePair(coordPart, context: "Anchor '\(name)'")
            let node = WardleyNode(id: name, label: name, x: x, y: y, className: .anchor)
            diagram.nodes.append(node)
            i += 1
            continue
        }

        // Parse component
        if hasPrefixOutsideQuotes(trimmed, prefix: "component ") {
            let rest = String(trimmed.dropFirst("component ".count)).trimmingCharacters(in: .whitespaces)
            let (namePart, restAfterName) = extractNameAndRest(rest)
            let name = trimmingQuotes(namePart)

            // Parse coordinates [visibility, evolution]
            guard let firstBracket = restAfterName.firstIndex(of: "["),
                  let lastBracket = restAfterName.firstIndex(of: "]") else {
                throw WardleyMapParserError.missingCoordinate("Component '\(name)'")
            }
            let coordStr = String(restAfterName[firstBracket...lastBracket])
            let (x, y) = try parseCoordinatePair(coordStr, context: "Component '\(name)'")

            var afterCoord = String(restAfterName[lastBracket...].dropFirst()).trimmingCharacters(in: .whitespaces)

            var labelOffsetX: Double? = nil
            var labelOffsetY: Double? = nil
            var sourceStrategy: WardleySourceStrategy? = nil
            var inertia = false

            // Parse label
            if afterCoord.lowercased().hasPrefix("label") {
                let labelInfo = parseLabelOffsets(afterCoord)
                labelOffsetX = labelInfo.x
                labelOffsetY = labelInfo.y
                // Remove processed label from afterCoord
                if let range = afterCoord.range(of: "label") {
                    let afterLabel = String(afterCoord[range.lowerBound...])
                    afterCoord = removeLabelStatement(afterLabel)
                }
            }

            // Parse decorators and inertia
            let remaining = afterCoord.trimmingCharacters(in: .whitespaces)
            sourceStrategy = parseDecorator(remaining)
            inertia = (remaining.lowercased().contains("inertia")) || (remaining.lowercased().contains("(inertia)"))

            let node = WardleyNode(
                id: name,
                label: name,
                x: x,
                y: y,
                className: .component,
                labelOffsetX: labelOffsetX,
                labelOffsetY: labelOffsetY,
                inertia: inertia,
                sourceStrategy: sourceStrategy
            )
            diagram.nodes.append(node)
            i += 1
            continue
        }

        // Parse note
        if hasPrefixOutsideQuotes(trimmed, prefix: "note ") {
            let rest = String(trimmed.dropFirst("note ".count)).trimmingCharacters(in: .whitespaces)
            // Format: "text" [visibility, evolution]
            guard let firstQuote = rest.firstIndex(of: "\"") else {
                throw WardleyMapParserError.invalidStatement(trimmed)
            }
            var afterQuote = rest[firstQuote...]
            var textChars: [Character] = []
            afterQuote.removeFirst()
            while !afterQuote.isEmpty {
                let ch = afterQuote.removeFirst()
                if ch == "\"" && textChars.last != "\\" {
                    break
                }
                textChars.append(ch)
            }
            let text = String(textChars)
            let coordPart = String(afterQuote).trimmingCharacters(in: .whitespaces)
            let (x, y) = try parseCoordinatePair(coordPart, context: "Note")
            diagram.notes.append(WardleyNote(text: text, x: x, y: y))
            i += 1
            continue
        }

        // Parse annotations (box position)
        if hasPrefixOutsideQuotes(trimmed, prefix: "annotations ") {
            let rest = String(trimmed.dropFirst("annotations ".count)).trimmingCharacters(in: .whitespaces)
            // Can have coordinate values that are int or decimal
            let cleaned = rest.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let _ = Double(parts[0]), let _ = Double(parts[1]) else {
                throw WardleyMapParserError.invalidStatement(trimmed)
            }
            let (x, y) = try parseCoordinateValue(rest, context: "Annotations box")
            diagram.annotationsBox = WardleyCoordinate(x: x, y: y)
            i += 1
            continue
        }

        // Parse annotation (individual)
        if hasPrefixOutsideQuotes(trimmed, prefix: "annotation ") {
            let rest = String(trimmed.dropFirst("annotation ".count)).trimmingCharacters(in: .whitespaces)
            // Format: number, [x, y] "text"
            let parts = rest.split(separator: ",", maxSplits: 1)
            guard let numberStr = parts.first?.trimmingCharacters(in: .whitespaces),
                  let number = Int(numberStr) else {
                throw WardleyMapParserError.annotationMissingNumber(trimmed)
            }

            let afterNumber = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            guard let bracketStart = afterNumber.firstIndex(of: "["),
                  let bracketEnd = afterNumber.firstIndex(of: "]") else {
                throw WardleyMapParserError.annotationMissingText(trimmed)
            }
            let coordStr = String(afterNumber[bracketStart...bracketEnd])
            let (x, y) = try parseCoordinateValue(coordStr, context: "Annotation \(number)")

            let afterBracket = String(afterNumber[bracketEnd...].dropFirst()).trimmingCharacters(in: .whitespaces)
            guard let firstQuote = afterBracket.firstIndex(of: "\""),
                  let lastQuote = afterBracket.lastIndex(of: "\"") else {
                throw WardleyMapParserError.annotationMissingText(trimmed)
            }
            let text = String(afterBracket[afterBracket.index(after: firstQuote)..<lastQuote])

            if diagram.annotations.contains(where: { $0.number == number }) {
                throw WardleyMapParserError.duplicateAnnotationNumber(number)
            }

            diagram.annotations.append(WardleyAnnotation(
                number: number,
                coordinates: [WardleyCoordinate(x: x, y: y)],
                text: text
            ))
            i += 1
            continue
        }

        // Parse evolve
        if hasPrefixOutsideQuotes(trimmed, prefix: "evolve ") {
            let rest = String(trimmed.dropFirst("evolve ".count)).trimmingCharacters(in: .whitespaces)
            let (componentName, targetVal) = try parseEvolveStatementRest(rest, sourceLine: trimmed)

            let targetX = try normalizeCoordinate(targetVal, context: "Evolve '\(componentName)' target")
            let componentNameClean = trimmingQuotes(componentName)

            // Get the component's current Y
            let node = diagram.nodes.first(where: { $0.id == componentNameClean || $0.label == componentNameClean })
            let nodeY = node?.y ?? 0

            diagram.trends.append(WardleyTrend(nodeId: componentNameClean, targetX: targetX, targetY: nodeY))
            i += 1
            continue
        }

        // Parse accelerator
        if hasPrefixOutsideQuotes(trimmed, prefix: "accelerator ") {
            let rest = String(trimmed.dropFirst("accelerator ".count)).trimmingCharacters(in: .whitespaces)
            let (namePart, coordPart) = extractNameAndRest(rest)
            let name = trimmingQuotes(namePart)
            let (x, y) = try parseCoordinatePair(coordPart, context: "Accelerator '\(name)'")
            diagram.accelerators.append(WardleyAccelerator(name: name, x: x, y: y))
            i += 1
            continue
        }

        // Parse deaccelerator
        if hasPrefixOutsideQuotes(trimmed, prefix: "deaccelerator ") {
            let rest = String(trimmed.dropFirst("deaccelerator ".count)).trimmingCharacters(in: .whitespaces)
            let (namePart, coordPart) = extractNameAndRest(rest)
            let name = trimmingQuotes(namePart)
            let (x, y) = try parseCoordinatePair(coordPart, context: "Deaccelerator '\(name)'")
            diagram.deaccelerators.append(WardleyDeaccelerator(name: name, x: x, y: y))
            i += 1
            continue
        }

        // Parse link
        if let arrowInfo = detectArrowInLine(trimmed) {
            if let (source, target) = splitLinkLine(trimmed, arrow: arrowInfo.arrow) {
                let cleanedSource = trimmingQuotes(source)
                let cleanedTarget = trimmingQuotes(target)
                let label = arrowInfo.semicolonLabel ?? arrowInfo.label
                let link = WardleyLink(
                    source: cleanedSource,
                    target: cleanedTarget,
                    dashed: arrowInfo.isDashed,
                    label: label,
                    flow: arrowInfo.flow
                )
                diagram.links.append(link)
                i += 1
                continue
            }
        }

        // Skip empty/comment lines
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            i += 1
            continue
        }

        // Unknown statement
        throw WardleyMapParserError.invalidStatement(trimmed)
    }

    // Apply frontmatter overrides
    if let fm = frontmatter {
        if let cfg = fm.wardleyBetaConfig { diagram.config = cfg }
        if let theme = fm.wardleyTheme { diagram.theme = theme }
        if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle {
            diagram.diagramTitle = fmTitle
        }
    }

    return (diagram, [])
}

// MARK: - Parsing helpers

private func parseAccDescrMultiline(from lines: [String]) -> (text: String, consumed: Int) {
    var textLines: [String] = []
    var consumed = 0
    var started = false

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if !started && trimmed.lowercased().hasPrefix("accdescr") {
            started = true
            let contentAfterBrace: String
            if let braceIdx = trimmed.firstIndex(of: "{") {
                contentAfterBrace = String(trimmed[trimmed.index(after: braceIdx)]).trimmingCharacters(in: .whitespaces)
            } else {
                contentAfterBrace = trimmed
            }
            if contentAfterBrace.contains("}") {
                let text = contentAfterBrace.replacingOccurrences(of: "}", with: "").trimmingCharacters(in: .whitespaces)
                textLines.append(text)
                consumed += 1
                break
            }
            if !contentAfterBrace.isEmpty {
                textLines.append(contentAfterBrace)
            }
            consumed += 1
            continue
        }
        if started {
            if trimmed.contains("}") {
                let text = trimmed.replacingOccurrences(of: "}", with: "").trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    textLines.append(text)
                }
                consumed += 1
                break
            }
            textLines.append(trimmed)
        }
        consumed += 1
    }

    return (textLines.joined(separator: "\n"), consumed)
}

private func parseAccTitleFromLine(_ trimmed: String) -> String? {
    let lower = trimmed.lowercased()
    guard lower.hasPrefix("acctitle") else { return nil }
    let after = String(trimmed.dropFirst("acctitle".count)).trimmingCharacters(in: .whitespaces)
    if after.hasPrefix(":") {
        return String(after.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    return nil
}

private func parseAccDescrFromLine(_ trimmed: String) -> String? {
    let lower = trimmed.lowercased()
    guard lower.hasPrefix("accdescr") else { return nil }
    let after = String(trimmed.dropFirst("accdescr".count)).trimmingCharacters(in: .whitespaces)

    // Don't handle multiline here
    if after.contains("{") { return nil }

    if after.hasPrefix(":") {
        return String(after.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
    return nil
}

private func extractNameAndRest(_ text: String) -> (name: String, rest: String) {
    let trimmed = text.trimmingCharacters(in: .whitespaces)

    // If quoted, extract quoted string
    if trimmed.hasPrefix("\"") {
        var chars = Array(trimmed.dropFirst())
        var nameChars: [Character] = []
        while !chars.isEmpty {
            let ch = chars.removeFirst()
            if ch == "\"" {
                break
            }
            nameChars.append(ch)
        }
        let rest = String(chars).trimmingCharacters(in: .whitespaces)
        return (String(nameChars), rest)
    }

    // Unquoted name: scan until we find [ or end
    // Handle hyphenated names that stop before ->
    let chars = Array(trimmed)
    var nameChars: [Character] = []
    var i = 0
    while i < chars.count {
        let ch = chars[i]
        if ch == "[" {
            break
        }
        if ch == "-" && i + 1 < chars.count && chars[i + 1] == ">" {
            break
        }
        nameChars.append(ch)
        i += 1
    }

    let name = String(nameChars).trimmingCharacters(in: .whitespaces)
    let rest = String(chars[i...]).trimmingCharacters(in: .whitespaces)
    return (name, rest)
}

private func trimmingQuotes(_ s: String) -> String {
    stripQuotes(s)
}

private func parseLabelOffsets(_ text: String) -> (x: Double?, y: Double?) {
    // Format: label [negX? offsetX, negY? offsetY]
    guard let labelRange = text.lowercased().range(of: "label") else {
        return (nil, nil)
    }
    let afterLabel = String(text[labelRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    guard let bracketStart = afterLabel.firstIndex(of: "["),
          let bracketEnd = afterLabel.firstIndex(of: "]") else {
        return (nil, nil)
    }
    let inside = String(afterLabel[afterLabel.index(after: bracketStart)..<bracketEnd])
    let parts = inside.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count == 2 else { return (nil, nil) }

    var x: Double?
    var y: Double?

    let xStr = parts[0]
    if let xVal = Double(xStr) {
        x = xVal
    } else if xStr.hasPrefix("-"), let xVal = Double(xStr) {
        x = xVal
    }

    let yStr = parts[1]
    if let yVal = Double(yStr) {
        y = yVal
    } else if yStr.hasPrefix("-"), let yVal = Double(yStr) {
        y = yVal
    }

    return (x, y)
}

private func parseEvolveStatementRest(_ rest: String, sourceLine: String) throws -> (componentName: String, target: Double) {
    let trimmed = rest.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
        throw WardleyMapParserError.evolveMissingComponent(sourceLine)
    }

    if trimmed.hasPrefix("\"") {
        var chars = Array(trimmed.dropFirst())
        var nameChars: [Character] = []
        var escaped = false
        while !chars.isEmpty {
            let ch = chars.removeFirst()
            if escaped {
                nameChars.append(ch)
                escaped = false
                continue
            }
            if ch == "\\" {
                nameChars.append(ch)
                escaped = true
                continue
            }
            if ch == "\"" {
                let targetText = String(chars).trimmingCharacters(in: .whitespaces)
                guard let target = Double(targetText) else {
                    throw WardleyMapParserError.evolveMissingTarget(sourceLine)
                }
                return (String(nameChars), target)
            }
            nameChars.append(ch)
        }
        throw WardleyMapParserError.evolveMissingComponent(sourceLine)
    }

    guard let splitIndex = trimmed.lastIndex(where: { $0 == " " || $0 == "\t" }) else {
        throw WardleyMapParserError.evolveMissingTarget(sourceLine)
    }

    let name = String(trimmed[..<splitIndex]).trimmingCharacters(in: .whitespaces)
    let targetText = String(trimmed[trimmed.index(after: splitIndex)...]).trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else {
        throw WardleyMapParserError.evolveMissingComponent(sourceLine)
    }
    guard let target = Double(targetText) else {
        throw WardleyMapParserError.evolveMissingTarget(sourceLine)
    }
    return (name, target)
}

private func removeLabelStatement(_ text: String) -> String {
    guard let labelRange = text.lowercased().range(of: "label") else {
        return text
    }
    let afterLabel = String(text[labelRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    guard let bracketEnd = afterLabel.firstIndex(of: "]") else {
        return afterLabel
    }
    return String(afterLabel[afterLabel.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
}

private func parseDecorator(_ text: String) -> WardleySourceStrategy? {
    let t = text.lowercased().trimmingCharacters(in: .whitespaces)
    if t.contains("(build)") { return .build }
    if t.contains("(buy)") { return .buy }
    if t.contains("(outsource)") { return .outsource }
    if t.contains("(market)") { return .market }
    return nil
}

private func parseEvolutionStages(_ text: String) throws -> ([String], [Double]?) {
    // Split on -> while respecting quoted strings
    let stages = splitOnArrow(text)
    if stages.count < 2 {
        throw WardleyMapParserError.invalidEvolutionStage(text)
    }

    var stageNames: [String] = []
    var boundaries: [Double] = []
    var hasAnyBoundary = false

    for stage in stages {
        let s = stage.trimmingCharacters(in: .whitespaces)
        var name = s
        var boundary: Double?

        // Check for @boundary
        if let atIdx = s.lastIndex(of: "@") {
            let boundaryStr = String(s[s.index(after: atIdx)...])
            if let b = Double(boundaryStr) {
                boundary = b
                name = String(s[..<atIdx]).trimmingCharacters(in: .whitespaces)
            }
        }

        stageNames.append(name)
        if let b = boundary {
            boundaries.append(b)
            hasAnyBoundary = true
        }
    }

    return (stageNames, hasAnyBoundary && boundaries.count == stageNames.count ? boundaries : nil)
}

private func splitOnArrow(_ text: String) -> [String] {
    // Splits on -> while respecting quoted strings
    var parts: [String] = []
    var current: [Character] = []
    var inQuote = false
    let chars = Array(text)

    var i = 0
    while i < chars.count {
        let ch = chars[i]
        if inQuote {
            current.append(ch)
            if ch == "\"" {
                inQuote = false
            }
            i += 1
            continue
        }
        if ch == "\"" {
            inQuote = true
            current.append(ch)
            i += 1
            continue
        }
        if ch == "-" && i + 1 < chars.count && chars[i + 1] == ">" {
            let part = String(current).trimmingCharacters(in: .whitespaces)
            if !part.isEmpty {
                parts.append(part)
            }
            current = []
            i += 2
            continue
        }
        current.append(ch)
        i += 1
    }

    let part = String(current).trimmingCharacters(in: .whitespaces)
    if !part.isEmpty {
        parts.append(part)
    }

    return parts
}
