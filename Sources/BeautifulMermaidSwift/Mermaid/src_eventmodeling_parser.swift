import Foundation

// MARK: - Public parse entry point

public func parseEventModeling(
    _ rawLines: [String],
    frontmatter fm: DiagramFrontmatter? = nil
) throws -> EventModelingDiagram {
    let normalized = rawLines
    var diagram = EventModelingDiagram()

    // Apply frontmatter config/theme
    if let cfg = fm?.eventmodelingConfig { diagram.config = cfg }
    if let theme = fm?.eventmodelingThemeVariables { diagram.themeVariables = theme }
    if let title = fm?.diagramTitle { diagram.diagramTitle = title }

    // Skip blank/comment lines to find the header
    let firstNonBlank = normalized.firstIndex(where: {
        let t = $0.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && !t.hasPrefix("%%")
    })
    guard let headerIdx = firstNonBlank else {
        throw EventModelingParserError.emptySource
    }

    let headerLine = normalized[headerIdx].trimmingCharacters(in: .whitespaces)
    guard headerLine.hasPrefix("eventmodeling") else {
        throw EventModelingParserError.missingHeader
    }

    var accDescrLines: [String] = []
    var inAccDescrBlock = false
    var usedFrameIds = Set<String>()

    var lineIdx = headerIdx + 1
    while lineIdx < normalized.count {
        let raw = normalized[lineIdx]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        lineIdx += 1

        // Skip blank lines and comments
        if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }

        // Handle accDescr multiline block
        if inAccDescrBlock {
            if trimmed == "}" {
                inAccDescrBlock = false
                diagram.accDescr = accDescrLines.joined(separator: "\n")
                accDescrLines = []
            } else {
                accDescrLines.append(raw)
            }
            continue
        }

        let lower = trimmed.lowercased()

        // accTitle
        if lower.hasPrefix("acctitle:") {
            let value = String(trimmed.dropFirst("acctitle:".count)).trimmingCharacters(in: .whitespaces)
            diagram.accTitle = value.isEmpty ? nil : value
            continue
        }

        // accDescr: single-line
        if lower.hasPrefix("accdescr:") {
            let value = String(trimmed.dropFirst("accdescr:".count)).trimmingCharacters(in: .whitespaces)
            diagram.accDescr = value.isEmpty ? nil : value
            continue
        }

        // accDescr { multiline
        if lower.hasPrefix("accdescr {") || lower == "accdescr {" {
            inAccDescrBlock = true
            accDescrLines = []
            // Check for content on the same line after {
            let afterBrace = trimmed.dropFirst("accdescr".count).trimmingCharacters(in: .whitespaces)
            if afterBrace.hasPrefix("{") {
                let content = String(afterBrace.dropFirst()).trimmingCharacters(in: .whitespaces)
                if content == "}" {
                    diagram.accDescr = ""
                    continue
                }
                if !content.isEmpty {
                    accDescrLines.append(content)
                }
            }
            continue
        }

        // title
        if lower.hasPrefix("title ") {
            let value = String(trimmed.dropFirst("title ".count)).trimmingCharacters(in: .whitespaces)
            diagram.diagramTitle = value.isEmpty ? nil : value
            continue
        }

        // data entity: data <name> { ... }
        if lower.hasPrefix("data ") {
            let (entity, consumed) = try parseDataEntity(from: normalized, startIdx: lineIdx - 1, trimmed: trimmed)
            diagram.dataEntities.append(entity)
            lineIdx = lineIdx - 1 + consumed
            continue
        }

        // note entity: note <frameId> { ... }
        if lower.hasPrefix("note ") {
            let (entity, consumed) = try parseNoteEntity(from: normalized, startIdx: lineIdx - 1, trimmed: trimmed)
            diagram.noteEntities.append(entity)
            lineIdx = lineIdx - 1 + consumed
            continue
        }

        // entity declaration: entity <name>
        if lower.hasPrefix("entity ") {
            let name = String(trimmed.dropFirst("entity ".count)).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                throw EventModelingParserError.missingEntityIdentifier(lineIdx)
            }
            diagram.modelEntities.append(EventModelingModelEntity(name: name))
            continue
        }

        // gwt: gwt <frameId> given ... when ... then ...
        if lower.hasPrefix("gwt ") {
            let gwt = try parseGwtEntity(from: trimmed, lineNumber: lineIdx)
            diagram.gwtEntities.append(gwt)
            continue
        }

        // reset frame: rf / resetframe
        if lower.hasPrefix("rf ") || lower.hasPrefix("resetframe ") {
            let isRf = lower.hasPrefix("rf ")
            let frame = try parseFrame(from: trimmed, lineNumber: lineIdx, isReset: true, isRfCompact: isRf)
            if usedFrameIds.contains(frame.name) {
                throw EventModelingParserError.duplicateFrameId(frame.name)
            }
            usedFrameIds.insert(frame.name)
            diagram.frames.append(frame)
            continue
        }

        // time frame: tf / timeframe
        if lower.hasPrefix("tf ") || lower.hasPrefix("timeframe ") {
            let isTf = lower.hasPrefix("tf ")
            let frame = try parseFrame(from: trimmed, lineNumber: lineIdx, isReset: false, isRfCompact: isTf)
            if usedFrameIds.contains(frame.name) {
                throw EventModelingParserError.duplicateFrameId(frame.name)
            }
            usedFrameIds.insert(frame.name)
            diagram.frames.append(frame)
            continue
        }

        // Unknown line at this point is unexpected
        // Mermaid parser would ignore it; let's be lenient
    }

    // Validate cross-references
    let frameNameSet = Set(diagram.frames.map(\.name))
    let frameByName = Dictionary(uniqueKeysWithValues: diagram.frames.map { ($0.name, $0) })
    for frame in diagram.frames {
        for srcName in frame.sourceFrameNames {
            guard let sourceFrame = frameByName[srcName] else {
                throw EventModelingParserError.invalidFrameReference(srcName, lineIdx)
            }
            if !isValidSourceType(sourceFrame.modelEntityType, forTarget: frame.modelEntityType) {
                throw EventModelingParserError.invalidSourceFrameType(
                    source: sourceFrame.modelEntityType,
                    target: frame.modelEntityType,
                    lineIdx
                )
            }
        }
    }

    let dataNameSet = Set(diagram.dataEntities.map(\.name))
    for frame in diagram.frames {
        if let refName = frame.dataReferenceName, !dataNameSet.contains(refName) {
            throw EventModelingParserError.invalidDataReference(refName, lineIdx)
        }
    }

    for note in diagram.noteEntities {
        if !frameNameSet.contains(note.sourceFrameName) {
            throw EventModelingParserError.invalidFrameReference(note.sourceFrameName, lineIdx)
        }
    }

    let modelNameSet = Set(diagram.modelEntities.map(\.name))
    for gwt in diagram.gwtEntities {
        if !frameNameSet.contains(gwt.sourceFrameName) {
            throw EventModelingParserError.invalidFrameReference(gwt.sourceFrameName, lineIdx)
        }
        for stmt in gwt.givenStatements {
            if !modelNameSet.contains(stmt.modelEntityName) {
                throw EventModelingParserError.invalidFrameReference(stmt.modelEntityName, lineIdx)
            }
        }
        for stmt in gwt.whenStatements {
            if !modelNameSet.contains(stmt.modelEntityName) {
                throw EventModelingParserError.invalidFrameReference(stmt.modelEntityName, lineIdx)
            }
        }
        for stmt in gwt.thenStatements {
            if !modelNameSet.contains(stmt.modelEntityName) {
                throw EventModelingParserError.invalidFrameReference(stmt.modelEntityName, lineIdx)
            }
        }
    }

    return diagram
}

// MARK: - Frame parsing

private func parseFrame(
    from line: String,
    lineNumber: Int,
    isReset: Bool,
    isRfCompact: Bool
) throws -> EventModelingFrame {
    // Remove prefix (tf/rf/timeframe/resetframe)
    var rest: Substring
    if isRfCompact {
        // tf or rf
        let prefix = isReset ? "rf " : "tf "
        rest = line[line.range(of: prefix, options: .caseInsensitive)!.upperBound...]
    } else {
        let prefix = isReset ? "resetframe " : "timeframe "
        rest = line[line.range(of: prefix, options: .caseInsensitive)!.upperBound...]
    }
    rest = rest.trimmingPrefix(while: { $0.isWhitespace })

    // Extract frame ID (1-3 digits)
    guard let firstSpace = rest.firstIndex(where: { $0.isWhitespace }),
          firstSpace > rest.startIndex else {
        throw EventModelingParserError.missingEntityIdentifier(lineNumber)
    }
    let frameId = String(rest[..<firstSpace])
    guard frameId.allSatisfy(\.isNumber),
          frameId.count >= 1 && frameId.count <= 3 else {
        throw EventModelingParserError.invalidFrameToken(frameId, lineNumber)
    }

    rest = rest[firstSpace...].trimmingPrefix(while: { $0.isWhitespace })

    // Extract entity type
    guard let typeEnd = rest.firstIndex(where: { $0.isWhitespace }),
          typeEnd > rest.startIndex else {
        throw EventModelingParserError.invalidEntityType(String(rest), lineNumber)
    }
    let typeStr = String(rest[..<typeEnd]).lowercased()
    guard let entityType = normalizeEntityType(typeStr) else {
        throw EventModelingParserError.invalidEntityType(typeStr, lineNumber)
    }

    rest = rest[typeEnd...].trimmingPrefix(while: { $0.isWhitespace })

    // Extract entity identifier (qualified name, may contain dots)
    let identifier = extractIdentifier(from: &rest)
    guard !identifier.isEmpty else {
        throw EventModelingParserError.missingEntityIdentifier(lineNumber)
    }

    // Parse remaining tokens: ->>, [[]], inline data
    var sourceFrameNames: [String] = []
    var dataReferenceName: String?
    var dataInlineType: EventModelingDataType?
    var dataInlineValue: String?

    while !rest.isEmpty {
        if rest.hasPrefix("->>") {
            // Advance past ->>
            if let arrowEnd = rest.range(of: "->>") { rest = rest[arrowEnd.upperBound...] }
            rest = rest.trimmingPrefix(while: { $0.isWhitespace })
            // Extract next frame ID
            guard let spaceOrEnd = rest.firstIndex(where: { $0.isWhitespace || $0 == "-" || $0 == "[" || $0 == "`" }),
                  spaceOrEnd > rest.startIndex else {
                if !rest.isEmpty {
                    let ref = String(rest).trimmingCharacters(in: .whitespaces)
                    if !ref.isEmpty, ref.allSatisfy(\.isNumber) {
                        sourceFrameNames.append(ref)
                        rest = ""
                        continue
                    }
                }
                break
            }
            let ref = String(rest[..<spaceOrEnd])
            rest = rest[spaceOrEnd...].trimmingPrefix(while: { $0.isWhitespace })
            if !ref.isEmpty {
                sourceFrameNames.append(ref)
            }
        } else if rest.hasPrefix("[[") {
            if let closeIdx = rest.range(of: "]]") {
                let refStart = rest.index(rest.startIndex, offsetBy: 2)
                let refEnd = closeIdx.lowerBound
                dataReferenceName = String(rest[refStart..<refEnd]).trimmingCharacters(in: .whitespaces)
                rest = rest[closeIdx.upperBound...].trimmingPrefix(while: { $0.isWhitespace })
            } else {
                throw EventModelingParserError.invalidDataReference(String(rest.prefix(20)), lineNumber)
            }
        } else if rest.hasPrefix("`") {
            // Data type annotation: `type` { value }
            let afterBacktick = rest.index(after: rest.startIndex)
            if let closeBacktick = rest[afterBacktick...].firstIndex(of: "`") {
                let dtStr = String(rest[afterBacktick..<closeBacktick]).lowercased()
                if let dt = EventModelingDataType(rawValue: dtStr) {
                    dataInlineType = dt
                }
                rest = rest[rest.index(after: closeBacktick)...].trimmingPrefix(while: { $0.isWhitespace })
            }
            // Now parse { value }
            if rest.hasPrefix("{") {
                let (value, afterCtx) = extractBraceContent(from: rest)
                dataInlineValue = value
                rest = afterCtx.trimmingPrefix(while: { $0.isWhitespace })
            }
        } else if rest.hasPrefix("{") {
            // Inline data without type annotation
            let (value, afterCtx) = extractBraceContent(from: rest)
            dataInlineValue = value
            rest = afterCtx.trimmingPrefix(while: { $0.isWhitespace })
        } else {
            // Skip unrecognized trailing content
            break
        }
    }

    return EventModelingFrame(
        name: frameId,
        modelEntityType: entityType,
        entityIdentifier: identifier,
        isResetFrame: isReset,
        sourceFrameNames: sourceFrameNames,
        dataReferenceName: dataReferenceName,
        dataInlineType: dataInlineType,
        dataInlineValue: dataInlineValue
    )
}

// MARK: - Data entity parsing

private func parseDataEntity(
    from lines: [String],
    startIdx: Int,
    trimmed: String
) throws -> (EventModelingDataEntity, Int) {
    // Line: data <name> [datatype] {
    var rest = String(trimmed.dropFirst("data ".count)).trimmingCharacters(in: CharacterSet(charactersIn: " "))
    // Extract name
    guard !rest.isEmpty else {
        throw EventModelingParserError.malformedDataBlock(rest, startIdx + 1)
    }
    let name: String
    if let nameEnd = rest.firstIndex(where: { $0.isWhitespace || $0 == "{" || $0 == "`" }) {
        guard nameEnd > rest.startIndex else {
            throw EventModelingParserError.malformedDataBlock(rest, startIdx + 1)
        }
        name = String(rest[..<nameEnd])
        rest = String(rest[nameEnd...]).trimmingCharacters(in: .whitespaces)
    } else {
        name = rest
        rest = ""
    }

    var dataType: EventModelingDataType?
    // Check for optional datatype annotation
    dataType = parseOptionalDataType(from: &rest)

    // Find opening brace - either on same line or next lines
    var lineIdx = startIdx

    if rest.firstIndex(of: "{") == nil {
        // Scan forward for {
        lineIdx += 1
        while lineIdx < lines.count {
            var l = lines[lineIdx].trimmingCharacters(in: .whitespaces)
            if !l.isEmpty && !l.hasPrefix("%%") {
                if dataType == nil {
                    dataType = parseOptionalDataType(from: &l)
                }
                rest = l
                break
            }
            lineIdx += 1
        }
    }

    guard rest.firstIndex(of: "{") != nil else {
        throw EventModelingParserError.malformedDataBlock(name, startIdx + 1)
    }

    let (content, consumedFromBraceLine) = try collectBracedBlockContent(
        from: lines,
        startIdx: lineIdx,
        initialText: rest,
        blockName: name
    )
    let consumed = lineIdx - startIdx + consumedFromBraceLine

    return (EventModelingDataEntity(name: name, dataType: dataType, dataBlockValue: content), consumed)
}

// MARK: - Note entity parsing

private func parseNoteEntity(
    from lines: [String],
    startIdx: Int,
    trimmed: String
) throws -> (EventModelingNoteEntity, Int) {
    let afterNote = String(trimmed.dropFirst("note ".count)).trimmingCharacters(in: .whitespaces)
    // Extract frame ID
    guard !afterNote.isEmpty else {
        throw EventModelingParserError.invalidFrameReference(afterNote, startIdx + 1)
    }
    let frameId: String
    var rest: String
    if let spaceOrBrace = afterNote.firstIndex(where: { $0.isWhitespace || $0 == "{" || $0 == "`" }) {
        guard spaceOrBrace > afterNote.startIndex else {
            throw EventModelingParserError.invalidFrameReference(afterNote, startIdx + 1)
        }
        frameId = String(afterNote[..<spaceOrBrace])
        rest = String(afterNote[spaceOrBrace...]).trimmingCharacters(in: .whitespaces)
    } else {
        frameId = afterNote
        rest = ""
    }

    var dataType: EventModelingDataType?
    dataType = parseOptionalDataType(from: &rest)
    var lineIdx = startIdx

    if rest.firstIndex(of: "{") == nil {
        // Scan forward for {
        lineIdx += 1
        while lineIdx < lines.count {
            var l = lines[lineIdx].trimmingCharacters(in: .whitespaces)
            if !l.isEmpty && !l.hasPrefix("%%") {
                if dataType == nil {
                    dataType = parseOptionalDataType(from: &l)
                }
                rest = l
                break
            }
            lineIdx += 1
        }
    }

    guard rest.firstIndex(of: "{") != nil else {
        throw EventModelingParserError.malformedDataBlock(frameId, startIdx + 1)
    }

    let (content, consumedFromBraceLine) = try collectBracedBlockContent(
        from: lines,
        startIdx: lineIdx,
        initialText: rest,
        blockName: frameId
    )
    let consumed = lineIdx - startIdx + consumedFromBraceLine
    return (EventModelingNoteEntity(sourceFrameName: frameId, dataType: dataType, dataBlockValue: content), consumed)
}

// MARK: - GWT parsing

private func parseGwtEntity(from line: String, lineNumber: Int) throws -> EventModelingGwtEntity {
    // gwt <frameId> given <type> <entity> [<type> <entity> ...] [when <type> <entity> ...] then <type> <entity> ...
    let afterGwt = String(line.dropFirst("gwt ".count)).trimmingCharacters(in: .whitespaces)

    // Extract source frame ID
    guard let firstSpace = afterGwt.firstIndex(where: { $0.isWhitespace }),
          firstSpace > afterGwt.startIndex else {
        throw EventModelingParserError.malformedGwtStatement(lineNumber)
    }
    let frameId = String(afterGwt[..<firstSpace])
    let rest = String(afterGwt[afterGwt.index(after: firstSpace)...]).trimmingCharacters(in: .whitespaces)

    let lowerRest = rest.lowercased()

    // Must start with "given"
    guard lowerRest.hasPrefix("given") else {
        throw EventModelingParserError.missingGwtBlock("given", lineNumber)
    }
    // Find positions of given/when/then
    let givenIdx = lowerRest.range(of: "given")!.lowerBound
    let whenRange = lowerRest.range(of: "when")
    let thenRange = lowerRest.range(of: "then")

    guard let thenIdx = thenRange?.lowerBound else {
        throw EventModelingParserError.missingGwtBlock("then", lineNumber)
    }

    let givenBlock: String
    let whenBlock: String?
    let thenBlock: String

    if let whenIdx = whenRange?.lowerBound {
        // given ... when ... then ...
        let givenStart = lowerRest.index(givenIdx, offsetBy: "given".count)
        let givenEnd = whenIdx
        givenBlock = String(rest[givenStart..<givenEnd]).trimmingCharacters(in: .whitespaces)

        let whenStart = lowerRest.index(whenIdx, offsetBy: "when".count)
        let whenEnd = thenIdx
        whenBlock = String(rest[whenStart..<whenEnd]).trimmingCharacters(in: .whitespaces)

        let thenStart = lowerRest.index(thenIdx, offsetBy: "then".count)
        thenBlock = String(rest[thenStart...]).trimmingCharacters(in: .whitespaces)
    } else {
        // given ... then ... (no when)
        let givenStart = lowerRest.index(givenIdx, offsetBy: "given".count)
        let givenEnd = thenIdx
        givenBlock = String(rest[givenStart..<givenEnd]).trimmingCharacters(in: .whitespaces)
        whenBlock = nil

        let thenStart = lowerRest.index(thenIdx, offsetBy: "then".count)
        thenBlock = String(rest[thenStart...]).trimmingCharacters(in: .whitespaces)
    }

    let givenStatements = try parseGwtStatements(from: givenBlock, lineNumber: lineNumber)
    let whenStatements = try whenBlock.map { try parseGwtStatements(from: $0, lineNumber: lineNumber) } ?? []
    let thenStatements = try parseGwtStatements(from: thenBlock, lineNumber: lineNumber)

    return EventModelingGwtEntity(
        sourceFrameName: frameId,
        givenStatements: givenStatements,
        whenStatements: whenStatements,
        thenStatements: thenStatements
    )
}

private func parseGwtStatements(from block: String, lineNumber: Int) throws -> [EventModelingGwtStatement] {
    // Format: <type> <entity> [<type> <entity> ...]
    var statements: [EventModelingGwtStatement] = []
    var rest = Substring(block)
    rest = rest.trimmingPrefix(while: { $0.isWhitespace })

    while !rest.isEmpty {
        // Extract type
        guard let typeEnd = rest.firstIndex(where: { $0.isWhitespace }),
              typeEnd > rest.startIndex else {
            break
        }
        let typeStr = String(rest[..<typeEnd]).lowercased()
        guard let entityType = normalizeEntityType(typeStr) else {
            throw EventModelingParserError.invalidEntityType(typeStr, lineNumber)
        }

        rest = rest[typeEnd...].trimmingPrefix(while: { $0.isWhitespace })

        // Extract entity name
        guard let nameEnd = rest.firstIndex(where: { $0.isWhitespace }),
              nameEnd > rest.startIndex else {
            // Last token
            let name = String(rest).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                statements.append(EventModelingGwtStatement(entityType: entityType, modelEntityName: name))
            }
            break
        }
        let name = String(rest[..<nameEnd])
        statements.append(EventModelingGwtStatement(entityType: entityType, modelEntityName: name))
        rest = rest[nameEnd...].trimmingPrefix(while: { $0.isWhitespace })
    }

    return statements
}

// MARK: - Helpers

private func normalizeEntityType(_ typeStr: String) -> EventModelingEntityType? {
    switch typeStr {
    case "ui":    return .ui
    case "command", "cmd": return .cmd
    case "event", "evt":   return .evt
    case "processor", "pcr": return .pcr
    case "readmodel", "rmo": return .rmo
    default: return nil
    }
}

private func isValidSourceType(_ sourceType: EventModelingEntityType, forTarget targetType: EventModelingEntityType) -> Bool {
    switch targetType {
    case .cmd:
        return sourceType == .ui || sourceType == .pcr
    case .evt:
        return sourceType == .cmd
    case .rmo:
        return sourceType == .evt
    case .pcr:
        return sourceType == .rmo
    case .ui:
        return sourceType == .rmo
    }
}

private func parseOptionalDataType(from rest: inout String) -> EventModelingDataType? {
    rest = rest.trimmingCharacters(in: .whitespaces)
    guard rest.hasPrefix("`") else { return nil }
    let afterBT = rest.index(after: rest.startIndex)
    guard let closeBT = rest[afterBT...].firstIndex(of: "`") else { return nil }
    let dtStr = String(rest[afterBT..<closeBT]).lowercased()
    rest = String(rest[rest.index(after: closeBT)...]).trimmingCharacters(in: .whitespaces)
    return EventModelingDataType(rawValue: dtStr)
}

/// Extract a qualified identifier (may contain dots) from the rest of a string.
private func extractIdentifier(from rest: inout Substring) -> String {
    rest = rest.trimmingPrefix(while: { $0.isWhitespace })
    var ident = ""
    while let ch = rest.first {
        if ch.isWhitespace || ch == "-" || ch == "[" || ch == "`" || ch == "{" {
            break
        }
        if ch.isLetter || ch.isNumber || ch == "." || ch == "_" {
            ident.append(ch)
            rest = rest[rest.index(after: rest.startIndex)...]
        } else {
            break
        }
    }
    rest = rest.trimmingPrefix(while: { $0.isWhitespace })
    return ident
}

/// Extract content between matching { } braces from a Substring.
private func extractBraceContent(from text: Substring) -> (String, Substring) {
    var rest = text
    guard rest.hasPrefix("{") else { return ("", rest) }
    rest = rest[rest.index(after: rest.startIndex)...]
    var depth = 1
    var content = ""
    while let ch = rest.first {
        if ch == "{" { depth += 1 }
        else if ch == "}" {
            depth -= 1
            if depth == 0 {
                rest = rest[rest.index(after: rest.startIndex)...]
                break
            }
        }
        content.append(ch)
        rest = rest[rest.index(after: rest.startIndex)...]
    }
    return (content.trimmingCharacters(in: .whitespacesAndNewlines), rest)
}

private func collectBracedBlockContent(
    from lines: [String],
    startIdx: Int,
    initialText: String,
    blockName: String
) throws -> (String, Int) {
    var content = ""
    var depth = 0
    var started = false
    var inQuote: Character?
    var isEscaped = false
    var consumed = 0

    for idx in startIdx..<lines.count {
        let text = idx == startIdx ? initialText : lines[idx]
        consumed += 1
        if started && !content.isEmpty {
            content.append("\n")
        }

        for ch in text {
            if !started {
                if ch == "{" {
                    started = true
                    depth = 1
                }
                continue
            }

            if let quote = inQuote {
                content.append(ch)
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == quote {
                    inQuote = nil
                }
                continue
            }

            if ch == "\"" || ch == "'" || ch == "`" {
                inQuote = ch
                content.append(ch)
                continue
            }

            if ch == "{" {
                depth += 1
                content.append(ch)
                continue
            }

            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    return (content.trimmingCharacters(in: .whitespacesAndNewlines), consumed)
                }
                content.append(ch)
                continue
            }

            content.append(ch)
        }
    }

    throw EventModelingParserError.malformedDataBlock(blockName, startIdx + 1)
}

extension Substring {
    func trimmingPrefix(while predicate: (Character) -> Bool) -> Substring {
        var idx = startIndex
        while idx < endIndex && predicate(self[idx]) {
            idx = index(after: idx)
        }
        return self[idx...]
    }
}
