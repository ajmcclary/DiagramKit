import Foundation

/// Result of preprocessing: the stripped diagram source and any parsed frontmatter.
typealias _PreprocessResult = (source: String, frontmatter: DiagramFrontmatter?)

func _preprocessMermaidSource(_ source: String) -> _PreprocessResult {
    _parseFrontMatterAndStripped(source)
}

func _mermaidSourceLines(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    let processed = _preprocessMermaidSource(source)
    let joined = _joinMultiLineBlocks(processed.source)
    return _splitMermaidStatements(joined, separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
}

private func _splitMermaidStatements(_ source: String, separatedBy separators: CharacterSet) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in source {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if _isMermaidStatementSeparator(ch, separators) {
            parts.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }

    parts.append(current)
    return parts
}

private func _isMermaidStatementSeparator(_ ch: Character, _ separators: CharacterSet) -> Bool {
    guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first else {
        return false
    }
    return separators.contains(scalar)
}

/// Parse YAML-like frontmatter from a source string.
/// Returns the stripped diagram source and any parsed DiagramFrontmatter.
func _parseFrontMatterAndStripped(_ source: String) -> _PreprocessResult {
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

    if let startIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
       lines[startIdx].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
        guard let endIdx = lines[(startIdx + 1)...].firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else {
            return (source, nil)
        }

        let fmLines = Array(lines[(startIdx + 1)..<endIdx])
        strippedSource = lines[(endIdx + 1)...].joined(separator: "\n")
        frontmatter = _parseYamlFrontmatter(fmLines)
        consumedFrontmatter = true
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
    ]
}

/// Apply flattened key-value pairs through all registered bindings.
private func _applyBindings(
    _ pairs: [(path: String, value: FrontmatterValue)],
    to frontmatter: inout DiagramFrontmatter
) -> Bool {
    var bindings = _activeBindings()
    var applied = false
    for (path, value) in pairs {
        for i in bindings.indices {
            if bindings[i].apply(path: path, value: value) {
                applied = true
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

private func _applyWardleyConfigValue(_ key: String, value: Any, config: inout WardleyDiagramConfig) -> Bool {
    switch key {
    case "width":
        if let v = _jsonDouble(value) { config.width = v; return true }
    case "height":
        if let v = _jsonDouble(value) { config.height = v; return true }
    case "padding":
        if let v = _jsonDouble(value) { config.padding = v; return true }
    case "nodeRadius":
        if let v = _jsonDouble(value) { config.nodeRadius = v; return true }
    case "nodeLabelOffset":
        if let v = _jsonDouble(value) { config.nodeLabelOffset = v; return true }
    case "axisFontSize":
        if let v = _jsonDouble(value) { config.axisFontSize = v; return true }
    case "labelFontSize":
        if let v = _jsonDouble(value) { config.labelFontSize = v; return true }
    case "showGrid":
        if let v = _jsonBool(value) { config.showGrid = v; return true }
    case "useMaxWidth":
        if let v = _jsonBool(value) { config.useMaxWidth = v; return true }
    default:
        break
    }
    return false
}

private func _wardleyThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isWardleyThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("wardley.") {
                let inner = String(subKey.dropFirst("wardley.".count))
                if _isWardleyThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

private func _isWardleyThemeKey(_ key: String) -> Bool {
    switch key {
    case "backgroundColor", "axisColor", "axisTextColor", "gridColor",
         "componentFill", "componentStroke", "componentLabelColor",
         "linkStroke", "evolutionStroke", "annotationStroke",
         "annotationTextColor", "annotationFill", "evolutionColor",
         "wardleyEvolutionColor":
        return true
    default:
        return false
    }
}

private func _applyWardleyThemeValue(_ key: String, value: String, theme: inout WardleyThemeVariables) -> Bool {
    switch key {
    case "backgroundColor": theme.backgroundColor = value
    case "axisColor": theme.axisColor = value
    case "axisTextColor": theme.axisTextColor = value
    case "gridColor": theme.gridColor = value
    case "componentFill": theme.componentFill = value
    case "componentStroke": theme.componentStroke = value
    case "componentLabelColor": theme.componentLabelColor = value
    case "linkStroke": theme.linkStroke = value
    case "evolutionStroke": theme.evolutionStroke = value
    case "annotationStroke": theme.annotationStroke = value
    case "annotationTextColor": theme.annotationTextColor = value
    case "annotationFill": theme.annotationFill = value
    case "evolutionColor":
        theme.evolutionColor = value
        theme.evolutionStroke = value
    case "wardleyEvolutionColor":
        theme.evolutionColor = value
        theme.evolutionStroke = value
    default:
        return false
    }
    return true
}

private final class _RadarFrontmatterAccumulator {
    var config = RadarDiagramConfig()
    var theme = RadarThemeConfig()
    var hasConfig = false
    var hasTheme = false
}

private struct _YamlFrontmatterEntry {
    var path: String
    var value: String
}

/// Extended YAML parser for Mermaid frontmatter.
/// Runs the legacy parser for global keys and families without bindings,
/// then applies registered `FrontmatterBinding` implementations so YAML
/// and JSON init directives produce the same `DiagramFrontmatter`.
func _parseYamlFrontmatter(_ lines: [String]) -> DiagramFrontmatter? {
    var frontmatter = _StackSafeYamlFrontmatterParser().parse(lines)
    let pairs = FrontmatterDocumentParser.flatten(lines)
    if !pairs.isEmpty {
        if frontmatter == nil {
            frontmatter = DiagramFrontmatter()
        }
        _applyBindings(pairs, to: &frontmatter!)
    }
    return frontmatter
}

private func _flattenYamlFrontmatterLines(_ lines: [String]) -> [ _YamlFrontmatterEntry ] {
    var pathStack: [(depth: Int, key: String)] = []
    var entries: [_YamlFrontmatterEntry] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        let commentStripped = _stripYamlComment(trimmed)
        guard let colonIdx = commentStripped.firstIndex(of: ":") else { continue }

        let key = String(commentStripped[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(commentStripped[commentStripped.index(after: colonIdx)...])
            .trimmingCharacters(in: .whitespaces)
        let indent = line.prefix(while: { $0 == " " }).count
        let depth = indent / 2

        while let last = pathStack.last, last.depth >= depth {
            pathStack.removeLast()
        }
        pathStack.append((depth: depth, key: key))

        entries.append(_YamlFrontmatterEntry(
            path: pathStack.map(\.key).joined(separator: "."),
            value: _unquote(rawValue)
        ))
    }

    return entries
}

private final class _StackSafeYamlFrontmatterParser {
    var frontmatter = DiagramFrontmatter()
    var hasAnyContent = false

    var flowchartConfig = original_src_types.FlowchartConfig()
    var hasFlowchartSection = false
    var classConfig = ClassConfig()
    var hasClassSection = false
    var erConfig = ErDiagramConfig()
    var hasErSection = false
    var xyChartConfig = XYChartConfig()
    var xyChartTheme = XYChartThemeConfig()
    var hasXYChartConfig = false
    var hasXYChartTheme = false
    var pieConfig = PieChartConfig()
    var pieTheme = PieChartThemeConfig()
    var hasPieConfig = false
    var hasPieTheme = false
    var sequenceConfig = SequenceDiagramConfig()
    var hasSequenceSection = false
    var stateConfig = original_src_types.StateConfig()
    var hasStateSection = false
    var journeyConfig = JourneyDiagramConfig()
    var hasJourneySection = false
    var ganttConfig = GanttDiagramConfig()
    var hasGanttSection = false
    var quadrantChartConfig = QuadrantChartConfig()
    var quadrantChartTheme = QuadrantChartThemeConfig()
    var hasQuadrantChartConfig = false
    var hasQuadrantChartTheme = false
    var requirementConfig = RequirementDiagramConfig()
    var requirementTheme = RequirementThemeVariables()
    var hasRequirementSection = false
    var hasRequirementTheme = false
    var gitGraphConfig = GitGraphConfig()
    var gitGraphTheme = GitGraphThemeConfig()
    var hasGitGraphSection = false
    var hasGitGraphTheme = false
    var mindmapConfig = MindmapConfig()
    var hasMindmapSection = false
    var timelineConfig = TimelineDiagramConfig()
    var timelineTheme = TimelineThemeConfig.default
    var hasTimelineSection = false
    var hasTimelineTheme = false
    var sankeyConfig = SankeyDiagramConfig()
    var hasSankeySection = false
    var blockConfig = BlockDiagramConfig()
    var hasBlockSection = false
    var packetConfig = PacketDiagramConfig.default
    var packetTheme = PacketThemeConfig.default
    var hasPacketSection = false
    var hasPacketTheme = false
    var kanbanConfig = KanbanDiagramConfig()
    var hasKanbanSection = false
    var archConfig = ArchitectureDiagramConfig()
    var archTheme = ArchitectureThemeConfig()
    var hasArchSection = false
    var hasArchTheme = false
    let radar = _RadarFrontmatterAccumulator()
    var treemapConfig = TreemapDiagramConfig()
    var treemapThemeVariables: [String: String] = [:]
    var hasTreemapSection = false
    var hasTreemapTheme = false
    var vennConfig = VennDiagramConfig()
    var vennThemeVariables: [String: String] = [:]
    var hasVennSection = false
    var hasVennTheme = false
    var ishikawaConfig = IshikawaDiagramConfig()
    var hasIshikawaSection = false
    var treeViewConfig = TreeViewDiagramConfig()
    var treeViewTheme = TreeViewThemeVariables.default
    var hasTreeViewSection = false
    var hasTreeViewTheme = false
    var eventmodelingConfig = EventModelingDiagramConfig()
    var eventmodelingThemeVariables = EventModelingThemeVariables()
    var hasEventModelingSection = false
    var hasEventModelingTheme = false
    var wardleyConfig = WardleyDiagramConfig()
    var wardleyTheme = WardleyThemeVariables()
    var hasWardleySection = false
    var hasWardleyTheme = false

    func parse(_ lines: [String]) -> DiagramFrontmatter? {
        for entry in _flattenYamlFrontmatterLines(lines) {
            hasAnyContent = true
            apply(entry)
        }
        finalize()
        return hasAnyContent ? frontmatter : nil
    }

    private func apply(_ entry: _YamlFrontmatterEntry) {
        let path = entry.path
        let value = entry.value

        if applyTitle(path, value) { return }
        if applyClass(path, value) { return }
        if applyFlowchart(path, value) { return }
        if applyEr(path, value) { return }
        if applyXYChart(path, value) { return }
        if applyPie(path, value) { return }
        if applySequence(path, value) { return }
        if applyState(path, value) { return }
        if applyJourney(path, value) { return }
        if applyGantt(path, value) { return }
        if applyRequirement(path, value) { return }
        if applyRequirementTheme(path, value) { return }
        if applyQuadrant(path, value) { return }
        if applyTimeline(path, value) { return }
        if applyTimelineTheme(path, value) { return }
        if applyGitGraphTheme(path, value) { return }
        if applyQuadrantTheme(path, value) { return }
        if applyGitGraph(path, value) { return }
        if applySankey(path, value) { return }
        if applyMindmap(path, value) { return }
        if applyBlock(path, value) { return }
        if applyPacket(path, value) { return }
        if applyKanban(path, value) { return }
        if applyArchitecture(path, value) { return }
        if applyRadar(path, value) { return }
        if applyTreemap(path, value) { return }
        if applyVenn(path, value) { return }
        if applyIshikawa(path, value) { return }
        if applyTreeView(path, value) { return }
        if applyEventModeling(path, value) { return }
        if applyWardley(path, value) { return }
        _ = applyGlobal(path, value)
    }

    private func applyTitle(_ path: String, _ value: String) -> Bool {
        guard path == "title", !value.isEmpty else { return false }
        frontmatter.title = value
        frontmatter.diagramTitle = value
        return true
    }

    private func applyClass(_ path: String, _ value: String) -> Bool {
        let prefix: String
        if path.hasPrefix("class.") {
            prefix = "class."
        } else if path.hasPrefix("config.class.") {
            prefix = "config.class."
        } else {
            return false
        }
        hasClassSection = true
        switch path.replacingOccurrences(of: prefix, with: "") {
        case "hideEmptyMembersBox": classConfig.hideEmptyMembersBox = (value.lowercased() == "true")
        case "hierarchicalNamespaces": classConfig.hierarchicalNamespaces = (value.lowercased() == "true")
        case "padding": classConfig.padding = Double(value)
        default: break
        }
        return true
    }

    private func applyFlowchart(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.flowchart.") || path == "flowchart" else { return false }
        hasFlowchartSection = true
        if path == "flowchart" {
            if !value.isEmpty { flowchartConfig.curve = value }
            return true
        }
        switch path.replacingOccurrences(of: "config.flowchart.", with: "") {
        case "curve": flowchartConfig.curve = value
        case "htmlLabels": flowchartConfig.htmlLabels = (value.lowercased() == "true")
        case "markdownAutoWrap": flowchartConfig.markdownAutoWrap = (value.lowercased() == "true")
        case "width": flowchartConfig.width = Int(value)
        case "inheritDir": flowchartConfig.inheritDir = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyEr(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.er.") else { return false }
        hasErSection = true
        switch path.replacingOccurrences(of: "config.er.", with: "") {
        case "titleTopMargin": erConfig.titleTopMargin = Double(value)
        case "diagramPadding": erConfig.diagramPadding = Double(value)
        case "layoutDirection": erConfig.layoutDirection = ErDirection(rawValue: value.uppercased())
        case "minEntityWidth": erConfig.minEntityWidth = Double(value)
        case "minEntityHeight": erConfig.minEntityHeight = Double(value)
        case "entityPadding": erConfig.entityPadding = Double(value)
        case "nodeSpacing": erConfig.nodeSpacing = Double(value)
        case "rankSpacing": erConfig.rankSpacing = Double(value)
        case "stroke": erConfig.stroke = value
        case "fill": erConfig.fill = value
        case "fontSize": erConfig.fontSize = Double(value)
        case "useMaxWidth": erConfig.useMaxWidth = (value.lowercased() == "true")
        case "erEdgeLabelBackground": erConfig.erEdgeLabelBackground = value
        default: break
        }
        return true
    }

    private func applyXYChart(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.xyChart.") {
            hasXYChartConfig = true
            let key = path.replacingOccurrences(of: "config.xyChart.", with: "")
            switch key {
            case "width": xyChartConfig.width = Double(value) ?? xyChartConfig.width
            case "height": xyChartConfig.height = Double(value) ?? xyChartConfig.height
            case "titleFontSize": xyChartConfig.titleFontSize = Double(value) ?? xyChartConfig.titleFontSize
            case "titlePadding": xyChartConfig.titlePadding = Double(value) ?? xyChartConfig.titlePadding
            case "showTitle": xyChartConfig.showTitle = (value.lowercased() == "true")
            case "showDataLabel": xyChartConfig.showDataLabel = (value.lowercased() == "true")
            case "showDataLabelOutsideBar": xyChartConfig.showDataLabelOutsideBar = (value.lowercased() == "true")
            case "chartOrientation": xyChartConfig.chartOrientation = value
            case "plotReservedSpacePercent": xyChartConfig.plotReservedSpacePercent = Double(value) ?? xyChartConfig.plotReservedSpacePercent
            default: applyXYAxis(key, value)
            }
            return true
        }
        guard path.hasPrefix("config.themeVariables.xyChart.") else { return false }
        hasXYChartTheme = true
        switch path.replacingOccurrences(of: "config.themeVariables.xyChart.", with: "") {
        case "backgroundColor": xyChartTheme.backgroundColor = value
        case "titleColor": xyChartTheme.titleColor = value
        case "dataLabelColor": xyChartTheme.dataLabelColor = value
        case "xAxisLabelColor": xyChartTheme.xAxisLabelColor = value
        case "xAxisTitleColor": xyChartTheme.xAxisTitleColor = value
        case "xAxisTickColor": xyChartTheme.xAxisTickColor = value
        case "xAxisLineColor": xyChartTheme.xAxisLineColor = value
        case "yAxisLabelColor": xyChartTheme.yAxisLabelColor = value
        case "yAxisTitleColor": xyChartTheme.yAxisTitleColor = value
        case "yAxisTickColor": xyChartTheme.yAxisTickColor = value
        case "yAxisLineColor": xyChartTheme.yAxisLineColor = value
        case "plotColorPalette": xyChartTheme.plotColorPalette = value
        default: break
        }
        return true
    }

    private func applyXYAxis(_ key: String, _ value: String) {
        if key.hasPrefix("xAxis.") {
            switch key.replacingOccurrences(of: "xAxis.", with: "") {
            case "showLabel": xyChartConfig.xAxis.showLabel = (value.lowercased() == "true")
            case "labelFontSize": xyChartConfig.xAxis.labelFontSize = Double(value) ?? xyChartConfig.xAxis.labelFontSize
            case "labelPadding": xyChartConfig.xAxis.labelPadding = Double(value) ?? xyChartConfig.xAxis.labelPadding
            case "showTitle": xyChartConfig.xAxis.showTitle = (value.lowercased() == "true")
            case "titleFontSize": xyChartConfig.xAxis.titleFontSize = Double(value) ?? xyChartConfig.xAxis.titleFontSize
            case "titlePadding": xyChartConfig.xAxis.titlePadding = Double(value) ?? xyChartConfig.xAxis.titlePadding
            case "showTick": xyChartConfig.xAxis.showTick = (value.lowercased() == "true")
            case "tickLength": xyChartConfig.xAxis.tickLength = Double(value) ?? xyChartConfig.xAxis.tickLength
            case "tickWidth": xyChartConfig.xAxis.tickWidth = Double(value) ?? xyChartConfig.xAxis.tickWidth
            case "showAxisLine": xyChartConfig.xAxis.showAxisLine = (value.lowercased() == "true")
            case "axisLineWidth": xyChartConfig.xAxis.axisLineWidth = Double(value) ?? xyChartConfig.xAxis.axisLineWidth
            default: break
            }
        } else if key.hasPrefix("yAxis.") {
            switch key.replacingOccurrences(of: "yAxis.", with: "") {
            case "showLabel": xyChartConfig.yAxis.showLabel = (value.lowercased() == "true")
            case "labelFontSize": xyChartConfig.yAxis.labelFontSize = Double(value) ?? xyChartConfig.yAxis.labelFontSize
            case "labelPadding": xyChartConfig.yAxis.labelPadding = Double(value) ?? xyChartConfig.yAxis.labelPadding
            case "showTitle": xyChartConfig.yAxis.showTitle = (value.lowercased() == "true")
            case "titleFontSize": xyChartConfig.yAxis.titleFontSize = Double(value) ?? xyChartConfig.yAxis.titleFontSize
            case "titlePadding": xyChartConfig.yAxis.titlePadding = Double(value) ?? xyChartConfig.yAxis.titlePadding
            case "showTick": xyChartConfig.yAxis.showTick = (value.lowercased() == "true")
            case "tickLength": xyChartConfig.yAxis.tickLength = Double(value) ?? xyChartConfig.yAxis.tickLength
            case "tickWidth": xyChartConfig.yAxis.tickWidth = Double(value) ?? xyChartConfig.yAxis.tickWidth
            case "showAxisLine": xyChartConfig.yAxis.showAxisLine = (value.lowercased() == "true")
            case "axisLineWidth": xyChartConfig.yAxis.axisLineWidth = Double(value) ?? xyChartConfig.yAxis.axisLineWidth
            default: break
            }
        }
    }

    private func applyPie(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.pie.") {
            hasPieConfig = true
            switch path.replacingOccurrences(of: "config.pie.", with: "") {
            case "textPosition": pieConfig.textPosition = Double(value) ?? pieConfig.textPosition
            case "useWidth": pieConfig.useWidth = Double(value) ?? pieConfig.useWidth
            case "useMaxWidth": pieConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        guard let key = _pieThemeSubKey(from: path) else { return false }
        if _applyPieThemeValue(key, value: value, theme: &pieTheme) { hasPieTheme = true }
        return true
    }

    private func applySequence(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.sequence.") else { return false }
        hasSequenceSection = true
        switch path.replacingOccurrences(of: "config.sequence.", with: "") {
        case "diagramMarginX": sequenceConfig.diagramMarginX = Double(value) ?? sequenceConfig.diagramMarginX
        case "diagramMarginY": sequenceConfig.diagramMarginY = Double(value) ?? sequenceConfig.diagramMarginY
        case "actorMargin": sequenceConfig.actorMargin = Double(value) ?? sequenceConfig.actorMargin
        case "width": sequenceConfig.width = Double(value) ?? sequenceConfig.width
        case "height": sequenceConfig.height = Double(value) ?? sequenceConfig.height
        case "boxMargin": sequenceConfig.boxMargin = Double(value) ?? sequenceConfig.boxMargin
        case "boxTextMargin": sequenceConfig.boxTextMargin = Double(value) ?? sequenceConfig.boxTextMargin
        case "noteMargin": sequenceConfig.noteMargin = Double(value) ?? sequenceConfig.noteMargin
        case "messageMargin": sequenceConfig.messageMargin = Double(value) ?? sequenceConfig.messageMargin
        case "activationWidth": sequenceConfig.activationWidth = Double(value) ?? sequenceConfig.activationWidth
        case "messageAlign": sequenceConfig.messageAlign = SequenceDiagramConfig.TextAlign(rawValue: value.lowercased()) ?? sequenceConfig.messageAlign
        case "noteAlign": sequenceConfig.noteAlign = SequenceDiagramConfig.TextAlign(rawValue: value.lowercased()) ?? sequenceConfig.noteAlign
        case "bottomMarginAdj": sequenceConfig.bottomMarginAdj = Double(value) ?? sequenceConfig.bottomMarginAdj
        case "useMaxWidth": sequenceConfig.useMaxWidth = (value.lowercased() == "true")
        case "mirrorActors": sequenceConfig.mirrorActors = (value.lowercased() == "true")
        case "hideUnusedParticipants": sequenceConfig.hideUnusedParticipants = (value.lowercased() == "true")
        case "rightAngles": sequenceConfig.rightAngles = (value.lowercased() == "true")
        case "showSequenceNumbers": sequenceConfig.showSequenceNumbers = (value.lowercased() == "true")
        case "forceMenus": sequenceConfig.forceMenus = (value.lowercased() == "true")
        case "arrowMarkerAbsolute": sequenceConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
        case "wrap": sequenceConfig.wrap = (value.lowercased() == "true")
        case "wrapPadding": sequenceConfig.wrapPadding = Double(value) ?? sequenceConfig.wrapPadding
        case "labelBoxWidth": sequenceConfig.labelBoxWidth = Double(value) ?? sequenceConfig.labelBoxWidth
        case "labelBoxHeight": sequenceConfig.labelBoxHeight = Double(value) ?? sequenceConfig.labelBoxHeight
        case "actorFontFamily": sequenceConfig.actorFontFamily = value
        case "actorFontSize": sequenceConfig.actorFontSize = Double(value)
        case "actorFontWeight": sequenceConfig.actorFontWeight = value
        case "messageFontFamily": sequenceConfig.messageFontFamily = value
        case "messageFontSize": sequenceConfig.messageFontSize = Double(value)
        case "messageFontWeight": sequenceConfig.messageFontWeight = value
        case "noteFontFamily": sequenceConfig.noteFontFamily = value
        case "noteFontSize": sequenceConfig.noteFontSize = Double(value)
        case "noteFontWeight": sequenceConfig.noteFontWeight = value
        default: break
        }
        return true
    }

    private func applyState(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.state.") else { return false }
        hasStateSection = true
        switch path.replacingOccurrences(of: "config.state.", with: "") {
        case "titleTopMargin": stateConfig.titleTopMargin = Double(value) ?? stateConfig.titleTopMargin
        case "useMaxWidth": stateConfig.useMaxWidth = (value.lowercased() == "true")
        case "defaultRenderer": stateConfig.defaultRenderer = value
        case "arrowMarkerAbsolute": stateConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
        case "dividerMargin": stateConfig.dividerMargin = Double(value) ?? stateConfig.dividerMargin
        case "sizeUnit": stateConfig.sizeUnit = Double(value) ?? stateConfig.sizeUnit
        case "padding": stateConfig.padding = Double(value) ?? stateConfig.padding
        case "textHeight": stateConfig.textHeight = Double(value) ?? stateConfig.textHeight
        case "titleShift": stateConfig.titleShift = Double(value) ?? stateConfig.titleShift
        case "noteMargin": stateConfig.noteMargin = Double(value) ?? stateConfig.noteMargin
        case "nodeSpacing": stateConfig.nodeSpacing = Int(value) ?? stateConfig.nodeSpacing
        case "rankSpacing": stateConfig.rankSpacing = Int(value) ?? stateConfig.rankSpacing
        case "forkWidth": stateConfig.forkWidth = Double(value) ?? stateConfig.forkWidth
        case "forkHeight": stateConfig.forkHeight = Double(value) ?? stateConfig.forkHeight
        case "miniPadding": stateConfig.miniPadding = Double(value) ?? stateConfig.miniPadding
        case "fontSizeFactor": stateConfig.fontSizeFactor = Double(value) ?? stateConfig.fontSizeFactor
        case "fontSize": stateConfig.fontSize = Double(value) ?? stateConfig.fontSize
        case "labelHeight": stateConfig.labelHeight = Double(value) ?? stateConfig.labelHeight
        case "edgeLengthFactor": stateConfig.edgeLengthFactor = value
        case "compositTitleSize": stateConfig.compositTitleSize = Double(value) ?? stateConfig.compositTitleSize
        case "radius": stateConfig.radius = Double(value) ?? stateConfig.radius
        case "scaleWidth": stateConfig.scaleWidth = Int(value)
        case "hideEmptyDescription": stateConfig.hideEmptyDescription = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyJourney(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.journey.") else { return false }
        hasJourneySection = true
        switch path.replacingOccurrences(of: "config.journey.", with: "") {
        case "diagramMarginX": journeyConfig.diagramMarginX = Double(value) ?? journeyConfig.diagramMarginX
        case "diagramMarginY": journeyConfig.diagramMarginY = Double(value) ?? journeyConfig.diagramMarginY
        case "leftMargin": journeyConfig.leftMargin = Double(value) ?? journeyConfig.leftMargin
        case "maxLabelWidth": journeyConfig.maxLabelWidth = Double(value) ?? journeyConfig.maxLabelWidth
        case "width": journeyConfig.width = Double(value) ?? journeyConfig.width
        case "height": journeyConfig.height = Double(value) ?? journeyConfig.height
        case "boxMargin": journeyConfig.boxMargin = Double(value) ?? journeyConfig.boxMargin
        case "boxTextMargin": journeyConfig.boxTextMargin = Double(value) ?? journeyConfig.boxTextMargin
        case "noteMargin": journeyConfig.noteMargin = Double(value) ?? journeyConfig.noteMargin
        case "messageMargin": journeyConfig.messageMargin = Double(value) ?? journeyConfig.messageMargin
        case "messageAlign": journeyConfig.messageAlign = value
        case "bottomMarginAdj": journeyConfig.bottomMarginAdj = Double(value) ?? journeyConfig.bottomMarginAdj
        case "useMaxWidth": journeyConfig.useMaxWidth = (value.lowercased() == "true")
        case "rightAngles": journeyConfig.rightAngles = (value.lowercased() == "true")
        case "taskFontSize": journeyConfig.taskFontSize = Double(value) ?? journeyConfig.taskFontSize
        case "taskFontFamily": journeyConfig.taskFontFamily = value
        case "taskMargin": journeyConfig.taskMargin = Double(value) ?? journeyConfig.taskMargin
        case "activationWidth": journeyConfig.activationWidth = Double(value) ?? journeyConfig.activationWidth
        case "textPlacement": journeyConfig.textPlacement = value
        case "actorColours": journeyConfig.actorColours = _parseYamlStringArray(value) ?? journeyConfig.actorColours
        case "sectionFills": journeyConfig.sectionFills = _parseYamlStringArray(value) ?? journeyConfig.sectionFills
        case "sectionColours": journeyConfig.sectionColours = _parseYamlStringArray(value) ?? journeyConfig.sectionColours
        case "titleColor": journeyConfig.titleColor = value
        case "titleFontFamily": journeyConfig.titleFontFamily = value
        case "titleFontSize": journeyConfig.titleFontSize = value
        case "faceColor": journeyConfig.faceColor = value
        default: break
        }
        return true
    }

    private func applyGantt(_ path: String, _ value: String) -> Bool {
        if path == "displayMode", value.lowercased() == "compact" {
            hasGanttSection = true
            ganttConfig.displayMode = "compact"
            return true
        }
        guard path.hasPrefix("config.gantt.") else { return false }
        hasGanttSection = true
        switch path.replacingOccurrences(of: "config.gantt.", with: "") {
        case "titleTopMargin": ganttConfig.titleTopMargin = Double(value) ?? ganttConfig.titleTopMargin
        case "barHeight": ganttConfig.barHeight = Double(value) ?? ganttConfig.barHeight
        case "barGap": ganttConfig.barGap = Double(value) ?? ganttConfig.barGap
        case "topPadding": ganttConfig.topPadding = Double(value) ?? ganttConfig.topPadding
        case "rightPadding": ganttConfig.rightPadding = Double(value) ?? ganttConfig.rightPadding
        case "leftPadding": ganttConfig.leftPadding = Double(value) ?? ganttConfig.leftPadding
        case "gridLineStartPadding": ganttConfig.gridLineStartPadding = Double(value) ?? ganttConfig.gridLineStartPadding
        case "fontSize": ganttConfig.fontSize = Double(value) ?? ganttConfig.fontSize
        case "sectionFontSize": ganttConfig.sectionFontSize = Double(value) ?? ganttConfig.sectionFontSize
        case "numberSectionStyles": ganttConfig.numberSectionStyles = Int(value) ?? ganttConfig.numberSectionStyles
        case "axisFormat": ganttConfig.axisFormat = value
        case "tickInterval": ganttConfig.tickInterval = value
        case "topAxis": ganttConfig.topAxis = (value.lowercased() == "true")
        case "displayMode": ganttConfig.displayMode = value
        case "weekday": ganttConfig.weekday = value
        case "useMaxWidth": ganttConfig.useMaxWidth = (value.lowercased() == "true")
        case "useWidth": ganttConfig.useWidth = Double(value)
        default: break
        }
        return true
    }

    private func applyRequirement(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.requirement.") else { return false }
        hasRequirementSection = true
        switch path.replacingOccurrences(of: "config.requirement.", with: "") {
        case "useMaxWidth": requirementConfig.useMaxWidth = (value.lowercased() == "true")
        case "useWidth": requirementConfig.useWidth = Double(value)
        case "rect_fill": requirementConfig.rect_fill = value
        case "text_color": requirementConfig.text_color = value
        case "rect_border_size": requirementConfig.rect_border_size = value
        case "rect_border_color": requirementConfig.rect_border_color = value
        case "rect_min_width": requirementConfig.rect_min_width = Double(value)
        case "rect_min_height": requirementConfig.rect_min_height = Double(value)
        case "fontSize": requirementConfig.fontSize = Double(value)
        case "rect_padding": requirementConfig.rect_padding = Double(value)
        case "line_height": requirementConfig.line_height = Double(value)
        case "nodeSpacing": requirementConfig.nodeSpacing = Double(value) ?? 50
        case "rankSpacing": requirementConfig.rankSpacing = Double(value) ?? 50
        case "htmlLabels": requirementConfig.htmlLabels = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyRequirementTheme(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.themeVariables.") else { return false }
        let key = path.replacingOccurrences(of: "config.themeVariables.", with: "")
        if _applyRequirementThemeKey(key, value: value) {
            hasRequirementTheme = true
            return true
        }
        return false
    }

    private func _applyRequirementThemeKey(_ key: String, value: String) -> Bool {
        switch key {
        case "requirementBackground": requirementTheme.requirementBackground = value
        case "requirementBorderColor": requirementTheme.requirementBorderColor = value
        case "requirementBorderSize": requirementTheme.requirementBorderSize = value
        case "requirementTextColor": requirementTheme.requirementTextColor = value
        case "relationColor": requirementTheme.relationColor = value
        case "relationLabelBackground": requirementTheme.relationLabelBackground = value
        case "relationLabelColor": requirementTheme.relationLabelColor = value
        case "requirementEdgeLabelBackground": requirementTheme.requirementEdgeLabelBackground = value
        case "strokeWidth": requirementTheme.strokeWidth = value
        case "nodeTextColor": requirementTheme.nodeTextColor = value
        case "textColor": requirementTheme.textColor = value
        case "nodeBorder": requirementTheme.nodeBorder = value
        case "edgeLabelBackground": requirementTheme.edgeLabelBackground = value
        default: return false
        }
        return true
    }

    private func applyQuadrant(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.quadrantChart.") else { return false }
        hasQuadrantChartConfig = true
        switch path.replacingOccurrences(of: "config.quadrantChart.", with: "") {
        case "chartWidth": quadrantChartConfig.chartWidth = Double(value) ?? quadrantChartConfig.chartWidth
        case "chartHeight": quadrantChartConfig.chartHeight = Double(value) ?? quadrantChartConfig.chartHeight
        case "titlePadding": quadrantChartConfig.titlePadding = Double(value) ?? quadrantChartConfig.titlePadding
        case "titleFontSize": quadrantChartConfig.titleFontSize = Double(value) ?? quadrantChartConfig.titleFontSize
        case "quadrantPadding": quadrantChartConfig.quadrantPadding = Double(value) ?? quadrantChartConfig.quadrantPadding
        case "quadrantTextTopPadding": quadrantChartConfig.quadrantTextTopPadding = Double(value) ?? quadrantChartConfig.quadrantTextTopPadding
        case "quadrantLabelFontSize": quadrantChartConfig.quadrantLabelFontSize = Double(value) ?? quadrantChartConfig.quadrantLabelFontSize
        case "quadrantInternalBorderStrokeWidth": quadrantChartConfig.quadrantInternalBorderStrokeWidth = Double(value) ?? quadrantChartConfig.quadrantInternalBorderStrokeWidth
        case "quadrantExternalBorderStrokeWidth": quadrantChartConfig.quadrantExternalBorderStrokeWidth = Double(value) ?? quadrantChartConfig.quadrantExternalBorderStrokeWidth
        case "xAxisLabelPadding": quadrantChartConfig.xAxisLabelPadding = Double(value) ?? quadrantChartConfig.xAxisLabelPadding
        case "xAxisLabelFontSize": quadrantChartConfig.xAxisLabelFontSize = Double(value) ?? quadrantChartConfig.xAxisLabelFontSize
        case "xAxisPosition": quadrantChartConfig.xAxisPosition = value
        case "yAxisLabelPadding": quadrantChartConfig.yAxisLabelPadding = Double(value) ?? quadrantChartConfig.yAxisLabelPadding
        case "yAxisLabelFontSize": quadrantChartConfig.yAxisLabelFontSize = Double(value) ?? quadrantChartConfig.yAxisLabelFontSize
        case "yAxisPosition": quadrantChartConfig.yAxisPosition = value
        case "pointTextPadding": quadrantChartConfig.pointTextPadding = Double(value) ?? quadrantChartConfig.pointTextPadding
        case "pointLabelFontSize": quadrantChartConfig.pointLabelFontSize = Double(value) ?? quadrantChartConfig.pointLabelFontSize
        case "pointRadius": quadrantChartConfig.pointRadius = Double(value) ?? quadrantChartConfig.pointRadius
        case "useMaxWidth": quadrantChartConfig.useMaxWidth = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyTimeline(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.timeline.") else { return false }
        hasTimelineSection = true
        switch path.replacingOccurrences(of: "config.timeline.", with: "") {
        case "disableMulticolor": timelineConfig.disableMulticolor = (value.lowercased() == "true")
        case "leftMargin": timelineConfig.leftMargin = Double(value) ?? timelineConfig.leftMargin
        case "padding": timelineConfig.padding = Double(value) ?? timelineConfig.padding
        case "useMaxWidth": timelineConfig.useMaxWidth = (value.lowercased() == "true")
        case "useWidth": timelineConfig.useWidth = Double(value)
        case "taskFontSize": timelineConfig.taskFontSize = Double(value) ?? timelineConfig.taskFontSize
        case "taskFontFamily": timelineConfig.taskFontFamily = value
        case "textPlacement": timelineConfig.textPlacement = value
        case "width": timelineConfig.width = Double(value) ?? timelineConfig.width
        case "height": timelineConfig.height = Double(value) ?? timelineConfig.height
        default: break
        }
        return true
    }

    private func applyTimelineTheme(_ path: String, _ value: String) -> Bool {
        guard let key = _timelineThemeSubKey(from: path) else { return false }
        if _applyTimelineThemeValue(key, value: value, theme: &timelineTheme) { hasTimelineTheme = true }
        return true
    }

    private func applyGitGraphTheme(_ path: String, _ value: String) -> Bool {
        guard let key = _gitGraphThemeSubKey(from: path) else { return false }
        if _applyGitGraphThemeValue(key, value: value, theme: &gitGraphTheme) { hasGitGraphTheme = true }
        return true
    }

    private func applyQuadrantTheme(_ path: String, _ value: String) -> Bool {
        let prefix: String
        if path.hasPrefix("config.themeVariables.") {
            prefix = "config.themeVariables."
        } else if path.hasPrefix("themeVariables.") {
            prefix = "themeVariables."
        } else {
            return false
        }
        let key = String(path.dropFirst(prefix.count))
        guard _isQuadrantThemeKey(key) else { return false }
        hasQuadrantChartTheme = true
        _ = _applyQuadrantThemeValue(key, value: value, theme: &quadrantChartTheme)
        return true
    }

    private func applyGitGraph(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.gitGraph.") else { return false }
        hasGitGraphSection = true
        let key = path.replacingOccurrences(of: "config.gitGraph.", with: "")
        if key.hasPrefix("nodeLabel.") {
            switch key.replacingOccurrences(of: "nodeLabel.", with: "") {
            case "width": gitGraphConfig.nodeLabel.width = Double(value) ?? gitGraphConfig.nodeLabel.width
            case "height": gitGraphConfig.nodeLabel.height = Double(value) ?? gitGraphConfig.nodeLabel.height
            case "x": gitGraphConfig.nodeLabel.x = Double(value) ?? gitGraphConfig.nodeLabel.x
            case "y": gitGraphConfig.nodeLabel.y = Double(value) ?? gitGraphConfig.nodeLabel.y
            default: break
            }
            return true
        }
        switch key {
        case "titleTopMargin": gitGraphConfig.titleTopMargin = Double(value) ?? gitGraphConfig.titleTopMargin
        case "diagramPadding": gitGraphConfig.diagramPadding = Double(value) ?? gitGraphConfig.diagramPadding
        case "mainBranchName": gitGraphConfig.mainBranchName = value
        case "mainBranchOrder": gitGraphConfig.mainBranchOrder = Int(value) ?? gitGraphConfig.mainBranchOrder
        case "showCommitLabel": gitGraphConfig.showCommitLabel = (value.lowercased() == "true")
        case "showBranches": gitGraphConfig.showBranches = (value.lowercased() == "true")
        case "rotateCommitLabel": gitGraphConfig.rotateCommitLabel = (value.lowercased() == "true")
        case "parallelCommits": gitGraphConfig.parallelCommits = (value.lowercased() == "true")
        case "arrowMarkerAbsolute": gitGraphConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
        case "useMaxWidth": gitGraphConfig.useMaxWidth = (value.lowercased() == "true")
        case "useWidth": gitGraphConfig.useWidth = Double(value)
        default: break
        }
        return true
    }

    private func applySankey(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.sankey.") else { return false }
        hasSankeySection = true
        let key = path.replacingOccurrences(of: "config.sankey.", with: "")
        if key.hasPrefix("nodeColors.") {
            sankeyConfig.nodeColors[_unquote(key.replacingOccurrences(of: "nodeColors.", with: ""))] = value
            return true
        }
        switch key {
        case "width": sankeyConfig.width = Double(value) ?? sankeyConfig.width
        case "height": sankeyConfig.height = Double(value) ?? sankeyConfig.height
        case "linkColor":
            switch value.lowercased() {
            case "source": sankeyConfig.linkColor = .source
            case "target": sankeyConfig.linkColor = .target
            case "gradient": sankeyConfig.linkColor = .gradient
            default: sankeyConfig.linkColor = .fixed(value)
            }
        case "nodeAlignment": sankeyConfig.nodeAlignment = SankeyNodeAlignment(rawValue: value.lowercased()) ?? sankeyConfig.nodeAlignment
        case "useMaxWidth": sankeyConfig.useMaxWidth = (value.lowercased() == "true")
        case "showValues": sankeyConfig.showValues = (value.lowercased() == "true")
        case "prefix": sankeyConfig.prefix = value
        case "suffix": sankeyConfig.suffix = value
        case "nodeWidth": sankeyConfig.nodeWidth = Double(value) ?? sankeyConfig.nodeWidth
        case "nodePadding": sankeyConfig.nodePadding = Double(value) ?? sankeyConfig.nodePadding
        case "labelStyle": sankeyConfig.labelStyle = SankeyLabelStyle(rawValue: value.lowercased()) ?? sankeyConfig.labelStyle
        default: break
        }
        return true
    }

    private func applyMindmap(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.mindmap.") else { return false }
        hasMindmapSection = true
        switch path.replacingOccurrences(of: "config.mindmap.", with: "") {
        case "padding": mindmapConfig.padding = Double(value) ?? mindmapConfig.padding
        case "maxNodeWidth": mindmapConfig.maxNodeWidth = Double(value) ?? mindmapConfig.maxNodeWidth
        case "useMaxWidth": mindmapConfig.useMaxWidth = (value.lowercased() == "true")
        case "layoutAlgorithm": mindmapConfig.layoutAlgorithm = value
        default: break
        }
        return true
    }

    private func applyBlock(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.block.") else { return false }
        hasBlockSection = true
        switch path.replacingOccurrences(of: "config.block.", with: "") {
        case "padding": blockConfig.padding = Double(value) ?? 8
        case "useMaxWidth": blockConfig.useMaxWidth = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyPacket(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.packet.") {
            hasPacketSection = true
            switch path.replacingOccurrences(of: "config.packet.", with: "") {
            case "rowHeight": packetConfig.rowHeight = Double(value) ?? packetConfig.rowHeight
            case "bitWidth": packetConfig.bitWidth = Double(value) ?? packetConfig.bitWidth
            case "bitsPerRow": packetConfig.bitsPerRow = Int(value) ?? packetConfig.bitsPerRow
            case "showBits": packetConfig.showBits = (value.lowercased() == "true")
            case "paddingX": packetConfig.paddingX = Double(value) ?? packetConfig.paddingX
            case "paddingY": packetConfig.paddingY = Double(value) ?? packetConfig.paddingY
            case "useMaxWidth": packetConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        guard let key = _packetThemeSubKey(from: path) else { return false }
        if _applyPacketThemeValue(key, value: value, theme: &packetTheme) { hasPacketTheme = true }
        return true
    }

    private func applyKanban(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.kanban.") else { return false }
        hasKanbanSection = true
        switch path.replacingOccurrences(of: "config.kanban.", with: "") {
        case "padding": kanbanConfig.padding = Double(value) ?? kanbanConfig.padding
        case "sectionWidth": kanbanConfig.sectionWidth = Double(value) ?? kanbanConfig.sectionWidth
        case "ticketBaseUrl": kanbanConfig.ticketBaseUrl = value
        case "useMaxWidth": kanbanConfig.useMaxWidth = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyArchitecture(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.architecture.") {
            hasArchSection = true
            switch path.replacingOccurrences(of: "config.architecture.", with: "") {
            case "padding": archConfig.padding = Double(value) ?? archConfig.padding
            case "iconSize": archConfig.iconSize = Double(value) ?? archConfig.iconSize
            case "fontSize": archConfig.fontSize = Double(value) ?? archConfig.fontSize
            case "randomize": archConfig.randomize = (value.lowercased() == "true")
            case "useMaxWidth": archConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        guard let key = _archThemeSubKey(from: path) else { return false }
        if _applyArchThemeValue(key, value: value, theme: &archTheme) { hasArchTheme = true }
        return true
    }

    private func applyRadar(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.radar.") {
            radar.hasConfig = true
            switch path.replacingOccurrences(of: "config.radar.", with: "") {
            case "width": radar.config.width = Double(value) ?? radar.config.width
            case "height": radar.config.height = Double(value) ?? radar.config.height
            case "marginTop": radar.config.marginTop = Double(value) ?? radar.config.marginTop
            case "marginRight": radar.config.marginRight = Double(value) ?? radar.config.marginRight
            case "marginBottom": radar.config.marginBottom = Double(value) ?? radar.config.marginBottom
            case "marginLeft": radar.config.marginLeft = Double(value) ?? radar.config.marginLeft
            case "axisScaleFactor": radar.config.axisScaleFactor = Double(value) ?? radar.config.axisScaleFactor
            case "axisLabelFactor": radar.config.axisLabelFactor = Double(value) ?? radar.config.axisLabelFactor
            case "curveTension": radar.config.curveTension = Double(value) ?? radar.config.curveTension
            case "useMaxWidth": radar.config.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        guard let key = _radarThemeSubKey(from: path) else { return false }
        if _applyRadarThemeValue(key, value: value, theme: &radar.theme) { radar.hasTheme = true }
        return true
    }

    private func applyTreemap(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.treemap.") {
            hasTreemapSection = true
            let key = path.replacingOccurrences(of: "config.treemap.", with: "")
            switch key {
            case "useMaxWidth": treemapConfig.useMaxWidth = (value.lowercased() == "true")
            case "padding": treemapConfig.padding = Double(value) ?? treemapConfig.padding
            case "diagramPadding": treemapConfig.diagramPadding = Double(value) ?? treemapConfig.diagramPadding
            case "showValues": treemapConfig.showValues = (value.lowercased() == "true")
            case "nodeWidth": treemapConfig.nodeWidth = Double(value) ?? treemapConfig.nodeWidth
            case "nodeHeight": treemapConfig.nodeHeight = Double(value) ?? treemapConfig.nodeHeight
            case "borderWidth": treemapConfig.borderWidth = Double(value) ?? treemapConfig.borderWidth
            case "valueFontSize": treemapConfig.valueFontSize = Double(value) ?? treemapConfig.valueFontSize
            case "labelFontSize": treemapConfig.labelFontSize = Double(value) ?? treemapConfig.labelFontSize
            case "valueFormat": treemapConfig.valueFormat = value
            default: break
            }
            return true
        }
        if let subKey = _treemapThemeSubKey(from: path) {
            treemapThemeVariables[subKey] = value
            hasTreemapTheme = true
            return true
        }
        return false
    }

    private func applyVenn(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.venn.") {
            hasVennSection = true
            let key = path.replacingOccurrences(of: "config.venn.", with: "")
            switch key {
            case "useMaxWidth": vennConfig.useMaxWidth = (value.lowercased() == "true")
            case "width": vennConfig.width = Double(value) ?? vennConfig.width
            case "height": vennConfig.height = Double(value) ?? vennConfig.height
            case "padding": vennConfig.padding = Double(value) ?? vennConfig.padding
            case "useDebugLayout": vennConfig.useDebugLayout = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        if let subKey = _vennThemeSubKey(from: path) {
            vennThemeVariables[subKey] = value
            hasVennTheme = true
            return true
        }
        return false
    }

    private func applyIshikawa(_ path: String, _ value: String) -> Bool {
        guard path.hasPrefix("config.ishikawa.") else { return false }
        hasIshikawaSection = true
        let key = path.replacingOccurrences(of: "config.ishikawa.", with: "")
        switch key {
        case "diagramPadding": ishikawaConfig.diagramPadding = Double(value) ?? ishikawaConfig.diagramPadding
        case "useMaxWidth": ishikawaConfig.useMaxWidth = (value.lowercased() == "true")
        default: break
        }
        return true
    }

    private func applyTreeView(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.treeView.") {
            hasTreeViewSection = true
            let key = path.replacingOccurrences(of: "config.treeView.", with: "")
            switch key {
            case "rowIndent": treeViewConfig.rowIndent = Double(value) ?? treeViewConfig.rowIndent
            case "paddingX": treeViewConfig.paddingX = Double(value) ?? treeViewConfig.paddingX
            case "paddingY": treeViewConfig.paddingY = Double(value) ?? treeViewConfig.paddingY
            case "lineThickness": treeViewConfig.lineThickness = Double(value) ?? treeViewConfig.lineThickness
            case "showIcons": treeViewConfig.showIcons = (value.lowercased() == "true")
            case "useMaxWidth": treeViewConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        if let subKey = _treeViewThemeSubKey(from: path) {
            _applyTreeViewThemeValue(subKey, value: value, theme: &treeViewTheme)
            hasTreeViewTheme = true
            return true
        }
        return false
    }

    private func applyEventModeling(_ path: String, _ value: String) -> Bool {
        if path.hasPrefix("config.eventmodeling.") {
            hasEventModelingSection = true
            let key = path.replacingOccurrences(of: "config.eventmodeling.", with: "")
            switch key {
            case "padding": eventmodelingConfig.padding = Double(value) ?? eventmodelingConfig.padding
            case "rowHeight": eventmodelingConfig.rowHeight = Double(value) ?? eventmodelingConfig.rowHeight
            case "useMaxWidth": eventmodelingConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            return true
        }
        if _isEventModelingThemeKey(path) {
            _applyEventModelingThemeValue(path, value: value)
            hasEventModelingTheme = true
            return true
        }
        return false
    }

    private func applyWardley(_ path: String, _ value: String) -> Bool {
        let configPrefixes = ["config.wardley-beta.", "config.wardleyBeta."]
        for prefix in configPrefixes {
            if path.hasPrefix(prefix) {
                let key = String(path.dropFirst(prefix.count))
                if _applyWardleyConfigValue(key, value: value, config: &wardleyConfig) {
                    hasWardleySection = true
                }
                return true
            }
        }
        if let subKey = _wardleyThemeSubKey(from: path) {
            if _applyWardleyThemeValue(subKey, value: value, theme: &wardleyTheme) {
                hasWardleyTheme = true
            }
            return true
        }
        return false
    }

    private func _isEventModelingThemeKey(_ path: String) -> Bool {
        let emKeys: Set<String> = [
            "config.themeVariables.emUiFill",
            "config.themeVariables.emUiStroke",
            "config.themeVariables.emProcessorFill",
            "config.themeVariables.emProcessorStroke",
            "config.themeVariables.emReadModelFill",
            "config.themeVariables.emReadModelStroke",
            "config.themeVariables.emCommandFill",
            "config.themeVariables.emCommandStroke",
            "config.themeVariables.emEventFill",
            "config.themeVariables.emEventStroke",
            "config.themeVariables.emSwimlaneBackgroundOdd",
            "config.themeVariables.emSwimlaneBackgroundStroke",
            "config.themeVariables.emRelationStroke",
            "config.themeVariables.emArrowhead",
        ]
        return emKeys.contains(path)
    }

    private func _applyEventModelingThemeValue(_ path: String, value: String) {
        let key = path.replacingOccurrences(of: "config.themeVariables.", with: "")
        switch key {
        case "emUiFill": eventmodelingThemeVariables.emUiFill = value
        case "emUiStroke": eventmodelingThemeVariables.emUiStroke = value
        case "emProcessorFill": eventmodelingThemeVariables.emProcessorFill = value
        case "emProcessorStroke": eventmodelingThemeVariables.emProcessorStroke = value
        case "emReadModelFill": eventmodelingThemeVariables.emReadModelFill = value
        case "emReadModelStroke": eventmodelingThemeVariables.emReadModelStroke = value
        case "emCommandFill": eventmodelingThemeVariables.emCommandFill = value
        case "emCommandStroke": eventmodelingThemeVariables.emCommandStroke = value
        case "emEventFill": eventmodelingThemeVariables.emEventFill = value
        case "emEventStroke": eventmodelingThemeVariables.emEventStroke = value
        case "emSwimlaneBackgroundOdd": eventmodelingThemeVariables.emSwimlaneBackgroundOdd = value
        case "emSwimlaneBackgroundStroke": eventmodelingThemeVariables.emSwimlaneBackgroundStroke = value
        case "emRelationStroke": eventmodelingThemeVariables.emRelationStroke = value
        case "emArrowhead": eventmodelingThemeVariables.emArrowhead = value
        default: break
        }
    }

    private func applyGlobal(_ path: String, _ value: String) -> Bool {
        switch path {
        case "config.layout":
            hasErSection = true
            erConfig.layout = value
            frontmatter.layout = value
        case "config.look":
            hasErSection = true
            erConfig.look = value
            frontmatter.look = value
        case "config.htmlLabels":
            hasErSection = true
            erConfig.htmlLabels = (value.lowercased() == "true")
            frontmatter.htmlLabels = (value.lowercased() == "true")
        case "config.theme":
            frontmatter.theme = value
        case "config.fontSize":
            frontmatter.fontSize = Double(value)
        case "config.securityLevel":
            frontmatter.securityLevel = value
        default:
            return false
        }
        return true
    }

    private func finalize() {
        if hasFlowchartSection || frontmatter.securityLevel != nil {
            if let sl = frontmatter.securityLevel { flowchartConfig.securityLevel = sl }
            frontmatter.flowchartConfig = flowchartConfig
        }
        if hasClassSection { frontmatter.classConfig = classConfig }
        if hasErSection { frontmatter.erConfig = erConfig }
        if hasXYChartConfig { frontmatter.xyChartConfig = xyChartConfig }
        if hasXYChartTheme { frontmatter.xyChartTheme = xyChartTheme }
        if hasPieConfig { frontmatter.pieConfig = pieConfig }
        if hasPieTheme { frontmatter.pieTheme = pieTheme }
        if hasSequenceSection { frontmatter.sequenceConfig = sequenceConfig }
        if hasStateSection || frontmatter.securityLevel != nil {
            if let sl = frontmatter.securityLevel { stateConfig.securityLevel = sl }
            frontmatter.stateConfig = stateConfig
        }
        if hasJourneySection { frontmatter.journeyConfig = journeyConfig }
        if hasGanttSection { frontmatter.ganttConfig = ganttConfig }
        if hasQuadrantChartConfig { frontmatter.quadrantChartConfig = quadrantChartConfig }
        if hasQuadrantChartTheme { frontmatter.quadrantChartTheme = quadrantChartTheme }
        if hasRequirementSection { frontmatter.requirementConfig = requirementConfig }
        if hasRequirementTheme { frontmatter.requirementTheme = requirementTheme }
        if hasGitGraphSection { frontmatter.gitGraphConfig = gitGraphConfig }
        if hasGitGraphTheme { frontmatter.gitGraphTheme = gitGraphTheme }
        if hasMindmapSection { frontmatter.mindmapConfig = mindmapConfig }
        if hasTimelineSection { frontmatter.timelineConfig = timelineConfig }
        if hasTimelineTheme { frontmatter.timelineTheme = timelineTheme }
        if hasSankeySection { frontmatter.sankeyConfig = sankeyConfig }
        if hasBlockSection { frontmatter.blockConfig = blockConfig }
        if hasPacketSection { frontmatter.packetConfig = packetConfig }
        if hasPacketTheme { frontmatter.packetTheme = packetTheme }
        if hasKanbanSection { frontmatter.kanbanConfig = kanbanConfig }
        if hasArchSection { frontmatter.archConfig = archConfig }
        if hasArchTheme { frontmatter.archTheme = archTheme }
        if radar.hasConfig { frontmatter.radarConfig = radar.config }
        if radar.hasTheme { frontmatter.radarTheme = radar.theme }
        if hasTreemapSection { frontmatter.treemapConfig = treemapConfig }
        if hasTreemapTheme { frontmatter.treemapThemeVariables = treemapThemeVariables }
        if hasVennSection { frontmatter.vennConfig = vennConfig }
        if hasVennTheme { frontmatter.vennThemeVariables = vennThemeVariables }
        if hasIshikawaSection { frontmatter.ishikawaConfig = ishikawaConfig }
        if hasTreeViewSection { frontmatter.treeViewConfig = treeViewConfig }
        if hasTreeViewTheme { frontmatter.treeViewTheme = treeViewTheme }
        if hasEventModelingSection { frontmatter.eventmodelingConfig = eventmodelingConfig }
        if hasEventModelingTheme { frontmatter.eventmodelingThemeVariables = eventmodelingThemeVariables }
        if hasWardleySection { frontmatter.wardleyBetaConfig = wardleyConfig }
        if hasWardleyTheme { frontmatter.wardleyTheme = wardleyTheme }
    }
}


private func _gitGraphThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.gitGraph.", "themeVariables.gitGraph."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isGitGraphThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isGitGraphThemeKey(_ key: String) -> Bool {
    switch key {
    case "git0", "git1", "git2", "git3", "git4", "git5", "git6", "git7",
         "gitInv0", "gitInv1", "gitInv2", "gitInv3", "gitInv4", "gitInv5", "gitInv6", "gitInv7",
         "gitBranchLabel0", "gitBranchLabel1", "gitBranchLabel2", "gitBranchLabel3",
         "gitBranchLabel4", "gitBranchLabel5", "gitBranchLabel6", "gitBranchLabel7",
         "commitLabelColor", "commitLabelBackground", "commitLabelFontSize",
         "tagLabelColor", "tagLabelBackground", "tagLabelBorder", "tagLabelFontSize",
         "nodeBorder", "mainBkg", "strokeWidth", "useGradient", "gradientStart",
         "gradientStop", "dropShadow", "filterColor", "fontFamily", "textColor",
         "primaryColor", "secondaryColor", "tertiaryColor", "primaryTextColor",
         "labelTextColor", "lineColor", "noteFontWeight":
        return true
    default:
        return false
    }
}

private func _applyGitGraphThemeValue(_ key: String, value: String, theme: inout GitGraphThemeConfig) -> Bool {
    switch key {
    case "git0": theme.git0 = value
    case "git1": theme.git1 = value
    case "git2": theme.git2 = value
    case "git3": theme.git3 = value
    case "git4": theme.git4 = value
    case "git5": theme.git5 = value
    case "git6": theme.git6 = value
    case "git7": theme.git7 = value
    case "gitInv0": theme.gitInv0 = value
    case "gitInv1": theme.gitInv1 = value
    case "gitInv2": theme.gitInv2 = value
    case "gitInv3": theme.gitInv3 = value
    case "gitInv4": theme.gitInv4 = value
    case "gitInv5": theme.gitInv5 = value
    case "gitInv6": theme.gitInv6 = value
    case "gitInv7": theme.gitInv7 = value
    case "gitBranchLabel0": theme.gitBranchLabel0 = value
    case "gitBranchLabel1": theme.gitBranchLabel1 = value
    case "gitBranchLabel2": theme.gitBranchLabel2 = value
    case "gitBranchLabel3": theme.gitBranchLabel3 = value
    case "gitBranchLabel4": theme.gitBranchLabel4 = value
    case "gitBranchLabel5": theme.gitBranchLabel5 = value
    case "gitBranchLabel6": theme.gitBranchLabel6 = value
    case "gitBranchLabel7": theme.gitBranchLabel7 = value
    case "commitLabelColor": theme.commitLabelColor = value
    case "commitLabelBackground": theme.commitLabelBackground = value
    case "commitLabelFontSize": theme.commitLabelFontSize = value
    case "tagLabelColor": theme.tagLabelColor = value
    case "tagLabelBackground": theme.tagLabelBackground = value
    case "tagLabelBorder": theme.tagLabelBorder = value
    case "tagLabelFontSize": theme.tagLabelFontSize = value
    case "nodeBorder": theme.nodeBorder = value
    case "mainBkg": theme.mainBkg = value
    case "strokeWidth": theme.strokeWidth = value
    case "useGradient": theme.useGradient = (value.lowercased() == "true")
    case "gradientStart": theme.gradientStart = value
    case "gradientStop": theme.gradientStop = value
    case "dropShadow": theme.dropShadow = value
    case "filterColor": theme.filterColor = value
    case "fontFamily": theme.fontFamily = value
    case "textColor": theme.textColor = value
    case "primaryColor": theme.primaryColor = value
    case "secondaryColor": theme.secondaryColor = value
    case "tertiaryColor": theme.tertiaryColor = value
    case "primaryTextColor": theme.primaryTextColor = value
    case "labelTextColor": theme.labelTextColor = value
    case "lineColor": theme.lineColor = value
    case "noteFontWeight": theme.noteFontWeight = value
    default: return false
    }
    return true
}

private func _pieThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.pie.", "themeVariables.pie."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isPieThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isPieThemeKey(_ key: String) -> Bool {
    switch key {
    case "pie1", "pie2", "pie3", "pie4", "pie5", "pie6",
         "pie7", "pie8", "pie9", "pie10", "pie11", "pie12",
         "pieTitleTextSize", "pieTitleTextColor",
         "pieSectionTextSize", "pieSectionTextColor",
         "pieLegendTextSize", "pieLegendTextColor",
         "pieStrokeColor", "pieStrokeWidth",
         "pieOuterStrokeWidth", "pieOuterStrokeColor",
         "pieOpacity", "fontFamily":
        return true
    default:
        return false
    }
}

private func _applyPieThemeValue(_ key: String, value: String, theme: inout PieChartThemeConfig) -> Bool {
    switch key {
    case "pie1": theme.pie1 = value
    case "pie2": theme.pie2 = value
    case "pie3": theme.pie3 = value
    case "pie4": theme.pie4 = value
    case "pie5": theme.pie5 = value
    case "pie6": theme.pie6 = value
    case "pie7": theme.pie7 = value
    case "pie8": theme.pie8 = value
    case "pie9": theme.pie9 = value
    case "pie10": theme.pie10 = value
    case "pie11": theme.pie11 = value
    case "pie12": theme.pie12 = value
    case "pieTitleTextSize": theme.pieTitleTextSize = value
    case "pieTitleTextColor": theme.pieTitleTextColor = value
    case "pieSectionTextSize": theme.pieSectionTextSize = value
    case "pieSectionTextColor": theme.pieSectionTextColor = value
    case "pieLegendTextSize": theme.pieLegendTextSize = value
    case "pieLegendTextColor": theme.pieLegendTextColor = value
    case "pieStrokeColor": theme.pieStrokeColor = value
    case "pieStrokeWidth": theme.pieStrokeWidth = value
    case "pieOuterStrokeWidth": theme.pieOuterStrokeWidth = value
    case "pieOuterStrokeColor": theme.pieOuterStrokeColor = value
    case "pieOpacity": theme.pieOpacity = value
    case "fontFamily": theme.fontFamily = value
    default: return false
    }
    return true
}

// MARK: - Quadrant Chart theme helpers

private func _isQuadrantThemeKey(_ key: String) -> Bool {
    switch key {
    case "quadrant1Fill", "quadrant2Fill", "quadrant3Fill", "quadrant4Fill",
         "quadrant1TextFill", "quadrant2TextFill", "quadrant3TextFill", "quadrant4TextFill",
         "quadrantPointFill", "quadrantPointTextFill",
         "quadrantXAxisTextFill", "quadrantYAxisTextFill",
         "quadrantInternalBorderStrokeFill", "quadrantExternalBorderStrokeFill",
         "quadrantTitleFill":
        return true
    default:
        return false
    }
}

private func _applyQuadrantThemeValue(_ key: String, value: String, theme: inout QuadrantChartThemeConfig) -> Bool {
    switch key {
    case "quadrant1Fill": theme.quadrant1Fill = value
    case "quadrant2Fill": theme.quadrant2Fill = value
    case "quadrant3Fill": theme.quadrant3Fill = value
    case "quadrant4Fill": theme.quadrant4Fill = value
    case "quadrant1TextFill": theme.quadrant1TextFill = value
    case "quadrant2TextFill": theme.quadrant2TextFill = value
    case "quadrant3TextFill": theme.quadrant3TextFill = value
    case "quadrant4TextFill": theme.quadrant4TextFill = value
    case "quadrantPointFill": theme.quadrantPointFill = value
    case "quadrantPointTextFill": theme.quadrantPointTextFill = value
    case "quadrantXAxisTextFill": theme.quadrantXAxisTextFill = value
    case "quadrantYAxisTextFill": theme.quadrantYAxisTextFill = value
    case "quadrantInternalBorderStrokeFill": theme.quadrantInternalBorderStrokeFill = value
    case "quadrantExternalBorderStrokeFill": theme.quadrantExternalBorderStrokeFill = value
    case "quadrantTitleFill": theme.quadrantTitleFill = value
    default: return false
    }
    return true
}

/// Strip surrounding quotes from a string.

private func _stripYamlComment(_ line: String) -> String {
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for idx in line.indices {
        let ch = line[idx]
        if inQuote {
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            continue
        }

        if ch == "#" {
            return String(line[..<idx]).trimmingCharacters(in: .whitespaces)
        }
    }

    return line
}

private func _parseYamlStringArray(_ value: String) -> [String]? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }

    let innerStart = trimmed.index(after: trimmed.startIndex)
    let innerEnd = trimmed.index(before: trimmed.endIndex)
    let inner = String(trimmed[innerStart..<innerEnd])
    if inner.trimmingCharacters(in: .whitespaces).isEmpty {
        return []
    }

    var items: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in inner {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if ch == "," {
            items.append(_unquote(current))
            current = ""
        } else {
            current.append(ch)
        }
    }

    items.append(_unquote(current))
    return items
}

// MARK: - Timeline Theme helpers

private func _timelineThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isTimelineThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isTimelineThemeKey(_ key: String) -> Bool {
    switch key {
    case "cScale0", "cScale1", "cScale2", "cScale3", "cScale4", "cScale5",
         "cScale6", "cScale7", "cScale8", "cScale9", "cScale10", "cScale11",
         "cScaleLabel0", "cScaleLabel1", "cScaleLabel2", "cScaleLabel3",
         "cScaleLabel4", "cScaleLabel5", "cScaleLabel6", "cScaleLabel7",
         "cScaleLabel8", "cScaleLabel9", "cScaleLabel10", "cScaleLabel11",
         "cScaleInv0", "cScaleInv1", "cScaleInv2", "cScaleInv3",
         "cScaleInv4", "cScaleInv5", "cScaleInv6", "cScaleInv7",
         "cScaleInv8", "cScaleInv9", "cScaleInv10", "cScaleInv11",
         "THEME_COLOR_LIMIT", "fontFamily", "fontSize",
         "mainBkg", "nodeBorder", "borderColorArray",
         "useGradient", "gradientStart", "gradientStop", "dropShadow":
        return true
    default:
        return false
    }
}

private func _applyTimelineThemeValue(_ key: String, value: String, theme: inout TimelineThemeConfig) -> Bool {
    switch key {
    case "cScale0": theme.cScale[0] = value
    case "cScale1": theme.cScale[1] = value
    case "cScale2": theme.cScale[2] = value
    case "cScale3": theme.cScale[3] = value
    case "cScale4": theme.cScale[4] = value
    case "cScale5": theme.cScale[5] = value
    case "cScale6": theme.cScale[6] = value
    case "cScale7": theme.cScale[7] = value
    case "cScale8": theme.cScale[8] = value
    case "cScale9": theme.cScale[9] = value
    case "cScale10": theme.cScale[10] = value
    case "cScale11": theme.cScale[11] = value
    case "cScaleLabel0": theme.cScaleLabel[0] = value
    case "cScaleLabel1": theme.cScaleLabel[1] = value
    case "cScaleLabel2": theme.cScaleLabel[2] = value
    case "cScaleLabel3": theme.cScaleLabel[3] = value
    case "cScaleLabel4": theme.cScaleLabel[4] = value
    case "cScaleLabel5": theme.cScaleLabel[5] = value
    case "cScaleLabel6": theme.cScaleLabel[6] = value
    case "cScaleLabel7": theme.cScaleLabel[7] = value
    case "cScaleLabel8": theme.cScaleLabel[8] = value
    case "cScaleLabel9": theme.cScaleLabel[9] = value
    case "cScaleLabel10": theme.cScaleLabel[10] = value
    case "cScaleLabel11": theme.cScaleLabel[11] = value
    case "cScaleInv0": theme.cScaleInv[0] = value
    case "cScaleInv1": theme.cScaleInv[1] = value
    case "cScaleInv2": theme.cScaleInv[2] = value
    case "cScaleInv3": theme.cScaleInv[3] = value
    case "cScaleInv4": theme.cScaleInv[4] = value
    case "cScaleInv5": theme.cScaleInv[5] = value
    case "cScaleInv6": theme.cScaleInv[6] = value
    case "cScaleInv7": theme.cScaleInv[7] = value
    case "cScaleInv8": theme.cScaleInv[8] = value
    case "cScaleInv9": theme.cScaleInv[9] = value
    case "cScaleInv10": theme.cScaleInv[10] = value
    case "cScaleInv11": theme.cScaleInv[11] = value
    case "THEME_COLOR_LIMIT": theme.themeColorLimit = Int(value) ?? theme.themeColorLimit
    case "fontFamily": theme.fontFamily = value
    case "fontSize": theme.fontSize = Double(value) ?? theme.fontSize
    case "mainBkg": theme.mainBkg = value
    case "nodeBorder": theme.nodeBorder = value
    case "useGradient": theme.useGradient = (value.lowercased() == "true")
    case "gradientStart": theme.gradientStart = value
    case "gradientStop": theme.gradientStop = value
    case "dropShadow": theme.dropShadow = value
    default: return false
    }
    return true
}

// MARK: - Packet Theme helpers

private func _packetThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.packet.", "themeVariables.packet."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    return nil
}

private func _applyPacketThemeValue(_ key: String, value: String, theme: inout PacketThemeConfig) -> Bool {
    switch key {
    case "byteFontSize": theme.byteFontSize = value
    case "startByteColor": theme.startByteColor = value
    case "endByteColor": theme.endByteColor = value
    case "labelColor": theme.labelColor = value
    case "labelFontSize": theme.labelFontSize = value
    case "titleColor": theme.titleColor = value
    case "titleFontSize": theme.titleFontSize = value
    case "blockStrokeColor": theme.blockStrokeColor = value
    case "blockStrokeWidth": theme.blockStrokeWidth = value
    case "blockFillColor": theme.blockFillColor = value
    default: return false
    }
    return true
}

// MARK: - Architecture Theme helpers

private func _archThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isArchThemeKey(subKey) {
                return subKey
            }
        }
    }
    return nil
}

private func _isArchThemeKey(_ key: String) -> Bool {
    switch key {
    case "archEdgeColor", "archEdgeArrowColor", "archEdgeWidth",
         "archGroupBorderColor", "archGroupBorderWidth":
        return true
    default:
        return false
    }
}

private func _applyArchThemeValue(_ key: String, value: String, theme: inout ArchitectureThemeConfig) -> Bool {
    switch key {
    case "archEdgeColor": theme.archEdgeColor = value
    case "archEdgeArrowColor": theme.archEdgeArrowColor = value
    case "archEdgeWidth": theme.archEdgeWidth = value
    case "archGroupBorderColor": theme.archGroupBorderColor = value
    case "archGroupBorderWidth": theme.archGroupBorderWidth = value
    default: return false
    }
    return true
}

// MARK: - Radar Theme helpers

private func _radarThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.radar.", "themeVariables.radar."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isRadarThemeKey(subKey) {
                return subKey
            }
        }
    }
    return nil
}

private func _isRadarThemeKey(_ key: String) -> Bool {
    switch key {
    case "axisColor", "axisStrokeWidth", "axisLabelFontSize",
         "curveOpacity", "curveStrokeWidth",
         "graticuleColor", "graticuleOpacity", "graticuleStrokeWidth",
         "legendBoxSize", "legendFontSize",
         "fontSize", "titleColor",
         "cScale0", "cScale1", "cScale2", "cScale3", "cScale4", "cScale5",
         "cScale6", "cScale7", "cScale8", "cScale9", "cScale10", "cScale11",
         "THEME_COLOR_LIMIT":
        return true
    default:
        return false
    }
}

private func _applyRadarThemeValue(_ key: String, value: String, theme: inout RadarThemeConfig) -> Bool {
    switch key {
    case "axisColor": theme.axisColor = value
    case "axisStrokeWidth": theme.axisStrokeWidth = Double(value) ?? theme.axisStrokeWidth
    case "axisLabelFontSize": theme.axisLabelFontSize = Double(value) ?? theme.axisLabelFontSize
    case "curveOpacity": theme.curveOpacity = Double(value) ?? theme.curveOpacity
    case "curveStrokeWidth": theme.curveStrokeWidth = Double(value) ?? theme.curveStrokeWidth
    case "graticuleColor": theme.graticuleColor = value
    case "graticuleOpacity": theme.graticuleOpacity = Double(value) ?? theme.graticuleOpacity
    case "graticuleStrokeWidth": theme.graticuleStrokeWidth = Double(value) ?? theme.graticuleStrokeWidth
    case "legendBoxSize": theme.legendBoxSize = Double(value) ?? theme.legendBoxSize
    case "legendFontSize": theme.legendFontSize = Double(value) ?? theme.legendFontSize
    case "fontSize": theme.fontSize = Double(value) ?? theme.fontSize
    case "titleColor": theme.titleColor = value
    case "cScale0": theme.cScale[0] = value
    case "cScale1": theme.cScale[1] = value
    case "cScale2": theme.cScale[2] = value
    case "cScale3": theme.cScale[3] = value
    case "cScale4": theme.cScale[4] = value
    case "cScale5": theme.cScale[5] = value
    case "cScale6": theme.cScale[6] = value
    case "cScale7": theme.cScale[7] = value
    case "cScale8": theme.cScale[8] = value
    case "cScale9": theme.cScale[9] = value
    case "cScale10": theme.cScale[10] = value
    case "cScale11": theme.cScale[11] = value
    case "THEME_COLOR_LIMIT": theme.themeColorLimit = Int(value) ?? theme.themeColorLimit
    default: return false
    }
    return true
}

private func _treemapThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isTreemapThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("treemap.") {
                let inner = String(subKey.dropFirst(8))
                if _isTreemapThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

private func _isTreemapThemeKey(_ key: String) -> Bool {
    if key.hasPrefix("cScale") {
        let num = String(key.dropFirst(6))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    if key.hasPrefix("cScalePeer") {
        let num = String(key.dropFirst(10))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    if key.hasPrefix("cScaleLabel") {
        let num = String(key.dropFirst(11))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    switch key {
    case "titleColor", "textColor": return true
    default: return false
    }
}

private func _vennThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isVennThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("venn.") {
                let inner = String(subKey.dropFirst(5))
                if _isVennThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

private func _isVennThemeKey(_ key: String) -> Bool {
    if key.hasPrefix("venn"), key.count >= 5 {
        let numStr = String(key.dropFirst(4))
        if let n = Int(numStr), n >= 1, n <= 8 {
            return true
        }
    }
    switch key {
    case "vennTitleTextColor", "vennSetTextColor": return true
    default: return false
    }
}

// MARK: - TreeView Theme Helpers

private func _treeViewThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isTreeViewThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("treeView.") {
                let inner = String(subKey.dropFirst(9))
                if _isTreeViewThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

private func _isTreeViewThemeKey(_ key: String) -> Bool {
    switch key {
    case "labelFontSize", "labelColor", "lineColor", "iconColor",
         "descriptionColor", "highlightBg", "highlightStroke":
        return true
    default:
        return false
    }
}

private func _applyTreeViewThemeValue(_ key: String, value: String, theme: inout TreeViewThemeVariables) {
    switch key {
    case "labelFontSize": theme.labelFontSize = value
    case "labelColor": theme.labelColor = value
    case "lineColor": theme.lineColor = value
    case "iconColor": theme.iconColor = value
    case "descriptionColor": theme.descriptionColor = value
    case "highlightBg": theme.highlightBg = value
    case "highlightStroke": theme.highlightStroke = value
    default: break
    }
}

// MARK: - EventModeling theme helpers

private func _isEMThemePath(_ fullPath: String) -> Bool {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isEMThemeKey(subKey)
        }
    }
    return false
}

private func _isEMThemeKey(_ key: String) -> Bool {
    switch key {
    case "emUiFill", "emUiStroke",
         "emProcessorFill", "emProcessorStroke",
         "emReadModelFill", "emReadModelStroke",
         "emCommandFill", "emCommandStroke",
         "emEventFill", "emEventStroke",
         "emSwimlaneBackgroundOdd", "emSwimlaneBackgroundStroke",
         "emRelationStroke", "emArrowhead":
        return true
    default:
        return false
    }
}
