import Foundation
import DiagramKitCommon

// MARK: - Public Entry Point

public func parseVennDiagram(_ rawLines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (VennDiagram, [DiagramDiagnostic]) {
    guard !rawLines.isEmpty else {
        throw VennParserError.emptySource
    }

    var diagram = VennDiagram()

    var knownSets = Set<String>()
    var currentSets: [String]? = nil
    var inIndentMode = false
    var headerFound = false

    for line in rawLines {
        if !headerFound {
            // Trim leading/trailing whitespace for header detection
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || _isComment(trimmed) {
                continue
            }
            if trimmed.lowercased() == "venn-beta" || trimmed.lowercased().hasPrefix("venn-beta") {
                headerFound = true
                continue
            }
            throw VennParserError.invalidHeader
        }

        // Determine indentation
        let trimmedLeading = line.trimmingCharacters(in: .whitespaces)
        if trimmedLeading.isEmpty || _isComment(trimmedLeading) {
            continue
        }

        let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

        let stripped = trimmedLeading
        let lowerStripped = stripped.lowercased()

        // Allow title/set/union/style at any indent level
        let isTopLevel = !lowerStripped.hasPrefix("text ")

        if isTopLevel {
            // Reset indent mode when a non-text top-level statement appears
            inIndentMode = false
            if indent == 0 {
                currentSets = nil
            }

            if lowerStripped.hasPrefix("title ") {
                let titleText = _parseTitleText(stripped)
                diagram.diagramTitle = titleText
            } else if lowerStripped.hasPrefix("set ") {
                let (area, err) = _parseSetStatement(stripped, knownSets: &knownSets)
                if let error = err { throw error }
                if let area = area {
                    diagram.areas.append(area)
                    currentSets = area.sets
                    inIndentMode = true
                }
            } else if lowerStripped.hasPrefix("union ") {
                let (area, err) = _parseUnionStatement(stripped, knownSets: knownSets)
                if let error = err { throw error }
                if let area = area {
                    diagram.areas.append(area)
                    currentSets = area.sets
                    inIndentMode = true
                }
            } else if lowerStripped.hasPrefix("style ") {
                let (entry, err) = _parseStyleStatement(stripped)
                if let error = err { throw error }
                if let entry = entry {
                    diagram.styleEntries.append(entry)
                }
                inIndentMode = false
            } else {
                throw VennParserError.invalidSetStatement(stripped)
            }
        } else {
            // Text nodes: detect if explicit targets or indented
            let restAfterText = String(stripped.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            let hasExplicitTargets = _textStatementHasExplicitTargets(restAfterText)

            if hasExplicitTargets {
                let (node, err) = _parseExplicitTextStatement(stripped)
                if let error = err { throw error }
                if let node = node {
                    diagram.textNodes.append(node)
                }
            } else {
                // Indented text node: uses currentSets
                if !inIndentMode {
                    if currentSets == nil {
                        throw VennParserError.textRequiresSet
                    }
                }
                let (node, err) = _parseIndentedTextStatement(stripped, currentSets: currentSets)
                if let error = err { throw error }
                if let node = node {
                    diagram.textNodes.append(node)
                }
            }
        }
    }

    return (diagram, [])
}

// MARK: - Helpers

private func _isComment(_ line: String) -> Bool {
    line.hasPrefix("%%")
}

private func _parseTitleText(_ line: String) -> String {
    var rest = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
    // Handle quoted title
    if rest.hasPrefix("\""), rest.count > 2 {
        if let endQuote = rest.lastIndex(of: "\""), rest.distance(from: rest.startIndex, to: endQuote) > 0 {
            let start = rest.index(after: rest.startIndex)
            let end = endQuote
            return String(rest[start..<end])
        }
    }
    // Take text up to #, ;, or end
    if let hashIdx = rest.firstIndex(of: "#") {
        rest = String(rest[..<hashIdx])
    }
    if let semiIdx = rest.firstIndex(of: ";") {
        rest = String(rest[..<semiIdx])
    }
    return rest.trimmingCharacters(in: .whitespaces)
}

private func _parseSetStatement(_ line: String, knownSets: inout Set<String>) -> (VennArea?, VennParserError?) {
    var rest = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)

    let identifier: String
    var label: String? = nil
    var size: Double? = nil

    // Parse identifier: may be bare or quoted string
    if rest.hasPrefix("\"") {
        let (id, remainder) = _parseQuotedString(rest)
        guard let id = id else {
            return (nil, .invalidSetStatement(line))
        }
        identifier = id
        rest = remainder
    } else {
        let (id, remainder) = _parseIdentifier(rest)
        guard let id = id else {
            return (nil, .invalidSetStatement(line))
        }
        identifier = id
        rest = remainder
    }

    // Parse optional label: [...] or ["..."]
    if rest.hasPrefix("[") {
        let (lbl, remainder) = _parseBracketLabel(rest)
        label = lbl
        rest = remainder
    }

    // Parse optional size: :<number>
    if rest.hasPrefix(":") {
        rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        let (sz, remainder) = _parseNumber(rest)
        guard let sz = sz else {
            return (nil, .invalidSetStatement(line))
        }
        size = sz
        rest = remainder
    }

    if !rest.trimmingCharacters(in: .whitespaces).isEmpty {
        return (nil, .invalidSetStatement(line))
    }

    knownSets.insert(identifier)

    let defaultSize = VennArea.defaultSize(forSetCount: 1)
    return (VennArea(sets: [identifier], size: size ?? defaultSize, label: label), nil)
}

private func _parseUnionStatement(_ line: String, knownSets: Set<String>) -> (VennArea?, VennParserError?) {
    var rest = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

    // Parse identifier list (comma-separated)
    var identifiers: [String] = []

    while !rest.isEmpty {
        let trimmed = rest.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { break }

        let identifier: String?
        if trimmed.hasPrefix("\"") {
            (identifier, rest) = _parseQuotedString(trimmed)
        } else {
            (identifier, rest) = _parseIdentifier(trimmed)
        }

        guard let id = identifier else {
            return (nil, .invalidUnionStatement(line))
        }
        identifiers.append(id)

        rest = rest.trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix(",") {
            rest = String(rest.dropFirst())
        } else {
            break
        }
    }

    if identifiers.count < 2 {
        return (nil, .unionRequiresMultipleIdentifiers)
    }

    // Validate all identifiers are known
    let unknownIds = identifiers.filter { !knownSets.contains($0) }
    if !unknownIds.isEmpty {
        return (nil, .unknownSetIdentifier(unknownIds))
    }

    var label: String? = nil
    var size: Double? = nil

    // Parse optional label: [...] or ["..."]
    rest = rest.trimmingCharacters(in: .whitespaces)
    if rest.hasPrefix("[") {
        let (lbl, remainder) = _parseBracketLabel(rest)
        label = lbl
        rest = remainder
    }

    // Parse optional size: :<number>
    rest = rest.trimmingCharacters(in: .whitespaces)
    if rest.hasPrefix(":") {
        rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        let (sz, remainder) = _parseNumber(rest)
        guard let sz = sz else {
            return (nil, .invalidUnionStatement(line))
        }
        size = sz
        rest = remainder
    }

    if !rest.trimmingCharacters(in: .whitespaces).isEmpty {
        return (nil, .invalidUnionStatement(line))
    }

    let defaultSize = VennArea.defaultSize(forSetCount: identifiers.count)
    return (VennArea(sets: identifiers.sorted(), size: size ?? defaultSize, label: label), nil)
}

private func _parseExplicitTextStatement(_ line: String) -> (VennTextNode?, VennParserError?) {
    var rest = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

    // Parse set identifier list
    var setIds: [String] = []

    while !rest.isEmpty {
        let token = _readToken(rest)
        guard let setId = _tryParseIdentifierOrQuoted(token) else {
            return (nil, .invalidTextStatement(line))
        }
        setIds.append(setId)
        rest = _remainderAfter(rest, token: token).trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix(",") {
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            continue
        }
        break
    }

    let textToken = _readToken(rest)
    guard let textId = _tryParseTextIdOrQuoted(textToken) else {
        return (nil, .invalidTextStatement(line))
    }
    rest = _remainderAfter(rest, token: textToken).trimmingCharacters(in: .whitespaces)

    var label: String? = nil
    if rest.hasPrefix("[") {
        let (lbl, remainder) = _parseBracketLabel(rest)
        guard let parsedLabel = lbl else {
            return (nil, .invalidTextStatement(line))
        }
        label = parsedLabel
        rest = remainder.trimmingCharacters(in: .whitespaces)
    }

    if !rest.isEmpty {
        return (nil, .invalidTextStatement(line))
    }

    return (VennTextNode(sets: setIds, id: textId, label: label), nil)
}

private func _parseIndentedTextStatement(_ line: String, currentSets: [String]?) -> (VennTextNode?, VennParserError?) {
    let rest = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

    guard let css = currentSets, !css.isEmpty else {
        return (nil, .textRequiresSet)
    }

    let firstToken = _readToken(rest)
    guard let textId = _tryParseIdentifierOrQuoted(firstToken) else {
        return (nil, .invalidTextStatement(line))
    }

    let after = _remainderAfter(rest, token: firstToken).trimmingCharacters(in: .whitespaces)
    var label: String? = nil
    if after.hasPrefix("[") {
        let (lbl, _) = _parseBracketLabel(after)
        label = lbl
    }

    return (VennTextNode(sets: css, id: textId, label: label), nil)
}

private func _parseStyleStatement(_ line: String) -> (VennStyleEntry?, VennParserError?) {
    var rest = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

    // Parse target list (comma-separated ids)
    var targets: [String] = []

    while !rest.isEmpty {
        let trimmed = rest.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { break }

        let identifier: String?
        if trimmed.hasPrefix("\"") {
            (identifier, rest) = _parseQuotedString(trimmed)
        } else {
            (identifier, rest) = _parseIdentifier(trimmed)
        }

        guard let id = identifier else {
            return (nil, .invalidStyleStatement(line))
        }
        targets.append(id)

        rest = rest.trimmingCharacters(in: .whitespaces)
        if rest.hasPrefix(",") {
            rest = String(rest.dropFirst())
        } else {
            break
        }
    }

    if targets.isEmpty {
        return (nil, .invalidStyleStatement(line))
    }

    // Parse style key:value pairs
    var styles: [String: String] = [:]
    rest = rest.trimmingCharacters(in: .whitespaces)

    while !rest.isEmpty {
        let colonIdx = rest.firstIndex(of: ":")
        guard let ci = colonIdx else {
            return (nil, .invalidStyleStatement(line))
        }

        let key = String(rest[..<ci]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            return (nil, .invalidStyleStatement(line))
        }

        var remainder = String(rest[rest.index(after: ci)...]).trimmingCharacters(in: .whitespaces)

        // Parse value: could be identifier, number, hex color, rgb(), rgba(), or quoted string
        let value: String
        if remainder.hasPrefix("rgba(") || remainder.hasPrefix("rgb(") {
            if let parenEnd = remainder.firstIndex(of: ")") {
                let end = remainder.index(after: parenEnd)
                value = String(remainder[..<end])
                remainder = String(remainder[end...]).trimmingCharacters(in: .whitespaces)
            } else {
                return (nil, .invalidStyleStatement(line))
            }
        } else if remainder.hasPrefix("\"") {
            let (qval, r) = _parseQuotedString(remainder)
            guard let qval = qval else {
                return (nil, .invalidStyleStatement(line))
            }
            value = qval
            remainder = r
        } else {
            // Read until comma or end
            if let commaIdx = remainder.firstIndex(of: ",") {
                value = String(remainder[..<commaIdx]).trimmingCharacters(in: .whitespaces)
                remainder = String(remainder[remainder.index(after: commaIdx)...])
            } else {
                value = remainder.trimmingCharacters(in: .whitespaces)
                remainder = ""
            }
        }

        if value.isEmpty {
            return (nil, .invalidStyleStatement(line))
        }

        styles[key] = value
        rest = remainder.trimmingCharacters(in: .whitespaces)
    }

    return (VennStyleEntry(targets: targets.sorted(), styles: styles), nil)
}

// MARK: - Low-level Tokenizers

private func _readToken(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("\"") {
        let (parsed, remainder) = _parseQuotedString(trimmed)
        if let _ = parsed {
            let endIdx = s.index(s.endIndex, offsetBy: -remainder.count)
            return String(s[s.startIndex..<endIdx]).trimmingCharacters(in: .whitespaces)
        }
    }
    // Read bare identifier
    let bare = trimmed
    if let firstNonId = bare.firstIndex(where: { c in
        !(c.isLetter || c.isNumber || c == "_" || c == "-")
    }) {
        return String(bare[..<firstNonId])
    }
    return bare
}

private func _remainderAfter(_ original: String, token: String) -> String {
    let trimmed = original.trimmingCharacters(in: .whitespaces)
    guard let range = trimmed.range(of: token) else { return "" }
    return String(trimmed[range.upperBound...])
}

private func _tryParseIdentifierOrQuoted(_ token: String) -> String? {
    let t = token.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("\"") {
        let (id, _) = _parseQuotedString(t)
        return id
    }
    return _parseBareIdentifier(t)
}

private func _tryParseTextIdOrQuoted(_ token: String) -> String? {
    let t = token.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("\"") {
        let (id, _) = _parseQuotedString(t)
        return id
    }
    if _isNumberToken(t) {
        return t
    }
    return _parseBareIdentifier(t)
}

private func _textStatementHasExplicitTargets(_ rest: String) -> Bool {
    var remaining = rest.trimmingCharacters(in: .whitespaces)
    guard !remaining.isEmpty else { return false }

    while !remaining.isEmpty {
        let token = _readToken(remaining)
        guard _tryParseIdentifierOrQuoted(token) != nil else {
            return false
        }
        remaining = _remainderAfter(remaining, token: token).trimmingCharacters(in: .whitespaces)
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
            continue
        }
        break
    }

    guard !remaining.isEmpty, !remaining.hasPrefix("[") else {
        return false
    }
    let textToken = _readToken(remaining)
    return _tryParseTextIdOrQuoted(textToken) != nil
}

private func _parseIdentifier(_ s: String) -> (String?, String) {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("\"") {
        let (id, remainder) = _parseQuotedString(trimmed)
        return (id, remainder)
    }
    return _parseBareIdentifierWithRemainder(trimmed)
}

private func _parseBareIdentifier(_ s: String) -> String? {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    var chars = ""
    for c in trimmed {
        if c.isLetter || c.isNumber || c == "_" || c == "-" {
            chars.append(c)
        } else {
            break
        }
    }
    return chars.isEmpty ? nil : chars
}

private func _parseBareIdentifierWithRemainder(_ s: String) -> (String?, String) {
    guard !s.isEmpty else { return (nil, "") }
    var chars = ""
    var idx = s.startIndex
    while idx < s.endIndex {
        let c = s[idx]
        if c.isLetter || c.isNumber || c == "_" || c == "-" {
            chars.append(c)
            idx = s.index(after: idx)
        } else {
            break
        }
    }
    if chars.isEmpty { return (nil, s) }
    return (chars, String(s[idx...]))
}

private func _parseQuotedString(_ s: String) -> (String?, String) {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("\"") else { return (nil, trimmed) }
    var chars = ""
    var idx = trimmed.index(after: trimmed.startIndex)
    while idx < trimmed.endIndex {
        if trimmed[idx] == "\\", trimmed.index(after: idx) < trimmed.endIndex {
            idx = trimmed.index(after: idx)
            chars.append(trimmed[idx])
        } else if trimmed[idx] == "\"" {
            idx = trimmed.index(after: idx)
            return (chars, String(trimmed[idx...]))
        } else {
            chars.append(trimmed[idx])
        }
        idx = trimmed.index(after: idx)
    }
    return (nil, trimmed)
}

private func _parseBracketLabel(_ s: String) -> (String?, String) {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") else { return (nil, trimmed) }

    let afterBracket = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)

    if afterBracket.hasPrefix("\"") {
        let (quotedText, remainder) = _parseQuotedString(afterBracket)
        guard let qt = quotedText else { return (nil, trimmed) }
        let r = remainder.trimmingCharacters(in: .whitespaces)
        guard r.hasPrefix("]") else { return (nil, trimmed) }
        return (qt, String(r.dropFirst()))
    }

    // Unquoted bracket label: read until ]
    var label = ""
    var idx = afterBracket.startIndex
    while idx < afterBracket.endIndex {
        if afterBracket[idx] == "]" {
            idx = afterBracket.index(after: idx)
            return (label.trimmingCharacters(in: .whitespaces), String(afterBracket[idx...]))
        }
        label.append(afterBracket[idx])
        idx = afterBracket.index(after: idx)
    }

    return (nil, trimmed)
}

private func _parseNumber(_ s: String) -> (Double?, String) {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return (nil, trimmed) }

    let pattern = "^[+-]?(\\d+(\\.\\d*)?|\\.\\d+)"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
          let range = Range(match.range, in: trimmed) else {
        return (nil, trimmed)
    }

    let numStr = String(trimmed[range])
    if let val = Double(numStr) {
        return (val, String(trimmed[range.upperBound...]))
    }
    return (nil, trimmed)
}

private func _isNumberToken(_ s: String) -> Bool {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    let (number, remainder) = _parseNumber(trimmed)
    return number != nil && remainder.trimmingCharacters(in: .whitespaces).isEmpty
}
