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

    public init(
        bg: String,
        fg: String,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
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
}

private func _decodeXML(_ text: String) -> String {
    // Aligns with TS decodeXML intent for markdown-escaped Mermaid source.
    text
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

private func detectDiagramType(_ text: String) -> _DiagramRoutingType {
    let firstLine = _mermaidSourceLines(from: text).first?.lowercased() ?? ""

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

    return .flowchart
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
    let decodedText = preprocessed.source
    let fm = preprocessed.frontmatter
    let colors = buildColors(options)
    let font = options.font ?? "Inter"
    let transparent = options.transparent ?? false
    let diagramType = detectDiagramType(decodedText)

    let lines = _mermaidSourceLines(from: decodedText)

    switch diagramType {
    case .sequence:
        let diagram = try parseSequenceDiagram(lines)
        let positioned = try layoutSequenceDiagram(diagram, options, config: fm?.sequenceConfig ?? .default)
        return try renderSequenceSvg(positioned, colors, font, transparent)
    case .class:
        let diagram = try parseClassDiagram(lines, frontmatter: fm)
        let positioned = try layoutClassDiagramSync(diagram, options: options)
        return try renderClassSvg(positioned, colors, font, transparent)
    case .er:
        let diagram = try parseErDiagram(lines, frontmatter: fm)
        let positioned = try layoutErDiagramSync(diagram, options: options, config: diagram.config)
        return try renderErSvg(positioned, colors, font, transparent)
    case .xychart:
        let chart = try parseXYChart(lines)
        var mutatedChart = chart
        if let fmc = fm?.xyChartConfig { mutatedChart.config = fmc }
        if let fmt = fm?.xyChartTheme { mutatedChart.theme = fmt }
        if mutatedChart.titleText == nil, let fmTitle = fm?.diagramTitle {
            mutatedChart.diagramTitle = fmTitle
        }
        let positioned = layoutXYChart(mutatedChart, options)
        return renderXYChartSvg(positioned, colors, font, transparent, interactive: options.interactive ?? false)
    case .pie:
        let chart = try parsePieChart(lines, frontmatter: fm)
        let positioned = layoutPieChart(chart)
        return renderPieSvg(positioned, colors, font, transparent)
    case .journey:
        let diagram = try parseJourneyDiagram(lines, frontmatter: fm)
        let config = fm?.journeyConfig ?? .default
        var merged = diagram
        merged.config = config
        let positioned = layoutJourneyDiagram(merged, options: options, config: config)
        return try renderJourneySvg(positioned, colors, font, transparent)
    case .gantt:
        let ganttLines = _mermaidSourceLines(from: decodedText,
            separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseGanttDiagram(ganttLines, frontmatter: fm)
        let config = fm?.ganttConfig ?? .default
        var merged = diagram
        merged.config = config
        let positioned = layoutGanttDiagram(merged)
        let diagramId = UUID().uuidString
        return try renderGanttSvg(positioned, diagramId: diagramId, colors, font, transparent)
    case .quadrant:
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
    case .flowchart:
        let graph = try parseMermaid(decodedText, config: fm?.flowchartConfig, stateConfig: fm?.stateConfig)
        let positioned = try layoutGraphSync(graph, options)
        return try renderSvg(positioned, colors, font, transparent)
    }
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

open class original_src_index {
    public init() {}
}
