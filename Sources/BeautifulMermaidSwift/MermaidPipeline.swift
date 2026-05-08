import Foundation

/// Stateless namespace for Mermaid diagram pipeline operations.
///
/// All methods are synchronous and nonisolated — callers are responsible
/// for dispatching to an appropriate thread when stack requirements
/// exceed the cooperative thread pool budget (~512 KB).
public enum MermaidPipeline {

    // MARK: - Parse

    public static func parse(_ source: String) throws -> MermaidGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.parse") {
            try MermaidParser.parse(source)
        }
    }

    // MARK: - Layout

    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layout(source:)") {
            let graph = try MermaidParser.parse(source)
            return try GraphLayout(config: config).layout(graph)
        }
    }

    public static func layout(
        _ graph: MermaidGraph,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layout(graph:)") {
            try GraphLayout(config: config).layout(graph)
        }
    }

    // MARK: - Prepare

    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) throws -> PreparedDiagram {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.prepare") {
            let graph = try MermaidParser.parse(source)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)
            return PreparedDiagram(positioned: positioned, theme: theme)
        }
    }

    // MARK: - Render SVG

    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderSVG") {
            try MermaidImageRenderer(theme: theme).renderSVGSync(from: source)
        }
    }

    public static func renderSVG(
        _ text: String,
        options: RenderOptions = RenderOptions()
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderSVG(options:)") {
            try _renderMermaidSVG(text, options)
        }
    }

    // MARK: - Render ASCII

    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderASCII") {
            let colors: [String: String] = [
                "fg": theme.foreground.hexString,
                "border": (theme.border ?? theme.foreground).hexString,
                "line": (theme.line ?? theme.foreground).hexString,
                "arrow": (theme.line ?? theme.foreground).hexString,
            ]
            let asciiTheme = original_src_ascii_index.diagramColorsToAsciiTheme(colors)
            let options = original_src_ascii_index.AsciiRenderOptions(theme: asciiTheme)
            return try original_src_ascii_index.renderMermaidASCII(source, options: options)
        }
    }
}
