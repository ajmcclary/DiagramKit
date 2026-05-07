import Foundation

private final class _MutableTreeNode: @unchecked Sendable {
    var name: String
    var nodeType: TreeViewNodeType
    var iconId: String?
    var cssClass: String?
    var description: String?
    var children: [_MutableTreeNode]
    var level: Int

    init(name: String, nodeType: TreeViewNodeType, iconId: String?, cssClass: String?, description: String?, children: [_MutableTreeNode] = [], level: Int = 0) {
        self.name = name
        self.nodeType = nodeType
        self.iconId = iconId
        self.cssClass = cssClass
        self.description = description
        self.children = children
        self.level = level
    }

    func toTreeViewNode(id: Int = 0) -> TreeViewNode {
        TreeViewNode(
            id: id,
            level: level,
            name: name,
            nodeType: nodeType,
            iconId: iconId,
            cssClass: cssClass,
            description: description,
            children: []
        )
    }
}

func _isTreeViewHeader(rawLines: [String]) -> Bool {
    let firstLine = rawLines.first { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.hasPrefix("%%")
    }?.trimmingCharacters(in: .whitespaces) ?? ""
    return firstLine == "treeView-beta" || firstLine.hasPrefix("treeView-beta ") || firstLine.hasPrefix("treeView-beta\t")
}

func parseTreeViewDiagram(_ rawLines: [String], frontmatter: DiagramFrontmatter?) throws -> TreeViewDiagram {
    guard !rawLines.isEmpty else {
        throw TreeViewParserError.emptySource
    }

    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?
    var accDescrLines: [String] = []
    var inAccDescrBlock = false

    var headerFound = false
    var headerIndex = -1

    for (i, line) in rawLines.enumerated() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "treeView-beta" || trimmed.hasPrefix("treeView-beta ") || trimmed.hasPrefix("treeView-beta\t") {
            headerFound = true
            headerIndex = i
            break
        }
        if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }
        throw TreeViewParserError.invalidHeader(trimmed)
    }

    guard headerFound else {
        throw TreeViewParserError.invalidHeader("treeView-beta header not found")
    }

    let titlePattern = try! NSRegularExpression(pattern: "^title\\s+(.+)$", options: .caseInsensitive)
    let accTitlePattern = try! NSRegularExpression(pattern: "^accTitle\\s*:\\s*(.+)$", options: .caseInsensitive)
    let accDescrPattern = try! NSRegularExpression(pattern: "^accDescr\\s*:\\s*(.+)$", options: .caseInsensitive)
    let accDescrOpenPattern = try! NSRegularExpression(pattern: "^accDescr\\s*\\{\\s*(.*)$")
    let accDescrInlinePattern = try! NSRegularExpression(pattern: "^accDescr\\s*\\{\\s*(.+?)\\s*\\}\\s*$", options: .caseInsensitive)

    let root = _MutableTreeNode(name: "/", nodeType: .directory, iconId: nil, cssClass: nil, description: nil, level: -1)
    var stack: [(level: Int, node: _MutableTreeNode)] = [(-1, root)]
    var allNodes: [_MutableTreeNode] = [root]
    var nextId = 1

    for (i, line) in rawLines.enumerated() {
        if i <= headerIndex { continue }

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        if inAccDescrBlock {
            if trimmedLine.contains("}") {
                if let range = trimmedLine.range(of: "}") {
                    let beforeBrace = String(trimmedLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !beforeBrace.isEmpty { accDescrLines.append(beforeBrace) }
                }
                inAccDescrBlock = false
                accDescr = accDescrLines.filter { !$0.isEmpty }.joined(separator: " ")
            } else {
                if !trimmedLine.isEmpty { accDescrLines.append(trimmedLine) }
            }
            continue
        }

        if trimmedLine.isEmpty || trimmedLine.hasPrefix("%%") { continue }

        if let match = accDescrInlinePattern.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
            accDescr = (trimmedLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            continue
        }

        if let match = accDescrOpenPattern.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
            inAccDescrBlock = true
            accDescrLines = []
            let firstContent = (trimmedLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if firstContent.hasSuffix("}") {
                accDescr = String(firstContent.dropLast()).trimmingCharacters(in: .whitespaces)
                inAccDescrBlock = false
            } else if !firstContent.isEmpty {
                accDescrLines.append(firstContent)
            }
            continue
        }

        if let match = accTitlePattern.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
            accTitle = _unquoteLabel((trimmedLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        if let match = accDescrPattern.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
            accDescr = _unquoteLabel((trimmedLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        if let match = titlePattern.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
            diagramTitle = _unquoteLabel((trimmedLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        let (level, name, nodeType, cssClass, iconId, description) = try _parseTreeViewLine(line)
        while level <= (stack.last?.level ?? -1) {
            stack.removeLast()
        }

        let node = _MutableTreeNode(
            name: name, nodeType: nodeType,
            iconId: iconId, cssClass: cssClass,
            description: description, level: level
        )
        stack.last!.node.children.append(node)
        stack.append((level, node))
        allNodes.append(node)
        nextId += 1
    }

    func convert(_ mnode: _MutableTreeNode, id: inout Int) -> TreeViewNode {
        let currentId = id
        id += 1
        let convertedChildren = mnode.children.map { convert($0, id: &id) }
        return TreeViewNode(
            id: currentId,
            level: mnode.level,
            name: mnode.name,
            nodeType: mnode.nodeType,
            iconId: mnode.iconId,
            cssClass: mnode.cssClass,
            description: mnode.description,
            children: convertedChildren
        )
    }

    var rootId = 0
    let convertedRoot = convert(root, id: &rootId)

    var nodeList: [TreeViewNode] = []
    func collect(_ node: TreeViewNode) {
        nodeList.append(node)
        for child in node.children {
            collect(child)
        }
    }
    collect(convertedRoot)

    return TreeViewDiagram(
        root: convertedRoot,
        nodes: nodeList,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: TreeViewDiagramConfig.default,
        theme: frontmatter.flatMap { _ in nil }
    )
}

private func _parseTreeViewLine(_ line: String) throws -> (level: Int, name: String, nodeType: TreeViewNodeType, cssClass: String?, iconId: String?, description: String?) {
    let indentCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty, !trimmed.hasPrefix("%%") else {
        throw TreeViewParserError.invalidLine(line)
    }

    var name: String
    var remainder: String

    if trimmed.hasPrefix("\"") {
        guard let closeQuote = _findClosingQuote(trimmed, from: trimmed.index(after: trimmed.startIndex), quote: "\"") else {
            throw TreeViewParserError.missingLabel(trimmed)
        }
        let afterOpen = trimmed.index(after: trimmed.startIndex)
        name = String(trimmed[afterOpen..<closeQuote])
        remainder = String(trimmed[trimmed.index(after: closeQuote)...]).trimmingCharacters(in: .whitespaces)
    } else if trimmed.hasPrefix("'") {
        guard let closeQuote = _findClosingQuote(trimmed, from: trimmed.index(after: trimmed.startIndex), quote: "'") else {
            throw TreeViewParserError.missingLabel(trimmed)
        }
        let afterOpen = trimmed.index(after: trimmed.startIndex)
        name = String(trimmed[afterOpen..<closeQuote])
        remainder = String(trimmed[trimmed.index(after: closeQuote)...]).trimmingCharacters(in: .whitespaces)
    } else {
        var scanIdx = trimmed.startIndex
        while scanIdx < trimmed.endIndex {
            let remaining = String(trimmed[scanIdx...])
            if remaining.hasPrefix(":::") || remaining.hasPrefix("##") {
                break
            }
            if remaining.hasPrefix("icon(") {
                break
            }
            scanIdx = trimmed.index(after: scanIdx)
        }

        if scanIdx == trimmed.startIndex {
            throw TreeViewParserError.missingLabel(trimmed)
        }

        name = String(trimmed[trimmed.startIndex..<scanIdx]).trimmingCharacters(in: .whitespaces)
        remainder = String(trimmed[scanIdx...]).trimmingCharacters(in: .whitespaces)
    }

    name = _unescapeQuotes(name)
    let nodeType: TreeViewNodeType = name.hasSuffix("/") ? .directory : .file
    if nodeType == .directory {
        name = String(name.dropLast())
    }

    var cssClass: String?
    var iconId: String?
    var description: String?

    while !remainder.isEmpty {
        if remainder.hasPrefix(":::") {
            let rest = String(remainder.dropFirst(3))
            let spaceIdx = rest.firstIndex(of: " ") ?? rest.endIndex
            let className = String(rest[rest.startIndex..<spaceIdx])
            cssClass = className
            remainder = String(rest[spaceIdx...]).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("icon(") {
            let rest = String(remainder.dropFirst(5))
            guard let closeParen = rest.firstIndex(of: ")") else {
                break
            }
            let iconName = String(rest[rest.startIndex..<closeParen]).trimmingCharacters(in: .whitespaces)
            if iconName.isEmpty || iconName == "none" {
                iconId = "none"
            } else {
                iconId = _unquoteLabel(iconName)
            }
            remainder = String(rest[rest.index(after: closeParen)...]).trimmingCharacters(in: .whitespaces)
        } else if remainder.hasPrefix("##") {
            let rest = String(remainder.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            description = _sanitizeDescription(rest)
            remainder = ""
        } else {
            break
        }
    }

    if iconId == nil {
        iconId = resolveIcon(name: name, nodeType: nodeType)
    }

    return (indentCount, name, nodeType, cssClass, iconId, description)
}

private func _findClosingQuote(_ text: String, from start: String.Index, quote: Character) -> String.Index? {
    var idx = start
    while idx < text.endIndex {
        if text[idx] == "\\" {
            idx = text.index(after: idx)
            if idx < text.endIndex { idx = text.index(after: idx) }
            continue
        }
        if text[idx] == quote {
            return idx
        }
        idx = text.index(after: idx)
    }
    return nil
}

private func _unquoteLabel(_ s: String) -> String {
    var result = s
    if result.hasPrefix("\"") && result.hasSuffix("\"") { result = String(result.dropFirst().dropLast()) }
    if result.hasPrefix("'") && result.hasSuffix("'") { result = String(result.dropFirst().dropLast()) }
    return result
}

private func _unescapeQuotes(_ s: String) -> String {
    s.replacingOccurrences(of: "\\\"", with: "\"")
     .replacingOccurrences(of: "\\'", with: "'")
     .replacingOccurrences(of: "\\\\", with: "\\")
}

private func _sanitizeDescription(_ raw: String) -> String {
    var result = raw
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    return result
}
