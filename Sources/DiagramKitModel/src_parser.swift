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

private struct _StateNodeMeta {
    var descriptions: [String] = []
    var stateClasses: [String] = []
    var stateTextStyles: [String] = []
    var note: original_src_types.ParsedStateNote? = nil
    var stateType: original_src_types.ParsedStateType? = nil
    var labelType: String = "markdown"
}

private enum _ParserEntryError: Error, LocalizedError, _MermaidRecoverableError {
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
private let _bareNodeRegex = _regex(#"^([\w\p{L}.-]+)"#)
private let _classShorthandRegex = _regex(#"^:::([\w][\w-]*)"#)
private let _clickRegex = _regex(#"^click\s+([\w\p{L}.-]+)\s+(.+)$"#)

private let _nodePatterns: [(regex: NSRegularExpression, shape: ParsedNodeShape)] = [
    (_regex(#"^([\w\p{L}.-]+)\(\(\((.+?)\)\)\)"#), .doublecircle),
    (_regex(#"^([\w\p{L}.-]+)\(\[(.+?)\]\)"#), .stadium),
    (_regex(#"^([\w\p{L}.-]+)\(\((.+?)\)\)"#), .circle),
    (_regex(#"^([\w\p{L}.-]+)\(-([^-]*?)-\)"#), .ellipse),
    (_regex(#"^([\w\p{L}.-]+)\[\[(.+?)\]\]"#), .subroutine),
    (_regex(#"^([\w\p{L}.-]+)\[\((.+?)\)\]"#), .cylinder),
    (_regex(#"^([\w\p{L}.-]+)\[\/(.+?)\\\]"#), .trapezoid),
    (_regex(#"^([\w\p{L}.-]+)\[\\(.+?)\/\]"#), .trapezoidAlt),
    (_regex(#"^([\w\p{L}.-]+)\[\/(.+?)\/\]"#), .parallelogram),
    (_regex(#"^([\w\p{L}.-]+)\[\\(.+?)\\\]"#), .parallelogramAlt),
    (_regex(#"^([\w\p{L}.-]+)>(.+?)\]"#), .asymmetric),
    (_regex(#"^([\w\p{L}.-]+)\{\{(.+?)\}\}"#), .hexagon),
    (_regex(#"^([\w\p{L}.-]+)\[(.+?)\]"#), .rectangle),
    (_regex(#"^([\w\p{L}.-]+)\((.+?)\)"#), .rounded),
    (_regex(#"^([\w\p{L}.-]+)\{(.+?)\}"#), .diamond),
]

public func parseMermaid(_ text: String, config: original_src_types.FlowchartConfig? = nil, stateConfig: original_src_types.StateConfig? = nil) throws -> MermaidGraph {
    try _parseMermaidEntry(text, config: config, stateConfig: stateConfig)
}

private func _parseMermaidEntry(_ text: String, config: original_src_types.FlowchartConfig? = nil, stateConfig: original_src_types.StateConfig? = nil) throws -> MermaidGraph {
    let lines = _mermaidSourceLines(from: text)

    guard !lines.isEmpty else {
        throw _ParserEntryError.emptyDiagram
    }

    let header = lines[0]
    let parsed: ParsedGraph
    let diagramType: DiagramType

    if _regexTest(#"^stateDiagram(-v2)?\s*$"#, header, caseInsensitive: true) {
        parsed = try _parseStateDiagram(lines, stateConfig: stateConfig)
        diagramType = .stateDiagram
    } else {
        parsed = try _parseFlowchart(lines, config: config)
        diagramType = .flowchart
    }

    return MermaidGraph(payload: diagramType == .stateDiagram ? .stateDiagram(parsed) : .flowchart(parsed))
}

private func _parseFlowchart(_ lines: [String], config: original_src_types.FlowchartConfig? = nil) throws -> ParsedGraph {
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
        if let commentIdx = line.range(of: "%%") {
            line = String(line[..<commentIdx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !line.isEmpty else { idx += 1; continue }

        if _regexTest(#"^accDescr\s*\{\s*$"#, line) {
            var descrLines: [String] = []
            idx += 1
            while idx < lines.count && !_regexTest(#"^\}\s*$"#, lines[idx]) {
                var nl = lines[idx]
                if let commentIdx = nl.range(of: "%%") {
                    nl = String(nl[..<commentIdx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
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

        if let classAssignMatch = _regexGroups(#"^class\s+([\w\p{L}.-]+(?:\s*,\s*[\w\p{L}.-]+)*)\s+(\w+)$"#, line),
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
            subgraphStack[subgraphStack.count - 1].direction = dir
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

        // Anonymous subgraph (bare "subgraph" keyword)
        if line.trimmingCharacters(in: .whitespaces) == "subgraph" {
            let autoId = "subgraph_\(graph.subgraphIds.count)"
            graph.subgraphIds.insert(autoId)
            subgraphStack.append(ParsedSubgraph(id: autoId, label: "", nodeIds: [], children: [], direction: nil))
            continue
        }

        if line == "end" {
            let completed = subgraphStack.popLast()
            if let completed {
                if !subgraphStack.isEmpty {
                    subgraphStack[subgraphStack.count - 1].children.append(completed)
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

    return graph.toParsedGraph()
}

private func _parseStateDiagram(_ lines: [String], stateConfig: original_src_types.StateConfig? = nil) throws -> ParsedGraph {
    var graph = _WorkingGraph(direction: .TD)
    if let sc = stateConfig { graph.stateConfig = sc }

    var compositeStack: [ParsedSubgraph] = []
    var compositeStateIds = Set<String>()
    var startCount = 0
    var endCount = 0
    var dividerCount = 0

    // Build regex patterns with embedded state ID character class
    let SID = #"[^\n\s\-\{\}\:\-\-\>]+"#
    func sPat(_ tmpl: String) -> String {
        tmpl.replacingOccurrences(of: "{{SID}}", with: SID)
    }

    func isStateKeyword(_ s: String) -> Bool {
        let lower = s.lowercased()
        let keywords: Set<String> = ["state", "note", "class", "classdef", "style", "click", "direction", "hide", "scale", "end", "left", "right", "of", "href"]
        return keywords.contains(lower)
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
        if let idx = line.range(of: "%%") {
            line = String(line[..<idx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !line.isEmpty else { i += 1; continue }

        // multiline note: "note left/right of <id>" followed by lines until "end note"
        if let noteMatch = _regexGroups(sPat("^note\\s+(left|right)\\s+of\\s+{{SID}}$"), line),
           noteMatch[safe: 1] != nil {
            var noteLines: [String] = [line]
            i += 1
            while i < lines.count && !_regexTest(#"^\s*end\s+note\s*$"#, lines[i], caseInsensitive: true) {
                var nl = lines[i]
                if let idx = nl.range(of: "%%") {
                    nl = String(nl[..<idx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
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
                if let idx = nl.range(of: "%%") {
                    nl = String(nl[..<idx.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
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
                compositeStack[compositeStack.count - 1].direction = direction
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
        if let clm = _regexGroups(sPat("^class\\s+({{SID}}(?:\\s*,\\s*{{SID}})*)\\s+(\\w+)$"), line),
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
        if let stm = _regexGroups(sPat("^style\\s+({{SID}}(?:\\s*,\\s*{{SID}})*)\\s+(.+)$"), line),
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
                    compositeStack[compositeStack.count - 1].children.append(processed)
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
            } else if !compositeStateIds.contains(sourceId), isValidStateID(sourceId) {
                _ensureStateNode(&graph, &compositeStack, sourceId)
            }
            if targetId == "[*]" {
                endCount += 1
                targetId = "\(parentID)_end"
                _registerStateNode(&graph, &compositeStack, ParsedNode(id: targetId, label: "", shape: .stateEnd))
            } else if !compositeStateIds.contains(targetId), isValidStateID(targetId) {
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
    }

    return graph.toParsedGraph()
}

private func _registerStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    let isNew = graph.nodesById[node.id] == nil
    if isNew {
        graph.upsertNode(node)
    }
    if !compositeStack.isEmpty {
        let current = compositeStack[compositeStack.count - 1]
        if !current.nodeIds.contains(node.id) {
            current.nodeIds.append(node.id)
        }
    }
}

private func _ensureStateNode(_ graph: inout _WorkingGraph, _ compositeStack: inout [ParsedSubgraph], _ id: String) {
    if graph.nodesById[id] == nil {
        _registerStateNode(&graph, &compositeStack, ParsedNode(id: id, label: id, shape: .rounded))
    } else if !compositeStack.isEmpty {
        let current = compositeStack[compositeStack.count - 1]
        if !current.nodeIds.contains(id) {
            current.nodeIds.append(id)
        }
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
        let result = subgraph
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

    let result = subgraph
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
        if !compositeStack[compositeStack.count - 1].nodeIds.contains(targetId) {
            compositeStack[compositeStack.count - 1].nodeIds.append(targetId)
        }
    }

    // Create note node and register in composite scope
    let noteId = "\(targetId)----note"
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

private let _dangerousURLPrefixes = ["javascript:", "data:", "vbscript:", "file:"]

private func _validateURL(_ url: String) -> Bool {
    let lowered = url.lowercased().trimmingCharacters(in: .whitespaces)
    guard !lowered.isEmpty else { return false }
    for prefix in _dangerousURLPrefixes {
        if lowered.hasPrefix(prefix) { return false }
    }
    return true
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
        let minlen = edgeOp.minlen
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

private func _registerNode(_ graph: inout _WorkingGraph, _ subgraphStack: inout [ParsedSubgraph], _ node: ParsedNode) {
    let isNew = graph.nodesById[node.id] == nil
    if isNew {
        graph.upsertNode(node)
    }
    _trackInSubgraph(&subgraphStack, node.id)
}

private func _trackInSubgraph(_ subgraphStack: inout [ParsedSubgraph], _ nodeId: String) {
    if !subgraphStack.isEmpty {
        let current = subgraphStack[subgraphStack.count - 1]
        if !current.nodeIds.contains(nodeId) {
            current.nodeIds.append(nodeId)
        }
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
    case "BR": return .BT  // Bottom-Right = Bottom-to-Top
    default: return ParsedDirection(rawValue: token.uppercased())
    }
}

private func _regexTest(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> Bool {
    _regexGroups(pattern, input, caseInsensitive: caseInsensitive) != nil
}

private func _regexGroups(_ pattern: String, _ input: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
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

open class original_src_parser {
    public init() {}

    // Export inventory from TypeScript source:
    // - export function parseMermaid
    public static func parseMermaid(_ text: String) throws -> MermaidGraph {
        try _parseMermaidEntry(text)
    }
}
