import Foundation
import DiagramKitModel

// MARK: - AsciiRenderDescriptor

/// Per-diagram-family ASCII rendering descriptor. Each closure consumes
/// preprocessed Mermaid source plus its parsed frontmatter and emits an
/// ASCII/Unicode string. Replaces 26 arms of the previous switch that
/// lived inline in `original_src_ascii_index.renderMermaidASCII`; the
/// flowchart/state arm still lives inline because it needs class-private
/// helpers (`parseMermaid`, `convertToAsciiGraph`, etc.).
struct AsciiRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (
        _ source: String,
        _ frontmatter: DiagramFrontmatter?,
        _ config: original_src_ascii_index.AsciiConfig,
        _ colorMode: original_src_ascii_index.AsciiThemeColorMode,
        _ theme: original_src_ascii_index.AsciiTheme
    ) throws -> String
}

// MARK: - AsciiRenderRegistry

/// Canonical ASCII rendering dispatcher for the 26 non-flowchart/state
/// families. Flowchart and state diagrams are dispatched directly inside
/// `original_src_ascii_index.renderMermaidASCII` because they require
/// access to class-private helpers.
enum AsciiRenderRegistry {

    static let all: [DiagramType: AsciiRenderDescriptor] = [
        .sequenceDiagram: AsciiRenderDescriptor(
            type: .sequenceDiagram,
            render: { source, _, config, colorMode, theme in
                try renderSequenceAscii(source, _mapAsciiConfig(config), _asciiMapColorMode(colorMode), _asciiMapTheme(theme))
            }
        ),
        .classDiagram: AsciiRenderDescriptor(
            type: .classDiagram,
            render: { source, _, config, colorMode, theme in
                try renderClassAscii(source, _mapAsciiConfig(config), _asciiMapColorMode(colorMode), _asciiMapTheme(theme))
            }
        ),
        .erDiagram: AsciiRenderDescriptor(
            type: .erDiagram,
            render: { source, _, config, colorMode, theme in
                try renderErAscii(source, _mapAsciiConfig(config), _asciiMapColorMode(colorMode), _asciiMapTheme(theme))
            }
        ),
        .xyChart: AsciiRenderDescriptor(
            type: .xyChart,
            render: { source, _, config, colorMode, theme in
                let mapped = _mapAsciiConfig(config)
                return renderXYChartAscii(source, mapped, _asciiMapColorMode(colorMode), _asciiMapTheme(theme, includeAccentBg: true))
            }
        ),
        .pie: AsciiRenderDescriptor(
            type: .pie,
            render: { source, _, _, _, _ in
                let chart = try parsePieChart(source)
                return renderPieAscii(chart)
            }
        ),
        .journey: AsciiRenderDescriptor(
            type: .journey,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseJourneyDiagram(rawLines, frontmatter: frontmatter)
                return renderJourneyAscii(model)
            }
        ),
        .gantt: AsciiRenderDescriptor(
            type: .gantt,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseGanttDiagram(rawLines, frontmatter: frontmatter)
                return renderGanttAscii(model)
            }
        ),
        .quadrantChart: AsciiRenderDescriptor(
            type: .quadrantChart,
            render: { source, _, _, _, _ in
                let model = try parseQuadrantChart(source)
                return renderQuadrantAscii(model)
            }
        ),
        .requirement: AsciiRenderDescriptor(
            type: .requirement,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseRequirementDiagram(rawLines, frontmatter: frontmatter)
                return renderRequirementAscii(model)
            }
        ),
        .gitGraph: AsciiRenderDescriptor(
            type: .gitGraph,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseGitGraph(rawLines, frontmatter: frontmatter)
                return renderGitGraphAscii(model)
            }
        ),
        .mindmap: AsciiRenderDescriptor(
            type: .mindmap,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseMindmap(rawLines, frontmatter: frontmatter)
                return renderMindmapAscii(model)
            }
        ),
        .timeline: AsciiRenderDescriptor(
            type: .timeline,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseTimelineDiagram(rawLines, frontmatter: frontmatter)
                return renderTimelineAscii(model)
            }
        ),
        .sankey: AsciiRenderDescriptor(
            type: .sankey,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseSankeyDiagram(rawLines, frontmatter: frontmatter)
                return renderSankeyAscii(model)
            }
        ),
        .block: AsciiRenderDescriptor(
            type: .block,
            render: { source, frontmatter, _, _, _ in
                let model = try parseBlockDiagram(source, frontmatter: frontmatter)
                return renderBlockAscii(model)
            }
        ),
        .packet: AsciiRenderDescriptor(
            type: .packet,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parsePacketDiagram(rawLines, frontmatter: frontmatter)
                return renderPacketAscii(model)
            }
        ),
        .kanban: AsciiRenderDescriptor(
            type: .kanban,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let (model, _) = try parseKanbanDiagram(rawLines, frontmatter: frontmatter)
                return renderKanbanAscii(model)
            }
        ),
        .architecture: AsciiRenderDescriptor(
            type: .architecture,
            render: { source, frontmatter, _, _, _ in
                let model = try parseArchitectureDiagram(source, frontmatter: frontmatter)
                return renderArchitectureAscii(model)
            }
        ),
        .radar: AsciiRenderDescriptor(
            type: .radar,
            render: { source, frontmatter, _, _, _ in
                let model = try parseRadarDiagram(source: source, frontmatter: frontmatter)
                return renderRadarAscii(model)
            }
        ),
        .treemap: AsciiRenderDescriptor(
            type: .treemap,
            render: { source, frontmatter, _, _, _ in
                let model = try parseTreemapDiagramFromSource(source, frontmatter: frontmatter)
                return renderTreemapAscii(model)
            }
        ),
        .venn: AsciiRenderDescriptor(
            type: .venn,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseVennDiagram(rawLines, frontmatter: frontmatter)
                return renderVennAscii(model)
            }
        ),
        .ishikawa: AsciiRenderDescriptor(
            type: .ishikawa,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseIshikawaDiagram(rawLines, frontmatter: frontmatter)
                return renderIshikawaAscii(model)
            }
        ),
        .treeView: AsciiRenderDescriptor(
            type: .treeView,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseTreeViewDiagram(rawLines, frontmatter: frontmatter)
                return renderTreeViewAscii(model)
            }
        ),
        .eventModeling: AsciiRenderDescriptor(
            type: .eventModeling,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseEventModeling(rawLines, frontmatter: frontmatter)
                return renderEventModelingAscii(model)
            }
        ),
        .wardleyBeta: AsciiRenderDescriptor(
            type: .wardleyBeta,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseWardleyMap(rawLines, frontmatter: frontmatter)
                return renderWardleyAscii(model)
            }
        ),
        .zenuml: AsciiRenderDescriptor(
            type: .zenuml,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let model = try parseZenUMLDiagram(rawLines, frontmatter: frontmatter)
                return renderZenUMLAscii(model)
            }
        ),
        .c4: AsciiRenderDescriptor(
            type: .c4,
            render: { source, frontmatter, _, _, _ in
                let rawLines = DiagramSourceNormalizer.rawLines(source)
                let (model, _) = try parseC4Diagram(rawLines, frontmatter: frontmatter)
                return renderC4Ascii(model)
            }
        )
    ]

    /// Look up the descriptor for `type` and execute it. Returns `nil` if
    /// the type is not in the registry — flowchart and state diagrams are
    /// the documented absences and are dispatched inline by
    /// `renderMermaidASCII`.
    static func render(
        type: DiagramType,
        source: String,
        frontmatter: DiagramFrontmatter?,
        config: original_src_ascii_index.AsciiConfig,
        colorMode: original_src_ascii_index.AsciiThemeColorMode,
        theme: original_src_ascii_index.AsciiTheme
    ) throws -> String? {
        guard let descriptor = all[type] else { return nil }
        return try descriptor.render(source, frontmatter, config, colorMode, theme)
    }
}

// MARK: - File-scope helpers

func _mapAsciiConfig(_ config: original_src_ascii_index.AsciiConfig) -> original_src_ascii_types.AsciiConfig {
    original_src_ascii_types.AsciiConfig(
        useAscii: config.useAscii,
        paddingX: config.paddingX,
        paddingY: config.paddingY,
        boxBorderPadding: config.boxBorderPadding,
        graphDirection: config.graphDirection
    )
}

func _asciiMapColorMode(_ colorMode: original_src_ascii_index.AsciiThemeColorMode) -> ColorMode {
    switch colorMode {
    case .none:   return .none
    case .ansi16: return .ansi16
    case .ansi256: return .ansi256
    case .truecolor: return .truecolor
    case .html:   return .html
    }
}

func _asciiMapTheme(_ theme: original_src_ascii_index.AsciiTheme, includeAccentBg: Bool = false) -> original_src_ascii_types.AsciiTheme {
    original_src_ascii_types.AsciiTheme(
        fg: theme.values["fg"] ?? "#27272a",
        border: theme.values["border"] ?? "#a1a1aa",
        line: theme.values["line"] ?? "#71717a",
        arrow: theme.values["arrow"] ?? "#52525b",
        corner: theme.values["corner"],
        junction: theme.values["junction"],
        accent: includeAccentBg ? theme.values["accent"] : nil,
        bg: includeAccentBg ? theme.values["bg"] : nil
    )
}
