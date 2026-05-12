// Ported from original/src/sequence/parser.ts
import Foundation
import DiagramKitCommon

// MARK: - Parse Error

public enum SequenceParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(expected: String, found: String)
    case invalidConfig(String)
    case duplicateActor(String)
    case actorInMultipleBoxes(String)
    case createWithoutMessage(String)
    case destroyWithoutMessage(String)
    case inactiveDeactivation(String)
    case unexpectedEndOfBlock(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(expected, found):
            return "Invalid sequence diagram header. Expected '\(expected)', found '\(found)'."
        case let .invalidConfig(msg):
            return "Invalid participant config: \(msg)"
        case let .duplicateActor(id):
            return "Duplicate actor ID '\(id)' — cannot have actors with the same id, even if one is destroyed before the next is created."
        case let .actorInMultipleBoxes(id):
            return "Participant '\(id)' is assigned to multiple boxes."
        case let .createWithoutMessage(id):
            return "Created participant '\(id)' must be followed by a message to it."
        case let .destroyWithoutMessage(id):
            return "Destroyed participant '\(id)' must have an associated destroying message."
        case let .inactiveDeactivation(id):
            return "Trying to deactivate an inactive participant (\(id))."
        case let .unexpectedEndOfBlock(type):
            return "Unexpected end of '\(type)' block."
        }
    }
}

// MARK: - Arrow Pattern Table

// IMPORTANT: longest patterns first to avoid partial matches
private let _arrowPatterns: [(pattern: String, type: SequenceArrowType)] = [
    ("<<-->>", .bidirectionalDotted),
    ("<<->>", .bidirectionalSolid),
    ("--|\\", .solidArrowTopDotted),
    ("--|/", .solidArrowBottomDotted),
    ("--\\\\", .stickArrowTopDotted),
    ("--//", .stickArrowBottomDotted),
    ("/|--", .solidArrowTopReverseDotted),
    ("\\|--", .solidArrowBottomReverseDotted),
    ("//--", .stickArrowTopReverseDotted),
    ("\\\\--", .stickArrowBottomReverseDotted),
    ("-->>", .dotted),
    ("--x", .dottedCross),
    ("--)", .dottedPoint),
    ("-->", .dottedOpen),
    ("-|\\", .solidArrowTop),
    ("-|/", .solidArrowBottom),
    ("-\\\\", .stickArrowTop),
    ("-//", .stickArrowBottom),
    ("/\\|-", .solidArrowTopReverse),
    ("\\|-", .solidArrowBottomReverse),
    ("//-", .stickArrowTopReverse),
    ("\\\\-", .stickArrowBottomReverse),
    ("->>", .solid),
    ("-x", .solidCross),
    ("-)", .solidPoint),
    ("->", .solidOpen),
]

// MARK: - Public API

public func parseSequenceDiagram(_ lines: [String]) throws -> SequenceDiagram {
    try _parseSequenceDiagramEntry(lines)
}

// MARK: - Main Parser

private func _parseSequenceDiagramEntry(_ lines: [String]) throws -> SequenceDiagram {
    guard let header = lines.first else {
        return SequenceDiagram(items: [])
    }

    if header.range(of: #"^sequencediagram\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
        throw SequenceParserError.invalidHeader(expected: "sequenceDiagram", found: header)
    }

    var items: [SequenceItem] = []
    var actorIds = Set<String>()
    var openBlocks: [(type: String, label: String)] = []
    var lastCreatedId: String? = nil
    var lastDestroyedId: String? = nil

    if lines.count <= 1 { return SequenceDiagram(items: []) }

    // Pre-scan: multiline accDescr/accTitle joining
    var processedLines: [String] = []
    var i = 1
    while i < lines.count {
        let raw = lines[i].trimmingCharacters(in: .whitespaces)
        if _match(#"^accDescr\s*\{\s*$"#, raw, caseInsensitive: true) != nil {
            var descrLines: [String] = []
            i += 1
            while i < lines.count && _match(#"^\}\s*$"#, lines[i].trimmingCharacters(in: .whitespaces), caseInsensitive: true) == nil {
                descrLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                i += 1
            }
            i += 1 // skip "}"
            processedLines.append("accDescr: " + descrLines.joined(separator: "\n"))
            continue
        }
        if _match(#"^accTitle\s*\{\s*$"#, raw, caseInsensitive: true) != nil {
            var titleLines: [String] = []
            i += 1
            while i < lines.count && _match(#"^\}\s*$"#, lines[i].trimmingCharacters(in: .whitespaces), caseInsensitive: true) == nil {
                titleLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                i += 1
            }
            i += 1 // skip "}"
            processedLines.append("accTitle: " + titleLines.joined(separator: "\n"))
            continue
        }
        processedLines.append(lines[i])
        i += 1
    }

    for rawLine in processedLines {
        let line = _preprocessLine(rawLine)
        if line.isEmpty { continue }

        // --- Title ---
        if let m = _match(#"^title\s+(.+)$"#, line, caseInsensitive: true) {
            items.append(.title(m[1].trimmingCharacters(in: .whitespaces)))
            continue
        }
        if let m = _match(#"^title:\s*(.+)$"#, line, caseInsensitive: true) {
            items.append(.title(m[1].trimmingCharacters(in: .whitespaces)))
            continue
        }
        // --- accTitle ---
        if let m = _match(#"^accTitle:\s*([\s\S]+)$"#, line, caseInsensitive: true) {
            items.append(.accTitle(m[1].trimmingCharacters(in: .whitespaces)))
            continue
        }
        // --- accDescr ---
        if let m = _match(#"^accDescr:\s*([\s\S]+)$"#, line, caseInsensitive: true) {
            items.append(.accDescr(m[1].trimmingCharacters(in: .whitespaces)))
            continue
        }

        // --- Autonumber ---
        if _match(#"^autonumber\s+off\s*$"#, line, caseInsensitive: true) != nil {
            items.append(.autonumberEvent(start: 1.0, step: 1.0, visible: false))
            continue
        }
        if let m = _match(#"^autonumber\s+([0-9]+(?:\.[0-9]{1,2})?)\s+([0-9]+(?:\.[0-9]{1,2})?)\s*$"#, line, caseInsensitive: true) {
            items.append(.autonumberEvent(start: Double(m[1]) ?? 1.0, step: Double(m[2]) ?? 1.0, visible: true))
            continue
        }
        if let m = _match(#"^autonumber\s+([0-9]+(?:\.[0-9]{1,2})?)\s*$"#, line, caseInsensitive: true) {
            items.append(.autonumberEvent(start: Double(m[1]) ?? 1.0, step: 1.0, visible: true))
            continue
        }
        if _match(#"^autonumber\s*$"#, line, caseInsensitive: true) != nil {
            items.append(.autonumberEvent(start: 1.0, step: 1.0, visible: true))
            continue
        }

        // --- Box ---
        if let m = _match(#"^box\s+(.+)$"#, line, caseInsensitive: true) {
            let boxData = _parseBoxData(m[1])
            items.append(.boxStart(fill: boxData.color, title: boxData.text, wrap: boxData.wrap))
            openBlocks.append((type: "box", label: boxData.text ?? ""))
            continue
        }

        // --- Participant / Actor with optional config ---
        if let result = _parseParticipantDeclaration(line) {
            let id = result.id
            actorIds.insert(id)
            let actor = SequenceActor(
                id: id,
                label: result.label,
                type: result.participantType,
                config: result.config,
                isExplicit: true,
                wrap: result.wrap
            )
            items.append(.actor(actor))
            continue
        }

        // --- Note ---
        if let m = _match(#"^note\s+(left of|right of|over)\s+([^:]+):\s*(.+)$"#, line, caseInsensitive: true) {
            let positionRaw = m[1].lowercased()
            let actorTokens = _splitActorTokens(m[2])
            let text = _decodeEntities(_brTagsToNewlines(m[3].trimmingCharacters(in: .whitespacesAndNewlines)))
            let pos: String = positionRaw == "left of" ? "left" : (positionRaw == "right of" ? "right" : "over")
            let afterIdx = items.lastIndex(where: { if case .message = $0 { true } else { false } }) ?? (items.count - 1)
            items.append(.note(SequenceNote(actorIds: actorTokens, text: text, position: pos, afterItemIndex: max(0, afterIdx))))
            continue
        }

        // --- Block dividers: else, and, option (must be before block start to catch 'option' before 'opt') ---
        if let m = _match(#"^(else|and|option)\s*(.*)$"#, line, caseInsensitive: true), !openBlocks.isEmpty {
            let label = _extractWrapDecode(m[2].trimmingCharacters(in: .whitespacesAndNewlines)).cleanedText
            items.append(.blockDivider(type: openBlocks.last!.type, label: label))
            continue
        }

        // --- Block start: loop, alt, opt, par, par_over, critical, break, rect ---
        if let m = _match(#"^(loop|alt|opt|par|par_over|critical|break|rect)\s*(.*)$"#, line, caseInsensitive: true) {
            let blockType = m[1].lowercased()
            let label = _extractWrapDecode(m[2].trimmingCharacters(in: .whitespacesAndNewlines)).cleanedText
            openBlocks.append((type: blockType, label: label))
            items.append(.blockStart(type: blockType, label: label))
            continue
        }

        // --- Block end ---
        if line.lowercased() == "end", !openBlocks.isEmpty {
            let closed = openBlocks.removeLast()
            if closed.type == "box" {
                items.append(.boxEnd)
            } else {
                items.append(.blockEnd(type: closed.type))
            }
            continue
        }

        // --- Create ---
        if let m = _match(#"^create\s+(participant|actor)\s+(\S+?)(?:\s+as\s+(.+))?$"#, line, caseInsensitive: true) {
            let pType: ParticipantType = m[1].lowercased() == "actor" ? .actor : .participant
            let id = m[2]
            if actorIds.contains(id) {
                throw SequenceParserError.duplicateActor(id)
            }
            actorIds.insert(id)
            let label = (m.count > 3 ? m[3] : "").isEmpty ? id : m[3]
            let actor = SequenceActor(id: id, label: label, type: pType, isExplicit: true)
            items.append(.createParticipant(actor))
            lastCreatedId = id
            continue
        }

        // --- Destroy ---
        if let m = _match(#"^destroy\s+(\S+)$"#, line, caseInsensitive: true) {
            let id = m[1]
            items.append(.destroyParticipant(actorId: id))
            lastDestroyedId = id
            continue
        }

        // --- Activate / Deactivate ---
        if let m = _match(#"^activate\s+(\S+)$"#, line, caseInsensitive: true) {
            items.append(.activationStart(actorId: m[1]))
            continue
        }
        if let m = _match(#"^deactivate\s+(\S+)$"#, line, caseInsensitive: true) {
            items.append(.activationEnd(actorId: m[1]))
            continue
        }

        // --- Link / Links ---
        if let m = _match(#"^link\s+(\S+?):\s*(.+)$"#, line, caseInsensitive: true) {
            let actorId = m[1]
            let text = m[2].trimmingCharacters(in: .whitespaces)
            if let url = _parseLink(text) {
                items.append(.link(actorId, label: url.label, url: url.url))
            }
            continue
        }
        if let m = _match(#"^links\s+(\S+?):\s*(.+)$"#, line, caseInsensitive: true) {
            items.append(.links(m[1], json: m[2].trimmingCharacters(in: .whitespaces)))
            continue
        }

        // --- Properties ---
        if let m = _match(#"^properties\s+(\S+?):\s*(.+)$"#, line, caseInsensitive: true) {
            items.append(.properties(m[1], json: m[2].trimmingCharacters(in: .whitespaces)))
            continue
        }

        // --- Details ---
        if let m = _match(#"^details\s+(\S+?):\s*(.+)$"#, line, caseInsensitive: true) {
            items.append(.details(m[1], elementId: m[2].trimmingCharacters(in: .whitespaces)))
            continue
        }

        // --- Message ---
        if let msg = _parseSequenceMessage(line, &items, &actorIds) {
            if let cid = lastCreatedId {
                if msg.to != cid {
                    throw SequenceParserError.createWithoutMessage(cid)
                }
                lastCreatedId = nil
            }
            if let did = lastDestroyedId {
                if msg.from != did && msg.to != did {
                    throw SequenceParserError.destroyWithoutMessage(did)
                }
                lastDestroyedId = nil
            }
            items.append(.message(msg))
            continue
        }
    }

    if let cid = lastCreatedId {
        throw SequenceParserError.createWithoutMessage(cid)
    }
    if let did = lastDestroyedId {
        throw SequenceParserError.destroyWithoutMessage(did)
    }

    return SequenceDiagram(items: items)
}

// MARK: - Preprocessing

private func _preprocessLine(_ rawLine: String) -> String {
    var line = rawLine

    // 1. Shield entity patterns from # comment stripping
    let entityRegex = try! NSRegularExpression(pattern: #"#(\d+|[a-zA-Z]+);"#, options: [])
    var entities: [String] = []
    let nsLine = line as NSString
    let matches = entityRegex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))
    // Collect in reverse order to preserve indices
    for match in matches.reversed() {
        let range = match.range
        let original = nsLine.substring(with: range)
        let placeholder = "__ENTITY_\(entities.count)__"
        entities.append(original)
        line = (line as NSString).replacingCharacters(in: range, with: placeholder)
    }

    // 2. Strip # comments
    if let hashIdx = line.firstIndex(of: "#") {
        let beforeHash = String(line[..<hashIdx])
        // Check if previous char is a backslash (escape)
        if hashIdx > line.startIndex {
            let prev = line[line.index(before: hashIdx)]
            if prev != "\\" {
                line = beforeHash
            }
        } else {
            line = beforeHash
        }
    }

    // 3. Restore entity patterns
    for (i, entity) in entities.enumerated() {
        line = line.replacingOccurrences(of: "__ENTITY_\(i)__", with: entity)
    }

    // 4. Strip %% comments
    if let range = line.range(of: "%%") {
        line = String(line[..<range.lowerBound])
    }

    return line.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Participant Declaration

private func _parseParticipantDeclaration(_ line: String) -> (id: String, label: String, participantType: ParticipantType, config: ParticipantConfig?, wrap: Bool?)? {
    // Pattern: (participant|actor) <id>@{config} as <alias>
    // Or: (participant|actor) <id> as <alias>
    guard let kMatch = _match(#"^(participant|actor)\s+"#, line, caseInsensitive: true) else {
        return nil
    }
    let pType: ParticipantType = kMatch[1].lowercased() == "actor" ? .actor : .participant
    let rest = String(line.dropFirst(kMatch[0].count)).trimmingCharacters(in: .whitespaces)

    // Extract actor ID (before @, as, or end)
    var id: String = ""
    var config: ParticipantConfig? = nil
    var alias: String? = nil
    var wrap: Bool? = nil

    // Check for @{ config
    if let configStart = rest.range(of: "@{") {
        // ID is everything before @{
        id = String(rest[..<configStart.lowerBound]).trimmingCharacters(in: .whitespaces)

        // Extract config content between { and }
        let afterConfig = rest[configStart.upperBound...]
        guard let closeBrace = afterConfig.range(of: "}") else {
            return nil // Invalid, should error
        }
        let configJSON = String(afterConfig[..<closeBrace.lowerBound])
        config = _parseParticipantConfig(configJSON)

        // Check for `as` after config
        let afterBrace = String(afterConfig[closeBrace.upperBound...]).trimmingCharacters(in: .whitespaces)
        let (cleanedAfter, _wrap) = _extractWrapDecode(afterBrace)
        wrap = _wrap
        if cleanedAfter.hasPrefix("as ") {
            alias = String(cleanedAfter.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if let inlineAlias = config?.alias, cleanedAfter.isEmpty {
            alias = inlineAlias
        }
    } else {
        // No config, check for `as`
        if let asRange = rest.range(of: " as ", options: .caseInsensitive) {
            id = String(rest[..<asRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let aliasRaw = String(rest[asRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let (cleaned, _wrap) = _extractWrapDecode(aliasRaw)
            alias = cleaned
            wrap = _wrap
        } else {
            let (cleaned, _wrap) = _extractWrapDecode(rest)
            id = cleaned
            wrap = _wrap
        }
    }

    // Validate ID: must not contain <, >, :, newline, comma, ;, @
    if id.contains(where: { "<>:,\n;@".contains($0) }) || id.isEmpty {
        return nil
    }

    let label = alias ?? id
    return (id: id, label: _brTagsToNewlines(_decodeEntities(label)), participantType: config?.type ?? pType, config: config, wrap: wrap)
}

private func _parseParticipantConfig(_ json: String) -> ParticipantConfig? {
    let trimmed = json.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return nil }

    // Relaxed YAML/JSON parsing for Mermaid-compatible syntax:
    // Supports: "type": "boundary", type: boundary, 'type': 'database'
    var config = ParticipantConfig()

    // Extract "type" key
    let typePatterns = [
        #""type"\s*:\s*"(\w+)"#,
        #"'type'\s*:\s*'(\w+)'"#,
        #"type\s*:\s*(\w+)"#,
    ]
    for pattern in typePatterns {
        if let m = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            .firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let r = Range(m.range(at: 1), in: trimmed) {
                let typeStr = String(trimmed[r]).lowercased()
                config.type = ParticipantType(rawValue: typeStr) ?? .participant
                break
            }
        }
    }

    // Extract "alias" key
    let aliasPatterns = [
        #""alias"\s*:\s*"([^"]+)"#,
        #"'alias'\s*:\s*'([^']+)'"#,
        #"alias\s*:\s*([^,}]+)"#,
    ]
    for pattern in aliasPatterns {
        if let m = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            .firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)) {
            if let r = Range(m.range(at: 1), in: trimmed) {
                config.alias = String(trimmed[r]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
    }

    return config
}

// MARK: - Box Data

private func _parseBoxData(_ str: String) -> (color: String, text: String?, wrap: Bool) {
    let trimmed = str.trimmingCharacters(in: .whitespaces)

    // Extract color from rgb/rgba/hsl/hsla or color name
    let (color, rest) = _parseColorAndRest(trimmed)

    // Validate color: check if it's a known CSS function or valid name
    let validatedColor = _isValidColor(color) ? color : "transparent"
    let title: String?
    if !_isValidColor(color) {
        // The whole line is the title
        title = trimmed.isEmpty ? nil : trimmed
    } else {
        let cleaned = rest?.trimmingCharacters(in: .whitespaces) ?? ""
        let (cleanedText, _) = _extractWrapDecode(cleaned)
        title = cleanedText.isEmpty ? nil : cleanedText
    }

    let (_, wrap) = _extractWrapDecode(title ?? "")
    return (color: validatedColor, text: title, wrap: wrap ?? false)
}

private func _parseColorAndRest(_ str: String) -> (color: String, rest: String?) {
    // Try rgb/rgba/hsl/hsla functions
    let funcPattern = #"^((?:rgba?|hsla?)\s*\([^)]*\))\s*(.*)$"#
    if let m = try? NSRegularExpression(pattern: funcPattern, options: [.caseInsensitive])
        .firstMatch(in: str, options: [], range: NSRange(str.startIndex..., in: str)),
       let r1 = Range(m.range(at: 1), in: str) {
        let color = String(str[r1])
        let rest = m.range(at: 2).location != NSNotFound ? String(str[Range(m.range(at: 2), in: str)!]) : nil
        return (color, rest?.trimmingCharacters(in: .whitespaces))
    }

    // Try color name (first word)
    let words = str.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    if let first = words.first {
        let color = String(first)
        let rest = words.count > 1 ? String(words[1]) : nil
        return (color, rest)
    }
    return ("transparent", str)
}

private func _isValidColor(_ color: String) -> Bool {
    if color.isEmpty || color.lowercased() == "transparent" { return true }
    // rgb/rgba/hsl/hsla function
    if color.range(of: #"^(rgba?|hsla?)\s*\("#, options: [.regularExpression, .caseInsensitive]) != nil {
        return true
    }
    // Known CSS color names
    let validNames: Set<String> = [
        "red", "green", "blue", "yellow", "orange", "purple", "pink", "cyan", "magenta",
        "white", "black", "gray", "grey", "brown", "lime", "navy", "teal", "aqua",
        "maroon", "olive", "silver", "gold", "coral", "indigo", "violet", "turquoise",
        "salmon", "plum", "orchid", "tan", "khaki", "ivory", "azure", "beige", "crimson",
        "aliceblue", "antiquewhite", "aquamarine", "bisque", "blanchedalmond", "blueviolet",
        "burlywood", "cadetblue", "chartreuse", "chocolate", "cornflowerblue", "cornsilk",
        "darkblue", "darkcyan", "darkgoldenrod", "darkgray", "darkgreen", "darkkhaki",
        "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred", "darksalmon",
        "darkseagreen", "darkslateblue", "darkslategray", "darkturquoise", "darkviolet",
        "deeppink", "deepskyblue", "dimgray", "dodgerblue", "firebrick", "floralwhite",
        "forestgreen", "gainsboro", "ghostwhite", "honeydew", "hotpink", "indianred",
        "lavender", "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral",
        "lightcyan", "lightgoldenrodyellow", "lightgray", "lightgreen", "lightpink",
        "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray", "lightsteelblue",
        "lightyellow", "limegreen", "linen", "mediumaquamarine", "mediumblue", "mediumorchid",
        "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen",
        "mediumturquoise", "mediumvioletred", "midnightblue", "mintcream", "mistyrose",
        "moccasin", "navajowhite", "oldlace", "olivedrab", "orangered", "palegoldenrod",
        "palegreen", "paleturquoise", "palevioletred", "papayawhip", "peachpuff", "peru",
        "powderblue", "rosybrown", "royalblue", "saddlebrown", "sandybrown", "seagreen",
        "seashell", "sienna", "skyblue", "slateblue", "slategray", "snow", "springgreen",
        "steelblue", "thistle", "tomato", "wheat", "whitesmoke", "yellowgreen",
        "rebeccapurple", "transparent",
    ]
    return validNames.contains(color.lowercased())
}

// MARK: - Wrap Extraction

private func _extractWrapDecode(_ text: String) -> (cleanedText: String, wrap: Bool?) {
    let trimmed = text.trimmingCharacters(in: .whitespaces)

    if let m = _match(#"^:?wrap:(.+)$"#, trimmed) {
        let inner = m[1].trimmingCharacters(in: .whitespaces)
        return (_brTagsToNewlines(_decodeEntities(inner)), true)
    }
    if let m = _match(#"^:?nowrap:(.+)$"#, trimmed) {
        let inner = m[1].trimmingCharacters(in: .whitespaces)
        return (_brTagsToNewlines(_decodeEntities(inner)), false)
    }
    return (_brTagsToNewlines(_decodeEntities(trimmed)), nil)
}

// MARK: - Arrow Head Type Detection

private func _detectArrowType(_ arrow: String) -> SequenceArrowType? {
    for (pattern, type) in _arrowPatterns {
        if arrow == pattern { return type }
    }
    return nil
}

// MARK: - Message Parsing

private func _parseSequenceMessage(_ line: String, _ items: inout [SequenceItem], _ actorIds: inout Set<String>) -> SequenceMessage? {
    // Find the colon separator for the label
    guard let colonIdx = line.firstIndex(of: ":") else { return nil }
    let beforeColon = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
    let afterColon = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

    // Try each arrow pattern to find one in the text (longest first = best match)
    for (pattern, type) in _arrowPatterns {
        guard let arrowRange = beforeColon.range(of: pattern) else { continue }

        var from = String(beforeColon[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let after = String(beforeColon[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        var centralConnection: CentralConnectionType? = nil
        var activation: String = ""
        var to = ""

        // Check for () before the arrow (source-side central connection)
        if from.hasSuffix("()") {
            centralConnection = .source
            from = String(from.dropLast(2)).trimmingCharacters(in: .whitespaces)
        }

        // Process text after the arrow
        var remaining = after

        // Check for () after arrow (dest-side central connection)
        if remaining.hasPrefix("()") {
            if centralConnection == .source {
                centralConnection = .both
            } else {
                centralConnection = .dest
            }
            remaining = String(remaining.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }

        // Check for activation marker
        if remaining.hasPrefix("+") {
            activation = "+"
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if remaining.hasPrefix("-") {
            activation = "-"
            remaining = String(remaining.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else if remaining.hasSuffix("+") {
            activation = "+"
            remaining = String(remaining.dropLast()).trimmingCharacters(in: .whitespaces)
        } else if remaining.hasSuffix("-") {
            activation = "-"
            remaining = String(remaining.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        to = remaining.trimmingCharacters(in: .whitespaces)

        guard !from.isEmpty, !to.isEmpty else { return nil }

        let (label, _) = _extractWrapDecode(afterColon)

        _ensureActor(&items, &actorIds, from)
        _ensureActor(&items, &actorIds, to)

        let msg = SequenceMessage(
            from: from, to: to, label: label, arrowType: type,
            activate: activation == "+", deactivate: activation == "-",
            centralConnection: centralConnection
        )

        if activation == "+" { items.append(.activationStart(actorId: to)) }
        if activation == "-" { items.append(.activationEnd(actorId: from)) }

        return msg
    }

    return nil
}

private func _buildMessage(from: String, arrowType: SequenceArrowType, activation: String, to: String, label: String, centralConnection: CentralConnectionType?) -> SequenceMessage {
    SequenceMessage(
        from: from,
        to: to,
        label: label,
        arrowType: arrowType,
        activate: activation == "+",
        deactivate: activation == "-",
        centralConnection: centralConnection
    )
}

// MARK: - Link Parsing

private func _parseLink(_ text: String) -> (label: String, url: String)? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if let sep = trimmed.firstIndex(of: "@") {
        let label = String(trimmed[..<sep]).trimmingCharacters(in: .whitespaces)
        let url = String(trimmed[trimmed.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
        guard _isSafeURL(url) else { return nil }
        return (label: label, url: url)
    }
    return nil
}

private func _isSafeURL(_ url: String) -> Bool {
    let lowercased = url.lowercased()
    let unsafePrefixes = ["javascript:", "data:", "vbscript:", "file:"]
    for prefix in unsafePrefixes {
        if lowercased.hasPrefix(prefix) { return false }
    }
    if lowercased.contains("javascript:") { return false }
    guard let parsed = URL(string: url) else {
        return !lowercased.starts(with: "unsafe:")
    }
    let allowedSchemes: Set<String> = ["https", "http", "mailto", "tel", "ftp"]
    if let scheme = parsed.scheme?.lowercased(), !allowedSchemes.contains(scheme) {
        return false
    }
    return true
}

// MARK: - Helpers

private func _ensureActor(_ items: inout [SequenceItem], _ actorIds: inout Set<String>, _ id: String) {
    if actorIds.contains(id) { return }
    actorIds.insert(id)
    let actor = SequenceActor(id: id, label: id, type: .participant, isExplicit: false)
    items.append(.actor(actor))
}

private func _splitActorTokens(_ s: String) -> [String] {
    s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

// MARK: - Entity Decoding

private let _entityMap: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
    "nbsp": "\u{00A0}", "iexcl": "\u{00A1}", "cent": "\u{00A2}", "pound": "\u{00A3}",
    "curren": "\u{00A4}", "yen": "\u{00A5}", "brvbar": "\u{00A6}", "sect": "\u{00A7}",
    "uml": "\u{00A8}", "copy": "\u{00A9}", "ordf": "\u{00AA}", "laquo": "\u{00AB}",
    "not": "\u{00AC}", "shy": "\u{00AD}", "reg": "\u{00AE}", "macr": "\u{00AF}",
    "deg": "\u{00B0}", "plusmn": "\u{00B1}", "sup2": "\u{00B2}", "sup3": "\u{00B3}",
    "acute": "\u{00B4}", "micro": "\u{00B5}", "para": "\u{00B6}", "middot": "\u{00B7}",
    "cedil": "\u{00B8}", "sup1": "\u{00B9}", "ordm": "\u{00BA}", "raquo": "\u{00BB}",
    "frac14": "\u{00BC}", "frac12": "\u{00BD}", "frac34": "\u{00BE}", "iquest": "\u{00BF}",
    "Agrave": "\u{00C0}", "Aacute": "\u{00C1}", "Acirc": "\u{00C2}", "Atilde": "\u{00C3}",
    "Auml": "\u{00C4}", "Aring": "\u{00C5}", "AElig": "\u{00C6}", "Ccedil": "\u{00C7}",
    "Egrave": "\u{00C8}", "Eacute": "\u{00C9}", "Ecirc": "\u{00CA}", "Euml": "\u{00CB}",
    "Igrave": "\u{00CC}", "Iacute": "\u{00CD}", "Icirc": "\u{00CE}", "Iuml": "\u{00CF}",
    "ETH": "\u{00D0}", "Ntilde": "\u{00D1}", "Ograve": "\u{00D2}", "Oacute": "\u{00D3}",
    "Ocirc": "\u{00D4}", "Otilde": "\u{00D5}", "Ouml": "\u{00D6}", "times": "\u{00D7}",
    "Oslash": "\u{00D8}", "Ugrave": "\u{00D9}", "Uacute": "\u{00DA}", "Ucirc": "\u{00DB}",
    "Uuml": "\u{00DC}", "Yacute": "\u{00DD}", "THORN": "\u{00DE}", "szlig": "\u{00DF}",
    "agrave": "\u{00E0}", "aacute": "\u{00E1}", "acirc": "\u{00E2}", "atilde": "\u{00E3}",
    "auml": "\u{00E4}", "aring": "\u{00E5}", "aelig": "\u{00E6}", "ccedil": "\u{00E7}",
    "egrave": "\u{00E8}", "eacute": "\u{00E9}", "ecirc": "\u{00EA}", "euml": "\u{00EB}",
    "igrave": "\u{00EC}", "iacute": "\u{00ED}", "icirc": "\u{00EE}", "iuml": "\u{00EF}",
    "eth": "\u{00F0}", "ntilde": "\u{00F1}", "ograve": "\u{00F2}", "oacute": "\u{00F3}",
    "ocirc": "\u{00F4}", "otilde": "\u{00F5}", "ouml": "\u{00F6}", "divide": "\u{00F7}",
    "oslash": "\u{00F8}", "ugrave": "\u{00F9}", "uacute": "\u{00FA}", "ucirc": "\u{00FB}",
    "uuml": "\u{00FC}", "yacute": "\u{00FD}", "thorn": "\u{00FE}", "yuml": "\u{00FF}",
    "infin": "\u{221E}", "hearts": "\u{2665}",
]

private func _decodeEntities(_ text: String) -> String {
    var result = text
    // Decode named entities: #name;
    for (name, char) in _entityMap {
        result = result.replacingOccurrences(of: "#\(name);", with: char)
    }
    // Decode decimal entities: #NNNN;
    let decimalRegex = try! NSRegularExpression(pattern: #"#(\d+);"#, options: [])
    let nsString = result as NSString
    let matches = decimalRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
    for match in matches.reversed() {
        let range = match.range
        if let numRange = Range(match.range(at: 1), in: result),
           let codePoint = Int(result[numRange]),
           let scalar = UnicodeScalar(codePoint) {
            result = (result as NSString).replacingCharacters(in: range, with: String(Character(scalar)))
        }
    }
    return result
}

// MARK: - Tag Normalization

private func _normalizeBrTags(_ text: String) -> String {
    text.replacingOccurrences(of: #"<br\s*/?>"#, with: "<br>", options: [.regularExpression, .caseInsensitive])
}

private func _brTagsToNewlines(_ text: String) -> String {
    text.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
}

// MARK: - Regex Helper

private func _match(_ pattern: String, _ text: String, caseInsensitive: Bool = true) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range) else {
        return nil
    }
    var out: [String] = []
    out.reserveCapacity(match.numberOfRanges)
    for idx in 0..<match.numberOfRanges {
        let r = match.range(at: idx)
        if let rr = Range(r, in: text) {
            out.append(String(text[rr]))
        } else {
            out.append("")
        }
    }
    return out
}

// MARK: - Legacy class

open class original_src_sequence_parser {
    public init() {}

    public static func parseSequenceDiagram(_ lines: [String]) throws -> SequenceDiagram {
        try _parseSequenceDiagramEntry(lines)
    }
}
