import Foundation
import DiagramKitCommon

public enum KanbanParserError: Error, LocalizedError {
    case invalidHeader(String)
    case itemsWithoutSection(String)
    case invalidShape(String)
    case invalidMetadata(String)
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let found):
            return "Invalid Kanban header. Expected 'kanban', found '\(found)'."
        case .itemsWithoutSection(let label):
            return "Items without section detected, found section (\"\(label)\")."
        case .invalidShape(let shape):
            return "No such shape: \(shape). Shape names should be lowercase."
        case .invalidMetadata(let detail):
            return "Invalid Kanban metadata: \(detail)."
        case .emptyInput:
            return "Kanban diagram is empty."
        }
    }
}

public func parseKanbanDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (KanbanDiagram, [DiagramDiagnostic]) {
    let config = frontmatter?.perDiagram.kanban.config ?? KanbanDiagramConfig()
    var diagramTitle = frontmatter?.shared.diagramTitle ?? frontmatter?.shared.title
    var accTitle: String?
    var accDescr: String?
    var kbnCounter = 0
    var diagnostics: [DiagramDiagnostic] = []

    func nextKbnId() -> String {
        kbnCounter += 1
        return "kbn\(kbnCounter)"
    }

    var allNodes: [KanbanNode] = []
    var sectionIndentLevel: Int? = nil
    var currentSectionId: String? = nil
    var headerFound = false

    var index = 0
    while index < lines.count {
        let rawLine = lines[index]
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerTrimmed = trimmed.lowercased()

        if !headerFound {
            if lowerTrimmed.isEmpty || lowerTrimmed.hasPrefix("%%") {
                index += 1
                continue
            }
            let firstWord = lowerTrimmed.split(separator: " ").first.map(String.init) ?? lowerTrimmed
            if firstWord == "kanban" {
                headerFound = true
                index += 1
                continue
            }
            throw KanbanParserError.invalidHeader(trimmed)
        }

        if trimmed.isEmpty || lowerTrimmed.hasPrefix("%%") {
            index += 1
            continue
        }

        let indent = rawLine.prefix(while: { $0 == " " }).count
        var commentStripped = _stripKanbanComment(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)

        if commentStripped.isEmpty {
            index += 1
            continue
        }

        if let title = _kanbanTitleValue(commentStripped) {
            diagramTitle = title
            index += 1
            continue
        }

        if let title = _kanbanColonDirectiveValue(commentStripped, keyword: "accTitle") {
            accTitle = title
            index += 1
            continue
        }

        if let descr = _kanbanColonDirectiveValue(commentStripped, keyword: "accDescr") {
            accDescr = descr
            index += 1
            continue
        }

        if _kanbanAccessibilityBlockStart(commentStripped, keyword: "accDescr") {
            let parsed = try _parseKanbanAccessibilityBlock(lines, startIndex: index, keyword: "accDescr")
            accDescr = parsed.text
            index = parsed.endIndex + 1
            continue
        }

        if _kanbanAccessibilityBlockStart(commentStripped, keyword: "accTitle") {
            let parsed = try _parseKanbanAccessibilityBlock(lines, startIndex: index, keyword: "accTitle")
            accTitle = parsed.text
            index = parsed.endIndex + 1
            continue
        }

        if commentStripped.contains("@{") && !_kanbanMetadataBlockIsComplete(commentStripped) {
            var metadataIndex = index + 1
            while metadataIndex < lines.count {
                let nextLine = _stripKanbanComment(lines[metadataIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                commentStripped += "\n" + nextLine
                if _kanbanMetadataBlockIsComplete(commentStripped) {
                    break
                }
                metadataIndex += 1
            }
            guard _kanbanMetadataBlockIsComplete(commentStripped) else {
                throw KanbanParserError.invalidMetadata("Unfinished metadata block")
            }
            index = metadataIndex
        }

        let line = commentStripped

        if let decoration = _parseKanbanDecoration(line) {
            _applyKanbanDecoration(decoration, to: &allNodes)
            index += 1
            continue
        }

        if sectionIndentLevel == nil {
            sectionIndentLevel = indent
        }

        guard let sl = sectionIndentLevel else {
            throw KanbanParserError.emptyInput
        }

        if indent < sl {
            throw KanbanParserError.itemsWithoutSection(line)
        }

        if indent == sl {
            let parsed = try _parseSingleKanbanNode(
                line: line,
                level: indent,
                kbnGenerator: nextKbnId,
                isSection: true
            )
            var section = parsed.node
            section.isGroup = true
            allNodes.append(section)
            currentSectionId = section.id
            index += 1
            continue
        }

        if indent > sl {
            guard let _ = currentSectionId else {
                throw KanbanParserError.itemsWithoutSection(line)
            }

            let parsed = try _parseSingleKanbanNode(
                line: line,
                level: indent,
                kbnGenerator: nextKbnId,
                isSection: false
            )
            var card = parsed.node
            card.isGroup = false
            card.parentId = currentSectionId
            allNodes.append(card)
            index += 1
            continue
        }
    }

    if !headerFound {
        throw KanbanParserError.emptyInput
    }

    var sanitizedNodes: [KanbanNode] = []
    for var node in allNodes {
        if node.id.isEmpty {
            node.id = nextKbnId()
        }
        sanitizedNodes.append(node)
    }

    let sanitizedSections = sanitizedNodes.filter { $0.isGroup }

    var seenIds = Set<String>()
    for node in sanitizedNodes {
        if seenIds.contains(node.id) {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "[Kanban] duplicate node ID \"\(node.id)\"",
                location: nil
            ))
        }
        seenIds.insert(node.id)
    }

    let diagram = KanbanDiagram(
        nodes: sanitizedNodes,
        sections: sanitizedSections,
        config: config,
        accTitle: accTitle,
        accDescr: accDescr,
        diagramTitle: diagramTitle
    )
    return (diagram, diagnostics)
}

private func _kanbanTitleValue(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    guard lower.hasPrefix("title ") else { return nil }
    let start = trimmed.index(trimmed.startIndex, offsetBy: "title".count)
    return String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _kanbanColonDirectiveValue(_ line: String, keyword: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    let lowerKeyword = keyword.lowercased()
    guard lower.hasPrefix(lowerKeyword) else { return nil }
    let afterKeyword = trimmed.index(trimmed.startIndex, offsetBy: keyword.count)
    guard afterKeyword < trimmed.endIndex, trimmed[afterKeyword] == ":" else { return nil }
    let valueStart = trimmed.index(after: afterKeyword)
    return String(trimmed[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _kanbanAccessibilityBlockStart(_ line: String, keyword: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return trimmed.hasPrefix(keyword.lowercased()) && trimmed.contains("{")
}

private func _parseKanbanAccessibilityBlock(
    _ lines: [String],
    startIndex: Int,
    keyword: String
) throws -> (text: String, endIndex: Int) {
    let firstLine = _stripKanbanComment(lines[startIndex])
    guard let open = firstLine.range(of: "{") else {
        throw KanbanParserError.invalidMetadata("Missing accessibility block opener")
    }

    var collected: [String] = []
    let firstRemainder = String(firstLine[open.upperBound...])
    if let close = firstRemainder.range(of: "}") {
        let text = String(firstRemainder[..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { collected.append(text) }
        return (collected.joined(separator: "\n"), startIndex)
    }

    let firstText = firstRemainder.trimmingCharacters(in: .whitespacesAndNewlines)
    if !firstText.isEmpty { collected.append(firstText) }

    var index = startIndex + 1
    while index < lines.count {
        let stripped = _stripKanbanComment(lines[index])
        if let close = stripped.range(of: "}") {
            let beforeClose = String(stripped[..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeClose.isEmpty { collected.append(beforeClose) }
            return (collected.joined(separator: "\n"), index)
        }
        let line = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { collected.append(line) }
        index += 1
    }

    throw KanbanParserError.invalidMetadata("Unfinished \(keyword) block")
}

private func _kanbanMetadataBlockIsComplete(_ text: String) -> Bool {
    let chars = Array(text)
    var index = 0
    var started = false
    var depth = 0
    var inSingle = false
    var inDouble = false

    while index < chars.count {
        let ch = chars[index]
        if !started {
            if ch == "@" && index + 1 < chars.count && chars[index + 1] == "{" {
                started = true
                depth = 1
                index += 2
                continue
            }
            index += 1
            continue
        }

        if ch == "'" && !inDouble {
            inSingle.toggle()
        } else if ch == "\"" && !inSingle {
            inDouble.toggle()
        } else if !inSingle && !inDouble {
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { return true }
            }
        }

        index += 1
    }

    return false
}

private func _parseKanbanDecoration(_ line: String) -> (icon: String?, cssClasses: String?)? {
    if line.hasPrefix("::icon("), line.hasSuffix(")") {
        let iconName = String(line.dropFirst("::icon(".count).dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        return (icon: _kbnSanitizeText(iconName), cssClasses: nil)
    }
    if line.hasPrefix(":::") && !line.hasPrefix("::::") {
        let classes = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        return (icon: nil, cssClasses: _kbnSanitizeText(classes))
    }
    return nil
}

private func _applyKanbanDecoration(_ decoration: (icon: String?, cssClasses: String?), to nodes: inout [KanbanNode]) {
    guard !nodes.isEmpty else { return }
    if let icon = decoration.icon {
        nodes[nodes.count - 1].icon = icon
    }
    if let classes = decoration.cssClasses {
        nodes[nodes.count - 1].cssClasses = classes
    }
}

public func _stripKanbanComment(_ line: String) -> String {
    var result = ""
    var inSingleQuote = false
    var inDoubleQuote = false
    var inBrace = 0
    let chars = Array(line)

    var i = 0
    while i < chars.count {
        let ch = chars[i]

        if !inSingleQuote && !inDoubleQuote && inBrace == 0 {
            if ch == "%" && i + 1 < chars.count && chars[i + 1] == "%" {
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if !inDoubleQuote && !inSingleQuote && inBrace > 0 {
            if ch == "{" { inBrace += 1 }
            else if ch == "}" { inBrace -= 1 }
            result.append(ch)
            i += 1
            continue
        }

        if ch == "'" && !inDoubleQuote && inBrace == 0 { inSingleQuote.toggle() }
        else if ch == "\"" && !inSingleQuote && inBrace == 0 { inDoubleQuote.toggle() }
        else if ch == "@" && !inSingleQuote && !inDoubleQuote && inBrace == 0 && i + 1 < chars.count && chars[i + 1] == "{" {
            inBrace = 1
            result.append(ch)
            result.append(chars[i + 1])
            i += 2
            continue
        }

        result.append(ch)
        i += 1
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

public func _parseSingleKanbanNode(
    line: String,
    level: Int,
    kbnGenerator: () -> String,
    isSection: Bool
) throws -> (node: KanbanNode, decorations: (icon: String?, css: String?)) {
    let trimmed = line
    var remaining = trimmed

    var metaLabel: String? = nil
    var metaIcon: String? = nil
    var metaAssigned: String? = nil
    var metaTicket: String? = nil
    var metaPriority: String? = nil
    var metaShape: String? = nil
    var metaUnknown: [String: String]? = nil

    if let atIdx = remaining.range(of: "@{") {
        let beforeMeta = String(remaining[..<atIdx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let metaStr = String(remaining[atIdx.lowerBound...])
        let meta = try parseKanbanMetadata(metaStr)
        var unknown: [String: String] = [:]
        for (k, v) in meta {
            switch k {
            case "label": metaLabel = v
            case "icon": metaIcon = v
            case "assigned": metaAssigned = v
            case "ticket": metaTicket = v
            case "priority": metaPriority = v
            case "shape": metaShape = v
            default: unknown[k] = v
            }
        }
        if !unknown.isEmpty { metaUnknown = unknown }
        remaining = beforeMeta
    }

    if let shape = metaShape {
        if shape.lowercased() != "kanbanitem" {
            throw KanbanParserError.invalidShape(shape)
        }
    }

    var id: String? = nil
    var label: String = remaining
    var shape: KanbanNodeShape = .default_

    let bracketContent = _extractBracketContentAfterId(remaining)
    if let (extractedId, inner, delType, afterBracket) = bracketContent {
        remaining = afterBracket.trimmingCharacters(in: .whitespacesAndNewlines)
        label = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        id = extractedId
        shape = delType
    } else {
        let tokens = _splitIdLabel(remaining)
        if tokens.id != nil {
            id = tokens.id
            label = tokens.label
        }
    }

    if label.isEmpty { label = id ?? "" }

    let finalLabel = _kbnSanitizeText(metaLabel ?? _kbnStripQuotes(label))
    let finalId = _kbnSanitizeText(id ?? finalLabel)
    let generatedId = finalId.isEmpty ? kbnGenerator() : finalId

    return (
        node: KanbanNode(
            id: generatedId,
            label: finalLabel,
            level: level,
            shape: shape,
            parentId: nil,
            icon: metaIcon,
            assigned: metaAssigned,
            ticket: metaTicket,
            priority: metaPriority,
            cssClasses: nil,
            width: 200,
            padding: 8,
            isGroup: isSection,
            unknownMetadata: metaUnknown
        ),
        decorations: (icon: nil, css: nil)
    )
}

public func _extractBracketContentAfterId(_ text: String) -> (id: String?, content: String, type: KanbanNodeShape, after: String)? {
    let chars = Array(text)
    var i = 0
    var quoteChar: Character?

    while i < chars.count {
        let ch = chars[i]
        if let qc = quoteChar {
            if ch == qc { quoteChar = nil }
            i += 1
            continue
        }
        if ch == "\"" || ch == "'" { quoteChar = ch; i += 1; continue }

        let remaining = String(chars[i...])
        if remaining.hasPrefix("[") { return _bracketContentAt(remaining, i, chars, shape: .rect) }
        if remaining.hasPrefix("((") { return _bracketContentAt(remaining, i, chars, shape: .circle, openLen: 2, close: "))") }
        if remaining.hasPrefix("(-") { return _bracketContentAt(remaining, i, chars, shape: .cloud, openLen: 2, close: "-)") }
        if remaining.hasPrefix("))") { return _bangContentAt(i, chars) }
        if remaining.hasPrefix("{{") { return _bracketContentAt(remaining, i, chars, shape: .hexagon, openLen: 2, close: "}}") }
        if remaining.hasPrefix("(") { return _bracketContentAt(remaining, i, chars, shape: .roundedRect) }
        if remaining.hasPrefix(")") { return _cloudBangContentAt(i, chars) }

        i += 1
    }

    return nil
}

private func _bracketContentAt(_ remaining: String, _ start: Int, _ chars: [Character], shape: KanbanNodeShape, openLen: Int = 1, close: String? = nil) -> (String?, String, KanbanNodeShape, String)? {
    let closeStr: String
    if let c = close {
        closeStr = c
    } else if remaining.hasPrefix("((") { closeStr = "))" }
    else if remaining.hasPrefix("{{") { closeStr = "}}"
    } else if remaining.hasPrefix("(-") { closeStr = "-)"
    } else if remaining.hasPrefix("(") { closeStr = ")"
    } else { closeStr = "]"
    }

    var idPart: String?
    if start > 0 {
        idPart = String(chars[0..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        if idPart?.isEmpty == true { idPart = nil }
    } else {
        idPart = nil
    }

    let restOfText = String(chars[start...])
    if let end = _findMatchingDelimiter(restOfText, open: String(restOfText.prefix(openLen)), close: closeStr) {
        let inner = String(restOfText[restOfText.index(restOfText.startIndex, offsetBy: openLen)..<end])
        let closeLen = closeStr.count
        let after = String(restOfText[restOfText.index(end, offsetBy: closeLen)...])
        return (idPart, inner, shape, after)
    }
    return nil
}

private func _bangContentAt(_ start: Int, _ chars: [Character]) -> (String?, String, KanbanNodeShape, String)? {
    var idPart: String?
    if start > 0 {
        idPart = String(chars[0..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        if idPart?.isEmpty == true { idPart = nil }
    } else {
        idPart = nil
    }
    let after = String(chars[(start + 2)...])
    return (idPart, "", .bang, after)
}

private func _cloudBangContentAt(_ start: Int, _ chars: [Character]) -> (String?, String, KanbanNodeShape, String)? {
    var idPart: String?
    if start > 0 {
        idPart = String(chars[0..<start]).trimmingCharacters(in: .whitespacesAndNewlines)
        if idPart?.isEmpty == true { idPart = nil }
    } else {
        idPart = nil
    }
    let after = String(chars[(start + 1)...])
    return (idPart, "", .cloud, after)
}

public func _extractBracketContent(_ text: String) -> (content: String, type: KanbanNodeShape, after: String)? {
    let trimmed = text

    if trimmed.hasPrefix("[") {
        if let end = _findMatchingDelimiter(trimmed, open: "[", close: "]") {
            let inner = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
            let after = String(trimmed[trimmed.index(after: end)...])
            return (inner, .rect, after)
        }
    } else if trimmed.hasPrefix("((") {
        if let end = _findMatchingDelimiter(trimmed, open: "((", close: "))") {
            let inner = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<end])
            let after = String(trimmed[trimmed.index(end, offsetBy: 2)...])
            return (inner, .circle, after)
        }
    } else if trimmed.hasPrefix("(-") {
        if let end = _findMatchingDelimiter(trimmed, open: "(-", close: "-)") {
            let inner = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<end])
            let after = String(trimmed[trimmed.index(end, offsetBy: 2)...])
            return (inner, .cloud, after)
        }
    } else if trimmed.hasPrefix("))") && !trimmed.hasPrefix(")))") {
        return ("", .bang, String(trimmed.dropFirst(2)))
    } else if trimmed.hasPrefix("{{") {
        if let end = _findMatchingDelimiter(trimmed, open: "{{", close: "}}") {
            let inner = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<end])
            let after = String(trimmed[trimmed.index(end, offsetBy: 2)...])
            return (inner, .hexagon, after)
        }
    } else if trimmed.hasPrefix("(") {
        if let end = _findMatchingDelimiter(trimmed, open: "(", close: ")") {
            let inner = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
            let after = String(trimmed[trimmed.index(after: end)...])
            return (inner, .roundedRect, after)
        }
    } else if trimmed.hasPrefix(")") && !trimmed.hasPrefix("))") {
        return ("", .cloud, String(trimmed.dropFirst()))
    }

    return nil
}

public func _findMatchingDelimiter(_ text: String, open: String, close: String) -> String.Index? {
    var depth = 1
    var inSingle = false
    var inDouble = false
    var i = text.index(text.startIndex, offsetBy: open.count)
    while i < text.endIndex {
        let ch = text[i]
        if ch == "'" && !inDouble { inSingle.toggle(); i = text.index(after: i); continue }
        if ch == "\"" && !inSingle { inDouble.toggle(); i = text.index(after: i); continue }
        if !inSingle && !inDouble {
            if _matchAt(text, needle: open, index: i) {
                depth += 1
                i = text.index(i, offsetBy: open.count)
                continue
            }
            if _matchAt(text, needle: close, index: i) {
                depth -= 1
                if depth == 0 {
                    return i
                }
                i = text.index(i, offsetBy: close.count)
                continue
            }
        }
        i = text.index(after: i)
    }
    return nil
}

public func _matchAt(_ text: String, needle: String, index: String.Index) -> Bool {
    let chars = text[index...]
    return chars.hasPrefix(needle)
}

public func _splitIdLabel(_ text: String) -> (id: String?, label: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.hasPrefix("\"") {
        let inner = _kbnStripQuotes(trimmed)
        return (nil, inner)
    }

    if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") {
        let inner = String(trimmed.dropFirst().dropLast())
        return (nil, inner)
    }

    let chars = Array(trimmed)
    var i = 0
    var quoteChar: Character?

    while i < chars.count {
        let ch = chars[i]
        if let qc = quoteChar {
            if ch == qc { quoteChar = nil }
            i += 1
            continue
        }
        if ch == "\"" || ch == "'" { quoteChar = ch; i += 1; continue }

        if ch == "[" || ch == "(" || ch == "{" || ch == "@" {
            let idPart = String(chars[0..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(chars[i...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if idPart.isEmpty { return (nil, trimmed) }
            return (idPart, rest)
        }
        i += 1
    }

    return (nil, trimmed)
}

public func parseKanbanMetadata(_ text: String) throws -> [String: String] {
    var result: [String: String] = [:]
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    guard trimmed.hasPrefix("@{") else {
        throw KanbanParserError.invalidMetadata("Metadata must start with '@{'")
    }

    var depth = 0
    var content = ""
    for ch in trimmed {
        if ch == "{" { depth += 1 }
        else if ch == "}" { depth -= 1 }
        if depth > 0 {
            content.append(ch)
        } else if depth == 0 && ch == "}" {
            break
        }
    }

    let inner = content.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
    if inner.isEmpty { return result }

    let lines = inner.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var allPairs: [(key: String, value: String)] = []

    for rawLine in lines {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") { continue }
        let kv = _splitKanbanKeyValue(line)
        for (k, v) in kv {
            allPairs.append((key: k, value: v))
        }
    }

    for pair in allPairs {
        result[pair.key] = pair.value
    }

    return result
}

public func _splitKanbanKeyValue(_ line: String) -> [(String, String)] {
    var results: [(String, String)] = []
    var current = ""
    var inSingle = false
    var inDouble = false
    var depth = 0

    for ch in line {
        if ch == "'" && !inDouble { inSingle.toggle(); current.append(ch); continue }
        if ch == "\"" && !inSingle { inDouble.toggle(); current.append(ch); continue }
        if !inSingle && !inDouble {
            if ch == "{" { depth += 1 }
            else if ch == "}" { depth -= 1 }
        }
        if ch == "," && !inSingle && !inDouble && depth == 0 {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let val = _unquoteKanbanValue(String(parts[1]))
                    results.append((key, val))
                }
            }
            current = ""
        } else {
            current.append(ch)
        }
    }

    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        let parts = trimmed.split(separator: ":", maxSplits: 1)
        if parts.count >= 2 {
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let val = _unquoteKanbanValue(String(parts[1]))
            results.append((key, val))
        }
    }

    return results
}

public func _unquoteKanbanValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}

public func _kbnStripQuotes(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}

public func _kbnSanitizeText(_ text: String) -> String {
    return text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
