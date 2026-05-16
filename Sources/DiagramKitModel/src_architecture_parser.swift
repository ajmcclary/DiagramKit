import Foundation
import DiagramKitCommon

public enum ArchitectureParserError: Error, LocalizedError {
    case missingHeader
    case duplicateId(String, existingType: String)
    case selfParenting(String)
    case missingParent(String)
    case parentNotGroup(String, String)
    case missingEndpoint(String, side: String)
    case invalidEndpointType(String, side: String, expected: String)
    case invalidDirection(String, side: String)
    case invalidGroupBoundaryModifier(String)
    case undeclaredId(String)
    case invalidStatement(String)

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "Missing 'architecture-beta' header."
        case .duplicateId(let id, let existingType):
            return "Duplicate id '\(id)' — already defined as \(existingType)."
        case .selfParenting(let id):
            return "Element '\(id)' cannot be its own parent."
        case .missingParent(let parent):
            return "Parent '\(parent)' not found."
        case .parentNotGroup(let id, let parent):
            return "Parent '\(parent)' for element '\(id)' must be a group."
        case .missingEndpoint(let id, let side):
            return "Missing \(side)-side endpoint '\(id)'."
        case .invalidEndpointType(let id, let side, let expected):
            return "\(side.sided()) endpoint '\(id)' must be a \(expected)."
        case .invalidDirection(let dir, let side):
            return "Invalid direction '\(dir)' on \(side) side. Must be L, R, T, or B."
        case .invalidGroupBoundaryModifier(let detail):
            return "Invalid group boundary modifier: \(detail)."
        case .undeclaredId(let id):
            return "Undeclared id '\(id)'."
        case .invalidStatement(let detail):
            return "Invalid statement: \(detail)."
        }
    }
}

private extension String {
    func sided() -> String {
        switch self {
        case "lhs": return "Left"
        case "rhs": return "Right"
        default: return self.capitalized
        }
    }
}

// MARK: - Parser State

private struct _ArchitectureParserState {
    var groups: [ArchitectureGroup] = []
    var services: [ArchitectureService] = []
    var junctions: [ArchitectureJunction] = []
    var edges: [ArchitectureEdge] = []
    var registeredIds: [String: String] = [:]
    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?

    mutating func registerId(_ id: String, as type: String) throws {
        if let existing = registeredIds[id] {
            throw ArchitectureParserError.duplicateId(id, existingType: existing)
        }
        registeredIds[id] = type
    }

    func isRegistered(_ id: String) -> Bool {
        registeredIds[id] != nil
    }

    func typeOf(_ id: String) -> String? {
        registeredIds[id]
    }

    func isGroup(_ id: String) -> Bool {
        typeOf(id) == "group"
    }

    func isServiceOrJunction(_ id: String) -> Bool {
        let t = typeOf(id)
        return t == "service" || t == "junction"
    }

    mutating func validateParent(_ parentId: String, for elementId: String) throws {
        if parentId == elementId {
            throw ArchitectureParserError.selfParenting(elementId)
        }
        guard let parentType = typeOf(parentId) else {
            throw ArchitectureParserError.missingParent(parentId)
        }
        if parentType != "group" {
            throw ArchitectureParserError.parentNotGroup(elementId, parentId)
        }
    }
}

// MARK: - Helpers

private func _extractBracketed(from remainder: inout String, open: Character, close: Character) throws -> String {
    remainder = remainder.trimmingCharacters(in: .whitespaces)
    guard remainder.first == open else {
        throw ArchitectureParserError.invalidStatement("expected '\(open)'")
    }

    let content = String(remainder.dropFirst())
    var depth = 1
    var result = ""
    var idx = content.startIndex
    while idx < content.endIndex {
        let ch = content[idx]
        let next = content.index(after: idx)
        if ch == open { depth += 1 }
        else if ch == close {
            depth -= 1
            if depth == 0 {
                remainder = String(content[next...]).trimmingCharacters(in: .whitespaces)
                return result.trimmingCharacters(in: .whitespaces)
            }
        }
        result.append(ch)
        idx = next
    }

    throw ArchitectureParserError.invalidStatement("unterminated '\(open)' section")
}

private func _extractIconSection(from remainder: inout String) throws -> (iconName: String?, iconText: String?) {
    let trimmed = remainder.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("(") else { return (nil, nil) }
    remainder = trimmed

    let inner = try _extractBracketed(from: &remainder, open: "(", close: ")")
    if inner.isEmpty { return (nil, nil) }
    if (inner.hasPrefix("\"") && inner.hasSuffix("\"")) || (inner.hasPrefix("'") && inner.hasSuffix("'")) {
        return (nil, _unquoteTitle(inner))
    }
    return (inner, nil)
}

private func _extractTitle(from remainder: inout String) throws -> String? {
    let trimmed = remainder.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") else { return nil }
    remainder = trimmed

    let inner = try _extractBracketed(from: &remainder, open: "[", close: "]")
    if inner.isEmpty { return nil }
    return _unquoteTitle(inner)
}

private func _consumeInParent(from remainder: inout String, line: String) throws -> String? {
    let trimmed = remainder.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
        remainder = ""
        return nil
    }
    guard trimmed.hasPrefix("in "), trimmed.count > 3 else {
        throw ArchitectureParserError.invalidStatement("unexpected content at end of line '\(line)': '\(trimmed)'")
    }

    var parentRemainder = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    guard let parentEnd = _scanId(from: parentRemainder) else {
        throw ArchitectureParserError.invalidStatement("invalid parent id in '\(line)'")
    }

    let parentId = String(parentRemainder[..<parentEnd])
    parentRemainder = String(parentRemainder[parentEnd...]).trimmingCharacters(in: .whitespaces)
    guard parentRemainder.isEmpty else {
        throw ArchitectureParserError.invalidStatement("unexpected content at end of line '\(line)': '\(parentRemainder)'")
    }

    remainder = ""
    return parentId
}

private func _unquoteTitle(_ s: String) -> String? {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return nil }
    if (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
        let inner = String(t.dropFirst().dropLast())
        return inner.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\'", with: "'")
    }
    return t
}

private func _scanId(from text: String) -> String.Index? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first, first.isLetter || first.isNumber || first == "_" else {
        return nil
    }
    var idx = trimmed.startIndex
    while idx < trimmed.endIndex {
        let ch = trimmed[idx]
        if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" {
            idx = trimmed.index(after: idx)
        } else {
            break
        }
    }
    if idx > trimmed.startIndex {
        let lastCharIdx = trimmed.index(before: idx)
        if trimmed[lastCharIdx] == "-" {
            return nil
        }
        let offset = idx.utf16Offset(in: trimmed)
        let textStart = text.distance(from: text.startIndex, to: text.firstIndex(of: first) ?? text.startIndex)
        return text.index(text.startIndex, offsetBy: textStart + offset)
    }
    return nil
}

// MARK: - Public API

public func parseArchitectureDiagram(_ source: String, frontmatter: DiagramFrontmatter? = nil) throws -> (ArchitectureDiagram, [DiagramDiagnostic]) {
    let processed = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = processed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseArchitectureDiagram(rawLines, frontmatter: frontmatter)
}

public func parseArchitectureDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (ArchitectureDiagram, [DiagramDiagnostic]) {
    var state = _ArchitectureParserState()
    var headerFound = false
    var inMultilineAccDescr = false
    var accDescrLines: [String] = []

    var idx = 0
    while idx < lines.count {
        let rawLine = lines[idx]
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

        if !headerFound {
            if trimmed.isEmpty || trimmed.hasPrefix("%%") {
                idx += 1
                continue
            }
        if !trimmed.hasPrefix("architecture-beta") {
            throw ArchitectureParserError.missingHeader
        }
        headerFound = true
        let rawRemainder = String(trimmed.dropFirst("architecture-beta".count))
        if let first = rawRemainder.first, !first.isWhitespace {
            throw ArchitectureParserError.missingHeader
        }
        let remainder = rawRemainder.trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty {
            guard remainder.hasPrefix("title ") else {
                throw ArchitectureParserError.invalidStatement("unexpected content after architecture header: '\(remainder)'")
            }
            state.diagramTitle = String(remainder.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        idx += 1
        continue
        }

        if trimmed.isEmpty {
            idx += 1
            continue
        }

        if trimmed.hasPrefix("%%") {
            idx += 1
            continue
        }

        if inMultilineAccDescr {
            if trimmed == "}" {
                inMultilineAccDescr = false
                state.accDescr = accDescrLines.joined(separator: "\n")
            } else {
                accDescrLines.append(rawLine)
            }
            idx += 1
            continue
        }

        let lower = trimmed.lowercased()

        if lower.hasPrefix("title ") {
            state.diagramTitle = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            idx += 1
            continue
        }

        if lower.hasPrefix("acctitle:") {
            state.accTitle = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            idx += 1
            continue
        }

        if lower.hasPrefix("accdescr") {
            let after = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            if after.hasPrefix("{") {
                let afterBrace = String(after.dropFirst()).trimmingCharacters(in: .whitespaces)
                if afterBrace.hasSuffix("}") {
                    state.accDescr = String(afterBrace.dropLast()).trimmingCharacters(in: .whitespaces)
                } else {
                    inMultilineAccDescr = true
                    accDescrLines = []
                    if !afterBrace.isEmpty {
                        accDescrLines.append(afterBrace)
                    }
                }
            } else if after.hasPrefix(":") {
                state.accDescr = String(after.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            idx += 1
            continue
        }

        if lower.hasPrefix("group ") {
            try _parseGroup(trimmed, into: &state)
            idx += 1
            continue
        }

        if lower.hasPrefix("service ") {
            try _parseService(trimmed, into: &state)
            idx += 1
            continue
        }

        if lower.hasPrefix("junction ") {
            try _parseJunction(trimmed, into: &state)
            idx += 1
            continue
        }

        if try _parseEdge(trimmed, into: &state) {
            idx += 1
            continue
        }

        throw ArchitectureParserError.invalidStatement(trimmed)
    }

    if !headerFound {
        throw ArchitectureParserError.missingHeader
    }

    var result = ArchitectureDiagram(
        groups: state.groups,
        services: state.services,
        junctions: state.junctions,
        edges: state.edges,
        diagramTitle: state.diagramTitle,
        accTitle: state.accTitle,
        accDescr: state.accDescr
    )

    if let fm = frontmatter {
        if let cfg = fm.perDiagram.architecture.config { result.config = cfg }
        if let theme = fm.perDiagram.architecture.theme { result.theme = theme }
    }
    if let fmTitle = frontmatter?.shared.diagramTitle, result.diagramTitle == nil {
        result.diagramTitle = fmTitle
    }
    if let fmTitle = frontmatter?.shared.title, result.diagramTitle == nil {
        result.diagramTitle = fmTitle
    }

    return (result, [])
}

// MARK: - Statement Parsers

private func _parseGroup(_ line: String, into state: inout _ArchitectureParserState) throws {
    var remainder = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

    guard let idEnd = _scanId(from: remainder) else {
        throw ArchitectureParserError.invalidStatement("Invalid group id in '\(line)'")
    }
    let id = String(remainder[..<idEnd])
    remainder = String(remainder[idEnd...]).trimmingCharacters(in: .whitespaces)
    try state.registerId(id, as: "group")

    let (iconName, _) = try _extractIconSection(from: &remainder)
    let titleOpt = try _extractTitle(from: &remainder)
    let parentId = try _consumeInParent(from: &remainder, line: line)

    if let p = parentId {
        try state.validateParent(p, for: id)
    }

    state.groups.append(ArchitectureGroup(id: id, icon: iconName, title: titleOpt, parentGroupId: parentId))
}

private func _parseService(_ line: String, into state: inout _ArchitectureParserState) throws {
    var remainder = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)

    guard let idEnd = _scanId(from: remainder) else {
        throw ArchitectureParserError.invalidStatement("Invalid service id in '\(line)'")
    }
    let id = String(remainder[..<idEnd])
    remainder = String(remainder[idEnd...]).trimmingCharacters(in: .whitespaces)
    try state.registerId(id, as: "service")

    let (iconName, iconText) = try _extractIconSection(from: &remainder)
    let titleOpt = try _extractTitle(from: &remainder)
    let parentId = try _consumeInParent(from: &remainder, line: line)

    if let p = parentId {
        try state.validateParent(p, for: id)
    }

    state.services.append(ArchitectureService(id: id, icon: iconName, iconText: iconText, title: titleOpt, parentGroupId: parentId))
}

private func _parseJunction(_ line: String, into state: inout _ArchitectureParserState) throws {
    var remainder = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)

    guard let idEnd = _scanId(from: remainder) else {
        throw ArchitectureParserError.invalidStatement("Invalid junction id in '\(line)'")
    }
    let id = String(remainder[..<idEnd])
    remainder = String(remainder[idEnd...]).trimmingCharacters(in: .whitespaces)
    try state.registerId(id, as: "junction")

    let parentId = try _consumeInParent(from: &remainder, line: line)
    if let p = parentId {
        try state.validateParent(p, for: id)
    }

    state.junctions.append(ArchitectureJunction(id: id, parentGroupId: parentId))
}

private func _parseEdge(_ line: String, into state: inout _ArchitectureParserState) throws -> Bool {
    var remainder = line.trimmingCharacters(in: .whitespaces)

    guard let lhsIdEnd = _scanId(from: remainder) else {
        return false
    }
    let lhsId = String(remainder[..<lhsIdEnd])
    remainder = String(remainder[lhsIdEnd...]).trimmingCharacters(in: .whitespaces)

    let lhsGB: Bool
    if remainder.hasPrefix("{") {
        guard remainder.hasPrefix("{group}") else {
            throw ArchitectureParserError.invalidGroupBoundaryModifier("expected '{group}' in '\(line)'")
        }
        remainder = String(remainder.dropFirst("{group}".count)).trimmingCharacters(in: .whitespaces)
        lhsGB = true
    } else {
        lhsGB = false
    }

    guard remainder.hasPrefix(":") else {
        return false
    }
    remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)

    guard remainder.count >= 1 else { return false }
    let lhsDirChar = String(remainder.first!).uppercased()
    guard let lhsDir = ArchitectureDirection(rawValue: lhsDirChar) else {
        throw ArchitectureParserError.invalidDirection(lhsDirChar, side: "lhs")
    }
    remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)

    let sourceArrow: Bool
    if remainder.hasPrefix("<") {
        sourceArrow = true
        remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
    } else {
        sourceArrow = false
    }

    let edgeLabel: String?
    if remainder.hasPrefix("-[") {
        let content = String(remainder.dropFirst(2))
        var labelStr = ""
        var scanned = content.startIndex
        var foundClosingBracket = false
        for ch in content {
            scanned = content.index(after: scanned)
            if ch == "]" {
                foundClosingBracket = true
                break
            }
            labelStr.append(ch)
        }
        guard foundClosingBracket else {
            throw ArchitectureParserError.invalidStatement("unterminated edge label in '\(line)'")
        }
        edgeLabel = labelStr.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelStr.trimmingCharacters(in: .whitespaces)
        remainder = String(content[scanned...]).trimmingCharacters(in: .whitespaces)
        guard remainder.hasPrefix("-") else {
            throw ArchitectureParserError.invalidStatement("expected trailing '-' after edge label in '\(line)'")
        }
        remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
    } else if remainder.hasPrefix("--") {
        edgeLabel = nil
        remainder = String(remainder.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    } else {
        return false
    }

    let targetArrow: Bool
    if remainder.hasPrefix(">") {
        targetArrow = true
        remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
    } else {
        targetArrow = false
    }

    guard remainder.count >= 1 else {
        throw ArchitectureParserError.invalidStatement("missing rhs direction in '\(line)'")
    }
    let rhsDirChar = String(remainder.first!).uppercased()
    guard let rhsDir = ArchitectureDirection(rawValue: rhsDirChar) else {
        throw ArchitectureParserError.invalidDirection(rhsDirChar, side: "rhs")
    }
    remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)

    guard remainder.hasPrefix(":") else {
        throw ArchitectureParserError.invalidStatement("missing colon before rhs id in '\(line)'")
    }
    remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)

    guard let rhsIdEnd = _scanId(from: remainder) else {
        throw ArchitectureParserError.missingEndpoint("(missing)", side: "rhs")
    }
    let rhsId = String(remainder[..<rhsIdEnd])
    remainder = String(remainder[rhsIdEnd...]).trimmingCharacters(in: .whitespaces)

    let rhsGB: Bool
    if remainder.hasPrefix("{") {
        guard remainder.hasPrefix("{group}") else {
            throw ArchitectureParserError.invalidGroupBoundaryModifier("expected '{group}' on rhs in '\(line)'")
        }
        remainder = String(remainder.dropFirst("{group}".count)).trimmingCharacters(in: .whitespaces)
        rhsGB = true
    } else {
        rhsGB = false
    }

    if !remainder.trimmingCharacters(in: .whitespaces).isEmpty {
        throw ArchitectureParserError.invalidStatement("unexpected content at end of line '\(line)': '\(remainder)'")
    }

    guard state.isRegistered(lhsId) else {
        throw ArchitectureParserError.undeclaredId(lhsId)
    }
    guard state.isRegistered(rhsId) else {
        throw ArchitectureParserError.undeclaredId(rhsId)
    }
    if state.isGroup(lhsId) {
        throw ArchitectureParserError.invalidEndpointType(lhsId, side: "lhs", expected: "service or junction")
    }
    if state.isGroup(rhsId) {
        throw ArchitectureParserError.invalidEndpointType(rhsId, side: "rhs", expected: "service or junction")
    }

    if (lhsGB || rhsGB) {
        let lhsGroup = state.services.first(where: { $0.id == lhsId })?.parentGroupId
            ?? state.junctions.first(where: { $0.id == lhsId })?.parentGroupId
        let rhsGroup = state.services.first(where: { $0.id == rhsId })?.parentGroupId
            ?? state.junctions.first(where: { $0.id == rhsId })?.parentGroupId
        if lhsGroup == nil || rhsGroup == nil || lhsGroup == rhsGroup {
            throw ArchitectureParserError.invalidGroupBoundaryModifier(
                "edge with {group} must connect nodes in two different groups"
            )
        }
    }

    state.edges.append(ArchitectureEdge(
        lhsId: lhsId,
        rhsId: rhsId,
        lhsDirection: lhsDir,
        rhsDirection: rhsDir,
        sourceArrow: sourceArrow,
        targetArrow: targetArrow,
        lhsGroupBoundary: lhsGB,
        rhsGroupBoundary: rhsGB,
        label: edgeLabel
    ))

    return true
}
