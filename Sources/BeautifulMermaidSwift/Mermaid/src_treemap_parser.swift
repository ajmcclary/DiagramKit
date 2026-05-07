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

        if let (indent, name, value, classSelector) = _parseTreemapLine(line) {
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
    }

    return TreemapDiagram(
        nodes: root.children?.map { $0.toTreemapNode() } ?? [],
        classDefs: classDefs,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: TreemapDiagramConfig.default,
        themeName: frontmatter?.theme,
        themeVariables: frontmatter?.treemapThemeVariables
    )
}

private func _parseTreemapLine(_ line: String) -> (indent: Int, name: String, value: Double?, classSelector: String?)? {
    let indentCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty, !trimmed.hasPrefix("%%") else { return nil }

    var name: String = ""
    var value: Double? = nil
    var classSelector: String? = nil

    let sectionRegex = try! NSRegularExpression(pattern: "^(?:\"([^\"]*(?:\\\\.[^\"]*)*)\"|'([^']*(?:\\\\.[^']*)*)')")

    guard let match = sectionRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
        return nil
    }

    let nsString = trimmed as NSString
    if match.range(at: 1).location != NSNotFound {
        name = nsString.substring(with: match.range(at: 1))
    } else if match.range(at: 2).location != NSNotFound {
        name = nsString.substring(with: match.range(at: 2))
    }
    name = _unescapeQuotes(name)

    let afterLabel = nsString.substring(from: match.range.location + match.range.length)

    let classSuffix = try! NSRegularExpression(pattern: ":::([a-zA-Z_][a-zA-Z0-9_]*)")
    if let classMatch = classSuffix.firstMatch(in: afterLabel, range: NSRange(afterLabel.startIndex..., in: afterLabel)) {
        classSelector = (afterLabel as NSString).substring(with: classMatch.range(at: 1))
    }

    let separatorRegex = try! NSRegularExpression(pattern: "^\\s*[:,\\s]+\\s*")
    let numberRegex = try! NSRegularExpression(pattern: "^([0-9][0-9,._]*)")

    let remainder = classSelector != nil
        ? (afterLabel as NSString).replacingCharacters(in: (afterLabel as NSString).range(of: ":::" + classSelector!), with: "")
        : afterLabel

    if let sepMatch = separatorRegex.firstMatch(in: remainder, range: NSRange(remainder.startIndex..., in: remainder)) {
        let afterSep = String(remainder[remainder.index(remainder.startIndex, offsetBy: sepMatch.range.location + sepMatch.range.length)...])
        if let numMatch = numberRegex.firstMatch(in: afterSep, range: NSRange(afterSep.startIndex..., in: afterSep)) {
            let rawValue = (afterSep as NSString).substring(with: numMatch.range(at: 1))
            let cleaned = rawValue.replacingOccurrences(of: ",", with: "")
            value = Double(cleaned) ?? 0
        }
    }

    return (indent: indentCount, name: name, value: value, classSelector: classSelector)
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
