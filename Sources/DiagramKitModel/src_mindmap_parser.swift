import Foundation
import DiagramKitCommon

private let MAX_SECTIONS = 12

public func parseMindmap(_ rawLines: [String], frontmatter: DiagramFrontmatter?) throws -> (MindmapDiagram, [DiagramDiagnostic]) {
    var config = frontmatter?.perDiagram.mindmap.config ?? MindmapConfig()
    if let fmLayout = frontmatter?.shared.layout { config.layout = fmLayout }
    if let fmLook = frontmatter?.shared.look { config.look = fmLook }
    if let fmTheme = frontmatter?.shared.theme { config.theme = fmTheme }
    if let fmHtmlLabels = frontmatter?.shared.htmlLabels { config.htmlLabels = fmHtmlLabels }
    if let fmFontSize = frontmatter?.shared.fontSize { config.fontSize = fmFontSize }
    if let fmSecurityLevel = frontmatter?.shared.securityLevel { config.securityLevel = fmSecurityLevel }

    let theme = MindmapThemeConfig.default
    var accTitle: String?
    var accDescr: String?
    var diagramTitle: String?
    var foundHeader = false
    var baseLevel: Int?
    var nodes: [MindmapNode] = []
    var nodeIdCounter = 0
    var contentStarted = false

    var accDescrLines: [String] = []
    var inAccDescrMultiline = false

    var lineIndex = 0
    while lineIndex < rawLines.count {
        let line = rawLines[lineIndex]
        lineIndex += 1

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if line.allSatisfy({ $0 == " " || $0 == "\t" }) { continue }
        if trimmed.isEmpty { continue }
        if trimmed.hasPrefix("%%") && !inAccDescrMultiline { continue }

        if !foundHeader {
            if trimmed.lowercased().hasPrefix("mindmap") {
                foundHeader = true
                continue
            }
            continue
        }

        if !contentStarted {
            if trimmed == "accTitle:" || trimmed.hasPrefix("accTitle:") {
                accTitle = String(trimmed.dropFirst("accTitle:".count)).trimmingCharacters(in: .whitespaces)
                if accTitle!.isEmpty { accTitle = nil }
                continue
            }
            if trimmed == "accDescr:" || trimmed.hasPrefix("accDescr:") {
                accDescr = String(trimmed.dropFirst("accDescr:".count)).trimmingCharacters(in: .whitespaces)
                if accDescr!.isEmpty { accDescr = nil }
                if accDescr != nil { continue }
                inAccDescrMultiline = false
                continue
            }
            if inAccDescrMultiline {
                if trimmed.hasPrefix("}") {
                    inAccDescrMultiline = false
                    accDescr = accDescrLines.joined(separator: "\n")
                    contentStarted = true
                    continue
                }
                accDescrLines.append(line)
                continue
            }
            if trimmed.hasPrefix("accDescr {") {
                inAccDescrMultiline = true
                let afterBrace = String(trimmed.dropFirst("accDescr {".count)).trimmingCharacters(in: .whitespaces)
                if !afterBrace.isEmpty { accDescrLines.append(afterBrace) }
                continue
            }
            if trimmed.hasPrefix("title:") {
                diagramTitle = String(trimmed.dropFirst("title:".count)).trimmingCharacters(in: .whitespaces)
                if diagramTitle!.isEmpty { diagramTitle = nil }
                continue
            }
        }

        let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        if baseLevel == nil { baseLevel = indent }

        let level = max(0, indent - (baseLevel ?? 0))
        let content = line.dropFirst(indent)
        let contentStr = String(content)

        if contentStr.trimmingCharacters(in: .whitespaces).isEmpty { continue }

        if contentStr.trimmingCharacters(in: .whitespaces).hasPrefix("%%") { continue }

        var inlineCommentStripped = _stripInlineComment(contentStr)

        if inlineCommentStripped.hasPrefix(":::") && !inlineCommentStripped.hasPrefix("::icon") {
            if let lastNode = nodes.last {
                let classStr = String(inlineCommentStripped.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var updated = lastNode
                let sanitized = _sanitizeMindmapDecoration(classStr, config: config)
                updated.cssClass = sanitized.isEmpty ? nil : sanitized
                nodes[nodes.count - 1] = updated
            }
            continue
        }

        if inlineCommentStripped.hasPrefix("::icon") {
            if let lastNode = nodes.last {
                let afterIcon = String(inlineCommentStripped.dropFirst("::icon".count)).trimmingCharacters(in: .whitespaces)
                var iconStr = afterIcon
                if iconStr.hasPrefix("(") && iconStr.hasSuffix(")") {
                    iconStr = String(iconStr.dropFirst().dropLast())
                }
                var updated = lastNode
                let sanitized = _sanitizeMindmapDecoration(iconStr, config: config)
                updated.icon = sanitized.isEmpty ? nil : sanitized
                nodes[nodes.count - 1] = updated
            }
            continue
        }

        inlineCommentStripped = try _consumeMultilineNodeContent(
            startingWith: inlineCommentStripped,
            rawLines: rawLines,
            nextIndex: &lineIndex
        )
        let (nodeId, descr, nodeType) = try _parseNodeContent(inlineCommentStripped)
        let displayText = descr.isEmpty ? nodeId : descr
        let sanitizedNodeId = _sanitizeMindmapText(nodeId, config: config)
        let sanitizedDescr = _sanitizeMindmapText(displayText, config: config)

        let parentNode = _findParent(nodes: nodes, level: level)
        if nodes.isEmpty {
            let node = MindmapNode(
                id: nodeIdCounter,
                nodeId: sanitizedNodeId,
                level: 0,
                descr: sanitizedDescr,
                type: nodeType,
                width: config.maxNodeWidth,
                padding: _paddingForType(nodeType, config: config),
                isRoot: true
            )
            nodes.append(node)
        } else if parentNode != nil {
            let node = MindmapNode(
                id: nodeIdCounter,
                nodeId: sanitizedNodeId,
                level: level,
                descr: sanitizedDescr,
                type: nodeType,
                width: config.maxNodeWidth,
                padding: _paddingForType(nodeType, config: config),
                isRoot: false
            )
            nodes.append(node)
        } else {
            throw MindmapParserError.multipleRoots(nodeDescription: sanitizedDescr)
        }

        nodeIdCounter += 1
        contentStarted = true
    }

    guard !nodes.isEmpty else {
        throw MindmapParserError.emptyDocument
    }

    let tree = _buildTree(nodes: nodes)
    let rootWithSections = _assignSectionsTree(tree: tree)

    var diagram = MindmapDiagram(
        root: rootWithSections,
        nodes: nodes,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        config: config,
        theme: theme
    )

    if let root = diagram.root {
        var updatedNodes = diagram.nodes
        let flatUpdated = flattenMindmapNodes(root)
        for flatNode in flatUpdated {
            if let idx = updatedNodes.firstIndex(where: { $0.id == flatNode.id }) {
                updatedNodes[idx] = flatNode
            }
        }
        diagram.nodes = updatedNodes
    }

    return (diagram, [])
}

private func _stripInlineComment(_ line: String) -> String {
    var inQuote = false
    var quoteChar: Character?
    var chars: [Character] = []
    for ch in line {
        if inQuote {
            chars.append(ch)
            if ch == quoteChar { inQuote = false; quoteChar = nil }
            continue
        }
        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            chars.append(ch)
            continue
        }
        if ch == "%" && chars.count > 0 {
            let prev = chars[chars.count - 1]
            if prev == "%" {
                chars.removeLast()
                return String(chars).trimmingCharacters(in: .whitespaces)
            }
        }
        chars.append(ch)
    }
    return String(chars)
}

private struct _ParsedMindmapNodeContent {
    var nodeId: String
    var descr: String
    var type: MindmapNodeType
    var hasDelimitedShape: Bool
    var ended: Bool
}

private func _consumeMultilineNodeContent(
    startingWith content: String,
    rawLines: [String],
    nextIndex: inout Int
) throws -> String {
    var combined = content
    var parsed = try _parseNodeContentDetailed(combined)

    while parsed.hasDelimitedShape && !parsed.ended && nextIndex < rawLines.count {
        combined += "\n" + rawLines[nextIndex]
        nextIndex += 1
        parsed = try _parseNodeContentDetailed(combined)
    }

    return combined
}

private func _parseNodeContent(_ content: String) throws -> (nodeId: String, descr: String, type: MindmapNodeType) {
    let parsed = try _parseNodeContentDetailed(content)
    if parsed.hasDelimitedShape && !parsed.ended {
        throw MindmapParserError.invalidShapeSyntax("Missing closing delimiter in \(content)")
    }
    return (parsed.nodeId, parsed.descr, parsed.type)
}

private func _parseNodeContentDetailed(_ content: String) throws -> _ParsedMindmapNodeContent {
    let trimmed = content.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty {
        return _ParsedMindmapNodeContent(nodeId: "", descr: "", type: .default, hasDelimitedShape: false, ended: true)
    }

    let (openDelim, closeDelim, delimiterStart) = _findDelimiters(in: trimmed)

    if let open = openDelim, let close = closeDelim, let startIdx = delimiterStart {
        let beforeDelim = String(trimmed[..<startIdx]).trimmingCharacters(in: .whitespaces)
        let afterOpen = trimmed[startIdx...]
        let (descText, ended) = _extractQuotedContent(String(afterOpen), openDelim: open, closeDelim: close)

        let nodeType = _getType(open: open, close: close)
        let nodeId = beforeDelim.isEmpty ? descText : beforeDelim
        let descr = descText

        return _ParsedMindmapNodeContent(
            nodeId: nodeId,
            descr: descr,
            type: nodeType,
            hasDelimitedShape: true,
            ended: ended
        )
    }

    return _ParsedMindmapNodeContent(nodeId: trimmed, descr: trimmed, type: .default, hasDelimitedShape: false, ended: true)
}

private func _findDelimiters(in text: String) -> (open: String?, close: String?, startIndex: String.Index?) {
    var inQuote = false
    var quoteChar: Character?
    var inBacktick = false

    for idx in text.indices {
        let ch = text[idx]
        if inQuote {
            if ch == quoteChar { inQuote = false; quoteChar = nil }
            continue
        }
        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            continue
        }
        if ch == "`" {
            inBacktick = !inBacktick
            continue
        }
        if inBacktick { continue }

        if let nextIdx = text.index(idx, offsetBy: 1, limitedBy: text.index(before: text.endIndex)) {
            let next = text[nextIdx]

            if ch == "(" && next == "(" {
                return ("((", "))", idx)
            }
            if ch == ")" && next == ")" {
                return ("))", "((", idx)
            }
            if ch == "{" && next == "{" {
                return ("{{", "}}", idx)
            }
        }

        if ch == "[" { return ("[", "]", idx) }
        if ch == "(" { return ("(", ")", idx) }
        if ch == ")" { return (")", "(", idx) }
    }

    return (nil, nil, nil)
}

private func _extractQuotedContent(_ text: String, openDelim: String, closeDelim: String) -> (content: String, ended: Bool) {
    let withoutOpen = String(text.dropFirst(openDelim.count))
    var inQuote = false
    var quoteChar: Character?
    var inBacktick = false
    var depth = 1
    var content: [Character] = []

    for idx in withoutOpen.indices {
        let ch = withoutOpen[idx]
        if inQuote {
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            } else {
                content.append(ch)
            }
            continue
        }
        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            continue
        }
        if ch == "`" {
            inBacktick = !inBacktick
            content.append(ch)
            continue
        }
        if inBacktick {
            content.append(ch)
            continue
        }

        if let nextIdx = withoutOpen.index(idx, offsetBy: 1, limitedBy: withoutOpen.index(before: withoutOpen.endIndex)) {
            let next = withoutOpen[nextIdx]
            let pair = String([ch, next])
            if pair == openDelim { depth += 1 }
            else if pair == closeDelim {
                depth -= 1
                if depth == 0 { return (String(content), true) }
            }
            if depth == 0 { return (String(content), true) }
        }

        let singleChar = String(ch)
        if singleChar == closeDelim && openDelim.count == 1 && closeDelim.count == 1 {
            depth -= 1
            if depth == 0 { return (String(content), true) }
        }

        content.append(ch)
    }

    return (String(content), false)
}

private func _getType(open: String, close: String) -> MindmapNodeType {
    switch (open, close) {
    case ("[", "]"): return .rect
    case ("(", ")"): return .roundedRect
    case ("((", "))"): return .circle
    case ("))", "(("): return .bang
    case (")", "("): return .cloud
    case ("{{", "}}"): return .hexagon
    default: return .default
    }
}

private func _findParent(nodes: [MindmapNode], level: Int) -> MindmapNode? {
    for node in nodes.reversed() {
        if node.level < level {
            return node
        }
    }
    return nil
}

private func _buildTree(nodes: [MindmapNode]) -> MindmapNode? {
    guard let root = nodes.first else { return nil }
    var result = root
    var children: [MindmapNode] = []

    for node in nodes.dropFirst() {
        let parentId = _findParentIndex(nodes: nodes, for: node)
        if let pi = parentId {
            if pi == 0 {
                var n = node
                n.children = _collectChildren(nodes: nodes, parentId: node.id)
                children.append(n)
            }
        }
    }

    result.children = children.filter { c in
        _findParentIndex(nodes: nodes, for: c) == 0
    }.map { _attachChildren(nodes: nodes, node: $0) }

    return result
}

private func _findParentIndex(nodes: [MindmapNode], for node: MindmapNode) -> Int? {
    guard let nodeIdx = nodes.firstIndex(where: { $0.id == node.id }) else { return nil }
    for idx in stride(from: nodeIdx - 1, through: 0, by: -1) {
        let candidate = nodes[idx]
        if candidate.level < node.level {
            return idx
        }
    }
    return nil
}

private func _collectChildren(nodes: [MindmapNode], parentId: Int) -> [MindmapNode] {
    nodes.filter { n in
        let pi = _findParentIndex(nodes: nodes, for: n)
        return pi != nil && nodes[pi!].id == parentId
    }
}

private func _attachChildren(nodes: [MindmapNode], node: MindmapNode) -> MindmapNode {
    var n = node
    let children = _collectChildren(nodes: nodes, parentId: n.id)
    n.children = children.map { _attachChildren(nodes: nodes, node: $0) }
    return n
}

private func _paddingForType(_ type: MindmapNodeType, config: MindmapConfig) -> Double {
    switch type {
    case .rect, .roundedRect, .hexagon:
        return config.padding * 2
    case .circle:
        return 10
    default:
        return config.padding
    }
}

private func _sanitizeMindmapText(_ text: String, config: MindmapConfig) -> String {
    var result = text
    result = result.replacingOccurrences(
        of: "(?is)<script\\b[^>]*>.*?</script>",
        with: "",
        options: .regularExpression
    )
    result = result.replacingOccurrences(
        of: "(?is)<style\\b[^>]*>.*?</style>",
        with: "",
        options: .regularExpression
    )

    let brPlaceholder = "\u{0}BM_BR\u{0}"
    result = result.replacingOccurrences(
        of: "(?i)<br\\s*/?>",
        with: brPlaceholder,
        options: .regularExpression
    )

    if config.securityLevel?.lowercased() != "loose" {
        result = result
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "=", with: "&equals;")
    }

    return result.replacingOccurrences(of: brPlaceholder, with: "<br/>")
}

private func _sanitizeMindmapDecoration(_ text: String, config: MindmapConfig) -> String {
    let sanitized = _sanitizeMindmapText(text, config: config)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-:./"))
    let scalars = sanitized.unicodeScalars.filter { allowed.contains($0) }
    return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
}

private func _assignSectionsTree(tree: MindmapNode?) -> MindmapNode? {
    guard var node = tree else { return nil }

    if node.isRoot {
        node.section = nil
    }

    node.children = node.children.enumerated().map { idx, child -> MindmapNode in
        var c = child
        if node.isRoot {
            c.section = idx % (MAX_SECTIONS - 1)
            return _assignSectionsChild(node: c, parentSection: c.section)
        } else {
            return _assignSectionsChild(node: c, parentSection: node.section)
        }
    }

    return node
}

private func _assignSectionsChild(node: MindmapNode, parentSection: Int?) -> MindmapNode {
    var n = node
    n.section = parentSection
    n.children = n.children.map { _assignSectionsChild(node: $0, parentSection: parentSection) }
    return n
}

public func flattenMindmapNodes(_ root: MindmapNode) -> [MindmapNode] {
    var result: [MindmapNode] = [root]
    for child in root.children {
        result.append(contentsOf: flattenMindmapNodes(child))
    }
    return result
}

public func generateMindmapLayoutData(_ diagram: MindmapDiagram) -> (nodes: [PositionedMindmapNode], edges: [PositionedMindmapEdge]) {
    guard let root = diagram.root else { return ([], []) }

    let flatNodes = flattenMindmapNodes(root)
    var positionedNodes: [PositionedMindmapNode] = []
    var positionedEdges: [PositionedMindmapEdge] = []

    for node in flatNodes {
        let cssClass: String?
        if node.isRoot {
            cssClass = nil
        } else {
            var parts: [String] = []
            if let s = node.section {
                parts.append("section-\(s)")
            }
            if let c = node.cssClass { parts.append(c) }
            cssClass = parts.isEmpty ? nil : parts.joined(separator: " ")
        }

        let pn = PositionedMindmapNode(
            id: node.id,
            nodeId: node.nodeId,
            descr: node.descr,
            type: node.type,
            level: node.level,
            section: node.section,
            cssClass: cssClass,
            icon: node.icon,
            isRoot: node.isRoot,
            x: 0,
            y: 0,
            width: node.width,
            height: 0,
            shapeName: node.type.rendererShapeName
        )
        positionedNodes.append(pn)
    }

    if let r = diagram.root {
        positionedEdges = _generateEdges(node: r)
    }

    return (positionedNodes, positionedEdges)
}

private func _generateEdges(node: MindmapNode) -> [PositionedMindmapEdge] {
    var edges: [PositionedMindmapEdge] = []
    for child in node.children {
        let edge = PositionedMindmapEdge(
            id: "edge_\(node.id)_\(child.id)",
            parentId: node.id,
            childId: child.id,
            section: child.section,
            depth: node.level + 1
        )
        edges.append(edge)
        edges.append(contentsOf: _generateEdges(node: child))
    }
    return edges
}
