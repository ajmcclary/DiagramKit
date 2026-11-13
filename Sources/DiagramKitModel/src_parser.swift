// Ported from original/src/parser.ts
import Foundation
import DiagramKitCommon

private typealias ParsedDirection = original_src_types.Direction
private typealias ParsedNodeShape = original_src_types.NodeShape
private typealias ParsedEdgeStyle = original_src_types.EdgeStyle
private typealias ParsedArrowHeadType = original_src_types.ArrowHeadType
private typealias ParsedNode = original_src_types.MermaidNode
private typealias ParsedEdge = original_src_types.MermaidEdge
private typealias ParsedSubgraph = original_src_types.MermaidSubgraph
private typealias ParsedGraph = original_src_types.MermaidGraph

private func _setSubgraphDirection(_ stack: inout [ParsedSubgraph], _ direction: ParsedDirection) {
    var top = stack[stack.count - 1]
    top.direction = direction
    stack[stack.count - 1] = top
}

private func _appendSubgraphChild(_ stack: inout [ParsedSubgraph], _ child: ParsedSubgraph) {
    var top = stack[stack.count - 1]
    top.children.append(child)
    stack[stack.count - 1] = top
}

private func _trackNodeInSubgraph(_ stack: inout [ParsedSubgraph], _ nodeId: String) {
    var top = stack[stack.count - 1]
    if !top.nodeIds.contains(nodeId) {
        top.nodeIds.append(nodeId)
    }
    stack[stack.count - 1] = top
}

private struct _StateNodeMeta {
    var descriptions: [String] = []
    var stateClasses: [String] = []
    var stateTextStyles: [String] = []
    var note: original_src_types.ParsedStateNote? = nil
    var stateType: original_src_types.ParsedStateType? = nil
    var labelType: String = "markdown"
}

private enum _ParserEntryError: Error, LocalizedError, _RecoverableDiagramError {
    case emptyDiagram
    case invalidHeader(String)

    var errorDescription: String? {
        switch self {
        case .emptyDiagram:
            return "The diagram source is empty."
        case .invalidHeader(let header):
            return "Invalid diagram header. Expected a Mermaid diagram type, found '\(header)'."
        }
    }
}

private struct _WorkingGraph {
    /// Parse-tier warnings (an unclosed subgraph or composite state at the
    /// end of the source). Not part of the parsed graph.
    var diagnostics: [DiagramDiagnostic] = []
    var direction: ParsedDirection
    var rendererType: String? = nil
    var nodesById: [String: ParsedNode] = [:]
    var nodeOrder: [String] = []
    var edges: [ParsedEdge] = []
    var subgraphs: [ParsedSubgraph] = []
    var subgraphIds: Set<String> = []
    var classDefs: [String: [String: String]] = [:]
    var classAssignments: [String: [String]] = [:]
    var nodeStyles: [String: [String: String]] = [:]
    var linkStyles: [Int: [String: String]] = [:]
    var accTitle: String? = nil
    var accDescr: String? = nil
    var config: original_src_types.FlowchartConfig? = nil
    var nodeInteractions: [String: original_src_types.NodeInteraction] = [:]
    var edgeClassAssignments: [String: String] = [:]
    var defaultClassDef: [String: String]? = nil
    var edgeProperties: [String: original_src_types.NodeProperties] = [:]
    var stateNodeMeta: [String: _StateNodeMeta] = [:]
    var stateClassAssignments: [String: [String]] = [:]
    var nodeTextStyles: [String: [String]] = [:]
    var hideEmptyDescription: Bool = false
    var scaleWidth: Int? = nil
    var stateConfig: original_src_types.StateConfig = original_src_types.StateConfig()

    mutating func upsertNode(_ node: ParsedNode) {
        if nodesById[node.id] == nil {
            nodeOrder.append(node.id)
        }
        nodesById[node.id] = node
    }

    mutating func mergeNodeStyle(_ id: String, _ props: [String: String]) {
        var merged = nodeStyles[id] ?? [:]
        for (k, v) in props {
            merged[k] = v
        }
        nodeStyles[id] = merged
    }

    func toParsedGraph() -> ParsedGraph {
        var resolvedNodesById = nodesById
        for (id, meta) in stateNodeMeta {
            if var node = resolvedNodesById[id] {
                if !meta.descriptions.isEmpty {
                    node.descriptions = meta.descriptions
                    if meta.descriptions.count > 1 {
                        node.shape = .rectWithTitle
                        node.label = meta.descriptions[0]
                    } else {
                        node.label = meta.descriptions[0]
                    }
                }
                if let stateType = meta.stateType {
                    switch stateType {
                    case .choice:
                        node.shape = .choice
                        node.label = ""
                    case .fork:
                        node.shape = .fork
                        node.label = ""
                    case .join:
                        node.shape = .join
                        node.label = ""
                    case .divider: node.shape = .stateDivider
                    }
                }
                resolvedNodesById[id] = node
            }
        }
        let nodesInOrder: [(id: String, node: ParsedNode)] = nodeOrder.compactMap { id in
            guard let node = resolvedNodesById[id] else { return nil }
            return (id: id, node: node)
        }
        return ParsedGraph(
            direction: direction,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs,
            classDefs: classDefs,
            classAssignments: classAssignments,
            nodeStyles: nodeStyles,
            linkStyles: linkStyles,
            accTitle: accTitle,
            accDescr: accDescr,
            config: config,
            rendererType: rendererType,
            nodeInteractions: nodeInteractions,
            edgeClassAssignments: edgeClassAssignments,
            defaultClassDef: defaultClassDef,
            edgeProperties: edgeProperties,
            stateConfig: stateConfig
        )
    }
}

private struct _ConsumedNode {
    var id: String
    var remaining: String
}

private struct _ConsumedNodeGroup {
    var ids: [String]
    var remaining: String
}

private func _regex(_ pattern: String) -> NSRegularExpression {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        assertionFailure("Invalid regex pattern: \(pattern)")
        // swift-corelibs-foundation has no `NSRegularExpression()` no-arg
        // initializer — fall back to a guaranteed-valid never-match pattern.
        return try! NSRegularExpression(pattern: "(?!)")
    }
    return regex
}

/// Text-embedded label regex — matches "-- label -->", "-. label .->", "== label ==>" syntax.
/// Used as fallback when the edge tokenizer doesn't capture a label.
private let _textEmbeddedArrowRegex = _regex(#"^(<)?(--|-\.|==)\s+(.+?)\s+(-->|---|\.\->|-\.\-|==>|===)"#)
private let _bareNodeRegex = _regex(#"^((?:[\w\p{L}.]|-(?![>\-.]))+)"#)
private let _classShorthandRegex = _regex(#"^:::([\w][\w-]*)"#)
private let _clickRegex = _regex(#"^click\s+((?:[\w\p{L}.]|-(?![>\-.]))+)\s+(.+)$"#)

/// Label alternatives for a node shape. A label that starts with `"` runs to
/// the next `"`, so a quoted label may contain the shape's own closing
/// delimiter (`B["array[0]"]`, `C("Start (init)")`, `D{"{x}"}`), as in
/// upstream Mermaid. Without the quoted branch the lazy `(.+?)` stopped at
/// the first delimiter, truncating the label and dropping the rest of the
/// line. The unquoted branch is unchanged.
private let _quotedOrLazyLabel = #"("[^"]*"|.+?)"#
/// The slash shapes (`[/…/]`, `[\…\]`, `[/…\]`, `[\…/]`) are tried before the
/// plain rectangle, and a lazy label could run past the first `]` into the
/// next node on the line (`W[/para/] --> X[\alt\]` became one node). Their
/// unquoted label stops at `]`.
private let _quotedOrBracketFreeLabel = #"("[^"]*"|[^\]]+?)"#
private let _nodeIdPattern = #"^((?:[\w\p{L}.]|-(?![>\-.]))+)"#

private let _nodePatterns: [(regex: NSRegularExpression, shape: ParsedNodeShape)] = [
    (_regex(_nodeIdPattern + #"\(\(\("# + _quotedOrLazyLabel + #"\)\)\)"#), .doublecircle),
    (_regex(_nodeIdPattern + #"\(\["# + _quotedOrLazyLabel + #"\]\)"#), .stadium),
    (_regex(_nodeIdPattern + #"\(\("# + _quotedOrLazyLabel + #"\)\)"#), .circle),
    (_regex(#"^((?:[\w\p{L}.]|-(?![>\-.]))+)\(-([^-]*?)-\)"#), .ellipse),
    (_regex(_nodeIdPattern + #"\[\["# + _quotedOrLazyLabel + #"\]\]"#), .subroutine),
    (_regex(_nodeIdPattern + #"\[\("# + _quotedOrLazyLabel + #"\)\]"#), .cylinder),
    (_regex(_nodeIdPattern + #"\[\/"# + _quotedOrBracketFreeLabel + #"\\\]"#), .trapezoid),
    (_regex(_nodeIdPattern + #"\[\\"# + _quotedOrBracketFreeLabel + #"\/\]"#), .trapezoidAlt),
    (_regex(_nodeIdPattern + #"\[\/"# + _quotedOrBracketFreeLabel + #"\/\]"#), .parallelogram),
    (_regex(_nodeIdPattern + #"\[\\"# + _quotedOrBracketFreeLabel + #"\\\]"#), .parallelogramAlt),
    (_regex(_nodeIdPattern + #">"# + _quotedOrLazyLabel + #"\]"#), .asymmetric),
    (_regex(_nodeIdPattern + #"\{\{"# + _quotedOrLazyLabel + #"\}\}"#), .hexagon),
    (_regex(_nodeIdPattern + #"\["# + _quotedOrLazyLabel + #"\]"#), .rectangle),
    (_regex(_nodeIdPattern + #"\("# + _quotedOrLazyLabel + #"\)"#), .rounded),
    (_regex(_nodeIdPattern + #"\{"# + _quotedOrLazyLabel + #"\}"#), .diamond),
]

public func parseMermaid(_ text: String, config: original_src_types.FlowchartConfig? = nil, stateConfig: original_src_types.StateConfig? = nil) throws -> (DiagramDocument, [DiagramDiagnostic]) {
    try _parseMermaidEntry(text, config: config, stateConfig: stateConfig)
}

private func _parseMermaidEntry(_ text: String, config: original_src_types.FlowchartConfig? = nil, stateConfig: original_src_types.StateConfig? = nil) throws -> (DiagramDocument, [DiagramDiagnostic]) {
    let lines = _mermaidSourceLines(from: text)

    guard !lines.isEmpty else {
        throw _ParserEntryError.emptyDiagram
    }

    let header = lines[0]
    let parsed: ParsedGraph
    let diagramType: DiagramType
    var diagnostics: [DiagramDiagnostic] = []

    if _regexTest(#"^stateDiagram(-v2)?\s*$"#, header, caseInsensitive: true) {
        parsed = try _parseStateDiagram(_expandingSingleLineStateBodies(lines), stateConfig: stateConfig, diagnostics: &diagnostics)
        diagramType = .stateDiagram
    } else {
        parsed = try _parseFlowchart(_mermaidFlowchartSourceLines(from: text), config: config, diagnostics: &diagnostics)
        diagramType = .flowchart
    }

    let document = DiagramDocument(payload: diagramType == .stateDiagram ? .stateDiagram(parsed) : .flowchart(parsed))
    return (document, diagnostics)
}

/// `state Single { a --> b }` written on one line becomes the three lines
/// the composite parser expects (`state Single {`, `a --> b`, `}`); it used
/// to match nothing and was dropped.
private func _expandingSingleLineStateBodies(_ lines: [String]) -> [String] {
    var result: [String] = []
    for line in lines {
        if line.hasPrefix("state "), let (head, body) = _splitOneLineBody(line) {
            result.append(head + " {")
            result.append(body)
            result.append("}")
        } else {
            result.append(line)
        }
    }
    return result
}

/// Splits `head { body }` (one `{`, one `}` at the end, non-empty head and
/// body) into its trimmed head and body; `nil` for any other shape. A plain
/// scan: the regex it replaces (`^(state\s+[^{}]+?)\s*\{\s*([^{}]*?)\s*\}$`)
/// backtracked quadratically on long runs of spaces.
func _splitOneLineBody(_ line: String) -> (head: String, body: String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasSuffix("}"),
          let open = trimmed.firstIndex(of: "{") else { return nil }
    let close = trimmed.index(before: trimmed.endIndex)
    guard open < close else { return nil }
    let inner = trimmed[trimmed.index(after: open)..<close]
    guard !inner.contains("{"), !inner.contains("}") else { return nil }
    let head = trimmed[..<open].trimmingCharacters(in: .whitespaces)
    let body = inner.trimmingCharacters(in: .whitespaces)
    // The head is `keyword name…`: it must hold more than the keyword and
    // no brace of its own.
    guard !body.isEmpty, !head.contains("}"), head.contains(where: \.isWhitespace) else { return nil }
    return (head, body)
}

private func _parseFlowchart(
    _ lines: [String],
    config: original_src_types.FlowchartConfig? = nil,
    diagnostics: inout [DiagramDiagnostic]
) throws -> ParsedGraph {
    guard let header = lines.first else {
        throw _ParserEntryError.invalidHeader("")
    }

    // Fetch renderer type and direction from header
    let rendererType: String?
    let direction: ParsedDirection

    if let match = _regexGroups(#"^(?:graph|flowchart|flowchart-elk)(?:\s+(TD|TB|LR|BT|RL|BR|<|>|\^|v))?\s*$"#, header, caseInsensitive: true) {
        rendererType = header.lowercased().hasPrefix("flowchart-elk") ? "elk" : nil
        if let dirToken = match[safe: 1] {
            direction = _parseDirection(dirToken) ?? .TB
        } else {
            direction = .TB  // Default: top-to-bottom
        }
    } else {
        throw _ParserEntryError.invalidHeader(header)
    }

    var graph = _WorkingGraph(direction: direction, rendererType: rendererType, config: config)
    var subgraphStack: [ParsedSubgraph] = []

    if lines.count <= 1 {
        return graph.toParsedGraph()
    }

    // Pre-scan: collect all subgraph IDs so forward-referenced subgraphs aren't
    // mistaken for bare nodes during edge parsing.
    for line in lines.dropFirst() {
        if let subgraphMatch = _regexGroups(#"^subgraph\s+(.+)$"#, line),
           let restRaw = subgraphMatch[safe: 1]
        {
            let rest = restRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let bracketMatch = _regexGroups(#"^([\w-]+)\s*\[(.+)\]$"#, rest),
               let foundId = bracketMatch[safe: 1]
            {
                graph.subgraphIds.insert(foundId)
            } else {
                let id = rest
                    .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
                    .replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
                graph.subgraphIds.insert(id)
            }
        }
    }

    // Pre-scan: multiline accDescr joining + inline %% stripping
    var processedLines: [String] = []
    var idx = 1
    while idx < lines.count {
        var line = lines[idx]
        line = DiagramSourceNormalizer.strippingInlineComment(line)
        guard !line.isEmpty else { idx += 1; continue }

        if _regexTest(#"^accDescr\s*\{\s*$"#, line) {
            var descrLines: [String] = []
            idx += 1
            while idx < lines.count && !_regexTest(#"^\}\s*$"#, lines[idx]) {
                var nl = lines[idx]
                nl = DiagramSourceNormalizer.strippingInlineComment(nl)
                if !nl.isEmpty { descrLines.append(nl) }
                idx += 1
            }
            idx += 1 // skip "}"
            processedLines.append("accDescr: " + descrLines.joined(separator: "\n"))
            continue
        }

        processedLines.append(line)
        idx += 1
    }

    for line in processedLines {
        if let classDefMatch = _regexGroups(#"^classDef\s+([\w\s,]+)\s+(.+)$"#, line),
           let namesRaw = classDefMatch[safe: 1],
           let propsStr = classDefMatch[safe: 2]
        {
            let names = namesRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let props = _parseStyleProps(propsStr)
            for name in names where !name.isEmpty {
                if name == "default" {
                    graph.defaultClassDef = props
                } else {
                    graph.classDefs[name] = props
                }
            }
            continue
        }

        if let classAssignMatch = _regexGroups(#"^class\s+((?:[\w\p{L}.]|-(?![>\-.]))+(?:\s*,\s*(?:[\w\p{L}.]|-(?![>\-.]))+)*)\s+(\w+)$"#, line),
           let idsRaw = classAssignMatch[safe: 1],
           let className = classAssignMatch[safe: 2]
        {
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                let firstChar = String(id.prefix(1))
                if firstChar == "e", Int(id.dropFirst()) != nil {
                    graph.edgeClassAssignments[id] = className
                } else {
                    if graph.classAssignments[id]?.contains(className) != true {
                        graph.classAssignments[id, default: []].append(className)
                    }
                }
            }
            continue
        }

        if let styleMatch = _regexGroups(#"^style\s+([\w,-]+)\s+(.+)$"#, line),
           let idsRaw = styleMatch[safe: 1],
           let propsRaw = styleMatch[safe: 2]
        {
            let props = _parseStyleProps(propsRaw)
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                graph.mergeNodeStyle(id, props)
            }
            continue
        }

        // --- linkStyle: `linkStyle 0 stroke:#f00` or `linkStyle default stroke:#f00` ---
        // Also supports: `linkStyle 0 interpolate basis`
        if let lsMatch = _regexGroups(#"^linkStyle\s+(default|[\d,\s]+)\s+(.+)$"#, line),
           let target = lsMatch[safe: 1],
           let propsRaw = lsMatch[safe: 2]
        {
            let targetTrimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check for interpolate syntax: `linkStyle 0 interpolate basis`
            if let interpMatch = _regexGroups(#"^interpolate\s+(\S+)\s*$"#, propsRaw),
               let curveType = interpMatch[safe: 1]
            {
                if targetTrimmed == "default" {
                    var merged = graph.linkStyles[-1] ?? [:]
                    merged["curve"] = curveType
                    graph.linkStyles[-1] = merged
                } else {
                    for part in targetTrimmed.split(separator: ",") {
                        if let idx = Int(part.trimmingCharacters(in: .whitespaces)) {
                            var merged = graph.linkStyles[idx] ?? [:]
                            merged["curve"] = curveType
                            graph.linkStyles[idx] = merged
                        }
                    }
                }
                continue
            }

            // Standard style props
            let props = _parseStyleProps(propsRaw)
            if targetTrimmed == "default" {
                var merged = graph.linkStyles[-1] ?? [:]
                for (k, v) in props { merged[k] = v }
                graph.linkStyles[-1] = merged
            } else {
                for part in targetTrimmed.split(separator: ",") {
                    if let idx = Int(part.trimmingCharacters(in: .whitespaces)) {
                        var merged = graph.linkStyles[idx] ?? [:]
                        for (k, v) in props { merged[k] = v }
                        graph.linkStyles[idx] = merged
                    }
                }
            }
            continue
        }

        // --- click: `click nodeId callback`, `click nodeId href "url"`, etc. ---
        if let clickMatch = _regexMatch(_clickRegex, line),
           let nodeIdRaw = clickMatch[safe: 1],
           let restRaw = clickMatch[safe: 2]
        {
            let nodeId = nodeIdRaw.trimmingCharacters(in: .whitespaces)
            let rest = restRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let interaction = _parseClickRest(rest) {
                graph.nodeInteractions[nodeId] = interaction
            }
            continue
        }

        // --- accTitle / accDescr directives ---
        if let accTitleMatch = _regexGroups(#"^accTitle\s*:\s*(.+)$"#, line),
           let title = accTitleMatch[safe: 1]
        {
            graph.accTitle = title.trimmingCharacters(in: .whitespaces)
            continue
        }
        if let accDescrMatch = _regexGroups(#"^accDescr\s*:\s*(.+)$"#, line),
           let descr = accDescrMatch[safe: 1]
        {
            graph.accDescr = descr.trimmingCharacters(in: .whitespaces)
            continue
        }

        if let dirMatch = _regexGroups(#"^direction\s+(TD|TB|LR|BT|RL|<|>|\^|v)\s*$"#, line, caseInsensitive: true),
           let dirToken = dirMatch[safe: 1],
           let dir = _parseDirection(dirToken),
           !subgraphStack.isEmpty
        {
            _setSubgraphDirection(&subgraphStack, dir)
            continue
        }

        if let subgraphMatch = _regexGroups(#"^subgraph\s+(.+)$"#, line),
           let restRaw = subgraphMatch[safe: 1]
        {
            let rest = restRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let id: String
            let label: String

            if let bracketMatch = _regexGroups(#"^([\w-]+)\s*\[(.+)\]$"#, rest),
               let foundId = bracketMatch[safe: 1],
               let foundLabel = bracketMatch[safe: 2]
            {
                id = foundId
                label = original_src_multiline_utils.normalizeBrTags(foundLabel)
            } else {
                label = original_src_multiline_utils.normalizeBrTags(rest)
                id = rest
                    .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
                    .replacingOccurrences(of: #"[^\w]"#, with: "", options: .regularExpression)
            }

            graph.subgraphIds.insert(id)
            subgraphStack.append(ParsedSubgraph(id: id, label: label, nodeIds: [], children: [], direction: nil))
            continue
        }

        // Anonymous subgraph (bare "subgraph" keyword). Collision guard:
        // a user-defined subgraph already named `subgraph_0` would
        // otherwise be silently shadowed; bump the index until unique.
        if line.trimmingCharacters(in: .whitespaces) == "subgraph" {
            var index = graph.subgraphIds.count
            var autoId = "subgraph_\(index)"
            while graph.subgraphIds.contains(autoId) {
                index += 1
                autoId = "subgraph_\(index)"
            }
            graph.subgraphIds.insert(autoId)
            subgraphStack.append(ParsedSubgraph(id: autoId, label: "", nodeIds: [], children: [], direction: nil))
            continue
        }

        if line == "end" {
            let completed = subgraphStack.popLast()
            if let completed {
                if !subgraphStack.isEmpty {
                    _appendSubgraphChild(&subgraphStack, completed)
                } else {
                    graph.subgraphs.append(completed)
                }
            }
            continue
        }

        // Standalone edge metadata: e1@{ animate: true, curve: basis }
        if let mdMatch = _regexGroups(#"^(e\d+)@\{(.+)$"#, line),
           let edgeId = mdMatch[safe: 1],
           let rest = mdMatch[safe: 2],
           let (props, _) = _parseMetadataBlock("@{" + rest)
        {
            graph.edgeProperties[edgeId] = props
            continue
        }

        _parseEdgeLine(line, graph: &graph, subgraphStack: &subgraphStack)
    }

    // A `subgraph` still open at the end of the source used to vanish with
    // no trace. Close it there, keep its contents, and say so.
    while let open = subgraphStack.popLast() {
        diagnostics.append(.lossyTransform(
            .subgraphFlatten,
            message: "[Flowchart] subgraph \"\(open.id)\" has no matching end; closed at the end of the diagram",
            location: nil
        ))
        if !subgraphStack.isEmpty {
            _appendSubgraphChild(&subgraphStack, open)
        } else {
            graph.subgraphs.append(open)
        }
    }

    return graph.toParsedGraph()
}

private func _parseStateDiagram(
    _ lines: [String],
    stateConfig: original_src_types.StateConfig? = nil,
    diagnostics: inout [DiagramDiagnostic]
) throws -> ParsedGraph {
    var graph = _WorkingGraph(direction: .TD)
    if let sc = stateConfig { graph.stateConfig = sc }

    var compositeStack: [ParsedSubgraph] = []
    var compositeStateIds = Set<String>()
    var startCount = 0
    var endCount = 0
    var dividerCount = 0

    // Build regex patterns with embedded state ID character class
    let SID = #"[^\n\s\-\{\}\:\-\-\>]+"#
    // Id-list patterns (`class a,b,c x`, `style a,b fill:…`) must not let one
    // id match a comma: with SID matching `,` too, `a,b,c` splits 2^(n-1)
    // ways and a line whose tail fails to match backtracks through all of
    // them (26 ids took ~14 s). SIDL excludes `,` so the list is linear.
    let SIDL = #"[^\n\s\-\{\}\:\-\-\>,]+"#
    func sPat(_ tmpl: String) -> String {
        tmpl.replacingOccurrences(of: "{{SID}}", with: SID)
            .replacingOccurrences(of: "{{SIDL}}", with: SIDL)
    }

    // Statement keywords that cannot stand alone as a state id. Matched
    // case-sensitively: `End`, `Left` and `Start` are ordinary state names
    // (`Start --> End` is about the most common state diagram there is).
    // Transitions never consult this filter; the `-->` already makes both
    // operands state ids.
    func isStateKeyword(_ s: String) -> Bool {
        let keywords: Set<String> = ["state", "note", "class", "classDef", "style", "click", "direction", "hide", "scale", "end", "left", "right", "of", "href"]
        return keywords.contains(s)
    }
    func isValidStateID(_ s: String) -> Bool {
        !s.isEmpty && !isStateKeyword(s)
    }

    if lines.count <= 1 {
        return graph.toParsedGraph()
    }

    // Pre-scan: multiline note/accDescr joining + inline %% stripping
    var preprocessed: [String] = []
    var i = 1
    while i < lines.count {
        var line = lines[i]
        // `%%` in description text after `:` is text (owner ruling on
        // pkg-diagram-parsers-20: match upstream).
        line = DiagramSourceNormalizer.strippingInlineComment(line, keepingTextAfterColon: true)
        guard !line.isEmpty else { i += 1; continue }

        // multiline note: "note left/right of <id>" followed by lines until "end note"
        if let noteMatch = _regexGroups(sPat("^note\\s+(left|right)\\s+of\\s+{{SID}}$"), line),
           noteMatch[safe: 1] != nil {
            var noteLines: [String] = [line]
            i += 1
            while i < lines.count && !_regexTest(#"^\s*end\s+note\s*$"#, lines[i], caseInsensitive: true) {
                var nl = lines[i]
                nl = DiagramSourceNormalizer.strippingInlineComment(nl)
                if !nl.isEmpty { noteLines.append(nl) }
                i += 1
            }
            i += 1 // skip "end note"
            preprocessed.append(noteLines.joined(separator: "\n"))
            continue
        }

        // multiline accDescr
        if _regexTest(#"^accDescr\s*\{\s*$"#, line) {
            var descrLines: [String] = []
            i += 1
            while i < lines.count && !_regexTest(#"^\}\s*$"#, lines[i]) {
                var nl = lines[i]
                nl = DiagramSourceNormalizer.strippingInlineComment(nl)
                if !nl.isEmpty { descrLines.append(nl) }
                i += 1
            }
            i += 1 // skip "}"
            preprocessed.append("accDescr: " + descrLines.joined(separator: " "))
            continue
        }

        preprocessed.append(line)
        i += 1
    }

    for line in preprocessed {
        // --- direction ---
        if let dm = _regexGroups(#"^direction\s+(TD|TB|LR|BT|RL)\s*$"#, line, caseInsensitive: true),
           let dirToken = dm[safe: 1], let direction = _parseDirection(dirToken) {
            if !compositeStack.isEmpty {
                _setSubgraphDirection(&compositeStack, direction)
            } else {
                graph.direction = direction
            }
            continue
        }

        // --- linkStyle ---
        if let ls = _regexGroups(#"^linkStyle\s+(default|[\d,\s]+)\s+(.+)$"#, line),
           let target = ls[safe: 1], let propsRaw = ls[safe: 2] {
            let props = _parseStyleProps(propsRaw)
            if target.trimmingCharacters(in: .whitespacesAndNewlines) == "default" {
                var merged = graph.linkStyles[-1] ?? [:]
                for (k, v) in props { merged[k] = v }
                graph.linkStyles[-1] = merged
            } else {
                let indices = target.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                for idx in indices {
                    var merged = graph.linkStyles[idx] ?? [:]
                    for (k, v) in props { merged[k] = v }
                    graph.linkStyles[idx] = merged
                }
            }
            continue
        }

        // --- scale ---
        if let sm = _regexGroups(#"^scale\s+(\d+)\s*(width)?$"#, line),
           let sv = sm[safe: 1], let w = Int(sv) { graph.scaleWidth = w; graph.stateConfig.scaleWidth = w; continue }

        // --- hide empty description ---
        if _regexTest(#"^hide\s+empty\s+description$"#, line) {
            graph.hideEmptyDescription = true
            graph.stateConfig.hideEmptyDescription = true
            continue
        }

        // --- accTitle ---
        if let am = _regexGroups(#"^accTitle\s*:\s*(.+)$"#, line),
           let title = am[safe: 1]?.trimmingCharacters(in: .whitespaces) { graph.accTitle = title; continue }

        // --- accDescr ---
        if let ad = _regexGroups(#"^accDescr\s*:\s*(.+)$"#, line),
           let descr = ad[safe: 1]?.trimmingCharacters(in: .whitespaces) { graph.accDescr = descr; continue }

        // --- click ---
        if let cm = _regexGroups(sPat("^click\\s+({{SID}})\\s+(.+)$"), line),
           let idRaw = cm[safe: 1], isValidStateID(idRaw) {
            if let interaction = _parseClickRest(cm[safe: 2] ?? "") {
                graph.nodeInteractions[idRaw] = interaction
            }
            continue
        }

        // --- classDef ---
        if let cdm = _regexGroups(#"^classDef\s+(default|\w+)\s+(.+)$"#, line),
           let name = cdm[safe: 1], let propsStr = cdm[safe: 2] {
            let props = _parseStyleProps(propsStr)
            if name == "default" { graph.defaultClassDef = props }
            else { graph.classDefs[name] = props }
            continue
        }

        // --- class ---
        if let clm = _regexGroups(sPat("^class\\s+({{SIDL}}(?:\\s*,\\s*{{SIDL}})*)\\s+(\\w+)$"), line),
           let idsRaw = clm[safe: 1], let className = clm[safe: 2] {
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                if let firstChar = id.first, firstChar == "e", Int(id.dropFirst()) != nil {
                    graph.edgeClassAssignments[id] = className
                } else {
                    if graph.classAssignments[id]?.contains(className) != true {
                        graph.classAssignments[id, default: []].append(className)
                    }
                }
            }
            continue
        }

        // --- style ---
        if let stm = _regexGroups(sPat("^style\\s+({{SIDL}}(?:\\s*,\\s*{{SIDL}})*)\\s+(.+)$"), line),
           let idsRaw = stm[safe: 1], let propsRaw = stm[safe: 2] {
            let props = _parseStyleProps(propsRaw)
            for id in idsRaw.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !id.isEmpty {
                graph.mergeNodeStyle(id, props)
            }
            continue
        }

        // --- composite state open ---
        if let comp = _regexGroups(sPat(#"^state\s+(?:\"([^\"]+)\"\s+as\s+)?({{SID}})\s*\{$"#), line),
           let id = comp[safe: 2], isValidStateID(id) {
            let label = comp[safe: 1]?.isEmpty == false ? comp[safe: 1]! : id
            let isAlt = (compositeStack.count % 2) == 1
            compositeStack.append(ParsedSubgraph(id: id, label: label, nodeIds: [], children: [], direction: nil, shape: .roundedWithTitle, altBkg: isAlt))
            compositeStateIds.insert(id)
            graph.nodesById.removeValue(forKey: id)
            graph.nodeOrder.removeAll { $0 == id }
            continue
        }

        // --- composite state close ---
        if line == "}" {
            if let completed = compositeStack.popLast() {
                let processed = _splitConcurrentRegions(completed, &graph)
                if !compositeStack.isEmpty {
                    _appendSubgraphChild(&compositeStack, processed)
                } else {
                    graph.subgraphs.append(processed)
                }
            }
            continue
        }

        // --- concurrency divider ---
        if _regexTest(#"^--$"#, line), !compositeStack.isEmpty {
            dividerCount += 1
            let dividerId = "_divider_\(dividerCount)"
            var meta = graph.stateNodeMeta[dividerId] ?? _StateNodeMeta()
            meta.stateType = .divider
            graph.stateNodeMeta[dividerId] = meta
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: dividerId, label: "", shape: .stateDivider))
            continue
        }

        // --- state alias ---
        if let am2 = _regexGroups(sPat(#"^state\s+\"([^\"]+)\"\s+as\s+({{SID}})\s*$"#), line),
           let labelRaw = am2[safe: 1], let id = am2[safe: 2], isValidStateID(id) {
            let label = original_src_multiline_utils.normalizeBrTags(labelRaw)
            // A later `state "…" as X` names a state that a transition
            // already created, as upstream's addState does; the first
            // mention used to win, so the label was ignored.
            if var existing = graph.nodesById[id] {
                existing.label = label
                graph.nodesById[id] = existing
            }
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: label, shape: .rounded))
            continue
        }

        // --- <<choice>> / <<fork>> / <<join>> ---
        if let pm = _regexGroups(sPat(#"^state\s+({{SID}})\s*<<(choice|fork|join)>>\s*$"#), line),
           let id = pm[safe: 1], isValidStateID(id), let typeName = pm[safe: 2] {
            let (st, sh): (original_src_types.ParsedStateType, ParsedNodeShape) = {
                switch typeName {
                case "choice": return (.choice, .choice)
                case "fork": return (.fork, .fork)
                case "join": return (.join, .join)
                default: return (.choice, .choice)
                }
            }()
            var meta = graph.stateNodeMeta[id] ?? _StateNodeMeta()
            meta.stateType = st
            graph.stateNodeMeta[id] = meta
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: id, shape: sh))
            continue
        }
        // Legacy bracket pseudo-node syntax: `state id [[choice]]`
        if let pm = _regexGroups(sPat(#"^state\s+({{SID}})\s*\[\[(choice|fork|join)\]\]\s*$"#), line),
           let id = pm[safe: 1], isValidStateID(id), let typeName = pm[safe: 2] {
            let (st, sh): (original_src_types.ParsedStateType, ParsedNodeShape) = {
                switch typeName {
                case "choice": return (.choice, .choice)
                case "fork": return (.fork, .fork)
                case "join": return (.join, .join)
                default: return (.choice, .choice)
                }
            }()
            var meta = graph.stateNodeMeta[id] ?? _StateNodeMeta()
            meta.stateType = st
            graph.stateNodeMeta[id] = meta
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: id, shape: sh))
            continue
        }

        // --- note (single-line or multiline-joined) ---
        if let nm = _regexGroups(sPat(#"^note\s+(left|right)\s+of\s+({{SID}})\s*:\s*(.+)$"#), line),
           let pos = nm[safe: 1], let targetId = nm[safe: 2], let noteText = nm[safe: 3] {
            _addStateNote(&graph, compositeStack: &compositeStack, targetId: targetId, position: pos, text: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
            continue
        }
        // multiline note body already joined in pre-pass; match the joined form
        if let nm2 = _regexGroups(sPat(#"^note\s+(left|right)\s+of\s+({{SID}})\n([\s\S]+)$"#), line),
           let pos = nm2[safe: 1], let targetId = nm2[safe: 2], let noteText = nm2[safe: 3] {
            _addStateNote(&graph, compositeStack: &compositeStack, targetId: targetId, position: pos, text: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
            continue
        }

        // --- floating note ---
        if let fn = _regexGroups(sPat(#"^note\s+\"([^\"]+)\"\s+as\s+({{SID}})\s*$"#), line),
           let noteText = fn[safe: 1], let noteId = fn[safe: 2], isValidStateID(noteId) {
            _registerStateNode(&graph, &compositeStack, ParsedNode(id: noteId, label: noteText, shape: .stateNote))
            continue
        }

        // --- transitions with optional ::: ---
        if let tm = _regexGroups(sPat(#"^(\[\*\]|{{SID}})(?::::(\w+))?\s*(-->)\s*(\[\*\]|{{SID}})(?::::(\w+))?(?:\s*:\s*(.+))?$"#), line),
           let sourceRaw = tm[safe: 1], let targetRaw = tm[safe: 4] {
            let sourceClass = tm[safe: 2]
            let targetClass = tm[safe: 5]

            var sourceId = sourceRaw
            var targetId = targetRaw
            let rawLabel = tm[safe: 6]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let edgeLabel = (rawLabel?.isEmpty == false) ? original_src_multiline_utils.normalizeBrTags(rawLabel!) : nil

            let parentID = compositeStack.last?.id ?? "root"
            if sourceId == "[*]" {
                startCount += 1
                sourceId = "\(parentID)_start"
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: sourceId, label: "", shape: .stateStart))
            } else if !compositeStateIds.contains(sourceId), !sourceId.isEmpty {
                _ensureStateNode(&graph, &compositeStack, sourceId)
            }
            if targetId == "[*]" {
                endCount += 1
                targetId = "\(parentID)_end"
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: targetId, label: "", shape: .stateEnd))
            } else if !compositeStateIds.contains(targetId), !targetId.isEmpty {
                _ensureStateNode(&graph, &compositeStack, targetId)
            }

            if let sc = sourceClass, !sc.isEmpty {
                if graph.classAssignments[sourceId]?.contains(sc) != true {
                    graph.classAssignments[sourceId, default: []].append(sc)
                }
            }
            if let tc = targetClass, !tc.isEmpty {
                if graph.classAssignments[targetId]?.contains(tc) != true {
                    graph.classAssignments[targetId, default: []].append(tc)
                }
            }

            graph.edges.append(ParsedEdge(
                source: sourceId, target: targetId, label: edgeLabel,
                style: .solid, arrowHeadStart: .none, arrowHeadEnd: .arrow
            ))
            continue
        }

        // --- description: id : label ---
        if let dm2 = _regexGroups(sPat(#"^({{SID}})\s*:\s*(.+)$"#), line),
           let id = dm2[safe: 1], isValidStateID(id), let labelRaw = dm2[safe: 2] {
            let label = original_src_multiline_utils.normalizeBrTags(labelRaw.trimmingCharacters(in: .whitespacesAndNewlines))
            var meta = graph.stateNodeMeta[id] ?? _StateNodeMeta()
            if meta.descriptions.isEmpty {
                meta.descriptions = [label]
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: label, shape: .rectangle))
            } else {
                meta.descriptions.append(label)
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: meta.descriptions[0], shape: .rectWithTitle))
            }
            graph.stateNodeMeta[id] = meta
            continue
        }

        // --- standalone state declaration ---
        if let sm2 = _regexGroups(sPat(#"^({{SID}})\s*$"#), line),
           let id = sm2[safe: 1], isValidStateID(id) { _ensureStateNode(&graph, &compositeStack, id); continue }

        // --- standalone: state <id> ---
        if let sim = _regexGroups(sPat(#"^state\s+({{SID}})\s*$"#), line),
           let id = sim[safe: 1], isValidStateID(id) { _ensureStateNode(&graph, &compositeStack, id); continue }

        // Nothing matched (for example a state id containing `-`, which
        // upstream rejects). The line used to be dropped silently.
        diagnostics.append(.featureDropped(
            .diagramFamilyUnsupported,
            message: "[State] statement not recognised and skipped: \(line.prefix(80))",
            location: nil
        ))
    }

    // A composite state still open at the end of the source used to vanish
    // with no trace. Close it there, keep its contents, and say so.
    while let open = compositeStack.popLast() {
        diagnostics.append(.lossyTransform(
            .subgraphFlatten,
            message: "[State] composite state \"\(open.id)\" has no closing }; closed at the end of the diagram",
            location: nil
        ))
        let processed = _splitConcurrentRegions(open, &graph)
        if !compositeStack.isEmpty {
            _appendSubgraphChild(&compositeStack, processed)
        } else {
            graph.subgraphs.append(processed)
        }
    }

    return graph.toParsedGraph()
}

private func _registerStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    let isNew = graph.nodesById[node.id] == nil
    if isNew {
        graph.upsertNode(node)
    }
    if !compositeStack.isEmpty {
        _trackNodeInSubgraph(&compositeStack, node.id)
    }
}

private func _ensureStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ id: String) {
    if graph.nodesById[id] == nil {
        _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: id, shape: .rounded))
    } else if !compositeStack.isEmpty {
        _trackNodeInSubgraph(&compositeStack, id)
    }
}

private func _splitConcurrentRegions(_ subgraph: ParsedSubgraph, _ graph: inout _WorkingGraph) -> ParsedSubgraph {
    let dividerIds = subgraph.nodeIds.filter { id in
        graph.stateNodeMeta[id]?.stateType == .divider
    }
    if dividerIds.isEmpty { return subgraph }

    for dividerId in dividerIds {
        graph.nodesById.removeValue(forKey: dividerId)
        graph.nodeOrder.removeAll { $0 == dividerId }
        graph.stateNodeMeta.removeValue(forKey: dividerId)
    }

    var regions: [[String]] = []
    var currentRegion: [String] = []
    for nodeId in subgraph.nodeIds {
        if dividerIds.contains(nodeId) {
            if !currentRegion.isEmpty {
                regions.append(currentRegion)
                currentRegion = []
            }
            continue
        }
        currentRegion.append(nodeId)
    }
    if !currentRegion.isEmpty {
        regions.append(currentRegion)
    }
    if regions.count <= 1 {
        var result = subgraph
        result.nodeIds = regions.first ?? []
        return result
    }

    var regionSubgraphs: [ParsedSubgraph] = []
    for (i, regionNodeIds) in regions.enumerated() {
        let regionSub = ParsedSubgraph(
            id: "\(subgraph.id)_region_\(i)",
            label: "",
            nodeIds: regionNodeIds,
            children: [],
            direction: subgraph.direction,
            shape: nil,
            altBkg: false
        )
        regionSubgraphs.append(regionSub)
    }

    var result = subgraph
    result.nodeIds = []
    result.children = regionSubgraphs + subgraph.children
    return result
}

private func _addStateNote(_ graph: inout _WorkingGraph, compositeStack: inout [ParsedSubgraph], targetId: String, position: String, text: String) {
    let normalizedText = original_src_multiline_utils.normalizeBrTags(text)
    let posEnum: original_src_types.ParsedStateNote.Position = position.lowercased() == "right" ? .right : .left
    var meta = graph.stateNodeMeta[targetId] ?? _StateNodeMeta()
    meta.note = original_src_types.ParsedStateNote(position: posEnum, text: normalizedText)
    graph.stateNodeMeta[targetId] = meta

    // Ensure the target state exists (note may appear before state declaration)
    if graph.nodesById[targetId] == nil {
        _registerStateNode(&graph, &compositeStack, ParsedNode(id: targetId, label: targetId, shape: .rounded))
    } else if !compositeStack.isEmpty {
        // Ensure target is tracked in current composite if it exists
        _trackNodeInSubgraph(&compositeStack, targetId)
    }

    // Create note node and register in composite scope. Each note gets its
    // own node (upstream numbers them too): a second note on the same state
    // used to reuse the first one's node, so its text was lost and only the
    // first note's text was drawn, on both sides.
    var noteId = "\(targetId)----note"
    var noteNumber = 2
    while graph.nodesById[noteId] != nil {
        noteId = "\(targetId)----note-\(noteNumber)"
        noteNumber += 1
    }
    _registerStateNode(&graph, &compositeStack, ParsedNode(id: noteId, label: normalizedText, shape: .stateNote))

    // Create dotted note edge
    let edge: ParsedEdge
    if posEnum == .right {
        edge = ParsedEdge(source: targetId, target: noteId, label: nil, style: .dotted, arrowHeadStart: .none, arrowHeadEnd: .none)
    } else {
        edge = ParsedEdge(source: noteId, target: targetId, label: nil, style: .dotted, arrowHeadStart: .none, arrowHeadEnd: .none)
    }
    graph.edges.append(edge)
}

private func _parseStyleProps(_ propsStr: String) -> [String: String] {
    // Strip trailing semicolons
    let cleaned = propsStr.replacingOccurrences(of: #";[\s]*$"#, with: "", options: .regularExpression)
    // Handle escaped commas: \, → placeholder, split, then restore
    let escaped = cleaned.replacingOccurrences(of: #"\\,"#, with: "\u{0001}")
    var props: [String: String] = [:]
    for pair in escaped.split(separator: ",", omittingEmptySubsequences: false) {
        let restored = String(pair).replacingOccurrences(of: "\u{0001}", with: ",")
        let item = restored.trimmingCharacters(in: .whitespaces)
        guard let idx = item.firstIndex(of: ":") else { continue }
        let key = item[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = item[item.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty, !value.isEmpty {
            props[key] = value
        }
    }
    return props
}

private typealias ParsedNodeInteraction = original_src_types.NodeInteraction

/// Every non-empty URL is kept in the model and written back as is; the
/// scheme check runs where a link is rendered (`_isSafeLinkURL`).
private func _validateURL(_ url: String) -> Bool {
    !url.trimmingCharacters(in: .whitespaces).isEmpty
}

private func _parseClickRest(_ rest: String) -> ParsedNodeInteraction? {
    // Mermaid click syntax variants:
    //   click A callback
    //   click A callback "tooltip"
    //   click A call callback()
    //   click A call callback() "tooltip"
    //   click A href "url"
    //   click A href "url" "tooltip"
    //   click A href "url" "tooltip" _blank
    //   click A href "url" _blank
    let r = rest.trimmingCharacters(in: .whitespaces)

    // call signature: call funcName() [ "tooltip" ]
    if r.hasPrefix("call ") {
        let afterCall = String(r.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if let callMatch = _regexGroups(#"^(\w+)\s*\(\s*\)\s*(?:"([^"]*)"\s*)?$"#, afterCall),
           let funcName = callMatch[safe: 1]
        {
            let tooltip = _emptyToNil(callMatch[safe: 2])
            return ParsedNodeInteraction(type: .call(funcName, ""), tooltip: tooltip)
        }
    }

    // href signature: href "url" [ "tooltip" ] [ _target ]
    if r.hasPrefix("href ") {
        let afterHref = String(r.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if let hrefMatch = _regexGroups(
            #"^"([^"]+)"\s*(?:"([^"]*)"\s*)?(?:\s*(_self|_blank|_parent|_top))?\s*$"#,
            afterHref
        ), let url = hrefMatch[safe: 1]
        {
            guard _validateURL(url) else { return nil }
            let tooltip = _emptyToNil(hrefMatch[safe: 2])
            let target = _emptyToNil(hrefMatch[safe: 3])
            return ParsedNodeInteraction(type: .href(url), tooltip: tooltip, target: target)
        }
    }

    // state diagram URL signature: "url" "tooltip"
    if let quotedUrlMatch = _regexGroups(
        #"^"([^"]+)"\s+"([^"]*)"\s*(?:\s*(_self|_blank|_parent|_top))?\s*$"#,
        r
    ), let url = quotedUrlMatch[safe: 1] {
        guard _validateURL(url) else { return nil }
        let tooltip = _emptyToNil(quotedUrlMatch[safe: 2])
        let target = _emptyToNil(quotedUrlMatch[safe: 3])
        return ParsedNodeInteraction(type: .href(url), tooltip: tooltip, target: target)
    }

    // bare callback: callbackName [ "tooltip" ]
    if let cbMatch = _regexGroups(#"^(\w+)\s*(?:"([^"]*)"\s*)?$"#, r),
       let name = cbMatch[safe: 1]
    {
        let tooltip = _emptyToNil(cbMatch[safe: 2])
        return ParsedNodeInteraction(type: .callback(name), tooltip: tooltip)
    }

    return nil
}

private func _emptyToNil(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}

private func _parseEdgeLine(_ line: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) {
    var remaining = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let firstGroup = _consumeNodeGroup(remaining, graph: &graph, subgraphStack: &subgraphStack), !firstGroup.ids.isEmpty else {
        return
    }

    remaining = firstGroup.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    var prevGroupIds = firstGroup.ids

    while !remaining.isEmpty {
        // Use the edge tokenizer to scan the edge operator
        guard let edgeOp = _scanEdgeOp(remaining) else { break }
        var edgeLabel = edgeOp.label
        let edgeId = edgeOp.edgeId
        var arrowHeadStart = edgeOp.arrowHeadStart
        var arrowHeadEnd = edgeOp.arrowHeadEnd
        var style = edgeOp.style
        // Extra length only; a normal-length edge is nil however it was
        // spelled (`-->` scans as 0, `-- text -->` as nil).
        let minlen = edgeOp.minlen.flatMap { $0 > 0 ? $0 : nil }
        var edgeProps: original_src_types.NodeProperties?

        remaining = String(remaining.dropFirst(edgeOp.consumedLength)).trimmingCharacters(in: .whitespacesAndNewlines)

        // Fallback: text-embedded label regex (if tokenizer didn't catch it)
        if edgeLabel == nil, let teMatch = _regexMatch(_textEmbeddedArrowRegex, remaining),
           let full = teMatch[safe: 0],
           let openOp = teMatch[safe: 2],
           let labelText = teMatch[safe: 3],
           let closeOp = teMatch[safe: 4]
        {
            arrowHeadStart = (teMatch[safe: 1] ?? "").isEmpty ? .none : .arrow
            let trimmedLabel = labelText.trimmingCharacters(in: .whitespacesAndNewlines)
            edgeLabel = trimmedLabel.isEmpty ? nil : original_src_multiline_utils.normalizeBrTags(trimmedLabel)
            remaining = String(remaining.dropFirst(full.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            style = _textArrowStyleFromOps(openOp, closeOp)
            arrowHeadEnd = closeOp.hasSuffix(">") ? .arrow : .none
        }

        // Check for inline edge metadata: @{ ... }
        if let (props, rem) = _parseMetadataBlock(remaining) {
            edgeProps = props
            remaining = rem.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Apply standalone edge metadata (from e1@{...} line) as fallback
        if edgeProps == nil, let eid = edgeId {
            edgeProps = graph.edgeProperties[eid]
        }

        guard let nextGroup = _consumeNodeGroup(remaining, graph: &graph, subgraphStack: &subgraphStack), !nextGroup.ids.isEmpty else {
            break
        }

        remaining = nextGroup.remaining.trimmingCharacters(in: .whitespacesAndNewlines)

        for sourceId in prevGroupIds {
            for targetId in nextGroup.ids {
                graph.edges.append(
                    ParsedEdge(
                        source: sourceId,
                        target: targetId,
                        label: edgeLabel,
                        style: style,
                        id: edgeId,
                        arrowHeadStart: arrowHeadStart,
                        arrowHeadEnd: arrowHeadEnd,
                        properties: edgeProps,
                        animate: edgeProps?.animate,
                        animationSpeed: edgeProps?.animation,
                        curve: edgeProps?.curve,
                        minlen: minlen
                    )
                )
            }
        }

        prevGroupIds = nextGroup.ids
    }
}

private func _consumeNodeGroup(_ text: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) -> _ConsumedNodeGroup? {
    guard let first = _consumeNode(text, graph: &graph, subgraphStack: &subgraphStack) else {
        return nil
    }

    var ids: [String] = [first.id]
    var remaining = first.remaining.trimmingCharacters(in: .whitespacesAndNewlines)

    while remaining.hasPrefix("&") {
        remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let next = _consumeNode(remaining, graph: &graph, subgraphStack: &subgraphStack) else {
            break
        }
        ids.append(next.id)
        remaining = next.remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return _ConsumedNodeGroup(ids: ids, remaining: remaining)
}

private func _consumeNode(_ text: String, graph: inout _WorkingGraph, subgraphStack: inout [ParsedSubgraph]) -> _ConsumedNode? {
    var id: String?
    var remaining = text

    for pattern in _nodePatterns {
        guard let match = _regexMatch(pattern.regex, text),
              let full = match[safe: 0],
              let matchedId = match[safe: 1],
              let rawLabel = match[safe: 2]
        else {
            continue
        }

        let label = original_src_multiline_utils.normalizeBrTags(rawLabel)
        _registerNode(&graph, &subgraphStack, ParsedNode(id: matchedId, label: label, shape: pattern.shape))
        id = matchedId
        remaining = String(text.dropFirst(full.count))
        break
    }

    if id == nil,
       let bare = _regexMatch(_bareNodeRegex, text),
       let full = bare[safe: 0],
       let bareId = bare[safe: 1]
    {
        id = bareId
        if graph.nodesById[bareId] == nil && !graph.subgraphIds.contains(bareId) {
            _registerNode(&graph, &subgraphStack, ParsedNode(id: bareId, label: bareId, shape: .rectangle))
        }
        remaining = String(text.dropFirst(full.count))
    }

    guard let nodeId = id else {
        return nil
    }

    // Check for inline @{ ... } metadata suffix
    if let (props, rem) = _parseMetadataBlock(remaining),
       var node = graph.nodesById[nodeId]
    {
        node.properties = props
        if let shapeStr = props.shape,
           let resolvedShape = original_src_types.NodeShape.resolve(alias: shapeStr) {
            node.shape = resolvedShape
        }
        graph.upsertNode(node)
        remaining = rem
    }

    if let classMatch = _regexMatch(_classShorthandRegex, remaining),
       let full = classMatch[safe: 0],
       let className = classMatch[safe: 1]
    {
        if graph.classAssignments[nodeId]?.contains(className) != true {
            graph.classAssignments[nodeId, default: []].append(className)
        }
        remaining = String(remaining.dropFirst(full.count))
    }

    return _ConsumedNode(id: nodeId, remaining: remaining)
}

/// Registers a node mention. Only the explicit form (`A[Start]`, `A((x))`)
/// reaches here for an existing node; bare mentions of a known id are not
/// re-registered. As upstream's `addVertex` does, a later explicit
/// declaration sets the label and shape even when the node was first
/// mentioned bare (`A --> B` then `A[Start]`); the first mention used to
/// win, and a canvas edit then wrote the bare form back over the user's
/// declaration. Other attributes (metadata, descriptions) are kept.
private func _registerNode(_ graph: inout _WorkingGraph, _ subgraphStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    if var existing = graph.nodesById[node.id] {
        existing.label = node.label
        existing.shape = node.shape
        graph.nodesById[node.id] = existing
    } else {
        graph.upsertNode(node)
    }
    _trackInSubgraph(&subgraphStack, node.id)
}

private func _trackInSubgraph(_ subgraphStack: inout [ParsedSubgraph], _ nodeId: String) {
    if !subgraphStack.isEmpty {
        _trackNodeInSubgraph(&subgraphStack, nodeId)
    }
}

private func _textArrowStyleFromOps(_ openOp: String, _ closeOp: String) -> ParsedEdgeStyle {
    if openOp == "-." || closeOp == ".->" || closeOp == "-.-" { return .dotted }
    if openOp == "==" || closeOp == "==>" || closeOp == "===" { return .thick }
    return .solid
}

private func _parseDirection(_ token: String) -> ParsedDirection? {
    switch token.uppercased() {
    case "TD", "TB", "V": return .TB
    case "BT", "^": return .BT
    case "LR", ">": return .LR
    case "RL", "<": return .RL
    // `BR` is treated as a `BT` synonym (Mermaid parity). The "Right" half
    // is not a direction in this enum, so we collapse onto Bottom-to-Top.
    case "BR": return .BT
    default: return ParsedDirection(rawValue: token.uppercased())
    }
}

private let _regexCache = _RegexCache()

// Concurrency Contract: flowchart/state-parser regex lookups go through a
// lock-guarded dictionary cache. `NSRegularExpression` instances are
// thread-safe once constructed, the lock makes get-or-insert atomic, and
// the key set is the parser's own fixed pattern vocabulary (no
// user-controllable unbounded growth). All parser entry points run on the
// 8 MB worker thread, but the cache is safe under arbitrary concurrency.
private final class _RegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(for pattern: String, options: NSRegularExpression.Options) -> NSRegularExpression? {
        let key = "\(pattern)\(options.rawValue)"
        lock.lock()
        if let cached = storage[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        lock.lock()
        storage[key] = regex
        lock.unlock()
        return regex
    }
}

private func _regexTest(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> Bool {
    _regexGroups(pattern, input, caseInsensitive: caseInsensitive) != nil
}

private func _regexGroups(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = _regexCache.regex(for: pattern, options: options),
          let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input))
    else {
        return nil
    }

    var groups: [String] = []
    for i in 0..<match.numberOfRanges {
        let nsRange = match.range(at: i)
        if nsRange.location == NSNotFound {
            groups.append("")
            continue
        }
        if let range = Range(nsRange, in: input) {
            groups.append(String(input[range]))
        } else {
            groups.append("")
        }
    }
    return groups
}

private func _regexMatch(_ regex: NSRegularExpression, _ input: String) -> [String]? {
    guard let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)) else {
        return nil
    }

    var groups: [String] = []
    for i in 0..<match.numberOfRanges {
        let nsRange = match.range(at: i)
        if nsRange.location == NSNotFound {
            groups.append("")
            continue
        }
        if let range = Range(nsRange, in: input) {
            groups.append(String(input[range]))
        } else {
            groups.append("")
        }
    }
    return groups
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

