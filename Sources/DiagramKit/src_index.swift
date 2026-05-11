// Apple-only — depends on Models gated SVG/layout symbols. `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
// Ported from original/src/index.ts
import Foundation
import DiagramKitCommon
import DiagramKitModel

// RenderOptions + DiagramColors moved to DiagramKitModel/RenderOptions.swift

private enum _IndexDefaults {
    static let bg = "#FFFFFF"
    static let fg = "#27272A"
}

private func _decodeXML(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

// `_DiagramRoutingType` and `detectDiagramType` previously lived here as
// a parallel routing surface that mapped `DiagramType` cases to a
// SVG-specific enum. Both have been replaced by `SVGRenderRegistry`,
// which routes directly off `DiagramRegistry.detect(from:).type`.

private func _firstDiagramStatement(in text: String) -> String {
    MermaidSourceNormalizer.statements(text).first ?? ""
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

private func _stableDiagramId(prefix: String, source: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in source.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    return "\(prefix)-\(String(hash, radix: 16))"
}

func _renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions(),
    layoutConfig: LayoutConfig = LayoutConfig()
) throws -> String {
    let preprocessed = _preprocessMermaidSource(_decodeXML(text))
    return try _renderPreprocessedMermaidSVG(
        preprocessed.source,
        frontmatter: preprocessed.frontmatter,
        options: options,
        layoutConfig: layoutConfig
    )
}

private func _renderPreprocessedMermaidSVG(
    _ decodedText: String,
    frontmatter fm: DiagramFrontmatter?,
    options: RenderOptions,
    layoutConfig: LayoutConfig
) throws -> String {
    let colors = buildColors(options)
    let font = options.font ?? DiagramFontResolver.shared.svgFontFamily
    let transparent = options.transparent ?? false
    return try SVGRenderRegistry.render(
        decodedText,
        frontmatter: fm,
        options: options,
        layoutConfig: layoutConfig,
        colors: colors,
        font: font,
        transparent: transparent
    )
}

func _renderC4SvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let lines = MermaidSourceNormalizer.rawLines(source)
    let config = fm?.c4Config ?? C4DiagramConfig()
    var diagram = try parseC4Diagram(lines, frontmatter: fm)
    diagram.config = config
    let positioned = layoutC4Diagram(diagram)
    let diagramId = StableID.derive(from: source)
    return try renderC4Svg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderSequenceSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseSequenceDiagram(lines)
    let positioned = try layoutSequenceDiagram(diagram, options, config: fm?.sequenceConfig ?? .default)
    return try renderSequenceSvg(positioned, colors, font, transparent)
}

func _renderClassSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseClassDiagram(lines, frontmatter: fm)
    let positioned = try layoutClassDiagramSync(diagram, options: options)
    return try renderClassSvg(positioned, colors, font, transparent, securityLevel: fm?.securityLevel)
}

func _renderErSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseErDiagram(lines, frontmatter: fm)
    let positioned = try layoutErDiagramSync(diagram, options: options, config: diagram.config)
    return try renderErSvg(positioned, colors, font, transparent)
}

func _renderXYChartSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let source = lines.joined(separator: "\n")
    let graph = try DiagramRegistry._xyChart.parse(source, fm)
    let positioned = try DiagramRegistry._xyChart.layout(graph, LayoutConfig())
    guard case let .xyChart(chart) = positioned.content else {
        throw MermaidStructuralError.payloadMismatch(.xyChart)
    }
    return renderXYChartSvg(chart, colors, font, transparent, interactive: options.interactive ?? false)
}

func _renderPieSvgCase(lines: [String], fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let chart = try parsePieChart(lines, frontmatter: fm)
    let positioned = layoutPieChart(chart)
    return renderPieSvg(positioned, colors, font, transparent)
}

func _renderJourneySvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let diagram = try parseJourneyDiagram(lines, frontmatter: fm)
    let config = fm?.journeyConfig ?? .default
    var merged = diagram
    merged.config = config
    let positioned = layoutJourneyDiagram(merged, options: options, config: config)
    return try renderJourneySvg(positioned, colors, font, transparent)
}

func _renderGanttSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let ganttLines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
    let diagram = try parseGanttDiagram(ganttLines, frontmatter: fm)
    let config = fm?.ganttConfig ?? .default
    var merged = diagram
    merged.config = config
    let positioned = layoutGanttDiagram(merged)
    let diagramId = StableID.derive(from: source)
    return try renderGanttSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderQuadrantSvgCase(lines: [String], fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let source = lines.joined(separator: "\n")
    let graph = try DiagramRegistry._quadrantChart.parse(source, fm)
    let positioned = try DiagramRegistry._quadrantChart.layout(graph, LayoutConfig())
    guard case let .quadrantChart(chart) = positioned.content else {
        throw MermaidStructuralError.payloadMismatch(.quadrantChart)
    }
    return renderQuadrantSvg(chart, colors, font, transparent)
}

func _renderRequirementSvgCase(lines: [String], fm: DiagramFrontmatter?, options: RenderOptions, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    var diagram = try parseRequirementDiagram(lines, frontmatter: fm)
    if let fmTheme = fm?.requirementTheme { diagram.config.theme = fmTheme }
    let positioned = try layoutRequirementDiagram(diagram, options: options)
    let dId = StableID.derive(from: lines.joined(separator: "\n"))
    return try renderRequirementSvg(positioned, colors, font, transparent,
        diagramId: dId,
        look: fm?.look,
        theme: fm?.requirementTheme,
        htmlLabels: fm?.htmlLabels)
}

func _renderFlowchartSvgCase(source: String, fm: DiagramFrontmatter?, options: RenderOptions, layoutConfig: LayoutConfig, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let graph = try parseMermaid(source, config: fm?.flowchartConfig, stateConfig: fm?.stateConfig)
    let positioned = layoutConfig == LayoutConfig()
        ? try layoutGraphSync(graph, options)
        : try layoutGraphSync(graph, config: layoutConfig)
    return try renderSvg(positioned, colors, font, transparent)
}

func _renderGitGraphSvgCase(source: String, fm: DiagramFrontmatter?) throws -> String {
    let gitLines = MermaidSourceNormalizer.statements(source)
    let diagram = try parseGitGraph(gitLines, frontmatter: fm)
    let positioned = layoutGitGraph(diagram)
    let diagramId = StableID.derive(from: source)
    return renderGitGraphSvg(positioned, diagramId: diagramId)
}

func _renderMindmapSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    let diagram = try parseMindmap(rawLines, frontmatter: fm)
    let positioned = try layoutMindmap(diagram)
    let diagramId = _stableDiagramId(prefix: "mindmap", source: source)
    return renderMindmapSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderTimelineSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let timelineLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseTimelineDiagram(timelineLines, frontmatter: fm)
    if let fmc = fm?.timelineConfig { diagram.config = fmc }
    if let fmt = fm?.timelineTheme { diagram.theme = fmt }
    if diagram.diagramTitle == nil, let fmTitle = fm?.title {
        diagram.diagramTitle = fmTitle
    }
    diagram.themeName = fm?.theme
    diagram.look = fm?.look
    let positioned = layoutTimelineDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return try renderTimelineSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderSankeySvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let graph = try DiagramRegistry._sankey.parse(source, fm)
    let positioned = try DiagramRegistry._sankey.layout(graph, LayoutConfig())
    guard case let .sankey(diagram) = positioned.content else {
        throw MermaidStructuralError.payloadMismatch(.sankey)
    }
    let diagramId = StableID.derive(from: source)
    return renderSankeySvg(diagram, colors, font, transparent, diagramId: diagramId)
}

func _renderBlockSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let blockLines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
    var diagram = try parseBlockDiagramLines(blockLines)
    if let fmc = fm?.blockConfig { diagram.config = fmc }
    if let title = fm?.diagramTitle { diagram.diagramTitle = title }
    let positioned = try layoutBlockDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return try renderBlockSvg(positioned, diagramId: diagramId, colors: colors, fontFamily: font, transparent: transparent)
}

func _renderPacketSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let packetLines = MermaidSourceNormalizer.statements(source)
    var diagram = try parsePacketDiagram(packetLines, frontmatter: fm)
    if diagram.diagramTitle == nil, let title = fm?.diagramTitle {
        diagram.diagramTitle = title
    }
    let positioned = layoutPacketDiagram(diagram)
    return renderPacketSvg(positioned, colors, font, transparent, theme: diagram.theme)
}

func _renderKanbanSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    let diagram = try parseKanbanDiagram(rawLines, frontmatter: fm)
    let positioned = layoutKanbanDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return try renderKanbanSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderArchitectureSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseArchitectureDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.archConfig { diagram.config = fmc }
    if let fmt = fm?.archTheme { diagram.theme = fmt }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutArchitectureDiagram(diagram)
    let diagramId = _stableDiagramId(prefix: "architecture", source: source)
    return try renderArchitectureSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderRadarSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let graph = try DiagramRegistry._radar.parse(source, fm)
    let positioned = try DiagramRegistry._radar.layout(graph, LayoutConfig())
    guard case let .radar(diagram) = positioned.content else {
        throw MermaidStructuralError.payloadMismatch(.radar)
    }
    return renderRadarSvg(diagram, colors: colors, font: font, transparent: transparent)
}

func _renderTreemapSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseTreemapDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.treemapConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutTreemapDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return renderTreemapSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderVennSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseVennDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.vennConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if let tv = fm?.vennThemeVariables { diagram.themeVariables = tv }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutVennDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return renderVennSvg(positioned, diagramId: diagramId, colors, font, transparent)
}

func _renderIshikawaSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseIshikawaDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.ishikawaConfig { diagram.config = fmc }
    if let theme = fm?.theme { diagram.themeName = theme }
    if let look = fm?.look { diagram.look = look }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutIshikawaDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return renderIshikawaSvg(positioned, diagramId: diagramId, colors: colors, fontFamily: font, transparent: transparent)
}

func _renderTreeViewSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseTreeViewDiagram(rawLines, frontmatter: fm)
    if let fmc = fm?.treeViewConfig { diagram.config = fmc }
    if let theme = fm?.treeViewTheme { diagram.theme = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutTreeViewDiagram(diagram)
    let diagramId = StableID.derive(from: source)
    return renderTreeViewSvg(positioned, diagramId: diagramId, font: font)
}

func _renderEventModelingSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    var diagram = try parseEventModeling(rawLines, frontmatter: fm)
    if let fmc = fm?.eventmodelingConfig { diagram.config = fmc }
    if let theme = fm?.eventmodelingThemeVariables { diagram.themeVariables = theme }
    if diagram.diagramTitle == nil, let fmTitle = fm?.diagramTitle {
        diagram.diagramTitle = fmTitle
    }
    let positioned = layoutEventModeling(diagram)
    let diagramId = StableID.derive(from: source)
    return renderEventModelingSvg(positioned, diagramId: diagramId, colors: colors, font: font, transparent: transparent)
}

func _renderWardleySvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let lines = MermaidSourceNormalizer.rawLines(source)
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
    try await MermaidRenderer._runOnWorker {
        try MermaidPipeline.renderSVG(text, options: options)
    }
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

func _renderZenUMLSvgCase(source: String, fm: DiagramFrontmatter?, colors: DiagramColors, font: String, transparent: Bool) throws -> String {
    let rawLines = MermaidSourceNormalizer.rawLines(source)
    let diagram = try parseZenUMLDiagram(rawLines, frontmatter: fm)
    let positioned = layoutZenUMLDiagram(diagram)
    let useMaxWidth = fm?.sequenceConfig?.useMaxWidth ?? true
    return renderZenUMLSvg(positioned, colors: colors, font: font, transparent: transparent, useMaxWidth: useMaxWidth)
}

open class original_src_index {
    public init() {}
}
#endif
