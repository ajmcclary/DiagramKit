import Foundation

public actor MermaidPipeline {
    public static let shared = MermaidPipeline()

    public init() {}

    public func parse(_ source: String) throws -> MermaidGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.parse") {
            try MermaidParser.parse(source)
        }
    }

    nonisolated func parseSync(_ source: String) throws -> MermaidGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.parseSync") {
            try MermaidParser.parse(source)
        }
    }

    public func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layout(source:)") {
            try layout(try parse(source), config: config)
        }
    }

    public func layout(
        _ graph: MermaidGraph,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layout(graph:)") {
            try GraphLayout(config: config).layout(graph)
        }
    }

    nonisolated func layoutSync(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layoutSync(source:)") {
            let graph = try MermaidParser.parse(source)
            return try GraphLayout(config: config).layout(graph)
        }
    }

    nonisolated func layoutSync(
        _ graph: MermaidGraph,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.layoutSync(graph:)") {
            try GraphLayout(config: config).layout(graph)
        }
    }

    public func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) throws -> PreparedDiagram {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.prepare") {
            let positioned = try layout(source, config: layoutConfig)
            return PreparedDiagram(positioned: positioned, theme: theme)
        }
    }

    /// Synchronous preparation entry point for execution on a non-cooperative thread.
    ///
    /// The layout pipeline can exhaust the small stacks (~512 KB) used by Swift's
    /// cooperative thread pool. Call this from a dedicated worker thread with an
    /// explicitly larger stack.
    nonisolated func prepareSync(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) throws -> PreparedDiagram {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.prepareSync") {
            let graph = try MermaidParser.parse(source)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)
            return PreparedDiagram(positioned: positioned, theme: theme)
        }
    }

    public func renderSVG(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try renderSVGSync(source: source, theme: theme)
    }

    nonisolated func renderSVGSync(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderSVGSync") {
            try MermaidImageRenderer(theme: theme).renderSVGSync(from: source)
        }
    }

    func renderSVG(
        _ text: String,
        options: RenderOptions = RenderOptions()
    ) throws -> String {
        try renderSVGSync(text, options: options)
    }

    nonisolated func renderSVGSync(
        _ text: String,
        options: RenderOptions = RenderOptions()
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderSVGSync(options:)") {
            try _renderMermaidSVG(text, options)
        }
    }

    public func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try renderASCIISync(source: source, theme: theme)
    }

    nonisolated func renderASCIISync(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try _withMermaidIssueReporting(operation: "MermaidPipeline.renderASCIISync") {
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
