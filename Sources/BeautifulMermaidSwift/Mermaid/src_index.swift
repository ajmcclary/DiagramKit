// Ported from original/src/index.ts
import Foundation

public struct RenderOptions: Sendable {
    public var bg: String?
    public var fg: String?
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?
    public var font: String?
    public var transparent: Bool?
    public var interactive: Bool?

    public init(
        bg: String? = nil,
        fg: String? = nil,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil,
        font: String? = nil,
        transparent: Bool? = nil,
        interactive: Bool? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.font = font
        self.transparent = transparent
        self.interactive = interactive
    }
}

public struct DiagramColors: Sendable {
    public var bg: String
    public var fg: String
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?
    public var noteBkg: String?
    public var noteBorder: String?

    public init(
        bg: String,
        fg: String,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil,
        noteBkg: String? = nil,
        noteBorder: String? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.noteBkg = noteBkg
        self.noteBorder = noteBorder
    }
}

private enum _IndexDefaults {
    static let bg = "#FFFFFF"
    static let fg = "#27272A"
}

private enum _DiagramRoutingType {
    case flowchart
    case sequence
    case `class`
    case er
    case xychart
    case pie
    case journey
    case gantt
    case quadrant
    case requirement
    case gitgraph
    case mindmap
    case timeline
    case sankey
    case block
    case packet
    case kanban
    case architecture
    case radar
    case treemap
    case venn
    case ishikawa
    case treeView
    case eventmodeling
    case wardley
    case c4
    case zenuml
}

private func _decodeXML(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func detectDiagramType(_ text: String) -> _DiagramRoutingType {
    let firstStatement = _firstDiagramStatement(in: text)
    let firstLine = firstStatement.lowercased()

    if firstLine.range(of: "^sequencediagram\\s*$", options: .regularExpression) != nil {
        return .sequence
    }
    if firstLine.range(of: #"^classdiagram(-v2)?\s*$"#, options: .regularExpression) != nil {
        return .class
    }
    if firstLine.range(of: "^erdiagram\\s*$", options: .regularExpression) != nil {
        return .er
    }
    if firstLine.hasPrefix("xychart") {
        return .xychart
    }
    if firstLine.hasPrefix("pie") {
        return .pie
    }
    if firstLine.hasPrefix("journey") {
        return .journey
    }
    if firstLine.hasPrefix("gantt") {
        return .gantt
    }
    if firstLine.hasPrefix("quadrantchart") {
        return .quadrant
    }
    if firstLine.hasPrefix("requirement") {
        return .requirement
    }
    if firstLine.hasPrefix("gitgraph") {
        return .gitgraph
    }
    if firstLine.hasPrefix("mindmap") {
        return .mindmap
    }
    if firstLine.hasPrefix("timeline") {
        return .timeline
    }
    if firstLine.hasPrefix("sankey") {
        return .sankey
    }
    if firstLine.hasPrefix("block") {
        return .block
    }
    if firstLine.hasPrefix("packet") {
        return .packet
    }
    if firstLine.hasPrefix("kanban") {
        return .kanban
    }
    if firstLine.hasPrefix("architecture") {
        return .architecture
    }
    if firstLine.hasPrefix("radar-beta") {
        return .radar
    }
    if firstLine.hasPrefix("treemap") {
        return .treemap
    }
    if firstLine.hasPrefix("venn-beta") {
        return .venn
    }
    if firstLine.range(of: #"^ishikawa(-beta)?\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
        return .ishikawa
    }
    if firstStatement == "treeView-beta" || firstStatement.hasPrefix("treeView-beta ") || firstStatement.hasPrefix("treeView-beta\t") {
        return .treeView
    }
    if firstLine.hasPrefix("eventmodeling") {
        return .eventmodeling
    }
    if firstLine.hasPrefix("wardley-beta") {
        return .wardley
    }

    // ZenUML — case-insensitive header prefix match
    if firstLine.hasPrefix("zenuml") {
        return .zenuml
    }

    // C4 — case-sensitive full-line header match
    if firstStatement.range(of: #"^C4(?:Context|Container|Component|Dynamic|Deployment)\s*$"#, options: .regularExpression) != nil {
        return .c4
    }

    return .flowchart
}

private func _firstDiagramStatement(in text: String) -> String {
    _sourceStatementsNoPreprocess(from: text).first ?? ""
}

private func _sourceStatementsNoPreprocess(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    var parts: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in normalized {
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

        if ch.unicodeScalars.count == 1,
           let scalar = ch.unicodeScalars.first,
           separators.contains(scalar) {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("%%") {
                parts.append(trimmed)
            }
            current = ""
        } else {
            current.append(ch)
        }
    }

    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, !trimmed.hasPrefix("%%") {
        parts.append(trimmed)
    }
    return parts
}

private func buildColors(_ options: RenderOptions) -> DiagramColors {
    DiagramColors(
        bg: options.bg ?? _IndexDefaults.bg,
        fg: options.fg ?? _IndexDefaults.fg,
        line: options.line,
        accent: options.accent,
        muted: options.muted,
        surface: options.surface,
        border: options.border
    )
}

func _renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) throws -> String {
    let preprocessed = _preprocessMermaidSource(_decodeXML(text))
    return try _renderPreprocessedMermaidSVG(
        preprocessed.source,
        frontmatter: preprocessed.frontmatter,
        options: options
    )
}

private func _renderPreprocessedMermaidSVG(
    _ decodedText: String,
    frontmatter fm: DiagramFrontmatter?,
    options: RenderOptions
) throws -> String {
    let colors = buildColors(options)
    let font = options.font ?? "Inter"
    let transparent = options.transparent ?? false
    let diagramType = detectDiagramType(decodedText)

    let lines = _sourceStatementsNoPreprocess(from: decodedText)

    switch diagramType {
    case .sequence:
        return try _renderSequenceSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .class:
        return try _renderClassSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .er:
        return try _renderErSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .xychart:
        return try _renderXYChartSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .pie:
        return try _renderPieSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
    case .journey:
        return try _renderJourneySvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .gantt:
        return try _renderGanttSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .quadrant:
        return try _renderQuadrantSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
    case .requirement:
        return try _renderRequirementSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .flowchart:
        return try _renderFlowchartSvgCase(source: decodedText, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
    case .gitgraph:
        return try _renderGitGraphSvgCase(source: decodedText, fm: fm)
    case .mindmap:
        return try _renderMindmapSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .timeline:
        return try _renderTimelineSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .sankey:
        return try _renderSankeySvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .block:
        return try _renderBlockSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .packet:
        return try _renderPacketSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .kanban:
        return try _renderKanbanSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .architecture:
        return try _renderArchitectureSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .radar:
        return try _renderRadarSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .treemap:
        return try _renderTreemapSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .venn:
        return try _renderVennSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .ishikawa:
        return try _renderIshikawaSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .treeView:
        return try _renderTreeViewSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .eventmodeling:
        return try _renderEventModelingSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .wardley:
        return try _renderWardleySvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .c4:
        return try _renderC4SvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    case .zenuml:
        return try _renderZenUMLSvgCase(source: decodedText, fm: fm, colors: colors, font: font, transparent: transparent)
    }
}

private func _renderC4SvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let lines = _rawDiagramLines(from: source)
    let config = fm?.c4Config ?? C4DiagramConfig()
    var diagram = try parseC4Diagram(lines, frontmatter: fm)
    diagram.config = config
    let positioned = layoutC4Diagram(diagram)
    let diagramId = UUID().uuidString
    return try renderC4Svg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderSequenceSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseSequenceDiagram(lines)
    let positioned = try layoutSequenceDiagram(diagram, options, config: fm?.sequenceConfig ?? .default)
    return try renderSequenceSvg(positioned, colors, font, transparent)
}

private func _renderClassSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseClassDiagram(lines, frontmatter: fm)
    let positioned = try layoutClassDiagramSync(diagram, options: options)
    return try renderClassSvg(positioned, colors, font, transparent, securityLevel: fm?.securityLevel)
}

private func _renderErSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseErDiagram(lines, frontmatter: fm)
    let positioned = try layoutErDiagramSync(diagram, options: options, config: diagram.config)
    return try renderErSvg(positioned, colors, font, transparent)
}

private func _renderXYChartSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let chart = try parseXYChart(lines)
    var mutatedChart = chart
    if let fmc = fm?.xyChartConfig { mutatedChart.config = fmc }
    if let fmt = fm?.xyChartTheme { mutatedChart.theme = fmt }
    if mutatedChart.titleText == nil, let fmTitle = fm?.diagramTitle {
        mutatedChart.diagramTitle = fmTitle
    }
    let positioned = layoutXYChart(mutatedChart, options)
    return renderXYChartSvg(positioned, colors, font, transparent, interactive: options.interactive ?? false)
}

private func _renderPieSvgCase(lines: [String], fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let chart = try parsePieChart(lines, frontmatter: fm)
    let positioned = layoutPieChart(chart)
    return renderPieSvg(positioned, colors, font, transparent)
}

private func _renderJourneySvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseJourneyDiagram(lines, frontmatter: fm)
    let config = fm?.journeyConfig ?? .default
    var merged = diagram
    merged.config = config
    let positioned = layoutJourneyDiagram(merged, options: options, config: config)
    let diagramId = UUID().uuidString
    return try renderJourneySvg(positioned, colors, font, transparent, diagramId: diagramId)
}

private func _renderGanttSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let ganttLines = _sourceStatementsNoPreprocess(from: source, separatedBy: CharacterSet(charactersIn: "\n"))
    let diagram = try parseGanttDiagram(ganttLines, frontmatter: fm)
    let config = fm?.ganttConfig ?? .default
    var merged = diagram
    merged.config = config
    let positioned = layoutGanttDiagram(merged)
    let diagramId = UUID().uuidString
    return try renderGanttSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderQuadrantSvgCase(lines: [String], fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let chart = try parseQuadrantChart(lines, frontmatter: fm)
    var mutatedChart = chart
    if let fmc = fm?.quadrantChartConfig { mutatedChart.config = fmc }
    if let fmt = fm?.quadrantChartTheme { mutatedChart.theme = fmt }
    if mutatedChart.titleText == nil, let fmTitle = fm?.diagramTitle {
        mutatedChart.titleText = fmTitle
        mutatedChart.diagramTitle = fmTitle
    }
    let positioned = layoutQuadrantChart(mutatedChart)
    return renderQuadrantSvg(positioned, colors, font, transparent)
}

private func _renderRequirementSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    var diagram = try parseRequirementDiagram(lines, frontmatter: fm)
    if let fmTheme = fm?.requirementTheme { diagram.config.theme = fmTheme }
    let positioned = try layoutRequirementDiagram(diagram, options: options)
    let dId = UUID().uuidString
    return try renderRequirementSvg(positioned, colors, font, transparent,
        diagramId: dId,
        look: fm?.look,
        theme: fm?.requirementTheme,
        htmlLabels: fm?.htmlLabels)
}

private func _renderFlowchartSvgCase(source: String, fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let graph = try parseMermaid(source, config: fm?.flowchartConfig, stateConfig: fm?.stateConfig)
    let positioned = try layoutGraphSync(graph, options)
    return try renderSvg(positioned, colors, font, transparent)
}

private func _renderGitGraphSvgCase(source: String, fm: DiagramFrontmatter?) throws -> String {
    let gitLines = _sourceStatementsNoPreprocess(from: source)
    let diagram = try parseGitGraph(gitLines, frontmatter: fm)
    let positioned = layoutGitGraph(diagram)
    let diagramId = UUID().uuidString
    return renderGitGraphSvg(positioned, diagramId: diagramId)
}

private func _renderMindmapSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    let diagram = try parseMindmap(rawLines, frontmatter: fm)
    let positioned = try layoutMindmap(diagram)
    let diagramId = UUID().uuidString
    return renderMindmapSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderTimelineSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let timelineLines = _rawDiagramLines(from: source)
    var diagram = try parseTimelineDiagram(timelineLines, frontmatter: fm)
    if let fmc = fm?.timelineConfig { diagram.config = fmc }
    if let fmt = fm?.timelineTheme { diagram.theme = fmt }
    if diagram.diagramTitle == nil, let fmTitle = fm?.title {
        diagram.diagramTitle = fmTitle
    }
    diagram.themeName = fm?.theme
    diagram.look = fm?.look
    let positioned = layoutTimelineDiagram(diagram)
    let diagramId = UUID().uuidString
    return try renderTimelineSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderSankeySvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let sankeyLines = _sourceStatementsNoPreprocess(from: source)
    var diagram = try parseSankeyDiagram(sankeyLines, frontmatter: fm)
    if let fmc = fm?.sankeyConfig { diagram.config = fmc }
    let positioned = layoutSankeyDiagram(diagram)
    return renderSankeySvg(positioned, colors, font, transparent)
}

private func _renderBlockSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let blockLines = _sourceStatementsNoPreprocess(from: source, separatedBy: CharacterSet(charactersIn: "\n"))
    var diagram = try parseBlockDiagramLines(blockLines)
    if let fmc = fm?.blockConfig { diagram.config = fmc }
    if let title = fm?.diagramTitle { diagram.diagramTitle = title }
    let positioned = try layoutBlockDiagram(diagram)
    let diagramId = UUID().uuidString
    return try renderBlockSvg(positioned, diagramId: diagramId, colors: colors, fontFamily: font, transparent: transparent)
}

private func _renderPacketSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let packetLines = _sourceStatementsNoPreprocess(from: source)
    var diagram = try parsePacketDiagram(packetLines, frontmatter: fm)
    if diagram.diagramTitle == nil, let title = fm?.diagramTitle {
        diagram.diagramTitle = title
    }
    let positioned = layoutPacketDiagram(diagram)
    return renderPacketSvg(positioned, colors, font, transparent, theme: diagram.theme)
}

private func _renderKanbanSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    let diagram = try parseKanbanDiagram(rawLines, frontmatter: fm)
    let positioned = layoutKanbanDiagram(diagram)
    let diagramId = UUID().uuidString
    return try renderKanbanSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderArchitectureSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseArchitectureDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.archConfig { diagram.config = fmc }
    if let fmt = fm?.archTheme { diagram.theme = fmt }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutArchitectureDiagram(diagram)
    let diagramId = UUID().uuidString
    return try renderArchitectureSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderRadarSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    var diagram = try parseRadarDiagram(source: source, frontmatter: fm)
    if let fmc = fm?.radarConfig { diagram.config = fmc }
    if let fmt = fm?.radarTheme { diagram.theme = fmt }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutRadarDiagram(diagram)
    return renderRadarSvg(positioned, colors: colors, font: font, transparent: transparent)
}

private func _renderTreemapSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseTreemapDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.treemapConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutTreemapDiagram(diagram)
    let diagramId = UUID().uuidString
    return renderTreemapSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderVennSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseVennDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.vennConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if let tv = fm?.vennThemeVariables { diagram.themeVariables = tv }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutVennDiagram(diagram)
    let diagramId = UUID().uuidString
    return renderVennSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

private func _renderIshikawaSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseIshikawaDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.ishikawaConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if let look = fm?.look { diagram.look = look }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutIshikawaDiagram(diagram)
    let diagramId = UUID().uuidString
    return renderIshikawaSvg(positioned, diagramId: diagramId, colors: colors, fontFamily: font, transparent: transparent)
}

private func _renderTreeViewSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseTreeViewDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.treeViewConfig { diagram.config = fmc }
    if let theme = fm?.treeViewTheme { diagram.theme = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutTreeViewDiagram(diagram)
    let diagramId = UUID().uuidString
    return renderTreeViewSvg(positioned, diagramId: diagramId, font: font)
}

private func _renderEventModelingSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    var diagram = try parseEventModeling(rawLines, frontmatter: fm)
    if let fmc = fm?.eventmodelingConfig { diagram.config = fmc }
    if let theme = fm?.eventmodelingThemeVariables { diagram.themeVariables = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutEventModeling(diagram)
    let diagramId = UUID().uuidString
    return renderEventModelingSvg(positioned, diagramId: diagramId, colors: colors, font: font, transparent: transparent)
}

private func _renderWardleySvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let lines = _rawDiagramLines(from: source)
    var diagram = try parseWardleyMap(lines, frontmatter: fm)
    if let fm = fm {
        if let cfg = fm.wardleyBetaConfig { diagram.config = cfg }
        if let theme = fm.wardleyTheme { diagram.theme = theme }
        if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle {
            diagram.diagramTitle = fmTitle
        }
    }
    let positioned = layoutWardleyMap(diagram)
    return renderWardleyMapSvg(positioned, colors: colors, font: font, transparent: transparent)
}

private func _rawDiagramLines(from source: String) -> [String] {
    source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
}

public func renderMermaidSVGAsync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderMermaidSVG(text, options)
}

public func renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await MermaidPipeline.shared.renderSVG(text, options: options)
}

@available(*, unavailable, message: "Use await renderMermaidSVG")
public func renderMermaidSync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) throws -> String {
    fatalError("Use await renderMermaidSVG(_:_:)")
}

@available(*, deprecated, message: "Use renderMermaidSVG")
public func renderMermaid(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderMermaidSVG(text, options)
}

private func _renderZenUMLSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = _rawDiagramLines(from: source)
    let diagram = try parseZenUMLDiagram(rawLines, frontmatter: fm)
    let positioned = layoutZenUMLDiagram(diagram)
    return renderZenUMLSvg(positioned, colors: colors, font: font, transparent: transparent)
}

open class original_src_index {
    public init() {}
}
