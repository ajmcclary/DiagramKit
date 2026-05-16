import Foundation
import DiagramKitCommon

// MARK: - Block Diagram Parser

public enum BlockParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(String)
    case invalidStatement(String)
    case unterminatedComposite(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let header):
            return "Invalid Block Diagram header: \(header)"
        case .invalidStatement(let statement):
            return "Invalid Block Diagram statement: \(statement)"
        case .unterminatedComposite(let id):
            return "Missing end for Block Diagram composite block: \(id)"
        }
    }
}

public func parseBlockDiagramLines(_ lines: [String]) throws -> BlockDiagram {
    resetBlockIdCounter()
    guard let header = lines.first?.lowercased(), header == "block" || header == "block-beta" else {
        throw BlockParserError.invalidHeader(lines.first ?? "")
    }

    var rootChildren: [BlockNode] = []
    var edgeList: [BlockEdge] = []
    var edgeCount: [String: Int] = [:]
    var classDefs: [String: BlockClassDef] = [:]
    var currentCompositeStack: [BlockNode] = []
    var tempChildren: [String: BlockNode] = [:]
    var rootBlock_tmp = BlockNode(id: "root", type: .composite, children: [], columns: -1)

    let bodyLines = lines.dropFirst()

    func mergedBlock(existing: BlockNode, incoming: BlockNode) -> BlockNode {
        var merged = existing
        let isBareReference = incoming.type == .square && incoming.label == incoming.id && incoming.children.isEmpty

        if incoming.type != .na && !isBareReference {
            merged.type = incoming.type
        } else if existing.type == .na {
            merged.type = incoming.type
        }

        if !incoming.label.isEmpty && incoming.label != incoming.id {
            merged.label = incoming.label
        } else if merged.label.isEmpty {
            merged.label = incoming.label
        }

        if !incoming.children.isEmpty {
            merged.children = incoming.children
        }
        if let columns = incoming.columns {
            merged.columns = columns
        }
        if let width = incoming.widthInColumns {
            merged.widthInColumns = width
        }
        if let directions = incoming.directions {
            merged.directions = directions
        }
        if let classes = incoming.classes {
            var mergedClasses = merged.classes ?? []
            for cls in classes where !mergedClasses.contains(cls) {
                mergedClasses.append(cls)
            }
            merged.classes = mergedClasses
        }
        if let styles = incoming.styles {
            merged.styles = styles
        }
        if let styleClass = incoming.styleClass {
            merged.styleClass = styleClass
        }
        if let stylesStr = incoming.stylesStr {
            merged.stylesStr = stylesStr
        }
        if let size = incoming.size {
            merged.size = size
        }
        return merged
    }

    func store(_ child: BlockNode) {
        if let existing = tempChildren[child.id] {
            tempChildren[child.id] = mergedBlock(existing: existing, incoming: child)
        } else {
            tempChildren[child.id] = child
        }
    }

    func addToParent(child: BlockNode) {
        store(child)
        if let currentIdx = currentCompositeStack.indices.last {
            var parent = currentCompositeStack[currentIdx]
            if !parent.children.contains(child.id) {
                parent.children.append(child.id)
            }
            currentCompositeStack[currentIdx] = parent
            tempChildren[parent.id] = parent
        } else {
            if !rootChildren.contains(where: { $0.id == child.id }) {
                rootChildren.append(child)
            }
        }
    }

    func applyClass(_ className: String, to nodeIds: [String]) {
        for nid in nodeIds {
            let trimmed = nid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if var existing = tempChildren[trimmed] {
                var classes = existing.classes ?? []
                if !classes.contains(className) {
                    classes.append(className)
                }
                existing.classes = classes
                tempChildren[trimmed] = existing
            } else {
                addToParent(child: BlockNode(id: trimmed, type: .na, classes: [className]))
            }
        }
    }

    func applyStyles(_ styles: [String], to nodeIds: [String]) {
        for nid in nodeIds {
            let trimmed = nid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if var existing = tempChildren[trimmed] {
                existing.styles = styles
                tempChildren[trimmed] = existing
            } else {
                addToParent(child: BlockNode(id: trimmed, type: .na, styles: styles))
            }
        }
    }

    func parseNodeIds(_ tokens: ArraySlice<String>) -> [String] {
        tokens
            .flatMap { token in token.split(separator: ",", omittingEmptySubsequences: true).map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "," }
    }

    @discardableResult
    func parseEdgeChain(tokens: [String], startIndex: Int) -> Int {
        guard startIndex < tokens.count else { return startIndex + 1 }
        let (startNodeId, startType, startLabel, startSpan, startDirs) = parseNodeToken(tokens[startIndex])
        guard var currentId = startNodeId else { return startIndex + 1 }
        addToParent(child: BlockNode(
            id: currentId,
            label: startLabel ?? currentId,
            type: startType ?? .square,
            widthInColumns: startSpan,
            directions: startDirs
        ))

        var j = startIndex + 1
        while j < tokens.count, isEdgeTokenStr(tokens[j]) {
            var edgeToken = tokens[j]
            var edgeLabel: String?
            var nextNodeIndex = j + 1

            if nextNodeIndex < tokens.count, isEdgeLabelToken(tokens[nextNodeIndex]) {
                edgeLabel = String(tokens[nextNodeIndex].dropFirst().dropLast())
                if nextNodeIndex + 1 < tokens.count, isEdgeTokenStr(tokens[nextNodeIndex + 1]) {
                    edgeToken = tokens[nextNodeIndex + 1]
                    nextNodeIndex += 2
                } else {
                    break
                }
            }

            guard nextNodeIndex < tokens.count else { break }
            let (endId, endType, endLabel, endSpan, endDirs) = parseNodeToken(tokens[nextNodeIndex])
            guard let endId else { break }

            addToParent(child: BlockNode(
                id: endId,
                label: endLabel ?? endId,
                type: endType ?? .square,
                widthInColumns: endSpan,
                directions: endDirs
            ))

            let count = (edgeCount["\(currentId)-\(endId)"] ?? 0) + 1
            edgeCount["\(currentId)-\(endId)"] = count
            edgeList.append(BlockEdge(
                id: "\(count)-\(currentId)-\(endId)",
                start: currentId,
                end: endId,
                label: edgeLabel,
                thickness: edgeTypeStrToThickness(edgeToken),
                pattern: edgeStrToPattern(edgeToken),
                arrowTypeEnd: edgeStrToEdgeData(edgeToken),
                arrowTypeStart: edgeStrToEdgeStartData(edgeToken)
            ))

            currentId = endId
            j = nextNodeIndex + 1
        }
        return j
    }

    for line in bodyLines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        if trimmed.hasPrefix("%%") { continue }

        if trimmed == "end" {
            if !currentCompositeStack.isEmpty {
                let composite = currentCompositeStack.removeLast()
                tempChildren[composite.id] = composite
                if currentCompositeStack.isEmpty {
                    addToParent(child: composite)
                } else {
                    addToParent(child: composite)
                }
            }
            continue
        }

        let tokens = tokenizeLine(trimmed)

        if tokens.isEmpty { continue }

        if tokens.count >= 2 && tokens[0] == "classDef" {
            let defId = tokens[1]
            var styles: [String] = []
            var textStyles: [String] = []
            let rawStyles = tokens.dropFirst(2).joined(separator: " ")
            let parts = rawStyles.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for part in parts {
                if part.isEmpty { continue }
                let fixed = part.replacingOccurrences(of: ";", with: "").trimmingCharacters(in: .whitespaces)
                if part.contains("color") {
                    let newStyle1 = fixed.replacingOccurrences(of: "fill", with: "bgFill")
                    let newStyle2 = newStyle1.replacingOccurrences(of: "color", with: "fill")
                    textStyles.append(newStyle2)
                }
                styles.append(fixed)
            }
            classDefs[defId] = BlockClassDef(id: defId, styles: styles, textStyles: textStyles)
            continue
        }

        if tokens.count >= 3 && tokens[0] == "class" {
            let className = tokens.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let nodeIds = parseNodeIds(tokens.dropFirst().dropLast())
            if !nodeIds.isEmpty && !className.isEmpty {
                applyClass(className, to: nodeIds)
            }
            continue
        }

        if tokens.count >= 3 && tokens[0] == "style" {
            var nodeIds: [String] = []
            var stylesCollected: [String] = []
            var collectingStyles = false
            for t in tokens.dropFirst(1) {
                if t.contains(",") && !collectingStyles {
                    nodeIds.append(contentsOf: t.split(separator: ",").map { String($0) })
                } else if !collectingStyles && (t.contains(":") || t.contains("#") || t.contains(";")) {
                    collectingStyles = true
                    stylesCollected.append(t)
                } else if collectingStyles {
                    stylesCollected.append(t)
                } else {
                    nodeIds.append(t)
                }
            }
            applyStyles(stylesCollected, to: nodeIds)
            continue
        }

        var i = 0
        while i < tokens.count {
            let t = tokens[i]

            if t == "block" || t == "block-beta" || t.hasPrefix("block:") {
                var compositeId: String? = nil
                var compositeLabel: String? = nil
                var span: Int? = nil

                if t.hasPrefix("block:") {
                    let afterPrefix = String(t.dropFirst(6))
                    let (nid, _, lbl, sp, _) = parseNodeToken(afterPrefix)
                    compositeId = nid ?? afterPrefix
                    compositeLabel = lbl ?? compositeId
                    span = sp
                    i += 1
                } else {
                    i += 1
                    if i < tokens.count {
                        let (nid, _, lbl, sp, _) = parseNodeToken(tokens[i])
                        if let id = nid {
                            compositeId = id
                            compositeLabel = lbl ?? id
                            span = sp
                            i += 1
                        }
                    }
                }

                if i < tokens.count && tokens[i].hasPrefix(":") {
                    span = Int(String(tokens[i].dropFirst()))
                    i += 1
                }

                let id = compositeId ?? generateBlockId()
                let lbl = compositeLabel ?? ""
                let compNode = BlockNode(id: id, label: lbl, type: .composite, children: [], widthInColumns: span)
                store(compNode)
                currentCompositeStack.append(compNode)
                continue
            }

            if t == "columns" {
                i += 1
                var colVal = -1
                if i < tokens.count {
                    if let n = Int(tokens[i]) { colVal = n }
                    else if tokens[i].lowercased() == "auto" { colVal = -1 }
                    i += 1
                }
                if let current = currentCompositeStack.last {
                    var parent = current
                    parent.columns = colVal
                    currentCompositeStack[currentCompositeStack.count - 1] = parent
                    tempChildren[parent.id] = parent
                } else {
                    rootBlock_tmp.columns = colVal
                }
                continue
            }

            if t.hasPrefix("space") {
                var span = 1
                if t.contains(":") {
                    let parts = t.split(separator: ":")
                    // Reject non-positive spans at parse time. Downstream layout
                    // divides `size.width` by widthInColumns; 0 → NaN.
                    if parts.count == 2, let n = Int(parts[1]), n > 0 { span = n }
                }
                for j in 0..<span {
                    let spaceId = generateBlockId() + "-s\(j)"
                    let spaceNode = BlockNode(id: spaceId, type: .space, widthInColumns: 1)
                    tempChildren[spaceId] = spaceNode
                    addToParent(child: spaceNode)
                }
                i += 1
                continue
            }

            if i + 1 < tokens.count, isEdgeTokenStr(tokens[i + 1]) {
                i = parseEdgeChain(tokens: tokens, startIndex: i)
                continue
            }

            let (nodeId, shapeType, label, span, dirs) = parseNodeToken(t)
            if let nid = nodeId {
                let nt = shapeType ?? .square
                let node = BlockNode(id: nid, label: label ?? nid, type: nt, widthInColumns: span, directions: dirs)
                addToParent(child: node)
                i += 1
                continue
            }

            if isEdgeTokenStr(t) {
                var startId = ""
                var endId = ""
                var edgeLabel: String?

                for j in stride(from: i - 1, through: 0, by: -1) {
                    let prev = tokens[j]
                    if !isEdgeTokenStr(prev) && !isEdgeLabelToken(prev) && !prev.hasPrefix(":") {
                        let (nid, _, _, _, _) = parseNodeToken(prev)
                        if let id = nid { startId = id; break }
                    }
                }

                var j = i + 1
                var foundLabel = false
                while j < tokens.count {
                    let next = tokens[j]
                    if next.hasPrefix("\"") && next.hasSuffix("\"") && !foundLabel {
                        foundLabel = true
                        edgeLabel = String(next.dropFirst().dropLast())
                        j += 1
                        continue
                    }
                    if isEdgeTokenStr(next) && !foundLabel {
                        j += 1
                        continue
                    }
                    if !isEdgeTokenStr(next) && !isEdgeLabelToken(next) && !next.hasPrefix(":") {
                        let (nid, _, _, _, _) = parseNodeToken(next)
                        if let id = nid { endId = id; break }
                    }
                    j += 1
                }

                let thickness = edgeTypeStrToThickness(t)
                let pattern = edgeStrToPattern(t)
                let arrowEnd = edgeStrToEdgeData(t)
                let arrowStart = edgeStrToEdgeStartData(t)

                if !startId.isEmpty && !endId.isEmpty {
                    let count = (edgeCount["\(startId)-\(endId)"] ?? 0) + 1
                    edgeCount["\(startId)-\(endId)"] = count
                    let edge = BlockEdge(
                        id: "\(count)-\(startId)-\(endId)",
                        start: startId,
                        end: endId,
                        label: edgeLabel,
                        thickness: thickness,
                        pattern: pattern,
                        arrowTypeEnd: arrowEnd,
                        arrowTypeStart: arrowStart
                    )
                    edgeList.append(edge)
                }
                i += 1
                continue
            }

            i += 1
        }
    }

    if let unterminated = currentCompositeStack.last {
        throw BlockParserError.unterminatedComposite(unterminated.id)
    }

    var rootBlock = rootBlock_tmp
    rootBlock.children = rootChildren.map(\.id)
    var db: [String: BlockNode] = ["root": rootBlock]
    for child in rootChildren {
        populateBlockDB(childId: child.id, from: tempChildren, into: &db, edgeList: &edgeList, edgeCount: &edgeCount)
    }

    return BlockDiagram(
        rootChildren: rootChildren.map(\.id),
        blockDatabase: db,
        edges: edgeList,
        classes: classDefs,
        config: .default
    )
}

private func tokenizeLine(_ line: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    var inQuote = false
    var i = line.startIndex

    func flush() {
        let t = current.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { tokens.append(t) }
        current = ""
    }

    while i < line.endIndex {
        let ch = line[i]
        if ch == "\"" {
            inQuote.toggle()
            current.append(ch)
            i = line.index(after: i)
            continue
        }
        if inQuote {
            current.append(ch)
            i = line.index(after: i)
            continue
        }
        if ch.isWhitespace {
            flush()
            i = line.index(after: i)
            continue
        }
        if ch == "," {
            flush()
            tokens.append(",")
            i = line.index(after: i)
            continue
        }
        if ch == ":" && current.isEmpty {
            current.append(ch)
            i = line.index(after: i)
            while i < line.endIndex && (line[i].isNumber || line[i].isLetter) {
                current.append(line[i])
                i = line.index(after: i)
            }
            flush()
            continue
        }
        current.append(ch)
        i = line.index(after: i)
    }
    flush()
    return tokens
}

private func parseNodeToken(_ token: String) -> (id: String?, type: BlockNodeType?, label: String?, span: Int?, directions: [BlockDirection]?) {
    let t = token
    if isEdgeTokenStr(t) || t.hasPrefix("\"") || t == "block" || t == "block-beta" ||
       t == "columns" || t == "space" || t == "end" || t == "classDef" || t == "class" || t == "style" ||
       t == "," { return (nil, nil, nil, nil, nil) }

    if t.hasPrefix("arrow") {
        var label: String? = nil
        var dirs: [BlockDirection] = []
        var span: Int? = nil
        if let labelStart = t.range(of: "<[\""), let labelEnd = t.range(of: "\"]>") {
            let start = labelStart.upperBound
            let end = labelEnd.lowerBound
            label = String(t[start..<end])
        }
        if let dirStart = t.range(of: ">("), let dirEnd = t.range(of: ")", options: .backwards) {
            let start = dirStart.upperBound
            let end = dirEnd.lowerBound
            let dirStr = String(t[start..<end])
            for d in dirStr.split(separator: ",") {
                let ds = String(d).trimmingCharacters(in: .whitespaces)
                if let dir = BlockDirection(rawValue: ds.lowercased()) { dirs.append(dir) }
            }
        }
        if let lastColon = t.range(of: ":", options: .backwards) {
            let afterColon = t[lastColon.upperBound...]
            if let n = Int(String(afterColon)), n > 0 { span = n }
        }
        return (generateBlockId(), .blockArrow, label, span, dirs)
    }

    var id: String? = nil
    var span: Int? = nil
    var nodeType: BlockNodeType? = nil
    var label: String? = nil

    var mainPart = t
    if t.contains(":") {
        let parts = t.split(separator: ":", maxSplits: 1)
        // Reject non-positive spans at parse time. Downstream layout
        // divides `size.width` by widthInColumns; 0 → NaN.
        if parts.count == 2, let n = Int(parts[1]), n > 0 {
            span = n
            mainPart = String(parts[0])
        }
    }

    let shapes: [(open: String, close: String, type: BlockNodeType)] = [
        ("[[", "]]", .subroutine),
        ("(((", ")))", .doublecircle),
        ("{{\"", "}}", .hexagon),
        ("((", "))", .circle),
        ("([", "])", .stadium),
        ("[(", ")]", .cylinder),
        ("[/\"", "/]", .leanRight),
        ("[\\\"", "\\]", .leanLeft),
        ("[/\"", "\\]", .trapezoid),
        ("[\\\"", "/]", .invTrapezoid),
        ("[\"", "\"]", .square),
        ("(\"", "\")", .round),
        ("{\"", "}", .diamond),
        (">\"", "\"]", .rectLeftInvArrow),
    ]

    for (open, close, type) in shapes {
        if mainPart.contains(open) {
            let openRange = mainPart.range(of: open)
            let closeRange = mainPart.range(of: close, options: .backwards)
            if let oEnd = openRange?.upperBound, let cStart = closeRange?.lowerBound, oEnd <= cStart {
                id = String(mainPart[mainPart.startIndex..<(openRange!.lowerBound)]).trimmingCharacters(in: .whitespaces)
                label = String(mainPart[oEnd..<cStart]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                nodeType = type
                break
            }
        }
    }

    if id == nil && nodeType == nil {
        id = mainPart
        nodeType = .square
    }

    return (id, nodeType, label, span, nil)
}

private func isEdgeTokenStr(_ t: String) -> Bool {
    let edgePatterns: Set<String> = ["---", "-->", "<-->", "--o", "--x", "===", "==>", "<==>", "-.-", "-.->", "<-.>", "<-.-", "<.-", "--"]
    if edgePatterns.contains(t) { return true }
    if t.hasPrefix("-") || t.hasPrefix("=") || t.hasPrefix(".") { return true }
    return false
}

private func isEdgeLabelToken(_ t: String) -> Bool {
    t.hasPrefix("\"") && t.hasSuffix("\"")
}

private func populateBlockDB(
    childId: String,
    from tempChildren: [String: BlockNode],
    into db: inout [String: BlockNode],
    edgeList: inout [BlockEdge],
    edgeCount: inout [String: Int]
) {
    guard let block = tempChildren[childId] else { return }
    var node = block

    if node.label.isEmpty {
        if node.type == .composite {
            node.label = ""
        } else {
            node.label = node.id
        }
    }
    node.label = sanitizeBlockText(node.label)

    if let existing = db[node.id] {
        var merged = existing
        if node.type != .na { merged.type = node.type }
        if node.label != node.id { merged.label = node.label }
        if let classes = node.classes { merged.classes = classes }
        if let styles = node.styles { merged.styles = styles }
        merged.children = node.children
        db[node.id] = merged
    } else {
        db[node.id] = node
    }

    if node.type == .space {
        return
    }

    for cid in node.children {
        if let _ = tempChildren[cid] {
            populateBlockDB(childId: cid, from: tempChildren, into: &db, edgeList: &edgeList, edgeCount: &edgeCount)
        }
    }
}

public func parseBlockDiagram(_ source: String, frontmatter: DiagramFrontmatter? = nil) throws -> (BlockDiagram, [DiagramDiagnostic]) {
    let (processed, fm) = _parseFrontMatterAndStripped(source)
    let resolvedFM = frontmatter ?? fm
    let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
    var diagram = try parseBlockDiagramLines(lines)
    if let fmc = resolvedFM {
        diagram.diagramTitle = fmc.shared.title
        if let bc = fmc.perDiagram.block.config { diagram.config = bc }
    }
    return (diagram, [])
}
