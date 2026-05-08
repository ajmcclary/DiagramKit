import Foundation

private final class _MutableNode: @unchecked Sendable {
    var name: String
    var children: [_MutableNode]?
    var value: Double?
    var classSelector: String?

    var isLeaf: Bool { children == nil && value != nil }

    init(name: String, children: [_MutableNode]? = nil, value: Double? = nil, classSelector: String? = nil) {
        self.name = name
        self.children = children
        self.value = value
        self.classSelector = classSelector
    }

    func toTreemapNode() -> TreemapNode {
        TreemapNode(
            name: name,
            children: children?.map { $0.toTreemapNode() },
            value: value,
            classSelector: classSelector
        )
    }
}

func parseTreemapDiagram(_ rawLines: [String], frontmatter: DiagramFrontmatter?) throws -> TreemapDiagram {
    guard !rawLines.isEmpty else {
        throw TreemapParserError.emptySource
    }

    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?
    var accDescrLines: [String] = []
    var inAccDescrBlock = false

    var classDefs: [TreemapClassDef] = []

    let titlePattern = try! NSRegularExpression(pattern: "^title\\s+(.+)$", options: .caseInsensitive)
    let accTitlePattern = try! NSRegularExpression(pattern: "^accTitle\\s*:\\s*(.+)$", options: .caseInsensitive)
    let accDescrPattern = try! NSRegularExpression(pattern: "^accDescr\\s*:\\s*(.+)$", options: .caseInsensitive)
    let accDescrOpenPattern = try! NSRegularExpression(pattern: "^accDescr\\s*\\{\\s*(.+)$")
    let accDescrInlinePattern = try! NSRegularExpression(pattern: "^accDescr\\s*\\{\\s*(.+?)\\s*\\}\\s*$", options: .caseInsensitive)

    var headerFound = false
    let root = _MutableNode(name: "", children: [])
    var parentStack: [(indent: Int, node: _MutableNode)] = [(indent: -1, node: root)]

    for line in rawLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if !headerFound {
            let lowered = trimmed.lowercased()
            if lowered == "treemap-beta" || lowered == "treemap" || lowered.hasPrefix("treemap-beta ") || lowered.hasPrefix("treemap ") {
                headerFound = true
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }
            let loweredTrimmed = trimmed.lowercased()
            guard loweredTrimmed == "treemap-beta" || loweredTrimmed == "treemap" || loweredTrimmed.hasPrefix("treemap-beta") || loweredTrimmed.hasPrefix("treemap") else {
                throw TreemapParserError.invalidHeader(trimmed)
            }
            headerFound = true
            continue
        }

        if inAccDescrBlock {
            if trimmed.contains("}") {
                if let range = trimmed.range(of: "}") {
                    let beforeBrace = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !beforeBrace.isEmpty { accDescrLines.append(beforeBrace) }
                }
                inAccDescrBlock = false
                accDescr = accDescrLines.joined(separator: " ")
            } else {
                accDescrLines.append(trimmed)
            }
            continue
        }

        if trimmed.isEmpty || trimmed.hasPrefix("%%") { continue }

        if let match = accDescrInlinePattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            accDescr = (trimmed as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            continue
        }

        if let match = accDescrOpenPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            inAccDescrBlock = true
            accDescrLines = []
            let firstContent = (trimmed as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            if firstContent.hasSuffix("}") {
                accDescr = String(firstContent.dropLast()).trimmingCharacters(in: .whitespaces)
                inAccDescrBlock = false
            } else {
                accDescrLines.append(firstContent)
            }
            continue
        }

        if let match = accTitlePattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            accTitle = _unquoteTreemap((trimmed as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        if let match = accDescrPattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            accDescr = _unquoteTreemap((trimmed as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        if let match = titlePattern.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            diagramTitle = _unquoteTreemap((trimmed as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            continue
        }

        let classDefRegex = try! NSRegularExpression(pattern: "^classDef\\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\\s+(.+?))?\\s*;?\\s*$")
        if let match = classDefRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
            let className = (trimmed as NSString).substring(with: match.range(at: 1))
            var styleText = ""
            if match.range(at: 2).location != NSNotFound {
                styleText = (trimmed as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            }
            let (nodeStyles, textStyles) = TreemapClassDef.parseStyleText(styleText)
            classDefs.append(TreemapClassDef(className: className, styleText: styleText, styles: nodeStyles, textStyles: textStyles))
            continue
        }

        let (indent, name, value, classSelector) = try _parseTreemapLine(line)
        while let top = parentStack.last, indent <= top.indent {
            parentStack.removeLast()
        }

        if let _ = value {
            let leafNode = _MutableNode(name: name, value: value, classSelector: classSelector)
            var kids = parentStack[parentStack.count - 1].node.children ?? []
            kids.append(leafNode)
            parentStack[parentStack.count - 1].node.children = kids
        } else {
            let sectionNode = _MutableNode(name: name, children: [], classSelector: classSelector)
            var kids = parentStack[parentStack.count - 1].node.children ?? []
            kids.append(sectionNode)
            parentStack[parentStack.count - 1].node.children = kids
            parentStack.append((indent: indent, node: sectionNode))
        }
    }

    let styledNodes = _resolveTreemapClassStyles(root.children?.map { $0.toTreemapNode() } ?? [], classDefs: classDefs)
    return TreemapDiagram(
        nodes: styledNodes,
        classDefs: classDefs,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: TreemapDiagramConfig.default,
        themeName: frontmatter?.theme,
        themeVariables: frontmatter?.treemapThemeVariables
    )
}

private func _parseTreemapLine(_ line: String) throws -> (indent: Int, name: String, value: Double?, classSelector: String?) {
    let indentCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty, !trimmed.hasPrefix("%%") else {
        throw TreemapParserError.invalidStatement(line)
    }

    var name: String = ""

    let sectionRegex = try! NSRegularExpression(pattern: "^(?:\"([^\"]*(?:\\\\.[^\"]*)*)\"|'([^']*(?:\\\\.[^']*)*)')")

    guard let match = sectionRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
        throw TreemapParserError.missingLabel(trimmed)
    }

    let nsString = trimmed as NSString
    if match.range(at: 1).location != NSNotFound {
        name = nsString.substring(with: match.range(at: 1))
    } else if match.range(at: 2).location != NSNotFound {
        name = nsString.substring(with: match.range(at: 2))
    }
    name = _unescapeQuotes(name)

    var remainder = nsString.substring(from: match.range.location + match.range.length)
        .trimmingCharacters(in: .whitespaces)

    if remainder.isEmpty {
        return (indent: indentCount, name: name, value: nil, classSelector: nil)
    }

    if remainder.hasPrefix(":::") {
        let selector = try _parseTreemapClassSelector(remainder, originalLine: line)
        return (indent: indentCount, name: name, value: nil, classSelector: selector)
    }

    guard let first = remainder.first, first == ":" || first == "," else {
        throw TreemapParserError.invalidStatement(trimmed)
    }
    remainder.removeFirst()
    remainder = remainder.trimmingCharacters(in: .whitespaces)

    let numberRegex = try! NSRegularExpression(pattern: "^([0-9][0-9,._]*)")
    guard let numMatch = numberRegex.firstMatch(in: remainder, range: NSRange(remainder.startIndex..., in: remainder)) else {
        throw TreemapParserError.invalidValue(name, remainder)
    }

    let rawValue = (remainder as NSString).substring(with: numMatch.range(at: 1))
    let cleaned = rawValue
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "_", with: "")
    guard let value = Double(cleaned), value.isFinite else {
        throw TreemapParserError.invalidValue(name, rawValue)
    }

    let afterValueIndex = remainder.index(remainder.startIndex, offsetBy: numMatch.range.location + numMatch.range.length)
    let afterValue = String(remainder[afterValueIndex...]).trimmingCharacters(in: .whitespaces)
    if afterValue.isEmpty {
        return (indent: indentCount, name: name, value: value, classSelector: nil)
    }
    if afterValue.hasPrefix(":::") {
        let selector = try _parseTreemapClassSelector(afterValue, originalLine: line)
        return (indent: indentCount, name: name, value: value, classSelector: selector)
    }
    throw TreemapParserError.invalidStatement(trimmed)
}

private func _parseTreemapClassSelector(_ text: String, originalLine: String) throws -> String {
    let selectorRegex = try! NSRegularExpression(pattern: "^:::([a-zA-Z_][a-zA-Z0-9_]*)\\s*$")
    guard let match = selectorRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
        throw TreemapParserError.invalidStatement(originalLine)
    }
    return (text as NSString).substring(with: match.range(at: 1))
}

private func _resolveTreemapClassStyles(_ nodes: [TreemapNode], classDefs: [TreemapClassDef]) -> [TreemapNode] {
    var styleMap: [String: [String]] = [:]
    var textStyleMap: [String: [String]] = [:]
    for classDef in classDefs {
        styleMap[classDef.className, default: []].append(contentsOf: classDef.styles)
        if !classDef.textStyles.isEmpty {
            textStyleMap[classDef.className, default: []].append(contentsOf: classDef.textStyles)
        }
    }

    func resolve(_ node: TreemapNode) -> TreemapNode {
        var styled = node
        if let selector = node.classSelector {
            if let styles = styleMap[selector], !styles.isEmpty {
                styled.cssCompiledStyles = styles
            }
            if let textStyles = textStyleMap[selector], !textStyles.isEmpty {
                styled.cssCompiledTextStyles = textStyles
            }
        }
        if let children = node.children {
            styled.children = children.map(resolve)
        }
        return styled
    }

    return nodes.map(resolve)
}

private func _unquoteTreemap(_ s: String) -> String {
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

func parseTreemapDiagramFromSource(_ source: String, frontmatter: DiagramFrontmatter?) throws -> TreemapDiagram {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseTreemapDiagram(rawLines, frontmatter: frontmatter)
}
