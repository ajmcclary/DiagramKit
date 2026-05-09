import Foundation

// MARK: - Text Sanitization

public func _gitGraphSanitizeText(_ text: String) -> String {
    text
}

// MARK: - Generated ID Generation

public func _gitGraphGeneratedID(seq: Int) -> String {
    let chars = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    let length = 7
    var result = ""
    var value = UInt64(truncatingIfNeeded: seq)
    value = value &* 0x9E3779B185EBCA87 &+ 0xC2B2AE3D27D4EB4F
    for _ in 0..<length {
        let index = Int(value % UInt64(chars.count))
        result.append(chars[index])
        value = value / UInt64(chars.count)
    }
    return result
}

// MARK: - Parser State (DB equivalent)

public struct _GitGraphDBState: Sendable {
    var commits: [String: GitGraphCommit] = [:]
    var head: GitGraphCommit?
    var branchConfig: [String: _GitGraphBranchConfig] = [:]
    var branchHeads: [String: String?] = [:]
    var branchInsertionOrder: [String] = []
    var branchNames: Set<String> = []
    var currBranch: String
    var direction: GitGraphOrientation
    var seq: Int = 0
    var config: GitGraphConfig
    var warnings: [String] = []

    init(config: GitGraphConfig, direction: GitGraphOrientation = .LR) {
        let main = config.mainBranchName
        self.currBranch = main
        self.direction = direction
        self.config = config
        self.branchNames.insert(main)
        self.branchInsertionOrder.append(main)
        self.branchHeads[main] = nil
        self.branchConfig[main] = _GitGraphBranchConfig(name: main, order: config.mainBranchOrder)
    }
}

public struct _GitGraphBranchConfig: Sendable, Equatable {
    var name: String
    var order: Int?
}

// MARK: - DB Operations

extension _GitGraphDBState {

    private func headID(for branch: String) -> String? {
        branchHeads[branch] ?? nil
    }

    mutating func commitDB(_ msg: String, id: String?, type: GitGraphCommitType?, tags: [String]?) {
        let effectiveId = id.map { _gitGraphSanitizeText($0) }
        let effectiveMsg = _gitGraphSanitizeText(msg)
        let effectiveType = type ?? .normal
        let effectiveTags = tags?.map { _gitGraphSanitizeText($0) } ?? []

        let commitID = (effectiveId != nil && !effectiveId!.isEmpty) ? effectiveId! : "\(seq)-\(_gitGraphGeneratedID(seq: seq))"
        let newCommit = GitGraphCommit(
            id: commitID,
            message: effectiveMsg,
            seq: seq,
            type: effectiveType,
            tags: effectiveTags,
            parents: head == nil ? [] : [head!.id],
            branch: currBranch
        )
        if commits[newCommit.id] != nil {
            warnings.append("Commit ID \(newCommit.id) already exists")
        }
        commits[newCommit.id] = newCommit
        branchHeads[currBranch] = newCommit.id
        head = newCommit
        seq += 1
    }

    mutating func branchDB(_ name: String, order: Int?) throws {
        let sanitized = _gitGraphSanitizeText(name)
        if branchNames.contains(sanitized) {
            throw GitGraphDBError.duplicateBranch(sanitized)
        }
        branchNames.insert(sanitized)
        branchInsertionOrder.append(sanitized)
        branchHeads[sanitized] = head?.id
        branchConfig[sanitized] = _GitGraphBranchConfig(name: sanitized, order: order)
        try checkoutDB(sanitized)
    }

    mutating func mergeDB(_ branch: String, id: String?, type: GitGraphCommitType?, tags: [String]?) throws {
        let otherBranch = _gitGraphSanitizeText(branch)
        let customId: String? = id.map { _gitGraphSanitizeText($0) }.flatMap { $0.isEmpty ? nil : $0 }

        let currentHeadID = headID(for: currBranch)
        let otherHeadID = headID(for: otherBranch)

        let currentCommit: GitGraphCommit? = currentHeadID.flatMap { commits[$0] }
        let otherCommit: GitGraphCommit? = otherHeadID.flatMap { commits[$0] }

        if let cc = currentCommit, otherCommit != nil, cc.branch == otherBranch {
            throw GitGraphDBError.mergeIntoSelf(otherBranch)
        }
        if currBranch == otherBranch {
            throw GitGraphDBError.mergeIntoSelf(otherBranch)
        }
        if currentCommit == nil {
            throw GitGraphDBError.mergeEmptyCurrent(currBranch)
        }
        if !branchNames.contains(otherBranch) {
            throw GitGraphDBError.mergeUnknownBranch(otherBranch)
        }
        if otherCommit == nil {
            throw GitGraphDBError.mergeEmptyTarget(otherBranch)
        }
        if currentCommit?.id == otherCommit?.id {
            throw GitGraphDBError.mergeSameHead
        }
        if let cid = customId, commits[cid] != nil {
            throw GitGraphDBError.mergeDuplicateId(cid)
        }

        let verifiedHead: String = otherHeadID ?? ""
        let effectiveTags = tags?.map { _gitGraphSanitizeText($0) } ?? []

        let commitID = customId ?? "\(seq)-\(_gitGraphGeneratedID(seq: seq))"
        let newCommit = GitGraphCommit(
            id: commitID,
            message: "merged branch \(otherBranch) into \(currBranch)",
            seq: seq,
            type: .merge,
            tags: effectiveTags,
            parents: head == nil ? [] : [head!.id, verifiedHead],
            branch: currBranch,
            customType: type,
            customId: customId != nil
        )
        commits[newCommit.id] = newCommit
        branchHeads[currBranch] = newCommit.id
        head = newCommit
        seq += 1
    }

    mutating func cherryPickDB(_ sourceId: String?, parent: String?, tags: [String]?) throws {
        guard let sourceId = sourceId, !sourceId.isEmpty else {
            throw GitGraphDBError.cherryPickMissingSource
        }
        let sanitized = _gitGraphSanitizeText(sourceId)
        guard let sourceCommit = commits[sanitized] else {
            throw GitGraphDBError.cherryPickSourceNotFound
        }

        if let parentId = parent, !parentId.isEmpty {
            let sanitizedParent = _gitGraphSanitizeText(parentId)
            if !sourceCommit.parents.contains(sanitizedParent) {
                throw GitGraphDBError.cherryPickInvalidParent
            }
        }

        if sourceCommit.type == .merge && (parent == nil || parent!.isEmpty) {
            throw GitGraphDBError.cherryPickMergeWithoutParent
        }

        if sourceCommit.branch == currBranch {
            throw GitGraphDBError.cherryPickSameBranch
        }

        guard let currentHeadID = headID(for: currBranch), let _ = commits[currentHeadID] else {
            throw GitGraphDBError.cherryPickEmptyCurrent(currBranch)
        }

        let effectiveTags: [String] = {
            if let tags = tags {
                return tags.filter { !$0.isEmpty }.map { _gitGraphSanitizeText($0) }
            }
            var defaultTag = "cherry-pick:\(sourceCommit.id)"
            if sourceCommit.type == .merge, let p = parent, !p.isEmpty {
                defaultTag += "|parent:\(p)"
            }
            return [defaultTag]
        }()

        let newCommit = GitGraphCommit(
            id: "\(seq)-\(_gitGraphGeneratedID(seq: seq))",
            message: "cherry-picked \(sourceCommit.message) into \(currBranch)",
            seq: seq,
            type: .cherryPick,
            tags: effectiveTags,
            parents: head == nil ? [] : [head!.id, sourceCommit.id],
            branch: currBranch
        )
        commits[newCommit.id] = newCommit
        branchHeads[currBranch] = newCommit.id
        head = newCommit
        seq += 1
    }

    mutating func checkoutDB(_ branch: String) throws {
        let sanitized = _gitGraphSanitizeText(branch)
        guard branchNames.contains(sanitized) else {
            throw GitGraphDBError.checkoutUnknownBranch(sanitized)
        }
        currBranch = sanitized
        if let hID = headID(for: sanitized) {
            head = commits[hID]
        } else {
            head = nil
        }
    }

    func getBranchesAsObjArray() -> [String] {
        let sorted = branchInsertionOrder.enumerated().compactMap { index, branchName -> (String, Double, Int)? in
            guard let cfg = branchConfig[branchName] else { return nil }
            if let order = cfg.order {
                return (branchName, Double(order), index)
            }
            return (branchName, Double("0.\(index)") ?? 0, index)
        }
        return sorted.sorted {
            if $0.1 == $1.1 { return $0.2 < $1.2 }
            return $0.1 < $1.1
        }.map { $0.0 }
    }

    func getCommitsArray() -> [GitGraphCommit] {
        commits.values.sorted { $0.seq < $1.seq }
    }
}

// MARK: - Tokenizer

private struct _GitGraphPropertyScan {
    var properties: [String: [String]] = [:]
    var bareQuotedStrings: [String] = []

    func last(_ key: String) -> String? {
        properties[key]?.last
    }

    func all(_ key: String) -> [String] {
        properties[key] ?? []
    }
}

private func _gitGraphUnescapeQuoted(_ value: String) -> String {
    var result = ""
    var isEscaped = false
    for ch in value {
        if isEscaped {
            result.append(ch)
            isEscaped = false
        } else if ch == "\\" {
            isEscaped = true
        } else {
            result.append(ch)
        }
    }
    if isEscaped { result.append("\\") }
    return result
}

private func _gitGraphReadQuoted(
    from text: String,
    startingAt quoteIndex: String.Index,
    context: String
) throws -> (value: String, next: String.Index) {
    var i = text.index(after: quoteIndex)
    var value = ""
    var isEscaped = false

    while i < text.endIndex {
        let ch = text[i]
        if isEscaped {
            value.append(ch)
            isEscaped = false
            i = text.index(after: i)
            continue
        }
        if ch == "\\" {
            isEscaped = true
            i = text.index(after: i)
            continue
        }
        if ch == "\"" {
            return (value, text.index(after: i))
        }
        value.append(ch)
        i = text.index(after: i)
    }

    throw GitGraphParserError.invalidStatement("Unterminated quoted string in \(context).")
}

private func _gitGraphScanProperties(
    _ text: String,
    context: String,
    allowedKeys: Set<String>,
    allowBareQuotedString: Bool = false
) throws -> _GitGraphPropertyScan {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    var scan = _GitGraphPropertyScan()
    var i = trimmed.startIndex

    while i < trimmed.endIndex {
        while i < trimmed.endIndex && trimmed[i].isWhitespace {
            i = trimmed.index(after: i)
        }
        guard i < trimmed.endIndex else { break }

        if trimmed[i] == "\"" {
            guard allowBareQuotedString else {
                throw GitGraphParserError.unexpectedProperty(String(trimmed[i...]), context)
            }
            let quoted = try _gitGraphReadQuoted(from: trimmed, startingAt: i, context: context)
            scan.bareQuotedStrings.append(quoted.value)
            i = quoted.next
            continue
        }

        let keyStart = i
        while i < trimmed.endIndex && trimmed[i] != ":" && !trimmed[i].isWhitespace {
            i = trimmed.index(after: i)
        }

        guard i < trimmed.endIndex && trimmed[i] == ":" else {
            throw GitGraphParserError.invalidStatement(String(trimmed[keyStart...]))
        }

        let key = String(trimmed[keyStart..<i]).trimmingCharacters(in: .whitespaces)
        guard allowedKeys.contains(key) else {
            throw GitGraphParserError.unexpectedProperty(key, context)
        }

        i = trimmed.index(after: i)
        while i < trimmed.endIndex && trimmed[i].isWhitespace {
            i = trimmed.index(after: i)
        }
        guard i < trimmed.endIndex else {
            throw GitGraphParserError.missingPropertyValue(key, context)
        }

        let value: String
        if trimmed[i] == "\"" {
            let quoted = try _gitGraphReadQuoted(from: trimmed, startingAt: i, context: context)
            value = quoted.value
            i = quoted.next
        } else {
            let valueStart = i
            while i < trimmed.endIndex && !trimmed[i].isWhitespace {
                i = trimmed.index(after: i)
            }
            value = String(trimmed[valueStart..<i])
            if value.isEmpty {
                throw GitGraphParserError.missingPropertyValue(key, context)
            }
        }

        scan.properties[key, default: []].append(value)
    }

    return scan
}

private func _gitGraphParseReferenceToken(_ text: String, context: String) throws -> (name: String, remainder: String, quoted: Bool) {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
        throw GitGraphParserError.missingPropertyValue("name", context)
    }

    if trimmed[trimmed.startIndex] == "\"" {
        let quoted = try _gitGraphReadQuoted(from: trimmed, startingAt: trimmed.startIndex, context: context)
        let name = _gitGraphUnescapeQuoted(quoted.value)
        let remainder = String(trimmed[quoted.next...])
        return (name, remainder, true)
    }

    var end = trimmed.startIndex
    while end < trimmed.endIndex && !trimmed[end].isWhitespace {
        end = trimmed.index(after: end)
    }
    let name = String(trimmed[..<end])
    try _gitGraphValidateReference(name, context: context)
    return (name, String(trimmed[end...]), false)
}

private func _gitGraphValidateReference(_ name: String, context: String) throws {
    guard !name.isEmpty else {
        throw GitGraphParserError.missingPropertyValue("name", context)
    }
    let full = NSRange(name.startIndex..<name.endIndex, in: name)
    let match = name.range(of: #"^\w([-\./\w]*[-\w])?$"#, options: .regularExpression)
    guard let match, NSRange(match, in: name) == full else {
        throw GitGraphParserError.invalidStatement("Invalid GitGraph reference '\(name)' in \(context).")
    }
}

public func _gitGraphParseCommitType(_ s: String) -> GitGraphCommitType? {
    switch s.uppercased().trimmingCharacters(in: .whitespaces) {
    case "NORMAL": return .normal
    case "REVERSE": return .reverse
    case "HIGHLIGHT": return .highlight
    default: return nil
    }
}

public func _gitGraphParseInt(_ s: String) -> Int? {
    Int(s.trimmingCharacters(in: .whitespaces))
}

// MARK: - Statement Parser

public func _gitGraphParseStatement(_ line: String) throws -> GitGraphStatement? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    guard !trimmed.hasPrefix("%%") else { return nil }

    if trimmed.lowercased().hasPrefix("commit ") {
        let rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)...])
        let props = try _gitGraphScanProperties(
            rest,
            context: "commit",
            allowedKeys: ["id", "msg", "tag", "type"],
            allowBareQuotedString: true
        )

        var type: GitGraphCommitType?
        if let typeStr = props.last("type") {
            guard let parsed = _gitGraphParseCommitType(typeStr) else {
                throw GitGraphParserError.invalidCommitType(typeStr)
            }
            type = parsed
        }

        let id = props.last("id")
        let message = props.last("msg") ?? props.bareQuotedStrings.first
        let tags = props.all("tag")
        return .commit(GitGraphCommitStatement(id: id, message: message, tags: tags, type: type))
    }

    if trimmed.lowercased().hasPrefix("commit") && (trimmed.count == 6 || trimmed.dropFirst(6).first?.isWhitespace == true) {
        let rest = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        if rest.isEmpty {
            return .commit(GitGraphCommitStatement())
        }
        let props = try _gitGraphScanProperties(
            rest,
            context: "commit",
            allowedKeys: ["id", "msg", "tag", "type"],
            allowBareQuotedString: true
        )
        var type: GitGraphCommitType?
        if let typeStr = props.last("type") {
            guard let parsed = _gitGraphParseCommitType(typeStr) else {
                throw GitGraphParserError.invalidCommitType(typeStr)
            }
            type = parsed
        }

        let id = props.last("id")
        let message = props.last("msg") ?? props.bareQuotedStrings.first
        let tags = props.all("tag")
        return .commit(GitGraphCommitStatement(id: id, message: message, tags: tags, type: type))
    }

    if trimmed.lowercased().hasPrefix("branch ") {
        let rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)...]).trimmingCharacters(in: .whitespaces)
        let reference = try _gitGraphParseReferenceToken(rest, context: "branch")
        let props = try _gitGraphScanProperties(
            reference.remainder,
            context: "branch",
            allowedKeys: ["order"]
        )
        var order: Int?
        if let orderStr = props.last("order") {
            guard let parsed = _gitGraphParseInt(orderStr) else {
                throw GitGraphParserError.invalidOrderValue(orderStr)
            }
            order = parsed
        }
        return .branch(GitGraphBranchStatement(name: reference.name, order: order))
    }

    if trimmed.lowercased().hasPrefix("checkout ") {
        let rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 9)...]).trimmingCharacters(in: .whitespaces)
        let reference = try _gitGraphParseReferenceToken(rest, context: "checkout")
        if !reference.remainder.trimmingCharacters(in: .whitespaces).isEmpty {
            throw GitGraphParserError.invalidStatement(trimmed)
        }
        return .checkout(GitGraphCheckoutStatement(branch: reference.name))
    }

    if trimmed.lowercased().hasPrefix("switch ") {
        let rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)...]).trimmingCharacters(in: .whitespaces)
        let reference = try _gitGraphParseReferenceToken(rest, context: "switch")
        if !reference.remainder.trimmingCharacters(in: .whitespaces).isEmpty {
            throw GitGraphParserError.invalidStatement(trimmed)
        }
        return .checkout(GitGraphCheckoutStatement(branch: reference.name))
    }

    if trimmed.lowercased().hasPrefix("merge ") {
        let rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 6)...]).trimmingCharacters(in: .whitespaces)
        let reference = try _gitGraphParseReferenceToken(rest, context: "merge")
        let props = try _gitGraphScanProperties(
            reference.remainder,
            context: "merge",
            allowedKeys: ["id", "tag", "type"]
        )
        var type: GitGraphCommitType?
        if let typeStr = props.last("type") {
            guard let parsed = _gitGraphParseCommitType(typeStr) else {
                throw GitGraphParserError.invalidCommitType(typeStr)
            }
            type = parsed
        }
        return .merge(GitGraphMergeStatement(branch: reference.name, id: props.last("id"), tags: props.all("tag"), type: type))
    }

    if trimmed.lowercased().hasPrefix("cherry-pick") {
        let rest: String
        if trimmed.lowercased().hasPrefix("cherry-pick ") {
            rest = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 11)...]).trimmingCharacters(in: .whitespaces)
        } else {
            rest = trimmed.dropFirst(11).trimmingCharacters(in: .whitespaces)
        }
        let props = try _gitGraphScanProperties(
            rest,
            context: "cherry-pick",
            allowedKeys: ["id", "tag", "parent"]
        )
        let id = props.last("id")
        let parent = props.last("parent")
        let tagValues = props.all("tag")
        let tags: [String]? = tagValues.isEmpty ? nil : tagValues
        return .cherryPick(GitGraphCherryPickStatement(id: id, parent: parent, tags: tags))
    }

    throw GitGraphParserError.invalidStatement(trimmed)
}

// MARK: - Header Parsing

public func _gitGraphParseHeader(_ line: String) throws -> (direction: GitGraphOrientation, title: String?, accTitle: String?, accDescr: String?) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let lower = trimmed.lowercased()

    guard lower.hasPrefix("gitgraph") else {
        throw GitGraphParserError.invalidHeader(trimmed)
    }

    let afterGitGraph = String(trimmed.dropFirst("gitgraph".count))
    let remaining = afterGitGraph.trimmingCharacters(in: .whitespaces)

    var direction: GitGraphOrientation = .LR
    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?

    if remaining.isEmpty || remaining == ":" {
        return (.LR, nil, nil, nil)
    }

    var rest = remaining
    if rest.hasSuffix(":") {
        rest = String(rest.dropLast())
    }

    let tokens = rest.split(separator: " ", omittingEmptySubsequences: true)
    for token in tokens {
        let upper = token.uppercased()
        if let dir = GitGraphOrientation(rawValue: upper) {
            direction = dir
            continue
        }
    }

    if trimmed.lowercased().contains("title ") {
        if let titleRange = trimmed.range(of: "title ", options: .caseInsensitive) {
            let titleText = String(trimmed[titleRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !titleText.isEmpty {
                diagramTitle = titleText
            }
        }
    }

    if trimmed.lowercased().contains("acctitle:") {
        if let range = trimmed.range(of: "acctitle:", options: .caseInsensitive) {
            let text = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            accTitle = text.isEmpty ? nil : text
        }
    }

    if trimmed.lowercased().contains("accdescr:") && !trimmed.lowercased().contains("accdescr {") {
        if let range = trimmed.range(of: "accdescr:", options: .caseInsensitive) {
            let text = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            accDescr = text.isEmpty ? nil : text
        }
    }

    if trimmed.lowercased().contains("accdescr {") || trimmed.lowercased().contains("accdescr{") {
        accDescr = nil
        _ = accDescr
    }

    return (direction, diagramTitle, accTitle, accDescr)
}

// MARK: - Main Parse Function

public func parseGitGraph(_ lines: [String], frontmatter: DiagramFrontmatter?) throws -> GitGraphDiagram {
    guard let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") }) else {
        throw GitGraphParserError.emptySource
    }

    let header = firstLine.trimmingCharacters(in: .whitespaces)
    let (direction, headerTitle, headerAccTitle, headerAccDescr) = try _gitGraphParseHeader(header)

    var statements: [GitGraphStatement] = []
    var diagramTitle: String? = headerTitle
    var accTitle: String? = headerAccTitle
    var accDescr: String? = headerAccDescr

    let headerLower = header.lowercased()
    var inAccDescrMultiline = false
    var accDescrMultiline: String = ""

    if headerLower.contains("accdescr {") || headerLower.contains("accdescr{") {
        if let range = header.range(of: "accDescr {", options: .caseInsensitive) ?? header.range(of: "accDescr{", options: .caseInsensitive) {
            let after = String(header[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if after.hasSuffix("}") {
                var content = after
                content.removeLast()
                accDescr = content.trimmingCharacters(in: .whitespaces)
            } else {
                inAccDescrMultiline = true
                accDescrMultiline = after
            }
        }
    }

    if let fm = frontmatter {
        if diagramTitle == nil { diagramTitle = fm.title ?? fm.diagramTitle }
    }

    var config = GitGraphConfig()
    if let fm = frontmatter {
        if let gc = fm.gitGraphConfig { config = gc }
    }

    let remainingLines = lines.drop(while: { $0.trimmingCharacters(in: .whitespaces) == firstLine.trimmingCharacters(in: .whitespaces) || $0.trimmingCharacters(in: .whitespaces).isEmpty || $0.trimmingCharacters(in: .whitespaces).hasPrefix("%%") })
    var i = 0
    let allLines = Array(remainingLines)

    while i < allLines.count {
        let rawLine = allLines[i]
        let line = rawLine.trimmingCharacters(in: .whitespaces)

        if line.isEmpty || line.hasPrefix("%%") {
            i += 1
            continue
        }

        if inAccDescrMultiline {
            if line.hasSuffix("}") {
                var content = line
                content.removeLast()
                accDescrMultiline += "\n" + content.trimmingCharacters(in: .whitespaces)
                accDescr = accDescrMultiline.trimmingCharacters(in: .whitespaces)
                inAccDescrMultiline = false
                accDescrMultiline = ""
            } else {
                accDescrMultiline += "\n" + line
            }
            i += 1
            continue
        }

        let lower = line.lowercased()

        if lower.hasPrefix("title ") {
            diagramTitle = String(line[line.index(line.startIndex, offsetBy: 6)...]).trimmingCharacters(in: .whitespaces)
            i += 1
            continue
        }

        if lower.hasPrefix("acctitle:") {
            let text = String(line[line.index(line.startIndex, offsetBy: 9)...]).trimmingCharacters(in: .whitespaces)
            accTitle = text.isEmpty ? nil : text
            i += 1
            continue
        }

        if lower.hasPrefix("accdescr:") && !lower.hasPrefix("accdescr {") {
            let text = String(line[line.index(line.startIndex, offsetBy: 9)...]).trimmingCharacters(in: .whitespaces)
            accDescr = text.isEmpty ? nil : text
            i += 1
            continue
        }

        if lower.hasPrefix("accdescr {") {
            var multiline = line.replacingOccurrences(of: "accDescr {", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "accDescr{", with: "", options: .caseInsensitive)
            var closed = false
            i += 1
            while i < allLines.count {
                let nextLine = allLines[i].trimmingCharacters(in: .whitespaces)
                i += 1
                if nextLine.hasSuffix("}") {
                    var content = nextLine
                    content.removeLast()
                    multiline += "\n" + content
                    closed = true
                    break
                }
                multiline += "\n" + nextLine
            }
            if closed {
                accDescr = multiline.trimmingCharacters(in: .whitespaces)
            }
            continue
        }

        if let stmt = try _gitGraphParseStatement(line) {
            statements.append(stmt)
        }

        i += 1
    }

    var dbState = _GitGraphDBState(config: config, direction: direction)
    for stmt in statements {
        switch stmt {
        case .commit(let cs):
            dbState.commitDB(cs.message ?? "", id: cs.id, type: cs.type, tags: cs.tags.isEmpty ? nil : cs.tags)
        case .branch(let bs):
            try dbState.branchDB(bs.name, order: bs.order)
        case .checkout(let cs):
            try dbState.checkoutDB(cs.branch)
        case .merge(let ms):
            try dbState.mergeDB(ms.branch, id: ms.id, type: ms.type, tags: ms.tags.isEmpty ? nil : ms.tags)
        case .cherryPick(let cp):
            try dbState.cherryPickDB(cp.id, parent: cp.parent, tags: cp.tags)
        }
    }

    let theme = frontmatter?.gitGraphTheme ?? GitGraphThemeConfig()
    let look = frontmatter?.look
    let themeName = frontmatter?.theme

    var publicBranchHeads: [String: String?] = [:]
    for branchName in dbState.branchInsertionOrder {
        publicBranchHeads[branchName] = .some(dbState.branchHeads[branchName] ?? nil)
    }

    return GitGraphDiagram(
        statements: statements,
        commits: dbState.getCommitsArray(),
        branches: dbState.getBranchesAsObjArray(),
        branchHeads: publicBranchHeads,
        currentBranch: dbState.currBranch,
        direction: direction,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: config,
        theme: theme,
        warnings: dbState.warnings,
        look: look,
        themeName: themeName
    )
}
