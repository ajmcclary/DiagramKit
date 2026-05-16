import Foundation
import DiagramKitCommon

public func parseRequirementDiagram(_ sourceLines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (RequirementDiagram, [DiagramDiagnostic]) {
    (try _parseRequirementDiagram(lines: sourceLines, frontmatter: frontmatter), [])
}

// MARK: - Tokenizer

private enum _ReqToken: Equatable {
    case unquoted(String)
    case quoted(String)
    case dash
    case arrowRight
    case arrowLeft
    case tripleColon
    case comma
    case openBrace
    case closeBrace
}

/// Characters that terminate an unquoted string scan, per the Jison rule:
///   unqString = [\w][^:,\r\n\{\<\>\-\=]*
/// Also breaks at `"` so quoted strings are parsed as their own token.
private let _reqReservedChars: Set<Character> = ["{", "}", ":", ",", "-", "<", ">", "=", "\""]

/// Tokenize a single line.  Quoted strings are unwrapped (escape handling included).
/// Unquoted strings are greedily scanned until a reserved character, then trimmed.
/// Structural tokens (dash, arrows, triple-colon, braces, comma) are emitted directly.
private func _reqTokenizeLine(_ line: String) -> [_ReqToken] {
    var tokens: [_ReqToken] = []
    let chars = Array(line)
    var i = 0

    func peek(_ offset: Int = 0) -> Character? {
        let idx = i + offset
        return idx < chars.count ? chars[idx] : nil
    }

    while i < chars.count {
        let ch = chars[i]

        if ch.isWhitespace || ch == "\r" || ch == "\n" { i += 1; continue }

        // Quoted string
        if ch == "\"" {
            i += 1
            var str = ""
            while i < chars.count {
                let c = chars[i]
                if c == "\\" && i + 1 < chars.count { i += 1; str.append(chars[i]) }
                else if c == "\"" { i += 1; break }
                else { str.append(c) }
                i += 1
            }
            tokens.append(.quoted(str))
            continue
        }

        // Single-char / multi-char structural tokens
        if ch == "{" { tokens.append(.openBrace); i += 1; continue }
        if ch == "}" { tokens.append(.closeBrace); i += 1; continue }
        if ch == "," { tokens.append(.comma); i += 1; continue }

        if ch == "-" {
            if peek(1) == ">" { tokens.append(.arrowRight); i += 2; continue }
            tokens.append(.dash); i += 1; continue
        }

        if ch == "<" {
            if peek(1) == "-" { tokens.append(.arrowLeft); i += 2; continue }
            i += 1; continue
        }

        // Triple colon  :::
        if ch == ":" && peek(1) == ":" && peek(2) == ":" {
            tokens.append(.tripleColon); i += 3; continue
        }

        // Colon / `>` / `=` — reserved in Jison but not emitted as tokens at top level;
        // they stop unqString scanning but are consumed here silently.
        if ch == ":" || ch == ">" || ch == "=" { i += 1; continue }

        // Unquoted string: scan greedily until a reserved char or end-of-line
        var str = ""
        while i < chars.count {
            let c = chars[i]
            if _reqReservedChars.contains(c) || c == "\r" || c == "\n" { break }
            str.append(c)
            i += 1
        }
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { tokens.append(.unquoted(trimmed)) }
    }

    return tokens
}

/// If `token` starts with one of the supplied `keywords` (case-insensitive),
/// return a tuple `(matchedKeyword, remainder)`.  The longest matching keyword wins.
private func _reqSplitKeyword(_ token: String, keywords: Set<String>) -> (keyword: String, remainder: String)? {
    let lower = token.lowercased()
    let candidates = keywords.filter { lower.hasPrefix($0) }
    guard let best = candidates.max(by: { $0.count < $1.count }) else { return nil }
    let remainder = String(token.dropFirst(best.count)).trimmingCharacters(in: .whitespaces)
    return (best, remainder)
}

/// Given a tokenized tokens after an optional keyword split, extract a
/// comma-separated id list.  Continues until a non-comma, non-identifier token.
private func _reqParseIdList(_ tokens: [_ReqToken], from start: Int) -> (names: [String], consumed: Int) {
    var names: [String] = []
    var idx = start
    while idx < tokens.count {
        switch tokens[idx] {
        case .unquoted(let s): names.append(s); idx += 1
        case .quoted(let s):   names.append(s); idx += 1
        case .comma:           idx += 1
        default:               return (names, idx - start)
        }
    }
    return (names, idx - start)
}

// MARK: - Regex cache

// Concurrency Contract: requirement-parser regex lookups go through
// `NSCache` + a private serial dispatch queue. The cache caps its own
// size under varied input (no unbounded growth on user-controllable
// patterns), and the queue guarantees the get-or-insert is atomic. The
// shape mirrors `_dateFormatterCache` in `src_gantt_parser.swift`.
private nonisolated(unsafe) let _reqCompiledRegex = NSCache<NSString, NSRegularExpression>()
private let _reqRegexCacheQueue = DispatchQueue(
    label: "diagramkit.requirement.regexCache"
)

private func _reqCachedRegex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression? {
    let key = "\(pattern)|\(options.rawValue)" as NSString
    return _reqRegexCacheQueue.sync {
        if let cached = _reqCompiledRegex.object(forKey: key) {
            return cached
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        _reqCompiledRegex.setObject(regex, forKey: key)
        return regex
    }
}

private func _reqGroups(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> [String]? {
    let opts: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = _reqCachedRegex(pattern, opts) else { return nil }
    let nsValue = value as NSString
    let range = NSRange(location: 0, length: nsValue.length)
    guard let match = regex.firstMatch(in: value, options: [], range: range) else { return nil }
    var results: [String] = []
    for idx in 0..<match.numberOfRanges {
        let r = match.range(at: idx)
        if r.location == NSNotFound { results.append("") }
        else { results.append(nsValue.substring(with: r)) }
    }
    return results
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Main parse

private func _parseRequirementDiagram(lines: [String], frontmatter: DiagramFrontmatter?) throws -> RequirementDiagram {
    var diagram = RequirementDiagram(
        requirements: [],
        elements: [],
        relationships: [],
        classDefs: [],
        direction: .TB,
        diagramTitle: frontmatter?.diagramTitle,
        accTitle: nil,
        accDescr: nil,
        config: frontmatter?.requirementConfig ?? RequirementDiagramConfig()
    )

    var requirementMap: [String: RequirementNode] = [:]
    var elementMap: [String: ElementNode] = [:]
    var requirementOrder: [String] = []
    var elementOrder: [String] = []
    var classDefMap: [String: RequirementClassDef] = [:]
    var sourceOrderCounter = 0
    var accDescrLines: [String]?

    // Parser state
    var inRequirementBody: (name: String, type: RequirementType, classes: [String])?
    var inElementBody: (name: String, classes: [String])?
    var latestReqId: String?
    var latestReqText: String?
    var latestReqRisk: RiskLevel?
    var latestReqVerify: VerifyMethod?
    var latestElType: String?
    var latestElDocRef: String?

    // Find header
    let sourceIter = lines.makeIterator()
    var remainingLines: [String] = []

    var foundHeader = false
    for line in sourceIter {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") || trimmed.hasPrefix("#") { continue }
        if trimmed.range(of: #"^requirement(Diagram)?\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            foundHeader = true
            continue
        }
        remainingLines.append(line)
    }

    if !foundHeader {
        throw RequirementParserError.invalidHeader(lines.first ?? "")
    }

    func nextSourceLine() -> String? {
        guard !remainingLines.isEmpty else { return nil }
        return remainingLines.removeFirst()
    }

    func ensureRequirement(_ name: String) -> RequirementNode {
        if let existing = requirementMap[name] { return existing }
        let node = RequirementNode(
            name: name, type: .requirement, requirementId: "", text: "",
            risk: nil, verifyMethod: nil,
            cssStyles: [], classes: ["default"],
            sourceOrder: sourceOrderCounter
        )
        sourceOrderCounter += 1
        requirementMap[name] = node
        requirementOrder.append(name)
        return node
    }

    func ensureElement(_ name: String) -> ElementNode {
        if let existing = elementMap[name] { return existing }
        let node = ElementNode(
            name: name, type: "", docRef: "",
            cssStyles: [], classes: ["default"],
            sourceOrder: sourceOrderCounter
        )
        sourceOrderCounter += 1
        elementMap[name] = node
        elementOrder.append(name)
        return node
    }

    func pushClassStylesToExistingNodes(_ classDef: RequirementClassDef) {
        for name in requirementOrder {
            if var node = requirementMap[name], node.classes.contains(classDef.id) {
                node.cssStyles.append(contentsOf: classDef.styles)
                requirementMap[name] = node
            }
        }
        for name in elementOrder {
            if var node = elementMap[name], node.classes.contains(classDef.id) {
                node.cssStyles.append(contentsOf: classDef.styles)
                elementMap[name] = node
            }
        }
    }

    func commitRequirement() {
        guard let body = inRequirementBody else { return }
        let name = body.name
        guard requirementMap[name] == nil else {
            inRequirementBody = nil
            latestReqId = nil; latestReqText = nil
            latestReqRisk = nil; latestReqVerify = nil
            return
        }
        _ = ensureRequirement(name)
        if var node = requirementMap[name] {
            node.type = body.type
            if let rid = latestReqId { node.requirementId = rid }
            if let t = latestReqText { node.text = t }
            if let r = latestReqRisk { node.risk = r }
            if let v = latestReqVerify { node.verifyMethod = v }
            for cn in body.classes {
                if !node.classes.contains(cn) { node.classes.append(cn) }
            }
            requirementMap[name] = node
        }
        inRequirementBody = nil
        latestReqId = nil; latestReqText = nil
        latestReqRisk = nil; latestReqVerify = nil
    }

    func commitElement() {
        guard let body = inElementBody else { return }
        let name = body.name
        guard elementMap[name] == nil else {
            inElementBody = nil
            latestElType = nil; latestElDocRef = nil
            return
        }
        _ = ensureElement(name)
        if var node = elementMap[name] {
            if let t = latestElType { node.type = t }
            if let d = latestElDocRef { node.docRef = d }
            for cn in body.classes {
                if !node.classes.contains(cn) { node.classes.append(cn) }
            }
            elementMap[name] = node
        }
        inElementBody = nil
        latestElType = nil; latestElDocRef = nil
    }

    while let rawLine = nextSourceLine() {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        if trimmed.hasPrefix("%%") || trimmed.hasPrefix("#") { continue }

        if accDescrLines != nil {
            if let closeIdx = trimmed.firstIndex(of: "}") {
                let beforeClose = String(trimmed[..<closeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeClose.isEmpty { accDescrLines?.append(beforeClose) }
                diagram.accDescr = accDescrLines?.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                accDescrLines = nil
            } else {
                accDescrLines?.append(trimmed)
            }
            continue
        }

        // Handle block bodies
        if inRequirementBody != nil {
            if trimmed == "}" { commitRequirement(); continue }
            if trimmed.hasPrefix("%%") || trimmed.hasPrefix("#") { continue }
            _parseReqBodyField(trimmed, &latestReqId, &latestReqText, &latestReqRisk, &latestReqVerify)
            continue
        }

        if inElementBody != nil {
            if trimmed == "}" { commitElement(); continue }
            if trimmed.hasPrefix("%%") || trimmed.hasPrefix("#") { continue }
            _parseElBodyField(trimmed, &latestElType, &latestElDocRef)
            continue
        }

        // accTitle
        if let at = _reqParseAccTitle(trimmed) { diagram.accTitle = at; continue }

        // accDescr
        if let ad = _reqParseAccDescr(trimmed) { diagram.accDescr = ad; continue }

        // accDescr multiline start
        if let firstLine = _reqParseAccDescrMultilineStart(trimmed) {
            accDescrLines = []
            if let closeIdx = firstLine.firstIndex(of: "}") {
                let beforeClose = String(firstLine[..<closeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeClose.isEmpty { accDescrLines?.append(beforeClose) }
                diagram.accDescr = accDescrLines?.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                accDescrLines = nil
            } else if !firstLine.isEmpty {
                accDescrLines?.append(firstLine)
            }
            continue
        }

        // direction
        if let dir = _reqParseDirection(trimmed) { diagram.direction = dir; continue }

        // Token-based parsing for definitions and relationships
        let tokens = _reqTokenizeLine(trimmed)

        // Requirement definition
        if let (name, reqType, classes) = _reqParseRequirementDef(tokens) {
            inRequirementBody = (name: name, type: reqType, classes: classes)
            if rawLine.trimmingCharacters(in: .whitespaces).hasSuffix("}") { commitRequirement() }
            continue
        }

        // Element definition
        if let (name, classes) = _reqParseElementDef(tokens) {
            inElementBody = (name: name, classes: classes)
            if rawLine.trimmingCharacters(in: .whitespaces).hasSuffix("}") { commitElement() }
            continue
        }

        // Relationship (token-based)
        if let rel = _reqParseRelationshipTokens(tokens) {
            diagram.relationships.append(rel)
            continue
        }

        // style — uses word-level parsing (matches Jison <style> state's ALPHA tokens)
        if trimmed.hasPrefix("style ") {
            _reqParseStyle(trimmed, &requirementMap, &elementMap)
            continue
        }

        // classDef — uses word-level parsing (matches Jison <style> state's ALPHA tokens)
        if trimmed.hasPrefix("classDef ") {
            if let cd = _reqParseClassDef(trimmed) {
                for clsName in cd.names {
                    let def = RequirementClassDef(id: clsName, styles: cd.styles, textStyles: cd.textStyles)
                    classDefMap[clsName] = def
                    diagram.classDefs.append(def)
                    pushClassStylesToExistingNodes(def)
                }
            }
            continue
        }

        // class — uses word-level parsing (matches Jison <style> state's ALPHA tokens)
        if trimmed.hasPrefix("class ") {
            _reqParseClassAssignmentWords(trimmed, &requirementMap, &elementMap, classDefMap)
            continue
        }

        // standalone shorthand :::
        if trimmed.contains(":::") {
            _reqParseShorthandClass(trimmed, &requirementMap, &elementMap)
            continue
        }
    }

    // Finalize pending blocks
    if inRequirementBody != nil { commitRequirement() }
    if inElementBody != nil { commitElement() }

    diagram.requirements = requirementOrder.compactMap { requirementMap[$0] }
    diagram.elements = elementOrder.compactMap { elementMap[$0] }
    return diagram
}

// MARK: - Token-based definition parsers

private let _reqTypeKeywords: Set<String> = [
    "requirement", "functionalrequirement", "interfacerequirement",
    "performancerequirement", "physicalrequirement", "designconstraint"
]

private let _reqRelKeywords: Set<String> = [
    "contains", "copies", "derives", "satisfies", "verifies", "refines", "traces"
]

private func _reqParseRequirementDef(_ tokens: [_ReqToken]) -> (name: String, type: RequirementType, classes: [String])? {
    // Pattern: requirementType name [::: classList] {
    guard tokens.count >= 2,
          case .unquoted(let first) = tokens[0],
          let (keyword, remainder) = _reqSplitKeyword(first, keywords: _reqTypeKeywords),
          let reqType = _reqRequirementType(from: keyword) else { return nil }

    let name: String
    var classes: [String] = []
    var idx = 1

    if !remainder.isEmpty {
        name = remainder
    } else {
        // name is the next token
        if idx >= tokens.count { return nil }
        switch tokens[idx] {
        case .unquoted(let s): name = s; idx += 1
        case .quoted(let s):   name = s; idx += 1
        default: return nil
        }
    }

    // Optional ::: classList
    if idx < tokens.count, case .tripleColon = tokens[idx] {
        idx += 1
        let (clist, _) = _reqParseIdList(tokens, from: idx)
        classes = clist
        // advance idx past the idList (rough — we just need to find the openBrace)
        while idx < tokens.count {
            if case .openBrace = tokens[idx] { break }
            idx += 1
        }
    }

    // Must end with {
    // (it's ok if `{` was not explicitly tokenized because the line has a body)
    return (name, reqType, classes)
}

private func _reqParseElementDef(_ tokens: [_ReqToken]) -> (name: String, classes: [String])? {
    // Pattern: element name [::: classList] {
    guard tokens.count >= 2,
          case .unquoted(let first) = tokens[0],
          let (keyword, remainder) = _reqSplitKeyword(first, keywords: ["element"]),
          keyword == "element" else { return nil }

    let name: String
    var classes: [String] = []
    var idx = 1

    if !remainder.isEmpty {
        name = remainder
    } else {
        if idx >= tokens.count { return nil }
        switch tokens[idx] {
        case .unquoted(let s): name = s; idx += 1
        case .quoted(let s):   name = s; idx += 1
        default: return nil
        }
    }

    // Optional ::: classList
    if idx < tokens.count, case .tripleColon = tokens[idx] {
        idx += 1
        let (clist, _) = _reqParseIdList(tokens, from: idx)
        classes = clist
    }

    return (name, classes)
}

private func _reqRequirementType(from raw: String) -> RequirementType? {
    switch raw.lowercased() {
    case "requirement": return .requirement
    case "functionalrequirement": return .functionalRequirement
    case "interfacerequirement": return .interfaceRequirement
    case "performancerequirement": return .performanceRequirement
    case "physicalrequirement": return .physicalRequirement
    case "designconstraint": return .designConstraint
    default: return nil
    }
}

// MARK: - Token-based relationship parser

private func _reqParseRelationshipTokens(_ tokens: [_ReqToken]) -> RequirementRelationship? {
    // Forward:  src  -  type  ->  dst
    if tokens.count >= 5,
       case .unquoted(let rel) = tokens[2],
       _reqRelKeywords.contains(rel.lowercased()),
       case .dash = tokens[1],
       case .arrowRight = tokens[3],
       let relType = RequirementRelationshipType(rawValue: rel.lowercased()) {

        let srcName: String
        switch tokens[0] {
        case .unquoted(let s): srcName = s
        case .quoted(let s):   srcName = s
        default: return nil
        }
        let dstName: String
        switch tokens[4] {
        case .unquoted(let s): dstName = s
        case .quoted(let s):   dstName = s
        default: return nil
        }
        return RequirementRelationship(type: relType, sourceName: srcName, destinationName: dstName, isReversed: false)
    }

    // Reverse:  dst  <-  type  -  src
    if tokens.count >= 5,
       case .unquoted(let rel) = tokens[2],
       _reqRelKeywords.contains(rel.lowercased()),
       case .arrowLeft = tokens[1],
       case .dash = tokens[3],
       let relType = RequirementRelationshipType(rawValue: rel.lowercased()) {

        let dstName: String  // leftmost name in Mermaid: dst <- type - src
        switch tokens[0] {
        case .unquoted(let s): dstName = s
        case .quoted(let s):   dstName = s
        default: return nil
        }
        let srcName: String  // rightmost name
        switch tokens[4] {
        case .unquoted(let s): srcName = s
        case .quoted(let s):   srcName = s
        default: return nil
        }
        // Normalize: source→destination ordering preserved in model
        return RequirementRelationship(type: relType, sourceName: srcName, destinationName: dstName, isReversed: true)
    }

    return nil
}

// MARK: - Body Field Parsing

private func _parseReqBodyField(
    _ line: String,
    _ reqId: inout String?,
    _ text: inout String?,
    _ risk: inout RiskLevel?,
    _ verify: inout VerifyMethod?
) {
    let lower = line.lowercased()
    if lower.hasPrefix("id:") {
        reqId = _reqUnquotedValue(String(line.dropFirst(3)))
        return
    }
    if lower.hasPrefix("text:") {
        text = _reqUnquotedValue(String(line.dropFirst(5)))
        return
    }
    if lower.hasPrefix("risk:") {
        let raw = _reqUnquotedValue(String(line.dropFirst(5))).lowercased()
        if raw == "low" { risk = .low }
        else if raw == "medium" { risk = .medium }
        else if raw == "high" { risk = .high }
        return
    }
    // verifymethod: or verifyMethod: (case-insensitive)
    if lower.hasPrefix("verifymethod:") || lower.hasPrefix("verifymethod :") {
        let prefixLen = lower.hasPrefix("verifymethod :") ? "verifymethod ".count : "verifymethod:".count
        let raw = _reqUnquotedValue(String(line.dropFirst(prefixLen))).lowercased()
        if raw == "analysis" { verify = .analysis }
        else if raw == "demonstration" { verify = .demonstration }
        else if raw == "inspection" { verify = .inspection }
        else if raw == "test" { verify = .test }
        return
    }
}

private func _parseElBodyField(
    _ line: String,
    _ elType: inout String?,
    _ docRef: inout String?
) {
    let lower = line.lowercased()
    if lower.hasPrefix("type:") {
        elType = _reqUnquotedValue(String(line.dropFirst(5)))
        return
    }
    if lower.hasPrefix("docref:") || lower.hasPrefix("docref :") {
        let prefixLen = lower.hasPrefix("docref :") ? "docref ".count : "docref:".count
        docRef = _reqUnquotedValue(String(line.dropFirst(prefixLen)))
        return
    }
}

// MARK: - Accessory Parsers (cached regex)

private func _reqParseAccTitle(_ line: String) -> String? {
    guard let groups = _reqGroups(#"^accTitle:\s*(.+)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return _reqStripQuotes(value.trimmingCharacters(in: .whitespaces))
}

private func _reqParseAccDescr(_ line: String) -> String? {
    guard let groups = _reqGroups(#"^accDescr:\s*(.+)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return _reqStripQuotes(value.trimmingCharacters(in: .whitespaces))
}

private func _reqParseAccDescrMultilineStart(_ line: String) -> String? {
    guard let groups = _reqGroups(#"^accDescr\s*\{\s*(.*)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _reqParseDirection(_ line: String) -> RequirementDirection? {
    guard let groups = _reqGroups(#"^direction\s+(TB|BT|LR|RL)$"#, line, caseInsensitive: true),
          let dirStr = groups[safe: 1]?.uppercased() else { return nil }
    return RequirementDirection(rawValue: dirStr)
}

// MARK: - Style / ClassDef / Class / Shorthand Parsing

private struct _ReqClassDefResult {
    let names: [String]
    let styles: [String]
    let textStyles: [String]
}

private func _reqParseStyle(_ line: String, _ reqMap: inout [String: RequirementNode], _ elMap: inout [String: ElementNode]) {
    let rest = String(line.dropFirst("style".count)).trimmingCharacters(in: .whitespaces)
    guard let nameEnd = rest.firstIndex(where: { $0 == " " || $0 == "\t" }),
          let styleStart = rest[nameEnd...].firstIndex(where: { !$0.isWhitespace }) else { return }
    let namePart = String(rest[..<nameEnd]).trimmingCharacters(in: .whitespaces)
    let stylePart = String(rest[styleStart...]).trimmingCharacters(in: .whitespaces)
    let names = namePart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let styles = _reqParseStyleValues(stylePart)
    for name in names {
        if var node = reqMap[name] { node.cssStyles.append(contentsOf: styles); reqMap[name] = node }
        if var node = elMap[name] { node.cssStyles.append(contentsOf: styles); elMap[name] = node }
    }
}

private func _reqParseClassDef(_ line: String) -> _ReqClassDefResult? {
    let rest = String(line.dropFirst("classDef".count)).trimmingCharacters(in: .whitespaces)
    guard let nameEnd = rest.firstIndex(where: { $0 == " " || $0 == "\t" }),
          let styleStart = rest[nameEnd...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
    let namePart = String(rest[..<nameEnd]).trimmingCharacters(in: .whitespaces)
    let stylePart = String(rest[styleStart...]).trimmingCharacters(in: .whitespaces)
    let names = namePart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let allStyles = _reqParseStyleValues(stylePart)

    // Per Mermaid requirementDb.ts defineClass():
    //   if /color/.exec(s) → duplicate into textStyles with 'fill' → 'bgFill'
    var styles: [String] = []
    var textStyles: [String] = []
    for s in allStyles {
        styles.append(s)
        if s.range(of: "color", options: .caseInsensitive) != nil {
            let ts = s.replacingOccurrences(of: "fill", with: "bgFill")
            textStyles.append(ts)
        }
    }

    return _ReqClassDefResult(names: names, styles: styles, textStyles: textStyles)
}

private func _reqParseClassAssignmentWords(
    _ line: String,
    _ reqMap: inout [String: RequirementNode],
    _ elMap: inout [String: ElementNode],
    _ classDefMap: [String: RequirementClassDef]
) {
    // Grammar: CLASS idList idList
    // In Jison's <style> state, ids are single-word ALPHA tokens (never multi-word unqString).
    // Commas separate ids within a list; the two lists are separated by a non-comma boundary.
    let rest = String(line.dropFirst("class".count)).trimmingCharacters(in: .whitespaces)
    let words = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard words.count >= 2 else { return }

    // Flatten each word into comma-separated parts, tracking comma boundaries
    var ids: [String] = []
    var commaAfter: Set<Int> = []
    for word in words {
        let parts = word.split(separator: ",", omittingEmptySubsequences: true).map(String.init)
        for (j, part) in parts.enumerated() {
            if !part.isEmpty { ids.append(part) }
            if j < parts.count - 1 { commaAfter.insert(ids.count - 1) }
        }
        if word.hasSuffix(",") && !ids.isEmpty { commaAfter.insert(ids.count - 1) }
        if word.hasPrefix(",") && ids.count >= 2 { commaAfter.insert(ids.count - 2) }
    }

    guard ids.count >= 2 else { return }

    // Find boundary between the two idLists:
    // scan backwards — first id NOT preceded by a comma starts the second list.
    var splitAt = ids.count
    for i in stride(from: ids.count - 1, through: 0, by: -1) {
        splitAt = i
        if i == 0 || !commaAfter.contains(i - 1) { break }
    }

    let entityNames = Array(ids[0..<splitAt])
    let classNames = Array(ids[splitAt...])

    if entityNames.isEmpty || classNames.isEmpty { return }

    for name in entityNames {
        if var node = reqMap[name] {
            for cn in classNames {
                if !node.classes.contains(cn) { node.classes.append(cn) }
                if let def = classDefMap[cn] { node.cssStyles.append(contentsOf: def.styles) }
            }
            reqMap[name] = node
        }
        if var node = elMap[name] {
            for cn in classNames {
                if !node.classes.contains(cn) { node.classes.append(cn) }
                if let def = classDefMap[cn] { node.cssStyles.append(contentsOf: def.styles) }
            }
            elMap[name] = node
        }
    }
}

private func _reqParseShorthandClass(
    _ line: String,
    _ reqMap: inout [String: RequirementNode],
    _ elMap: inout [String: ElementNode]
) {
    let parts = line.split(separator: ":::", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
    guard parts.count == 2 else { return }
    let name = parts[0].trimmingCharacters(in: .whitespaces)
    let classStr = parts[1].trimmingCharacters(in: .whitespaces)
    let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    for cn in classNames {
        if var node = reqMap[name] { if !node.classes.contains(cn) { node.classes.append(cn) }; reqMap[name] = node }
        if var node = elMap[name] { if !node.classes.contains(cn) { node.classes.append(cn) }; elMap[name] = node }
    }
}

// MARK: - Utilities

private func _reqParseStyleValues(_ text: String) -> [String] {
    var values: [String] = []
    var current = ""
    var depth = 0
    for ch in text {
        if ch == "(" { depth += 1 }
        else if ch == ")" { depth -= 1 }
        if ch == "," && depth == 0 {
            values.append(current.trimmingCharacters(in: .whitespaces))
            current = ""
        } else {
            current.append(ch)
        }
    }
    let last = current.trimmingCharacters(in: .whitespaces)
    if !last.isEmpty { values.append(last) }
    return values
}

private func _reqUnquotedValue(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}

private func _reqStripQuotes(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
        let start = t.index(after: t.startIndex)
        let end = t.index(before: t.endIndex)
        return String(t[start..<end])
    }
    return t
}
