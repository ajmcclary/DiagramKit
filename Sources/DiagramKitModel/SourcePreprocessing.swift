import Foundation
import DiagramKitCommon

/// Result of preprocessing: the stripped diagram source and any parsed frontmatter.
public typealias _PreprocessResult = (source: String, frontmatter: DiagramFrontmatter?)

public func _preprocessMermaidSource(_ source: String) -> _PreprocessResult {
    _parseFrontMatterAndStripped(source)
}

public func _mermaidSourceLines(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    let processed = _preprocessMermaidSource(source)
    let joined = _joinMultiLineBlocks(processed.source)
    return MermaidSourceNormalizer.statements(joined, separators: separators)
}

/// Parse YAML-like frontmatter from a source string.
/// Returns the stripped diagram source and any parsed DiagramFrontmatter.
public func _parseFrontMatterAndStripped(_ source: String) -> _PreprocessResult {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    guard normalized.contains("%%{") || _firstNonEmptyLineIsFrontmatterFence(normalized) else {
        return (source, nil)
    }
    return _parseFrontMatterAndStrippedSlow(normalized, originalSource: source)
}

private func _firstNonEmptyLineIsFrontmatterFence(_ source: String) -> Bool {
    for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }
        return trimmed == "---"
    }
    return false
}

@inline(never)
private func _parseFrontMatterAndStrippedSlow(_ normalized: String, originalSource source: String) -> _PreprocessResult {
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    var strippedSource = normalized
    var frontmatter: DiagramFrontmatter?
    var consumedFrontmatter = false

    // Parse one or more leading frontmatter sections delimited by `---`.
    // YAML multi-doc treats `---` as both a closer of the previous doc and
    // an opener of the next, so a source like
    //   ---
    //   <doc1>
    //   ---
    //   <doc2>
    //   ---
    //   <body>
    // contains two frontmatter sections and a diagram body. All sections are
    // concatenated and parsed as a single YAML document.
    let firstNonBlank = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? lines.endIndex
    var combinedFmLines: [String] = []
    if firstNonBlank < lines.endIndex,
       lines[firstNonBlank].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
        // Find every `---` marker contiguously from the start (separated only
        // by blank lines or YAML body content — never by another non-`---`
        // non-YAML line).
        var markers: [Int] = [firstNonBlank]
        var cursor = firstNonBlank + 1
        while cursor < lines.endIndex {
            if lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                markers.append(cursor)
            }
            cursor += 1
        }
        // We need at least two `---` markers to have one frontmatter section.
        // With N markers, there are N-1 sections (or floor((N)/1) frontmatter
        // sections separated by `---`). If the last marker has no trailing
        // body, treat all sections as frontmatter and body is empty.
        if markers.count >= 2 {
            for i in 0..<(markers.count - 1) {
                let blockStart = markers[i] + 1
                let blockEnd = markers[i + 1]
                combinedFmLines.append(contentsOf: lines[blockStart..<blockEnd])
            }
            let lastMarker = markers.last!
            strippedSource = lines[(lastMarker + 1)...].joined(separator: "\n")
            consumedFrontmatter = true
        }
    }
    if consumedFrontmatter {
        frontmatter = _parseYamlFrontmatter(combinedFmLines)
    } else if firstNonBlank < lines.endIndex,
              lines[firstNonBlank].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
        // Unterminated single block: legacy behavior.
        return (source, nil)
    }

    guard strippedSource.contains("%%{") else {
        if consumedFrontmatter || frontmatter != nil {
            return (strippedSource, frontmatter)
        }
        return (source, nil)
    }

    let initProcessed = _stripAndApplyInitDirectives(from: strippedSource, frontmatter: frontmatter)
    if consumedFrontmatter || initProcessed.source != strippedSource || initProcessed.frontmatter != nil {
        return initProcessed
    }
    return (source, nil)
}

private func _stripAndApplyInitDirectives(
    from source: String,
    frontmatter: DiagramFrontmatter?
) -> _PreprocessResult {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var strippedLines: [String] = []
    var nextFrontmatter = frontmatter
    var removedDirective = false

    for line in lines {
        guard let payload = _initDirectivePayload(from: line) else {
            strippedLines.append(line)
            continue
        }

        removedDirective = true
        var fm = nextFrontmatter ?? DiagramFrontmatter()
        if _applyInitDirectivePayload(payload, to: &fm) {
            nextFrontmatter = fm
        }
    }

    if removedDirective {
        return (strippedLines.joined(separator: "\n"), nextFrontmatter)
    }
    return (source, nextFrontmatter)
}

private func _initDirectivePayload(from line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("%%{"), trimmed.hasSuffix("}%%") else {
        return nil
    }

    let contentStart = trimmed.index(trimmed.startIndex, offsetBy: 3)
    let contentEnd = trimmed.index(trimmed.endIndex, offsetBy: -3)
    let content = String(trimmed[contentStart..<contentEnd]).trimmingCharacters(in: .whitespaces)
    guard let colon = content.firstIndex(of: ":") else {
        return nil
    }

    let directiveName = String(content[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard directiveName.caseInsensitiveCompare("init") == .orderedSame else {
        return nil
    }

    return String(content[content.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
}

@discardableResult
private func _applyInitDirectivePayload(_ payload: String, to frontmatter: inout DiagramFrontmatter) -> Bool {
    // New path: use InitDirectiveParser + FrontmatterBinding for diagram-specific config.
    // Shared values (theme, layout, look, htmlLabels, fontSize, securityLevel) are still
    // handled inline for backward compatibility. Per-diagram config and theme bindings
    // are dispatched through the FrontmatterBinding registry below.
    guard let object = InitDirectiveParser.parseJSON(payload) else {
        return false
    }

    var applied = _applySharedInitValues(object, to: &frontmatter)

    // Flatten the JSON into key-value pairs and apply through registered bindings.
    let pairs = InitDirectiveParser.flatten(object, prefix: "")
    applied = _applyBindings(pairs, to: &frontmatter) || applied

    return applied
}

/// Registry of active `FrontmatterBinding` implementations. Each binding
/// receives every key-value pair; it returns `true` if it consumed the key.
private func _activeBindings() -> [any FrontmatterBinding] {
    [
        SequenceFrontmatterBinding(),
        RequirementFrontmatterBinding(),
        RadarFrontmatterBinding(),
        TreemapFrontmatterBinding(),
        VennFrontmatterBinding(),
        IshikawaFrontmatterBinding(),
        C4FrontmatterBinding(),
        TreeViewFrontmatterBinding(),
        EventModelingFrontmatterBinding(),
        WardleyFrontmatterBinding(),
        FlowchartFrontmatterBinding(),
        StateFrontmatterBinding(),
        ClassFrontmatterBinding(),
        ERFrontmatterBinding(),
        XYChartFrontmatterBinding(),
        PieFrontmatterBinding(),
        JourneyFrontmatterBinding(),
        GanttFrontmatterBinding(),
        QuadrantFrontmatterBinding(),
        TimelineFrontmatterBinding(),
        GitGraphFrontmatterBinding(),
        SankeyFrontmatterBinding(),
        MindmapFrontmatterBinding(),
        BlockFrontmatterBinding(),
        PacketFrontmatterBinding(),
        KanbanFrontmatterBinding(),
        ArchitectureFrontmatterBinding(),
    ]
}

/// Apply flattened key-value pairs through all registered bindings.
/// Normalizes paths so bindings receive both `config.X.Y` and `X.Y` forms,
/// enabling parity between YAML frontmatter and JSON init directive paths.
private func _applyBindings(
    _ pairs: [(path: String, value: FrontmatterValue)],
    to frontmatter: inout DiagramFrontmatter
) -> Bool {
    var bindings = _activeBindings()
    var applied = false
    for (path, value) in pairs {
        // Generate alternate forms for cross-path compatibility.
        // YAML produces "config.sequence.diagramMarginX"; JSON produces
        // "sequence.diagramMarginX". Try both so bindings match either.
        var pathsToTry = [path]
        if path.hasPrefix("config.") {
            pathsToTry.append(String(path.dropFirst("config.".count)))
        } else {
            pathsToTry.append("config." + path)
        }
        for tryPath in pathsToTry {
            for i in bindings.indices {
                if bindings[i].apply(path: tryPath, value: value) {
                    applied = true
                }
            }
        }
    }
    for i in bindings.indices {
        bindings[i].commit(into: &frontmatter)
    }
    return applied
}

@discardableResult
private func _applySharedInitValues(_ object: [String: Any], to frontmatter: inout DiagramFrontmatter) -> Bool {
    var applied = false

    if let theme = _jsonString(object["theme"]) {
        frontmatter.theme = theme
        applied = true
    }
    if let layout = _jsonString(object["layout"]) {
        frontmatter.layout = layout
        applied = true
    }
    if let look = _jsonString(object["look"]) {
        frontmatter.look = look
        applied = true
    }
    if let htmlLabels = _jsonBool(object["htmlLabels"]) {
        frontmatter.htmlLabels = htmlLabels
        applied = true
    }
    if let fontSize = _jsonDouble(object["fontSize"]) {
        frontmatter.fontSize = fontSize
        applied = true
    }
    if let securityLevel = _jsonString(object["securityLevel"]) {
        frontmatter.securityLevel = securityLevel
        applied = true
    }

    return applied
}


private func _jsonString(_ value: Any?) -> String? {
    value as? String
}

private func _jsonScalarString(_ value: Any) -> String? {
    if let string = value as? String {
        return string
    }
    if let number = value as? NSNumber {
        return number.stringValue
    }
    if let bool = value as? Bool {
        return bool ? "true" : "false"
    }
    return nil
}

private func _jsonDouble(_ value: Any?) -> Double? {
    if let double = value as? Double {
        return double
    }
    if let number = value as? NSNumber {
        return number.doubleValue
    }
    if let string = value as? String {
        return Double(string)
    }
    return nil
}

private func _jsonBool(_ value: Any?) -> Bool? {
    if let bool = value as? Bool {
        return bool
    }
    if let number = value as? NSNumber {
        return number.boolValue
    }
    if let string = value as? String {
        switch string.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }
    return nil
}

/// Parse YAML frontmatter lines into `DiagramFrontmatter`.
/// Handles global keys (title, theme, layout, look, htmlLabels, fontSize,
/// securityLevel) inline and delegates diagram-specific config to
/// registered `FrontmatterBinding` implementations, ensuring YAML
/// and JSON init directives produce identical results.
public func _parseYamlFrontmatter(_ lines: [String]) -> DiagramFrontmatter? {
    let pairs = FrontmatterDocumentParser.flatten(lines)
    guard !pairs.isEmpty else { return nil }

    var frontmatter = DiagramFrontmatter()
    var hasContent = false

    // Handle global keys and title inline
    for (path, value) in pairs {
        switch path {
        case "title", "config.title":
            if !value.string.isEmpty {
                frontmatter.title = value.string
                frontmatter.diagramTitle = value.string
                hasContent = true
            }
        case "config.theme":
            frontmatter.theme = value.string
            hasContent = true
        case "config.layout":
            frontmatter.layout = value.string
            hasContent = true
        case "config.look":
            frontmatter.look = value.string
            hasContent = true
        case "config.htmlLabels":
            frontmatter.htmlLabels = value.bool
            hasContent = true
        case "config.fontSize":
            frontmatter.fontSize = value.double
            hasContent = true
        case "config.securityLevel":
            frontmatter.securityLevel = value.string
            hasContent = true
        default:
            hasContent = true
        }
    }

    // Apply bindings for all diagram-specific config
    _ = _applyBindings(pairs, to: &frontmatter)

    // Legacy: propagate global layout/look/htmlLabels to ER config if set
    if frontmatter.layout != nil || frontmatter.look != nil || frontmatter.htmlLabels != nil {
        if var er = frontmatter.erConfig {
            if let l = frontmatter.layout { er.layout = l }
            if let lk = frontmatter.look { er.look = lk }
            if let hl = frontmatter.htmlLabels { er.htmlLabels = hl }
            frontmatter.erConfig = er
        }
    }

    // Legacy: propagate securityLevel to flowchart and state configs
    if let sl = frontmatter.securityLevel {
        if var fc = frontmatter.flowchartConfig {
            fc.securityLevel = sl
            frontmatter.flowchartConfig = fc
        } else {
            var fc = original_src_types.FlowchartConfig()
            fc.securityLevel = sl
            frontmatter.flowchartConfig = fc
        }
        if var sc = frontmatter.stateConfig {
            sc.securityLevel = sl
            frontmatter.stateConfig = sc
        } else {
            var sc = original_src_types.StateConfig()
            sc.securityLevel = sl
            frontmatter.stateConfig = sc
        }
    }

    return hasContent ? frontmatter : nil
}

